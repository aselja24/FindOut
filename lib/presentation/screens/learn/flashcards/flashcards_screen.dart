import 'package:flutter/material.dart';
import '../../../../core/theme/app_text_styles.dart';

class FlashcardsScreen extends StatelessWidget {
  const FlashcardsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FlashcardsScreen')),
      body: Center(child: Text('FlashcardsScreen — в разработке', style: AppTextStyles.body)),
    );
  }
}
