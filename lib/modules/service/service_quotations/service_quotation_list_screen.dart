import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:QUIK/modules/service/service_quotations/create_service_quotation_screen.dart';
import 'service_quotation_pdf_generator.dart';

class ServiceQuotationListScreen extends StatefulWidget {
  final String companyId; // Inject from your Auth/State Management

  const ServiceQuotationListScreen({Key? key, required this.companyId}) : super(key: key);

  @override
  _ServiceQuotationListScreenState createState() => _ServiceQuotationListScreenState();
}

class _ServiceQuotationListScreenState extends State<ServiceQuotationListScreen> {
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _paymentFilter = 'All';

  final List<String> _statuses = ['All', 'Draft', 'Sent', 'Approved', 'Rejected', 'Converted To Work Order'];
  final List<String> _paymentStatuses = ['All', 'Pending', 'Advance Received', 'Partial Payment', 'Paid'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Quotations'),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Create Quotation'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateServiceQuotationScreen(companyId: widget.companyId),
                ),
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryCards(),
          _buildFilters(),
          Expanded(
            child: _buildDataTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('service_quotations')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();

        int total = 0;
        int draft = 0;
        int approved = 0;
        int converted = 0;
        double totalValue = 0.0;

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          total++;
          totalValue += (data['grandTotal'] ?? 0.0);
          final status = data['status'] ?? '';
          if (status == 'Draft') draft++;
          if (status == 'Approved') approved++;
          if (status == 'Converted To Work Order') converted++;
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _summaryCard('Total Quotations', total.toString(), Colors.blue),
              _summaryCard('Draft', draft.toString(), Colors.orange),
              _summaryCard('Approved', approved.toString(), Colors.green),
              _summaryCard('Converted', converted.toString(), Colors.purple),
              _summaryCard('Total Value', '₹${totalValue.toStringAsFixed(2)}', Colors.teal),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              const SizedBox(height: 8),
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search by Quotation No, Customer, or Serial No',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _statusFilter,
              decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
              items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) => setState(() => _statusFilter = val!),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _paymentFilter,
              decoration: const InputDecoration(labelText: 'Payment Status', border: OutlineInputBorder()),
              items: _paymentStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) => setState(() => _paymentFilter = val!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('service_quotations')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var docs = snapshot.data?.docs ?? [];

        // Client-side filtering
        docs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final qNo = (data['quotationNo'] ?? '').toString().toLowerCase();
          final cust = (data['customerName'] ?? '').toString().toLowerCase();
          final serial = (data['serialNumber'] ?? '').toString().toLowerCase();
          final status = data['status'] ?? '';
          final payStatus = data['paymentStatus'] ?? '';

          final matchesSearch = qNo.contains(_searchQuery) || cust.contains(_searchQuery) || serial.contains(_searchQuery);
          final matchesStatus = _statusFilter == 'All' || status == _statusFilter;
          final matchesPayment = _paymentFilter == 'All' || payStatus == _paymentFilter;

          return matchesSearch && matchesStatus && matchesPayment;
        }).toList();

        if (docs.isEmpty) {
          return const Center(child: Text('No Service Quotations found.'));
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Quotation No')),
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Customer')),
                DataColumn(label: Text('Machine Model')),
                DataColumn(label: Text('Grand Total')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final date = data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now();

                return DataRow(
                  cells: [
                    DataCell(Text(data['quotationNo'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(DateFormat('dd MMM yyyy').format(date))),
                    DataCell(Text(data['customerName'] ?? 'N/A')),
                    DataCell(Text(data['machineModel'] ?? 'N/A')),
                    DataCell(Text('₹${(data['grandTotal'] ?? 0).toStringAsFixed(2)}')),
                    DataCell(_buildStatusBadge(data['status'] ?? 'Draft')),
                    DataCell(
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                            tooltip: 'View PDF',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ServiceQuotationPdfPreviewScreen(quotationData: data),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            tooltip: 'Edit',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CreateServiceQuotationScreen(
                                    companyId: widget.companyId,
                                    // Correctly unpack the QueryDocumentSnapshot into a Map<String, dynamic>
                                    existingQuotation: {
                                      'id': doc.id,
                                      ...doc.data() as Map<String, dynamic>,
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                          if (data['status'] != 'Converted To Work Order')
                            IconButton(
                              icon: const Icon(Icons.build_circle, color: Colors.green),
                              tooltip: 'Convert to Work Order',
                              onPressed: () => _convertToWorkOrder(doc),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'Approved': color = Colors.green; break;
      case 'Rejected': color = Colors.red; break;
      case 'Sent': color = Colors.blue; break;
      case 'Converted To Work Order': color = Colors.purple; break;
      default: color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color)),
      child: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _convertToWorkOrder(DocumentSnapshot quoteDoc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Convert to Work Order'),
        content: const Text('Are you sure you want to convert this quotation into a Work Order?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Convert')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final db = FirebaseFirestore.instance;
      final data = quoteDoc.data() as Map<String, dynamic>;

      await db.runTransaction((transaction) async {
        // Auto-generate WO Number
        final counterRef = db.collection('companies').doc(widget.companyId).collection('counters').doc('work_orders');
        final counterSnap = await transaction.get(counterRef);
        int currentCount = 1;
        if (counterSnap.exists) {
          currentCount = (counterSnap.data()?['count'] ?? 0) + 1;
          transaction.update(counterRef, {'count': currentCount});
        } else {
          transaction.set(counterRef, {'count': currentCount});
        }

        final year = DateTime.now().year;
        final woNumber = 'WO-$year-${currentCount.toString().padLeft(4, '0')}';

        // Create WO Doc
        final newWoRef = db.collection('companies').doc(widget.companyId).collection('work_orders').doc();
        transaction.set(newWoRef, {
          'id': newWoRef.id,
          'companyId': widget.companyId,
          'workOrderNo': woNumber,
          'sourceQuotationId': quoteDoc.id,
          'customerId': data['customerId'],
          'customerName': data['customerName'],
          'machineModel': data['machineModel'],
          'serialNumber': data['serialNumber'],
          'complaintDescription': data['complaintDescription'],
          'assignedEngineer': data['assignedEngineer'],
          'items': data['items'],
          'status': 'Open',
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': 'CURRENT_USER', // Replace with real UID
        });

        // Update Quote Status
        transaction.update(quoteDoc.reference, {
          'status': 'Converted To Work Order',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully converted to Work Order')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}