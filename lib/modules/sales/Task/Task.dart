import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final _db = FirebaseFirestore.instance;
  AppUser? me;
  String status = 'All';
  String search = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  Future<void> _loadMe() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return setState(() => loading = false);
    QuerySnapshot<Map<String, dynamic>> snap;
    if ((u.email ?? '').isNotEmpty) {
      snap = await _db.collectionGroup('users').where('email', isEqualTo: u.email).limit(1).get();
    } else {
      snap = await _db.collectionGroup('users').where('uid', isEqualTo: u.uid).limit(1).get();
    }
    if (snap.docs.isEmpty) return setState(() => loading = false);
    final d = snap.docs.first;
    final companyId = d.reference.parent.parent!.id;
    setState(() {
      me = AppUser.fromDoc(d, companyId);
      loading = false;
    });
  }

  bool get isAdmin => ['admin', 'superadmin', 'super_admin'].contains((me?.role ?? '').toLowerCase());

  Stream<QuerySnapshot<Map<String, dynamic>>> _taskStream() {
    final base = _db.collection('companies').doc(me!.companyId).collection('tasks');
    if (isAdmin) return base.snapshots();
    return base.where('assignedToUids', arrayContains: me!.uid).snapshots();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filter(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final q = search.trim().toLowerCase();
    docs.sort((a, b) => _date(b.data()['createdAt']).compareTo(_date(a.data()['createdAt'])));
    return docs.where((d) {
      final m = d.data();
      final okStatus = status == 'All' || (m['status'] ?? '') == status;
      final text = '${m['title']} ${m['description']} ${m['notes']}'.toLowerCase();
      return okStatus && (q.isEmpty || text.contains(q));
    }).toList();
  }

  DateTime _date(dynamic v) => v is Timestamp ? v.toDate() : DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (me == null) return const Center(child: Text('User profile not found. Please login again.'));

    return Scaffold(
      backgroundColor: const Color(0xfff6f8fc),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('Tasks', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
            if (isAdmin)
              FilledButton.icon(
                onPressed: () => _openTaskDialog(context),
                icon: const Icon(Icons.add_task),
                label: const Text('Assign Task'),
              ),
          ]),
          const SizedBox(height: 4),
          Text(isAdmin ? 'Create, assign and monitor employee tasks.' : 'Your assigned tasks only.',
              style: const TextStyle(color: Color(0xff64748b))),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _taskStream(),
            builder: (context, snap) {
              final docs = _filter(snap.data?.docs ?? []);
              final open = docs.where((d) => d.data()['status'] == 'Open').length;
              final doing = docs.where((d) => d.data()['status'] == 'In Progress').length;
              final done = docs.where((d) => d.data()['status'] == 'Done').length;
              return Expanded(child: Column(children: [
                Row(children: [
                  _StatCard('Total', docs.length.toString(), Icons.assignment),
                  _StatCard('Open', open.toString(), Icons.radio_button_unchecked),
                  _StatCard('In Progress', doing.toString(), Icons.timelapse),
                  _StatCard('Done', done.toString(), Icons.check_circle_outline),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: TextField(
                    decoration: _input('Search title, notes, description...', Icons.search),
                    onChanged: (v) => setState(() => search = v),
                  )),
                  const SizedBox(width: 12),
                  SizedBox(width: 190, child: DropdownButtonFormField<String>(
                    value: status,
                    decoration: _input('Status', Icons.filter_alt),
                    items: ['All', 'Open', 'In Progress', 'Done', 'Cancelled'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setState(() => status = v ?? 'All'),
                  )),
                ]),
                const SizedBox(height: 14),
                Expanded(
                  child: docs.isEmpty
                      ? const Center(child: Text('No tasks found'))
                      : ListView.separated(
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _TaskCard(
                            doc: docs[i],
                            isAdmin: isAdmin,
                            onStatus: (s) => docs[i].reference.update({'status': s, 'updatedAt': FieldValue.serverTimestamp()}),
                          ),
                        ),
                ),
              ]));
            },
          ),
        ]),
      ),
    );
  }

  InputDecoration _input(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xffdbe3ef))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xffdbe3ef))),
      );

  Future<void> _openTaskDialog(BuildContext context) async {
    final usersSnap = await _db.collection('companies').doc(me!.companyId).collection('users').get();
    final employees = usersSnap.docs.map((d) => AppUser.fromDoc(d, me!.companyId)).where((u) => u.uid.isNotEmpty).toList();
    if (!context.mounted) return;
    showDialog(context: context, builder: (_) => _TaskDialog(me: me!, employees: employees));
  }
}

class _TaskDialog extends StatefulWidget {
  final AppUser me;
  final List<AppUser> employees;
  const _TaskDialog({required this.me, required this.employees});

  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
  final title = TextEditingController();
  final desc = TextEditingController();
  final notes = TextEditingController();
  String priority = 'Medium';
  DateTime? dueDate;
  final selected = <AppUser>[];
  bool saving = false;

