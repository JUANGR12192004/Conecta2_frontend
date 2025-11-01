import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/account_management_sheet.dart';
import '../widgets/profile_popover.dart';
import '../utils/categories.dart';
import '../widgets/current_location_map.dart';

const _primary = Color(0xFF2E7D32);

class ClientHome extends StatefulWidget {
  static const String routeName = '/clientHome';
  const ClientHome({super.key});
  @override
  State<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends State<ClientHome> with SingleTickerProviderStateMixin {
  late TabController _tab;

  Map<String, dynamic>? _profile;
  bool _profileLoading = false;
  String? _profileError;
  int? _clientId;
  bool _didLoadArgs = false;
  Map<String, dynamic>? _initialArgs;

  List<Map<String, dynamic>> _services = [];
  bool _loading = false;
  String? _error;

  // Ofertas in-app
  List<Map<String, dynamic>> _offers = [];
  bool _offersLoading = false;
  String? _offersError;
  Duration _offersPollEvery = const Duration(seconds: 15);
  Future<void>? _offersPollTimer;

  final List<String> _categorias = kServiceCategoryLabels.keys.toList();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadArgs) return;
    _didLoadArgs = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _initialArgs = Map<String, dynamic>.from(
        args.map((k, v) => MapEntry(k.toString(), v)),
      );
      _clientId = _asInt(args['userId'] ?? args['id']);
      final profileArg = args['profile'];
      if (profileArg is Map<String, dynamic>) {
        _profile = Map<String, dynamic>.from(profileArg);
      } else if (profileArg is Map) {
        _profile = profileArg.map((k, v) => MapEntry(k.toString(), v));
      }
    }

    if (_clientId != null) {
      _refreshProfile();
      _startOffersPolling();
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    _stopOffersPolling();
    super.dispose();
  }

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

  String _currentName() => _stringFromSources(['nombreCompleto', 'nombre', 'fullName']);
  String _currentEmail() => _stringFromSources(['correo', 'email', 'correoElectronico']);

  Future<void> _reload() async {
    await _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiService.getServices();
      if (!mounted) return;
      setState(() {
        _services = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _refreshProfile() async {
    final id = _clientId;
    if (id == null) return;
    setState(() { _profileLoading = true; _profileError = null; });
    try {
      final data = await ApiService.fetchClientById(id);
      if (!mounted) return;
      setState(() { _profile = data; _profileLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _profileError = e.toString().replaceFirst('Exception: ', ''); _profileLoading = false; });
    }
  }

  // Ofertas
  void _startOffersPolling() {
    _offersPollTimer = Future.delayed(_offersPollEvery, () async {
      if (!mounted) return;
      await _fetchOffers();
      if (!mounted) return;
      _startOffersPolling();
    });
  }

  void _stopOffersPolling() { _offersPollTimer = null; }

  Future<void> _fetchOffers() async {
    final id = _clientId; if (id == null) return;
    setState(() { _offersLoading = true; _offersError = null; });
    try {
      final list = await ApiService.getClientPendingOffers(id);
      if (!mounted) return;
      setState(() { _offers = list; _offersLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _offersError = e.toString().replaceFirst('Exception: ', ''); _offersLoading = false; });
    }
  }

  Future<void> _openNotifications() async {
    await _fetchOffers();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setM) {
          Future<void> doAccept(int id) async {
            try {
              await ApiService.respondOffer(offerId: id, action: 'ACCEPT');
              setM(() => _offers.removeWhere((o) => (o['id'] ?? 0) == id));
              // Refresca lista de servicios para reflejar estado ASIGNADO
              await _loadServices();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Servicio asignado'), behavior: SnackBarBehavior.floating, backgroundColor: _primary),
                );
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating, backgroundColor: Colors.red),
              );
            }
          }

          Future<void> doReject(int id) async {
            try {
              await ApiService.respondOffer(offerId: id, action: 'REJECT');
              setM(() => _offers.removeWhere((o) => (o['id'] ?? 0) == id));
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating, backgroundColor: Colors.red),
              );
            }
          }

          Future<void> doCounter(int id) async {
            final ctrl = TextEditingController();
            final newPrice = await showDialog<double?>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Enviar contraoferta'),
                content: TextField(
                  controller: ctrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Nuevo precio',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                  TextButton(onPressed: () {
                    final raw = ctrl.text.trim().replaceAll(',', '.');
                    final v = double.tryParse(raw);
                    Navigator.pop(context, v);
                  }, child: const Text('Enviar')),
                ],
              ),
            );
            if (newPrice == null || newPrice <= 0) return;
            try {
              await ApiService.respondOffer(offerId: id, action: 'COUNTER', precio: newPrice);
              setM(() => _offers.removeWhere((o) => (o['id'] ?? 0) == id));
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating, backgroundColor: Colors.red),
              );
            }
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8))),
                const SizedBox(height: 12),
                const Text('Notificaciones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (_offersLoading && _offers.isEmpty)
                  const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                else if (_offersError != null)
                  Material(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      leading: const Icon(Icons.error_outline, color: Colors.red),
                      title: Text('$_offersError', style: const TextStyle(color: Colors.red)),
                      trailing: IconButton(icon: const Icon(Icons.refresh, color: Colors.red), onPressed: _fetchOffers),
                    ),
                  )
                else if (_offers.isEmpty)
                  const Padding(padding: EdgeInsets.all(12), child: Text('No tienes ofertas nuevas.', style: TextStyle(color: Colors.black54)))
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _offers.length,
                      separatorBuilder: (_, __) => const Divider(height: 16),
                      itemBuilder: (context, i) {
                        final o = _offers[i];
                        final workerName = (o['workerName'] ?? o['trabajador'] ?? 'Trabajador').toString();
                        final precio = (o['precio'] ?? o['monto'] ?? '').toString();
                        final titulo = (o['serviceTitle'] ?? o['tituloServicio'] ?? '').toString();
                        final offerId = () { final v = o['id']; if (v is int) return v; return int.tryParse(v.toString()) ?? 0; }();
                        return ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.campaign_outlined)),
                          title: Text('$workerName ofertó'),
                          subtitle: Text([
                            if (titulo.isNotEmpty) 'Servicio: $titulo',
                            if (precio.isNotEmpty) 'Precio: $precio',
                          ].join(' • ')),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(tooltip: 'Aceptar', icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: () => doAccept(offerId)),
                              IconButton(tooltip: 'Rechazar', icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => doReject(offerId)),
                              IconButton(tooltip: 'Contraoferta', icon: const Icon(Icons.swap_horiz, color: Colors.orange), onPressed: () => doCounter(offerId)),
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

  Future<void> _openEditForm(int serviceId, Map<String, dynamic> initial) async {
    final updated = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      useSafeArea: true,
      builder: (_) => _EditServiceForm(
        serviceId: serviceId,
        categorias: _categorias,
        initial: initial,
      ),
    );
    if (updated != null) {
      await _loadServices();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servicio actualizado'), behavior: SnackBarBehavior.floating, backgroundColor: _primary),
      );
    }
  }

  Future<void> _confirmDelete(int serviceId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar servicio'),
        content: const Text('¿Seguro que deseas eliminar esta publicación?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.deleteService(serviceId);
      await _loadServices();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servicio eliminado'), behavior: SnackBarBehavior.floating, backgroundColor: Colors.black87),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating, backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _openAccountManager() async {
    final id = _clientId; if (id == null) return;
    final updated = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      useSafeArea: true,
      builder: (_) => AccountManagementSheet(userId: id, role: 'client', initialData: _profile),
    );
    if (updated != null && mounted) {
      setState(() => _profile = updated);
      await _refreshProfile();
    }
  }

  Future<void> _openPublishForm() async {
    final created = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      useSafeArea: true,
      builder: (_) => _PublishServiceForm(categorias: _categorias),
    );
    if (created != null) {
      await _loadServices();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Servicio publicado con éxito'), behavior: SnackBarBehavior.floating, backgroundColor: _primary));
    }
  }

  Future<void> _logout() async {
    ApiService.clearToken();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, "/", (route) => false);
  }

  Future<void> _showProfileMenu() async {
    final email = _currentEmail();
    final name = _currentName();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => ProfilePopover(name: name, email: email.isNotEmpty ? email : 'Mi cuenta', initialLetter: name.isNotEmpty ? name[0].toUpperCase() : '?', accentColor: _primary),
    );
    if (result == 'manage') {
      await _openAccountManager();
    } else if (result == 'logout') {
      await _logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.add_circle_outline, color: _primary),
          tooltip: 'Publicar servicio',
          onPressed: _openPublishForm,
        ),
        title: const Text('Conecta2', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined, color: Colors.black87),
                if (_offers.isNotEmpty)
                  Positioned(
                    right: -2, top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                      child: Text(_offers.length.toString(), style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ),
              ],
            ),
            tooltip: 'Notificaciones',
            onPressed: _openNotifications,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: GestureDetector(onTap: _showProfileMenu, child: CircleAvatar(backgroundColor: _primary, child: Text((_currentName().isNotEmpty ? _currentName()[0] : '?').toUpperCase(), style: const TextStyle(color: Colors.white))))
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadServices,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ...List.generate(_services.length, (i) {
                    final s = _services[i];
                    final titulo = (s['titulo'] ?? '').toString();
                    final categoria = categoryDisplayLabel((s['categoria'] ?? '').toString());
                    final ubicacion = (s['ubicacion'] ?? '').toString();
                    final estado = (s['estado'] ?? 'PENDIENTE').toString();
                    final int? serviceId = () {
                      final v = s['id'];
                      if (v == null) return null;
                      if (v is int) return v;
                      return int.tryParse(v.toString());
                    }();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        color: const Color(0xFFF6F1FF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF7E57C2).withOpacity(0.12),
                            child: const Icon(Icons.work_outline, color: Color(0xFF7E57C2)),
                          ),
                          title: Text(titulo.isEmpty ? 'Servicio' : titulo,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text([
                            if (ubicacion.isNotEmpty) ubicacion,
                            if (categoria.isNotEmpty) categoria,
                            'Estado: $estado',
                          ].join(' • ')),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              () {
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
                                return Chip(
                                  label: Text(estado),
                                  backgroundColor: statusColor.withOpacity(0.1),
                                  labelStyle: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
                                );
                              }(),
                              if (estado.toUpperCase() == 'PENDIENTE' && serviceId != null) ...[
                                const SizedBox(width: 6),
                                PopupMenuButton<String>(
                                  tooltip: 'Opciones',
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _openEditForm(serviceId!, s);
                                    } else if (value == 'delete') {
                                      _confirmDelete(serviceId!);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Editar'))),
                                    const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.red), title: Text('Eliminar'))),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  const Text('Ver mapa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const CurrentLocationMap(height: 260),
                ],
              ),
      ),
    );
  }
}

