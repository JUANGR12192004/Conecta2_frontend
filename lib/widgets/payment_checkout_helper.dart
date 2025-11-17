import 'package:flutter/material.dart';

import 'payment_checkout_sheet.dart';

Future<void> showPaymentCheckout({
  required BuildContext context,
  required int offerId,
  int? serviceId,
  String? serviceTitle,
  Map<String, dynamic>? initialPaymentInfo,
  ValueChanged<Map<String, dynamic>>? onPaymentInfo,
  ValueChanged<Map<String, dynamic>>? onPaymentFailed,
  VoidCallback? onPaymentSucceeded,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    useSafeArea: true,
    builder: (_) => PaymentCheckoutSheet(
      offerId: offerId,
      serviceId: serviceId,
      serviceTitle: serviceTitle,
      initialPaymentInfo: initialPaymentInfo,
      onPaymentInfo: onPaymentInfo,
      onPaymentFailed: onPaymentFailed,
      onPaymentSucceeded: onPaymentSucceeded,
    ),
  );
}