  Future<void> save() async {
    if (title.text.trim().isEmpty || selected.isEmpty) return;
    setState(() => saving = true);
    await FirebaseFirestore.instance.collection('companies').doc(widget.me.companyId).collection('tasks').add({
      'title': title.text.trim(),
      'description': desc.text.trim(),
      'notes': notes.text.trim(),
      'priority': priority,
      'status': 'Open',
      'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate!),
      'assignedToUids': selected.map((e) => e.uid).toList(),
      'assignedToNames': selected.map((e) => e.name).toList(),
      'assignedTo': selected.map((e) => {'uid': e.uid, 'name': e.name, 'email': e.email}).toList(),
      'createdByUid': widget.me.uid,
      'createdByName': widget.me.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Assign New Task'),
        content: SizedBox(width: 620, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, decoration: _dec('Task title *')),
          const SizedBox(height: 10),
          TextField(controller: desc, maxLines: 3, decoration: _dec('Work details')),
          const SizedBox(height: 10),
          TextField(controller: notes, maxLines: 3, decoration: _dec('Admin notes / special instructions')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: DropdownButtonFormField<String>(
              value: priority,
              decoration: _dec('Priority'),
              items: ['Low', 'Medium', 'High', 'Urgent'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => priority = v ?? 'Medium'),
            )),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(
              icon: const Icon(Icons.calendar_month),
              label: Text(dueDate == null ? 'Select Due Date' : '${dueDate!.day}/${dueDate!.month}/${dueDate!.year}'),
              onPressed: () async {
                final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime(2035), initialDate: DateTime.now());
                if (d != null) setState(() => dueDate = d);
              },
            )),
          ]),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerLeft, child: Text('Assign to employees *', style: Theme.of(context).textTheme.titleSmall)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: widget.employees.map((u) {
            final on = selected.any((x) => x.uid == u.uid);
            return FilterChip(
              selected: on,
              label: Text(u.name.isEmpty ? u.email : u.name),
              onSelected: (v) => setState(() => v ? selected.add(u) : selected.removeWhere((x) => x.uid == u.uid)),
            );
          }).toList()),
        ]))),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton.icon(onPressed: saving ? null : save, icon: const Icon(Icons.send), label: Text(saving ? 'Saving...' : 'Assign Task')),
        ],
      );

  InputDecoration _dec(String label) => InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)));
}

class _TaskCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool isAdmin;
  final ValueChanged<String> onStatus;
  const _TaskCard({required this.doc, required this.isAdmin, required this.onStatus});

  @override
  Widget build(BuildContext context) {
    final m = doc.data();
    final due = m['dueDate'] is Timestamp ? (m['dueDate'] as Timestamp).toDate() : null;
    final names = (m['assignedToNames'] as List?)?.join(', ') ?? '';
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xffdbe3ef))),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(m['title'] ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          _Pill(m['priority'] ?? 'Medium'),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: m['status'] ?? 'Open',
            underline: const SizedBox(),
            items: ['Open', 'In Progress', 'Done', 'Cancelled'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => v == null ? null : onStatus(v),
          ),
        ]),
        if ((m['description'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(m['description'])),
        if ((m['notes'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Notes: ${m['notes']}', style: const TextStyle(color: Color(0xff475569)))),
        const SizedBox(height: 10),
        Wrap(spacing: 16, runSpacing: 8, children: [
          _Info(Icons.people, names),
          _Info(Icons.person, 'By ${m['createdByName'] ?? ''}'),
          if (due != null) _Info(Icons.event, 'Due ${due.day}/${due.month}/${due.year}'),
        ]),
      ])),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  const _StatCard(this.title, this.value, this.icon);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    margin: const EdgeInsets.only(right: 10), padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xffdbe3ef))),
    child: Row(children: [Icon(icon, color: Colors.blue), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)), Text(title)])]),
  ));
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill(this.text);
  @override
  Widget build(BuildContext context) => Chip(label: Text(text), visualDensity: VisualDensity.compact);
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Info(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: Colors.blueGrey), const SizedBox(width: 5), Text(text, style: const TextStyle(color: Color(0xff475569)))]);
}

class AppUser {
  final String uid, name, email, role, companyId;
  AppUser({required this.uid, required this.name, required this.email, required this.role, required this.companyId});
  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> d, String companyId) {
    final m = d.data() ?? {};
    return AppUser(
      uid: (m['uid'] ?? d.id).toString(),
      name: (m['name'] ?? m['displayName'] ?? m['fullName'] ?? '').toString(),
      email: (m['email'] ?? '').toString(),
      role: (m['role'] ?? '').toString(),
      companyId: companyId,
    );
  }
}
