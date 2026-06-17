import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';

class FlashcardsScreen extends StatefulWidget {
  final int moduleId;
  final String title;
  final Color color;
  final bool isOwned; // <--- НОВЫЙ ПАРАМЕТР (Свой или чужой модуль)

  const FlashcardsScreen({
    super.key,
    required this.moduleId,
    required this.title,
    required this.color,
    required this.isOwned,
  });

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _cards = [];

  final PageController _pageController = PageController(viewportFraction: 0.9);
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _fetchCards();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Загружаем карточки (слова) из БД
  Future<void> _fetchCards() async {
    try {
      final res = await Supabase.instance.client
          .from('flashcards')
          .select()
          .eq('module_id', widget.moduleId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _cards = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки слов модуля: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Верхняя панель (Назад и Меню)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                      IconButton(
                        icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary, size: 28),
                        onPressed: () => _showModuleOptionsSheet(),
                      ),
                    ],
                  ),
                ),

                // 2. Карусель больших карточек
                if (_cards.isNotEmpty) ...[
                  SizedBox(
                    height: 200,
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (idx) => setState(() => _currentPage = idx),
                      itemCount: _cards.length,
                      itemBuilder: (ctx, idx) {
                        final card = _cards[idx];
                        return _buildBigFlashcard(card['word']);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Индикатор точек
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_cards.length, (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _currentPage ? AppColors.accent : const Color(0xFFD9D9D9),
                        shape: BoxShape.circle,
                      ),
                    )),
                  ),
                  const SizedBox(height: 24),
                ],

                // 3. Заголовок и счетчик
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${_cards.length} терминов',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'Poppins'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Список слов
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                    itemCount: _cards.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, idx) {
                      final card = _cards[idx];
                      return _buildListItem(card['word'], card['translation']);
                    },
                  ),
                ),
              ],
            ),

            // 5. Плавающая кнопка
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: SizedBox(
                height: 58,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('Изучать этот модуль', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBigFlashcard(String word) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -20,
            top: -20,
            child: CircleAvatar(radius: 60, backgroundColor: Colors.white.withOpacity(0.15)),
          ),
          Positioned(
            right: -40,
            bottom: -40,
            child: CircleAvatar(radius: 80, backgroundColor: Colors.white.withOpacity(0.1)),
          ),
          Center(
            child: Text(
              word,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins'),
              textAlign: TextAlign.center,
            ),
          ),
          const Positioned(
            right: 16,
            bottom: 16,
            child: Icon(Icons.fullscreen_rounded, color: AppColors.textPrimary, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(String word, String translation) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(word, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins')),
                const SizedBox(height: 4),
                Text(translation, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary, fontFamily: 'Poppins')),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.volume_up_rounded, color: AppColors.textPrimary, size: 24),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // === ДИНАМИЧЕСКОЕ МЕНЮ ОПЦИЙ ===
  void _showModuleOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),

            // Если модуль НАШ (создан нами или скачан), показываем редактирование
            if (widget.isOwned) ...[
              _buildSheetActionRow(Icons.edit_outlined, 'Редактировать модуль', () => Navigator.pop(ctx)),
              const SizedBox(height: 18),
            ],

            // Эти две кнопки есть у всех модулей
            _buildSheetActionRow(Icons.create_new_folder_outlined, 'Добавить в папку', () => Navigator.pop(ctx)),
            const SizedBox(height: 18),
            _buildSheetActionRow(Icons.visibility_outlined, 'Изучить', () => Navigator.pop(ctx)),
            const SizedBox(height: 18),

            // Последняя кнопка зависит от владения
            if (widget.isOwned)
              _buildSheetActionRow(Icons.delete_outline, 'Удалить', () => Navigator.pop(ctx))
            else
              _buildSheetActionRow(Icons.file_download_outlined, 'Скачать', () => Navigator.pop(ctx)),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetActionRow(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 14),
          Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontFamily: 'Poppins')),
        ],
      ),
    );
  }
}