import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/account_management_sheet.dart';
import '../widgets/profile_popover.dart';

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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
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

  Widget _buildPlaceholderCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Tus oportunidades',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8),
            Text(
              'Aquí verás las solicitudes de los clientes y podrás responderlas. '
              'Mientras tanto, asegúrate de mantener tu información al día.',
              style: TextStyle(color: Colors.black54),
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
          _buildPlaceholderCard(),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined, color: Colors.black87),
            tooltip: 'Actualizar',
            onPressed: _fetchProfile,
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
      body: _loading && _profile == null
          ? const Center(child: CircularProgressIndicator())
          : body,
    );
  }
}
