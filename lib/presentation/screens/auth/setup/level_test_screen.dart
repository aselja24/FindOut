import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_colors.dart';

class LevelTestScreen extends StatelessWidget {
  const LevelTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go(Routes.setupLevel),
        ),
        title: const Text('Тест уровня'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📝', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 24),
            const Text(
              'Тест уровня',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 24,
                  fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            const Text(
              'Скоро будет готово',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 16,
                  color: AppColors.textSecondary),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go(Routes.setupTime),
                  child: const Text('Пропустить'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
