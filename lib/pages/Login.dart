import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _obscure = true;
  late String _role; // "worker" | "client"

  // 🔹 Token en memoria (TRABAJADOR)
  String? _accessToken;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final raw = (args?['role'] as String?)?.toLowerCase().trim();
    _role = (raw == 'worker' || raw == 'client') ? raw! : 'client'; // default
  }

  Color get primary =>
      _role == 'worker' ? const Color(0xFF1E88E5) : const Color(0xFF2E7D32);
  Color get secondary =>
      _role == 'worker' ? const Color(0xFF64B5F6) : const Color(0xFF66BB6A);

  String get title => _role == 'worker'
      ? "Inicia sesión como Trabajador"
      : "Inicia sesión como Cliente";

  int? _extractUserId(Map<String, dynamic> payload) {
    const candidates = [
      'id',
      'userId',
      'usuarioId',
      'clienteId',
      'trabajadorId',
    ];
    for (final key in candidates) {
      final value = payload[key];
      if (value == null) continue;
      if (value is int) return value;
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  // 🔹 Banner para cuenta no verificada
  void _showUnverifiedBanner() {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearMaterialBanners();
    messenger.showMaterialBanner(
      MaterialBanner(
        content: const Text(
          "Tu cuenta no está verificada. Revisa tu correo y activa tu cuenta para poder iniciar sesión.",
        ),
        leading: const Icon(Icons.info_outline),
        backgroundColor: Colors.amber.shade100,
        actions: [
          TextButton(
            onPressed: () => messenger.hideCurrentMaterialBanner(),
            child: const Text("Entendido"),
          ),
        ],
      ),
    );
  }

  Future<void> _doLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      Map<String, dynamic> resp;
      if (_role == 'worker') {
        resp = await ApiService.loginWorker(
          correo: _emailCtrl.text.trim(),
          contrasena: _passwordCtrl.text,
        );

        // 🔹 TOMAR TOKEN de trabajador si viene en la respuesta
        final tok = resp['token'] as String?;
        if (tok != null && tok.isNotEmpty) {
          setState(() => _accessToken = tok);
          // TODO: si deseas persistir: usa flutter_secure_storage
          // final storage = const FlutterSecureStorage();
          // await storage.write(key: 'auth_token', value: tok);
        }
      } else {
        resp = await ApiService.loginClient(
          correo: _emailCtrl.text.trim(),
          contrasena: _passwordCtrl.text,
        );
      }

      if (!mounted) return;
      final nombre = resp['nombreCompleto'] ?? resp['nombre'] ?? '¡Bienvenido!';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Bienvenido $nombre"),
          backgroundColor: primary,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Redireccion segun el rol autenticado
      final route = _role == 'worker' ? '/workerHome' : '/clientHome';
      final args = <String, dynamic>{"role": _role, "profile": resp};
      final userId = _extractUserId(resp);
      if (userId != null) args["userId"] = userId;

      Navigator.pushReplacementNamed(context, route, arguments: args);
    } catch (e) {
      if (!mounted) return;
      // 👇 AQUI: redirige al Home del Cliente

      // 🔹 Detección simple del caso "Cuenta no verificada"
      final msg = e.toString();
      final noVerificada = msg.toLowerCase().contains("no verificada");

      if (noVerificada && _role == 'worker') {
        _showUnverifiedBanner();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goToRegister() {
    if (_role == 'worker') {
      Navigator.pushNamed(context, "/registerWorker");
    } else {
      Navigator.pushNamed(context, "/registerClient");
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primary, secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  elevation: 10,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Icon(
                            _role == 'worker' ? Icons.work : Icons.person,
                            size: 56,
                            color: primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Email
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: "Correo electrónico",
                              prefixIcon: Icon(Icons.email),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return "Ingresa tu correo";
                              }
                              final rx = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                              if (!rx.hasMatch(v.trim())) {
                                return "Correo inválido";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Password
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: "Contraseña",
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? "Ingresa tu contraseña"
                                : null,
                          ),
                          const SizedBox(height: 8),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                // TODO: recuperación de contraseña si aplica
                              },
                              child: const Text("¿Olvidaste tu contraseña?"),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Botón de login
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _doLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                minimumSize: const Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text("Iniciar Sesión"),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Ir a registro según rol
                          TextButton(
                            onPressed: _goToRegister,
                            child: const Text(
                              "¿No tienes cuenta? Regístrate aquí",
                            ),
                          ),

                          // Volver al inicio (selector de rol)
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                "/",
                                (route) => false,
                              );
                            },
                            child: const Text("⬅️ Volver al inicio"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
