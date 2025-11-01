import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class ApiService {
  // ==========================
  // BASE URL
  // ==========================
  static String host = kIsWeb
      ? "http://localhost:8080"
      : "http://localhost:8080";

  static String get _apiPrefix => "/api/v1";
  static Uri _u(String path, {Map<String, String>? query}) =>
      Uri.parse("$host$_apiPrefix$path").replace(queryParameters: query);

  /// Construye URIs fuera de `/api/v1` (compatibilidad con rutas legacy).
  static Uri _absolute(String path, {Map<String, String>? query}) =>
      Uri.parse("$host$path").replace(queryParameters: query);

  // ==========================
  // JWT EN MEMORIA
  // ==========================
  static String? _jwtWorker;
  static String? _jwtClient;
  static String? get workerToken => _jwtWorker;
  static String? get clientToken => _jwtClient;
  static void setWorkerToken(String? t) => _jwtWorker = t;
  static void setClientToken(String? t) => _jwtClient = t;
  static void clearToken() { _jwtWorker = null; _jwtClient = null; }

  // ==========================
  // HEADERS
  // ==========================
  static Map<String, String> _jsonHeaders({bool auth = false, String? role}) {
    final h = <String, String>{"Content-Type": "application/json"};
    if (auth) {
      String? token;
      if (role == 'worker') {
        token = _jwtWorker;
      } else if (role == 'client') {
        token = _jwtClient;
      } else {
        // fallback por compatibilidad; intenta cliente y luego trabajador
        token = _jwtClient ?? _jwtWorker;
      }
      if (token != null) h["Authorization"] = "Bearer $token";
    }
    return h;
  }

  // ==========================
  // TRABAJADORES
  // ==========================
  static Future<Map<String, dynamic>> registerWorker({
    required String nombreCompleto,
    required String correo,
    required String celular,
    required String areaServicio,
    required String contrasena,
    required String confirmarContrasena,
  }) async {
    final res = await http
        .post(
          _u("/auth/workers/register"),
          headers: _jsonHeaders(),
          body: jsonEncode({
            "nombreCompleto": nombreCompleto,
            "correo": correo,
            "celular": celular,
            "areaServicio": areaServicio,
            "contrasena": contrasena,
            "confirmarContrasena": confirmarContrasena,
          }),
        )
        .timeout(const Duration(seconds: 15));
    return _processResponse(res, "registro de trabajador");
  }

  static Future<Map<String, dynamic>> loginWorker({
    required String correo,
    required String contrasena,
  }) async {
    // No limpiar tokens del otro rol; permite sesiones separadas
    final res = await http
        .post(
          _u("/auth/login"),
          headers: _jsonHeaders(),
          body: jsonEncode({"email": correo, "password": contrasena}),
        )
        .timeout(const Duration(seconds: 15));

    final data = _processResponse(res, "login de trabajador");
    if (data["token"] is String) setWorkerToken(data["token"]);
    return data;
  }

  static Future<Map<String, dynamic>> verifyAccount(
    String activationToken,
  ) async {
    final res = await http
        .get(
          _u("/auth/verify", query: {"token": activationToken}),
          headers: _jsonHeaders(),
        )
        .timeout(const Duration(seconds: 15));
    return _processResponse(res, "verificación de cuenta");
  }

  static Future<Map<String, dynamic>> resendActivation(String email) async {
    final res = await http
        .post(
          _u("/auth/resend-activation"),
          headers: _jsonHeaders(),
          body: jsonEncode({"email": email}),
        )
        .timeout(const Duration(seconds: 15));
    return _processResponse(res, "reenviar activación");
  }

  // ==========================
  // TRABAJADORES - GESTIÓN CUENTA
  // ==========================

  static Future<Map<String, dynamic>> fetchWorkerById(int id) async {
    final res = await http
        .get(
          _absolute("/api/Trabajadores/$id"),
          headers: _jsonHeaders(auth: true, role: 'worker'),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw Exception("Formato inesperado al consultar trabajador.");
    }
    if (res.statusCode == 404) {
      throw Exception("Trabajador no encontrado (404).");
    }
    throw Exception(
      "Error consultando trabajador (${res.statusCode}): ${res.body}",
    );
  }

  static Future<Map<String, dynamic>> updateWorkerAccount({
    required int id,
    String? nombreCompleto,
    String? correo,
    String? celular,
    String? areaServicio,
    String? contrasena,
    String? confirmarContrasena,
  }) async {
    final payload = <String, dynamic>{
      if (nombreCompleto != null) "nombreCompleto": nombreCompleto,
      if (correo != null) "correo": correo,
      if (celular != null) "celular": celular,
      if (areaServicio != null) "areaServicio": areaServicio,
    };

    final bool wantsPasswordChange =
        (contrasena != null && contrasena.isNotEmpty) ||
        (confirmarContrasena != null && confirmarContrasena.isNotEmpty);

    if (wantsPasswordChange) {
      if (contrasena == null || confirmarContrasena == null) {
        throw Exception(
          "Debes ingresar la nueva contraseña y su confirmación.",
        );
      }
      payload["contrasena"] = contrasena;
      payload["confirmarContrasena"] = confirmarContrasena;
    }

    if (payload.isEmpty) {
      throw Exception("No hay cambios para actualizar.");
    }

    final res = await http
        .put(
          _absolute("/api/Trabajadores/$id"),
          headers: _jsonHeaders(auth: true, role: 'worker'),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));

    return _processResponse(res, "actualización de trabajador");
  }

  // ==========================
  // CLIENTES
  // ==========================
  static Future<Map<String, dynamic>> registerClient({
    required String nombreCompleto,
    required String correo,
    required String celular,
    required String contrasena,
    required String confirmarContrasena,
  }) async {
    final res = await http
        .post(
          _u("/auth/clients/register"),
          headers: _jsonHeaders(),
          body: jsonEncode({
            "nombreCompleto": nombreCompleto,
            "correo": correo,
            "celular": celular,
            "contrasena": contrasena,
            "confirmarContrasena": confirmarContrasena,
          }),
        )
        .timeout(const Duration(seconds: 15));
    return _processResponse(res, "registro de cliente");
  }

  static Future<Map<String, dynamic>> loginClient({
    required String correo,
    required String contrasena,
  }) async {
    // No limpiar tokens del otro rol; permite sesiones separadas
    final res = await http
        .post(
          _u("/auth/clients/login"),
          headers: _jsonHeaders(),
          body: jsonEncode({"email": correo, "password": contrasena}),
        )
        .timeout(const Duration(seconds: 15));

    final data = _processResponse(res, "login de cliente");
    if (data["token"] is String) setClientToken(data["token"]);
    return data;
  }

  static Future<Map<String, dynamic>> verifyClientAccount(
    String activationToken,
  ) async {
    final res = await http
        .get(
          _u("/auth/clients/verify", query: {"token": activationToken}),
          headers: _jsonHeaders(),
        )
        .timeout(const Duration(seconds: 15));
    return _processResponse(res, "verificación de cuenta");
  }

  // ==========================
  // CLIENTES - GESTIÓN CUENTA
  // ==========================

  static Future<Map<String, dynamic>> fetchClientById(int id) async {
    final res = await http
        .get(_absolute("/api/Clientes/$id"), headers: _jsonHeaders(auth: true, role: 'client'))
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw Exception("Formato inesperado al consultar cliente.");
    }
    if (res.statusCode == 404) {
      throw Exception("Cliente no encontrado (404).");
    }
    throw Exception(
      "Error consultando cliente (${res.statusCode}): ${res.body}",
    );
  }

  static Future<Map<String, dynamic>> updateClientAccount({
    required int id,
    String? nombreCompleto,
    String? correo,
    String? celular,
    String? contrasena,
    String? confirmarContrasena,
  }) async {
    final payload = <String, dynamic>{
      if (nombreCompleto != null) "nombreCompleto": nombreCompleto,
      if (correo != null) "correo": correo,
      if (celular != null) "celular": celular,
    };

    final bool wantsPasswordChange =
        (contrasena != null && contrasena.isNotEmpty) ||
        (confirmarContrasena != null && confirmarContrasena.isNotEmpty);

    if (wantsPasswordChange) {
      if (contrasena == null || confirmarContrasena == null) {
        throw Exception(
          "Debes ingresar la nueva contraseña y su confirmación.",
        );
      }
      payload["contrasena"] = contrasena;
      payload["confirmarContrasena"] = confirmarContrasena;
    }

    if (payload.isEmpty) {
      throw Exception("No hay cambios para actualizar.");
    }

    final res = await http
        .put(
          _absolute("/api/Clientes/$id"),
          headers: _jsonHeaders(auth: true, role: 'client'),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));
    return _processResponse(res, "actualización de cliente");
  }

  // ==========================
  // SERVICIOS (HU005/HU006)
  // ==========================

  /// GET /api/v1/clients/services/public/available (pública)
  static Future<List<Map<String, dynamic>>> getServices() async {
    final res = await http
        .get(_u("/clients/services"), headers: _jsonHeaders(auth: true, role: 'client'))
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      if (decoded is Map && decoded['content'] is List) {
        return (decoded['content'] as List).cast<Map<String, dynamic>>();
      }
      return [];
    }

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception(
        "No autorizado (token requerido). Código: ${res.statusCode}",
      );
    }

    throw Exception(
      "Error listando servicios (${res.statusCode}): ${res.body}",
    );
  }

  /// Lista de servicios publicados disponibles para todos (público).
  /// Opcionalmente se puede filtrar por `categoria` (ENUM del backend).
  static Future<List<Map<String, dynamic>>> getPublicAvailableServices({
    String? categoria,
  }) async {
    final query = <String, String>{};
    if (categoria != null && categoria.trim().isNotEmpty) {
      query['categoria'] = categoria.trim();
    }

    final res = await http
        .get(
          _u("/clients/services/public/available", query: query.isEmpty ? null : query),
          headers: _jsonHeaders(),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) return decoded.cast<Map<String, dynamic>>();
      if (decoded is Map && decoded['content'] is List) {
        return (decoded['content'] as List).cast<Map<String, dynamic>>();
      }
      return [];
    }

    throw Exception(
      "Error listando servicios públicos (${res.statusCode}): ${res.body}",
    );
  }

  // ==========================
  // OFERTAS (Trabajador <-> Cliente)
  // ==========================

  /// Crea una oferta de un trabajador para un servicio publicado.
  /// Endpoint sugerido: POST /api/v1/workers/services/{serviceId}/offers
  static Future<Map<String, dynamic>> createOffer({
    required int serviceId,
    required int workerId,
    required double precio,
    String? mensaje,
  }) async {
    final res = await http
        .post(
          _u("/workers/services/$serviceId/offers"),
          headers: _jsonHeaders(auth: true, role: 'client'),
          body: jsonEncode({
            "workerId": workerId,
            // Backend espera 'monto'. Si tu backend usa 'precio', avísame para revertir.
            "monto": precio,
            if (mensaje != null && mensaje.trim().isNotEmpty) "mensaje": mensaje,
          }),
        )
        .timeout(const Duration(seconds: 15));
    return _processResponse(res, "crear oferta");
  }

  /// Lista ofertas pendientes para un cliente (notificaciones).
  /// Endpoint sugerido: GET /api/v1/clients/{clientId}/offers/pending
  static Future<List<Map<String, dynamic>>> getClientPendingOffers(
      int clientId) async {
    final res = await http
        .get(
          _u("/clients/$clientId/offers/pending"),
          headers: _jsonHeaders(auth: true, role: 'client'),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) return decoded.cast<Map<String, dynamic>>();
      if (decoded is Map && decoded['content'] is List) {
        return (decoded['content'] as List).cast<Map<String, dynamic>>();
      }
      return [];
    }
    throw Exception(
      "Error obteniendo ofertas (${res.statusCode}): ${res.body}",
    );
  }

  /// Lista ofertas pendientes para un trabajador (p. ej. contraofertas).
  /// Endpoint sugerido: GET /api/v1/workers/{workerId}/offers/pending
  static Future<List<Map<String, dynamic>>> getWorkerPendingOffers(
      int workerId) async {
    final res = await http
        .get(
          _u("/workers/$workerId/offers/pending"),
          headers: _jsonHeaders(auth: true, role: 'client'),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) return decoded.cast<Map<String, dynamic>>();
      if (decoded is Map && decoded['content'] is List) {
        return (decoded['content'] as List).cast<Map<String, dynamic>>();
      }
      return [];
    }
    throw Exception(
      "Error obteniendo ofertas (${res.statusCode}): ${res.body}",
    );
  }

  /// Responder a una oferta: ACCEPT | REJECT | COUNTER (con nuevo precio opcional)
  /// Endpoint sugerido: POST /api/v1/offers/{offerId}/respond
  static Future<Map<String, dynamic>> respondOffer({
    required int offerId,
    required String action, // ACCEPT | REJECT | COUNTER
    double? precio,
    String? mensaje,
  }) async {
    final body = <String, dynamic>{
      "action": action.toUpperCase(),
      if (precio != null) "precio": precio,
      if (mensaje != null && mensaje.trim().isNotEmpty) "mensaje": mensaje,
    };

    final res = await http
        .post(
          _u("/offers/$offerId/respond"),
          headers: _jsonHeaders(auth: true, role: 'client'),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    return _processResponse(res, "respuesta de oferta");
  }

  static Future<List<Map<String, dynamic>>> getServicesByClientPublic(
    int clientId,
  ) async {
    final res = await http
        .get(
          _u("/clients/services/public/by-client/$clientId"),
          headers: _jsonHeaders(),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      return [];
    }

    throw Exception(
      "Error listando servicios públicos (${res.statusCode}): ${res.body}",
    );
  }

  /// POST /api/v1/clients/services  (privada)
  static Future<Map<String, dynamic>> createService({
    required String titulo,
    required String descripcion,
    required String categoria, // ENUM del backend (PLOMERIA, etc.)
    required String ubicacion,
    required DateTime fechaEstimada,
  }) async {
    final body = jsonEncode({
      "titulo": titulo,
      "descripcion": descripcion,
      "categoria": categoria,
      "ubicacion": ubicacion,
      "fechaEstimada": fechaEstimada
          .toIso8601String(), // ISO ok para LocalDateTime
    });

    final res = await http
        .post(
          _u("/clients/services"),
          headers: _jsonHeaders(auth: true, role: 'client'),
          body: body,
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 201 || res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {"ok": true, "raw": res.body};
    }

    if (res.statusCode == 403) {
      throw Exception("No autorizado. Verifica el token (403).");
    }
    throw Exception("Error creando servicio (${res.statusCode}): ${res.body}");
  }

  /// PUT /api/v1/clients/services/{id}  (privada)
  static Future<Map<String, dynamic>> updateService({
    required int id,
    required String titulo,
    required String descripcion,
    required String categoria, // ENUM backend
    required String ubicacion,
    required DateTime fechaEstimada,
  }) async {
    final body = jsonEncode({
      "titulo": titulo,
      "descripcion": descripcion,
      "categoria": categoria,
      "ubicacion": ubicacion,
      "fechaEstimada": fechaEstimada.toIso8601String(),
    });

    final res = await http
        .put(
          _u("/clients/services/$id"),
          headers: _jsonHeaders(auth: true, role: 'client'),
          body: body,
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {"ok": true, "raw": res.body};
    }

    if (res.statusCode == 403) {
      throw Exception("No autorizado. Verifica el token (403).");
    }
    throw Exception(
      "Error actualizando servicio (${res.statusCode}): ${res.body}",
    );
  }

  /// DELETE /api/v1/clients/services/{id}  (privada)
  static Future<void> deleteService(int id) async {
    final res = await http
        .delete(_u("/clients/services/$id"), headers: _jsonHeaders(auth: true, role: 'client'))
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 204 || res.statusCode == 200) {
      return;
    }

    if (res.statusCode == 403) {
      throw Exception("No autorizado. Verifica el token (403).");
    }

    throw Exception(
      "Error eliminando servicio (${res.statusCode}): ${res.body}",
    );
  }

  // ==========================================================
  // (Opcional) helpers comunes
  // ==========================================================
  static Map<String, dynamic> _processResponse(
    http.Response response,
    String proceso,
  ) {
    final status = response.statusCode;
    final body = response.body;

    dynamic decoded;
    try {
      decoded = body.isNotEmpty ? jsonDecode(body) : null;
    } catch (_) {
      decoded = null;
    }

    if (status == 200 || status == 201) {
      return (decoded is Map<String, dynamic>)
          ? decoded
          : {"ok": true, "raw": body};
    }
    if (status == 400)
      throw Exception(_msg(decoded, fallback: "Petición inválida ($proceso)"));
    if (status == 401)
      throw Exception(_msg(decoded, fallback: "No autorizado (401)."));
    if (status == 403)
      throw Exception(_msg(decoded, fallback: "Prohibido (403)."));
    if (status >= 500) throw Exception("Error del servidor ($status): $body");
    throw Exception(_msg(decoded, fallback: "Error en $proceso: $body"));
  }

  static String _msg(dynamic decoded, {required String fallback}) {
    if (decoded is Map && decoded["mensaje"] is String)
      return decoded["mensaje"];
    if (decoded is Map && decoded["message"] is String)
      return decoded["message"];
    return fallback;
  }
}


