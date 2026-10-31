import 'package:flutter/material.dart';
import 'package:kharcha_ai/core/constants/app_colors.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final double height;
  final double borderRadius;
  final bool isOutlined;
  final Gradient? gradient;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.height = 52,
    this.borderRadius = 14,
    this.isOutlined = false,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBg = backgroundColor ?? AppColors.primary;
    final effectiveFg = textColor ??
        (isOutlined ? AppColors.primary : Colors.white);

    if (isOutlined) {
      return SizedBox(
        width: double.infinity,
        height: height,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: effectiveFg,
            side: BorderSide(color: effectiveFg.withOpacity(0.5), width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
          child: _buildChild(effectiveFg),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        gradient: gradient ??
            (backgroundColor == null && onPressed != null
                ? AppColors.primaryGradient
                : null),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: (onPressed != null && !isLoading && backgroundColor == null)
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: (gradient != null || backgroundColor == null)
              ? Colors.transparent
              : effectiveBg,
          foregroundColor: effectiveFg,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: effectiveBg.withOpacity(0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: _buildChild(effectiveFg),
      ),
    );
  }

  Widget _buildChild(Color fgColor) {
    if (isLoading) {
      return SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(fgColor),
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: fgColor),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: fgColor,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}
