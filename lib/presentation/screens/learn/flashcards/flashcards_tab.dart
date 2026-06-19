import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../flashcards/flashcard_search_screen.dart';
import '../flashcards/flashcards_screen.dart';
import '../flashcards/create_edit_module_screen.dart';
import 'flashcard_study_screen.dart';
import 'folder_view_screen.dart';

class FlashcardsTab extends StatefulWidget {
  final String currentLevel;
  const FlashcardsTab({super.key, required this.currentLevel});

  @override
  State<FlashcardsTab> createState() => _FlashcardsTabState();
}

class _FlashcardsTabState extends State<FlashcardsTab> {
  final _searchCtrl = TextEditingController();

  // Состояние БД
  bool _isLoading = true;
  List<Map<String, dynamic>> _modules = [];
  List<Map<String, dynamic>> _folders = [];

  final Set<int> _hiddenModuleIds = {};

  // Состояние Библиотеки
  bool _isModulesSelected = true;
  String _selectedLibraryFilter = 'Все';

  // Состояние Карусели
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _carouselTimer;


  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fetchData();
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // Запуск таймера для карусели
  void _startCarouselTimer(int itemsCount) {
    _carouselTimer?.cancel();
    if (itemsCount <= 1) return;

    _carouselTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_pageController.hasClients) {
        int nextPage = _currentPage + 1;
        if (nextPage >= itemsCount) {
          nextPage = 0;
          _pageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        } else {
          _pageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeIn,
          );
        }
      }
    });
  }

  // === ПРИВЯЗКА К SUPABASE ===
  Future<void> _fetchData() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final foldersData = await Supabase.instance.client
          .from('flashcard_folders')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final modulesData = await Supabase.instance.client
          .from('flashcard_modules')
          .select('*, flashcards(id, is_learned)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final parsedModules = (modulesData as List<dynamic>).map((m) {
        final cards = m['flashcards'] as List<dynamic>? ?? [];
        final total = cards.length;
        final progress = cards.where((c) => c['is_learned'] == true).length;

        Color moduleColor = AppColors.accentLight;
        final colorStr = m['color'] as String?;
        if (colorStr != null && colorStr.startsWith('0x')) {
          moduleColor = Color(int.tryParse(colorStr) ?? 0xFFDBF494);
        }

        return {
          'id': m['id'],
          'title': m['title'] ?? 'Без названия',
          'author': 'Вы',
          'progress': progress,
          'total': total,
          'color': moduleColor,
          'is_downloaded': m['original_module_id'] != null,
          'created_at': m['created_at'],
        };
      }).toList();

      if (mounted) {
        setState(() {
          _folders = List<Map<String, dynamic>>.from(foldersData);
          _modules = parsedModules;
          _isLoading = false;
        });

        final activeItemsCount = _modules.where((m) => m['total'] > 0).length;
        _startCarouselTimer(activeItemsCount);
      }
    } catch (e) {
      debugPrint('Ошибка загрузки данных: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createNewFolder(String name) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client.from('flashcard_folders').insert({
        'user_id': userId,
        'name': name.trim(),
      });
      _fetchData(); // Обновляем список после создания
    } catch (e) {
      debugPrint('Ошибка создания папки: $e');
    }
  }

  Widget _buildContinueLearningCarousel() {
    final items = _modules.where((m) => m['total'] > 0 && !_hiddenModuleIds.contains(m['id'])).toList();

    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text('У вас пока нет начатых модулей.', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Poppins')),
      );
    }

    return SizedBox(
      height: 200,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemCount: items.length,
              itemBuilder: (ctx, idx) {
                final item = items[idx];

                final Color bgColor = item['color'];
                final double progressVal = item['total'] == 0 ? 0 : (item['progress'] / item['total']);

                return Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['title'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins'), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('Автор: ${item['author']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary.withOpacity(0.7), fontFamily: 'Poppins')),
                          const Spacer(),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progressVal,
                              minHeight: 6,
                              backgroundColor: Colors.white.withOpacity(0.4),
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('Отсортировано карточек ${item['progress']}/${item['total']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins')),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 38,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FlashcardStudyScreen(
                                      moduleId: item['id'],
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.4),
                                foregroundColor: AppColors.textPrimary,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Продолжить', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                            ),
                          )
                        ],
                      ),
                      Positioned(
                        right: 0, top: 0,
                        child: GestureDetector(
                          onTap: () => _showModuleActionMenu(item),
                          child: const Icon(Icons.more_vert_rounded, color: AppColors.textPrimary),
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          if (items.length > 1) Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(items.length, (i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _currentPage ? 24 : 16,
              height: 6,
              decoration: BoxDecoration(
                color: i == _currentPage ? AppColors.accent : const Color(0xFFD9D9D9),
                borderRadius: BorderRadius.circular(3),
              ),
            )),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        _buildSearchAndCreateRow(),
        const SizedBox(height: 24),

        _buildSectionTitle('Продолжить учебу'),
        const SizedBox(height: 14),
        _buildContinueLearningCarousel(),
        const SizedBox(height: 24),

        _buildSectionTitle('Недавние'),
        const SizedBox(height: 14),
        _buildRecentGrid(),
        const SizedBox(height: 24),

        _buildSectionTitle('Библиотека'),
        const SizedBox(height: 14),
        _buildLibraryToggleButtons(),
        const SizedBox(height: 16),
        _buildLibraryFilterAndContent(),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins'),
    );
  }

  Widget _buildSearchAndCreateRow() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const FlashcardSearchScreen()));
            },
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const IgnorePointer(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Найти модуль',
                    hintStyle: TextStyle(color: Color(0xFFAAAAAA), fontFamily: 'Poppins'),
                    prefixIcon: Icon(Icons.search, color: Color(0xFFAAAAAA), size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _showCreateBottomSheet,
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Row(
              children: [
                Text('Создать ', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14, fontFamily: 'Poppins')),
                Icon(Icons.add, color: AppColors.textPrimary, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentGrid() {
    final items = _modules.where((m) => !_hiddenModuleIds.contains(m['id'])).take(4).toList();
    if (items.isEmpty) return const SizedBox();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 68,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FlashcardsScreen(
                  moduleId: item['id'],
                  title: item['title'],
                  color: item['color'],
                  isOwned: true,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary, width: 1.5),
                  ),
                  child: Center(
                    child: CustomPaint(
                      size: const Size(20, 20),
                      painter: FlashcardIconPainter(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(item['title'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins'), overflow: TextOverflow.ellipsis),
                      Text('${item['total']} карточек • Автор: ${item['author']}', style: TextStyle(fontSize: 9, color: AppColors.textSecondary.withOpacity(0.8), fontFamily: 'Poppins'), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLibraryToggleButtons() {
    return Row(
      children: [
        _buildToggleButton('Модули', _isModulesSelected, () => setState(() => _isModulesSelected = true)),
        const SizedBox(width: 12),
        _buildToggleButton('Папки', !_isModulesSelected, () => setState(() => _isModulesSelected = false)),
      ],
    );
  }

  Widget _buildToggleButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (_isModulesSelected ? AppColors.accentLight : AppColors.orangeLight.withOpacity(0.6))
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins'),
        ),
      ),
    );
  }

  Widget _buildLibraryFilterAndContent() {
    List<Map<String, dynamic>> filteredModules = _modules;
    if (_isModulesSelected) {
      if (_selectedLibraryFilter == 'Созданные') {
        filteredModules = _modules.where((m) => m['is_downloaded'] == false).toList();
      } else if (_selectedLibraryFilter == 'Скачано') {
        filteredModules = _modules.where((m) => m['is_downloaded'] == true).toList();
      } else if (_selectedLibraryFilter == 'Изучено') {
        filteredModules = _modules.where((m) => m['progress'] == m['total'] && m['total'] > 0).toList();
      }
    }

    final int itemCount = _isModulesSelected ? filteredModules.length : _folders.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isModulesSelected) ...[
          PopupMenuButton<String>(
            initialValue: _selectedLibraryFilter,
            onSelected: (v) => setState(() => _selectedLibraryFilter = v),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_selectedLibraryFilter, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins')),
                const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textPrimary, size: 18),
              ],
            ),
            itemBuilder: (ctx) => ['Все', 'Созданные', 'Изучено', 'Скачано'].map((f) => PopupMenuItem(value: f, child: Text(f, style: const TextStyle(fontFamily: 'Poppins')))).toList(),
          ),
          const SizedBox(height: 6),
          const Text('Июнь 2026г', style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA), fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
          const SizedBox(height: 10),
        ],

        if (itemCount == 0)
          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Text('Ничего не найдено', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Poppins')),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: itemCount,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, idx) {
              final isMod = _isModulesSelected;
              final title = isMod ? filteredModules[idx]['title'] : _folders[idx]['name'];
              final subtitle = isMod
                  ? 'Модуль • ${filteredModules[idx]['total']} карточек • Автор: ${filteredModules[idx]['author']}'
                  : 'Папка • Автор: Вы';

              return GestureDetector(
                onTap: () {
                  if (isMod) {
                    final item = filteredModules[idx];
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FlashcardsScreen(
                          moduleId: item['id'],
                          title: item['title'],
                          color: item['color'],
                          isOwned: true,
                        ),
                      ),
                    );
                  } else {
                    final folderItem = _folders[idx];
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FolderViewScreen(
                          folderId: folderItem['id'],
                          initialFolderName: folderItem['name'],
                        ),
                      ),
                    ).then((_) => _fetchData()); // Обновляем библиотеку при возврате
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary, width: 1.5),
                        ),
                        child: Center(
                          child: CustomPaint(
                            size: const Size(22, 22),
                            painter: isMod
                                ? FlashcardIconPainter(color: AppColors.primary)
                                : FolderIconPainter(color: AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins'), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: TextStyle(color: AppColors.textSecondary.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w500, fontFamily: 'Poppins'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  void _showModuleActionMenu(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),

            // Кнопка: Перейти к модулю
            _buildActionMenuRow(Icons.layers_outlined, 'Перейти к модулю', () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FlashcardsScreen(
                    moduleId: item['id'],
                    title: item['title'],
                    color: item['color'],
                    isOwned: true, // Считаем его своим
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),

            // Кнопка: Скрыть
            _buildActionMenuRow(Icons.visibility_off_outlined, 'Скрыть', () {
              Navigator.pop(ctx);
              setState(() {
                _hiddenModuleIds.add(item['id']); // Добавляем ID в список скрытых

                // Пересчитываем карусель, чтобы не сломался таймер
                final activeCount = _modules.where((m) => m['total'] > 0 && !_hiddenModuleIds.contains(m['id'])).length;
                if (activeCount <= 1) _carouselTimer?.cancel();
              });
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildActionMenuRow(IconData icon, String label, VoidCallback onTap) {
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

  void _showCreateFolderDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Новая папка', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Название папки', focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                _createNewFolder(ctrl.text);
              }
            },
            child: const Text('Создать', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCreateBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            _buildCreateOptionRow('Модуль', FlashcardIconPainter(color: AppColors.primary), () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateEditModuleScreen(),
                ),
              ).then((created) {
                if (created == true) _fetchData();
              });
            }),
            const SizedBox(height: 14),
            _buildCreateOptionRow('Папка', FolderIconPainter(color: AppColors.primary), () {
              Navigator.pop(ctx);
              _showCreateFolderDialog();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateOptionRow(String label, CustomPainter painter, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Center(child: CustomPaint(size: const Size(20, 20), painter: painter)),
            ),
            const SizedBox(width: 14),
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins')),
          ],
        ),
      ),
    );
  }
}

// === Отрисовка кастомных иконок ===
class FlashcardIconPainter extends CustomPainter {
  final Color color;
  FlashcardIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path1 = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.1, size.height * 0.2, size.width * 0.6, size.height * 0.7), const Radius.circular(4)));
    final path2 = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.22, size.height * 0.13, size.width * 0.6, size.height * 0.7), const Radius.circular(4)));
    final path3 = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.35, size.height * 0.06, size.width * 0.6, size.height * 0.7), const Radius.circular(4)));

    canvas.drawPath(path1, Paint()..color = color.withOpacity(0.4));
    canvas.drawPath(path2, Paint()..color = color.withOpacity(0.7));
    canvas.drawPath(path3, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FolderIconPainter extends CustomPainter {
  final Color color;
  FolderIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final path = Path()
      ..moveTo(size.width * 0.15, size.height * 0.25)
      ..lineTo(size.width * 0.45, size.height * 0.25)
      ..lineTo(size.width * 0.55, size.height * 0.38)
      ..lineTo(size.width * 0.85, size.height * 0.38)
      ..lineTo(size.width * 0.85, size.height * 0.8)
      ..lineTo(size.width * 0.15, size.height * 0.8)
      ..close();

    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}