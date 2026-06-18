import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MeetingListScreen extends StatefulWidget {
  final String companyId;
  final String currentUserUid;
  final String currentUserName;
  final String currentUserEmail;

  const MeetingListScreen({
    super.key,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserName,
    required this.currentUserEmail,
  });

  @override
  State<MeetingListScreen> createState() => _MeetingListScreenState();
}

class _MeetingListScreenState extends State<MeetingListScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _meetingsRef =>
      _db.collection('companies').doc(widget.companyId).collection('meetings');

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _db.collection('companies').doc(widget.companyId).collection('users');

  CollectionReference<Map<String, dynamic>> get _notificationsRef => _db
      .collection('companies')
      .doc(widget.companyId)
      .collection('notifications');

  CollectionReference<Map<String, dynamic>> get _emailQueueRef => _db
      .collection('companies')
      .doc(widget.companyId)
      .collection('email_queue');

  CollectionReference<Map<String, dynamic>> get _remindersRef => _db
      .collection('companies')
      .doc(widget.companyId)
      .collection('meeting_reminders');

  CollectionReference<Map<String, dynamic>> get _countersRef =>
      _db.collection('companies').doc(widget.companyId).collection('counters');

  String _safeString(dynamic value) => (value ?? '').toString().trim();

  DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _formatDateTime(dynamic value) {
    final date = _toDate(value);
    if (date == null) return '-';
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  String _currentYear() => DateTime.now().year.toString();

  Future<String> _nextMeetingNumber(Transaction transaction) async {
    final year = _currentYear();
    final counterRef = _countersRef.doc('meeting_counter_$year');
    final counterSnap = await transaction.get(counterRef);

    int currentSeq = 1;
    if (counterSnap.exists) {
      currentSeq = ((counterSnap.data()?['sequence'] ?? 0) as num).toInt() + 1;
    }

    transaction.set(counterRef, <String, dynamic>{
      'sequence': currentSeq,
      'year': year,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return 'MTG-$year-${currentSeq.toString().padLeft(3, '0')}';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _meetingStream() {
    return _meetingsRef.snapshots();
  }

  Future<List<_Participant>> _loadUsers() async {
    final snap = await _usersRef.limit(300).get();

    final users = snap.docs
        .where((doc) {
          final data = doc.data();
          return data['isDeleted'] != true && data['isActive'] != false;
        })
        .map((doc) {
          final data = doc.data();
          final name = _safeString(
            data['displayName'] ??
                data['name'] ??
                data['employeeName'] ??
                data['fullName'] ??
                data['email'] ??
                doc.id,
          );
          return _Participant(
            uid: doc.id,
            name: name.isEmpty ? doc.id : name,
            email: _safeString(data['email']),
          );
        })
        .toList();

    if (!users.any((u) => u.uid == widget.currentUserUid)) {
      users.insert(
        0,
        _Participant(
          uid: widget.currentUserUid,
          name: widget.currentUserName.isEmpty
              ? 'Current User'
              : widget.currentUserName,
          email: widget.currentUserEmail,
        ),
      );
    }

    users.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return users;
  }

  List<_MeetingRecord> _recordsFromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final records = docs
        .map((doc) => _MeetingRecord.fromDoc(doc))
        .where((meeting) => meeting.isDeleted != true)
        .toList();

    records.sort((a, b) {
      final aDate =
          _toDate(a.startAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate =
          _toDate(b.startAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aDate.compareTo(bDate);
    });

    return records;
  }

  Future<void> _openCreateMeetingDialog() async {
    final titleCtrl = TextEditingController();
    final agendaCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    final teamsCtrl = TextEditingController();
    final zoomCtrl = TextEditingController();
    final meetingIdCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final dateCtrl = TextEditingController();
    final timeCtrl = TextEditingController();

    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    String selectedMeetingType = 'Online';
    final meetingTypes = [
      'Online',
      'Offline',
      'Customer Meeting',
      'Internal',
      'Review',
    ];
    final selectedParticipants = <String, _Participant>{};

    final usersFuture = _loadUsers();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return FutureBuilder<List<_Participant>>(
          future: usersFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const AlertDialog(
                content: SizedBox(
                  height: 90,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final users = snap.data ?? <_Participant>[];
            selectedParticipants.putIfAbsent(
              widget.currentUserUid,
              () => users.firstWhere(
                (u) => u.uid == widget.currentUserUid,
                orElse: () => _Participant(
                  uid: widget.currentUserUid,
                  name: widget.currentUserName,
                  email: widget.currentUserEmail,
                ),
              ),
            );

            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: const Text('Schedule Meeting'),
                  content: SizedBox(
                    width: 760,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: titleCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Meeting Title *',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: dateCtrl,
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Date *',
                                    border: OutlineInputBorder(),
                                    suffixIcon: Icon(
                                      Icons.calendar_month_outlined,
                                    ),
                                  ),
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      firstDate: DateTime.now().subtract(
                                        const Duration(days: 1),
                                      ),
                                      lastDate: DateTime(2100),
                                      initialDate:
                                          selectedDate ?? DateTime.now(),
                                    );
                                    if (picked != null) {
                                      selectedDate = picked;
                                      dateCtrl.text = DateFormat(
                                        'dd MMM yyyy',
                                      ).format(picked);
                                      setDialogState(() {});
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: timeCtrl,
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Time *',
                                    border: OutlineInputBorder(),
                                    suffixIcon: Icon(
                                      Icons.access_time_outlined,
                                    ),
                                  ),
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime:
                                          selectedTime ?? TimeOfDay.now(),
                                    );
                                    if (picked != null) {
                                      selectedTime = picked;
                                      timeCtrl.text = picked.format(context);
                                      setDialogState(() {});
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: selectedMeetingType,
                            items: meetingTypes
                                .map(
                                  (type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(type),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(
                                  () => selectedMeetingType = value,
                                );
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: 'Meeting Type',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: agendaCtrl,
                            minLines: 2,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Agenda',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: descriptionCtrl,
                            minLines: 2,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Participants *',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 220),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: users.length,
                              itemBuilder: (context, index) {
                                final user = users[index];
                                final checked = selectedParticipants
                                    .containsKey(user.uid);

                                return CheckboxListTile(
                                  value: checked,
                                  dense: true,
                                  title: Text(user.name),
                                  subtitle: user.email.isEmpty
                                      ? null
                                      : Text(user.email),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      if (value == true) {
                                        selectedParticipants[user.uid] = user;
                                      } else {
                                        selectedParticipants.remove(user.uid);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: teamsCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Microsoft Teams Meeting Link',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: zoomCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Zoom Meeting Link',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: meetingIdCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Meeting ID',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: passwordCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Password',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.event_available_outlined),
                      label: const Text('Schedule'),
                      onPressed: () async {
                        final title = titleCtrl.text.trim();

                        if (title.isEmpty ||
                            selectedDate == null ||
                            selectedTime == null ||
                            selectedParticipants.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Title, date, time and participants are required.',
                              ),
                            ),
                          );
                          return;
                        }

                        final startAt = DateTime(
                          selectedDate!.year,
                          selectedDate!.month,
                          selectedDate!.day,
                          selectedTime!.hour,
                          selectedTime!.minute,
                        );

                        try {
                          await _createMeeting(
                            title: title,
                            startAt: startAt,
                            meetingType: selectedMeetingType,
                            agenda: agendaCtrl.text.trim(),
                            description: descriptionCtrl.text.trim(),
                            teamsLink: teamsCtrl.text.trim(),
                            zoomLink: zoomCtrl.text.trim(),
                            meetingId: meetingIdCtrl.text.trim(),
                            password: passwordCtrl.text.trim(),
                            participants: selectedParticipants.values.toList(),
                          );

                          if (mounted) {
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Meeting scheduled successfully'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Meeting save failed: $e'),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );

    titleCtrl.dispose();
    agendaCtrl.dispose();
    descriptionCtrl.dispose();
    teamsCtrl.dispose();
    zoomCtrl.dispose();
    meetingIdCtrl.dispose();
    passwordCtrl.dispose();
    dateCtrl.dispose();
    timeCtrl.dispose();
  }

  Future<void> _createMeeting({
    required String title,
    required DateTime startAt,
    required String meetingType,
    required String agenda,
    required String description,
    required String teamsLink,
    required String zoomLink,
    required String meetingId,
    required String password,
    required List<_Participant> participants,
  }) async {
    final meetingRef = _meetingsRef.doc();

    await _db.runTransaction((transaction) async {
      final meetingNumber = await _nextMeetingNumber(transaction);
      final participantMaps = participants
          .map(
            (p) => <String, dynamic>{
              'uid': p.uid,
              'name': p.name,
              'email': p.email,
            },
          )
          .toList();

      final meetingPayload = <String, dynamic>{
        'companyId': widget.companyId,
        'meetingNumber': meetingNumber,
        'title': title,
        'startAt': Timestamp.fromDate(startAt),
        'meetingType': meetingType,
        'agenda': agenda,
        'description': description,
        'teamsLink': teamsLink,
        'zoomLink': zoomLink,
        'meetingId': meetingId,
        'password': password,
        'participantUids': participants.map((p) => p.uid).toList(),
        'participants': participantMaps,
        'createdByUid': widget.currentUserUid,
        'createdByName': widget.currentUserName,
        'createdByEmail': widget.currentUserEmail,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'Scheduled',
        'isDeleted': false,
      };

      transaction.set(meetingRef, meetingPayload);

      for (final participant in participants) {
        final linkText = teamsLink.isNotEmpty
            ? teamsLink
            : zoomLink.isNotEmpty
            ? zoomLink
            : 'Meeting link not added';

        transaction.set(_notificationsRef.doc(), <String, dynamic>{
          'companyId': widget.companyId,
          'recipientUid': participant.uid,
          'recipientName': participant.name,
          'recipientEmail': participant.email,
          'type': 'meeting_invitation',
          'module': 'meetings',
          'relatedModule': 'meetings',
          'relatedDocId': meetingRef.id,
          'route': 'salesMeetings',
          'title': 'Meeting invitation: $title',
          'message':
              '${DateFormat('dd MMM yyyy, hh:mm a').format(startAt)} • $linkText',
          'meetingDocId': meetingRef.id,
          'meetingNumber': meetingNumber,
          'meetingTitle': title,
          'meetingType': meetingType,
          'meetingStartAt': Timestamp.fromDate(startAt),
          'meetingLink': linkText,
          'meetingId': meetingId,
          'password': password,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'createdByUid': widget.currentUserUid,
          'createdByName': widget.currentUserName,
        });

        if (participant.email.isNotEmpty) {
          transaction.set(_emailQueueRef.doc(), <String, dynamic>{
            'companyId': widget.companyId,
            'toUid': participant.uid,
            'toName': participant.name,
            'toEmail': participant.email,
            'subject': 'Meeting invitation: $title',
            'body':
                'Meeting: $title\nType: $meetingType\nDate & Time: ${DateFormat('dd MMM yyyy, hh:mm a').format(startAt)}\nLink: $linkText\nMeeting ID: $meetingId\nPassword: $password\nAgenda: $agenda',
            'type': 'meeting_invitation',
            'meetingDocId': meetingRef.id,
            'meetingNumber': meetingNumber,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        final reminderRules = <Map<String, dynamic>>[
          {'label': '1 day before', 'minutesBefore': 1440},
          {'label': '1 hour before', 'minutesBefore': 60},
          {'label': '15 minutes before', 'minutesBefore': 15},
        ];

        for (final rule in reminderRules) {
          final minutesBefore = rule['minutesBefore'] as int;
          final scheduledAt = startAt.subtract(
            Duration(minutes: minutesBefore),
          );

          if (scheduledAt.isAfter(DateTime.now())) {
            transaction.set(_remindersRef.doc(), <String, dynamic>{
              'companyId': widget.companyId,
              'recipientUid': participant.uid,
              'recipientName': participant.name,
              'recipientEmail': participant.email,
              'type': 'meeting_reminder',
              'label': rule['label'],
              'meetingDocId': meetingRef.id,
              'meetingNumber': meetingNumber,
              'meetingTitle': title,
              'meetingType': meetingType,
              'meetingStartAt': Timestamp.fromDate(startAt),
              'meetingLink': linkText,
              'meetingId': meetingId,
              'password': password,
              'scheduledAt': Timestamp.fromDate(scheduledAt),
              'status': 'pending',
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    });
  }

  Future<void> _cancelMeeting(_MeetingRecord meeting) async {
    await _meetingsRef.doc(meeting.id).update(<String, dynamic>{
      'status': 'Cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
      'cancelledAt': FieldValue.serverTimestamp(),
      'cancelledByUid': widget.currentUserUid,
      'cancelledByName': widget.currentUserName,
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Cancelled':
        return const Color(0xFFDC2626);
      case 'Completed':
        return const Color(0xFF16A34A);
      case 'Scheduled':
      default:
        return const Color(0xFF2563EB);
    }
  }

  Widget _chip(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _meetingCard(_MeetingRecord meeting) {
    final link = meeting.teamsLink.isNotEmpty
        ? meeting.teamsLink
        : meeting.zoomLink.isNotEmpty
        ? meeting.zoomLink
        : '';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 780;

            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip(
                      meeting.meetingNumber.isEmpty
                          ? 'MEETING'
                          : meeting.meetingNumber,
                      const Color(0xFF0F172A),
                      Icons.confirmation_number_outlined,
                    ),
                    _chip(
                      meeting.status,
                      _statusColor(meeting.status),
                      Icons.event_available_outlined,
                    ),
                    _chip(
                      meeting.meetingType.isEmpty
                          ? 'Meeting'
                          : meeting.meetingType,
                      const Color(0xFF7C3AED),
                      Icons.category_outlined,
                    ),
                    _chip(
                      '${meeting.participants.length} Participants',
                      const Color(0xFF0891B2),
                      Icons.groups_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  meeting.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _info(
                      Icons.schedule_outlined,
                      _formatDateTime(meeting.startAt),
                    ),
                    if (meeting.meetingId.isNotEmpty)
                      _info(Icons.tag_outlined, 'ID: ${meeting.meetingId}'),
                    if (meeting.password.isNotEmpty)
                      _info(
                        Icons.lock_outline,
                        'Password: ${meeting.password}',
                      ),
                  ],
                ),
                if (meeting.agenda.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Agenda: ${meeting.agenda}',
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
                if (meeting.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    meeting.description,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
                if (link.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SelectableText(
                    link,
                    style: const TextStyle(
                      color: Color(0xFF2563EB),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: meeting.participants
                      .map(
                        (p) => Chip(
                          label: Text(p.name),
                          avatar: const Icon(Icons.person_outline, size: 16),
                        ),
                      )
                      .toList(),
                ),
              ],
            );

            final actions = Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: meeting.status == 'Cancelled'
                      ? null
                      : () => _cancelMeeting(meeting),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel'),
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [content, const SizedBox(height: 12), actions],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: content),
                const SizedBox(width: 12),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _info(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF64748B)),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF475569),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(List<_MeetingRecord> meetings) {
    final now = DateTime.now();
    final upcoming = meetings.where((m) {
      final date = _toDate(m.startAt);
      return m.status != 'Cancelled' && date != null && date.isAfter(now);
    }).length;
    final today = meetings.where((m) {
      final date = _toDate(m.startAt);
      return m.status != 'Cancelled' &&
          date != null &&
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).length;
    final cancelled = meetings.where((m) => m.status == 'Cancelled').length;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _summaryCard(
          'Upcoming',
          '$upcoming',
          Icons.upcoming_outlined,
          const Color(0xFF2563EB),
        ),
        _summaryCard(
          'Today',
          '$today',
          Icons.today_outlined,
          const Color(0xFF0891B2),
        ),
        _summaryCard(
          'Cancelled',
          '$cancelled',
          Icons.cancel_outlined,
          const Color(0xFFDC2626),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _meetingStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Meeting loading error: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final meetings = _recordsFromDocs(snapshot.data!.docs);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: _openCreateMeetingDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Schedule Meeting'),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _buildSummary(meetings),
                    ],
                  ),
                ),
              ),
              if (meetings.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'No meetings scheduled yet.',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
                  sliver: SliverList.builder(
                    itemCount: meetings.length,
                    itemBuilder: (context, index) =>
                        _meetingCard(meetings[index]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MeetingRecord {
  final String id;
  final String meetingNumber;
  final String title;
  final dynamic startAt;
  final String meetingType;
  final String agenda;
  final String description;
  final String teamsLink;
  final String zoomLink;
  final String meetingId;
  final String password;
  final String status;
  final List<_Participant> participants;
  final bool isDeleted;

  _MeetingRecord({
    required this.id,
    required this.meetingNumber,
    required this.title,
    required this.startAt,
    required this.meetingType,
    required this.agenda,
    required this.description,
    required this.teamsLink,
    required this.zoomLink,
    required this.meetingId,
    required this.password,
    required this.status,
    required this.participants,
    required this.isDeleted,
  });

  factory _MeetingRecord.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    String str(dynamic value) => (value ?? '').toString().trim();

    final rawParticipants = data['participants'];
    final participants = <_Participant>[];

    if (rawParticipants is List) {
      for (final item in rawParticipants) {
        if (item is Map) {
          participants.add(
            _Participant(
              uid: str(item['uid']),
              name: str(item['name']).isEmpty
                  ? 'Participant'
                  : str(item['name']),
              email: str(item['email']),
            ),
          );
        }
      }
    }

    return _MeetingRecord(
      id: doc.id,
      meetingNumber: str(data['meetingNumber']),
      title: str(data['title']).isEmpty
          ? 'Untitled Meeting'
          : str(data['title']),
      startAt: data['startAt'],
      meetingType: str(data['meetingType']).isEmpty
          ? 'Online'
          : str(data['meetingType']),
      agenda: str(data['agenda']),
      description: str(data['description']),
      teamsLink: str(data['teamsLink']),
      zoomLink: str(data['zoomLink']),
      meetingId: str(data['meetingId']),
      password: str(data['password']),
      status: str(data['status']).isEmpty ? 'Scheduled' : str(data['status']),
      participants: participants,
      isDeleted: data['isDeleted'] == true,
    );
  }
}

class _Participant {
  final String uid;
  final String name;
  final String email;

  _Participant({required this.uid, required this.name, required this.email});
}
