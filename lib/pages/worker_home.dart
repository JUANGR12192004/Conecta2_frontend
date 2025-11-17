import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/account_management_sheet.dart';
import '../widgets/profile_popover.dart';
import '../utils/categories.dart';
import '../widgets/current_location_map.dart';
import '../widgets/payment_checkout_helper.dart';

const Color _workerPrimary = Color(0xFF1E88E5);
const Color _workerSecondary = Color(0xFF64B5F6);

class WorkerHome extends StatefulWidget {
  static const String routeName = '/workerHome';

  const WorkerHome({super.key});

  @override
  State<WorkerHome> createState() => _WorkerHomeState();
}

class _WorkerHomeState extends State<WorkerHome> with WidgetsBindingObserver {
  int? _workerId;
  Map<String, dynamic>? _profile;
  bool _loading = false;
  String? _error;
  bool _initialized = false;
  Map<String, dynamic>? _initialArgs;
  // Oportunidades
  List<Map<String, dynamic>> _opportunities = [];
  String? _opError;
  int _hiddenExpiredOpportunities = 0;
  // Notificaciones para trabajador (contraofertas/aceptaciones)
  List<Map<String, dynamic>> _incomingOffers = [];
  bool _inOffersLoading = false;
  String? _inOffersError;

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final normalized = value.replaceAll(',', '.');
      return double.tryParse(normalized);
    }
    return null;
  }

  String _formatCurrency(double? value) {
    if (value == null) return '';
    final bool isInt = value % 1 == 0;
    final amount = isInt ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
    return '\$$amount';
  }

  String _participantLabel(dynamic raw) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) return '';
    switch (value.toUpperCase()) {
      case 'CLIENTE':
      case 'CUSTOMER':
        return 'Cliente';
      case 'TRABAJADOR':
      case 'WORKER':
        return 'Trabajador';
      default:
        return value[0].toUpperCase() + value.substring(1).toLowerCase();
    }
  }

  String _negotiationStateLabel(dynamic raw) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) return '';
    switch (value.toUpperCase()) {
      case 'EN_NEGOCIACION':
        return 'En negociación';
      case 'EN_CURSO':
      case 'EN_PROCESO':
        return 'En curso';
      case 'ACEPTADA':
        return 'Aceptada';
      case 'RECHAZADA':
        return 'Rechazada';
      case 'CERRADA':
        return 'Cerrada';
      case 'PENDIENTE':
        return 'Pendiente';
      default:
        return value[0].toUpperCase() + value.substring(1).toLowerCase();
    }
  }

  bool _isWorkerTurn(dynamic raw) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) return true;
    final upper = value.toUpperCase();
    return upper == 'TRABAJADOR' || upper == 'WORKER';
  }

  String _stringFromSources(List<String> keys) {
    final Map<String, dynamic> combined = {};
    if (_initialArgs != null) combined.addAll(_initialArgs!);
    if (_profile != null) combined.addAll(_profile!);
    for (final key in keys) {
      final value = combined[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _currentName() =>
      _stringFromSources(['nombreCompleto', 'nombre', 'fullName']);
  String _currentEmail() =>
      _stringFromSources(['correo', 'email', 'correoElectronico']);
  String _currentPhone() =>
      _stringFromSources(['celular', 'telefono', 'phone']);
  String _currentArea() =>
      _stringFromSources(['areaServicio', 'area', 'especialidad']);

  String _serviceStateLabel(dynamic raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return 'Pendiente';
    switch (value.toUpperCase()) {
      case 'PENDIENTE':
        return 'Pendiente';
      case 'PENDIENTE_PAGO':
        return 'Pago pendiente';
      case 'ASIGNADO':
        return 'Asignado';
      case 'EN_PROCESO':
      case 'EN_CURSO':
        return 'En curso';
      case 'FINALIZADO':
        return 'Finalizado';
      case 'CANCELADO':
        return 'Expirado';
      default:
        return value[0].toUpperCase() + value.substring(1).toLowerCase();
    }
  }

  int? _serviceIdFromOffer(Map<String, dynamic> offer) {
    final direct = _asInt(
      offer['serviceId'] ??
          offer['servicioId'] ??
          offer['servicio_id'] ??
          offer['servicioID'],
    );
    if (direct != null) return direct;
    final nested = offer['service'] ?? offer['servicio'];
    if (nested is Map) return _asInt(nested['id']);
    return null;
  }

  void _removeOpportunityByServiceId(int? serviceId) {
    if (serviceId == null) return;
    setState(() {
      _opportunities.removeWhere((svc) {
        final id = _asInt(svc['id']);
        return id != null && id == serviceId;
      });
    });
  }

  String _initialLetter() {
    final source = _currentName().isNotEmpty ? _currentName() : _currentEmail();
    if (source.isEmpty) return '?';
    return source.trim().substring(0, 1).toUpperCase();
  }

  DateTime? _parseServiceDate(dynamic raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    try {
      final parsed = DateTime.parse(text);
      return parsed.isUtc ? parsed.toLocal() : parsed;
    } catch (_) {
      return null;
    }
  }

  bool _isDateExpired(DateTime? date) {
    if (date == null) return false;
    final cutoff = DateTime(date.year, date.month, date.day, 23, 59, 59);
    return DateTime.now().isAfter(cutoff);
  }

  bool _shouldHideService(Map<String, dynamic> service) {
    final estadoRaw = (service['estado'] ?? service['estadoServicio'] ?? service['status'] ?? '').toString();
    if (estadoRaw.toUpperCase() == 'CANCELADO') return true;
    final date = _parseServiceDate(service['fechaEstimada'] ?? service['fecha']);
    return _isDateExpired(date);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _initialArgs = Map<String, dynamic>.from(
        args.map((key, value) => MapEntry(key.toString(), value)),
      );
      _workerId = _asInt(args["userId"] ?? args["id"]);
      final profileArg = args["profile"];
      if (profileArg is Map<String, dynamic>) {
        _profile = Map<String, dynamic>.from(profileArg);
      } else if (profileArg is Map) {
        _profile = profileArg.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    }

    if (_workerId != null) {
      _fetchProfile();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshWorkerData();
    }
  }

  Future<void> _fetchProfile() async {
    final id = _workerId;
    if (id == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ApiService.fetchWorkerById(id);
      if (!mounted) return;
      setState(() {
        _profile = data;
        _loading = false;
      });
      await _refreshWorkerData();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _refreshWorkerData() async {
    if (_workerId == null) return;
    await _fetchOpportunities();
    await _fetchIncomingOffers();
  }

  Future<void> _fetchOpportunities() async {
    final area = _currentArea();
    final categoria = normalizeCategoryValue(area);
    if (categoria.isEmpty) {
    if (mounted) {
      setState(() {
        _opportunities = [];
        _opError = null;
        _hiddenExpiredOpportunities = 0;
      });
    }
      return;
    }

    if (mounted) {
      setState(() {
        _opError = null;
      });
    }

    try {
      final list = await ApiService.getPublicAvailableServices(categoria: categoria);
      if (!mounted) return;
      int expiredCount = 0;
      final filtered = <Map<String, dynamic>>[];
      for (final svc in list) {
        if (_shouldHideService(svc)) {
          expiredCount++;
          continue;
        }
        filtered.add(svc);
      }
      setState(() {
        _opportunities = filtered;
        _hiddenExpiredOpportunities = expiredCount;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _opError = e.toString().replaceFirst('Exception: ', '');
        _hiddenExpiredOpportunities = 0;
      });
    }
  }

  Future<void> _fetchIncomingOffers() async {
    final id = _workerId;
    if (id == null) return;
    if (mounted) {
      setState(() {
        _inOffersLoading = true;
        _inOffersError = null;
      });
    }
    try {
      final list = await ApiService.getWorkerPendingOffers(id);
      if (!mounted) return;
      setState(() {
        _incomingOffers = list;
        _inOffersLoading = false;
      });

      // Si alguna oferta aparece como ACEPTADA por el cliente,
      // marcar el servicio correspondiente como ASIGNADO solo para este trabajador.
      for (final o in list) {
        final estado = (o['estadoNegociacion'] ?? o['estado'] ?? '').toString().toUpperCase();
        if (estado == 'ACEPTADA') {
          final sid = _serviceIdFromOffer(o);
          if (sid != null) {
            setState(() {
              _opportunities = _opportunities.map((svc) {
                final id = _asInt(svc['id']);
                if (id != null && id == sid) {
                  final updated = Map<String, dynamic>.from(svc);
                  updated['estado'] = 'ASIGNADO';
                  updated['estadoServicio'] = 'ASIGNADO';
                  return updated;
                }
                return svc;
              }).toList();
            });
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _inOffersError = e.toString().replaceFirst('Exception: ', '');
        _inOffersLoading = false;
      });
    }
  }

  Future<void> _openAccountManager() async {
    final id = _workerId;
    if (id == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No fue posible cargar los datos de tu cuenta.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final updated = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      useSafeArea: true,
      builder: (_) => AccountManagementSheet(
        userId: id,
        role: 'worker',
        initialData: _profile,
      ),
    );

    if (updated != null && mounted) {
      setState(() => _profile = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Datos de cuenta actualizados'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _workerPrimary,
        ),
      );
      await _fetchProfile();
    }
  }

  Future<void> _logout() async {
    ApiService.clearToken();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, "/", (route) => false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _openOfferSheet(int serviceId, String titulo) async {
    final workerId = _workerId;
    if (workerId == null) return;

    final priceCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    bool sending = false;

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setM) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Ofertar para: ${titulo.isEmpty ? 'Servicio' : titulo}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Precio propuesto',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Mensaje (opcional)',
                    prefixIcon: Icon(Icons.message_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: sending ? null : () => Navigator.pop(ctx),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _workerPrimary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: sending
                            ? null
                            : () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final raw = priceCtrl.text.trim().replaceAll(',', '.');
                                final price = double.tryParse(raw);
                                if (price == null || price <= 0) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Ingresa un precio válido'),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }
                                setM(() => sending = true);
                                try {
                                  await ApiService.createOffer(
                                    serviceId: serviceId,
                                    workerId: workerId,
                                    precio: price,
                                    mensaje: noteCtrl.text.trim(),
                                  );
                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx);
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Oferta enviada âœ…'),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: _workerPrimary,
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Error al ofertar: $e'),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                } finally {
                                  setM(() => sending = false);
                                }
                              },
                        child: sending
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Enviar oferta'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _showProfileMenu() async {
    final email = _currentEmail();
    final name = _currentName();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => ProfilePopover(
        name: name,
        email: email.isNotEmpty ? email : 'Mi cuenta',
        initialLetter: _initialLetter(),
        accentColor: _workerPrimary,
      ),
    );

    if (result == 'manage') {
      await _openAccountManager();
    } else if (result == 'logout') {
      await _logout();
    }
  }

  Widget _buildProfileAvatar() {
    final letter = _initialLetter();
    return CircleAvatar(
      radius: 18,
      backgroundColor: _workerPrimary,
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final nombre = _currentName();
    final correo = _currentEmail();
    final celular = _currentPhone();
    final area = _currentArea();
    final rawActive =
        (_profile != null ? _profile!['activo'] : null) ??
        (_initialArgs != null ? _initialArgs!['activo'] : null);
    final activo =
        rawActive != null && rawActive.toString().toLowerCase() == 'true';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: _workerPrimary.withOpacity(0.12),
                  child: const Icon(
                    Icons.engineering_outlined,
                    color: _workerPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre.isEmpty ? 'Trabajador' : nombre,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (correo.isNotEmpty)
                        Text(
                          correo,
                          style: const TextStyle(color: Colors.black87),
                        ),
                      if (celular.isNotEmpty)
                        Text(
                          celular,
                          style: const TextStyle(color: Colors.black54),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.manage_accounts_outlined,
                    color: _workerPrimary,
                  ),
                  tooltip: 'Editar cuenta',
                  onPressed: _openAccountManager,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (area.isNotEmpty)
                  Chip(
                    label: Text(area),
                    backgroundColor: _workerSecondary.withOpacity(0.15),
                    labelStyle: const TextStyle(color: _workerPrimary),
                  ),
                Chip(
                  label: Text(activo ? 'Cuenta activa' : 'Cuenta inactiva'),
                  backgroundColor: (activo ? Colors.green : Colors.orange)
                      .withOpacity(0.15),
                  labelStyle: TextStyle(
                    color: activo ? Colors.green[800] : Colors.orange[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = RefreshIndicator(
      onRefresh: _fetchProfile,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_profile != null) _buildProfileCard(),
          if (_error != null)
            Card(
              color: Colors.red.withOpacity(0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: Text(_error!, style: const TextStyle(color: Colors.red)),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.red),
                  onPressed: _fetchProfile,
                  tooltip: 'Reintentar',
                ),
              ),
            ),
          if (_profile == null && _error == null && !_loading)
            OutlinedButton.icon(
              onPressed: _fetchProfile,
              icon: const Icon(Icons.person_search_outlined),
              label: const Text('Cargar datos de mi cuenta'),
            ),
          const SizedBox(height: 12),
          _buildOpportunitiesCard(),
const SizedBox(height: 12),
_buildMapCard(),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Conecta2 Trabajador',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
        ),
        actions: [ IconButton( icon: Stack( clipBehavior: Clip.none, children: [ const Icon(Icons.notifications_outlined, color: Colors.black87), if (_incomingOffers.isNotEmpty) Positioned(right: -2, top: -2, child: Container(padding: const EdgeInsets.symmetric(horizontal:5, vertical:2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)), child: Text(_incomingOffers.length.toString(), style: const TextStyle(color: Colors.white, fontSize: 10)),),), ], ), tooltip: 'Notificaciones', onPressed: _openWorkerNotifications, ), IconButton( icon: const Icon(Icons.refresh_outlined, color: Colors.black87), tooltip: 'Actualizar', onPressed: _fetchProfile, ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: GestureDetector(
              onTap: _showProfileMenu,
              child: _buildProfileAvatar(),
            ),
          ),
        ],
      ),
      body: _loading && _profile == null
          ? const Center(child: CircularProgressIndicator())
          : body,
    );
  }

  Future<void> _openWorkerNotifications() async {
    await _fetchIncomingOffers();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setM) {
          Future<void> respond({
            required int offerId,
            required String action,
            double? monto,
            String? mensaje,
            int? serviceId,
          }) async {
            final upper = action.toUpperCase();
            Map<String, dynamic>? response;
            try {
              if (upper == 'COUNTER') {
                final counterMonto = monto;
                if (counterMonto == null || counterMonto <= 0) {
                  throw Exception('Monto inválido');
                }
                await ApiService.workerCounterOffer(
                  offerId: offerId,
                  monto: counterMonto,
                  mensaje: mensaje,
                );
              } else {
                response = await ApiService.workerRespondOffer(
                  offerId: offerId,
                  action: upper,
                  mensaje: mensaje,
                );
              }
              if (!mounted) return;
              setM(() => _incomingOffers.removeWhere((o) {
                    final raw = o['id'];
                    if (raw is int) return raw == offerId;
                    return int.tryParse(raw.toString()) == offerId;
                  }));
              if (upper == 'ACCEPT' && mounted) {
                _removeOpportunityByServiceId(serviceId);
              }
              await _fetchOpportunities();
              if (!mounted) return;
              final color = upper == 'ACCEPT'
                  ? Colors.green
                  : upper == 'REJECT'
                      ? Colors.red
                      : _workerPrimary;
              final text = upper == 'ACCEPT'
                  ? 'Oferta aceptada'
                  : upper == 'REJECT'
                      ? 'Oferta rechazada'
                      : 'Contraoferta enviada';
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(text),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: color,
                ),
              );
              if (upper == 'ACCEPT' && _requiresPayment(response)) {
                await _openWorkerPaymentCheckout(
                  offerId: offerId,
                  serviceId: serviceId,
                  paymentInfo: response,
                );
              }
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: $e'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Colors.red,
                ),
              );
            }
          }

          Future<void> doCounter(int offerId, int? serviceId) async {
            final priceCtrl = TextEditingController();
            final noteCtrl = TextEditingController();
            String? errorText;
            final payload = await showDialog<Map<String, dynamic>?>(
              context: context,
              builder: (_) => StatefulBuilder(
                builder: (dialogCtx, setDialogState) {
                  return AlertDialog(
                    title: const Text('Enviar contraoferta'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: priceCtrl,
                          autofocus: true,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Monto',
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: noteCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Mensaje (opcional)',
                            prefixIcon: Icon(Icons.message_outlined),
                          ),
                        ),
                        if (errorText != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                errorText!,
                                style: const TextStyle(color: Colors.red, fontSize: 12),
                              ),
                            ),
                          ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () {
                          final raw = priceCtrl.text.trim().replaceAll(',', '.');
                          final value = double.tryParse(raw);
                          if (value == null || value <= 0) {
                            setDialogState(() => errorText = 'Ingresa un monto válido');
                            return;
                          }
                          final note = noteCtrl.text.trim();
                          Navigator.pop(dialogCtx, {
                            "monto": value,
                            if (note.isNotEmpty) "mensaje": note,
                          });
                        },
                        child: const Text('Enviar'),
                      ),
                    ],
                  );
                },
              ),
            );

            final monto = payload?['monto'] as double?;
            if (monto == null || monto <= 0) return;
            final mensaje = payload?['mensaje'] as String?;
            await respond(
              offerId: offerId,
              action: 'COUNTER',
              monto: monto,
              mensaje: mensaje,
              serviceId: serviceId,
            );
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                ),
                const SizedBox(height: 12),
                const Text('Notificaciones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (_inOffersLoading && _incomingOffers.isEmpty)
                  const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                else if (_inOffersError != null)
                  Material(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      leading: const Icon(Icons.error_outline, color: Colors.red),
                      title: Text('' + _inOffersError.toString(), style: const TextStyle(color: Colors.red)),
                      trailing: IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.red),
                        onPressed: _fetchIncomingOffers,
                      ),
                    ),
                  )
                else if (_incomingOffers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('No tienes nuevas respuestas.', style: TextStyle(color: Colors.black54)),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _incomingOffers.length,
                      separatorBuilder: (_, __) => const Divider(height: 16),
                      itemBuilder: (context, i) {
                        final o = _incomingOffers[i];
                        final client = (o['clientName'] ?? 'Cliente').toString();
                        final estadoRaw = (o['estadoNegociacion'] ?? o['estado'] ?? '').toString();
                        final estado = _negotiationStateLabel(estadoRaw);
                        final turnoRaw = o['requiereRespuestaDe'] ?? o['turno'] ?? o['pendingFor'];
                        final turno = _participantLabel(turnoRaw);
                        final ultimo = _participantLabel(o['ultimoEmisor'] ?? o['lastActor']);
                        final serviceTitle = (o['serviceTitle'] ?? o['tituloServicio'] ?? '').toString();
                        final montoActual = _asDouble(o['monto'] ?? o['precio'] ?? o['montoActual'] ?? o['montoFinal']);
                        final montoCliente = _asDouble(o['montoCliente'] ?? o['precioCliente']);
                        final montoTrab = _asDouble(o['montoTrabajador'] ?? o['precioTrabajador']);
                        final offerId = () {
                          final v = o['id'];
                          if (v is int) return v;
                          return int.tryParse(v.toString()) ?? 0;
                        }();
                        final serviceId = _serviceIdFromOffer(o);
                        final subtitleLines = <String>[
                          if (serviceTitle.isNotEmpty) 'Servicio: ' + serviceTitle,
                          if (estado.isNotEmpty) 'Estado: ' + estado,
                          if (turno.isNotEmpty) 'Turno: ' + turno,
                          if (ultimo.isNotEmpty) '?ltima oferta: ' + ultimo,
                          if (montoActual != null) 'Monto vigente: ' + _formatCurrency(montoActual),
                          if (montoCliente != null) 'Cliente ofert?: ' + _formatCurrency(montoCliente),
                          if (montoTrab != null) 'Tu oferta: ' + _formatCurrency(montoTrab),
                        ];
                        final subtitleWidget = subtitleLines.isEmpty
                            ? null
                            : Text(subtitleLines.join('\n'));
                        final estadoNormalized = estadoRaw.toUpperCase();
                        final canRespond = offerId > 0 && (estadoNormalized.isEmpty || estadoNormalized == 'EN_NEGOCIACION') && _isWorkerTurn(turnoRaw);
                        return ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.campaign_outlined)),
                          title: Text(client),
                          subtitle: subtitleWidget,
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                tooltip: 'Aceptar',
                                icon: const Icon(Icons.check_circle, color: Colors.green),
                                onPressed: canRespond ? () => respond(offerId: offerId, action: 'ACCEPT', serviceId: serviceId) : null,
                              ),
                              IconButton(
                                tooltip: 'Rechazar',
                                icon: const Icon(Icons.cancel, color: Colors.red),
                                onPressed: canRespond ? () => respond(offerId: offerId, action: 'REJECT', serviceId: serviceId) : null,
                              ),
                              IconButton(
                                tooltip: 'Contraoferta',
                                icon: const Icon(Icons.swap_horiz, color: Colors.orange),
                                onPressed: canRespond ? () => doCounter(offerId, serviceId) : null,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        });
      },
    );
  }

}

