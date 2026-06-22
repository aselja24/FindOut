import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';

class ProgressScreen extends StatefulWidget {
  final String? currentLevel; // передаём из HomeScreen напрямую

  const ProgressScreen({super.key, this.currentLevel});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;

  // Статистика
  int _wordsLearned = 0;         // кол-во папок с карточками
  int _lessonsCompleted = 0;     // уникальные course_lesson
  int _allActivities = 0;        // все записи прогресса
  int _streakDays = 0;
  String _currentLevel = 'A1';
  int _courseLessonsCompleted = 0;
  int _totalLessonsForLevel = 0;

  // График: количество активностей по дням (Пн–Вс), за последние 7 дней
  final List<int> _weeklyActivity = [0, 0, 0, 0, 0, 0, 0];
  final List<bool> _weeklyStreak = [false, false, false, false, false, false, false];

  // Сравнение с прошлой неделей
  int _thisWeekTotal = 0;
  int _lastWeekTotal = 0;

  @override
  void initState() {
    super.initState();
    _fetchStatistics();
  }

  Future<void> _fetchStatistics() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 1. Профиль — если уровень уже передан снаружи, используем его сразу
      try {
        final profileData = await _supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();
        if (profileData != null) {
          _streakDays = profileData['streak_days'] ?? 0;
          // Приоритет: переданный уровень из HomeScreen (уже актуальный),
          // иначе читаем из профиля
          _currentLevel = widget.currentLevel ?? profileData['language_level'] ?? 'A1';
        }
      } catch (e) {
        debugPrint('Ошибка профиля: $e');
        if (widget.currentLevel != null) _currentLevel = widget.currentLevel!;
      }

      String levelRange = 'A1-A2';
      if (_currentLevel == 'B1' || _currentLevel == 'B2') levelRange = 'B1-B2';
      if (_currentLevel == 'C1' || _currentLevel == 'C2') levelRange = 'C1-C2';

      // 2. Всего уроков для уровня
      try {
        final data = await _supabase
            .from('course_lessons')
            .select('id')
            .eq('level', levelRange);
        _totalLessonsForLevel = data.length;
      } catch (e) {
        debugPrint('Ошибка уроков курса: $e');
      }

      // 3. Папки с карточками (= "слова изучены" через коллекции)
      try {
        final foldersData = await _supabase
            .from('flashcard_folders')
            .select('id')
            .eq('user_id', user.id);
        _wordsLearned = foldersData.length;
      } catch (e) {
        debugPrint('Ошибка папок карточек: $e');
      }

