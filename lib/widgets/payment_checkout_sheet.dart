import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/api_service_payment.dart';

class PaymentCheckoutSheet extends StatefulWidget {
  final int offerId;
  final int? serviceId;
  final String? serviceTitle;
  final Map<String, dynamic>? initialPaymentInfo;
  final ValueChanged<Map<String, dynamic>>? onPaymentInfo;
  final ValueChanged<Map<String, dynamic>>? onPaymentFailed;
  final VoidCallback? onPaymentSucceeded;

  const PaymentCheckoutSheet({
    super.key,
    required this.offerId,
    this.serviceId,
    this.serviceTitle,
    this.initialPaymentInfo,
    this.onPaymentInfo,
    this.onPaymentFailed,
    this.onPaymentSucceeded,
  });

  @override
  State<PaymentCheckoutSheet> createState() => _PaymentCheckoutSheetState();
}

class _PaymentCheckoutSheetState extends State<PaymentCheckoutSheet> {
  Map<String, dynamic>? _paymentInfo;
  bool _loading = true;
  bool _submitting = false;
  bool _polling = false;
  bool _didNotifySuccess = false;
  bool _didNotifyFailure = false;
  String? _error;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _cardCtrl = TextEditingController(text: '4242424242424242');
  final TextEditingController _expCtrl = TextEditingController(text: '12/30');
  final TextEditingController _cvcCtrl = TextEditingController(text: '123');

