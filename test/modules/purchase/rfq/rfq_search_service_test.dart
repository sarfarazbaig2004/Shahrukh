import 'package:flutter_test/flutter_test.dart';
import 'package:QUIK/modules/purchase/rfq/models/purchase_rfq_model.dart';
import 'package:QUIK/modules/purchase/rfq/models/purchase_rfq_item_model.dart';
import 'package:QUIK/modules/purchase/rfq/models/purchase_rfq_vendor_model.dart';
import 'package:QUIK/modules/purchase/rfq/models/rfq_status.dart';
import 'package:QUIK/modules/purchase/rfq/services/rfq_search_service.dart';

void main() {
  group('RfqSearchService', () {
    final now = DateTime(2026, 7, 21, 10, 0);

    PurchaseRfq buildRfq({
      required String id,
      required String rfqNumber,
      required String title,
      DateTime? createdAt,
      DateTime? updatedAt,
      DateTime? rfqDate,
      String? prNumber,
      String? buyer,
      String? deliveryLocation,
      List<PurchaseRfqItem>? items,
      List<PurchaseRfqVendor>? vendors,
      RfqStatus status = RfqStatus.draft,
      bool isDeleted = false,
    }) {
      return PurchaseRfq(
        id: id,
        companyId: 'company-1',
        rfqNumber: rfqNumber,
        title: title,
        rfqDate: rfqDate ?? now,
        purchaseRequisitionNumber: prNumber,
        assignedBuyerName: buyer,
        deliveryLocation: deliveryLocation,
        items: items ?? const [],
        vendors: vendors ?? const [],
        status: status,
        createdBy: 'user-1',
        createdAt: createdAt ?? now,
        updatedAt: updatedAt,
        isDeleted: isDeleted,
      );
    }

    final rfqExact = buildRfq(
      id: '1',
      rfqNumber: 'RFQ-2026-00125',
      title: 'Boiler fabrication material requirement',
      createdAt: now.subtract(const Duration(days: 5)),
    );

    final rfqPrefix = buildRfq(
      id: '2',
      rfqNumber: 'RFQ-2026-00126',
      title: 'Another RFQ',
      createdAt: now.subtract(const Duration(days: 4)),
    );

    final rfqTitle = buildRfq(
      id: '3',
      rfqNumber: 'RFQ-2026-00050',
      title: 'Boiler maintenance spare parts',
      createdAt: now.subtract(const Duration(days: 3)),
    );

    final rfqPr = buildRfq(
      id: '4',
      rfqNumber: 'RFQ-2026-00010',
      title: 'PR linked RFQ',
      prNumber: 'PR-2026-0048',
      createdAt: now.subtract(const Duration(days: 2)),
    );

    final rfqVendor = buildRfq(
      id: '5',
      rfqNumber: 'RFQ-2026-00020',
      title: 'Vendor linked RFQ',
      vendors: const [
        PurchaseRfqVendor(
          vendorId: 'v-1',
          vendorName: 'Acme Engineering Supplies',
        ),
      ],
      createdAt: now.subtract(const Duration(days: 1)),
    );

    final rfqItem = buildRfq(
      id: '6',
      rfqNumber: 'RFQ-2026-00030',
      title: 'Item linked RFQ',
      items: const [
        PurchaseRfqItem(
          itemName: 'Stainless Steel Boiler Tube',
          itemCode: 'SSBT-304',
          quantity: 10,
          unit: 'Mtr',
        ),
      ],
      createdAt: now,
    );

    final rfqDeleted = buildRfq(
      id: '7',
      rfqNumber: 'RFQ-2026-00125-DELETED',
      title: 'Deleted RFQ',
      isDeleted: true,
      createdAt: now,
    );

    final rfqs = [
      rfqExact,
      rfqPrefix,
      rfqTitle,
      rfqPr,
      rfqVendor,
      rfqItem,
      rfqDeleted,
    ];

    final service = RfqSearchService();

    test('exact RFQ-number match ranks first', () {
      final results = service.getSuggestions(
        rfqs: rfqs,
        query: 'RFQ-2026-00125',
        limit: 10,
      );
      expect(results.first.rfqNumber, 'RFQ-2026-00125');
      expect(results.length, 1); // exact only
    });

    test('RFQ-number prefix search returns prefix matches', () {
      final results = service.getSuggestions(
        rfqs: rfqs,
        query: 'RFQ-2026-001',
        limit: 10,
      );
      expect(
        results.map((r) => r.rfqNumber),
        containsAll(['RFQ-2026-00125', 'RFQ-2026-00126']),
      );
    });

    test('title search matches title start', () {
      final results = service.getSuggestions(
        rfqs: rfqs,
        query: 'Boiler maintenance',
        limit: 10,
      );
      expect(results.first.id, '3');
    });

    test('title search matches terms inside item names/descriptions', () {
      final results = service.getSuggestions(
        rfqs: rfqs,
        query: 'boiler',
        limit: 10,
      );
      final ids = results.map((r) => r.id).toSet();
      expect(ids, containsAll({'1', '3', '6'}));
    });

    test('Purchase Requisition number search', () {
      final results = service.getSuggestions(
        rfqs: rfqs,
        query: 'PR-2026-0048',
        limit: 10,
      );
      expect(results, hasLength(1));
      expect(results.first.id, '4');
    });

    test('vendor-name search', () {
      final results = service.getSuggestions(
        rfqs: rfqs,
        query: 'Acme Engineering',
        limit: 10,
      );
      expect(results, hasLength(1));
      expect(results.first.id, '5');
    });

    test('item-name search', () {
      final results = service.getSuggestions(
        rfqs: rfqs,
        query: 'Boiler Tube',
        limit: 10,
      );
      expect(results, hasLength(1));
      expect(results.first.id, '6');
    });

    test('item-code search ranks before generic contains', () {
      final results = service.getSuggestions(
        rfqs: rfqs,
        query: 'SSBT-304',
        limit: 10,
      );
      expect(results, hasLength(1));
      expect(results.first.id, '6');
    });

    test('status search by display label', () {
      final approved = buildRfq(
        id: '8',
        rfqNumber: 'RFQ-2026-00999',
        title: 'Approved RFQ',
        status: RfqStatus.approved,
      );
      final results = service.getSuggestions(
        rfqs: [...rfqs, approved],
        query: 'Approved',
        limit: 10,
      );
      expect(results.map((r) => r.id), contains('8'));
    });

    test('deleted RFQs are excluded', () {
      final results = service.getSuggestions(
        rfqs: rfqs,
        query: 'RFQ-2026-00125-DELETED',
        limit: 10,
      );
      expect(results, isEmpty);
    });

    test('deleted RFQs are excluded from empty-query results', () {
      final results = service.getSuggestions(rfqs: rfqs, query: '', limit: 10);
      expect(results, isNot(contains(rfqDeleted)));
    });

    test(
      'empty query returns recent RFQs sorted by updatedAt, createdAt, rfqDate',
      () {
        final older = buildRfq(
          id: 'older',
          rfqNumber: 'RFQ-OLD',
          title: 'Old',
          createdAt: now.subtract(const Duration(days: 10)),
          updatedAt: now.subtract(const Duration(days: 10)),
        );
        final newer = buildRfq(
          id: 'newer',
          rfqNumber: 'RFQ-NEW',
          title: 'New',
          createdAt: now,
          updatedAt: now.add(const Duration(minutes: 1)),
        );
        final results = service.getSuggestions(
          rfqs: [...rfqs.where((r) => !r.isDeleted), older, newer],
          query: '',
          limit: 10,
        );
        expect(results.first.id, 'newer');
      },
    );

    test('suggestion limit is respected', () {
      final results = service.getSuggestions(
        rfqs: rfqs,
        query: 'RFQ',
        limit: 3,
      );
      expect(results.length, 3);
    });

    test('original RFQ list is not mutated', () {
      final originalOrder = rfqs.toList();
      service.getSuggestions(rfqs: rfqs, query: 'boiler', limit: 10);
      expect(rfqs, orderedEquals(originalOrder));
    });

    test('search is case-insensitive', () {
      final results = service.getSuggestions(
        rfqs: rfqs,
        query: 'rfq-2026-00125',
        limit: 10,
      );
      expect(results.first.rfqNumber, 'RFQ-2026-00125');
    });

    test('search trims whitespace', () {
      final results = service.getSuggestions(
        rfqs: rfqs,
        query: '  boiler  ',
        limit: 10,
      );
      expect(results.map((r) => r.id).toSet(), containsAll({'1', '3', '6'}));
    });
  });
}
