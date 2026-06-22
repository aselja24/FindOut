import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_colors.dart';

class SetupLevelScreen extends StatefulWidget {
  const SetupLevelScreen({super.key});
  @override
  State<SetupLevelScreen> createState() => _SetupLevelScreenState();
}

class _SetupLevelScreenState extends State<SetupLevelScreen> {
  String? _selected; // хранит 'label' выбранного элемента
  bool _isSaving = false;

  final _levels = [
    {'emoji': '🌱', 'code': 'A1', 'label': 'A1 — С нуля',        'desc': 'Никогда не учил немецкий'},
    {'emoji': '📖', 'code': 'A2', 'label': 'A2 — Начинающий',    'desc': 'Знаю базовые слова и фразы'},
    {'emoji': '💬', 'code': 'B1', 'label': 'B1 — Средний',       'desc': 'Могу поддержать разговор'},
    {'emoji': '🎯', 'code': 'B2', 'label': 'B2 — Выше среднего', 'desc': 'Свободно общаюсь на большинство тем'},
    {'emoji': '🚀', 'code': 'C1', 'label': 'C1 — Продвинутый',   'desc': 'Понимаю сложные тексты и речь'},
  ];

  Future<void> _save() async {
    if (_selected == null) return;
    setState(() => _isSaving = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final code = _levels.firstWhere((l) => l['label'] == _selected)['code']!;
        await Supabase.instance.client
            .from('profiles')
            .update({'language_level': code, 'target_language': 'de'})
            .eq('id', userId);
      }
      if (mounted) context.push(Routes.setupTime);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Шапка с прогрессом ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.black),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: const LinearProgressIndicator(
                        value: 0.5, // шаг 1 из 2
                        backgroundColor: Color(0xFFEEEEEE),
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('1/2',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),

            // ── Заголовок ───────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 28, 24, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Какой у тебя уровень немецкого?',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 22,
                        fontWeight: FontWeight.w800, color: Colors.black),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Не переживай — всегда можно изменить',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

            // ── Список уровней ──────────────────────────────────────────
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                itemCount: _levels.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final item = _levels[i];
                  final isSelected = _selected == item['label'];
                  return GestureDetector(
                    onTap: () => setState(() => _selected = item['label']),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.08)
                            : const Color(0xFFF6F6F6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withOpacity(0.15)
                                  : Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(item['emoji']!, style: const TextStyle(fontSize: 20)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['label']!,
                                  style: TextStyle(
                                    fontFamily: 'Poppins', fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? AppColors.primary : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item['desc']!,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins', fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded,
                                color: AppColors.primary, size: 22),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Кнопка Далее ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity, height: 58,
                child: ElevatedButton(
                  onPressed: _selected != null && !_isSaving ? _save : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.35),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Далее',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}