  @override
  void initState() {
    super.initState();
    if (widget.initialPaymentInfo != null) {
      final initial = Map<String, dynamic>.from(widget.initialPaymentInfo!);
      _paymentInfo = initial;
      _loading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyInfo(initial);
        _fetchInfo(refresh: true);
      });
    } else {
      _fetchInfo();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cardCtrl.dispose();
    _expCtrl.dispose();
    _cvcCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchInfo({bool refresh = false}) async {
    setState(() {
      if (!refresh) {
        _loading = true;
      }
      _error = null;
    });
    try {
      if (refresh) {
        await _refreshIntentStatus();
      } else {
        await _ensureIntent();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _describeError(e);
      });
    }
  }

  void _applyInfo(Map<String, dynamic> info) {
    setState(() {
      _paymentInfo = Map<String, dynamic>.from(info);
      _loading = false;
      _submitting = false;
      _polling = false;
      _error = null;
    });
    widget.onPaymentInfo?.call(_paymentInfo!);
    final status = _statusUpper();
    if (status == 'SUCCEEDED' && !_didNotifySuccess) {
      _didNotifySuccess = true;
      widget.onPaymentSucceeded?.call();
    } else if (status == 'FAILED' && !_didNotifyFailure) {
      _didNotifyFailure = true;
      widget.onPaymentFailed?.call(_paymentInfo!);
    }
  }

  void _requireClientAuth() {
    if (ApiService.clientToken == null) {
      throw Exception('Necesitas iniciar sesión como cliente antes de usar el checkout.');
    }
  }

  String _describeError(Object error) {
    if (error is PaymentGatewayException) {
      try {
        final decoded = error.body.isNotEmpty ? jsonDecode(error.body) : null;
        if (decoded is Map<String, dynamic> && decoded['error'] != null) {
          return decoded['error'].toString();
        }
      } catch (_) {
        // ignore
      }
      final fallback = error.body.isNotEmpty ? error.body : 'Error desconocido';
      return fallback;
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  String _statusUpper() {
    final status = _paymentInfo?['paymentStatus'] ?? _paymentInfo?['status'];
    if (status == null) return '';
    return status.toString().trim().toUpperCase();
  }

  Color _statusColor() {
    switch (_statusUpper()) {
      case 'SUCCEEDED':
        return Colors.green;
      case 'FAILED':
        return Colors.red;
      case 'REQUIRES_ACTION':
        return Colors.deepOrange;
      case 'PENDING':
      default:
        return Colors.orange;
    }
  }

  double? _amount() {
    final value = _paymentInfo?['amount'];
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.'));
    }
    return null;
  }

  String _currency() {
    final currency = _paymentInfo?['currency'] ?? 'COP';
    final text = currency.toString().trim();
    return text.isEmpty ? 'COP' : text;
  }

  String? _intentId() {
    return _paymentInfo?['paymentIntentId']?.toString() ??
        _paymentInfo?['id']?.toString();
  }

  String? _clientSecret() {
    return _paymentInfo?['paymentClientSecret']?.toString() ??
        _paymentInfo?['clientSecret']?.toString();
  }

  bool get _canSubmit {
    if (_paymentInfo == null) return false;
    if (_statusUpper() == 'SUCCEEDED') return false;
    return !_submitting && !_polling;
  }

  Future<void> _confirmPayment() async {
    final intentId = _intentId();
    final clientSecret = _clientSecret();
    if (intentId == null || intentId.isEmpty || clientSecret == null) {
      setState(() {
        _error = 'Aún no hay intent de pago disponible.';
      });
      return;
    }
    _requireClientAuth();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ApiServicePayment.confirmPayment(
        paymentIntentId: intentId,
        paymentMethod: 'pm_card_visa',
      );
      if (!mounted) return;
      await _refreshIntentStatus();
      await _startPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _describeError(e);
        _submitting = false;
      });
    }
  }

  Future<void> _startPolling() async {
    if (_polling) return;
    setState(() => _polling = true);
    for (int i = 0; i < 8 && mounted; i++) {
      await Future.delayed(const Duration(seconds: 3));
      try {
        await _refreshIntentStatus();
        if (!mounted) return;
        final status = _statusUpper();
        if (status == 'SUCCEEDED' || status == 'FAILED') break;
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = _describeError(e);
        });
      }
    }
    if (!mounted) return;
    setState(() => _polling = false);
  }

  Future<void> _ensureIntent() async {
    final intentId = _intentId();
    final secret = _clientSecret();
    _requireClientAuth();
    if (intentId != null && intentId.isNotEmpty && secret != null && secret.isNotEmpty) {
      return;
    }
    await _createIntent();
  }

  Future<void> _refreshIntentStatus() async {
    final intentId = _intentId();
    if (intentId == null || intentId.isEmpty) {
      await _createIntent();
      return;
    }
    _requireClientAuth();
    try {
      final response = await ApiServicePayment.getPaymentStatus(paymentIntentId: intentId);
      await _applyGatewayResponse(response);
    } on PaymentGatewayException catch (e) {
      if (e.statusCode == 404) {
        await _createIntent();
        return;
      }
      rethrow;
    }
  }

  Future<void> _createIntent() async {
    final amountCents = _amountInCents();
    if (amountCents == null || amountCents <= 0) {
      throw Exception('Monto inválido para crear el pago.');
    }
    _requireClientAuth();
    final response = await ApiServicePayment.createIntent(
      amount: amountCents,
      description: _descriptionForIntent(),
      paymentMethodTypes: ['card'],
      metadata: _metadataForIntent(),
    );
    await _applyGatewayResponse(response);
  }

  Future<void> _applyGatewayResponse(Map<String, dynamic> response) async {
    if (response.isEmpty) return;
    final normalized = _normalizeGatewayIntent(response);
    if (normalized.isEmpty) return;
    final merged = <String, dynamic>{...? _paymentInfo, ...normalized};
    if (!mounted) return;
    _applyInfo(merged);
  }

  Map<String, dynamic> _normalizeGatewayIntent(Map<String, dynamic> response) {
    final normalized = <String, dynamic>{};
    final intentValue = response['id'] ?? response['paymentIntentId'];
    final statusValue = response['status'] ?? response['paymentStatus'];
    final secretValue = response['clientSecret'] ?? response['paymentClientSecret'];
    final methodValue = response['paymentMethod'];
    final customerValue = response['customer'];
    final lastErrorValue = response['lastPaymentError'];
    final publishableKey = response['publishableKey'] ?? response['paymentPublishableKey'];
    final amountValue = response['amount'];
    final currencyValue = response['currency'];
    if (intentValue != null) normalized['paymentIntentId'] = intentValue;
    if (statusValue != null) normalized['paymentStatus'] = statusValue;
    if (secretValue != null) normalized['paymentClientSecret'] = secretValue;
    if (methodValue != null) normalized['paymentMethod'] = methodValue;
    if (customerValue != null) normalized['customer'] = customerValue;
    if (lastErrorValue != null) normalized['lastPaymentError'] = lastErrorValue;
    if (publishableKey != null) normalized['paymentPublishableKey'] = publishableKey;
    if (amountValue != null) {
      if (amountValue is num) {
        normalized['amount'] = amountValue / 100;
      } else if (amountValue is String) {
        final parsed = double.tryParse(amountValue);
        if (parsed != null) normalized['amount'] = parsed / 100;
      }
    }
    if (currencyValue != null) normalized['currency'] = currencyValue;
    if (response['metadata'] != null) normalized['metadata'] = response['metadata'];
    return normalized;
  }

  int? _amountInCents() {
    final amount = _amount();
    if (amount == null) return null;
    return (amount * 100).round();
  }

  String _descriptionForIntent() {
    final title = widget.serviceTitle?.trim();
    if (title != null && title.isNotEmpty) {
      return title;
    }
    return 'Servicio en Conecta2';
  }

  Map<String, dynamic> _metadataForIntent() {
    final metadata = <String, dynamic>{
      'offerId': widget.offerId,
      'origin': 'Conecta2-frontend',
    };
    if (widget.serviceId != null) {
      metadata['serviceId'] = widget.serviceId;
    }
    return metadata;
  }

  Widget _buildStatusTile() {
    final status = _statusUpper();
    final color = _statusColor();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.16),
            child: Icon(
              status == 'SUCCEEDED'
                  ? Icons.check
                  : (status == 'FAILED'
                      ? Icons.error_outline
                      : Icons.lock_clock),
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  status == 'SUCCEEDED'
                      ? 'Tu pago fue confirmado por la pasarela.'
                      : status == 'FAILED'
                          ? 'El intento de pago fue rechazado. Revisa los datos o intenta nuevamente.'
                          : 'Ingresa los datos de la tarjeta simulada y presiona "Pagar".',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntentSummary() {
    final amount = _amount();
    final currency = _currency();
    final intent = _intentId() ?? 'Pendiente';
    final secret = _clientSecret();
    final maskedSecret = secret == null
        ? 'Pendiente'
        : secret.length <= 12
            ? secret
            : '${secret.substring(0, 6)}...${secret.substring(secret.length - 4)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (amount != null)
          Text('Monto: ${currency.toUpperCase()} ${amount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
        Text('Intent ID: $intent'),
        Text('Client secret: $maskedSecret'),
      ],
    );
  }

  Widget _buildCardForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Nombre del titular',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _cardCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Número de tarjeta',
            prefixIcon: Icon(Icons.credit_card),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _expCtrl,
                decoration: const InputDecoration(
                  labelText: 'Expiración (MM/AA)',
                  prefixIcon: Icon(Icons.date_range),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _cvcCtrl,
                decoration: const InputDecoration(
                  labelText: 'CVC',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final serviceTitle = widget.serviceTitle?.trim();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              Text(
                'Checkout de pago',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Oferta #${widget.offerId} · ${serviceTitle?.isNotEmpty == true ? serviceTitle : 'Servicio'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (!_loading) ...[
                _buildStatusTile(),
                const SizedBox(height: 12),
                _buildIntentSummary(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                ],
                const SizedBox(height: 16),
                if (_statusUpper() != 'SUCCEEDED') ...[
                  _buildCardForm(),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _canSubmit ? _confirmPayment : null,
                    style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                    child: Text(_submitting || _polling ? 'Procesando...' : 'Pagar ahora'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _polling ? null : () => _fetchInfo(refresh: true),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar estado'),
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Tu pago fue confirmado. Puedes cerrar esta ventana.'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Cerrar'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
