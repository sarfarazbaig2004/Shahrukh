import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:QUIK/modules/crm/customers/customer_duplicate_helper.dart';

enum CustomerDuplicateLookupType { name, phone, email, gst }

class CustomerDuplicateSuggestion {
  const CustomerDuplicateSuggestion({
    required this.reference,
    required this.name,
    required this.customerCode,
    required this.gstNumber,
    required this.mobileNumber,
    required this.city,
    required this.status,
  });

  final DocumentReference<Map<String, dynamic>> reference;
  final String name;
  final String customerCode;
  final String gstNumber;
  final String mobileNumber;
  final String city;
  final String status;

  bool get isActive => status.toLowerCase() == 'active';

  factory CustomerDuplicateSuggestion.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final addresses = data['addresses'];
    String city = _text(data['city']);

    if (city.isEmpty && addresses is List) {
      Map<dynamic, dynamic>? selectedAddress;
      for (final address in addresses) {
        if (address is Map && address['isPrimary'] == true) {
          selectedAddress = address;
          break;
        }
      }
      if (selectedAddress == null &&
          addresses.isNotEmpty &&
          addresses.first is Map) {
        selectedAddress = addresses.first as Map;
      }
      city = _text(selectedAddress?['city']);
    }

    final rawStatus = _text(data['status']).toLowerCase();
    final explicitlyInactive =
        data['isActive'] == false ||
        rawStatus == 'inactive' ||
        rawStatus == 'deleted';

    return CustomerDuplicateSuggestion(
      reference: document.reference,
      name: _firstText(data, const [
        'companyName',
        'name',
      ], fallback: 'Unnamed customer'),
      customerCode: _firstText(data, const ['customerCode', 'code']),
      gstNumber: _firstText(data, const [
        'gst',
        'gstNumberNormalized',
        'gstNormalized',
      ]),
      mobileNumber: _firstText(data, const [
        'phone',
        'companyPhone',
        'phoneNumberNormalized',
      ]),
      city: city,
      status: explicitlyInactive ? 'Inactive' : 'Active',
    );
  }
}

class CustomerDuplicateSearchService {
  CustomerDuplicateSearchService(this._customers);

  static const int _queryLimit = 12;
  static const int _resultLimit = 5;
  static const Duration _cacheLifetime = Duration(minutes: 1);

  final CollectionReference<Map<String, dynamic>> _customers;
  final Map<String, _CachedSuggestions> _cache = {};

