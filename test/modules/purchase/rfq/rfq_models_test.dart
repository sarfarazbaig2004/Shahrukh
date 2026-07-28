import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:QUIK/modules/purchase/rfq/models/purchase_rfq_item_model.dart';
import 'package:QUIK/modules/purchase/rfq/models/purchase_rfq_model.dart';
import 'package:QUIK/modules/purchase/rfq/models/purchase_rfq_vendor_model.dart';
import 'package:QUIK/modules/purchase/rfq/models/rfq_status.dart';

void main() {
  group('PurchaseRfq.fromMap', () {
    test('handles missing fields with safe defaults', () {
      final rfq = PurchaseRfq.fromMap({});
      expect(rfq.id, '');
      expect(rfq.companyId, '');
      expect(rfq.rfqNumber, '');
      expect(rfq.title, '');
      expect(rfq.items, isEmpty);
      expect(rfq.vendors, isEmpty);
      expect(rfq.status, RfqStatus.draft);
      expect(rfq.isDeleted, false);
      expect(rfq.createdBy, '');
      expect(rfq.createdAt, isA<DateTime>());
    });

    test('parses timestamps from Firestore Timestamp safely', () {
      final date = DateTime(2026, 7, 21, 14, 30);
      final rfq = PurchaseRfq.fromMap({
        'id': 'rfq-1',
        'rfqNumber': 'RFQ-2026-00001',
        'title': 'Test RFQ',
        'rfqDate': Timestamp.fromDate(date),
        'createdAt': Timestamp.fromDate(date),
        'updatedAt': Timestamp.fromDate(date),
        'status': 'approved',
        'createdBy': 'user-1',
      });
      expect(rfq.id, 'rfq-1');
      expect(rfq.rfqDate, date);
      expect(rfq.createdAt, date);
      expect(rfq.updatedAt, date);
      expect(rfq.status, RfqStatus.approved);
    });

    test('round-trips through toMap and fromMap', () {
      final rfq = PurchaseRfq(
        id: 'rfq-2',
        companyId: 'c-1',
        rfqNumber: 'RFQ-2026-00002',
        title: 'Round trip RFQ',
        rfqDate: DateTime(2026, 7, 20),
        purchaseRequisitionNumber: 'PR-2026-0001',
        items: const [
          PurchaseRfqItem(
            id: 'item-1',
            itemName: 'Steel Plate',
            quantity: 5,
            unit: 'Kg',
          ),
        ],
        vendors: const [
          PurchaseRfqVendor(vendorId: 'v-1', vendorName: 'Vendor One'),
        ],
        status: RfqStatus.sent,
        createdBy: 'user-2',
        createdAt: DateTime(2026, 7, 20, 10, 0),
      );

      final map = rfq.toMap();
      final restored = PurchaseRfq.fromMap(map);

      expect(restored.id, rfq.id);
      expect(restored.rfqNumber, rfq.rfqNumber);
      expect(restored.title, rfq.title);
      expect(restored.status, rfq.status);
      expect(restored.items.length, 1);
      expect(restored.items.first.itemName, 'Steel Plate');
      expect(restored.vendors.length, 1);
      expect(restored.vendors.first.vendorName, 'Vendor One');
    });

    test('serializes to and from JSON', () {
      final rfq = PurchaseRfq(
        id: 'rfq-json',
        companyId: 'c-1',
        rfqNumber: 'RFQ-2026-00003',
        title: 'JSON RFQ',
        rfqDate: DateTime(2026, 7, 20),
        status: RfqStatus.draft,
        createdBy: 'user-3',
        createdAt: DateTime(2026, 7, 20),
      );

      final json = rfq.toJson();
      final restored = PurchaseRfq.fromJson(json);

      expect(restored.id, rfq.id);
      expect(restored.rfqNumber, rfq.rfqNumber);
      expect(restored.status, rfq.status);
    });

    test('isDeleted flag is parsed safely', () {
      final rfq = PurchaseRfq.fromMap({'isDeleted': true});
      expect(rfq.isDeleted, true);

      final notDeleted = PurchaseRfq.fromMap({'isDeleted': false});
      expect(notDeleted.isDeleted, false);

      final missing = PurchaseRfq.fromMap({});
      expect(missing.isDeleted, false);
    });
  });

  group('PurchaseRfqItem', () {
    test('numeric values are parsed safely', () {
      final item = PurchaseRfqItem.fromMap({
        'quantity': '12,500.50',
        'unit': 'Mtr',
        'itemName': 'Cable',
      });
      expect(item.quantity, 12500.50);
      expect(item.unit, 'Mtr');
      expect(item.itemName, 'Cable');
    });

    test('missing quantity defaults to zero', () {
      final item = PurchaseRfqItem.fromMap({'itemName': 'Undefined qty'});
      expect(item.quantity, 0);
    });

    test('invalid quantity defaults to zero', () {
      final item = PurchaseRfqItem.fromMap({
        'itemName': 'Bad qty',
        'quantity': 'not-a-number',
      });
      expect(item.quantity, 0);
    });

    test('required delivery date parses from Timestamp', () {
      final date = DateTime(2026, 8, 15);
      final item = PurchaseRfqItem.fromMap({
        'itemName': 'Dated item',
        'requiredDeliveryDate': Timestamp.fromDate(date),
      });
      expect(item.requiredDeliveryDate, date);
    });
  });

  group('PurchaseRfqVendor', () {
    test('isSelected defaults to false', () {
      final vendor = PurchaseRfqVendor.fromMap({
        'vendorId': 'v-1',
        'vendorName': 'Vendor',
      });
      expect(vendor.isSelected, false);
    });

    test('nullable fields remain null when missing', () {
      final vendor = PurchaseRfqVendor.fromMap({
        'vendorId': 'v-1',
        'vendorName': 'Vendor',
      });
      expect(vendor.email, isNull);
      expect(vendor.phone, isNull);
    });

    test('respondedAt parses from Timestamp', () {
      final date = DateTime(2026, 7, 22);
      final vendor = PurchaseRfqVendor.fromMap({
        'vendorId': 'v-1',
        'vendorName': 'Vendor',
        'respondedAt': Timestamp.fromDate(date),
      });
      expect(vendor.respondedAt, date);
    });
  });

  group('RfqStatus', () {
    test('enum parsing falls back safely to draft', () {
      expect(RfqStatusExtension.parse(null), RfqStatus.draft);
      expect(RfqStatusExtension.parse(''), RfqStatus.draft);
      expect(RfqStatusExtension.parse('unknown-status'), RfqStatus.draft);
    });

    test('parses firestore values and display labels', () {
      expect(RfqStatusExtension.parse('approved'), RfqStatus.approved);
      expect(
        RfqStatusExtension.parse('Pending Approval'),
        RfqStatus.pendingApproval,
      );
      expect(
        RfqStatusExtension.parse('Converted to PO'),
        RfqStatus.convertedToPO,
      );
    });

    test('firestoreValue round-trips through parse', () {
      for (final status in RfqStatus.values) {
        expect(RfqStatusExtension.parse(status.firestoreValue), status);
      }
    });

    test('display labels are human readable', () {
      expect(RfqStatus.draft.displayLabel, 'Draft');
      expect(RfqStatus.underEvaluation.displayLabel, 'Under Evaluation');
    });
  });
}
