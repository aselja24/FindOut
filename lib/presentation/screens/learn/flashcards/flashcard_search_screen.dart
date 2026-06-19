import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../widgets/common/colored_module_card.dart';
import 'flashcards_screen.dart';
import 'create_edit_module_screen.dart';
import 'flashcard_study_screen.dart';

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

  // --- ЗАГРУЗКА ДАННЫХ И ПОИСК ---

  Future<void> _loadUserFolders() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final res = await Supabase.instance.client
          .from('flashcard_folders')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _userFolders = List<Map<String, dynamic>>.from(res);
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки папок: $e');
    }
  }

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
          .select('*, profiles(first_name, avatar_url), flashcards(id)')
          .eq('is_public', true) // Ищем только публичные
          .ilike('title', '%${query.trim()}%')
          .limit(10);

      final parsed = (res as List<dynamic>).map<Map<String, dynamic>>((m) {
        final map = m as Map<String, dynamic>;

        Color moduleColor = AppColors.accentLight;
        final colorStr = map['color'] as String?;
        if (colorStr != null && colorStr.startsWith('0x')) {
          moduleColor = Color(int.tryParse(colorStr) ?? 0xFFDBF494);
        }

        final profile = map['profiles'] as Map<String, dynamic>?;
        final cards = map['flashcards'] as List<dynamic>? ?? [];

        return {
          'id': map['id'],
          'user_id': map['user_id'],
          'title': map['title'],
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

  // --- ЛОГИКА СКАЧИВАНИЯ (КЛОНИРОВАНИЯ) МОДУЛЯ ---

  Future<void> _downloadModule(Map<String, dynamic> module, {int? targetFolderId}) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // ЗАЩИТА ОТ ДУБЛИКАТОВ: Проверяем, не скачивали ли мы его уже
      final existingRes = await Supabase.instance.client
          .from('flashcard_modules')
          .select('id')
          .eq('user_id', userId)
          .eq('original_module_id', module['id'])
          .maybeSingle();

      if (existingRes != null) {
        // Если модуль уже был скачан ранее, просто кладем его в новую папку (если нужно)
        if (targetFolderId != null) {
          await Supabase.instance.client
              .from('flashcard_modules')
              .update({'folder_id': targetFolderId})
              .eq('id', existingRes['id']);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Модуль уже есть в вашей библиотеке и добавлен в папку!', style: TextStyle(fontFamily: 'Poppins')))
          );
        }
        return; // Прерываем функцию, чтобы не качать карточки по второму кругу
      }

      setState(() => _isLoading = true);

      final colorHex = '0x${(module['color'] as Color).value.toRadixString(16).toUpperCase()}';

      // 1. Создаем копию модуля для себя
      final newModuleRes = await Supabase.instance.client.from('flashcard_modules').insert({
        'user_id': userId,
        'title': module['title'],
        'color': colorHex,
        'is_public': false,
        'original_module_id': module['id'],
        if (targetFolderId != null) 'folder_id': targetFolderId,
      }).select('id').single();

      final newModuleId = newModuleRes['id'];

      // 2. Копируем все карточки этого модуля
      final cardsRes = await Supabase.instance.client
          .from('flashcards')
          .select()
          .eq('module_id', module['id']);

      final originalCards = cardsRes as List<dynamic>;
      if (originalCards.isNotEmpty) {
        final cardsToInsert = originalCards.map<Map<String, dynamic>>((c) {
          final map = c as Map<String, dynamic>;
          return {
            'module_id': newModuleId,
            'word': map['word'],
            'translation': map['translation'],
            'is_learned': false,
            if (map.containsKey('image_url')) 'image_url': map['image_url'],
            if (map.containsKey('example')) 'example': map['example'],
          };
        }).toList();

        await Supabase.instance.client.from('flashcards').insert(cardsToInsert);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Модуль успешно скачан!', style: TextStyle(fontFamily: 'Poppins')))
        );
      }
    } catch (e) {
      debugPrint('Ошибка скачивания: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка при скачивании модуля', style: TextStyle(fontFamily: 'Poppins')))
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ИНТЕРФЕЙС ---

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
                    onTap: () => Navigator.pop(context), // Возврат
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
                            isOwned: isOwned,
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

            if (isOwned) ...[
              _buildSheetActionRow(Icons.edit_outlined, 'Редактировать модуль', () {
                Navigator.pop(ctx);
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
                  if (updated == true) _performSearch(_searchCtrl.text);
                });
              }),
              const SizedBox(height: 18),
            ],

            _buildSheetActionRow(Icons.create_new_folder_outlined, 'Добавить в папку', () {
              Navigator.pop(ctx);
              _showAddToFolderSheet(module);
            }),
            const SizedBox(height: 18),

            _buildSheetActionRow(Icons.visibility_outlined, 'Изучить', () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FlashcardStudyScreen(moduleId: module['id']),
                ),
              );
            }),
            const SizedBox(height: 18),

            if (isOwned)
              _buildSheetActionRow(Icons.delete_outline, 'Удалить', () async {
                Navigator.pop(ctx);
                try {
                  await Supabase.instance.client.from('flashcard_modules').delete().eq('id', module['id']);
                  _performSearch(_searchCtrl.text);
                } catch(e) {}
              })
            else
              _buildSheetActionRow(Icons.file_download_outlined, 'Скачать', () {
                Navigator.pop(ctx);
                _downloadModule(module);
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

  // 2. Меню выбора папки
  void _showAddToFolderSheet(Map<String, dynamic> module) {
    int? selectedFolderId;
    bool isSaving = false; // Блокировка от двойного нажатия

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
                      _showCreateFolderSheet(module);
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

                  if (isSaving)
                    const Padding(
                      padding: EdgeInsets.only(top: 20, bottom: 10),
                      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    ),

                  ..._userFolders.map((folder) {
                    final isSelected = selectedFolderId == folder['id'];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: isSaving ? null : () async {
                          setModalState(() {
                            selectedFolderId = folder['id'];
                            isSaving = true;
                          });

                          final currentUserId = Supabase.instance.client.auth.currentUser?.id;
                          final bool isOwned = module['user_id'] == currentUserId;

                          try {
                            if (isOwned) {
                              await Supabase.instance.client.from('flashcard_modules').update({'folder_id': folder['id']}).eq('id', module['id']);
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Добавлено в папку!')));
                            } else {
                              await _downloadModule(module, targetFolderId: folder['id']);
                            }
                          } finally {
                            Future.delayed(const Duration(milliseconds: 300), () {
                              if (mounted) Navigator.pop(ctx);
                            });
                          }
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

  // 3. Меню создания новой папки
  void _showCreateFolderSheet(Map<String, dynamic> moduleToLink) {
    final folderCtrl = TextEditingController();
    bool isSaving = false; // Блокировка от двойного нажатия

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
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
                      enabled: !isSaving, // Блокируем поле при сохранении
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
                      onPressed: isSaving ? null : () async {
                        if (folderCtrl.text.trim().isEmpty) return;

                        setModalState(() => isSaving = true); // БЛОКИРУЕМ КНОПКУ

                        try {
                          final userId = Supabase.instance.client.auth.currentUser?.id;

                          // 1. Создаем папку в БД
                          final res = await Supabase.instance.client.from('flashcard_folders').insert({
                            'user_id': userId,
                            'name': folderCtrl.text.trim(),
                          }).select().single();

                          setState(() {
                            _userFolders.insert(0, res as Map<String, dynamic>);
                          });

                          // 2. Привязываем модуль
                          final bool isOwned = moduleToLink['user_id'] == userId;
                          if (isOwned) {
                            await Supabase.instance.client.from('flashcard_modules').update({'folder_id': res['id']}).eq('id', moduleToLink['id']);
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Папка создана, модуль добавлен!')));
                          } else {
                            await _downloadModule(moduleToLink, targetFolderId: res['id']);
                          }

                          if (mounted) Navigator.pop(ctx);
                        } catch (e) {
                          debugPrint('Ошибка создания папки: $e');
                        } finally {
                          if (mounted) setModalState(() => isSaving = false); // РАЗБЛОКИРУЕМ (если вдруг ошибка)
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                      ),
                      child: isSaving
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Создать папку', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                    ),
                  ),
                ],
              ),
            );
          }
      ),
    );
  }
}