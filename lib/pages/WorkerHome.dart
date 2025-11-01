import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/account_management_sheet.dart';
import '../widgets/profile_popover.dart';
import '../utils/categories.dart';
import '../widgets/current_location_map.dart';

const Color _workerPrimary = Color(0xFF1E88E5);
const Color _workerSecondary = Color(0xFF64B5F6);

class WorkerHome extends StatefulWidget {
  static const String routeName = '/workerHome';

  const WorkerHome({super.key});

  @override
  State<WorkerHome> createState() => _WorkerHomeState();
}

class _WorkerHomeState extends State<WorkerHome> {
  int? _workerId;
  Map<String, dynamic>? _profile;
  bool _loading = false;
  String? _error;
  bool _initialized = false;
  Map<String, dynamic>? _initialArgs;
  // Oportunidades
  List<Map<String, dynamic>> _opportunities = [];
  bool _opLoading = false;
  String? _opError;
  Duration _pollEvery = const Duration(seconds: 20);
  Future<void>? _pollTimer;
  // Notificaciones para trabajador (contraofertas/aceptaciones)
  List<Map<String, dynamic>> _incomingOffers = [];
  bool _inOffersLoading = false;
  String? _inOffersError;
  Duration _offerPollEvery = const Duration(seconds: 15);
  Future<void>? _offerPollTimer;

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
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

  String _initialLetter() {
    final source = _currentName().isNotEmpty ? _currentName() : _currentEmail();
    if (source.isEmpty) return '?';
    return source.trim().substring(0, 1).toUpperCase();
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
      _startPolling();
      _startOfferPolling();
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
      await _fetchOpportunities();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _fetchOpportunities() async {
    final area = _currentArea();
    final categoria = normalizeCategoryValue(area);
    if (categoria.isEmpty) {
      if (mounted) {
        setState(() {
          _opportunities = [];
          _opError = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _opLoading = true;
        _opError = null;
      });
    }

    try {
      final list = await ApiService.getPublicAvailableServices(categoria: categoria);
      if (!mounted) return;
      setState(() {
        _opportunities = list;
        _opLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _opError = e.toString().replaceFirst('Exception: ', '');
        _opLoading = false;
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _inOffersError = e.toString().replaceFirst('Exception: ', '');
        _inOffersLoading = false;
      });
    }
  }

  void _startPolling() {
    _pollTimer = Future.delayed(_pollEvery, () async {
      if (!mounted) return;
      await _fetchOpportunities();
      if (!mounted) return;
      _startPolling();
    });
  }

  void _stopPolling() {
    // Usamos Future.delayed en cadena; al salir de la pantalla, la siguiente
    // llamada a _startPolling no se reencadena debido a mounted=false.
    _pollTimer = null;
  }

  void _startOfferPolling() {
    _offerPollTimer = Future.delayed(_offerPollEvery, () async {
      if (!mounted) return;
      await _fetchIncomingOffers();
      if (!mounted) return;
      _startOfferPolling();
    });
  }

  void _stopOfferPolling() {
    _offerPollTimer = null;
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
    _stopPolling();
    _stopOfferPolling();
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
                                final raw = priceCtrl.text.trim().replaceAll(',', '.');
                                final price = double.tryParse(raw);
                                if (price == null || price <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
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
                                  if (!mounted) return;
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Oferta enviada âœ…'),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: _workerPrimary,
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
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

  Widget _buildPlaceholderCard() { return Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 1, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [Text('Tus oportunidades', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), SizedBox(height: 8), Text('Aquí verás las solicitudes de los clientes y podrás responderlas. Mientras tanto, asegúrate de mantener tu información al día.', style: TextStyle(color: Colors.black54)),],),),); }
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
                  final estado = (s['estado'] ?? 'PENDIENTE').toString();
                  final fechaRaw = (s['fechaEstimada'] ?? s['fecha'] ?? '').toString();
                  DateTime? fecha;
                  try { fecha = DateTime.tryParse(fechaRaw); } catch (_) {}
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
                  switch (estado.toUpperCase()) {
                    case 'ASIGNADO':
                    case 'EN_PROCESO':
                      statusColor = Colors.blue; break;
                    case 'FINALIZADO':
                      statusColor = Colors.green; break;
                    case 'CANCELADO':
                      statusColor = Colors.red; break;
                    default:
                      statusColor = Colors.orange; break;
                  }

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _workerPrimary.withOpacity(0.08),
                      child: const Icon(Icons.work_outline, color: _workerPrimary),
                    ),
                    title: Text(
                      titulo.isEmpty ? 'Servicio' : titulo,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text([
  
                      if (ubicacion.isNotEmpty) ubicacion,
                      if (categoria.isNotEmpty) categoryDisplayLabel(categoria),
                      if (fechaTxt.isNotEmpty) 'Fecha: $fechaTxt',
                    ].join(' • ')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _statusChip(estado, statusColor),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: serviceId == null
                              ? null
                              : () => _openOfferSheet(serviceId, titulo),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _workerPrimary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Ofertar'),
                        ),
                      ],
                    ),
                    onTap: serviceId == null ? null : () => _openOfferSheet(serviceId, titulo),
                  );
                },
              ),
          ],
        ),
      ),
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
          Future<void> respond(int offerId, String action) async {
            try {
              await ApiService.respondOffer(offerId: offerId, action: action);
              setM(() => _incomingOffers.removeWhere((o) => (o['id'] ?? 0) == offerId));
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: ' + e.toString()), behavior: SnackBarBehavior.floating, backgroundColor: Colors.red),
              );
            }
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
                        final estado = (o['estado'] ?? '').toString();
                        final precio = (o['precio'] ?? o['monto'] ?? '').toString();
                        final offerId = () { final v = o['id']; if(v is int) return v; return int.tryParse(v.toString()) ?? 0; }();
                        return ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.campaign_outlined)),
                          title: Text(client),
                          subtitle: Text(['Estado: ' + estado, if (precio.isNotEmpty) 'Precio: ' + precio].join(' • ')),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                tooltip: 'Aceptar',
                                icon: const Icon(Icons.check_circle, color: Colors.green),
                                onPressed: () => respond(offerId, 'ACCEPT'),
                              ),
                              IconButton(
                                tooltip: 'Rechazar',
                                icon: const Icon(Icons.cancel, color: Colors.red),
                                onPressed: () => respond(offerId, 'REJECT'),
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









