import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import 'create_edit_module_screen.dart';
import 'flashcards_screen.dart';

class FolderViewScreen extends StatefulWidget {
  final int folderId;
  final String initialFolderName;

  const FolderViewScreen({
    super.key,
    required this.folderId,
    required this.initialFolderName,
  });

  @override
  State<FolderViewScreen> createState() => _FolderViewScreenState();
}

class _FolderViewScreenState extends State<FolderViewScreen> {
  bool _isLoading = true;
  late String _folderName;
  List<Map<String, dynamic>> _modules = [];
  String _sortOption = 'Недавние';

  @override
  void initState() {
    super.initState();
    _folderName = widget.initialFolderName;
    _fetchFolderModules();
  }


  Future<void> _fetchFolderModules() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('flashcard_modules')
          .select('*, flashcards(id)')
          .eq('folder_id', widget.folderId);

      final parsed = (res as List<dynamic>).map<Map<String, dynamic>>((m) {
        final map = m as Map<String, dynamic>;
        final cards = map['flashcards'] as List<dynamic>? ?? [];
        return {
          ...map,
          'total_cards': cards.length,
        };
      }).toList();;

      _applySort(parsed, _sortOption);
    } catch (e) {
      debugPrint('Ошибка загрузки модулей папки: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applySort(List<Map<String, dynamic>> list, String sortType) {
    setState(() {
      _sortOption = sortType;
      _modules = list;

      if (sortType == 'Названию') {
        _modules.sort((a, b) => (a['title'] as String).compareTo(b['title'] as String));
      } else {
        // И для "Недавние", и для "Дата добавления" сортируем по дате создания (убывание)
        _modules.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
      }
      _isLoading = false;
    });
  }

  // --- ДЕЙСТВИЯ С ПАПКОЙ ---

  Future<void> _removeModuleFromFolder(int moduleId) async {
    try {
      // Убираем привязку модуля к папке
      await Supabase.instance.client
          .from('flashcard_modules')
          .update({'folder_id': null})
          .eq('id', moduleId);

      setState(() {
        _modules.removeWhere((m) => m['id'] == moduleId);
      });
    } catch (e) {
      debugPrint('Ошибка удаления модуля из папки: $e');
    }
  }

  Future<void> _deleteFolder() async {
    try {
      // Сначала отвязываем все модули
      await Supabase.instance.client
          .from('flashcard_modules')
          .update({'folder_id': null})
          .eq('folder_id', widget.folderId);

      // Удаляем саму папку
      await Supabase.instance.client
          .from('flashcard_folders')
          .delete()
          .eq('id', widget.folderId);

      if (mounted) Navigator.pop(context, true); // Возвращаемся и обновляем библиотеку
    } catch (e) {
      debugPrint('Ошибка удаления папки: $e');
    }
  }

  void _showRenameDialog() {
    final ctrl = TextEditingController(text: _folderName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Переименовать папку', style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Название',
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              try {
                await Supabase.instance.client
                    .from('flashcard_folders')
                    .update({'name': ctrl.text.trim()})
                    .eq('id', widget.folderId);
                setState(() => _folderName = ctrl.text.trim());
                if (mounted) Navigator.pop(ctx);
              } catch (e) {
                debugPrint('Ошибка переименования: $e');
              }
            },
            child: const Text('Сохранить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- ИНТЕРФЕЙС ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_outlined, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(_folderName, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary, size: 28), onPressed: _showFolderMenu),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Меню сортировки
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: PopupMenuButton<String>(
              onSelected: (val) => _applySort(_modules, val),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_sortOption, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontFamily: 'Poppins')),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textPrimary),
                ],
              ),
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'Недавние', child: Text('Недавние', style: TextStyle(fontFamily: 'Poppins'))),
                const PopupMenuItem(value: 'Дата добавления', child: Text('Дата добавления', style: TextStyle(fontFamily: 'Poppins'))),
                const PopupMenuItem(value: 'Названию', child: Text('Названию', style: TextStyle(fontFamily: 'Poppins'))),
              ],
            ),
          ),

          // Список модулей
          Expanded(
            child: _modules.isEmpty
                ? const Center(child: Text('В этой папке пока нет модулей', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Poppins')))
                : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              itemCount: _modules.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, idx) {
                final m = _modules[idx];
                return _buildModuleCard(m);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleCard(Map<String, dynamic> module) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FlashcardsScreen(
              moduleId: module['id'],
              title: module['title'],
              color: Color(int.tryParse(module['color'].toString()) ?? 0xFFDBF494),
              isOwned: true,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: const Icon(Icons.style_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(module['title'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins')),
                  const SizedBox(height: 4),
                  Text('Модуль · ${module['total_cards']} карточек · Автор: Вы', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                ],
              ),
            ),

            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.primary),
              onPressed: () => _removeModuleFromFolder(module['id']),
            ),
          ],
        ),
      ),
    );
  }


  void _showFolderMenu() {
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

            _buildMenuRow(Icons.edit_outlined, 'Редактировать', () {
              Navigator.pop(ctx);
              _showRenameDialog();
            }),
            const SizedBox(height: 18),
            _buildMenuRow(Icons.library_add_outlined, 'Добавить материалы', () {
              Navigator.pop(ctx);
              _showAddMaterialsSheet();
            }),
            const SizedBox(height: 18),
            _buildMenuRow(Icons.delete_outline_rounded, 'Удалить', () {
              Navigator.pop(ctx);
              _deleteFolder();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuRow(IconData icon, String label, VoidCallback onTap) {
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


  void _showAddMaterialsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => AddMaterialsSheet(
        folderId: widget.folderId,
        onMaterialsAdded: _fetchFolderModules, // Обновляем список после добавления
      ),
    );
  }
}

class AddMaterialsSheet extends StatefulWidget {
  final int folderId;
  final VoidCallback onMaterialsAdded;

  const AddMaterialsSheet({super.key, required this.folderId, required this.onMaterialsAdded});

  @override
  State<AddMaterialsSheet> createState() => _AddMaterialsSheetState();
}

class _AddMaterialsSheetState extends State<AddMaterialsSheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _availableModules = [];
  List<Map<String, dynamic>> _filteredModules = [];
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAvailableModules();
    _searchCtrl.addListener(() {
      _filterModules(_searchCtrl.text);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAvailableModules() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final res = await Supabase.instance.client
          .from('flashcard_modules')
          .select('*, flashcards(id)')
          .eq('user_id', userId)
          .isFilter('folder_id', null)
          .order('created_at', ascending: false);

      final parsed = (res as List<dynamic>).map<Map<String, dynamic>>((m) {
        final map = m as Map<String, dynamic>;
        final cards = map['flashcards'] as List<dynamic>? ?? [];
        return {
          ...map,
          'total_cards': cards.length,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _availableModules = parsed;
          _filteredModules = parsed;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки доступных модулей: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterModules(String query) {
    if (query.isEmpty) {
      setState(() => _filteredModules = _availableModules);
      return;
    }
    setState(() {
      _filteredModules = _availableModules.where((m) =>
          (m['title'] as String).toLowerCase().contains(query.toLowerCase())
      ).toList();
    });
  }

  Future<void> _addModuleToFolder(int moduleId) async {
    try {
      await Supabase.instance.client
          .from('flashcard_modules')
          .update({'folder_id': widget.folderId})
          .eq('id', moduleId);

      setState(() {
        _availableModules.removeWhere((m) => m['id'] == moduleId);
        _filterModules(_searchCtrl.text);
      });

      widget.onMaterialsAdded(); // Сигнализируем родительскому виджету обновиться
    } catch (e) {
      debugPrint('Ошибка добавления: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.9, // Занимает 90% экрана
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Шапка
            Row(
              children: [
                IconButton(icon: const Icon(Icons.close_rounded, size: 28), onPressed: () => Navigator.pop(context), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                const Expanded(child: Text('Добавить материалы', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Poppins'))),
                const SizedBox(width: 28), // Для баланса
              ],
            ),
            const SizedBox(height: 24),

            // Список модулей
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _filteredModules.isEmpty
                  ? const Center(child: Text('Нет доступных модулей для добавления', style: TextStyle(fontFamily: 'Poppins')))
                  : ListView.separated(
                itemCount: _filteredModules.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, idx) {
                  final m = _filteredModules[idx];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.primary.withOpacity(0.3))),
                          child: const Icon(Icons.style_rounded, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m['title'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins')),
                              const SizedBox(height: 4),
                              Text('Модуль · ${m['total_cards']} карточек · Автор: Вы', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 28),
                          onPressed: () => _addModuleToFolder(m['id']),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Кнопка Создать модуль
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateEditModuleScreen(targetFolderId: widget.folderId),
                    ),
                  ).then((_) {
                    _fetchAvailableModules();
                    widget.onMaterialsAdded();
                  });
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
                child: const Text('Создать модуль', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
              ),
            ),
            const SizedBox(height: 16),

            // Поиск в самом низу
            Container(
              height: 52,
              decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(26)),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(fontFamily: 'Poppins'),
                decoration: const InputDecoration(
                  hintText: 'Найти модуль',
                  hintStyle: TextStyle(color: AppColors.textSecondary, fontFamily: 'Poppins'),
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}