class _PublishServiceForm extends StatefulWidget {
  final List<String> categorias;
  const _PublishServiceForm({required this.categorias});
  @override
  State<_PublishServiceForm> createState() => _PublishServiceFormState();
}

class _PublishServiceFormState extends State<_PublishServiceForm> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _ubicacionCtrl = TextEditingController();
  String? _categoria;
  DateTime? _fecha;
  bool _sending = false;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _ubicacionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha ?? now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      helpText: 'Selecciona fecha estimada',
      locale: const Locale('es', 'CO'),
    );
    if (picked != null) {
      setState(() => _fecha = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _submit() async {
    if (_sending) return;
    if (!_formKey.currentState!.validate()) return;
    final today = DateTime.now();
    final todayAt0 = DateTime(today.year, today.month, today.day);
    if (_fecha == null || _fecha!.isBefore(todayAt0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La fecha no puede ser anterior a hoy'), behavior: SnackBarBehavior.floating, backgroundColor: Colors.red));
      return;
    }

    final categoriaValue = normalizeCategoryValue(_categoria);
    if (categoriaValue.isEmpty || !widget.categorias.contains(categoriaValue)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Categoría inválida'), behavior: SnackBarBehavior.floating, backgroundColor: Colors.red));
      return;
    }

    setState(() => _sending = true);
    try {
      final resp = await ApiService.createService(
        titulo: _tituloCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim(),
        categoria: categoriaValue,
        ubicacion: _ubicacionCtrl.text.trim(),
        fechaEstimada: _fecha!,
      );
      if (!mounted) return;
      Navigator.pop(context, resp);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al publicar: $e'), behavior: SnackBarBehavior.floating, backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8))),
              const SizedBox(height: 12),
              const Text('Publicación de servicios', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),

              TextFormField(
                controller: _tituloCtrl,
                decoration: const InputDecoration(labelText: 'Título *', prefixIcon: Icon(Icons.title)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'El título no debe estar vacío' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _descripcionCtrl,
                minLines: 3, maxLines: 6,
                decoration: const InputDecoration(labelText: 'Descripción *', prefixIcon: Icon(Icons.description_outlined)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'La descripción no debe estar vacía' : null,
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Categoría *', prefixIcon: Icon(Icons.category_outlined)),
                value: _categoria,
                items: widget.categorias.map((c) => DropdownMenuItem(value: c, child: Text(categoryDisplayLabel(c)))).toList(),
                onChanged: (v) => setState(() => _categoria = v),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Selecciona una categoría' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _ubicacionCtrl,
                decoration: const InputDecoration(labelText: 'Ubicación *', prefixIcon: Icon(Icons.location_on_outlined)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'La ubicación es obligatoria' : null,
              ),
              const SizedBox(height: 12),

              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Fecha estimada *', prefixIcon: Icon(Icons.event_outlined), border: OutlineInputBorder()),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fecha == null ? 'Selecciona una fecha' : _fmtDate(_fecha!)),
                      const Icon(Icons.calendar_today, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: _sending ? null : () => Navigator.pop(context), child: const Text('Cancelar'))),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white), onPressed: _sending ? null : _submit, child: _sending ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Guardar'))),
                ],
              ),
              const SizedBox(height: 4),
              const Align(alignment: Alignment.centerLeft, child: Text('* Campos obligatorios', style: TextStyle(fontSize: 12, color: Colors.black54))),
            ],
          ),
        ),
      ),
    );
  }
}

