import 'package:khanak/api/response.dart';

/// Items loaded so far for a list that pages in more as you scroll.
class Paged<T> {
  final List<T> items;
  final int? total;
  final bool hasMore;

  const Paged({required this.items, this.total, required this.hasMore});

  const Paged.empty() : items = const [], total = 0, hasMore = false;

  /// First page, or [previous] with the next page appended.
  factory Paged.fromPage(
    PageJson page,
    T Function(Map<String, dynamic>) parse, {
    Paged<T>? previous,
  }) {
    final items = [...?previous?.items, ...page.items.map(parse)];
    final hasMore = page.total == null
        ? page.items.length >= page.limit
        : items.length < page.total!;
    return Paged(items: items, total: page.total, hasMore: hasMore);
  }

  bool get isEmpty => items.isEmpty;
  int get nextOffset => items.length;
}
