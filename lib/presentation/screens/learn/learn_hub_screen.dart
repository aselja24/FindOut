import 'package:flutter/material.dart';
import '../../../core/theme/app_text_styles.dart';

class LearnHubScreen extends StatelessWidget {
  const LearnHubScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LearnHubScreen')),
      body: Center(child: Text('LearnHubScreen — в разработке', style: AppTextStyles.body)),
    );
  }
}
