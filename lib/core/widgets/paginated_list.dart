import 'package:flutter/material.dart';

class PaginatedList<T> extends StatefulWidget {
  const PaginatedList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.rowsPerPage = 10,
    this.separatorBuilder,
    this.emptyBuilder,
  }) : assert(rowsPerPage > 0);

  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final int rowsPerPage;
  final Widget Function(BuildContext context, int index)? separatorBuilder;
  final WidgetBuilder? emptyBuilder;

  @override
  State<PaginatedList<T>> createState() => _PaginatedListState<T>();
}

class _PaginatedListState<T> extends State<PaginatedList<T>> {
  int _currentPage = 0;

  @override
  void didUpdateWidget(covariant PaginatedList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final lastPage = widget.items.isEmpty
        ? 0
        : (widget.items.length - 1) ~/ widget.rowsPerPage;
    if (_currentPage > lastPage) _currentPage = lastPage;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return widget.emptyBuilder?.call(context) ?? const SizedBox.shrink();
    }

    final start = _currentPage * widget.rowsPerPage;
    final end = (start + widget.rowsPerPage).clamp(0, widget.items.length);
    final children = <Widget>[];
    for (var index = start; index < end; index++) {
      if (index > start && widget.separatorBuilder != null) {
        children.add(widget.separatorBuilder!(context, index - start - 1));
      }
      children.add(widget.itemBuilder(context, widget.items[index], index));
    }

    if (widget.items.length > widget.rowsPerPage) {
      children.add(
        _PaginationControls(
          firstItem: start + 1,
          lastItem: end,
          itemCount: widget.items.length,
          canGoBack: _currentPage > 0,
          canGoForward: end < widget.items.length,
          onPrevious: () => setState(() => _currentPage--),
          onNext: () => setState(() => _currentPage++),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _PaginationControls extends StatelessWidget {
  const _PaginationControls({
    required this.firstItem,
    required this.lastItem,
    required this.itemCount,
    required this.canGoBack,
    required this.canGoForward,
    required this.onPrevious,
    required this.onNext,
  });

  final int firstItem;
  final int lastItem;
  final int itemCount;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('$firstItem–$lastItem of $itemCount'),
          IconButton(
            tooltip: 'Previous page',
            onPressed: canGoBack ? onPrevious : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: canGoForward ? onNext : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}
