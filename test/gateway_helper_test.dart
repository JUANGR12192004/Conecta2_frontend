import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_applicatiomconecta2/services/gateway_helper.dart';

void main() {
  test('PaymentIntentResponse.fromJson extracts intent and status', () {
    final json = {
      'intentId': 'pi_ABC',
      'status': 'REQUIRES_ACTION',
    };
    final resp = PaymentIntentResponse.fromJson(json);
    expect(resp.intentId, 'pi_ABC');
    expect(resp.status, 'REQUIRES_ACTION');
  });

  test('GatewayException exposes metadata in toString', () {
    final error = GatewayException(statusCode: 401, body: '{"message":"invalid"}');
    final str = error.toString();
    expect(str, contains('statusCode: 401'));
    expect(str, contains('invalid'));
  });
}