Widget _statusChip(String text, Color color) {
  return Chip(
    label: Text(text),
    backgroundColor: color.withOpacity(0.1),
    labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
  );
}

extension _WorkerHomeUI on _WorkerHomeState {
Widget _buildOpportunitiesCard() {
if (_opError != null) {
      return Card(
        color: Colors.orange.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          leading: const Icon(Icons.error_outline, color: Colors.orange),
          title: Text(_opError!, style: const TextStyle(color: Colors.orange)),
          trailing: IconButton(
            icon: const Icon(Icons.refresh_outlined, color: Colors.orange),
            onPressed: _fetchOpportunities,
            tooltip: 'Reintentar',
          ),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tus oportunidades',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (_hiddenExpiredOpportunities > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Se ocultaron $_hiddenExpiredOpportunities solicitudes vencidas.',
                  style: const TextStyle(color: Colors.orange),
                ),
              ),
            if (_opportunities.isEmpty)
              const Text(
                'No hay oportunidades disponibles en tu área por ahora.',
                style: TextStyle(color: Colors.black54),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemCount: _opportunities.length,
                itemBuilder: (context, index) {
                  final s = _opportunities[index];
                  final titulo = (s['titulo'] ?? '').toString();
                  final categoria = normalizeCategoryValue((s['categoria'] ?? '').toString());
                  final ubicacion = (s['ubicacion'] ?? '').toString();
                  final estadoRaw = (s['estado'] ?? s['estadoServicio'] ?? s['status'] ?? 'PENDIENTE').toString();
                  final estadoUpper = estadoRaw.toUpperCase();
                  final estadoLabel = _serviceStateLabel(estadoRaw);
                  final negotiationRaw = (s['estadoNegociacion'] ?? s['negociacionEstado'] ?? '').toString();
                  final negotiationUpper = negotiationRaw.toUpperCase();
                  final negotiationLabel = negotiationRaw.isEmpty ? '' : _negotiationStateLabel(negotiationRaw);
                  final negotiationOpen = negotiationUpper == 'EN_NEGOCIACION';
                  final bool canOffer = estadoUpper == 'PENDIENTE' && !negotiationOpen;
                  final fechaRaw = s['fechaEstimada'] ?? s['fecha'];
                  final fecha = _parseServiceDate(fechaRaw);
                  final fechaTxt = fecha != null
                      ? '${fecha.day.toString().padLeft(2,'0')}/${fecha.month.toString().padLeft(2,'0')}/${fecha.year}'
                      : '';
                  final int? serviceId = () {
                    final v = s['id'];
                    if (v == null) return null;
                    if (v is int) return v;
                    return int.tryParse(v.toString());
                  }();

                  Color statusColor = Colors.orange;
                  switch (estadoUpper) {
                    case 'ASIGNADO':
                    case 'EN_PROCESO':
                    case 'EN_CURSO':
                      statusColor = Colors.blue; break;
                    case 'FINALIZADO':
                      statusColor = Colors.green; break;
                    case 'CANCELADO':
                      statusColor = Colors.red; break;
                    case 'PENDIENTE_PAGO':
                      statusColor = Colors.amber.shade800; break;
                    default:
                      statusColor = Colors.orange; break;
                  }

                  final details = <String>[
                    if (ubicacion.isNotEmpty) ubicacion,
                    if (categoria.isNotEmpty) categoryDisplayLabel(categoria),
                    if (fechaTxt.isNotEmpty) 'Fecha: $fechaTxt',
                    if (negotiationLabel.isNotEmpty) 'Negociacion: $negotiationLabel',
                  ];

                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: serviceId == null || !canOffer
                        ? null
                        : () => _openOfferSheet(serviceId, titulo),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor: _workerPrimary.withOpacity(0.08),
                            child: const Icon(Icons.work_outline, color: _workerPrimary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  titulo.isEmpty ? 'Servicio' : titulo,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                if (details.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(details.join('\n')),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 120, maxWidth: 160),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _statusChip(estadoLabel, statusColor),
                                const SizedBox(height: 6),
                                Tooltip(
                                  message: canOffer
                                      ? 'Enviar una nueva oferta'
                                      : 'Este servicio ya no admite nuevas ofertas',
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: serviceId == null || !canOffer
                                          ? null
                                          : () => _openOfferSheet(serviceId, titulo),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _workerPrimary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        minimumSize: const Size(0, 40),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(24),
                                        ),
                                      ),
                                      child: const Text('Ofertar'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Ver mapa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            SizedBox(height: 8),
            CurrentLocationMap(height: 260),
          ],
        ),
      ),
    );
  }

  bool _requiresPayment(Map<String, dynamic>? info) {
    if (info == null) return false;
    final status = _paymentStatusUpper(
      info['paymentStatus'] ??
          info['payment_state'] ??
          info['payment_status'] ??
          info['status'],
    );
    if (status != 'REQUIRES_ACTION' && status != 'PENDING') return false;
    final intentId = info['paymentIntentId'] ??
        info['payment_intent_id'] ??
        info['paymentIntent'] ??
        info['intentId'];
    final clientSecret = info['paymentClientSecret'] ??
        info['payment_client_secret'] ??
        info['clientSecret'];
    return intentId != null && clientSecret != null;
  }

  Future<void> _openWorkerPaymentCheckout({
    required int offerId,
    int? serviceId,
    Map<String, dynamic>? paymentInfo,
  }) async {
    await showPaymentCheckout(
      context: context,
      offerId: offerId,
      serviceId: serviceId,
      serviceTitle: null,
      initialPaymentInfo: paymentInfo,
      onPaymentSucceeded: () async {
        await _fetchOpportunities();
      },
    );
  }

  String _paymentStatusUpper(dynamic raw) {
    if (raw == null) return '';
    final text = raw.toString().trim();
    if (text.isEmpty) return '';
    return text.toUpperCase();
  }
}

















