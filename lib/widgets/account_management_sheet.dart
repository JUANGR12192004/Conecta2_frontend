import 'package:flutter/material.dart';

import '../services/api_service.dart';

class AccountManagementSheet extends StatefulWidget {
  const AccountManagementSheet({
    super.key,
    required this.userId,
    required this.role,
    this.initialData,
  });

  final int userId;
  final String role; // 'client' | 'worker'
  final Map<String, dynamic>? initialData;

  @override
  State<AccountManagementSheet> createState() => _AccountManagementSheetState();
}

class _AccountManagementSheetState extends State<AccountManagementSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _celularCtrl;
  late final TextEditingController _areaCtrl;
  final TextEditingController _currentPassCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();

  bool _sending = false;
  bool _loadingInitialData = false;
  bool _obscureCurrent = true;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  String _initialNombre = '';
  String _initialCelular = '';
  String _initialArea = '';

  bool get _isWorker => widget.role.toLowerCase() == 'worker';
  bool get _wantsPasswordChange =>
      _passCtrl.text.isNotEmpty || _confirmCtrl.text.isNotEmpty;

  Color get _primary =>
      _isWorker ? const Color(0xFF1E88E5) : const Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _hydrateFrom(widget.initialData);

    _nombreCtrl = TextEditingController(text: _initialNombre);
    _celularCtrl = TextEditingController(text: _initialCelular);
    _areaCtrl = TextEditingController(text: _initialArea);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bool shouldFetch =
          !_isWorker || widget.initialData == null || widget.initialData!.isEmpty;
      if (shouldFetch) _loadInitialData();
    });
  }

  @override
  void didUpdateWidget(covariant AccountManagementSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialData != null && widget.initialData != oldWidget.initialData) {
      setState(() {
        _hydrateFrom(widget.initialData);
        _syncControllersWithInitials();
      });
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _celularCtrl.dispose();
    _areaCtrl.dispose();
    _currentPassCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _hydrateFrom(Map<String, dynamic>? raw) {
    final data = raw ?? {};
    _initialNombre = (data['nombreCompleto'] ?? data['nombre'] ?? '').toString();
    _initialCelular = (data['celular'] ?? data['telefono'] ?? '').toString();
    _initialArea = (data['areaServicio'] ?? data['area'] ?? '').toString();
  }

  void _syncControllersWithInitials() {
    _nombreCtrl.text = _initialNombre;
    _celularCtrl.text = _initialCelular;
    _areaCtrl.text = _initialArea;
  }

  Future<void> _loadInitialData() async {
    setState(() => _loadingInitialData = true);
    try {
      final Map<String, dynamic> data = _isWorker
          ? await ApiService.fetchWorkerById(widget.userId)
          : await ApiService.fetchClientById(widget.userId);
      if (!mounted) return;
      setState(() {
        _hydrateFrom(data);
        _syncControllersWithInitials();
        _loadingInitialData = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingInitialData = false);
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudieron cargar los datos: $message'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final nombre = _nombreCtrl.text.trim();
    final celular = _celularCtrl.text.trim();
    final area = _areaCtrl.text.trim();
    final pass = _passCtrl.text;
    final confirm = _confirmCtrl.text;
    final currentPass = _currentPassCtrl.text;

    String? nombrePayload;
    String? celularPayload;
    String? areaPayload;
    String? passPayload;
    String? confirmPayload;
    String? currentPassPayload;

    if (nombre != _initialNombre) nombrePayload = nombre;
    if (celular != _initialCelular) celularPayload = celular;
    if (_isWorker && area != _initialArea) areaPayload = area;

    if (_wantsPasswordChange) {
      if (pass.isEmpty || confirm.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Completa la nueva contraseña y su confirmación'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (pass != confirm) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Las contraseñas no coinciden'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (currentPass.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes ingresar tu contraseña actual'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      passPayload = pass;
      confirmPayload = confirm;
      currentPassPayload = currentPass;
    }

    if (nombrePayload == null &&
        celularPayload == null &&
        areaPayload == null &&
        passPayload == null &&
        confirmPayload == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay cambios para guardar'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      Map<String, dynamic> updated;
      if (_isWorker) {
        updated = await ApiService.updateWorkerAccount(
          id: widget.userId,
          nombreCompleto: nombrePayload,
          celular: celularPayload,
          areaServicio: areaPayload,
          contrasena: passPayload,
          confirmarContrasena: confirmPayload,
          contrasenaActual: currentPassPayload,
        );
      } else {
        updated = await ApiService.updateClientAccount(
          id: widget.userId,
          nombreCompleto: nombrePayload,
          celular: celularPayload,
          contrasena: passPayload,
          confirmarContrasena: confirmPayload,
          contrasenaActual: currentPassPayload,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      final rawMessage = e.toString().replaceFirst('Exception: ', '').trim();
      final normalized = rawMessage.toLowerCase();
      final bool wrongPassword = normalized.contains('contraseña') &&
          (normalized.contains('actual') ||
              normalized.contains('incorrecta') ||
              normalized.contains('invalida') ||
              normalized.contains('inválida'));
      final displayMessage =
          wrongPassword ? 'Contraseña incorrecta' : 'Error: $rawMessage';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(displayMessage),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final title = _isWorker
        ? 'Gestionar cuenta de trabajador'
        : 'Gestionar cuenta de cliente';

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 50,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Actualiza solo los campos que hayan cambiado. Si deseas cambiar tu contraseña debes confirmarla.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tu correo electrónico es tu identificador y no puede modificarse desde aquí.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 18),
                if (_loadingInitialData) ...[
                  const LinearProgressIndicator(minHeight: 3),
                  const SizedBox(height: 18),
                ],

                TextFormField(
                  controller: _nombreCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Ingresa tu nombre completo';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _celularCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Número de celular',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Ingresa tu número de celular';
                    if (text.length < 7) return 'Número inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                if (_isWorker)
                  Column(
                    children: [
                      TextFormField(
                        controller: _areaCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Área de servicio',
                          prefixIcon: Icon(Icons.build_outlined),
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) {
                            return 'Ingresa tu área de servicio';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),

                TextFormField(
                  controller: _currentPassCtrl,
                  obscureText: _obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Contraseña actual',
                    helperText: 'Requerida para cambiar la contraseña',
                    prefixIcon: const Icon(Icons.lock_person_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureCurrent
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () =>
                          setState(() => _obscureCurrent = !_obscureCurrent),
                    ),
                  ),
                  validator: (value) {
                    if (!_wantsPasswordChange) return null;
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) {
                      return 'Ingresa tu contraseña actual';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscurePass,
                  decoration: InputDecoration(
                    labelText: 'Nueva contraseña (opcional)',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePass ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirmar contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _sending
                            ? null
                            : () => Navigator.of(context).maybePop(),
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
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Guardar cambios'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
