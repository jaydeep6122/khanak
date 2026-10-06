import 'package:flutter/material.dart';
import 'package:khanak/global/themes.dart';

/// A small grey caption above a group, with an optional link on the right.
class GroupCaption extends StatelessWidget {
  final String text;
  final String? action;
  final VoidCallback? onAction;

  const GroupCaption(this.text, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spaceXs, 0, 0, AppTheme.spaceSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Text(text, style: context.text.labelMedium)),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: AppTheme.spaceMd),
                child: Text(
                  action!,
                  style: context.text.labelMedium?.copyWith(color: context.colors.primary, fontSize: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A bold section title, as on the home screen ("હિસાબ   બધું જુઓ").
class SectionTitle extends StatelessWidget {
  final String text;
  final String? action;
  final VoidCallback? onAction;

  const SectionTitle(this.text, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spaceXs, 0, 0, AppTheme.spaceMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Text(text, style: context.text.titleLarge)),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: AppTheme.spaceMd),
                child: Text(
                  action!,
                  style: context.text.labelLarge?.copyWith(color: context.colors.primary, fontSize: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Rows stacked in one white card with hairlines between them, like an iOS
/// settings group. An optional caption sits above.
class GroupedSection extends StatelessWidget {
  final String? caption;
  final String? action;
  final VoidCallback? onAction;
  final List<Widget> children;

  /// Where the hairline between rows starts, so it lines up with the text
  /// after a leading icon.
  final double dividerIndent;

  const GroupedSection({
    super.key,
    this.caption,
    this.action,
    this.onAction,
    required this.children,
    this.dividerIndent = 64,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(Divider(indent: dividerIndent, height: 0.6));
      rows.add(children[i]);
    }
    final radius = BorderRadius.circular(AppTheme.radiusLg);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (caption != null) GroupCaption(caption!, action: action, onAction: onAction),
        DecoratedBox(
          decoration: BoxDecoration(borderRadius: radius, boxShadow: context.cardShadow),
          child: Material(
            color: context.colors.surface,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: Column(mainAxisSize: MainAxisSize.min, children: rows),
          ),
        ),
      ],
    );
  }
}

/// One row of a [GroupedSection]: an icon or badge, a small label over the
/// main text, and a value or chevron on the right.
class GroupedRow extends StatelessWidget {
  final Widget? leading;

  /// Small grey text above [title], like "પાટલા" over the worker's name.
  final String? label;
  final String title;

  /// Grey text below [title].
  final String? subtitle;

  /// Text on the right, such as an amount.
  final String? value;
  final Color? valueColor;

  /// Shown instead of [value].
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// A chevron on the right; on by default for rows that can be tapped.
  final bool? chevron;
  final Color? titleColor;

  /// Show [title] in muted text, for a choice not made yet.
  final bool placeholder;

  const GroupedRow({
    super.key,
    this.leading,
    this.label,
    required this.title,
    this.subtitle,
    this.value,
    this.valueColor,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.chevron,
    this.titleColor,
    this.placeholder = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final showChevron = chevron ?? onTap != null;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 54),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg, vertical: 11),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: AppTheme.spaceMd)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (label != null) Text(label!, style: context.text.bodySmall?.copyWith(fontSize: 12)),
                    Text(
                      title,
                      style: context.text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: placeholder ? colors.muted : titleColor,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(subtitle!, style: context.text.bodySmall),
                      ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (value != null)
                Padding(
                  padding: const EdgeInsets.only(left: AppTheme.spaceSm),
                  child: Text(
                    value!,
                    style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: valueColor),
                  ),
                ),
              if (showChevron)
                Padding(
                  padding: const EdgeInsets.only(left: AppTheme.spaceXs),
                  child: Icon(Icons.chevron_right_rounded, color: colors.muted.withValues(alpha: 0.6), size: 22),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A label and amount on one line, for breakdowns inside a card.
class AmountLine extends StatelessWidget {
  final String label;
  final String? note;
  final String value;
  final Color? valueColor;
  final bool strong;

  const AmountLine({
    super.key,
    required this.label,
    this.note,
    required this.value,
    this.valueColor,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = strong ? context.text.titleMedium : context.text.bodyLarge?.copyWith(fontSize: 15);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: label,
                children: [
                  if (note != null)
                    TextSpan(
                      text: '  ·  $note',
                      style: TextStyle(color: context.colors.muted),
                    ),
                ],
              ),
              style: style,
            ),
          ),
          const SizedBox(width: AppTheme.spaceSm),
          Text(
            value,
            style: style?.copyWith(fontWeight: FontWeight.w600, color: valueColor),
          ),
        ],
      ),
    );
  }
}
