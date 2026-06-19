import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../profile/profile_screen.dart';

class ReadingScreen extends StatefulWidget {
  const ReadingScreen({super.key});

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _articles = [];
  bool _isLoading = true;

  final List<String> _categories = ['Все', 'Культура', 'Места', 'Традиции', 'История', 'Кухня'];
  String _selectedCategory = 'Все';

  @override
  void initState() {
    super.initState();
    _fetchArticlesAndProgress();
  }

  Future<void> _fetchArticlesAndProgress() async {
    try {
      setState(() => _isLoading = true);
      final user = _supabase.auth.currentUser;

      // 1. Формируем запрос на статьи
      var query = _supabase.from('culture_articles').select();
      if (_selectedCategory != 'Все') {
        query = query.eq('category', _selectedCategory);
      }
      final articlesData = await query.order('created_at');

      List<Map<String, dynamic>> progressData = [];
      List<int> favoriteIds = [];

      if (user != null) {
        // 2. Получаем прогресс
        final pData = await _supabase
            .from('user_progress')
            .select('item_id, score_percentage')
            .eq('user_id', user.id)
            .eq('item_type', 'reading_test');
        progressData = List<Map<String, dynamic>>.from(pData);

        // 3. Получаем список избранного
        final favData = await _supabase
            .from('favorite_articles')
            .select('article_id')
            .eq('user_id', user.id);
        favoriteIds = favData.map((f) => f['article_id'] as int).toList();
      }

      // 4. Объединяем данные
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
          'is_favorite': favoriteIds.contains(articleId), // Флаг лайка
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

  // Функция добавления/удаления из избранного
  Future<void> _toggleFavorite(int articleId, bool isCurrentlyFavorite) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Мгновенное обновление UI (оптимистичный подход)
    setState(() {
      final index = _articles.indexWhere((a) => a['id'] == articleId);
      if (index != -1) {
        _articles[index]['is_favorite'] = !isCurrentlyFavorite;
      }
    });

    try {
      if (isCurrentlyFavorite) {
        // Удаляем лайк
        await _supabase
            .from('favorite_articles')
            .delete()
            .eq('user_id', user.id)
            .eq('article_id', articleId);
      } else {
        // Ставим лайк
        await _supabase.from('favorite_articles').insert({
          'user_id': user.id,
          'article_id': articleId,
        });
      }

      // ОТПРАВЛЯЕМ СИГНАЛ ПРОФИЛЮ ОБНОВИТЬСЯ:
      ProfileScreen.refreshNotifier.value++;

    } catch (e) {
      debugPrint('Ошибка избранного: $e');
      // В случае ошибки возвращаем как было
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
                      color: _selectedCategory == cat ? const Color(0xFFFF9D66) : const Color(0xFFFF9D66).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(cat, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                  ),
                ),
              )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFC3F336), borderRadius: BorderRadius.circular(20)),
                child: const Row(
                  children: [
                    Text('A1-A2', style: TextStyle(fontWeight: FontWeight.w700)),
                    Icon(Icons.keyboard_arrow_down, size: 16),
                  ],
                ),
              ),
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
              : _articles.isEmpty
              ? const Center(child: Text('Статей пока нет'))
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _articles.length,
            itemBuilder: (context, index) {
              final article = _articles[index];
              return _buildArticleCard(article);
            },
          ),
        ),
      ],
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