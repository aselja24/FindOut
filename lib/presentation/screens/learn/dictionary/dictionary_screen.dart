import 'package:flutter/material.dart';
import '../../../../core/theme/app_text_styles.dart';

class DictionaryScreen extends StatelessWidget {
  const DictionaryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DictionaryScreen')),
      body: Center(child: Text('DictionaryScreen — в разработке', style: AppTextStyles.body)),
    );
  }
}
