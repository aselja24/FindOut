import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import 'create_edit_module_screen.dart';
import 'flashcard_study_screen.dart';

class FlashcardsScreen extends StatefulWidget {
  final int moduleId;
  final String title;
  final Color color;
  final bool isOwned;

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
  List<Map<String, dynamic>> _userFolders = []; // Для меню "Добавить в папку"

  final PageController _pageController = PageController(viewportFraction: 0.9);
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _fetchCards();
    _loadUserFolders();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // --- ЗАГРУЗКА ДАННЫХ ---

  Future<void> _fetchCards() async {
    try {
      final res = await Supabase.instance.client
          .from('flashcards')
          .select()
          .eq('module_id', widget.moduleId)
          .order('id', ascending: true);

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

  Future<void> _loadUserFolders() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final res = await Supabase.instance.client
          .from('flashcard_folders')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      if (mounted) setState(() => _userFolders = List<Map<String, dynamic>>.from(res));
    } catch (e) {
      debugPrint('Ошибка загрузки папок: $e');
    }
  }

  // --- ФУНКЦИОНАЛ МЕНЮ ---

  // 1. Удаление своего модуля
  Future<void> _deleteModule() async {
    setState(() => _isLoading = true);
    try {
      // Сначала удаляем карточки модуля (если не настроен каскадный сброс)
      await Supabase.instance.client.from('flashcards').delete().eq('module_id', widget.moduleId);
      // Затем сам модуль
      await Supabase.instance.client.from('flashcard_modules').delete().eq('id', widget.moduleId);

      if (mounted) Navigator.pop(context); // Возвращаемся в библиотеку
    } catch (e) {
      debugPrint('Ошибка удаления: $e');
      setState(() => _isLoading = false);
    }
  }

  // 2. Скачивание (клонирование) чужого модуля
  Future<void> _downloadModule() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final colorHex = '0x${widget.color.value.toRadixString(16).toUpperCase()}';

      // Создаем копию модуля
      final res = await Supabase.instance.client.from('flashcard_modules').insert({
        'user_id': userId,
        'title': widget.title,
        'color': colorHex,
        'is_public': false,
        'original_module_id': widget.moduleId, // Помечаем, что это скачанный модуль
      }).select('id').single();

      final newModuleId = res['id'];

      // Копируем карточки
      if (_cards.isNotEmpty) {
        final cardsToInsert = _cards.map((c) => {
          'module_id': newModuleId,
          'word': c['word'],
          'translation': c['translation'],
          'is_learned': false,
        }).toList();
        await Supabase.instance.client.from('flashcards').insert(cardsToInsert);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Модуль успешно скачан!', style: TextStyle(fontFamily: 'Poppins'))));
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Ошибка скачивания: $e');
      setState(() => _isLoading = false);
    }
  }

  // --- ИНТЕРФЕЙС ---

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
                // 1. Верхняя панель
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

                // 2. Карусель
                if (_cards.isNotEmpty) ...[
                  SizedBox(
                    height: 200,
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (idx) => setState(() => _currentPage = idx),
                      itemCount: _cards.length,
                      itemBuilder: (ctx, idx) => _buildBigFlashcard(_cards[idx]['word']),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_cards.length, (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 6, height: 6,
                      decoration: BoxDecoration(color: i == _currentPage ? AppColors.accent : const Color(0xFFD9D9D9), shape: BoxShape.circle),
                    )),
                  ),
                  const SizedBox(height: 24),
                ],

                // 3. Заголовок
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins'), overflow: TextOverflow.ellipsis)),
                      Text('${_cards.length} терминов', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'Poppins')),
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
                    itemBuilder: (ctx, idx) => _buildListItem(_cards[idx]['word'], _cards[idx]['translation']),
                  ),
                ),
              ],
            ),

            // 5. Кнопка "Изучать этот модуль" (режим изучения)
            Positioned(
              bottom: 24, left: 24, right: 24,
              child: SizedBox(
                height: 58,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FlashcardStudyScreen(moduleId: widget.moduleId))),
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
      decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(24)),
      child: Stack(
        children: [
          Positioned(left: -20, top: -20, child: CircleAvatar(radius: 60, backgroundColor: Colors.white.withOpacity(0.15))),
          Positioned(right: -40, bottom: -40, child: CircleAvatar(radius: 80, backgroundColor: Colors.white.withOpacity(0.1))),
          Center(child: Text(word, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins'), textAlign: TextAlign.center)),
          const Positioned(right: 16, bottom: 16, child: Icon(Icons.fullscreen_rounded, color: AppColors.textPrimary, size: 24)),
        ],
      ),
    );
  }

  Widget _buildListItem(String word, String translation) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(16)),
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
        ],
      ),
    );
  }

  // === МЕНЮ ОПЦИЙ (Редактировать, Добавить, Изучить, Удалить/Скачать) ===

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
              _buildSheetActionRow(Icons.edit_outlined, 'Редактировать модуль', () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateEditModuleScreen(
                      moduleId: widget.moduleId,
                      initialTitle: widget.title,
                      initialColor: widget.color,
                    ),
                  ),
                ).then((updated) {
                  if (updated == true) _fetchCards(); // Обновляем карточки после возврата
                });
              }),
              const SizedBox(height: 18),
            ],

            _buildSheetActionRow(Icons.create_new_folder_outlined, 'Добавить в папку', () {
              Navigator.pop(ctx);
              _showAddToFolderSheet();
            }),
            const SizedBox(height: 18),

            _buildSheetActionRow(Icons.visibility_outlined, 'Изучить', () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FlashcardStudyScreen(moduleId: widget.moduleId),
                ),
              );
            }),

            // Последняя кнопка зависит от владения
            if (widget.isOwned)
              _buildSheetActionRow(Icons.delete_outline, 'Удалить', () {
                Navigator.pop(ctx);
                _deleteModule();
              })
            else
              _buildSheetActionRow(Icons.file_download_outlined, 'Скачать', () {
                Navigator.pop(ctx);
                _downloadModule();
              }),
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

  // --- МЕНЮ ПАПОК ---

  void _showAddToFolderSheet() {
    int? selectedFolderId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 24),
                  const Text('Добавить в папку', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                  const SizedBox(height: 16),

                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _showCreateFolderSheet();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(16)),
                      child: const Row(
                        children: [
                          Icon(Icons.add, color: AppColors.textPrimary, size: 20),
                          SizedBox(width: 12),
                          Text('Новая папка', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins')),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  ..._userFolders.map((folder) {
                    final isSelected = selectedFolderId == folder['id'];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () {
                          setModalState(() => selectedFolderId = folder['id']);
                          // TODO: Добавить логику привязки модуля к папке в БД
                          Future.delayed(const Duration(milliseconds: 300), () => Navigator.pop(ctx));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.accentLight : AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, color: AppColors.textPrimary, size: 20),
                              const SizedBox(width: 12),
                              Text(folder['name'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins')),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }
      ),
    );
  }

  void _showCreateFolderSheet() {
    final folderCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            const Text('Новая папка', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textSecondary, fontFamily: 'Poppins')),
            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(16)),
              child: TextField(
                controller: folderCtrl,
                autofocus: true,
                style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500),
                decoration: const InputDecoration(
                  hintText: 'Введите название папки...',
                  hintStyle: TextStyle(color: Color(0xFFAAAAAA), fontFamily: 'Poppins'),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  if (folderCtrl.text.trim().isEmpty) return;
                  // TODO: Сохранить папку в БД
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                ),
                child: const Text('Создать папку', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}