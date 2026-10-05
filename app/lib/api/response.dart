import 'package:dio/dio.dart';

// Every successful response is `{ success: true, data, pagination? }`.

Map<String, dynamic> dataOf(Response<dynamic> response) =>
    Map<String, dynamic>.from(response.data['data'] as Map);

List<Map<String, dynamic>> listOf(Response<dynamic> response) =>
    (response.data['data'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

/// One page of a list endpoint.
class PageJson {
  final List<Map<String, dynamic>> items;
  final int limit;
  final int offset;

  /// Null when the server could not count (a page past the end).
  final int? total;

  const PageJson({
    required this.items,
    required this.limit,
    required this.offset,
    this.total,
  });

  factory PageJson.of(Response<dynamic> response) {
    final pagination = Map<String, dynamic>.from(
      response.data['pagination'] as Map,
    );
    return PageJson(
      items: listOf(response),
      limit: (pagination['limit'] as num).toInt(),
      offset: (pagination['offset'] as num).toInt(),
      total: (pagination['total'] as num?)?.toInt(),
    );
  }
}

/// Query parameters without null or empty values.
Map<String, dynamic> queryOf(Map<String, Object?> params) => {
  for (final entry in params.entries)
    if (entry.value != null && entry.value.toString().isNotEmpty)
      entry.key: entry.value.toString(),
};

String factoryPath(String factoryId) => '/factories/$factoryId';
