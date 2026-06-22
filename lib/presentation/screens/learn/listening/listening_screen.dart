import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import 'listening_test_screen.dart';

class ListeningScreen extends StatefulWidget {
  final String? currentLevel;
  const ListeningScreen({super.key, this.currentLevel});

  @override
  State<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends State<ListeningScreen> {
  final _supabase = Supabase.instance.client;
  String _selectedLevel = 'A1-A2';
  final List<String> _levels = ['A1-A2', 'B1-B2', 'C1-C2'];

  List<Map<String, dynamic>> _tests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.currentLevel != null) {
      _selectedLevel = _mapLevelToRange(widget.currentLevel!);
    }
    _fetchTests();
  }

  @override
  void didUpdateWidget(ListeningScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentLevel != oldWidget.currentLevel && widget.currentLevel != null) {
      setState(() {
        _selectedLevel = _mapLevelToRange(widget.currentLevel!);
      });
    }
  }

  String _mapLevelToRange(String level) {
    if (level == 'A1' || level == 'A2') return 'A1-A2';
    if (level == 'B1' || level == 'B2') return 'B1-B2';
    if (level == 'C1' || level == 'C2') return 'C1-C2';
    return 'A1-A2';
  }

  // Функция для динамического определения цвета уровня
  Color _getLevelColor(String level) {
    if (level.contains('A1') || level.contains('A2')) {
      return const Color(0xFFFF9DE6); // Розовый
    } else if (level.contains('B1') || level.contains('B2')) {
      return const Color(0xFFC3F336); // Зеленый
    } else if (level.contains('C1') || level.contains('C2')) {
      return const Color(0xFF4D96FF); // Синий
    }
    return const Color(0xFFEEEEEE);
  }

  Future<void> _fetchTests() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('listening_tests')
          .select()
          .order('id', ascending: true);

      setState(() {
        _tests = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки тестов: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Фильтруем тесты по выбранному уровню
    final filteredTests = _tests.where((test) => test['level'] == _selectedLevel).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Заголовок и фильтр уровней
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Модельтесты',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins'),
            ),
            _buildLevelFilter(),
          ],
        ),
        const SizedBox(height: 28),

        const Text(
          'Продолжить слушать',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 16),
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildHorizontalList(filteredTests),

        const SizedBox(height: 32),

        const Text(
          'Рекомендуется для вас',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 16),
        _isLoading
            ? const SizedBox()
            : _buildHorizontalList(filteredTests.reversed.toList()),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildLevelFilter() {
    return PopupMenuButton<String>(
      initialValue: _selectedLevel,
      onSelected: (value) => setState(() => _selectedLevel = value),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      offset: const Offset(0, 40),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _getLevelColor(_selectedLevel), // Динамический цвет для кнопки фильтра
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Text(_selectedLevel, style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Poppins', fontSize: 13, color: Colors.black)),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.black),
          ],
        ),
      ),
      itemBuilder: (context) => _levels.map((lvl) => PopupMenuItem(
        value: lvl,
        child: Text(lvl, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
      )).toList(),
    );
  }

  Widget _buildHorizontalList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return const SizedBox(
        height: 170,
        child: Center(child: Text('Для этого уровня пока нет тестов.', style: TextStyle(fontFamily: 'Poppins', color: Colors.grey))),
      );
    }

    return SizedBox(
      height: 170,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) => _buildTestCard(items[index]),
      ),
    );
  }

  Widget _buildTestCard(Map<String, dynamic> item) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ListeningTestScreen(testData: item)));
      },
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFEEEEEE), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Динамический значок уровня на самой карточке
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getLevelColor(item['level']), // <-- Теперь цвет подтягивается автоматически
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                      item['level'],
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'Poppins', color: Colors.black)
                  ),
                ),
                const Icon(Icons.favorite_border_rounded, color: Color(0xFFCCCCCC), size: 22),
              ],
            ),
            const Spacer(),
            Text(item['title'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins')),
            const SizedBox(height: 6),
            const Text(
              'Training zur Prüfung Goethe-/\nÖSD-Zertifikat für Jugendliche',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary, fontFamily: 'Poppins', height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}