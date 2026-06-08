import 'package:flutter/material.dart';
import '../../../core/theme/app_text_styles.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SettingsScreen')),
      body: Center(child: Text('SettingsScreen — в разработке', style: AppTextStyles.body)),
    );
  }
}
