import 'package:flutter/material.dart';
import '../../../core/theme/app_text_styles.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ProgressScreen')),
      body: Center(child: Text('ProgressScreen — в разработке', style: AppTextStyles.body)),
    );
  }
}
