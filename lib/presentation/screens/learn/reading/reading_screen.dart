import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../profile/profile_screen.dart';

class ReadingScreen extends StatefulWidget {
  final String? currentLevel;
  const ReadingScreen({super.key, this.currentLevel});

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _articles = [];
  bool _isLoading = true;

  final List<String> _categories = ['Все', 'Культура', 'Места', 'Традиции', 'История', 'Кухня'];
  String _selectedCategory = 'Все';

  String _selectedLevel = 'A1-A2';
  final List<String> _levels = ['A1-A2', 'B1-B2', 'C1-C2'];

  @override
  void initState() {
    super.initState();
    if (widget.currentLevel != null) {
      _selectedLevel = _mapLevelToRange(widget.currentLevel!);
    }
    _fetchArticlesAndProgress();
  }

  @override
  void didUpdateWidget(ReadingScreen oldWidget) {
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

  Color _getLevelColor(String level) {
    if (level.contains('A1') || level.contains('A2')) return const Color(0xFFC3F336);
    if (level.contains('B1') || level.contains('B2')) return const Color(0xFFFF9DE6);
    if (level.contains('C1') || level.contains('C2')) return const Color(0xFF4D96FF);
    return const Color(0xFFEEEEEE);
  }

  Future<void> _fetchArticlesAndProgress() async {
    try {
      setState(() => _isLoading = true);
      final user = _supabase.auth.currentUser;

      var query = _supabase.from('culture_articles').select();
      if (_selectedCategory != 'Все') {
        query = query.eq('category', _selectedCategory);
      }
      final articlesData = await query.order('created_at');

      List<Map<String, dynamic>> progressData = [];
      List<int> favoriteIds = [];

      if (user != null) {
        final pData = await _supabase
            .from('user_progress')
            .select('item_id, score_percentage')
            .eq('user_id', user.id)
            .eq('item_type', 'reading_test');
        progressData = List<Map<String, dynamic>>.from(pData);

        final favData = await _supabase
            .from('favorite_articles')
            .select('article_id')
            .eq('user_id', user.id);
        favoriteIds = favData.map((f) => f['article_id'] as int).toList();
      }

      final List<Map<String, dynamic>> mergedArticles = [];
      for (var article in articlesData) {
        final articleId = article['id'];

        final prog = progressData.firstWhere(
                (p) => p['item_id'] == articleId,
            orElse: () => {}
        );
        final int percent = prog.isNotEmpty ? (prog['score_percentage'] ?? 0) as int : 0;

        mergedArticles.add({
          ...article,
          'progress_percent': percent,
          'is_favorite': favoriteIds.contains(articleId),
        });
      }

      setState(() {
        _articles = mergedArticles;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки статей: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFavorite(int articleId, bool isCurrentlyFavorite) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() {
      final index = _articles.indexWhere((a) => a['id'] == articleId);
      if (index != -1) {
        _articles[index]['is_favorite'] = !isCurrentlyFavorite;
      }
    });

    try {
      if (isCurrentlyFavorite) {
        await _supabase
            .from('favorite_articles')
            .delete()
            .eq('user_id', user.id)
            .eq('article_id', articleId);
      } else {
        await _supabase.from('favorite_articles').insert({
          'user_id': user.id,
          'article_id': articleId,
        });
      }
      ProfileScreen.refreshNotifier.value++;
    } catch (e) {
      debugPrint('Ошибка избранного: $e');
      setState(() {
        final index = _articles.indexWhere((a) => a['id'] == articleId);
        if (index != -1) {
          _articles[index]['is_favorite'] = isCurrentlyFavorite;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredArticles = _articles.where((article) {
      final String lvl = article['level_restriction'] ?? '';
      if (_selectedLevel == 'A1-A2') return lvl == 'A1' || lvl == 'A2' || lvl == 'A1-A2';
      if (_selectedLevel == 'B1-B2') return lvl == 'B1' || lvl == 'B2' || lvl == 'B1-B2';
      if (_selectedLevel == 'C1-C2') return lvl == 'C1' || lvl == 'C2' || lvl == 'C1-C2';
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              ..._categories.map((cat) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedCategory = cat);
                    _fetchArticlesAndProgress();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _selectedCategory == cat ? const Color(0xFFFF9D66) : const Color(0xFFFF9D66).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(cat, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                  ),
                ),
              )),
              _buildLevelFilter(),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Продолжить чтение', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredArticles.isEmpty
              ? const Center(child: Text('Для этого уровня пока нет статей', style: TextStyle(fontFamily: 'Poppins')))
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filteredArticles.length,
            itemBuilder: (context, index) {
              final article = filteredArticles[index];
              return _buildArticleCard(article);
            },
          ),
        ),
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
          color: _getLevelColor(_selectedLevel),
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

  Widget _buildArticleCard(Map<String, dynamic> article) {
    final int percent = article['progress_percent'] ?? 0;
    final double progressValue = percent / 100.0;
    final bool isFavorite = article['is_favorite'] == true;

    return GestureDetector(
      onTap: () async {
        await context.push('/reading/detail', extra: article);
        _fetchArticlesAndProgress();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFDBF494), borderRadius: BorderRadius.circular(12)),
                      child: Text(article['level_restriction'] ?? 'A1', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFFF9DE6), borderRadius: BorderRadius.circular(12)),
                      child: Text(article['category'] ?? '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => _toggleFavorite(article['id'], isFavorite),
                  child: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : Colors.grey,
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(article['title'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Разделение и объединение страны', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: progressValue,
                    backgroundColor: const Color(0xFFEEEEEE),
                    color: const Color(0xFF7B4DFE),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Text('$percent%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }
}