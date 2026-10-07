import 'package:flutter_test/flutter_test.dart';
import 'package:khanak/helpers/support.dart';
import 'package:khanak/types/trade.dart';

void main() {
  test('legal pages sit at the root of the API host, not under /v1', () {
    for (final page in LegalPage.values) {
      expect(page.url.path, '/legal/${page.path}');
      expect(page.url.pathSegments, isNot(contains('v1')));
    }
  });

  test('a payment read back for editing keeps its mode and note', () {
    final payment = PartyPayment.fromJson({
      'id': 'p1',
      'kind': 'received',
      'paid_on': '2026-10-06',
      'amount': '2500.00',
      'mode': 'upi',
      'note': 'GPay',
    });
    expect(payment.amount, 2500);
    expect(payment.mode, 'upi');
    expect(payment.note, 'GPay');
    expect(payment.paidOn, DateTime(2026, 10, 6));
  });
}
