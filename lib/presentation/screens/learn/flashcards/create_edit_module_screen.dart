import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';

class CreateEditModuleScreen extends StatefulWidget {
  final int? moduleId; // Если null -> Создание, иначе -> Редактирование
  final String? initialTitle;
  final Color? initialColor;

  const CreateEditModuleScreen({
    super.key,
    this.moduleId,
    this.initialTitle,
    this.initialColor,
  });

  @override
  State<CreateEditModuleScreen> createState() => _CreateEditModuleScreenState();
}

class _CreateEditModuleScreenState extends State<CreateEditModuleScreen> {
  bool _isLoading = false;
  bool _showColorPicker = false;

  late TextEditingController _titleCtrl;
  Color _selectedColor = const Color(0xFFFFA5D9); // По умолчанию розовый

  // Список контроллеров для карточек
  final List<Map<String, TextEditingController>> _cards = [];

  // Доступные цвета из макета
  final List<Color> _palette = [
    const Color(0xFFFD9E6B), // Оранжевый
    const Color(0xFFBAA1F6), // Фиолетовый
    const Color(0xFFDBF494), // Салатовый
    const Color(0xFFFFA5D9), // Розовый
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle ?? '');
    if (widget.initialColor != null) {
      _selectedColor = widget.initialColor!;
    }

    if (widget.moduleId != null) {
      // Режим редактирования: грузим карточки из БД
      _loadExistingCards();
    } else {
      // Режим создания: даем 2 пустые карточки по умолчанию
      _addNewCard();
      _addNewCard();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    for (var card in _cards) {
      card['term']?.dispose();
      card['def']?.dispose();
    }
    super.dispose();
  }

  void _addNewCard({String term = '', String def = ''}) {
    setState(() {
      _cards.add({
        'term': TextEditingController(text: term),
        'def': TextEditingController(text: def),
      });
    });
  }

  Future<void> _loadExistingCards() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('flashcards')
          .select()
          .eq('module_id', widget.moduleId!)
          .order('id', ascending: true);

      setState(() {
        _cards.clear();
        for (var row in res) {
          _addNewCard(term: row['word'], def: row['translation']);
        }
        if (_cards.isEmpty) {
          _addNewCard();
          _addNewCard();
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки карточек: $e');
      setState(() => _isLoading = false);
    }
  }

  // Сохранение модуля и карточек в БД
  Future<void> _saveModule() async {
    if (_titleCtrl.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final colorHex = '0x${_selectedColor.value.toRadixString(16).toUpperCase()}';
      int currentModuleId;

      if (widget.moduleId == null) {
        // СОЗДАНИЕ
        final res = await Supabase.instance.client.from('flashcard_modules').insert({
          'user_id': userId,
          'title': _titleCtrl.text.trim(),
          'color': colorHex,
          'is_public': true, // Или брать из настроек
        }).select('id').single();
        currentModuleId = res['id'];
      } else {
        // РЕДАКТИРОВАНИЕ
        currentModuleId = widget.moduleId!;
        await Supabase.instance.client.from('flashcard_modules').update({
          'title': _titleCtrl.text.trim(),
          'color': colorHex,
        }).eq('id', currentModuleId);

        // Удаляем старые карточки, чтобы записать новые
        await Supabase.instance.client.from('flashcards').delete().eq('module_id', currentModuleId);
      }

      // Добавляем карточки
      final cardsToInsert = _cards
          .where((c) => c['term']!.text.trim().isNotEmpty && c['def']!.text.trim().isNotEmpty)
          .map((c) => {
        'module_id': currentModuleId,
        'word': c['term']!.text.trim(),
        'translation': c['def']!.text.trim(),
        'is_learned': false,
      })
          .toList();

      if (cardsToInsert.isNotEmpty) {
        await Supabase.instance.client.from('flashcards').insert(cardsToInsert);
      }

      if (mounted) Navigator.pop(context, true); // Возвращаемся и сигнализируем об успехе
    } catch (e) {
      debugPrint('Ошибка сохранения: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Светло-серый фон как на макете
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // 1. Верхний AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          widget.moduleId == null ? 'Создать модуль' : 'Редактировать',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, color: AppColors.textPrimary, size: 26),
                        onPressed: () {}, // TODO: Экран настроек модуля
                      ),
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline_rounded, color: AppColors.textPrimary, size: 26),
                        onPressed: _saveModule,
                      ),
                    ],
                  ),
                ),

                // 2. Скроллируемая область
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                      : ListView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 100), // Отступ снизу для панели
                    children: [
                      // Ввод названия модуля
                      TextField(
                        controller: _titleCtrl,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins'),
                        decoration: const InputDecoration(
                          hintText: 'Предмет, глава, раздел',
                          hintStyle: TextStyle(color: Color(0xFFAAAAAA)),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textPrimary, width: 2)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary, width: 2)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text('название', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                      const SizedBox(height: 32),

                      // Список Карточек
                      ...List.generate(_cards.length, (index) => _buildCardItem(index)),
                    ],
                  ),
                ),
              ],
            ),

            // Всплывающая палитра цветов (поверх всего)
            if (_showColorPicker)
              Positioned(
                bottom: 85,
                right: 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _palette.map((color) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedColor = color;
                            _showColorPicker = false;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          width: 28, height: 28,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

            // 3. Нижняя фиксированная панель (Счетчик, Плюс, Цвет)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: 75,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Счетчик карточек
                    Row(
                      children: [
                        const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text('1/${_cards.length}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                      ],
                    ),

                    // Кнопка добавления карточки
                    GestureDetector(
                      onTap: () {
                        _addNewCard();
                        // Скроллинг вниз можно добавить через ScrollController
                      },
                      child: Container(
                        width: 48, height: 48,
                        decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                        child: const Icon(Icons.add, color: AppColors.textPrimary, size: 28),
                      ),
                    ),

                    // Кнопка выбора цвета
                    GestureDetector(
                      onTap: () => setState(() => _showColorPicker = !_showColorPicker),
                      child: Container(
                        width: 42, height: 42,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey[300]!, width: 2),
                        ),
                        child: Container(
                          decoration: BoxDecoration(color: _selectedColor, shape: BoxShape.circle),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardItem(int index) {
    final termCtrl = _cards[index]['term']!;
    final defCtrl = _cards[index]['def']!;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Поле "Термин" + Иконка картинки
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: termCtrl,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary, fontFamily: 'Poppins'),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.only(bottom: 8),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textPrimary, width: 1.5)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {}, // TODO: Выбор картинки
                child: const Icon(Icons.image_outlined, color: AppColors.textSecondary, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('термин', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'Poppins')),

          const SizedBox(height: 16),

          // Поле "Определение"
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: defCtrl,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary, fontFamily: 'Poppins'),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.only(bottom: 8),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textPrimary, width: 1.5)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {}, // TODO: Выбор картинки
                child: const Icon(Icons.image_outlined, color: AppColors.textSecondary, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('определение', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'Poppins')),
        ],
      ),
    );
  }
}