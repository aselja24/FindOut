import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_colors.dart';

class SetupLanguageScreen extends StatefulWidget {
  const SetupLanguageScreen({super.key});
  @override
  State<SetupLanguageScreen> createState() => _SetupLanguageScreenState();
}

class _SetupLanguageScreenState extends State<SetupLanguageScreen> {
  String? _selectedCode;
  bool _isUpdating = false;

  final List<Map<String, String>> _languages = [
    {'name': 'Немецкий', 'code': 'de', 'flag': '🇩🇪'},
    {'name': 'Английский', 'code': 'en', 'flag': '🇬🇧'},
    {'name': 'Корейский', 'code': 'ko', 'flag': '🇰🇷'},
  ];

  Future<void> _saveLanguage() async {
    if (_selectedCode == null) return;
    setState(() => _isUpdating = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        // Записываем 'de', 'en' или 'ko' в target_language, как требует внешний ключ в SQL
        await Supabase.instance.client
            .from('profiles')
            .update({'target_language': _selectedCode})
            .eq('id', userId);
      }
      if (mounted) context.push(Routes.setupGoal);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения языка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
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
          onPressed: () => context.pop(),
        ),
        title: const Text('Выполнено 1/4',
            style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),
            const Text('Какой язык ты хочешь изучать?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.black)),
            const SizedBox(height: 32),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _languages.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final lang = _languages[i];
                  final isSelected = _selectedCode == lang['code'];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCode = lang['code']),
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
                            child: Center(child: Text(lang['flag']!, style: const TextStyle(fontSize: 22))),
                          ),
                          const SizedBox(width: 16),
                          Text(lang['name']!,
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
                  onPressed: _selectedCode == null || _isUpdating ? null : _saveLanguage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _isUpdating
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Далее', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}