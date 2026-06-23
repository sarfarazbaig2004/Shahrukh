import 'package:flutter/material.dart';

class TaskListScreen extends StatelessWidget {
  final String? companyId;
  final String? userUid;
  final String? currentUserId;
  final String? currentUserUid;
  final String? currentUserName;
  final String? userName;
  final String? userEmail;
  final String? currentUserEmail;
  final String? role;
  final String? currentUserRole;

  const TaskListScreen({
    super.key,
    this.companyId,
    this.userUid,
    this.currentUserId,
    this.currentUserUid,
    this.currentUserName,
    this.userName,
    this.userEmail,
    this.currentUserEmail,
    this.role,
    this.currentUserRole,
  });

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Task module has been removed.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
