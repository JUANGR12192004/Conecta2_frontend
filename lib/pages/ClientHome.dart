// ignore: unused_import
import 'dart:convert';
import 'package:flutter/material.dart';
// TODO: Ajusta esta importación al path real de tu ApiService:
import '../services/api_service.dart';
import '../widgets/account_management_sheet.dart';
import '../widgets/profile_popover.dart';

/// =============================================================
/// ClientHome.dart
/// - Home del Cliente con HU005 y HU006 conectados al backend
/// - UI basada en tu versión original, con lista/tabs/form modal
/// =============================================================

class ClientHome extends StatefulWidget {
  static const String routeName = '/clientHome';

  const ClientHome({super.key});

  @override
  State<ClientHome> createState() => _ClientHomeState();
}

/// Modelo para un servicio publicado (adaptado al backend)
class ServiceItem {
  final int id;
  final String titulo;
  final String descripcion;
  final String categoria;
  final String ubicacion;
  final DateTime fechaEstimada;
  final String estado; // PENDIENTE | EN_PROCESO | FINALIZADO | CANCELADO

  ServiceItem({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.categoria,
    required this.ubicacion,
    required this.fechaEstimada,
    required this.estado,
  });

  factory ServiceItem.fromJson(Map<String, dynamic> j) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return ServiceItem(
      id: int.tryParse((j['id'] ?? '0').toString()) ?? 0,
      titulo: (j['titulo'] ?? '').toString(),
      descripcion: (j['descripcion'] ?? '').toString(),
      categoria: (j['categoria'] ?? '').toString(),
      ubicacion: (j['ubicacion'] ?? '').toString(),
      fechaEstimada: parseDate(j['fechaEstimada']),
      estado: (j['estado'] ?? 'PENDIENTE').toString(),
    );
  }
}

/// Paleta Cliente
const _primary = Color(0xFF2E7D32);
const _secondary = Color(0xFF66BB6A);

