import 'package:flutter_test/flutter_test.dart';
import 'package:QUIK/modules/crm/customers/customer_duplicate_helper.dart';

void main() {
  group('customer normalization', () {
    test('normalizes customer names across unicode styles and spacing', () {
      const rawNames = [
        'ABC Engineering',
        'abc engineering',
        ' ABC Engineering',
        'ABC  Engineering',
        'ＡＢＣ Engineering',
        '𝐀𝐁𝐂 Engineering',
        '𝘼𝘽𝘾 Engineering',
        '𝑨𝑩𝑪 Engineering',
        '𝒜𝒷𝒸 Engineering',
        '𝔄𝔅ℭ Engineering',
        '𝕬𝕭𝕮 Engineering',
      ];

      for (final value in rawNames) {
        expect(normalizeCustomerName(value), 'abc engineering');
      }
    });

    test('normalizes gst, phone and email values', () {
      expect(normalizeGST('27-ABCDE1234F1Z5'), '27ABCDE1234F1Z5');
      expect(normalizePhone('+91-9876543210'), '919876543210');
      expect(normalizeCustomerPhoneLast10('+91 (98765) 43210'), '9876543210');
      expect(normalizeCustomerPhoneLast10('09876543210'), '9876543210');
      expect(normalizeEmail(' User@Example.COM '), 'user@example.com');
    });
  });

  group('duplicate detection', () {
    test('detects duplicates across normalized customer fields', () {
      final customers = [
        {
          'id': '1',
          'customerNameNormalized': 'abc engineering',
          'gstNumberNormalized': '27ABCDE1234F1Z5',
          'phoneNumberNormalized': '919876543210',
          'emailNormalized': 'user@example.com',
        },
      ];

      expect(
        findDuplicateMatch(
          customers: customers,
          currentCustomerId: null,
          name: 'ＡＢＣ Engineering',
        ),
        'customerName',
      );
      expect(
        findDuplicateMatch(
          customers: customers,
          currentCustomerId: null,
          gst: '27-abcde1234f1z5',
        ),
        'gst',
      );
      expect(
        findDuplicateMatch(
          customers: customers,
          currentCustomerId: null,
          phone: '+91 9876543210',
        ),
        'phone',
      );
      expect(
        findDuplicateMatch(
          customers: customers,
          currentCustomerId: null,
          email: 'USER@EXAMPLE.COM',
        ),
        'email',
      );
    });
  });
}
