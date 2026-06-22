import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../learn/grammar/grammar_screen.dart';
import '../learn/flashcards/flashcards_tab.dart';
import '../learn/reading/reading_screen.dart';
import '../learn/listening/listening_screen.dart';
import '../progress/progress_screen.dart';

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

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _wordOfTheDay;
  List<Map<String, dynamic>> _nextLessons = [];
  bool _isLoading = true;

  String _currentLevel = 'A1';
  final List<String> _levels = ['A1', 'A2', 'B1', 'C1'];

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

  // ИСПРАВЛЕНО: Добавлен параметр showLoading для мгновенной реакции UI при возврате
  Future<void> _loadInitialData({bool showLoading = false}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }

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
        _loadNextLessons(),
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

  String _mapLevelToRange(String level) {
    if (level == 'A1' || level == 'A2') return 'A1-A2';
    if (level == 'B1' || level == 'B2') return 'B1-B2';
    if (level == 'C1' || level == 'C2') return 'C1-C2';
    return 'A1-A2';
  }

  Future<void> _loadNextLessons() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final progressData = await _supabase.from('user_progress').select().eq('user_id', userId);

      Set<int> completedGrammar = {};
      Set<int> completedListening = {};
      Set<int> completedReading = {};
      Set<int> completedCourse = {};

      Map<String, int> partialProgress = {};

      for (var p in progressData) {
        final type = p['item_type'] as String;
        final id = (p['item_id'] as num).toInt();
        final score = (p['score_percentage'] as num?)?.toInt() ?? 0;

        partialProgress['${type}_$id'] = score;

        if (score >= 60) {
          if (type == 'grammar_lesson') completedGrammar.add(id);
          if (type == 'listening_test') completedListening.add(id);
          if (type == 'culture_article' || type == 'reading_test') completedReading.add(id);
          if (type == 'course_lesson') completedCourse.add(id);
        }
      }

      List<Map<String, dynamic>> nextLessons = [];
      final levelRange = _mapLevelToRange(_currentLevel);

      // Грамматика
      final grammarData = await _supabase.from('grammar_lessons').select().eq('level', levelRange).order('id');
      final nextGrammar = grammarData.firstWhere(
              (g) => !completedGrammar.contains((g['id'] as num).toInt()),
          orElse: () => {'id': -1}
      );
      if (nextGrammar['id'] != -1) {
        nextLessons.add({
          'type': 'grammar',
          'title': 'Грамматика',
          'subtitle': nextGrammar['title'] ?? '',
          'index': grammarData.indexOf(nextGrammar) + 1,
          'progress': partialProgress['grammar_lesson_${nextGrammar['id']}'] ?? 0,
          'mainColor': const Color(0xFF7B4DFE),
          'bgColor': const Color(0xFFBCA6F6),
          'icon': Icons.book_rounded,
          'raw_data': nextGrammar,
        });
      } else if (grammarData.isNotEmpty) {
        nextLessons.add({
          'type': 'grammar',
          'title': 'Грамматика',
          'subtitle': 'Все уроки пройдены! 🎉',
          'index': grammarData.length,
          'progress': 100,
          'mainColor': const Color(0xFF7B4DFE),
          'bgColor': const Color(0xFFBCA6F6),
          'icon': Icons.book_rounded,
          'raw_data': grammarData.last,
        });
      }

      // Слушание
      final listeningData = await _supabase.from('listening_tests').select().eq('level', levelRange).order('id');
      final nextListening = listeningData.firstWhere(
              (l) => !completedListening.contains((l['id'] as num).toInt()),
          orElse: () => {'id': -1}
      );
      if (nextListening['id'] != -1) {
        nextLessons.add({
          'type': 'listening',
          'title': 'Слушание',
          'subtitle': nextListening['title'] ?? '',
          'index': listeningData.indexOf(nextListening) + 1,
          'progress': partialProgress['listening_test_${nextListening['id']}'] ?? 0,
          'mainColor': const Color(0xFF8DB600),
          'bgColor': const Color(0xFFE4F9A0),
          'icon': Icons.headphones_rounded,
          'raw_data': nextListening,
        });
      } else if (listeningData.isNotEmpty) {
        nextLessons.add({
          'type': 'listening',
          'title': 'Слушание',
          'subtitle': 'Все тесты пройдены! 🎉',
          'index': listeningData.length,
          'progress': 100,
          'mainColor': const Color(0xFF8DB600),
          'bgColor': const Color(0xFFE4F9A0),
          'icon': Icons.headphones_rounded,
          'raw_data': listeningData.last,
        });
      }

      // Чтение
      List<String> readingLevels = levelRange == 'A1-A2' ? ['A1', 'A2', 'A1-A2'] : [levelRange];
      final readingData = await _supabase.from('culture_articles').select().inFilter('level_restriction', readingLevels).order('id');
      final nextReading = readingData.firstWhere(
              (r) => !completedReading.contains((r['id'] as num).toInt()),
          orElse: () => {'id': -1}
      );
      if (nextReading['id'] != -1) {
        nextLessons.add({
          'type': 'reading',
          'title': 'Чтение',
          'subtitle': nextReading['title'] ?? '',
          'index': readingData.indexOf(nextReading) + 1,
          'progress': partialProgress['reading_test_${nextReading['id']}'] ?? partialProgress['culture_article_${nextReading['id']}'] ?? 0,
          'mainColor': const Color(0xFFCA4B24),
          'bgColor': const Color(0xFFF6B282),
          'icon': Icons.menu_book_rounded,
          'raw_data': nextReading,
        });
      } else if (readingData.isNotEmpty) {
        nextLessons.add({
          'type': 'reading',
          'title': 'Чтение',
          'subtitle': 'Все статьи пройдены! 🎉',
          'index': readingData.length,
          'progress': 100,
          'mainColor': const Color(0xFFCA4B24),
          'bgColor': const Color(0xFFF6B282),
          'icon': Icons.menu_book_rounded,
          'raw_data': readingData.last,
        });
      }

      // Комплексный урок
      final courseData = await _supabase.from('course_lessons').select().eq('level', levelRange).order('order_num');
      final nextCourse = courseData.firstWhere(
              (c) => !completedCourse.contains((c['id'] as num).toInt()),
          orElse: () => {'id': -1}
      );
      if (nextCourse['id'] != -1) {
        nextLessons.add({
          'type': 'course',
          'title': 'Комплексный урок',
          'subtitle': nextCourse['title'] ?? '',
          'index': nextCourse['order_num'] ?? (courseData.indexOf(nextCourse) + 1),
          'progress': partialProgress['course_lesson_${nextCourse['id']}'] ?? 0,
          'mainColor': const Color(0xFFD1339B),
          'bgColor': const Color(0xFFF4ADD6),
          'icon': Icons.school_rounded,
          'raw_data': nextCourse,
        });
      } else if (courseData.isNotEmpty) {
        nextLessons.add({
          'type': 'course',
          'title': 'Комплексный урок',
          'subtitle': 'Курс завершен!',
          'index': courseData.length,
          'progress': 100,
          'mainColor': const Color(0xFFD1339B),
          'bgColor': const Color(0xFFF4ADD6),
          'icon': Icons.school_rounded,
          'raw_data': courseData.last,
        });
      }

      if (mounted) {
        setState(() => _nextLessons = nextLessons);
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
                  GrammarScreen(currentLevel: _currentLevel),
                  ListeningScreen(currentLevel: _currentLevel),
                  ReadingScreen(currentLevel: _currentLevel),
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
            child: avatarUrl == null || avatarUrl.isEmpty ? const Icon(Icons.person_outline, size: 32, color: Color(0xFFAAAAAA)) : null,
          ),
          const Spacer(),
          Text('$streak', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'Poppins')),
          const SizedBox(width: 4),
          const Icon(Icons.local_fire_department_outlined, size: 26, color: Color(0xFFFF7B33)),
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
          const Text('Прогресс этапа', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500, fontFamily: 'Poppins')),
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

  Widget _buildNextLessonCard(Map<String, dynamic> item) {
    final type = item['type'] as String;
    final title = item['title'] as String;
    final subtitle = item['subtitle'] as String;
    final index = item['index'] as int;
    final progress = item['progress'] as int;
    final Color mainColor = item['mainColor'];
    final Color bgColor = item['bgColor'];
    final IconData icon = item['icon'];

    final double fillValue = progress == 0 ? 0.0 : progress / 100.0;

    return GestureDetector(
      onTap: () {
        final rawData = item['raw_data'];

        // ИСПРАВЛЕНО: Теперь при возврате включается загрузка (showLoading: true)
        if (type == 'grammar') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => GrammarDetailScreen(lesson: rawData)))
              .then((_) => _loadInitialData(showLoading: true));
        } else if (type == 'reading') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ReadingDetailScreen(article: rawData)))
              .then((_) => _loadInitialData(showLoading: true));
        } else if (type == 'listening') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ListeningTestScreen(testData: rawData)))
              .then((_) => _loadInitialData(showLoading: true));
        } else if (type == 'course') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => LessonFlowScreen(lessonData: rawData)))
              .then((_) => _loadInitialData(showLoading: true));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            Container(
              width: 54, height: 54,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
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
                  CircularProgressIndicator(value: 1.0, strokeWidth: 4, valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withValues(alpha: 0.6))),
                  CircularProgressIndicator(value: fillValue, strokeWidth: 4, backgroundColor: Colors.transparent, valueColor: AlwaysStoppedAnimation<Color>(mainColor)),
                  Center(child: Text('$index', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87, fontFamily: 'Poppins'))),
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
      decoration: BoxDecoration(color: const Color(0xFFBAA1F6), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: const Text('Слово дня', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
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

  Widget _buildMenuBlock({required String title, required String subtitle, required Color color, required bool isDarkTheme, required String imageAsset, required VoidCallback onTap}) {
    final textColor = isDarkTheme ? Colors.white : AppColors.textPrimary;
    final subTextColor = isDarkTheme ? Colors.white.withValues(alpha: 0.8) : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, height: 115,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
                  const SizedBox(height: 4),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.5, child: Text(subtitle, style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.w500, fontFamily: 'Poppins', height: 1.2))),
                ],
              ),
            ),
            Positioned(right: 8, bottom: 0, top: 0, child: Image.asset(imageAsset, width: 105, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox())),
          ],
        ),
      ),
    );
  }
}