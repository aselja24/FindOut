import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  // Глобальный сигнал для синхронизации всех экранов
  static final ValueNotifier<int> refreshNotifier = ValueNotifier(0);

  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _favoriteArticles = [];

  bool _isLoading = true;
  String _email = '';
  int _wordsLearned = 0;
  int _lessonsCompleted = 0;

  final Color _purple = const Color(0xFF7B4DFE);
  final Color _green = const Color(0xFFC3F336);

  @override
  void initState() {
    super.initState();
    _loadProfile();
    ProfileScreen.refreshNotifier.addListener(_onRefreshNeeded);
  }

  @override
  void dispose() {
    ProfileScreen.refreshNotifier.removeListener(_onRefreshNeeded);
    super.dispose();
  }

  void _onRefreshNeeded() {
    if (mounted) {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      _email = user.email ?? '';

      // 1. Данные профиля
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      // 2. Подсчет выученных слов (из всех модулей пользователя)
      final modulesData = await _supabase
          .from('flashcard_modules')
          .select('id, flashcards(is_learned)')
          .eq('user_id', user.id);

      int learnedCount = 0;
      for (var m in modulesData) {
        final cards = m['flashcards'] as List<dynamic>? ?? [];
        learnedCount += cards.where((c) => c['is_learned'] == true).length;
      }

      // 3. Загрузка избранных статей и прогресса
      final favData = await _supabase
          .from('favorite_articles')
          .select('culture_articles(*)')
          .eq('user_id', user.id);

      final progressData = await _supabase
          .from('user_progress')
          .select()
          .eq('user_id', user.id);

      // Считаем пройденные комплексные уроки (item_type = course_lesson, уникальные)
      final Set<int> uniqueCompletedLessons = {};
      for (var p in progressData) {
        if (p['item_type'] == 'course_lesson' && (p['score_percentage'] ?? 0) >= 60) {
          uniqueCompletedLessons.add((p['item_id'] as num).toInt());
        }
      }

      List<Map<String, dynamic>> favArticles = [];
      for (var f in favData) {
        final article = f['culture_articles'];
        if (article != null) {
          final prog = progressData.firstWhere(
            (p) => p['item_id'] == article['id'] && (p['item_type'] == 'reading_test' || p['item_type'] == 'culture_article'),
            orElse: () => {},
          );
          final int percent = prog.isNotEmpty ? (prog['score_percentage'] ?? 0) as int : 0;

          favArticles.add({
            ...article,
            'progress_percent': percent,
          });
        }
      }

      setState(() {
        _profile = data;
        _wordsLearned = learnedCount;
        _lessonsCompleted = uniqueCompletedLessons.length;
        _favoriteArticles = favArticles;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки профиля: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await _supabase.auth.signOut();
    if (mounted) context.go('/login');
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Удаление аккаунта', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
        content: const Text('Вы уверены? Это действие необратимо. Все ваши данные (прогресс, слова, статьи) будут удалены навсегда.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена', style: TextStyle(color: Colors.grey, fontFamily: 'Poppins')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final userId = _supabase.auth.currentUser?.id;
        if (userId != null) {
          try {
            await _supabase.rpc('delete_user');
          } catch (rpcError) {
            debugPrint('RPC delete_user failed: $rpcError');
            await _supabase.from('profiles').delete().eq('id', userId);
          }
          await _supabase.auth.signOut();
          if (mounted) {
            context.go('/login');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ваш аккаунт был успешно удален.'))
            );
          }
        }
      } catch (e) {
        debugPrint('Ошибка при удалении аккаунта: $e');
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Не удалось удалить аккаунт: $e'))
          );
        }
      }
    }
  }

  String _getLevelLabel(String lvl) {
    if (lvl.contains('A1') || lvl.contains('A2')) return 'Начинающий - $lvl';
    if (lvl.contains('B1') || lvl.contains('B2')) return 'Средний - $lvl';
    if (lvl.contains('C1') || lvl.contains('C2')) return 'Продвинутый - $lvl';
    return 'Начинающий - $lvl';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator()));
    }

    final name = _profile?['first_name'] ?? 'Имя пользователя';
    final rawLevel = _profile?['language_level'] ?? 'A1';
    final streak = _profile?['streak_days'] ?? 0;
    final avatarUrl = _profile?['avatar_url'];
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Профиль', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, fontFamily: 'Poppins')),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                        const SizedBox(height: 4),
                        Text(_email, style: const TextStyle(color: Colors.grey, fontSize: 14, fontFamily: 'Poppins')),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: _purple,
                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                    child: (avatarUrl == null || avatarUrl.isEmpty) ? Text(initial, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)) : null,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_getLevelLabel(rawLevel), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                  const Text('Прогресс', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Poppins', color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 8),
              Stack(
                children: [
                  Container(height: 8, decoration: BoxDecoration(color: const Color(0xFFEEEEEE), borderRadius: BorderRadius.circular(4))),
                  LayoutBuilder(
                    builder: (context, constraints) => Container(
                      width: constraints.maxWidth * 0.3,
                      height: 8,
                      decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: _purple, shape: BoxShape.circle),
                      child: const Center(child: Text('DE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Poppins'))),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Немецкий', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Poppins')),
                        Text('язык изучения', style: TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Poppins')),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 32),

              const Text('Статистика', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatItem(_wordsLearned.toString(), 'Слов\nизучено'),
                  _buildStatItem(streak.toString(), 'Дней\nподряд'),
                  _buildStatItem(_lessonsCompleted.toString(), 'Уроков\nпройдено'),
                ],
              ),
              const SizedBox(height: 32),

              const Text('Избранные статьи', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
              const SizedBox(height: 16),
              if (_favoriteArticles.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16.0),
                  child: Text('У вас пока нет избранных статей.', style: TextStyle(color: Colors.grey, fontFamily: 'Poppins')),
                )
              else
                ..._favoriteArticles.map((article) => _buildFavoriteArticleCard(article)),

              const SizedBox(height: 16),

              _buildListTile('Настройки', Icons.settings_outlined, onTap: () async {
                await context.push('/settings');
                _loadProfile();
                ProfileScreen.refreshNotifier.value++;
              }),
              _buildListTile('Ежедневная цель', Icons.flag_outlined, trailingText: '${_profile?['daily_time_target'] ?? '15'} мин/день'),
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Color(0xFFEEEEEE))),
              _buildListTile('Выйти из аккаунта', Icons.logout, color: Colors.black, onTap: _signOut),
              _buildListTile('Удалить аккаунт', Icons.delete_outline, color: Colors.red, onTap: _deleteAccount),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, fontFamily: 'Poppins')),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Poppins')),
      ],
    );
  }

  Widget _buildFavoriteArticleCard(Map<String, dynamic> article) {
    final percent = article['progress_percent'] ?? 0;

    return GestureDetector(
      onTap: () async {
        await context.push('/reading/detail', extra: article);
        _loadProfile();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFEEEEEE)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(12)), child: Text(article['level_restriction'] ?? 'A1', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Poppins'))),
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFFF9DE6), borderRadius: BorderRadius.circular(12)), child: Text(article['category'] ?? '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Poppins'))),
                const Spacer(),
                Text('$percent%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Poppins')),
              ],
            ),
            const SizedBox(height: 12),
            Text(article['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Poppins')),
            Text(article['category'] ?? 'Культура', style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Poppins')),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(String title, IconData icon, {Color color = Colors.black, String? trailingText, VoidCallback? onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color, fontFamily: 'Poppins')),
      trailing: trailingText != null
          ? Text(trailingText, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontFamily: 'Poppins'))
          : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}
