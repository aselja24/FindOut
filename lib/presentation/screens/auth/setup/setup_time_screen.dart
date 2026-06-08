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
  bool _isUpdating = false;

  final List<Map<String, String>> _times = [
    {'label': '5 мин/день', 'icon': '⚡'},
    {'label': '15 мин/день', 'icon': '🕐'},
    {'label': '30 мин/день', 'icon': '🕑'},
    {'label': '60 мин/день', 'icon': '🔥'},
  ];

  Future<void> _completeSetup() async {
    if (_selected == null) return;
    setState(() => _isUpdating = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        // ИСПРАВЛЕНО: Меняем на 'daily_time_target' строго под твою структуру таблицы profiles
        await Supabase.instance.client
            .from('profiles')
            .update({'daily_time_target': _selected})
            .eq('id', userId);
      }

      if (mounted) {
        context.go(Routes.home);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось завершить настройку: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
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
        title: const Text('Выполнено 4/4',
            style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),
            const Text('Сколько времени в день?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.black)),
            const SizedBox(height: 32),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _times.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final time = _times[i];
                  final isSelected = _selected == time['label'];
                  return GestureDetector(
                    onTap: _isUpdating ? null : () => setState(() => _selected = time['label']),
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
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : const Color(0xFFD9D9D9),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(time['icon']!, style: const TextStyle(fontSize: 20)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(time['label']!,
                              style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700,
                                color: isSelected ? AppColors.primary : Colors.black,
                              )),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity, height: 58,
                child: ElevatedButton(
                  onPressed: _selected == null || _isUpdating ? null : _completeSetup,
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
                      : const Text('Начать обучение', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}