String _fmtDate(DateTime d) {
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _EditServiceForm extends StatefulWidget {
  final int serviceId;
  final List<String> categorias;
  final Map<String, dynamic> initial;
  const _EditServiceForm({required this.serviceId, required this.categorias, required this.initial});
  @override
  State<_EditServiceForm> createState() => _EditServiceFormState();
}

class _EditServiceFormState extends State<_EditServiceForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tituloCtrl;
  late final TextEditingController _descripcionCtrl;
  late final TextEditingController _ubicacionCtrl;
  String? _categoria;
  DateTime? _fecha;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _tituloCtrl = TextEditingController(text: (init['titulo'] ?? '').toString());
    _descripcionCtrl = TextEditingController(text: (init['descripcion'] ?? '').toString());
    _ubicacionCtrl = TextEditingController(text: (init['ubicacion'] ?? '').toString());
    final rawCat = normalizeCategoryValue((init['categoria'] ?? '').toString());
    _categoria = widget.categorias.contains(rawCat) ? rawCat : null;
    final fechaRaw = (init['fechaEstimada'] ?? init['fecha'] ?? '').toString();
    try { _fecha = DateTime.tryParse(fechaRaw); } catch (_) {}
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _ubicacionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha ?? now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      helpText: 'Selecciona fecha estimada',
      locale: const Locale('es', 'CO'),
    );
    if (picked != null) {
      setState(() => _fecha = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    final today = DateTime.now();
    final todayAt0 = DateTime(today.year, today.month, today.day);
    if (_fecha == null || _fecha!.isBefore(todayAt0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La fecha no puede ser anterior a hoy'), behavior: SnackBarBehavior.floating, backgroundColor: Colors.red));
      return;
    }

    final categoriaValue = normalizeCategoryValue(_categoria);
    if (categoriaValue.isEmpty || !widget.categorias.contains(categoriaValue)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Categoría inválida'), behavior: SnackBarBehavior.floating, backgroundColor: Colors.red));
      return;
    }

    setState(() => _saving = true);
    try {
      final resp = await ApiService.updateService(
        id: widget.serviceId,
        titulo: _tituloCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim(),
        categoria: categoriaValue,
        ubicacion: _ubicacionCtrl.text.trim(),
        fechaEstimada: _fecha!,
      );
      if (!mounted) return;
      Navigator.pop(context, resp);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e'), behavior: SnackBarBehavior.floating, backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8))),
              const SizedBox(height: 12),
              const Text('Editar servicio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),

              TextFormField(
                controller: _tituloCtrl,
                decoration: const InputDecoration(labelText: 'Título *', prefixIcon: Icon(Icons.title)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'El título no debe estar vacío' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _descripcionCtrl,
                minLines: 3, maxLines: 6,
                decoration: const InputDecoration(labelText: 'Descripción *', prefixIcon: Icon(Icons.description_outlined)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'La descripción no debe estar vacía' : null,
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Categoría *', prefixIcon: Icon(Icons.category_outlined)),
                value: _categoria,
                items: widget.categorias.map((c) => DropdownMenuItem(value: c, child: Text(categoryDisplayLabel(c)))).toList(),
                onChanged: (v) => setState(() => _categoria = v),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Selecciona una categoría' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _ubicacionCtrl,
                decoration: const InputDecoration(labelText: 'Ubicación *', prefixIcon: Icon(Icons.location_on_outlined)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'La ubicación es obligatoria' : null,
              ),
              const SizedBox(height: 12),

              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Fecha estimada *', prefixIcon: Icon(Icons.event_outlined), border: OutlineInputBorder()),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fecha == null ? 'Selecciona una fecha' : _fmtDate(_fecha!)),
                      const Icon(Icons.calendar_today, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancelar'))),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white), onPressed: _saving ? null : _submit, child: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Guardar'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
