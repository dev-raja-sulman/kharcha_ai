import 'package:flutter/material.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';

class FintechCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Gradient? gradient;
  final Border? border;
  final double borderRadius;
  final VoidCallback? onTap;
  final bool hasShadow;

  const FintechCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.backgroundColor,
    this.gradient,
    this.border,
    this.borderRadius = 18,
    this.onTap,
    this.hasShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark ? AppColors.darkSurface : AppColors.surface;
    final defaultBorder = Border.all(
      color: isDark ? AppColors.darkCardBorder : AppColors.cardBorder,
      width: 1,
    );

    Widget content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (backgroundColor ?? defaultBg) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ?? defaultBorder,
        boxShadow: (hasShadow && gradient == null)
            ? [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.25)
                      : const Color(0xFF101828).withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: content,
        ),
      );
    }

    return content;
  }
}
