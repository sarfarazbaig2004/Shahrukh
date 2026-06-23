import 'package:flutter_test/flutter_test.dart';

import 'package:QUIK/modules/purchase/purchase_bills/purchase_bill_model.dart';

void main() {
  group('Purchase bill calculations', () {
    test('calculates line discount, tax and total', () {
      const line = PurchaseBillLine(
        productId: 'p1',
        productName: 'Servo Drive',
        description: 'Industrial servo drive',
        hsnCode: '850440',
        unit: 'Nos.',
        quantity: 10,
        rate: 100,
        discountPercent: 10,
        taxPercent: 18,
        taxAmount: 162,
        lineTotal: 1062,
      );

      expect(line.subtotal, 1000);
      expect(line.discountAmount, 100);
      expect(line.taxableValue, 900);
      expect(line.effectivePurchaseRate, 90);
    });

    test('calculates bill totals with charges and TDS', () {
      const lines = [
        PurchaseBillLine(
          productId: 'p1',
          productName: 'Product 1',
          description: '',
          hsnCode: '1001',
          unit: 'Nos.',
          quantity: 2,
          rate: 500,
          discountPercent: 10,
          taxPercent: 18,
          taxAmount: 162,
          lineTotal: 1062,
        ),
        PurchaseBillLine(
          productId: 'p2',
          productName: 'Product 2',
          description: '',
          hsnCode: '1002',
          unit: 'Nos.',
          quantity: 1,
          rate: 200,
          discountPercent: 0,
          taxPercent: 5,
          taxAmount: 10,
          lineTotal: 210,
        ),
      ];

      final totals = PurchaseBillTotals.fromLines(
        lines,
        freightAmount: 50,
        otherCharges: 20,
        tdsAmount: 10,
      );

      expect(totals.subtotal, 1200);
      expect(totals.discountTotal, 100);
      expect(totals.taxableValue, 1100);
      expect(totals.taxAmount, 172);
      expect(totals.grandTotal, 1332);
    });

    test('uses Indian April-to-March financial year', () {
      expect(purchaseFinancialYear(DateTime(2026, 4, 1)), '2026-27');
      expect(purchaseFinancialYear(DateTime(2027, 3, 31)), '2026-27');
    });

    test('updates weighted average purchase valuation', () {
      final rate = weightedAveragePurchaseRate(
        currentQuantity: 10,
        currentRate: 80,
        receivedQuantity: 5,
        receivedTaxableValue: 500,
      );

      expect(rate, closeTo(86.6666667, 0.0001));
    });

    test('serializes required product-line fields', () {
      const line = PurchaseBillLine(
        productId: 'p1',
        productName: 'Servo Drive',
        description: 'Industrial servo drive',
        hsnCode: '850440',
        unit: 'Nos.',
        quantity: 2,
        rate: 1000,
        discountPercent: 5,
        taxPercent: 18,
        taxAmount: 342,
        lineTotal: 2242,
      );
      final map = line.toMap();

      expect(
        map.keys,
        containsAll([
          'productId',
          'productName',
          'description',
          'hsnCode',
          'unit',
          'quantity',
          'rate',
          'discountPercent',
          'taxPercent',
          'taxAmount',
          'lineTotal',
        ]),
      );
    });
  });
}
