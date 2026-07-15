import 'package:flutter/material.dart';

const Color invitePrimaryColor = Color(0xFF17324D);
const Color inviteAccentColor = Color(0xFF3B82F6);
const Color inviteScaffoldBgColor = Color(0xFFF4F7FB);
const Color inviteCardBorderColor = Color(0xFFE2E8F0);
const Color inviteMutedTextColor = Color(0xFF64748B);
const Color inviteHeadingTextColor = Color(0xFF0F172A);

const List<String> inviteDepartmentOptions = [
  'Sales',
  'CRM',
  'Inventory',
  'Purchase',
  'Dispatch',
  'Finance',
  'Administration',
  'Management',
  'Service',
];

const Map<String, List<String>> inviteDesignationOptionsByDepartment = {
  'Sales': [
    'Sales Executive',
    'Senior Sales Executive',
    'Area Sales Manager',
    'Regional Sales Manager',
    'Vice President - Business Development',
  ],
  'CRM': ['CRM Executive', 'CRM Coordinator', 'Customer Relationship Manager'],
  'Inventory': [
    'Store Executive',
    'Inventory Executive',
    'Warehouse Executive',
    'Inventory Manager',
  ],
  'Purchase': [
    'Purchase Executive',
    'Senior Purchase Executive',
    'Procurement Manager',
  ],
  'Dispatch': [
    'Dispatch Executive',
    'Logistics Coordinator',
    'Dispatch Manager',
  ],
  'Finance': ['Accounts Executive', 'Senior Accountant', 'Finance Manager'],
  'Administration': [
    'Admin Executive',
    'Office Administrator',
    'HR Executive',
    'Admin Manager',
  ],
  'Management': [
    'Chief Executive Officer (CEO)',
    'Managing Director (MD)',
    'General Manager',
    'Business Head',
    'Vice President',
    'Director',
  ],
  'Service': [
    'Service Engineer',
    'Service Technician',
    'Service Coordinator',
    'Service Manager',
  ],
};
