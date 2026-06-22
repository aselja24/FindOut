import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class LevelTestScreen extends StatefulWidget {
  const LevelTestScreen({super.key});
  @override
  State<LevelTestScreen> createState() => _LevelTestScreenState();
}

class _LevelTestScreenState extends State<LevelTestScreen> {
  int _current = 0;
  int _score = 0;
  String? _selected;
  bool _showResult = false;

  final _questions = [
    {'q': 'Как будет "Hello" на немецком?', 'opts': ['Auf Wiedersehen', 'Hallo', 'Danke', 'Bitte'], 'ans': 'Hallo'},
    {'q': 'Что означает "감사합니다"?', 'opts': ['Привет', 'До свидания', 'Спасибо', 'Пожалуйста'], 'ans': 'Спасибо'},
    {'q': 'Выбери правильный артикль: ___ Buch (книга)', 'opts': ['der', 'die', 'das', 'den'], 'ans': 'das'},
    {'q': '"I have been studying" — это время:', 'opts': ['Present Simple', 'Present Perfect', 'Present Continuous', 'Present Perfect Continuous'], 'ans': 'Present Perfect Continuous'},
    {'q': 'Корейский алфавит называется:', 'opts': ['Хирагана', 'Хангыль', 'Катакана', 'Хандза'], 'ans': 'Хангыль'},
  ];

  String get _result {
    if (_score <= 1) return 'A1';
    if (_score == 2) return 'A2';
    if (_score == 3) return 'B1';
    if (_score == 4) return 'B2';
    return 'C1';
  }

  void _answer(String opt) {
    setState(() => _selected = opt);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      if (_questions[_current]['ans'] == opt) _score++;
      if (_current < _questions.length - 1) {
        setState(() {
          _current++;
          _selected = null;
        });
      } else {
        setState(() => _showResult = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showResult) return _buildResult();
    final q = _questions[_current];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Тест на уровень',
          style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              LinearProgressIndicator(
                value: (_current + 1) / _questions.length,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text('${_current + 1} / ${_questions.length}', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
              const Spacer(),
              Text(q['q'] as String, style: AppTextStyles.h3, textAlign: TextAlign.center),
              const SizedBox(height: 32),
              ...(q['opts'] as List<String>).map((opt) {
                Color? bg;
                Color? border;
                if (_selected != null) {
                  if (opt == q['ans']) {
                    bg = AppColors.success.withValues(alpha: 0.1);
                    border = AppColors.success;
                  } else if (opt == _selected) {
                    bg = AppColors.error.withValues(alpha: 0.1);
                    border = AppColors.error;
                  }
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: _selected == null ? () => _answer(opt) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: bg ?? AppColors.backgroundGrey,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border ?? Colors.transparent, width: 2),
                      ),
                      child: Text(
                        opt,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              }),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResult() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Text('', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 24),
              Text('Твой уровень', style: AppTextStyles.body.copyWith(color: AppColors.textMuted)),
              Text(_result, style: AppTextStyles.h1.copyWith(color: AppColors.primary, fontSize: 56)),
              const SizedBox(height: 12),
              Text('Правильных ответов: $_score / ${_questions.length}', style: AppTextStyles.body.copyWith(color: AppColors.textMuted)),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => context.push(Routes.home),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  child: const Text('Начать обучение', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.push(Routes.home),
                child: const Text('Начать с A1', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
