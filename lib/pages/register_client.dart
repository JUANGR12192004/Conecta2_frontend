import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Página de registro para CLIENTE con el mismo estilo/UX que RegisterWorker
class RegisterClientPage extends StatefulWidget {
  const RegisterClientPage({super.key});

  @override
  State<RegisterClientPage> createState() => _RegisterClientPageState();
}

class _RegisterClientPageState extends State<RegisterClientPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _termsAccepted = false;
  bool _loading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  // Errores específicos por campo devueltos por el backend
  Map<String, String> fieldErrors = {};

  // Cambia host si ejecutas en emulador Android (10.0.2.2) o IP de tu PC
  final String baseHost = "http://localhost:8080";
  String get registerUrl => "$baseHost/api/v1/auth/clients/register";

  void _showSnack(String message, {Color? background}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: background ?? Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _clearFieldErrors() => setState(() => fieldErrors = {});

  // Muestra error específico bajo cada TextFormField
  Widget _fieldError(String key) {
    final msg = fieldErrors[key];
    if (msg == null || msg.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6.0, left: 6.0),
      child: Text(msg, style: const TextStyle(color: Colors.red, fontSize: 12)),
    );
  }

  Future<void> _register() async {
    _clearFieldErrors();

    // Validaciones locales
    if (!_formKey.currentState!.validate()) return;
    if (!_termsAccepted) {
      _showSnack("Debes aceptar los términos y condiciones.");
      return;
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      _showSnack("Las contraseñas no coinciden.");
      return;
    }

    setState(() => _loading = true);

    final payload = {
      "nombreCompleto": _nameCtrl.text.trim(),
      "correo": _emailCtrl.text.trim(),
      "contrasena": _passCtrl.text,
      "confirmarContrasena": _confirmCtrl.text, // 👈 Importante para evitar 400
      "celular": _phoneCtrl.text.trim(),
    };

    try {
      final uri = Uri.parse(registerUrl);
      final response = await http
          .post(uri, headers: {"Content-Type": "application/json"}, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Esperamos respuesta como { id, mensaje: "...Revisa tu correo..." }
        String msg = "Registro recibido. Revisa tu correo para activar la cuenta.";
        try {
          final Map<String, dynamic> data = jsonDecode(response.body);
          if (data["mensaje"] is String) msg = data["mensaje"];
        } catch (_) {}

        _showSnack(msg, background: Colors.green);

        // Pequeño delay para que el usuario vea el mensaje
        await Future.delayed(const Duration(milliseconds: 900));
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, "/login", arguments: {"role": "client"});
        return;
      }

      // Manejo de errores genérico (mensaje + errores por campo)
      final content = response.body;
      dynamic decoded;
      try {
        decoded = jsonDecode(content);
      } catch (_) {
        decoded = null;
      }

      // Si el backend devolvió {errores: ["campo: mensaje", ...]}
      if (decoded is Map && decoded.containsKey("errores")) {
        final List<dynamic> errores = decoded["errores"];
        final Map<String, String> parsed = {};
        for (var e in errores) {
          if (e is String && e.contains(":")) {
            final parts = e.split(":");
            final key = parts[0].trim();
            final msg = parts.sublist(1).join(":").trim();
            parsed[key] = msg;
          } else if (e is String) {
            _showSnack(e);
          }
        }
        setState(() => fieldErrors = parsed);
        if (decoded.containsKey("mensaje")) {
          _showSnack(decoded["mensaje"]);
        }
        return;
      }

      if (decoded is Map && decoded.containsKey("mensaje")) {
        _showSnack(decoded["mensaje"]);
        return;
      }

      if (content.isNotEmpty) {
        _showSnack(content);
        return;
      }

      _showSnack("Error desconocido: ${response.statusCode}");
    } on http.ClientException catch (e) {
      _showSnack("Error de conexión: ${e.message}");
    } on Exception catch (e) {
      _showSnack("Ocurrió un error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Paleta para CLIENTE (verde)
    const Color primary = Color(0xFF2E7D32);
    const Color secondary = Color(0xFF66BB6A);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
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
                constraints: const BoxConstraints(maxWidth: 520),
                child: Card(
                  elevation: 10,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          const Icon(Icons.person, size: 56, color: primary),
                          const SizedBox(height: 12),
                          const Text(
                            "Registro de Cliente",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 24),

                          // Nombre completo
                          TextFormField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: "Nombre completo",
                              prefixIcon: Icon(Icons.person),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? "Ingresa tu nombre" : null,
                          ),
                          _fieldError("nombreCompleto"),
                          const SizedBox(height: 14),

                          // Correo
                          TextFormField(
                            controller: _emailCtrl,
                            decoration: const InputDecoration(
                              labelText: "Correo electrónico",
                              prefixIcon: Icon(Icons.email),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return "Ingresa tu correo";
                              final rx = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                              if (!rx.hasMatch(v.trim())) return "Correo inválido";
                              return null;
                            },
                          ),
                          _fieldError("correo"),
                          const SizedBox(height: 14),

                          // Contraseña
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _obscurePass,
                            decoration: InputDecoration(
                              labelText: "Contraseña",
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscurePass = !_obscurePass),
                                icon: Icon(_obscurePass ? Icons.visibility : Icons.visibility_off),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return "Ingresa tu contraseña";
                              if (v.length < 8) return "La contraseña debe tener al menos 8 caracteres";
                              final rx = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&]).+$');
                              if (!rx.hasMatch(v)) {
                                return "Debe incluir mayúsculas, minúsculas, números y un carácter especial";
                              }
                              return null;
                            },
                          ),
                          _fieldError("contrasena"),
                          const SizedBox(height: 14),

                          // Confirmar contraseña
                          TextFormField(
                            controller: _confirmCtrl,
                            obscureText: _obscureConfirm,
                            decoration: InputDecoration(
                              labelText: "Confirmar contraseña",
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return "Confirma tu contraseña";
                              if (v != _passCtrl.text) return "Las contraseñas no coinciden";
                              return null;
                            },
                          ),
                          _fieldError("confirmarContrasena"),
                          const SizedBox(height: 14),

                          // Número de celular
                          TextFormField(
                            controller: _phoneCtrl,
                            decoration: const InputDecoration(
                              labelText: "Número de celular",
                              prefixIcon: Icon(Icons.phone),
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? "Ingresa tu número de celular" : null,
                          ),
                          _fieldError("celular"),
                          const SizedBox(height: 10),

                          // Términos
                          Row(
                            children: [
                              Checkbox(
                                value: _termsAccepted,
                                onChanged: (v) => setState(() => _termsAccepted = v ?? false),
                              ),
                              const Expanded(
                                child: Text("Acepto términos y condiciones"),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Botón registrarse
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _register,
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
                                  : const Text("Registrarse"),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Ya tengo cuenta → login (modo client)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _loading
                                  ? null
                                  : () => Navigator.pushReplacementNamed(
                                        context,
                                        "/login",
                                        arguments: {"role": "client"},
                                      ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text("Ya tengo cuenta"),
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Volver al inicio (selector de rol)
                          TextButton(
                            onPressed: () => Navigator.pushNamedAndRemoveUntil(context, "/", (r) => false),
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
