import 'package:flutter/material.dart';
import 'package:khanak/components/errorWidget.dart';
import 'package:khanak/components/loadingIndicator.dart';
import 'package:khanak/global/themes.dart';

/// A pull-to-refresh list that loads the next page near the bottom.
class PagedListView<T> extends StatefulWidget {
  final List<T> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Used instead of [itemBuilder] when a row depends on its neighbours
  /// (grouping by date, rounding the first and last rows).
  final Widget Function(BuildContext context, int index)? indexedItemBuilder;
  final Widget emptyState;

  /// Scrolls with the list (filters, summaries).
  final Widget? header;
  final EdgeInsetsGeometry padding;
  final double spacing;

  const PagedListView({
    super.key,
    required this.items,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.onRefresh,
    required this.onLoadMore,
    required this.itemBuilder,
    required this.emptyState,
    this.error,
    this.header,
    this.indexedItemBuilder,
    this.padding = const EdgeInsets.fromLTRB(
      AppTheme.spaceLg,
      0,
      AppTheme.spaceLg,
      AppTheme.fabClearance,
    ),
    this.spacing = AppTheme.spaceSm,
  });

  @override
  State<PagedListView<T>> createState() => _PagedListViewState<T>();
}

class _PagedListViewState<T> extends State<PagedListView<T>> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    if (_controller.position.extentAfter < 600 &&
        widget.hasMore &&
        !widget.isLoading &&
        !widget.isLoadingMore) {
      widget.onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final header = widget.header;

    Widget body;
    if (widget.isLoading && widget.items.isEmpty) {
      body = const SliverFillRemaining(child: SkeletonList());
    } else if (widget.error != null && widget.items.isEmpty) {
      body = SliverFillRemaining(
        hasScrollBody: false,
        child: AppErrorWidget(errorMessage: widget.error!, onRetry: widget.onRefresh),
      );
    } else if (widget.items.isEmpty) {
      body = SliverFillRemaining(hasScrollBody: false, child: widget.emptyState);
    } else {
      body = SliverPadding(
        padding: widget.padding,
        sliver: SliverList.separated(
          itemCount: widget.items.length + 1,
          separatorBuilder: (_, _) => SizedBox(height: widget.spacing),
          itemBuilder: (context, index) {
            if (index < widget.items.length) {
              return widget.indexedItemBuilder?.call(context, index) ??
                  widget.itemBuilder(context, widget.items[index]);
            }
            return SizedBox(
              height: 48,
              child: widget.isLoadingMore
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  : null,
            );
          },
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: CustomScrollView(
        controller: _controller,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (header != null) SliverToBoxAdapter(child: header),
          body,
        ],
      ),
    );
  }
}
