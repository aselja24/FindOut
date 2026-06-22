import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';

class GrammarScreen extends StatefulWidget {
  final String? currentLevel;
  const GrammarScreen({super.key, this.currentLevel});

  @override
  State<GrammarScreen> createState() => _GrammarScreenState();
}

class _GrammarScreenState extends State<GrammarScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _allLessons = [];
  List<Map<String, dynamic>> _filteredLessons = [];
  bool _isLoading = true;

  String _selectedLevel = 'A1-A2';
  final List<String> _levels = ['A1-A2', 'B1-B2', 'C1-C2'];

  final List<Color> _cardColors = [
    const Color(0xFFBAA1F6),
    const Color(0xFFFD9E6B),
    const Color(0xFFFD65BD),
    const Color(0xFFDBF494),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.currentLevel != null) {
      _selectedLevel = _mapLevelToRange(widget.currentLevel!);
    }
    _fetchAllLessons();
    _searchCtrl.addListener(_filterLessons);
  }

  @override
  void didUpdateWidget(GrammarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentLevel != oldWidget.currentLevel && widget.currentLevel != null) {
      setState(() {
        _selectedLevel = _mapLevelToRange(widget.currentLevel!);
        _filterLessons();
      });
    }
  }

  String _mapLevelToRange(String level) {
    if (level == 'A1' || level == 'A2') return 'A1-A2';
    if (level == 'B1' || level == 'B2') return 'B1-B2';
    if (level == 'C1' || level == 'C2') return 'C1-C2';
    return 'A1-A2';
  }

  Future<void> _fetchAllLessons() async {
    try {
      setState(() => _isLoading = true);
      final data = await _supabase
          .from('grammar_lessons')
          .select()
          .order('created_at');

      setState(() {
        _allLessons = List<Map<String, dynamic>>.from(data);
        _filterLessons();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching grammar: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterLessons() {
    final query = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredLessons = _allLessons.where((lesson) => lesson['level'] == _selectedLevel).toList();
      } else {
        _filteredLessons = _allLessons.where((lesson) {
          final title = lesson['title'].toString().toLowerCase();
          return title.contains(query);
        }).toList();
      }
    });
  }

  String _getLevelLabel(String level) {
    switch (level) {
      case 'A1-A2': return 'A1-A2 начинающий';
      case 'B1-B2': return 'B1-B2 средний';
      case 'C1-C2': return 'C1-C2 продвинутый';
      default: return level;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
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
                    FocusScope.of(context).unfocus();
                  },
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Выбери уровень',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, fontFamily: 'Poppins'),
              ),
              PopupMenuButton<String>(
                initialValue: _selectedLevel,
                onSelected: (String level) {
                  setState(() {
                    _selectedLevel = level;
                    if (_searchCtrl.text.isNotEmpty) {
                      _searchCtrl.clear();
                    }
                    _filterLessons();
                  });
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                offset: const Offset(0, 40),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _getLevelLabel(_selectedLevel),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.black),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.black),
                    ],
                  ),
                ),
                itemBuilder: (context) => _levels.map((lvl) => PopupMenuItem(
                  value: lvl,
                  child: Text(
                    _getLevelLabel(lvl),
                    style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
                  ),
                )).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _filteredLessons.isEmpty
              ? Center(
            child: Text(
              _searchCtrl.text.isEmpty ? 'Уроков пока нет' : 'Поиск не дал результатов',
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
            itemCount: _filteredLessons.length,
            itemBuilder: (context, index) {
              final lesson = _filteredLessons[index];
              final color = _cardColors[index % _cardColors.length];

              return GestureDetector(
                onTap: () => context.push('/grammar/detail', extra: lesson),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          lesson['level'] ?? '',
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, fontFamily: 'Poppins'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lesson['title'],
                        maxLines: 2,
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
