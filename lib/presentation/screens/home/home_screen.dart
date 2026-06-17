import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../learn/grammar/grammar_screen.dart';

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
  bool _isLoading = true;

  // Выбранный уровень
  String _currentLevel = 'A1';
  final List<String> _levels = ['A1', 'A2', 'B1', 'C1'];

  // Управление под-страницами (Главная, Карточки, Грамматика...)
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
      await _loadWordOfTheDay();
    } catch (e) {
      debugPrint('Ошибка загрузки данных главной: $e');
    } finally {
      setState(() => _isLoading = false);
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

      setState(() => _wordOfTheDay = res);
    } catch (e) {
      debugPrint('Ошибка загрузки слова дня: $e');
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
      await _loadWordOfTheDay();
    } catch (e) {
      debugPrint('Не удалось обновить уровень: $e');
    } finally {
      setState(() => _isLoading = false);
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
            // 1. Хедер (Аватарка, Дни, Колокольчик)
            _buildTopHeader(),

            // 2. Селектор Уровня и Индикатор прогресса
            _buildLevelAndProgressSelector(),

            // 3. Кастомное меню вкладок (Главная, Карточки...)
            _buildSubTabBar(),

            // Контент страниц со свайпом
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMainTabContent(),
                  const Center(child: Text('Экран карточек (В разработке)')),
                  const GrammarScreen(),
                  const Center(child: Text('Экран слушания (В разработке)')),
                  const Center(child: Text('Экран чтения (В разработке)')),
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
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 16,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFFF2F2F2),
            backgroundImage:
            avatarUrl != null && avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl == null || avatarUrl.isEmpty
                ? const Icon(
              Icons.person_outline,
              size: 32,
              color: Color(0xFFAAAAAA),
            )
                : null,
          ),

          const Spacer(),

          Text(
            '$streak',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'Poppins'),
          ),

          const SizedBox(width:4),

          const Icon(
            Icons.local_fire_department_outlined,
            size: 26,
            color: Color(0xFFFF7B33),
          ),

          const SizedBox(width: 2),

          IconButton(
            onPressed: () {},
            splashRadius: 20,
            icon: const Icon(
              Icons.notifications_none_rounded,
              size: 26,
              color: Color(0xFF7643EE),
            ),
          ),
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
            color: AppColors.primary.withOpacity(0.08),
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
          onTap: () => context.push(Routes.home),
        ),
        const SizedBox(height: 14),

        _buildMenuBlock(
          title: 'Интересные Статьи',
          subtitle: 'Погружайся в культуру и чтение',
          color: AppColors.accentLight,
          isDarkTheme: false,
          imageAsset: 'assets/images/home/home_im2.png',
          onTap: () => context.push(Routes.home),
        ),
        const SizedBox(height: 14),

        _buildRecentActivityCard(),
        const SizedBox(height: 24),
      ],
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
              // Чисто белый бейдж без прозрачности, текст фиолетовый primary
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Слово дня',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              // Белая иконка громкости
              const Icon(
                Icons.volume_up_rounded,
                color: Colors.white,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Немецкое слово
          Text(
            word,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontFamily: 'Poppins',
            ),
          ),
          if (transcription.isNotEmpty) ...[
            const SizedBox(height: 2),
            // Транскрипция белым цветом с легкой прозрачностью
            Text(
              transcription,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins',
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Русский перевод
          Text(
            translation,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 4),
          // Объяснение / Пример предложения
          Text(
            explanation,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.9),
              height: 1.3,
              fontFamily: 'Poppins',
            ),
          ),
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
    final subTextColor = isDarkTheme ? Colors.white.withOpacity(0.8) : AppColors.textSecondary;

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

  Widget _buildRecentActivityCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Вы изучали в последний раз', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins')),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(12)),
                child: const Center(child: Text('📖', style: TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Грамматика: Passiv', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins')),
                    const SizedBox(height: 2),
                    Text('Урок 3 из 10 • Уровень $_currentLevel', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500, fontFamily: 'Poppins')),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
            ],
          ),
        ],
      ),
    );
  }
}
