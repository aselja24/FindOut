import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/theme/app_colors.dart';

class LanguageSelectScreen extends StatefulWidget {
  const LanguageSelectScreen({super.key});
  @override
  State<LanguageSelectScreen> createState() => _LanguageSelectScreenState();
}

class _LanguageSelectScreenState extends State<LanguageSelectScreen> {
  String? _selected;
  bool _isUpdating = false;

  final List<Map<String, String>> _languages = [
  {'name': 'Немецкий', 'code': 'de', 'icon': '🇩🇪'},
{'name': 'Английский', 'code': 'en', 'icon': '🇬🇧'},
{'name': 'Корейский', 'code': 'ko', 'icon': '🇰🇷'},
{'name': 'Французский', 'code': 'fr', 'icon': '🇫🇷'},
{'name': 'Испанский', 'code': 'es', 'icon': '🇪🇸'},
{'name': 'Итальянский', 'code': 'it', 'icon': '🇮🇹'},
];

Future<void> _saveLanguage() async {
  if (_selected == null) return;
  setState(() => _isUpdating = true);

  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      final langCode = _languages.firstWhere((l) => l['name'] == _selected)['code'];
      await Supabase.instance.client
          .from('profiles')
          .update({'learning_language': langCode})
          .eq('id', userId);
    }
    if (mounted) context.push(Routes.setupGoal);
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ошибка сети при сохранении: $e')),
    );
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Какой язык ты\\nхочешь изучать?',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 32, fontWeight: FontWeight.w800, color: Colors.black, height: 1.2)),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: _languages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final lang = _languages[i];
                final isSelected = _selected == lang['name'];
                return GestureDetector(
                  onTap: _isUpdating ? null : () => setState(() => _selected = lang['name']),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent, width: 2),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : const Color(0xFFD9D9D9),
                            shape: BoxShape.circle,
                          ),
                          child: Center(child: Text(lang['icon']!, style: const TextStyle(fontSize: 20))),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          lang['name']!,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: isSelected ? AppColors.primary : Colors.black),
                        ),
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
                onPressed: _selected == null || _isUpdating ? null : _saveLanguage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: _isUpdating
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
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