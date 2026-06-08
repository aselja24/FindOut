import 'package:flutter/material.dart';
import '../../../core/theme/app_text_styles.dart';

class CultureScreen extends StatelessWidget {
  const CultureScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CultureScreen')),
      body: Center(child: Text('CultureScreen — в разработке', style: AppTextStyles.body)),
    );
  }
}
