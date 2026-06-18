import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';

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
    _fetchArticles();
  }

  Future<void> _fetchArticles() async {
    try {
      setState(() => _isLoading = true);

      // 1. Создаем базовый запрос без сортировки
      var query = _supabase.from('culture_articles').select();

      // 2. Добавляем фильтр, если выбрана конкретная категория
      if (_selectedCategory != 'Все') {
        query = query.eq('category', _selectedCategory);
      }

      // 3. Добавляем сортировку и выполняем запрос
      final data = await query.order('created_at');

      setState(() {
        _articles = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки статей: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Категории
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
                    _fetchArticles();
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
              // Кнопка уровня
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
    return GestureDetector(
      onTap: () => context.push('/reading/detail', extra: article),
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
                const Icon(Icons.favorite_border, color: Colors.grey, size: 20),
              ],
            ),
            const SizedBox(height: 16),
            Text(article['title'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Разделение и объединение страны', style: TextStyle(fontSize: 12, color: Colors.grey)), // Заглушка подзаголовка
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: 0.65, // Заглушка прогресса
                    backgroundColor: const Color(0xFFEEEEEE),
                    color: const Color(0xFF7B4DFE),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('65%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }
}