class _ClientHomeState extends State<ClientHome>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  /// Lista de servicios disponibles (desde backend)
  List<ServiceItem> _services = [];
  bool _loading = false;
  String? _error;

  /// Datos del perfil del cliente autenticado
  Map<String, dynamic>? _profile;
  bool _profileLoading = false;
  String? _profileError;
  int? _clientId;
  bool _didLoadArgs = false;
  Map<String, dynamic>? _initialArgs;

  /// Categorías disponibles (para validar “existe en opciones”)
  final List<String> _categorias = const [
    'Plomería',
    'Carpintería',
    'Aseo',
    'Electricidad',
    'Pintura',
    'Jardinería',
    'Costura',
    'Cocina',
    'Tecnología',
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _reload();
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

  String _currentName() =>
      _stringFromSources(['nombreCompleto', 'nombre', 'fullName']);
  String _currentEmail() =>
      _stringFromSources(['correo', 'email', 'correoElectronico']);
  String _currentPhone() =>
      _stringFromSources(['celular', 'telefono', 'phone']);

  String _initialLetter() {
    final source = _currentName().isNotEmpty ? _currentName() : _currentEmail();
    if (source.isEmpty) return '?';
    return source.trim().substring(0, 1).toUpperCase();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadArgs) return;
    _didLoadArgs = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _initialArgs = Map<String, dynamic>.from(
        args.map((key, value) => MapEntry(key.toString(), value)),
      );
      _clientId = _asInt(args["userId"] ?? args["id"]);
      final profileArg = args["profile"];
      if (profileArg is Map<String, dynamic>) {
        _profile = Map<String, dynamic>.from(profileArg);
      } else if (profileArg is Map) {
        _profile = profileArg.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    }

    if (_clientId != null) {
      _refreshProfile();
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _refreshProfile() async {
    final id = _clientId;
    if (id == null) return;

    setState(() {
      _profileLoading = true;
      _profileError = null;
    });

    try {
      final data = await ApiService.fetchClientById(id);
      if (!mounted) return;
      setState(() {
        _profile = data;
        _profileLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _profileError = e.toString().replaceFirst('Exception: ', '');
        _profileLoading = false;
      });
    }
  }

  Future<void> _openAccountManager() async {
    final id = _clientId;
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
        role: 'client',
        initialData: _profile,
      ),
    );

    if (updated != null && mounted) {
      setState(() => _profile = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Datos de cuenta actualizados'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _primary,
        ),
      );
      await _refreshProfile();
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
      builder: (_) => ProfilePopover(
        name: name,
        email: email.isNotEmpty ? email : 'Mi cuenta',
        initialLetter: _initialLetter(),
        accentColor: _primary,
      ),
    );

    if (result == 'manage') {
      await _openAccountManager();
    } else if (result == 'logout') {
      await _logout();
    }
  }

  Widget _buildProfileCard() {
    final nombre = _currentName();
    final correo = _currentEmail();
    final celular = _currentPhone();

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      elevation: 0,
      color: Colors.grey[100],
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _primary.withOpacity(0.12),
          child: const Icon(Icons.person_outline, color: _primary),
        ),
        title: Text(
          nombre.isEmpty ? 'Mi cuenta' : nombre,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (correo.isNotEmpty) Text(correo),
            if (celular.isNotEmpty) Text(celular),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.manage_accounts_outlined, color: _primary),
          tooltip: 'Editar cuenta',
          onPressed: _openAccountManager,
        ),
      ),
    );
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiService.getServices();
      setState(() {
        _services = list.map((m) => ServiceItem.fromJson(m)).toList();
        _loading = false;
      });
    } catch (e) {
      final msg = e.toString();
      setState(() {
        _error = msg;
        _loading = false;
      });
      if (mounted && msg.toLowerCase().contains("no autorizado")) {
        _snack("Sesión expirada. Vuelve a iniciar sesión.");
        await _logout();
      }
    }
  }

  /// Abre el formulario de publicación (HU005)
  void _openPublishForm() async {
    final created = await showModalBottomSheet<ServiceItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _PublishServiceForm(categorias: _categorias),
      ),
    );

    if (created != null) {
      // Refrescamos desde backend para mantener consistencia
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Servicio publicado con éxito'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _primary,
        ),
      );
      _tab.animateTo(0);
    }
  }

  /// Editar servicio (HU006)
  Future<void> _openEditSheet(ServiceItem s) async {
    if (s.estado != "PENDIENTE") {
      _snack("Solo los servicios PENDIENTES pueden editarse.");
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _EditServiceForm(categorias: _categorias, item: s),
      ),
    );

    // Tras cerrar (guardar/cancelar), recargar lista
    _reload();
  }

  /// Eliminar servicio (HU006)
  Future<void> _confirmDelete(ServiceItem s) async {
    if (s.estado != "PENDIENTE") {
      _snack("Solo los servicios PENDIENTES pueden eliminarse.");
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirmar eliminación"),
        content: Text(
          '¿Eliminar el servicio "${s.titulo}"?\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await ApiService.deleteService(s.id);
        _snack("Servicio eliminado ✅", success: true);
        _reload();
      } catch (e) {
        _snack("Error al eliminar: $e");
      }
    }
  }

  void _snack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: success ? _primary : Colors.red,
      ),
    );
  }

  Color _statusColor(String estado) {
    switch (estado.toUpperCase()) {
      case "PENDIENTE":
        return Colors.orange;
      case "EN_PROCESO":
        return Colors.blue;
      case "FINALIZADO":
        return Colors.green;
      case "CANCELADO":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildProfileAvatar() {
    final letter = _initialLetter();
    return CircleAvatar(
      radius: 18,
      backgroundColor: _primary,
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  void _showComingSoon() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Esta sección estará disponible próximamente.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        // Esquina superior izquierda: Publicar servicio (HU005)
        leading: IconButton(
          icon: const Icon(Icons.add_circle_outline, color: _primary),
          tooltip: 'Publicar servicio',
          onPressed: _openPublishForm,
        ),
        title: const Text(
          'Conecta2',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_outlined,
              color: Colors.black87,
            ),
            tooltip: 'Notificaciones',
            onPressed: _showComingSoon,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: GestureDetector(
              onTap: _showProfileMenu,
              child: _buildProfileAvatar(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_profileLoading) const LinearProgressIndicator(minHeight: 2),
          if (_profile != null) _buildProfileCard(),
          if (_profileError != null && _profile == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Material(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  leading: const Icon(Icons.error_outline, color: Colors.red),
                  title: Text(
                    '$_profileError',
                    style: const TextStyle(color: Colors.red),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.red),
                    tooltip: 'Reintentar',
                    onPressed: _clientId != null ? _refreshProfile : null,
                  ),
                ),
              ),
            ),
          Container(
            margin: const EdgeInsets.all(16),
            child: TabBar(
              controller: _tab,
              indicator: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(30),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.black87,
              tabs: const [
                Tab(text: 'Mis servicios'),
                Tab(text: 'Ver mapa'),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                // AVAILABLE: lista de servicios publicados
                _buildAvailable(),
                // VIEW ON MAP: placeholder
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_outlined, size: 64, color: Colors.black38),
                      SizedBox(height: 8),
                      Text(
                        'Vista de Mapa en construcción🔧...',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailable() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Error cargando servicios:\n$_error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }
    if (_services.isEmpty) {
      return const Center(
        child: Text(
          'Aún no hay servicios publicados',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, i) {
          final s = _services[i];
          return Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _secondary.withOpacity(.15),
                child: const Icon(
                  Icons.home_repair_service_rounded,
                  color: _primary,
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.titulo,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Chip(
                    label: Text(s.estado),
                    backgroundColor: _statusColor(s.estado).withOpacity(0.1),
                    labelStyle: TextStyle(
                      color: _statusColor(s.estado),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                '${s.ubicacion} • ${s.categoria}\nFecha: ${_fmtDate(s.fechaEstimada)}',
              ),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (value) {
                  if (value == 'editar') {
                    _openEditSheet(s);
                  } else if (value == 'eliminar') {
                    _confirmDelete(s);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'editar',
                    child: ListTile(
                      leading: Icon(Icons.edit, color: Colors.black87),
                      title: Text('Editar'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'eliminar',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline, color: Colors.red),
                      title: Text('Eliminar'),
                    ),
                  ),
                ],
              ),
              onTap: () {
                // Aquí podrías navegar a un detalle
              },
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemCount: _services.length,
      ),
    );
  }
}

String _fmtDate(DateTime d) {
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';
}

/// ===============================
/// FORMULARIO DE PUBLICACIÓN (HU005) -> hace POST al backend
/// ===============================
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
    final initial = _fecha ?? now.add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
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

    // Validaciones de UI
    if (!_formKey.currentState!.validate()) return;

    // HU005: validación fecha >= hoy
    final today = DateTime.now();
    final todayAt0 = DateTime(today.year, today.month, today.day);
    if (_fecha == null || _fecha!.isBefore(todayAt0)) {
      _snack('La fecha estimada no puede ser anterior al día actual.');
      return;
    }

    // Validación: categoría existe
    if (_categoria == null ||
        !widget.categorias
            .map((e) => e.toLowerCase())
            .contains(_categoria!.toLowerCase())) {
      _snack('La categoría seleccionada no es válida.');
      return;
    }

    setState(() => _sending = true);
    try {
      final resp = await ApiService.createService(
        titulo: _tituloCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim(),
        categoria: _categoria!,
        ubicacion: _ubicacionCtrl.text.trim(),
        fechaEstimada: _fecha!,
      );

      // Convertimos respuesta a ServiceItem (por si backend devuelve el creado)
      final created = ServiceItem.fromJson(resp);

      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (e) {
      _snack('Error al publicar: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ).copyWith(top: 16, bottom: 22),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
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
              const Text(
                'Publicación de servicios',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),

              // TÍTULO
              TextFormField(
                controller: _tituloCtrl,
                decoration: const InputDecoration(
                  labelText: 'Título *',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'El título no debe estar vacío'
                    : null,
              ),
              const SizedBox(height: 12),

              // DESCRIPCIÓN
              TextFormField(
                controller: _descripcionCtrl,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Descripción *',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'La descripción no debe estar vacía'
                    : null,
              ),
              const SizedBox(height: 12),

              // CATEGORÍA
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Categoría *',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                value: _categoria,
                items: widget.categorias
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _categoria = v),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Selecciona una categoría'
                    : null,
              ),
              const SizedBox(height: 12),

              // UBICACIÓN
              TextFormField(
                controller: _ubicacionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ubicación *',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'La ubicación es obligatoria'
                    : null,
              ),
              const SizedBox(height: 12),

              // FECHA ESTIMADA
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha estimada *',
                    prefixIcon: Icon(Icons.event_outlined),
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _fecha == null
                            ? 'Selecciona una fecha'
                            : _fmtDate(_fecha!),
                        style: TextStyle(
                          color: _fecha == null
                              ? Colors.black45
                              : Colors.black87,
                        ),
                      ),
                      const Icon(Icons.calendar_today, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // BOTONES
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _sending ? null : () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _sending ? null : _submit,
                      child: _sending
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Publicar'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '* Campos obligatorios',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ===============================
/// FORMULARIO DE EDICIÓN (HU006) -> hace PUT al backend
/// ===============================
class _EditServiceForm extends StatefulWidget {
  final List<String> categorias;
  final ServiceItem item;

  const _EditServiceForm({required this.categorias, required this.item});

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
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _tituloCtrl = TextEditingController(text: widget.item.titulo);
    _descripcionCtrl = TextEditingController(text: widget.item.descripcion);
    _ubicacionCtrl = TextEditingController(text: widget.item.ubicacion);
    _categoria = widget.item.categoria;
    _fecha = widget.item.fechaEstimada;
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
    final initial = _fecha ?? now.add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
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
      _snack('La fecha estimada no puede ser anterior al día actual.');
      return;
    }

    if (_categoria == null ||
        !widget.categorias
            .map((e) => e.toLowerCase())
            .contains(_categoria!.toLowerCase())) {
      _snack('La categoría seleccionada no es válida.');
      return;
    }

    setState(() => _sending = true);
    try {
      await ApiService.updateService(
        id: widget.item.id,
        titulo: _tituloCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim(),
        categoria: _categoria!,
        ubicacion: _ubicacionCtrl.text.trim(),
        fechaEstimada: _fecha!,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // cerramos la hoja
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Servicio actualizado'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _primary,
        ),
      );
    } catch (e) {
      _snack('Error al actualizar: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ).copyWith(top: 16, bottom: 22),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
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
              const Text(
                'Editar servicio',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),

              // TÍTULO
              TextFormField(
                controller: _tituloCtrl,
                decoration: const InputDecoration(
                  labelText: 'Título *',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'El título no debe estar vacío'
                    : null,
              ),
              const SizedBox(height: 12),

              // DESCRIPCIÓN
              TextFormField(
                controller: _descripcionCtrl,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Descripción *',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'La descripción no debe estar vacía'
                    : null,
              ),
              const SizedBox(height: 12),

              // CATEGORÍA
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Categoría *',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                value: _categoria,
                items: widget.categorias
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _categoria = v),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Selecciona una categoría'
                    : null,
              ),
              const SizedBox(height: 12),

              // UBICACIÓN
              TextFormField(
                controller: _ubicacionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ubicación *',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'La ubicación es obligatoria'
                    : null,
              ),
              const SizedBox(height: 12),

              // FECHA ESTIMADA
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha estimada *',
                    prefixIcon: Icon(Icons.event_outlined),
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _fecha == null
                            ? 'Selecciona una fecha'
                            : _fmtDate(_fecha!),
                        style: TextStyle(
                          color: _fecha == null
                              ? Colors.black45
                              : Colors.black87,
                        ),
                      ),
                      const Icon(Icons.calendar_today, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // BOTONES
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _sending ? null : () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _sending ? null : _submit,
                      child: _sending
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Guardar'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '* Campos obligatorios',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
