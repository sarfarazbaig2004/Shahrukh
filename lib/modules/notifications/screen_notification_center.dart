import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ScreenNotificationCenter extends StatefulWidget {
  final String companyId;

  const ScreenNotificationCenter({super.key, required this.companyId});

  @override
  State<ScreenNotificationCenter> createState() =>
      _ScreenNotificationCenterState();
}

class _ScreenNotificationCenterState extends State<ScreenNotificationCenter> {
  static const Color _primary = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _blue = Color(0xFF2563EB);
  static const Color _green = Color(0xFF16A34A);
  static const Color _orange = Color(0xFFF97316);

  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';
  String _filter = 'all';

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _notificationsRef =>
      FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('notifications');

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    final uid = _currentUid;
    if (uid == null || uid.trim().isEmpty) {
      return const Stream.empty();
    }

    return _notificationsRef.where('recipientUid', isEqualTo: uid).snapshots();
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _timeText(dynamic value) {
    final date = _date(value);
    if (date == null) return '-';
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  IconData _icon(String type) {
    switch (type.toLowerCase()) {
      case 'task_assignment':
      case 'task_update':
        return Icons.task_alt_outlined;
      case 'meeting_invitation':
      case 'meeting_reminder':
        return Icons.event_available_outlined;
      case 'approval':
        return Icons.verified_outlined;
      default:
        return Icons.notifications_none_outlined;
    }
  }

  Color _color(String type) {
    switch (type.toLowerCase()) {
      case 'task_assignment':
      case 'task_update':
        return _blue;
      case 'meeting_invitation':
      case 'meeting_reminder':
        return _green;
      case 'approval':
        return _orange;
      default:
        return _primary;
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final q = _search.trim().toLowerCase();

    final filtered = docs.where((doc) {
      final data = doc.data();
      final isRead = data['isRead'] == true;

      if (_filter == 'unread' && isRead) return false;
      if (_filter == 'read' && !isRead) return false;

      if (q.isEmpty) return true;

      final haystack = [
        data['title'],
        data['message'],
        data['type'],
        data['module'],
        data['relatedModule'],
        data['taskNumber'],
        data['meetingNumber'],
      ].whereType<Object>().map((e) => e.toString().toLowerCase()).join(' ');

      return haystack.contains(q);
    }).toList();

    filtered.sort((a, b) {
      final ad = _date(a.data()['createdAt']) ?? DateTime(1970);
      final bd = _date(b.data()['createdAt']) ?? DateTime(1970);
      return bd.compareTo(ad);
    });

    return filtered;
  }

  Future<void> _markRead(String id, bool isRead) async {
    await _notificationsRef.doc(id).update({
      'isRead': isRead,
      'readAt': isRead ? FieldValue.serverTimestamp() : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _markAllRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final unread = docs.where((doc) => doc.data()['isRead'] != true).toList();
    if (unread.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in unread) {
      batch.update(doc.reference, {
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUid == null) {
      return const Scaffold(
        body: Center(child: Text('Please login again to view notifications.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Notification Center'),
        backgroundColor: Colors.white,
        foregroundColor: _primary,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Notification error: ${snap.error}'));
          }

          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final rawDocs = snap.data?.docs ?? [];
          final unreadCount = rawDocs
              .where((doc) => doc.data()['isRead'] != true)
              .length;
          final docs = _applyFilters(rawDocs);

          return Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(total: rawDocs.length, unread: unreadCount),
                const SizedBox(height: 14),
                _toolbar(rawDocs),
                const SizedBox(height: 14),
                Expanded(
                  child: docs.isEmpty
                      ? _emptyState()
                      : ListView.separated(
                          itemCount: docs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            return _notificationCard(docs[index]);
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _header({required int total, required int unread}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notification Center',
                style: TextStyle(
                  color: _primary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Track task alerts, meeting invitations, reminders, and ERP activity.',
                style: TextStyle(color: _muted, fontSize: 13),
              ),
            ],
          ),
          Wrap(
            spacing: 10,
            children: [
              _statChip(
                'Total',
                total.toString(),
                Icons.notifications_outlined,
              ),
              _statChip('Unread', unread.toString(), Icons.mark_email_unread),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: _blue),
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: const TextStyle(
              color: _primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar(List<QueryDocumentSnapshot<Map<String, dynamic>>> rawDocs) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 320,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (value) => setState(() => _search = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search notifications',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _border),
                ),
              ),
            ),
          ),
          DropdownButton<String>(
            value: _filter,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All')),
              DropdownMenuItem(value: 'unread', child: Text('Unread')),
              DropdownMenuItem(value: 'read', child: Text('Read')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _filter = value);
            },
          ),
          OutlinedButton.icon(
            onPressed: () => _markAllRead(rawDocs),
            icon: const Icon(Icons.done_all),
            label: const Text('Mark all read'),
          ),
        ],
      ),
    );
  }

  Widget _notificationCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final type = (data['type'] ?? '').toString();
    final title = (data['title'] ?? 'Notification').toString();
    final message = (data['message'] ?? '').toString();
    final isRead = data['isRead'] == true;
    final color = _color(type);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : const Color(0xFFEFF6FF),
        border: Border.all(color: isRead ? _border : const Color(0xFFBFDBFE)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(_icon(type), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (!isRead)
                      _badge('Unread', _blue)
                    else
                      _badge('Read', _muted),
                    if (type.trim().isNotEmpty) _badge(type, color),
                  ],
                ),
                if (message.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    message,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  _timeText(data['createdAt']),
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: isRead ? 'Mark unread' : 'Mark read',
            onPressed: () => _markRead(doc.id, !isRead),
            icon: Icon(
              isRead
                  ? Icons.mark_email_unread_outlined
                  : Icons.mark_email_read_outlined,
              color: _primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none_outlined, size: 42, color: _muted),
            SizedBox(height: 10),
            Text(
              'No notifications found',
              style: TextStyle(
                color: _primary,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Try changing search or filter.',
              style: TextStyle(color: _muted),
            ),
          ],
        ),
      ),
    );
  }
}
