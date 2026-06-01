import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class Eyebrow extends StatelessWidget {
  final String text;
  final Color color;

  const Eyebrow(this.text, {super.key, this.color = AppColors.berry});

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: AppTextStyles.eyebrow(color: color));
  }
}
