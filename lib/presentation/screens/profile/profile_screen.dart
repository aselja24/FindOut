import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  String _email = '';

  final Color _purple = const Color(0xFF7B4DFE);
  final Color _green = const Color(0xFFC3F336);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      _email = user.email ?? '';

      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      setState(() {
        _profile = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки профиля: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await _supabase.auth.signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator()));
    }

    final name = _profile?['first_name'] ?? 'Имя пользователя';
    final level = _profile?['language_level'] ?? 'A1';
    final streak = _profile?['streak_days'] ?? 0;
    // Пока мокаем эти две цифры
    final wordsLearned = 1240;
    final lessonsCompleted = 5;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Профиль', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
              const SizedBox(height: 24),

              // Имя и Email
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(_email, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                  CircleAvatar(radius: 24, backgroundColor: _purple, child: const Icon(Icons.person, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 24),

              // Уровень и Прогресс-бар
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Начинающий - $level', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Text('28%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Stack(
                children: [
                  Container(height: 8, decoration: BoxDecoration(color: const Color(0xFFEEEEEE), borderRadius: BorderRadius.circular(4))),
                  LayoutBuilder(
                    builder: (context, constraints) => Container(
                      width: constraints.maxWidth * 0.28,
                      height: 8,
                      decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Блок языка
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: _purple, shape: BoxShape.circle),
                      child: const Center(child: Text('DE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Немецкий', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('язык изучения', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Статистика
              const Text('Статистика', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatItem(wordsLearned.toString(), 'Слов\nизучено'),
                  _buildStatItem(streak.toString(), 'Дней\nподряд'),
                  _buildStatItem(lessonsCompleted.toString(), 'Уроков\nпройдено'),
                ],
              ),
              const SizedBox(height: 32),

              // Избранные статьи
              const Text('Избранные статьи', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Container(
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
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(12)), child: const Text('A1-A2', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                        const SizedBox(width: 8),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFFF9DE6), borderRadius: BorderRadius.circular(12)), child: const Text('Места', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                        const Spacer(),
                        const Text('65%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Берлинская стена', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Text('Разделение и объединение страны', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Настройки и прочее
              _buildListTile('Настройки', Icons.settings_outlined, onTap: () async {
                // Идем в настройки и ждем возврата, чтобы обновить профиль
                await context.push('/settings');
                _loadProfile();
              }),
              _buildListTile('Ежедневная цель', Icons.flag_outlined, trailingText: '${_profile?['daily_time_target'] ?? '15'} мин/день'),
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Color(0xFFEEEEEE))),
              _buildListTile('Выйти из аккаунта', Icons.logout, color: Colors.black, onTap: _signOut),
              _buildListTile('Удалить аккаунт', Icons.delete_outline, color: Colors.red),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildListTile(String title, IconData icon, {Color color = Colors.black, String? trailingText, VoidCallback? onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
      trailing: trailingText != null
          ? Text(trailingText, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
          : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}