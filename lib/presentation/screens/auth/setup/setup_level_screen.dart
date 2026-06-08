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
  String? _selectedLevel;
  bool _isUpdating = false;

  final List<Map<String, String>> _levels = [
    {'code': 'A1', 'label': 'Начинающий'},
    {'code': 'A2', 'label': 'Базовый'},
    {'code': 'B1', 'label': 'Средний'},
    {'code': 'C1', 'label': 'Продвинутый'},
  ];

  Future<void> _saveLevel(String levelCode, BuildContext modalContext) async {
    setState(() => _isUpdating = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        // ИСПРАВЛЕНО: сохраняем строго в 'language_level' согласно твоей SQL-схеме
        await Supabase.instance.client
            .from('profiles')
            .update({'language_level': levelCode})
            .eq('id', userId);
      }

      // Закрываем BottomSheet, используя его контекст
      if (Navigator.canPop(modalContext)) {
        Navigator.pop(modalContext);
      }

      // Переходим на следующий шаг
      if (mounted) {
        context.push(Routes.setupTime);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при сохранении уровня: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  void _showLevelPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      isDismissible: !_isUpdating, // Запрещаем закрывать свайпом во время сохранения
      enableDrag: !_isUpdating,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // декор-ручка (handle)
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              ..._levels.map((level) {
                final isSelected = _selectedLevel == level['code'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: _isUpdating
                        ? null
                        : () {
                      setModal(() {}); // перерисовываем внутренности BottomSheet
                      setState(() => _selectedLevel = level['code']);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : const Color(0xFFF2F2F2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44, height: 44, // Сделали 44х44 для точного соответствия остальным экранам
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : const Color(0xFFD9D9D9),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                level['code']!,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: isSelected ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            level['label']!,
                            style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700,
                              color: isSelected ? AppColors.primary : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 58,
                child: ElevatedButton(
                  onPressed: _selectedLevel == null || _isUpdating
                      ? null
                      : () => _saveLevel(_selectedLevel!, ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _isUpdating
                      ? const SizedBox(
                    height: 24, width: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                      : const Text('Далее', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black),
          onPressed: _isUpdating ? null : () => context.pop(),
        ),
        title: const Text('Выполнено 3/4',
            style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              const Text('Каков твой уровень?',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.black)),
              const Spacer(),
              Image.asset(
                'assets/images/auth/level1.png',
                height: 280,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                const Text('🔍', style: TextStyle(fontSize: 100)),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity, height: 58,
                child: ElevatedButton(
                  onPressed: _isUpdating ? null : _showLevelPicker,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('Выбрать уровень',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('или', style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const Expanded(child: Divider()),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 58,
                child: ElevatedButton(
                  onPressed: _isUpdating ? null : () => context.push(Routes.levelTest),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF2F2F2),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('Пройти тест',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFFAAAAAA))),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}