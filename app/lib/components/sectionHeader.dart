import 'package:flutter/material.dart';
import 'package:khanak/global/themes.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onActionTap,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: AppTheme.spaceXs),
                child: Text(
                  title,
                  style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            if (actionLabel != null)
              TextButton(
                onPressed: onActionTap,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceSm),
                  minimumSize: const Size(0, 36),
                ),
                child: Text(actionLabel!),
              ),
          ],
        ),
      ),
    );
  }
}
