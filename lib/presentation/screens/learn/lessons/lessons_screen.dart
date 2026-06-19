import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import 'lesson_flow_screen.dart';

class LessonsScreen extends StatefulWidget {
  const LessonsScreen({super.key});

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String _userLevel = 'A1-A2'; // По умолчанию, пока не загрузим профиль
  List<Map<String, dynamic>> _lessons = [];

  @override
  void initState() {
    super.initState();
    _fetchUserLevelAndLessons();
  }

  Future<void> _fetchUserLevelAndLessons() async {
    try {
      final user = _supabase.auth.currentUser;

      // 1. Получаем уровень пользователя из профиля (если есть)
      if (user != null) {
        final profile = await _supabase.from('profiles').select('language_level').eq('id', user.id).maybeSingle();
        if (profile != null && profile['language_level'] != null) {
          // Маппинг уровня пользователя в формат уроков
          final lvl = profile['language_level'];
          if (lvl == 'A1' || lvl == 'A2') _userLevel = 'A1-A2';
          else if (lvl == 'B1' || lvl == 'B2') _userLevel = 'B1-B2';
          else if (lvl == 'C1' || lvl == 'C2') _userLevel = 'C1-C2';
        }
      }

      // 2. Загружаем уроки для этого уровня
      final data = await _supabase
          .from('course_lessons')
          .select()
          .eq('level', _userLevel)
          .order('order_num', ascending: true);

      // В будущем здесь также можно подтягивать прогресс из user_progress,
      // чтобы понимать, какие уроки уже пройдены, а какие заблокированы.

      setState(() {
        _lessons = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки уроков: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      children: [
        // Заголовок
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Твой путь', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, fontFamily: 'Poppins')),
                SizedBox(height: 4),
                Text('Проходи уроки шаг за шагом', style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontFamily: 'Poppins')),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFC3F336), borderRadius: BorderRadius.circular(20)),
              child: Text(_userLevel, style: const TextStyle(fontWeight: FontWeight.w800, fontFamily: 'Poppins', color: Colors.black)),
            ),
          ],
        ),
        const SizedBox(height: 32),

        if (_lessons.isEmpty)
          const Center(child: Text('Для твоего уровня пока нет уроков.', style: TextStyle(fontFamily: 'Poppins')))
        else
          ..._lessons.map((lesson) => _buildLessonCard(lesson)),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildLessonCard(Map<String, dynamic> lesson) {
    // Временно делаем первый урок всегда доступным, а остальные можно визуально "заблокировать"
    final bool isLocked = lesson['order_num'] > 1; // Заглушка: всё кроме 1-го урока заблокировано

    return GestureDetector(
        onTap: () {
          if (isLocked) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сначала пройди предыдущие уроки!')));
            return;
          }

          // ВОТ ЗДЕСЬ ЗАПУСКАЕМ НАШ ФЛОУ:
          Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => LessonFlowScreen(lessonData: lesson))
          ).then((_) {
            // Когда пользователь возвращается с урока, обновляем список (чтобы разблокировать следующий)
            _fetchUserLevelAndLessons();
          });
        },
      child: Opacity(
        opacity: isLocked ? 0.6 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isLocked ? const Color(0xFFF5F5F5) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isLocked ? Colors.transparent : const Color(0xFFEEEEEE), width: 2),
            boxShadow: isLocked ? [] : [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFBCA6F6), borderRadius: BorderRadius.circular(12)),
                    child: Text('Урок ${lesson['order_num']}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
                  ),
                  Icon(isLocked ? Icons.lock_outline_rounded : Icons.play_circle_fill_rounded, color: isLocked ? Colors.grey : const Color(0xFF7B4DFE), size: 28),
                ],
              ),
              const SizedBox(height: 16),
              Text(lesson['title'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black, fontFamily: 'Poppins')),
              const SizedBox(height: 8),
              Text(
                lesson['description'] ?? '3 задания: Грамматика, Чтение и Слушание.',
                style: const TextStyle(fontSize: 13, color: Colors.black54, fontFamily: 'Poppins', height: 1.4),
              ),
              if (!isLocked) ...[
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.menu_book_rounded, size: 16, color: Colors.grey),
                    SizedBox(width: 6),
                    Text('Грамматика', style: TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'Poppins')),
                    SizedBox(width: 12),
                    Icon(Icons.article_rounded, size: 16, color: Colors.grey),
                    SizedBox(width: 6),
                    Text('Чтение', style: TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'Poppins')),
                    SizedBox(width: 12),
                    Icon(Icons.headset_rounded, size: 16, color: Colors.grey),
                    SizedBox(width: 6),
                    Text('Аудирование', style: TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'Poppins')),
                  ],
                )
              ]
            ],
          ),
        ),
      ),
    );
  }
}