import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:khanak/global/themes.dart';

/// The save button pinned to the bottom of a form, on frosted glass, with
/// what will be saved beside the label, centred ("સેવ કરો · ₹14,300").
///
/// Use as a Scaffold's `bottomNavigationBar` with `extendBody: true`, and
/// keep [AppTheme.fabClearance] below the form so its end clears the bar.
class SaveBar extends StatelessWidget {
  final String label;

  /// Shown on the right of the button, usually the total.
  final String? trailing;
  final VoidCallback? onPressed;
  final bool isLoading;

  const SaveBar({super.key, required this.label, this.trailing, this.onPressed, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onPressed != null && !isLoading;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.background.withValues(alpha: 0.86),
            border: Border(top: BorderSide(color: colors.border, width: 0.5)),
          ),
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: AppTheme.spaceMd),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.spaceXl, AppTheme.spaceMd, AppTheme.spaceXl, 0),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: enabled || isLoading ? 1 : 0.5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    boxShadow: [
                      BoxShadow(
                        color: colors.shadow.withValues(alpha: 0.35),
                        blurRadius: 24,
                        spreadRadius: -12,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Material(
                    color: colors.ink,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: enabled ? onPressed : null,
                      child: SizedBox(
                        height: 56,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXl),
                          child: isLoading
                              ? Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.4, color: colors.onInk),
                                  ),
                                )
                              // Centred: "સેવ કરો · ₹14,300".
                              : Center(
                                  child: Text.rich(
                                    TextSpan(
                                      text: label,
                                      children: [
                                        if (trailing != null) ...[
                                          TextSpan(
                                            text: '  ·  ',
                                            style: TextStyle(color: colors.onInk.withValues(alpha: 0.5)),
                                          ),
                                          TextSpan(
                                            text: trailing,
                                            style: TextStyle(
                                              color: context.isDark ? colors.primary : const Color(0xFFF2A07A),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: context.text.titleMedium?.copyWith(color: colors.onInk),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
