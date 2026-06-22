import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../profile/profile_screen.dart';
import 'lesson_flow_screen.dart';

class LessonsScreen extends StatefulWidget {
  const LessonsScreen({super.key});

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  final _supabase = Supabase.instance.client;
  StreamSubscription? _profileSubscription;

  bool _isLoading = true;
  String _currentRawLevel = 'A1';
  String _displayLevelRange = 'A1-A2';
  List<Map<String, dynamic>> _lessons = [];

  Set<int> _completedLessonIds = {};
  int _maxCompletedOrder = 0;

  @override
  void initState() {
    super.initState();
    _setupProfileListener();
    // Слушаем сигнал об обновлении (например, смены уровня на главной)
    ProfileScreen.refreshNotifier.addListener(_onGlobalRefresh);
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    ProfileScreen.refreshNotifier.removeListener(_onGlobalRefresh);
    super.dispose();
  }

  void _onGlobalRefresh() {
    if (mounted) {
      _fetchUserLevelAndLessons();
    }
  }

  String _mapLevelToRange(String level) {
    if (level == 'A1' || level == 'A2') return 'A1-A2';
    if (level == 'B1' || level == 'B2') return 'B1-B2';
    if (level == 'C1' || level == 'C2') return 'C1-C2';
    return 'A1-A2';
  }

  // Метод для принудительного получения уровня из профиля (если стрим задержался)
  Future<void> _fetchUserLevelAndLessons() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final profile = await _supabase.from('profiles').select('language_level').eq('id', userId).maybeSingle();
      if (profile != null) {
        final rawLevel = profile['language_level'] ?? 'A1';
        final range = _mapLevelToRange(rawLevel);
        
        setState(() {
          _currentRawLevel = rawLevel;
          _displayLevelRange = range;
        });
        await _fetchLessonsAndProgress();
      }
    } catch (e) {
      debugPrint('Ошибка обновления уровня: $e');
    }
  }

  void _setupProfileListener() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _profileSubscription = _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .listen((data) {
          if (data.isNotEmpty) {
            final rawLevel = data.first['language_level'] ?? 'A1';
            final range = _mapLevelToRange(rawLevel);
            
            if (rawLevel != _currentRawLevel || _lessons.isEmpty) {
              if (mounted) {
                setState(() {
                  _currentRawLevel = rawLevel;
                  _displayLevelRange = range;
                });
                _fetchLessonsAndProgress();
              }
            }
          }
        });
  }

  Future<void> _fetchLessonsAndProgress() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('course_lessons')
          .select()
          .eq('level', _displayLevelRange)
          .order('order_num', ascending: true);

      final progressData = await _supabase
          .from('user_progress')
          .select('item_id')
          .eq('user_id', user.id)
          .eq('item_type', 'course_lesson');

      final completedIds = progressData.map<int>((p) => (p['item_id'] as num).toInt()).toSet();

      if (mounted) {
        setState(() {
          _lessons = List<Map<String, dynamic>>.from(data);
          _completedLessonIds = completedIds;

          _maxCompletedOrder = 0;
          for (var lesson in _lessons) {
            final lid = (lesson['id'] as num).toInt();
            if (completedIds.contains(lid) && (lesson['order_num'] as num).toInt() > _maxCompletedOrder) {
              _maxCompletedOrder = (lesson['order_num'] as num).toInt();
            }
          }
          _isLoading = false;
        });
      }
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          children: [
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
                  child: Text(_currentRawLevel, style: const TextStyle(fontWeight: FontWeight.w800, fontFamily: 'Poppins', color: Colors.black)),
                ),
              ],
            ),
            const SizedBox(height: 32),

            if (_lessons.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Column(
                    children: [
                      Icon(Icons.school_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('Для уровня $_currentRawLevel пока нет уроков.',
                        style: const TextStyle(fontFamily: 'Poppins', color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              )
            else
              ..._lessons.map((lesson) => _buildLessonCard(lesson)),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonCard(Map<String, dynamic> lesson) {
    final orderNum = (lesson['order_num'] as num).toInt();
    final bool isLocked = orderNum > _maxCompletedOrder + 1;
    final bool isCompleted = _completedLessonIds.contains((lesson['id'] as num).toInt());

    return GestureDetector(
      onTap: () {
        if (isLocked) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Сначала пройди предыдущие уроки!', style: TextStyle(fontFamily: 'Poppins')))
          );
          return;
        }

        Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LessonFlowScreen(lessonData: lesson))
        ).then((_) => _fetchLessonsAndProgress());
      },
      child: Opacity(
        opacity: isLocked ? 0.6 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isLocked ? const Color(0xFFF5F5F5) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isCompleted ? const Color(0xFFC3F336) : (isLocked ? Colors.transparent : const Color(0xFFEEEEEE)), 
              width: 2
            ),
            boxShadow: isLocked ? [] : [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 5))
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
                    decoration: BoxDecoration(
                      color: isCompleted ? const Color(0xFFC3F336) : const Color(0xFFBCA6F6), 
                      borderRadius: BorderRadius.circular(12)
                    ),
                    child: Text(
                      isCompleted ? 'Пройдено' : 'Урок $orderNum', 
                      style: TextStyle(color: isCompleted ? Colors.black : Colors.white, fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'Poppins')
                    ),
                  ),
                  Icon(
                      isLocked ? Icons.lock_outline_rounded : (isCompleted ? Icons.check_circle_rounded : Icons.play_circle_fill_rounded),
                      color: isLocked ? Colors.grey : (isCompleted ? const Color(0xFFC3F336) : const Color(0xFF7B4DFE)),
                      size: 28
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(lesson['title'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black, fontFamily: 'Poppins')),
              const SizedBox(height: 8),
              Text(
                lesson['description'] ?? 'Грамматика, Чтение и Слушание.',
                style: const TextStyle(fontSize: 13, color: Colors.black54, fontFamily: 'Poppins', height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
