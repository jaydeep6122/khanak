import 'package:flutter/material.dart';
import 'package:khanak/global/themes.dart';

class LoadingIndicator extends StatelessWidget {
  final String? message;

  /// Placeholder rows shaped like list items instead of a spinner.
  final bool isShimmer;

  const LoadingIndicator({super.key, this.message, this.isShimmer = false});

  @override
  Widget build(BuildContext context) {
    if (isShimmer) return const SkeletonList();

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          if (message != null) ...[
            const SizedBox(height: AppTheme.spaceLg),
            Text(message!, style: context.text.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// Pulsing placeholder rows while a list loads.
class SkeletonList extends StatefulWidget {
  final int itemCount;
  final EdgeInsetsGeometry padding;

  const SkeletonList({
    super.key,
    this.itemCount = 6,
    this.padding = const EdgeInsets.all(AppTheme.spaceLg),
  });

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_controller),
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: widget.padding,
        itemCount: widget.itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: AppTheme.spaceMd),
        itemBuilder: (context, index) => Container(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: colors.border),
          ),
          child: const Row(
            children: [
              SkeletonBox(width: 40, height: 40, radius: 20),
              SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 160, height: 14),
                    SizedBox(height: AppTheme.spaceSm),
                    SkeletonBox(width: 100, height: 12),
                  ],
                ),
              ),
              SkeletonBox(width: 64, height: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = AppTheme.radiusXs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
