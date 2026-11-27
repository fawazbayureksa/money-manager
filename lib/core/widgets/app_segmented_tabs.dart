import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppTabOption<T> {
  const AppTabOption({
    required this.value,
    required this.label,
    this.icon,
    this.count,
    this.accentColor,
    this.softColor,
  });

  final T value;
  final String label;
  final IconData? icon;
  final int? count;
  final Color? accentColor;
  final Color? softColor;
}

class AppSegmentedTabs<T> extends StatelessWidget {
  const AppSegmentedTabs({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
    this.height = 52,
    this.borderRadius = 18,
  }) : assert(options.length >= 2, 'AppSegmentedTabs requires at least 2 options');

  final List<AppTabOption<T>> options;
  final T selectedValue;
  final ValueChanged<T> onChanged;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final selectedIndex = options
        .indexWhere((o) => o.value == selectedValue)
        .clamp(0, options.length - 1);
    final activeOption = options[selectedIndex];
    final activeAccent =
        activeOption.accentColor ?? Theme.of(context).colorScheme.primary;
    final activeBg =
        activeOption.softColor ?? activeAccent.withValues(alpha: 0.12);

    final alignX = options.length == 1
        ? 0.0
        : -1.0 + (2.0 * selectedIndex / (options.length - 1));
    final innerRadius = (borderRadius - 5).clamp(8.0, 99.0);

    return Container(
      height: height,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: colors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment(alignX, 0),
            child: FractionallySizedBox(
              widthFactor: 1 / options.length,
              heightFactor: 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: activeBg,
                  borderRadius: BorderRadius.circular(innerRadius),
                  border: Border.all(
                    color: activeAccent.withValues(alpha: 0.24),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: options.map((option) {
              final selected = option.value == selectedValue;
              final accent =
                  option.accentColor ?? Theme.of(context).colorScheme.primary;
              return Expanded(
                child: _SegmentedTabItem(
                  option: option,
                  selected: selected,
                  accent: accent,
                  innerRadius: innerRadius,
                  onTap: () => onChanged(option.value),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _SegmentedTabItem<T> extends StatelessWidget {
  const _SegmentedTabItem({
    required this.option,
    required this.selected,
    required this.accent,
    required this.innerRadius,
    required this.onTap,
  });

  final AppTabOption<T> option;
  final bool selected;
  final Color accent;
  final double innerRadius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final fgColor = selected ? accent : colors.mutedText;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(innerRadius),
        splashColor: accent.withValues(alpha: 0.08),
        highlightColor: accent.withValues(alpha: 0.04),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (option.icon != null) ...[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: selected
                          ? accent.withValues(alpha: 0.16)
                          : colors.canvas,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      option.icon,
                      size: 13,
                      color: fgColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                          color: fgColor,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w600,
                        ),
                    child: Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (option.count != null) ...[
                  const SizedBox(width: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? accent.withValues(alpha: 0.15)
                          : colors.canvas,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${option.count}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: fgColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
