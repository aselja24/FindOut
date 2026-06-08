import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_colors.dart';

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
                  const Center(child: Text('Экран грамматики (В разработке)')),
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
    final firstName = _profile?['first_name'] ?? 'Пользователь';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.surfaceVariant,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? const Icon(Icons.person, color: AppColors.textSecondary, size: 22)
                : null,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Привет,', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500, fontFamily: 'Nunito')),
              Text(firstName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Nunito')),
            ],
          ),
          const Spacer(),
          // Стрик дней в стиле скругленной капсулы из дизайна
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.orangeLight.withOpacity(0.15),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 4),
                Text('$streak дней', style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.w800, fontSize: 13, fontFamily: 'Nunito')),
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimary, size: 24),
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
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
              const Text('Мой уровень: ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontFamily: 'Nunito')),
              PopupMenuButton<String>(
                initialValue: _currentLevel,
                onSelected: _updateLevel,
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Text(_currentLevel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary, fontFamily: 'Nunito')),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary, size: 20),
                  ],
                ),
                itemBuilder: (context) => _levels.map((lvl) => PopupMenuItem<String>(
                  value: lvl,
                  child: Text(lvl, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Nunito')),
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
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Прогресс этапа', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500, fontFamily: 'Nunito')),
              Text('35%', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'Nunito')),
            ],
          ),
        ],
      ),
    );
  }

  // Полностью переработанный таббар, соответствующий вашему чистому UI
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
          dividerColor: Colors.transparent, // Убираем дефолтную серую линию Material 3
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'Nunito'),
          unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Nunito'),
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
          color: AppColors.accent,
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
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12)
                ),
                child: const Text('Слово дня', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Nunito')),
              ),
              const Icon(Icons.volume_up_rounded, color: AppColors.primary, size: 22),
            ],
          ),
          const SizedBox(height: 12),
          Text(word, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Nunito')),
          if (transcription.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(transcription, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500, fontFamily: 'Nunito')),
          ],
          const Divider(height: 20, thickness: 1, color: AppColors.border),
          Text(translation, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Nunito')),
          const SizedBox(height: 4),
          Text(explanation, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.3, fontFamily: 'Nunito')),
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
                  Text(title, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'Nunito')),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.5,
                    child: Text(subtitle, style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.w500, fontFamily: 'Nunito', height: 1.2)),
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
          const Text('Вы изучали в последний раз', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Nunito')),
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
                    const Text('Грамматика: Passiv', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Nunito')),
                    const SizedBox(height: 2),
                    Text('Урок 3 из 10 • Уровень $_currentLevel', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500, fontFamily: 'Nunito')),
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