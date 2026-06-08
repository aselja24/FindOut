import 'package:flutter/material.dart';
import '../../../../core/theme/app_text_styles.dart';

class GrammarScreen extends StatelessWidget {
  const GrammarScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GrammarScreen')),
      body: Center(child: Text('GrammarScreen — в разработке', style: AppTextStyles.body)),
    );
  }
}
