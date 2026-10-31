import 'package:flutter/material.dart';

class CategoryMeta {
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  const CategoryMeta({
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });
}

class CategoryIconAvatar extends StatelessWidget {
  final String category;
  final double size;
  final double iconSize;
  final double borderRadius;

  const CategoryIconAvatar({
    super.key,
    required this.category,
    this.size = 44,
    this.iconSize = 22,
    this.borderRadius = 14,
  });

  static CategoryMeta getMeta(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'dining':
      case 'groceries':
        return const CategoryMeta(
          icon: Icons.restaurant_rounded,
          color: Color(0xFFEA580C),
          backgroundColor: Color(0xFFFFEDD5),
        );
      case 'transport':
      case 'travel':
      case 'commute':
        return const CategoryMeta(
          icon: Icons.directions_car_rounded,
          color: Color(0xFF2563EB),
          backgroundColor: Color(0xFFDBEAFE),
        );
      case 'shopping':
        return const CategoryMeta(
          icon: Icons.shopping_bag_rounded,
          color: Color(0xFF9333EA),
          backgroundColor: Color(0xFFF3E8FF),
        );
      case 'bills':
      case 'utilities':
      case 'electricity':
        return const CategoryMeta(
          icon: Icons.receipt_long_rounded,
          color: Color(0xFF0D9488),
          backgroundColor: Color(0xFFCCFBF1),
        );
      case 'healthcare':
      case 'medical':
        return const CategoryMeta(
          icon: Icons.medical_services_rounded,
          color: Color(0xFFE11D48),
          backgroundColor: Color(0xFFFFE4E6),
        );
      case 'education':
        return const CategoryMeta(
          icon: Icons.school_rounded,
          color: Color(0xFF4F46E5),
          backgroundColor: Color(0xFFE0E7FF),
        );
      case 'entertainment':
        return const CategoryMeta(
          icon: Icons.movie_rounded,
          color: Color(0xFFDB2777),
          backgroundColor: Color(0xFFFCE7F3),
        );
      case 'rent':
      case 'housing':
        return const CategoryMeta(
          icon: Icons.home_rounded,
          color: Color(0xFF0284C7),
          backgroundColor: Color(0xFFE0F2FE),
        );
      case 'salary':
      case 'business':
      case 'freelance':
      case 'investments':
      case 'income':
        return const CategoryMeta(
          icon: Icons.arrow_downward_rounded,
          color: Color(0xFF16A36A),
          backgroundColor: Color(0xFFECFDF3),
        );
      default:
        return const CategoryMeta(
          icon: Icons.widgets_rounded,
          color: Color(0xFF475467),
          backgroundColor: Color(0xFFF2F4F7),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = getMeta(category);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: meta.backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Icon(
          meta.icon,
          color: meta.color,
          size: iconSize,
        ),
      ),
    );
  }
}