      // 4. Прогресс
      try {
        final progressData = await _supabase
            .from('user_progress')
            .select()
            .eq('user_id', user.id);

        final now = DateTime.now();
        // Границы текущей и прошлой недели
        final todayStart = DateTime(now.year, now.month, now.day);
        final thisWeekStart = todayStart.subtract(Duration(days: now.weekday - 1));
        final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));

        Set<int> uniqueCourseLessons = {};
        _allActivities = progressData.length;

        for (var p in progressData) {
          final type = p['item_type'] as String?;
          final itemId = (p['item_id'] as num?)?.toInt() ?? 0;

          // Уникальные пройденные уроки курса
          if (type == 'course_lesson') {
            uniqueCourseLessons.add(itemId);
          }

          // Разбираем дату
          final dateStr = p['completed_at'];
          if (dateStr == null) continue;

          DateTime completedAt;
          try {
            completedAt = DateTime.parse(dateStr).toLocal();
          } catch (_) {
            continue;
          }

          final dayStart = DateTime(completedAt.year, completedAt.month, completedAt.day);

          // Текущая неделя (Пн–Вс)
          if (!dayStart.isBefore(thisWeekStart) && dayStart.isBefore(thisWeekStart.add(const Duration(days: 7)))) {
            final weekdayIdx = completedAt.weekday - 1; // 0=Пн, 6=Вс
            _weeklyActivity[weekdayIdx] += 1;
            _weeklyStreak[weekdayIdx] = true;
            _thisWeekTotal++;
          }

          // Прошлая неделя
          if (!dayStart.isBefore(lastWeekStart) && dayStart.isBefore(thisWeekStart)) {
            _lastWeekTotal++;
          }
        }

        _courseLessonsCompleted = uniqueCourseLessons.length;
        // Все типы активности как "уроков пройдено"
        _lessonsCompleted = uniqueCourseLessons.length;

      } catch (e) {
        debugPrint('Ошибка прогресса: $e');
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Генеральная ошибка: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getNextLevel(String current) {
    switch (current) {
      case 'A1': return 'A2';
      case 'A2': return 'B1';
      case 'B1': return 'B2';
      case 'B2': return 'C1';
      case 'C1': return 'C2';
      default: return 'C2';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Статистика',
          style: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.w800, fontFamily: 'Poppins'),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Текущий уровень', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87, fontFamily: 'Poppins')),
            const SizedBox(height: 16),
            _buildCurrentLevelCard(),
            const SizedBox(height: 32),

            const Text('Активность', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87, fontFamily: 'Poppins')),
            const SizedBox(height: 6),
            Text(
              'количество занятий за каждый день этой недели',
              style: TextStyle(fontSize: 12, color: Colors.black54, fontFamily: 'Poppins'),
            ),
            const SizedBox(height: 20),
            _buildActivityChart(),
            const SizedBox(height: 16),
            _buildWeekComparison(),
            const SizedBox(height: 32),

            const Text('За всё время', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87, fontFamily: 'Poppins')),
            const SizedBox(height: 16),
            _buildAllTimeStats(),
            const SizedBox(height: 32),

            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Страйк', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87, fontFamily: 'Poppins')),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    'последние 7 дней',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87.withOpacity(0.5), fontFamily: 'Poppins'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildStreakCalendar(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentLevelCard() {
    final nextLvl = _getNextLevel(_currentLevel);
    int lessonsLeft = (_totalLessonsForLevel - _courseLessonsCompleted).clamp(0, 9999);
    int percent = _totalLessonsForLevel == 0
        ? 0
        : ((_courseLessonsCompleted / _totalLessonsForLevel) * 100).toInt().clamp(0, 100);
    final double progressFraction = percent / 100.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFE4F9A0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _currentLevel,
                style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, height: 1.0, color: Color(0xFF8DB600), fontFamily: 'Poppins'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Немецкий', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87, fontFamily: 'Poppins')),
                    const SizedBox(height: 4),
                    Text(
                      'До уровня $nextLvl осталось $lessonsLeft уроков',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87.withOpacity(0.7), fontFamily: 'Poppins'),
                    ),
                  ],
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'Poppins', color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Прогресс-бар
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressFraction,
              backgroundColor: Colors.white.withOpacity(0.6),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8DB600)),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityChart() {
    final days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final maxVal = _weeklyActivity.fold(1, (prev, curr) => curr > prev ? curr : prev);
    // Округляем шкалу вверх до красивого числа
    final int topLabel = maxVal;

    return SizedBox(
      height: 160,
      child: Stack(
        children: [
          // Горизонтальные линии
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildChartGridLine('$topLabel'),
              _buildChartGridLine('${(topLabel * 0.66).round()}'),
              _buildChartGridLine('${(topLabel * 0.33).round()}'),
              _buildChartGridLine('0'),
              const SizedBox(height: 20),
            ],
          ),
          // Столбцы
          Padding(
            padding: const EdgeInsets.only(left: 30, bottom: 24, top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final val = _weeklyActivity[index];
                final double barHeight = maxVal == 0 ? 0 : (val / maxVal) * 110;
                // Сегодняшний день подсвечиваем ярче
                final todayIdx = DateTime.now().weekday - 1;
                final isToday = index == todayIdx;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (val > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '$val',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isToday ? AppColors.primary : Colors.black54,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    Container(
                      width: 20,
                      height: barHeight > 0 ? barHeight : 2,
                      decoration: BoxDecoration(
                        color: isToday ? AppColors.primary : const Color(0xFFBCA6F6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
          // Подписи дней
          Positioned(
            bottom: 0, left: 30, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (index) {
                final todayIdx = DateTime.now().weekday - 1;
                final isToday = index == todayIdx;
                return Text(
                  days[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                    color: isToday ? AppColors.primary : Colors.black54,
                    fontFamily: 'Poppins',
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartGridLine(String label) {
    return Row(
      children: [
        SizedBox(width: 26, child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'Poppins'))),
        const SizedBox(width: 4),
        Expanded(child: Container(height: 1, color: const Color(0xFFEEEEEE))),
      ],
    );
  }

  Widget _buildWeekComparison() {
    final diff = _thisWeekTotal - _lastWeekTotal;
    final bool isUp = diff >= 0;
    final String diffText = diff == 0
        ? 'как на прошлой неделе'
        : '${diff.abs()} ${_activitiesWord(diff.abs())} ${isUp ? "больше" : "меньше"}, чем на прошлой неделе';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isUp ? const Color(0xFFE4F9A0) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: isUp ? const Color(0xFF8DB600) : Colors.orange,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'На этой неделе $_thisWeekTotal ${_activitiesWord(_thisWeekTotal)} — $diffText',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Poppins', color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  String _activitiesWord(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'занятие';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) return 'занятия';
    return 'занятий';
  }

  Widget _buildAllTimeStats() {
    return Row(
      children: [
        Expanded(child: _buildStatSquare('$_wordsLearned', 'Наборов карточек', Colors.white)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatSquare('$_streakDays', 'Дней подряд', const Color(0xFFE4F9A0))),
        const SizedBox(width: 12),
        Expanded(child: _buildStatSquare('$_lessonsCompleted', 'Уроков курса', const Color(0xFFFF9DE6))),
      ],
    );
  }

  Widget _buildStatSquare(String value, String label, Color bgColor) {
    final bool isWhite = bgColor == Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isWhite
            ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87, fontFamily: 'Poppins')),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.black87, fontFamily: 'Poppins')),
        ],
      ),
    );
  }

  Widget _buildStreakCalendar() {
    final days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final todayIdx = DateTime.now().weekday - 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final isActive = _weeklyStreak[index];
        final isToday = index == todayIdx;

        return Column(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary
                    : (isToday ? const Color(0xFFEDE7FF) : const Color(0xFFF5F5F5)),
                shape: BoxShape.circle,
                border: isToday && !isActive
                    ? Border.all(color: AppColors.primary, width: 2)
                    : null,
              ),
              child: Icon(
                isActive ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: isActive ? Colors.white : (isToday ? AppColors.primary : const Color(0xFFCCCCCC)),
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              days[index],
              style: TextStyle(
                fontSize: 13,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                fontFamily: 'Poppins',
                color: isToday ? AppColors.primary : Colors.black87,
              ),
            ),
          ],
        );
      }),
    );
  }
}