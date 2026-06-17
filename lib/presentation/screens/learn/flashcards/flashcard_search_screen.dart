import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../widgets/common/colored_module_card.dart';
import 'flashcards_screen.dart';
import 'create_edit_module_screen.dart';

class FlashcardSearchScreen extends StatefulWidget {
  const FlashcardSearchScreen({super.key});

  @override
  State<FlashcardSearchScreen> createState() => _FlashcardSearchScreenState();
}

class _FlashcardSearchScreenState extends State<FlashcardSearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _searchResults = [];

  // Папки пользователя для BottomSheet "Добавить в папку"
  List<Map<String, dynamic>> _userFolders = [];

  @override
  void initState() {
    super.initState();
    _loadUserFolders();
    _searchCtrl.addListener(() {
      _performSearch(_searchCtrl.text);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Загрузка папок текущего пользователя
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

  // Поиск модулей
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await Supabase.instance.client
          .from('flashcard_modules')
          .select('*, profiles!inner(first_name, avatar_url), flashcards(id)')
          .ilike('title', '%${query.trim()}%')
          .limit(10);

      final parsed = (res as List<dynamic>).map((m) {
        Color moduleColor = AppColors.accentLight;
        final colorStr = m['color'] as String?;
        if (colorStr != null && colorStr.startsWith('0x')) {
          moduleColor = Color(int.tryParse(colorStr) ?? 0xFFDBF494);
        }

        final profile = m['profiles'] as Map<String, dynamic>?;
        final cards = m['flashcards'] as List<dynamic>? ?? [];

        return {
          'id': m['id'],
          'user_id': m['user_id'], // <--- Сохраняем ID владельца модуля
          'title': m['title'],
          'total': cards.length,
          'authorName': profile?['first_name'] ?? 'Аноним',
          'authorAvatar': profile?['avatar_url'],
          'color': moduleColor,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _searchResults = parsed;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Ошибка поиска: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Поисковая строка и кнопка Отмена
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        autofocus: true,
                        style: const TextStyle(fontSize: 14, fontFamily: 'Poppins', fontWeight: FontWeight.w500),
                        decoration: const InputDecoration(
                          hintText: 'Поиск...',
                          hintStyle: TextStyle(color: Color(0xFFAAAAAA), fontFamily: 'Poppins'),
                          prefixIcon: Icon(Icons.search, color: Color(0xFFAAAAAA), size: 20),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => Navigator.pop(context), // Возврат на предыдущий экран
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Center(
                        child: Text(
                          'Отмена',
                          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14, fontFamily: 'Poppins'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Результаты поиска
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _searchResults.isEmpty && _searchCtrl.text.isNotEmpty
                  ? const Center(child: Text('Ничего не найдено', style: TextStyle(fontFamily: 'Poppins', color: AppColors.textSecondary)))
                  : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (ctx, idx) {
                  final item = _searchResults[idx];
                  return ColoredModuleCard(
                    title: item['title'],
                    termsCount: item['total'],
                    authorName: item['authorName'],
                    authorAvatarUrl: item['authorAvatar'],
                    backgroundColor: item['color'],
                    onStudyPressed: () {
                      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
                      final bool isOwned = item['user_id'] == currentUserId;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FlashcardsScreen(
                            moduleId: item['id'],
                            title: item['title'],
                            color: item['color'],
                            isOwned: isOwned, // Передаем статус владения на экран просмотра
                          ),
                        ),
                      );
                    },
                    onMorePressed: () => _showModuleOptionsSheet(item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // BOTTOM SHEETS (Нижние меню)
  // ==========================================

  void _showModuleOptionsSheet(Map<String, dynamic> module) {
    // Проверяем, является ли текущий пользователь владельцем модуля
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final bool isOwned = module['user_id'] == currentUserId;

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

            // Если мы владельцы — показываем "Редактировать модуль"
            if (isOwned) ...[
              _buildSheetActionRow(Icons.edit_outlined, 'Редактировать модуль', () {
                Navigator.pop(ctx); // Закрываем меню
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateEditModuleScreen(
                      moduleId: module['id'],
                      initialTitle: module['title'],
                      initialColor: module['color'],
                    ),
                  ),
                ).then((updated) {
                  // Обновляем результаты поиска, если мы что-то изменили
                  if (updated == true) _performSearch(_searchCtrl.text);
                });
              }),
              const SizedBox(height: 18),
            ],

            _buildSheetActionRow(Icons.create_new_folder_outlined, 'Добавить в папку', () {
              Navigator.pop(ctx);
              _showAddToFolderSheet(module['id']);
            }),
            const SizedBox(height: 18),
            _buildSheetActionRow(Icons.visibility_outlined, 'Изучить', () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FlashcardsScreen(
                    moduleId: module['id'],
                    title: module['title'],
                    color: module['color'],
                    isOwned: isOwned,
                  ),
                ),
              );
            }),
            const SizedBox(height: 18),

            // Если мы владельцы — показываем "Удалить", иначе "Скачать"
            if (isOwned)
              _buildSheetActionRow(Icons.delete_outline, 'Удалить', () {
                // TODO: Логика удаления модуля
                Navigator.pop(ctx);
              })
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

  // 2. Меню выбора папки
  void _showAddToFolderSheet(int moduleId) {
    int? selectedFolderId; // Локальный стейт для выбора папки

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
                              Icon(
                                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                color: AppColors.textPrimary,
                                size: 20,
                              ),
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

  // 3. Меню создания новой папки
  void _showCreateFolderSheet() {
    final folderCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true, // Чтобы не перекрывало клавиатурой
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
                  // TODO: Сохранить в БД и обновить _userFolders
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