import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../learn/grammar/grammar_screen.dart';
import '../learn/flashcards/flashcards_tab.dart';
import '../learn/reading/reading_screen.dart';
import '../learn/listening/listening_screen.dart';
import '../progress/progress_screen.dart';

// Экраны для переходов из блока "Мои уроки"
import '../learn/grammar/grammar_detail_screen.dart';
import '../learn/reading/reading_detail_screen.dart';
import '../learn/listening/listening_test_screen.dart';
import '../learn/lessons/lesson_flow_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Состояние пользователя
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _wordOfTheDay;

  // ИСПРАВЛЕНО: Умный список следующих уроков
  List<Map<String, dynamic>> _nextLessons = [];
  bool _isLoading = true;

  // Выбранный уровень
  String _currentLevel = 'A1';
  final List<String> _levels = ['A1', 'A2', 'B1', 'C1'];

  // Управление под-страницами
  late TabController _tabController;
  final List<String> _subTabs = ['Главная', 'Карточки', 'Грамматика', 'Слушание', 'Чтение'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _subTabs.length, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final profileData = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (profileData != null) {
        setState(() {
          _profile = profileData;
          _currentLevel = profileData['language_level'] ?? 'A1';
        });
      }

      await Future.wait([
        _loadWordOfTheDay(),
        _loadNextLessons(), // Вызываем умную загрузку
      ]);
    } catch (e) {
      debugPrint('Ошибка загрузки данных главной: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadWordOfTheDay() async {
    try {
      final res = await _supabase
          .from('words_dictionary')
          .select()
          .eq('level', _currentLevel)
          .eq('is_word_of_the_day', true)
          .limit(1)
          .maybeSingle();

      if (mounted) setState(() => _wordOfTheDay = res);
    } catch (e) {
      debugPrint('Ошибка загрузки слова дня: $e');
    }
  }

  // --- ИСПРАВЛЕНО: Умный поиск СЛЕДУЮЩЕГО урока, который еще не пройден ---
  Future<void> _loadNextLessons() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 1. Получаем ВЕСЬ прогресс пользователя, чтобы знать, что уже изучено
      final progressData = await _supabase.from('user_progress').select().eq('user_id', userId);

      Set<int> completedGrammar = {};
      Set<int> completedListening = {};
      Set<int> completedReading = {};
      Set<int> completedCourse = {};

      Map<String, int> partialProgress = {}; // Для кольца прогресса

      for (var p in progressData) {
        final type = p['item_type'] as String;
        final id = p['item_id'] as int;
        final score = p['score_percentage'] ?? 0;

        partialProgress['${type}_$id'] = score;

        // Если сдали на 100, считаем урок полностью пройденным
        if (score == 100) {
          if (type == 'grammar_lesson') completedGrammar.add(id);
          if (type == 'listening_test') completedListening.add(id);
          if (type == 'culture_article' || type == 'reading_test') completedReading.add(id);
          if (type == 'course_lesson') completedCourse.add(id);
        }
      }

      List<Map<String, dynamic>> nextLessons = [];

      // 2. Ищем первый не пройденный урок ГРАММАТИКИ
      final grammarData = await _supabase.from('grammar_lessons').select().order('id');
      final nextGrammar = grammarData.where((g) => !completedGrammar.contains(g['id'])).firstOrNull 
          ?? (grammarData.isNotEmpty ? grammarData.last : null);
      
      if (nextGrammar != null) {
        final gId = nextGrammar['id'];
        nextLessons.add({
          'type': 'grammar',
          'title': 'Грамматика',
          'subtitle': nextGrammar['title'] ?? '',
          'index': grammarData.indexOf(nextGrammar) + 1,
          'progress': partialProgress['grammar_lesson_$gId'] ?? 0,
          'mainColor': const Color(0xFF7B4DFE),
          'bgColor': const Color(0xFFBCA6F6),
          'icon': Icons.book_rounded,
          'raw_data': nextGrammar,
        });
      }

      // 3. Ищем первый не пройденный урок СЛУШАНИЯ
      final listeningData = await _supabase.from('listening_tests').select().order('id');
      final nextListening = listeningData.where((l) => !completedListening.contains(l['id'])).firstOrNull 
          ?? (listeningData.isNotEmpty ? listeningData.last : null);
      
      if (nextListening != null) {
        final lId = nextListening['id'];
        nextLessons.add({
          'type': 'listening',
          'title': 'Слушание',
          'subtitle': nextListening['title'] ?? '',
          'index': listeningData.indexOf(nextListening) + 1,
          'progress': partialProgress['listening_test_$lId'] ?? 0,
          'mainColor': const Color(0xFF8DB600),
          'bgColor': const Color(0xFFE4F9A0),
          'icon': Icons.headphones_rounded,
          'raw_data': nextListening,
        });
      }

      // 4. Ищем первый не пройденный урок ЧТЕНИЯ
      final readingData = await _supabase.from('culture_articles').select().order('id');
      final nextReading = readingData.where((r) => !completedReading.contains(r['id'])).firstOrNull 
          ?? (readingData.isNotEmpty ? readingData.last : null);
      
      if (nextReading != null) {
        final rId = nextReading['id'];
        nextLessons.add({
          'type': 'reading',
          'title': 'Чтение',
          'subtitle': nextReading['title'] ?? '',
          'index': readingData.indexOf(nextReading) + 1,
          'progress': partialProgress['reading_test_$rId'] ?? partialProgress['culture_article_$rId'] ?? 0,
          'mainColor': const Color(0xFFCA4B24),
          'bgColor': const Color(0xFFF6B282),
          'icon': Icons.menu_book_rounded,
          'raw_data': nextReading,
        });
      }

      // 5. Ищем первый не пройденный КОМПЛЕКСНЫЙ УРОК
      final courseData = await _supabase.from('course_lessons').select().order('order_num');
      final nextCourse = courseData.where((c) => !completedCourse.contains(c['id'])).firstOrNull 
          ?? (courseData.isNotEmpty ? courseData.last : null);
      
      if (nextCourse != null) {
        final cId = nextCourse['id'];
        nextLessons.add({
          'type': 'course',
          'title': 'Комплексный урок',
          'subtitle': nextCourse['title'] ?? '',
          'index': nextCourse['order_num'] ?? (courseData.indexOf(nextCourse) + 1),
          'progress': partialProgress['course_lesson_$cId'] ?? 0,
          'mainColor': const Color(0xFFD1339B),
          'bgColor': const Color(0xFFF4ADD6),
          'icon': Icons.school_rounded,
          'raw_data': nextCourse,
        });
      }

      if (mounted) {
        setState(() {
          _nextLessons = nextLessons;
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки следующих уроков: $e');
    }
  }

  Future<void> _updateLevel(String newLevel) async {
    setState(() {
      _currentLevel = newLevel;
      _isLoading = true;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase
            .from('profiles')
            .update({'language_level': newLevel})
            .eq('id', userId);
      }
      await Future.wait([
        _loadWordOfTheDay(),
        _loadNextLessons(),
      ]);
    } catch (e) {
      debugPrint('Не удалось обновить уровень: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _profile == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopHeader(),
            _buildLevelAndProgressSelector(),
            _buildSubTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMainTabContent(),
                  FlashcardsTab(currentLevel: _currentLevel),
                  const GrammarScreen(),
                  const ListeningScreen(),
                  const ReadingScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    final streak = _profile?['streak_days'] ?? 0;
    final avatarUrl = _profile?['avatar_url'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFFF2F2F2),
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null || avatarUrl.isEmpty
                ? const Icon(Icons.person_outline, size: 32, color: Color(0xFFAAAAAA))
                : null,
          ),
          const Spacer(),
          Text(
            '$streak',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'Poppins'),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.local_fire_department_outlined,
            size: 26,
            color: Color(0xFFFF7B33),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildLevelAndProgressSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Мой уровень: ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontFamily: 'Poppins')),
              PopupMenuButton<String>(
                initialValue: _currentLevel,
                onSelected: _updateLevel,
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Text(_currentLevel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary, fontFamily: 'Poppins')),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary, size: 20),
                  ],
                ),
                itemBuilder: (context) => _levels.map((lvl) => PopupMenuItem<String>(
                  value: lvl,
                  child: Text(lvl, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                )).toList(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: const LinearProgressIndicator(
              value: 0.35,
              minHeight: 7,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Прогресс этапа', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500, fontFamily: 'Poppins')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabBar() {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Theme(
        data: ThemeData(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          labelPadding: const EdgeInsets.symmetric(horizontal: 14),
          indicator: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'Poppins'),
          unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
          tabs: _subTabs.map((tabName) => Tab(text: tabName)).toList(),
        ),
      ),
    );
  }

  Widget _buildMainTabContent() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      children: [
        _buildWordOfTheDayCard(),
        const SizedBox(height: 14),

        _buildMenuBlock(
          title: 'Моя Статистика',
          subtitle: 'Посмотри свои успехи в обучении',
          color: AppColors.primary,
          isDarkTheme: true,
          imageAsset: 'assets/images/home/home_im.png',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProgressScreen()),
            );
          },
        ),
        const SizedBox(height: 14),

        _buildMenuBlock(
          title: 'Интересные Статьи',
          subtitle: 'Погружайся в культуру и чтение',
          color: AppColors.accentLight,
          isDarkTheme: false,
          imageAsset: 'assets/images/home/home_im2.png',
          onTap: () {
            _tabController.animateTo(4);
          },
        ),
        const SizedBox(height: 24),

        const Text('Мои уроки', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary, fontFamily: 'Poppins')),
        const SizedBox(height: 16),

        if (_nextLessons.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('Вы еще не начали изучение. Пройдите свой первый урок!', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Poppins')),
          )
        else
          ..._nextLessons.map((item) => _buildNextLessonCard(item)),

        const SizedBox(height: 24),
      ],
    );
  }

  // --- ИСПРАВЛЕНО: Дизайн карточки точь-в-точь как на макете ---
  Widget _buildNextLessonCard(Map<String, dynamic> item) {
    final type = item['type'] as String;
    final title = item['title'] as String;
    final subtitle = item['subtitle'] as String;
    final index = item['index'] as int;
    final progress = item['progress'] as int;
    final Color mainColor = item['mainColor'];
    final Color bgColor = item['bgColor'];
    final IconData icon = item['icon'];

    // Заполнение круга (от 0.0 до 1.0) в зависимости от частичного прогресса
    final double fillValue = progress == 0 ? 0.0 : progress / 100.0;

    return GestureDetector(
      onTap: () {
        // Переход на нужный экран в зависимости от типа урока
        final rawData = item['raw_data'];
        if (type == 'grammar') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => GrammarDetailScreen(lesson: rawData))).then((_) => _loadInitialData());
        } else if (type == 'reading') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ReadingDetailScreen(article: rawData))).then((_) => _loadInitialData());
        } else if (type == 'listening') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ListeningTestScreen(testData: rawData))).then((_) => _loadInitialData());
        } else if (type == 'course') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => LessonFlowScreen(lessonData: rawData))).then((_) => _loadInitialData());
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 54, height: 54,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: mainColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87, fontFamily: 'Poppins')),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500, fontFamily: 'Poppins'), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 50, height: 50,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Белый фон кольца
                  CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withValues(alpha: 0.6)),
                  ),
                  // Цветное заполнение кольца (если урок начат, но не закончен)
                  CircularProgressIndicator(
                    value: fillValue,
                    strokeWidth: 4,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(mainColor),
                  ),
                  // Номер урока в центре
                  Center(
                    child: Text(
                      '$index',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87, fontFamily: 'Poppins'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordOfTheDayCard() {
    final word = _wordOfTheDay?['word'] ?? 'Lernen';
    final translation = _wordOfTheDay?['translation'] ?? 'Учиться';
    final transcription = _wordOfTheDay?['transcription'] ?? '[lernen]';
    final explanation = _wordOfTheDay?['explanation'] ?? 'Регулярное изучение нового материала.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFBAA1F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Слово дня',
                  style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'Poppins'),
                ),
              ),
              const Icon(Icons.volume_up_rounded, color: Colors.white, size: 22),
            ],
          ),
          const SizedBox(height: 16),
          Text(word, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Poppins')),
          if (transcription.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(transcription, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8), fontStyle: FontStyle.italic, fontWeight: FontWeight.w500, fontFamily: 'Poppins')),
          ],
          const SizedBox(height: 12),
          Text(translation, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Poppins')),
          const SizedBox(height: 4),
          Text(explanation, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9), height: 1.3, fontFamily: 'Poppins')),
        ],
      ),
    );
  }

  Widget _buildMenuBlock({
    required String title,
    required String subtitle,
    required Color color,
    required bool isDarkTheme,
    required String imageAsset,
    required VoidCallback onTap,
  }) {
    final textColor = isDarkTheme ? Colors.white : AppColors.textPrimary;
    final subTextColor = isDarkTheme ? Colors.white.withValues(alpha: 0.8) : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 115,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.5,
                    child: Text(subtitle, style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.w500, fontFamily: 'Poppins', height: 1.2)),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 8,
              bottom: 0,
              top: 0,
              child: Image.asset(
                imageAsset,
                width: 105,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