  Future<List<CustomerDuplicateSuggestion>> search({
    required CustomerDuplicateLookupType type,
    required String value,
    String? excludedCustomerId,
  }) async {
    final normalized = _normalizedValue(type, value);
    if (normalized.isEmpty ||
        (type == CustomerDuplicateLookupType.name && normalized.length < 3) ||
        (type == CustomerDuplicateLookupType.phone && normalized.length < 10)) {
      return const [];
    }

    final cacheKey = '${type.name}:$normalized:${excludedCustomerId ?? ''}';
    final cached = _cache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.createdAt) < _cacheLifetime) {
      return cached.suggestions;
    }

    final documents = type == CustomerDuplicateLookupType.name
        ? await _searchName(normalized)
        : await _searchExact(type, normalized);

    final suggestions = documents
        .where((document) => document.id != excludedCustomerId)
        .where((document) => document.data()['isDeleted'] != true)
        .where(
          (document) => _documentMatches(type, normalized, document.data()),
        )
        .take(_resultLimit)
        .map(CustomerDuplicateSuggestion.fromDocument)
        .toList(growable: false);

    if (_cache.length >= 100) _cache.remove(_cache.keys.first);
    _cache[cacheKey] = _CachedSuggestions(DateTime.now(), suggestions);
    return suggestions;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _searchName(
    String normalized,
  ) async {
    final searchToken = normalized
        .split(' ')
        .where((part) => part.isNotEmpty)
        .reduce((a, b) => a.length >= b.length ? a : b);

    try {
      final snapshot = await _customers
          .where('searchKeywords', arrayContains: searchToken)
          .limit(_queryLimit)
          .get();
      return snapshot.docs;
    } on FirebaseException {
      return const [];
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _searchExact(
    CustomerDuplicateLookupType type,
    String normalized,
  ) async {
    final queries =
        <Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>>[];

    switch (type) {
      case CustomerDuplicateLookupType.phone:
        final variants = <String>{
          normalized,
          '0$normalized',
          '91$normalized',
        }.toList();
        for (final field in const [
          'phoneLast10',
          'phoneNumberNormalized',
          'phoneNormalized',
          'phoneDigitsOnly',
        ]) {
          queries.add(_safeExactQuery(field, variants));
        }
        break;
      case CustomerDuplicateLookupType.email:
        for (final field in const ['emailNormalized', 'emailLower']) {
          queries.add(_safeExactQuery(field, [normalized]));
        }
        break;
      case CustomerDuplicateLookupType.gst:
        for (final field in const [
          'gstNumberNormalized',
          'gstNormalized',
          'gst',
        ]) {
          queries.add(_safeExactQuery(field, [normalized]));
        }
        break;
      case CustomerDuplicateLookupType.name:
        break;
    }

    final queryResults = await Future.wait(queries);
    final unique = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final documents in queryResults) {
      for (final document in documents) {
        unique[document.id] = document;
      }
    }
    return unique.values.toList(growable: false);
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _safeExactQuery(
    String field,
    List<String> values,
  ) async {
    try {
      Query<Map<String, dynamic>> query = _customers;
      query = values.length == 1
          ? query.where(field, isEqualTo: values.first)
          : query.where(field, whereIn: values);
      return (await query.limit(_queryLimit).get()).docs;
    } on FirebaseException {
      return const [];
    }
  }

  static String _normalizedValue(
    CustomerDuplicateLookupType type,
    String value,
  ) {
    switch (type) {
      case CustomerDuplicateLookupType.name:
        return normalizeCustomerName(value);
      case CustomerDuplicateLookupType.phone:
        return normalizeCustomerPhoneLast10(value);
      case CustomerDuplicateLookupType.email:
        return normalizeEmail(value);
      case CustomerDuplicateLookupType.gst:
        return normalizeGST(value);
    }
  }

  static bool _documentMatches(
    CustomerDuplicateLookupType type,
    String normalized,
    Map<String, dynamic> data,
  ) {
    switch (type) {
      case CustomerDuplicateLookupType.name:
        final name = normalizeCustomerName(
          data['customerNameNormalized'] ??
              data['companyNameNormalized'] ??
              data['companyName'] ??
              data['name'],
        );
        final nameTokens = name.split(' ').where((part) => part.isNotEmpty);
        final queryTokens = normalized
            .split(' ')
            .where((part) => part.isNotEmpty);
        return queryTokens.every(
          (queryToken) =>
              nameTokens.any((nameToken) => nameToken.startsWith(queryToken)),
        );
      case CustomerDuplicateLookupType.phone:
        return const [
          'phoneLast10',
          'phoneNumberNormalized',
          'phoneNormalized',
          'phoneDigitsOnly',
          'phone',
          'companyPhone',
        ].any(
          (field) => normalizeCustomerPhoneLast10(data[field]) == normalized,
        );
      case CustomerDuplicateLookupType.email:
        return const [
          'emailNormalized',
          'emailLower',
          'email',
          'businessEmail',
        ].any((field) => normalizeEmail(data[field]) == normalized);
      case CustomerDuplicateLookupType.gst:
        return const [
          'gstNumberNormalized',
          'gstNormalized',
          'gst',
        ].any((field) => normalizeGST(data[field]) == normalized);
    }
  }
}

class _CachedSuggestions {
  const _CachedSuggestions(this.createdAt, this.suggestions);

  final DateTime createdAt;
  final List<CustomerDuplicateSuggestion> suggestions;
}

String _text(dynamic value) => (value ?? '').toString().trim();

String _firstText(
  Map<String, dynamic> data,
  List<String> fields, {
  String fallback = '—',
}) {
  for (final field in fields) {
    final value = _text(data[field]);
    if (value.isNotEmpty) return value;
  }
  return fallback;
}
