import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';

enum TestState { loading, playing, checking, result, review }

class GrammarTestScreen extends StatefulWidget {
  final int lessonId;

  const GrammarTestScreen({super.key, required this.lessonId});

  @override
  State<GrammarTestScreen> createState() => _GrammarTestScreenState();
}

class _GrammarTestScreenState extends State<GrammarTestScreen> {
  List<dynamic> _questions = [];
  List<dynamic> _wrongAnswers = [];

  TestState _currentState = TestState.loading;
  int _currentIndex = 0;
  int? _selectedOptionIndex;
  int _correctAnswersCount = 0;

  // Цвета из макетов
  final Color _purple = const Color(0xFF7B4DFE);
  final Color _orange = const Color(0xFFFF9D66);
  final Color _green = const Color(0xFFC3F336);
  final Color _pink = const Color(0xFFFF9DE6);
  final Color _darkText = const Color(0xFF2D2D2D);
  final Color _red = const Color(0xFFE86B43);
  final Color _bgGray = const Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    try {
      final response = await Supabase.instance.client
          .from('grammar_questions')
          .select()
          .eq('lesson_id', widget.lessonId)
          .order('id', ascending: true);

      setState(() {
        _questions = response;
        _currentState = _questions.isEmpty ? TestState.result : TestState.playing;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
    }
  }

  // Сохранение прогресса в БД
  Future<void> _saveProgressToDB() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client.from('user_progress').upsert({
          'user_id': user.id,
          'item_type': 'grammar_test',
          'item_id': widget.lessonId,
          'completed_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Ошибка сохранения прогресса: $e');
      }
    }
  }

  void _recordAnswer() {
    final question = _questions[_currentIndex];
    final correctIndex = question['correct_index'] as int;

    if (_selectedOptionIndex == correctIndex) {
      _correctAnswersCount++;
    } else {
      _wrongAnswers.add({
        'question': question,
        'selected_index': _selectedOptionIndex,
      });
    }
  }

  void _checkAnswer() {
    if (_selectedOptionIndex == null) return;
    _recordAnswer();
    setState(() {
      _currentState = TestState.checking;
    });
  }

  void _nextQuestion() async {
    // Если мы не проверяли ответ кнопкой "Проверить", то тихо сохраняем его сейчас
    if (_currentState == TestState.playing) {
      if (_selectedOptionIndex == null) return;
      _recordAnswer();
    }

    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOptionIndex = null;
        _currentState = TestState.playing;
      });
    } else {
      // Сохраняем в базу перед показом результатов
      await _saveProgressToDB();
      setState(() {
        _currentState = TestState.result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopMockupHeader(),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // ВЕРХНИЙ КОЛОНТИТУЛ (Как на макете)
  // ==========================================
  Widget _buildTopMockupHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(backgroundColor: _purple, radius: 20, child: const Icon(Icons.person, color: Colors.white)),
              Row(
                children: [
                  const Text('0 ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const Icon(Icons.local_fire_department_outlined, color: Colors.orange),
                  const SizedBox(width: 16),
                  Icon(Icons.notifications_none, color: _purple),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Начинающий - А1', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const Icon(Icons.keyboard_arrow_down, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(height: 6, decoration: BoxDecoration(color: const Color(0xFFEEEEEE), borderRadius: BorderRadius.circular(3))),
              LayoutBuilder(
                builder: (context, constraints) => Container(
                  width: constraints.maxWidth * 0.2,
                  height: 6,
                  decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(3)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(20)),
              child: const Text('А1-начинающий', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentState) {
      case TestState.loading:
        return Center(child: CircularProgressIndicator(color: _purple));
      case TestState.playing:
      case TestState.checking:
        return _buildTestContent();
      case TestState.result:
        return _buildResultContent();
      case TestState.review:
        return _buildReviewContent();
    }
  }

  // ==========================================
  // 1. ЭКРАН ТЕСТА (Вопрос и Проверка)
  // ==========================================
  Widget _buildTestContent() {
    final question = _questions[_currentIndex];
    final options = List<String>.from(question['options']);
    final correctIndex = question['correct_index'] as int;
    final isChecking = _currentState == TestState.checking;
    final isLastQuestion = _currentIndex == _questions.length - 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ТЕСТ', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: _darkText)),
          Container(height: 4, width: double.infinity, color: _purple, margin: const EdgeInsets.only(top: 8, bottom: 24)),

          const Text(
            'Личные местоимения и глаголы в настоящем времени',
            style: TextStyle(fontSize: 16, color: Color(0xFF555555)),
          ),
          const SizedBox(height: 32),

          // Карточка с вопросом
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_currentIndex + 1}. Выбери правильный вариант',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _darkText),
                    ),
                    if (isChecking && _selectedOptionIndex != correctIndex)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: _red, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(question['question'], style: TextStyle(fontSize: 16, color: _darkText, height: 1.5)),
                const SizedBox(height: 24),

                // Варианты ответов (Pills)
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: List.generate(options.length, (index) {
                    final isSelected = _selectedOptionIndex == index;
                    return GestureDetector(
                      onTap: isChecking ? null : () => setState(() => _selectedOptionIndex = index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? _purple : _purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          options[index],
                          style: TextStyle(
                            color: isSelected ? Colors.white : _purple,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          if (isChecking) ...[
            const SizedBox(height: 24),
            Text.rich(
              TextSpan(
                text: 'Правильный ответ: ',
                style: const TextStyle(fontSize: 15, color: Color(0xFF555555)),
                children: [
                  TextSpan(text: options[correctIndex], style: TextStyle(color: _purple, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Объяснение', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _darkText)),
            const SizedBox(height: 8),
            Text(
              question['explanation'] ?? '',
              style: const TextStyle(fontSize: 15, color: Color(0xFF555555), height: 1.5),
            ),
          ],

          const SizedBox(height: 40),

          // Кнопки управления внизу
          // Кнопки управления внизу
          Row(
            mainAxisAlignment: isChecking ? MainAxisAlignment.end : MainAxisAlignment.spaceBetween,
            children: [
              if (!isChecking)
                SizedBox(
                  width: 140,
                  child: _CustomButton(
                    text: 'Проверить',
                    color: _orange,
                    textColor: Colors.black,
                    onPressed: _selectedOptionIndex != null ? _checkAnswer : null,
                  ),
                ),
              SizedBox(
                width: isLastQuestion ? 180 : 140,
                child: _CustomButton(
                  text: isLastQuestion ? 'Завершить тест' : 'Дальше',
                  color: isLastQuestion ? _purple : _green,
                  textColor: isLastQuestion ? Colors.white : Colors.black,
                  // Кнопка активна, если выбран ответ или если мы уже находимся в режиме проверки
                  onPressed: (_selectedOptionIndex != null || isChecking) ? _nextQuestion : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ==========================================
  // 2. ЭКРАН РЕЗУЛЬТАТОВ
  // ==========================================
  Widget _buildResultContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ты молодец!', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: _darkText)),
          Container(height: 4, width: double.infinity, color: _purple, margin: const EdgeInsets.only(top: 8, bottom: 40)),

          Center(
            child: Column(
              children: [
                // Имитация картинки из макета
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                  child: const Text('А ты крут ;)', style: TextStyle(fontSize: 14)),
                ),
                const SizedBox(height: 16),
                const Icon(Icons.emoji_events_outlined, size: 120, color: Colors.amber), // Заглушка вместо иллюстрации
                const SizedBox(height: 32),

                Text(
                  '$_correctAnswersCount из ${_questions.length} правильных ответов',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: _darkText),
                ),
              ],
            ),
          ),

          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 140,
              child: _CustomButton(
                text: 'Далее',
                color: _orange,
                textColor: Colors.black,
                onPressed: () => context.pop(),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _CustomButton(
                  text: 'Вернуться к правилу',
                  color: _pink,
                  textColor: Colors.black,
                  onPressed: () => context.pop(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _CustomButton(
                  text: 'Разбор ошибок',
                  color: _green,
                  textColor: Colors.black,
                  onPressed: () {
                    if (_wrongAnswers.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('У тебя нет ошибок!')));
                    } else {
                      setState(() => _currentState = TestState.review);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ==========================================
  // 3. ЭКРАН РАЗБОРА ОШИБОК
  // ==========================================
  Widget _buildReviewContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Давай разберем ошибки!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _darkText)),
              Container(height: 4, width: double.infinity, color: _purple, margin: const EdgeInsets.only(top: 8, bottom: 24)),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            itemCount: _wrongAnswers.length,
            separatorBuilder: (_, __) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Divider(color: Color(0xFFEEEEEE), thickness: 1),
            ),
            itemBuilder: (context, index) {
              final item = _wrongAnswers[index];
              final q = item['question'];
              final options = List<String>.from(q['options']);
              final correctIndex = q['correct_index'] as int;

              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${index + 1}. Выбери правильный вариант',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _darkText),
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: _red, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(q['question'], style: TextStyle(fontSize: 16, color: _darkText)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: options.map((opt) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _purple,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(opt, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      )).toList(),
                    ),
                    const SizedBox(height: 24),
                    Text.rich(
                      TextSpan(
                        text: 'Правильный ответ: ',
                        style: const TextStyle(fontSize: 15, color: Color(0xFF555555)),
                        children: [
                          TextSpan(text: options[correctIndex], style: TextStyle(color: _purple, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Объяснение', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _darkText)),
                    const SizedBox(height: 8),
                    Text(
                      q['explanation'] ?? '',
                      style: const TextStyle(fontSize: 14, color: Color(0xFF555555), height: 1.5),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 240,
              child: _CustomButton(
                text: 'Продолжить обучение',
                color: _orange,
                textColor: Colors.black,
                onPressed: () => context.pop(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Вспомогательный виджет кнопок
class _CustomButton extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;
  final VoidCallback? onPressed;

  const _CustomButton({
    required this.text,
    required this.color,
    required this.textColor,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        disabledBackgroundColor: color.withOpacity(0.5),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
      ),
      child: Text(
        text,
        style: TextStyle(
            color: onPressed == null ? textColor.withOpacity(0.5) : textColor,
            fontSize: 15,
            fontWeight: FontWeight.w700
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}