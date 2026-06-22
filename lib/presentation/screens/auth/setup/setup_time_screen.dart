import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_colors.dart';

class SetupTimeScreen extends StatefulWidget {
  const SetupTimeScreen({super.key});
  @override
  State<SetupTimeScreen> createState() => _SetupTimeScreenState();
}

class _SetupTimeScreenState extends State<SetupTimeScreen> {
  String? _selected;
  bool _isSaving = false;

  final _times = [
    {'emoji': '⚡', 'value': '5',  'label': '5 минут',  'desc': 'Лёгкий старт, главное — регулярность'},
    {'emoji': '🕐', 'value': '15', 'label': '15 минут', 'desc': 'Оптимально для стабильного прогресса'},
    {'emoji': '🕑', 'value': '30', 'label': '30 минут', 'desc': 'Быстрый рост словарного запаса'},
    {'emoji': '🔥', 'value': '60', 'label': '1 час',    'desc': 'Максимальный результат'},
  ];

  Future<void> _save() async {
    if (_selected == null) return;
    setState(() => _isSaving = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final val = _times.firstWhere((t) => t['label'] == _selected)['value']!;
        await Supabase.instance.client
            .from('profiles')
            .update({'daily_time_target': val})
            .eq('id', userId);
      }
      if (mounted) context.go(Routes.home);
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
                        value: 1.0, // шаг 2 из 2
                        backgroundColor: Color(0xFFEEEEEE),
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('2/2',
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
                    'Сколько времени в день?',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 22,
                        fontWeight: FontWeight.w800, color: Colors.black),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Регулярность важнее длительности',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

            // ── Список вариантов ────────────────────────────────────────
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                itemCount: _times.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final item = _times[i];
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

            // ── Кнопка Начать ────────────────────────────────────────────
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
                      : const Text('Начать обучение',
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