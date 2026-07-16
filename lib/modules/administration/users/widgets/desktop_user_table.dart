import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:QUIK/modules/administration/users/helpers/user_management_constants.dart';
import 'package:QUIK/modules/administration/users/helpers/user_management_formatters.dart';
import 'package:QUIK/modules/administration/users/widgets/mini_badge.dart';

typedef UserDoc = QueryDocumentSnapshot<Map<String, dynamic>>;

class DesktopUserTable extends StatefulWidget {
  final List<UserDoc> pageDocs;
  final String currentUid;

  final bool sortAscending;
  final int? sortColumnIndex;

  final void Function(int columnIndex, String field) onSort;

  final Future<void> Function(UserDoc doc) onView;
  final Future<void> Function(UserDoc doc) onEdit;
  final Future<void> Function(UserDoc doc) onToggle;
  final Future<void> Function(UserDoc doc) onDelete;
  final Future<void> Function(UserDoc doc)? onRestore;
  final Future<void> Function(UserDoc doc)? onPermanentDelete;

  const DesktopUserTable({
    super.key,
    required this.pageDocs,
    required this.currentUid,
    required this.sortAscending,
    required this.sortColumnIndex,
    required this.onSort,
    required this.onView,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    this.onRestore,
    this.onPermanentDelete,
  });
  @override
  State<DesktopUserTable> createState() => _DesktopUserTableState();
}

class _DesktopUserTableState extends State<DesktopUserTable> {
  final ScrollController _horizontalScrollController = ScrollController();
  final FocusNode _tableFocusNode = FocusNode(debugLabel: 'DesktopUserTable');

  static const double _keyboardScrollStep = 160;

  List<UserDoc> get pageDocs => widget.pageDocs;
  String get currentUid => widget.currentUid;
  bool get sortAscending => widget.sortAscending;
  int? get sortColumnIndex => widget.sortColumnIndex;

  void Function(int, String) get onSort => widget.onSort;
  Future<void> Function(UserDoc) get onView => widget.onView;
  Future<void> Function(UserDoc) get onEdit => widget.onEdit;
  Future<void> Function(UserDoc) get onToggle => widget.onToggle;
  Future<void> Function(UserDoc) get onDelete => widget.onDelete;

  Future<void> Function(UserDoc)? get onRestore => widget.onRestore;
  Future<void> Function(UserDoc)? get onPermanentDelete =>
      widget.onPermanentDelete;

