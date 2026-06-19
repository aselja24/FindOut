import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';

// Импортируем экраны теории
import '../grammar/grammar_detail_screen.dart';
import '../reading/reading_detail_screen.dart';

// Импортируем экраны тестов
import '../grammar/grammar_test_screen.dart';
import '../reading/reading_test_screen.dart';
import '../listening/listening_test_screen.dart';

class LessonFlowScreen extends StatefulWidget {
  final Map<String, dynamic> lessonData;

  const LessonFlowScreen({super.key, required this.lessonData});

  @override
  State<LessonFlowScreen> createState() => _LessonFlowScreenState();
}

class _LessonFlowScreenState extends State<LessonFlowScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isFinished = false;

  // Данные для каждого этапа
  Map<String, dynamic>? _grammarData;
  Map<String, dynamic>? _readingData;
  Map<String, dynamic>? _listeningData;

  @override
  void initState() {
    super.initState();
    _fetchLessonMaterials();
  }

  // Загружаем данные обо всех частях урока из базы
  Future<void> _fetchLessonMaterials() async {
    try {
      final grammarId = widget.lessonData['grammar_id'];
      final readingId = widget.lessonData['reading_id'];
      final listeningId = widget.lessonData['listening_id'];

      // Загружаем грамматику
      if (grammarId != null) {
        _grammarData = await _supabase.from('grammar_lessons').select().eq('id', grammarId).maybeSingle();
      }
      // Загружаем статью
      if (readingId != null) {
        _readingData = await _supabase.from('culture_articles').select().eq('id', readingId).maybeSingle();
      }
      // Загружаем тест аудирования
      if (listeningId != null) {
        _listeningData = await _supabase.from('listening_tests').select().eq('id', listeningId).maybeSingle();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Ошибка загрузки материалов урока: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ГЛАВНАЯ ЛОГИКА: ПОСЛЕДОВАТЕЛЬНЫЙ ЗАПУСК (ТЕОРИЯ -> ПРАКТИКА) ---
  Future<void> _startLessonFlow() async {

    // 1. ЭТАП: ГРАММАТИКА
    if (_grammarData != null) {
      // Сначала теория
      await Navigator.push(context, MaterialPageRoute(builder: (_) => GrammarDetailScreen(lesson: _grammarData!)));
      if (!mounted) return;
      // Затем тест по грамматике
      await Navigator.push(context, MaterialPageRoute(builder: (_) => GrammarTestScreen(lessonId: _grammarData!['id'])));
    }

    if (!mounted) return;

    // 2. ЭТАП: ЧТЕНИЕ
    if (_readingData != null) {
      // Сначала сама статья
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ReadingDetailScreen(article: _readingData!)));
      if (!mounted) return;
      // Затем тест по чтению
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ReadingTestScreen(articleId: _readingData!['id'])));
    }

    if (!mounted) return;

    // 3. ЭТАП: АУДИРОВАНИЕ (Сразу тест)
    if (_listeningData != null) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ListeningTestScreen(testData: _listeningData!)));
    }

    if (!mounted) return;

    // 4. ЭТАП: ЗАВЕРШЕНИЕ УРОКА
    final user = _supabase.auth.currentUser;
    if (user != null) {
      await _supabase.from('user_progress').upsert({
        'user_id': user.id,
        'item_type': 'course_lesson',
        'item_id': widget.lessonData['id'],
        'score_percentage': 100,
        'completed_at': DateTime.now().toIso8601String(),
      });
    }

    setState(() {
      _isFinished = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator()));
    }

    if (_isFinished) {
      return _buildFinishedScreen();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView( // Добавил скролл на случай длинного списка этапов
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFBCA6F6), borderRadius: BorderRadius.circular(12)),
                child: Text('Урок ${widget.lessonData['order_num']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
              ),
              const SizedBox(height: 16),
              Text(widget.lessonData['title'] ?? 'Без названия', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, fontFamily: 'Poppins')),
              const SizedBox(height: 8),
              Text(widget.lessonData['description'] ?? '', style: const TextStyle(fontSize: 15, color: Colors.black54, fontFamily: 'Poppins', height: 1.5)),
              const SizedBox(height: 32),

              const Text('Что внутри:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
              const SizedBox(height: 16),

              // Обновленный список этапов
              if (_grammarData != null) ...[
                _buildStepRow(Icons.menu_book_rounded, 'Грамматика (Теория)', _grammarData!['title']),
                _buildStepRow(Icons.quiz_rounded, 'Грамматика (Практика)', 'Проверка знаний'),
              ],
              if (_readingData != null) ...[
                _buildStepRow(Icons.article_rounded, 'Чтение (Статья)', _readingData!['title']),
                _buildStepRow(Icons.quiz_rounded, 'Чтение (Практика)', 'Тест по тексту'),
              ],
              if (_listeningData != null) ...[
                _buildStepRow(Icons.headset_rounded, 'Слушание (Тест)', _listeningData!['title']),
              ],

              const SizedBox(height: 40),

              // Кнопка НАЧАТЬ
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _startLessonFlow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    elevation: 0,
                  ),
                  child: const Text('Начать урок', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow(IconData icon, String type, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Poppins'), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFinishedScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFF9D66), size: 100),
              const SizedBox(height: 24),
              const Text('Урок пройден!', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, fontFamily: 'Poppins')),
              const SizedBox(height: 12),
              const Text('Ты отлично справился со всеми этапами. Так держать!', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.black54, fontFamily: 'Poppins')),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC3F336),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    elevation: 0,
                  ),
                  child: const Text('Вернуться в меню', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}