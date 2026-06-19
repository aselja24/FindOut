import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';

class FlashcardStudyScreen extends StatefulWidget {
  final int moduleId;

  const FlashcardStudyScreen({super.key, required this.moduleId});

  @override
  State<FlashcardStudyScreen> createState() => _FlashcardStudyScreenState();
}

class _FlashcardStudyScreenState extends State<FlashcardStudyScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _originalCards = [];
  List<Map<String, dynamic>> _activeCards = [];
  List<Map<String, dynamic>> _unknownCardsToRepeat = [];

  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _progressSaved = false;

  // Настройки
  bool _shuffle = false;
  bool _tts = true;
  bool _sortByStacks = true;
  bool _frontIsGerman = true; // true = Немецкий, false = Русский

  // Счетчики
  int _knownCount = 0;
  int _unknownCount = 0;

  // Анимация свайпа
  Offset _dragOffset = Offset.zero;
  double _dragAngle = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _fetchCards();
  }

  Future<void> _fetchCards() async {
    try {
      final res = await Supabase.instance.client
          .from('flashcards')
          .select()
          .eq('module_id', widget.moduleId)
          .order('id', ascending: true);

      if (mounted) {
        setState(() {
          _originalCards = List<Map<String, dynamic>>.from(res);
          _startSession();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки слов: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startSession({bool onlyUnknown = false}) {
    setState(() {
      if (onlyUnknown) {
        _activeCards = List.from(_unknownCardsToRepeat);
      } else {
        _activeCards = List.from(_originalCards);
        _unknownCount = 0;
        _knownCount = 0;
      }

      if (_shuffle) _activeCards.shuffle();

      _currentIndex = 0;
      _isFlipped = false;
      _progressSaved = false; //рухсари
      _unknownCardsToRepeat.clear();
      _dragOffset = Offset.zero;
      _dragAngle = 0.0;
    });
  }

  // --- ЛОГИКА СВАЙПОВ ---

  void _onPanStart(DragStartDetails details) {
    setState(() => _isDragging = true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
      _dragAngle = _dragOffset.dx / 400; // Наклон при свайпе
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() => _isDragging = false);
    if (_dragOffset.dx > 100) {
      _handleSwipe(true); // Вправо -> Знаю
    } else if (_dragOffset.dx < -100) {
      _handleSwipe(false); // Влево -> Не знаю
    } else {
      // Возврат в центр
      setState(() {
        _dragOffset = Offset.zero;
        _dragAngle = 0.0;
      });
    }
  }

  void _handleSwipe(bool isKnown) {
    if (isKnown) {
      _knownCount++;
    } else {
      _unknownCount++;
      _unknownCardsToRepeat.add(_activeCards[_currentIndex]);
    }

    setState(() {
      _dragOffset = Offset.zero;
      _dragAngle = 0.0;
      _isFlipped = false;
      _currentIndex++;

      // <-- ДОБАВИТЬ ЭТОТ БЛОК: Рухсари
      // Если дошли до конца, нет ошибок и еще не сохраняли
      if (_currentIndex >= _activeCards.length && _unknownCount == 0 && !_progressSaved) {
        _saveModuleProgress();
      }
    });
  }
  //Рухсари
  Future<void> _saveModuleProgress() async {
    _progressSaved = true;
    try {
      await Supabase.instance.client
          .from('flashcards')
          .update({'is_learned': true})
          .eq('module_id', widget.moduleId);
    } catch (e) {
      debugPrint('Ошибка сохранения прогресса модуля: $e');
    }
  }

  void _undoSwipe() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _isFlipped = false;
        // Для простоты отменяем счетчик, предполагая, что это была последняя карточка
        // В идеале нужно хранить историю свайпов, но для старта этого достаточно
      });
    }
  }

  // --- ИНТЕРФЕЙС ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    if (_originalCards.isEmpty) return const Scaffold(backgroundColor: Colors.white, body: Center(child: Text('Нет карточек', style: TextStyle(fontFamily: 'Poppins'))));

    final isSessionFinished = _currentIndex >= _activeCards.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: isSessionFinished ? _buildResultsScreen() : _buildStudyScreen(),
      ),
    );
  }

  Widget _buildStudyScreen() {
    final progress = _activeCards.isEmpty ? 0.0 : (_currentIndex / _activeCards.length);

    return Column(
      children: [
        // 1. AppBar и Прогресс-бар
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 24), onPressed: () => Navigator.pop(context)),
              Text('${_currentIndex + 1}/${_activeCards.length}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins')),
              IconButton(icon: const Icon(Icons.settings_outlined, color: AppColors.textPrimary, size: 26), onPressed: _showSettingsSheet),
            ],
          ),
        ),

        // Линия прогресса
        Container(
          height: 6, width: double.infinity, color: Colors.grey[200],
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress > 1 ? 1 : progress,
            child: Container(color: const Color(0xFFC7F464)), // Яркий зеленый
          ),
        ),
        const SizedBox(height: 16),

        // 2. Счетчики (Оранжевый и Зеленый)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCounterBadge(_unknownCount.toString(), const Color(0xFFE5805E)), // Оранжевый
              _buildCounterBadge(_knownCount.toString(), const Color(0xFFC7F464)), // Зеленый
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 3. Карточки (Stack для свайпа)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Следующая карточка (на фоне)
                if (_currentIndex < _activeCards.length - 1)
                  Transform.scale(
                    scale: 0.95,
                    child: _buildCardSide(_activeCards[_currentIndex + 1], false),
                  ),

                // Текущая активная карточка (Свайпается)
                if (_currentIndex < _activeCards.length)
                  GestureDetector(
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    onTap: () => setState(() => _isFlipped = !_isFlipped),
                    child: AnimatedContainer(
                      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      transform: Matrix4.translationValues(_dragOffset.dx, _dragOffset.dy, 0)..rotateZ(_dragAngle),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder: _flipTransition,
                        child: _isFlipped
                            ? _buildCardSide(_activeCards[_currentIndex], true, key: const ValueKey('back'))
                            : _buildCardSide(_activeCards[_currentIndex], false, key: const ValueKey('front')),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // 4. Нижние кнопки (Назад и Плей)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(icon: const Icon(Icons.undo_rounded, color: AppColors.textSecondary, size: 28), onPressed: _undoSwipe),
              IconButton(icon: const Icon(Icons.play_arrow_rounded, color: AppColors.textSecondary, size: 32), onPressed: () {}), // Для автоплея, если нужно
            ],
          ),
        )
      ],
    );
  }

  Widget _flipTransition(Widget child, Animation<double> animation) {
    final rotateAnim = Tween(begin: pi, end: 0.0).animate(animation);
    return AnimatedBuilder(
      animation: rotateAnim,
      child: child,
      builder: (context, widget) {
        final isUnder = (ValueKey(_isFlipped) != widget?.key);
        var tilt = ((animation.value - 0.5).abs() - 0.5) * 0.003;
        tilt *= isUnder ? -1.0 : 1.0;
        final value = isUnder ? min(rotateAnim.value, pi / 2) : rotateAnim.value;
        return Transform(transform: Matrix4.rotationY(value)..setEntry(3, 0, tilt), alignment: Alignment.center, child: widget);
      },
    );
  }

  Widget _buildCounterBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16, fontFamily: 'Poppins')),
    );
  }

  Widget _buildCardSide(Map<String, dynamic> cardData, bool isBack, {Key? key}) {
    final textToShow = isBack
        ? (_frontIsGerman ? cardData['translation'] : cardData['word'])
        : (_frontIsGerman ? cardData['word'] : cardData['translation']);

    return Container(
      key: key,
      width: double.infinity, height: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFA5D9), // Розовая карточка
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Stack(
        children: [
          // Декоративные круги
          Positioned(left: -20, top: -20, child: CircleAvatar(radius: 60, backgroundColor: Colors.white.withOpacity(0.15))),
          Positioned(right: -40, bottom: -40, child: CircleAvatar(radius: 80, backgroundColor: Colors.white.withOpacity(0.1))),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_tts) const Icon(Icons.volume_up_rounded, color: AppColors.textPrimary, size: 26) else const SizedBox(),
              ],
            ),
          ),

          Center(
            child: Text(
              textToShow,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins'),
            ),
          ),
        ],
      ),
    );
  }

  // --- ЭКРАН РЕЗУЛЬТАТОВ ---

  Widget _buildResultsScreen() {
    final total = _activeCards.length;
    final double percent = total == 0 ? 0 : (_knownCount / total);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.pop(context)),
              Text('$total/$total', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
              IconButton(icon: const Icon(Icons.settings_outlined), onPressed: _showSettingsSheet),
            ],
          ),
          const SizedBox(height: 32),

          const Align(alignment: Alignment.centerLeft, child: Text('Твой прогресс', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, fontFamily: 'Poppins'))),
          const SizedBox(height: 32),

          // Круговой график
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 140, height: 140,
                child: CustomPaint(
                  painter: ProgressDonutPainter(percent: percent),
                  child: Center(child: Text('${(percent * 100).toInt()}%', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textSecondary, fontFamily: 'Poppins'))),
                ),
              ),
              const SizedBox(width: 32),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildResultPill('Знаю', _knownCount, const Color(0xFFD6F58E)),
                  const SizedBox(height: 12),
                  _buildResultPill('Не знаю', _unknownCount, const Color(0xFFE5805E)),
                ],
              )
            ],
          ),

          // === ДОБАВЛЕНА КАРТИНКА ===
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Image.asset(
                'assets/images/flash/flash.png',
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Кнопки
          if (_unknownCount > 0)
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: () => _startSession(onlyUnknown: true),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBCA6F6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)), elevation: 0),
                child: Text('Продолжить повтор $_unknownCount терминов', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: () => _startSession(onlyUnknown: false),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)), elevation: 0),
              child: const Text('Начать заново', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildResultPill(String label, int count, Color color) {
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontFamily: 'Poppins')),
          Text(count.toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins')),
        ],
      ),
    );
  }

  // --- НАСТРОЙКИ (BOTTOM SHEET) ---

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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

                  const Text('Основные', style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                  const Divider(),

                  _buildSwitchRow('Перемешать карточки', _shuffle, (val) => setModalState(() => _shuffle = val)),
                  _buildSwitchRow('Преобразование текста в речь', _tts, (val) => setModalState(() => _tts = val)),
                  _buildSwitchRow('Сортировка по стопкам', _sortByStacks, (val) => setModalState(() => _sortByStacks = val)),

                  const SizedBox(height: 24),
                  const Text('Формат карточек', style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                  const Divider(),
                  const SizedBox(height: 12),

                  const Text('Лицевая сторона', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontFamily: 'Poppins')),
                  const SizedBox(height: 12),

                  // Переключатель языка
                  Container(
                    height: 48,
                    decoration: BoxDecoration(color: const Color(0xFFBCA6F6), borderRadius: BorderRadius.circular(24)),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => _frontIsGerman = true),
                            child: Container(
                              decoration: BoxDecoration(color: _frontIsGerman ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(24)),
                              alignment: Alignment.center,
                              child: Text('Немецкий', style: TextStyle(color: _frontIsGerman ? AppColors.textPrimary : Colors.white, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => _frontIsGerman = false),
                            child: Container(
                              decoration: BoxDecoration(color: !_frontIsGerman ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(24)),
                              alignment: Alignment.center,
                              child: Text('Русский', style: TextStyle(color: !_frontIsGerman ? AppColors.textPrimary : Colors.white, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _startSession(onlyUnknown: false); // Применяем настройки и сбрасываем
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF1F1F1), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
                      child: const Text('Пройти карточки заново', style: TextStyle(color: Color(0xFFCA4B24), fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                    ),
                  ),
                ],
              ),
            );
          }
      ),
    ).then((_) => setState((){})); // Обновляем главный экран при закрытии
  }

  Widget _buildSwitchRow(String title, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontFamily: 'Poppins'))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFFBCA6F6),
          ),
        ],
      ),
    );
  }
}

// --- ОТРИСОВКА КРУГОВОГО ГРАФИКА ---
class ProgressDonutPainter extends CustomPainter {
  final double percent;

  ProgressDonutPainter({required this.percent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) - 10;
    const strokeWidth = 20.0;

    // Оранжевый фон (Не знаю)
    final bgPaint = Paint()
      ..color = const Color(0xFFE5805E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Зеленый прогресс (Знаю)
    final progressPaint = Paint()
      ..color = const Color(0xFFD6F58E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Рисуем фоновое (оранжевое) кольцо
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), 0, 2 * pi, false, bgPaint);

    // Рисуем зеленый прогресс
    final sweepAngle = 2 * pi * percent;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -pi / 2, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}