  KeyEventResult _handleHorizontalKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || !_horizontalScrollController.hasClients) {
      return KeyEventResult.ignored;
    }

    double delta;

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      delta = -_keyboardScrollStep;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      delta = _keyboardScrollStep;
    } else {
      return KeyEventResult.ignored;
    }

    final position = _horizontalScrollController.position;

    final targetOffset = (_horizontalScrollController.offset + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();

    _horizontalScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );

    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _tableFocusNode.dispose();
    super.dispose();
  }

  static const double _tableMinWidth = 1040;

  String _normalizeText(String? value) {
    return (value ?? '').trim();
  }

  String _normalizeRole(String? value) {
    return _normalizeText(value).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: cardBorderColor),
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Focus(
          focusNode: _tableFocusNode,
          autofocus: true,
          onKeyEvent: _handleHorizontalKeyEvent,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _tableFocusNode.requestFocus(),
            child: Scrollbar(
              controller: _horizontalScrollController,
              thumbVisibility: true,
              trackVisibility: true,
              interactive: true,
              scrollbarOrientation: ScrollbarOrientation.bottom,
              radius: const Radius.circular(999),
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: _tableMinWidth),
                  child: Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: cardBorderColor),
                    child: DataTable(
                      sortAscending: sortAscending,
                      sortColumnIndex: sortColumnIndex,
                      headingRowHeight: 50,
                      dataRowMinHeight: 64,
                      dataRowMaxHeight: 70,
                      columnSpacing: 20,
                      horizontalMargin: 16,
                      dividerThickness: 0.7,
                      headingRowColor: WidgetStateProperty.all(
                        const Color(0xFFF8FAFC),
                      ),
                      columns: _buildColumns(),
                      rows: pageDocs.map(_buildRow).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<DataColumn> _buildColumns() {
    const headingStyle = TextStyle(
      fontWeight: FontWeight.w700,
      color: primaryColor,
      fontSize: 13,
    );

    return [
      DataColumn(
        label: const Text('User', style: headingStyle),
        onSort: (_, __) => onSort(0, 'displayName'),
      ),
      DataColumn(
        label: const Text('Role', style: headingStyle),
        onSort: (_, __) => onSort(1, 'role'),
      ),
      DataColumn(
        label: const Text('Department', style: headingStyle),
        onSort: (_, __) => onSort(2, 'department'),
      ),
      DataColumn(
        label: const Text('Status', style: headingStyle),
        onSort: (_, __) => onSort(3, 'status'),
      ),
      DataColumn(
        label: const Text('Last Login', style: headingStyle),
        onSort: (_, __) => onSort(4, 'lastLoginAt'),
      ),
      DataColumn(
        label: const Text('Created', style: headingStyle),
        onSort: (_, __) => onSort(5, 'createdAt'),
      ),
      const DataColumn(label: Text('Actions', style: headingStyle)),
    ];
  }

  DataRow _buildRow(UserDoc doc) {
    final data = doc.data();

    final displayName = _readDisplayName(data);
    final email = _normalizeText(data['email']);
    final role = _normalizeRole(data['role']);
    final department = _normalizeText(data['department']);
    final designation = _normalizeText(data['designation']);

    final isActive = (data['isActive'] ?? true) == true;
    final isDeleted = (data['isDeleted'] ?? false) == true;
    final storedStatus = _normalizeText(data['status']);

    final isSelfUser = doc.id == currentUid;

    final statusText = storedStatus.isNotEmpty
        ? statusLabelFromValue(storedStatus)
        : statusLabel(isActive: isActive, isDeleted: isDeleted);

    final statusClr = storedStatus.isNotEmpty
        ? statusColorFromValue(storedStatus)
        : statusColor(isActive: isActive, isDeleted: isDeleted);

    return DataRow(
      cells: [
        DataCell(
          _buildUserCell(
            displayName: displayName,
            email: email,
            designation: designation,
            isSelfUser: isSelfUser,
          ),
        ),
        DataCell(
          MiniBadge(
            text: formatRole(role),
            textColor: roleColor(role),
            backgroundColor: roleColor(role).withValues(alpha: 0.10),
          ),
        ),
        DataCell(_textCell(formatDepartment(department), width: 150)),
        DataCell(
          MiniBadge(
            text: statusText,
            textColor: statusClr,
            backgroundColor: statusClr.withValues(alpha: 0.10),
          ),
        ),
        DataCell(_textCell(formatTimestamp(data['lastLoginAt']), width: 135)),
        DataCell(_textCell(formatTimestamp(data['createdAt']), width: 135)),
        DataCell(
          _buildActions(
            doc: doc,
            isActive: isActive,
            isDeleted: isDeleted,
            isSelfUser: isSelfUser,
          ),
        ),
      ],
    );
  }

  Widget _buildUserCell({
    required String displayName,
    required String email,
    required String designation,
    required bool isSelfUser,
  }) {
    final safeName = displayName.trim().isEmpty ? 'Unnamed User' : displayName;
    final secondaryText = email.isNotEmpty
        ? email
        : (designation.isEmpty ? '-' : designation);

    return SizedBox(
      width: 300,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Text(
              safeName[0].toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: primaryColor,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        safeName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    if (isSelfUser) ...[
                      const SizedBox(width: 6),
                      const MiniBadge(
                        text: 'YOU',
                        textColor: accentColor,
                        backgroundColor: Color(0x1A2563EB),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  secondaryText,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: mutedTextColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _textCell(String value, {required double width}) {
    final safeValue = value.trim().isEmpty ? '-' : value;

    return SizedBox(
      width: width,
      child: Text(
        safeValue,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: const TextStyle(color: Color(0xFF475569), fontSize: 12.5),
      ),
    );
  }

  Widget _buildActions({
    required UserDoc doc,
    required bool isActive,
    required bool isDeleted,
    required bool isSelfUser,
  }) {
    final canToggle = !isSelfUser && !isDeleted;
    final canDelete = !isSelfUser && !isDeleted;
    final canRestore = !isSelfUser && isDeleted && onRestore != null;
    final canPermanentDelete =
        !isSelfUser && isDeleted && onPermanentDelete != null;

    return SizedBox(
      width: 110,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Transform.scale(
            scale: 0.84,
            child: Switch(
              value: isDeleted ? false : isActive,
              onChanged: canToggle
                  ? (_) async {
                await onToggle(doc);
              }
                  : null,
              activeThumbColor: primaryColor,
            ),
          ),
          const SizedBox(width: 2),
          PopupMenuButton<String>(
            tooltip: 'Actions',
            constraints: const BoxConstraints(minWidth: 180),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) async {
              switch (value) {
                case 'view':
                  await onView(doc);
                  break;
                case 'edit':
                  await onEdit(doc);
                  break;
                case 'delete':
                  if (canDelete) {
                    await onDelete(doc);
                  }
                  break;
                case 'restore':
                  if (canRestore) {
                    await onRestore!(doc);
                  }
                  break;
                case 'permanentDelete':
                  if (canPermanentDelete) {
                    await onPermanentDelete!(doc);
                  }
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'view', child: Text('View')),
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              if (isDeleted) ...[
                PopupMenuItem(
                  value: 'restore',
                  enabled: canRestore,
                  child: Text(
                    'Restore User',
                    style: TextStyle(
                      color: canRestore ? successColor : mutedTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                PopupMenuItem(
                  value: 'permanentDelete',
                  enabled: canPermanentDelete,
                  child: Text(
                    'Permanently Delete',
                    style: TextStyle(
                      color: canPermanentDelete ? dangerColor : mutedTextColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ] else
                PopupMenuItem(
                  value: 'delete',
                  enabled: canDelete,
                  child: Text(
                    'Delete',
                    style: TextStyle(
                      color: canDelete ? dangerColor : mutedTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: cardBorderColor),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.more_horiz,
                size: 16,
                color: primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _readDisplayName(Map<String, dynamic> data) {
    final displayName = _normalizeText(data['displayName']);
    if (displayName.isNotEmpty) return displayName;

    final legacyName = _normalizeText(data['name']);
    if (legacyName.isNotEmpty) return legacyName;

    return 'Unnamed User';
  }
}