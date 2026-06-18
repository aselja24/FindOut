import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';

class GrammarScreen extends StatefulWidget {
  const GrammarScreen({super.key});

  @override
  State<GrammarScreen> createState() => _GrammarScreenState();
}

class _GrammarScreenState extends State<GrammarScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _lessons = [];
  List<Map<String, dynamic>> _filteredLessons = []; // Отфильтрованный список для отображения
  bool _isLoading = true;
  String _selectedLevel = 'A1';

  final List<Color> _cardColors = [
    const Color(0xFFBAA1F6),
    const Color(0xFFFD9E6B),
    const Color(0xFFFD65BD),
    const Color(0xFFDBF494),
  ];

  @override
  void initState() {
    super.initState();
    _fetchLessons();

    // Добавляем слушатель на изменение текста в поисковике
    _searchCtrl.addListener(_filterLessons);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Загрузка всех уроков выбранного уровня из БД
  Future<void> _fetchLessons() async {
    try {
      setState(() => _isLoading = true);
      final data = await _supabase
          .from('grammar_lessons')
          .select()
          .eq('level', _selectedLevel)
          .order('created_at');

      setState(() {
        _lessons = List<Map<String, dynamic>>.from(data);
        _filteredLessons = _lessons; // Изначально показываем все уроки
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching grammar: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Локальная фильтрация списка по введенному тексту
  void _filterLessons() {
    final query = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredLessons = _lessons;
      } else {
        _filteredLessons = _lessons.where((lesson) {
          final title = lesson['title'].toString().toLowerCase();
          return title.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Поисковик (Дизайн перенесен из FlashcardSearchScreen)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA), // Или AppColors.surfaceVariant, если он у вас есть
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 14, fontFamily: 'Poppins', fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Найти тему...',
                hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontFamily: 'Poppins'),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFAAAAAA), size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Color(0xFFAAAAAA), size: 20),
                  onPressed: () {
                    _searchCtrl.clear();
                    FocusScope.of(context).unfocus(); // Убираем клавиатуру при очистке
                  },
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),

        // 2. Выбор уровня
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Выбери уровень',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, fontFamily: 'Poppins'),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Text(
                      '$_selectedLevel-начинающий',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const Icon(Icons.keyboard_arrow_down, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Список уроков
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _filteredLessons.isEmpty
              ? Center(
            child: Text(
              _searchCtrl.text.isEmpty ? 'Уроков пока нет' : 'Ничего не найдено',
              style: const TextStyle(fontFamily: 'Poppins', color: Colors.grey),
            ),
          )
              : GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            itemCount: _filteredLessons.length, // Используем отфильтрованный список
            itemBuilder: (context, index) {
              final lesson = _filteredLessons[index]; // Используем отфильтрованный список
              final color = _cardColors[index % _cardColors.length];

              return GestureDetector(
                onTap: () => context.push('/grammar/detail', extra: lesson),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson['title'],
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Учимся грамматике и правилам',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Colors.black87),
                      ),
                      const Spacer(),
                      const Text(
                        'Подробнее...',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}