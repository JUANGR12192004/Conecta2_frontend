import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';

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

  final TextEditingController _cardCtrl =
      TextEditingController(text: '4242424242424242');
  final TextEditingController _nameCtrl = TextEditingController();
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
        if (mounted) {
          _applyInfo(initial);
        }
      });
    } else {
      _fetchInfo();
    }
  }

  @override
  void dispose() {
    _cardCtrl.dispose();
    _nameCtrl.dispose();
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
      final info = await ApiService.getOfferPaymentInfo(
        offerId: widget.offerId,
        refresh: refresh,
      );
      if (!mounted) return;
      _applyInfo(info);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
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

  String _statusUpper() {
    final status = _paymentInfo?['paymentStatus'] ?? _paymentInfo?['status'];
    if (status == null) return '';
    final text = status.toString().trim();
    return text.toUpperCase();
  }

  String _statusLabel() {
    switch (_statusUpper()) {
      case 'PENDING':
        return 'Pago pendiente';
      case 'REQUIRES_ACTION':
        return 'Se requiere acción';
      case 'SUCCEEDED':
        return 'Pago confirmado';
      case 'FAILED':
        return 'Pago rechazado';
      default:
        return 'Estado desconocido';
    }
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

  String? _intentId() => _paymentInfo?['paymentIntentId']?.toString();

  String? _clientSecret() => _paymentInfo?['paymentClientSecret']?.toString();

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

    final holder = _nameCtrl.text.trim().isEmpty
        ? 'Cliente Conecta2'
        : _nameCtrl.text.trim();
    final cardNumber = _cardCtrl.text.trim();
    final expText = _expCtrl.text.trim();
    final expMatch = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(expText);
    if (expMatch == null) {
      setState(() {
        _error = 'Formato de fecha inválido. Usa MM/AA';
      });
      return;
    }
    final expMonth = int.tryParse(expMatch.group(1)!);
    final expYear = int.tryParse(expMatch.group(2)!);
    if (expMonth == null || expMonth < 1 || expMonth > 12) {
      setState(() {
        _error = 'Mes inválido';
      });
      return;
    }
    if (expYear == null) {
      setState(() {
        _error = 'Año inválido';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ApiService.confirmPaymentIntent(
        paymentIntentId: intentId,
        clientSecret: clientSecret,
        paymentMethod: {
          'type': 'CARD',
          'card': {
            'number': cardNumber,
            'expMonth': expMonth,
            'expYear': 2000 + expYear,
            'cvc': _cvcCtrl.text.trim(),
            'holder': holder,
          },
        },
        billingDetails: {
          'name': holder,
        },
        metadata: {
          'offerId': widget.offerId,
          if (widget.serviceId != null) 'serviceId': widget.serviceId,
          'origin': 'Conecta2-frontend',
        },
      );
      if (!mounted) return;
      await _fetchInfo(refresh: true);
      await _startPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _submitting = false;
      });
    }
  }

  Future<void> _startPolling() async {
    if (_polling) return;
    setState(() {
      _polling = true;
    });
    for (int i = 0; i < 8 && mounted; i++) {
      await Future.delayed(const Duration(seconds: 3));
      try {
        final info = await ApiService.getOfferPaymentInfo(
          offerId: widget.offerId,
          refresh: true,
        );
        if (!mounted) return;
        _applyInfo(info);
        final status = _statusUpper();
        if (status == 'SUCCEEDED' || status == 'FAILED') {
          break;
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
    if (!mounted) return;
    setState(() {
      _polling = false;
    });
  }

  Widget _buildStatusTile() {
    final status = _statusLabel();
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
              _statusUpper() == 'SUCCEEDED'
                  ? Icons.check
                  : (_statusUpper() == 'FAILED'
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
                  _statusUpper() == 'SUCCEEDED'
                      ? 'Tu pago fue confirmado por la pasarela.'
                      : _statusUpper() == 'FAILED'
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final serviceTitle = widget.serviceTitle?.trim();
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
                'Oferta #${widget.offerId} • ${serviceTitle?.isNotEmpty == true ? serviceTitle : 'Servicio'}',
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
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
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
