import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';

enum TestState { loading, playing, checking, result, review }

class ReadingTestScreen extends StatefulWidget {
  final int articleId;

  const ReadingTestScreen({super.key, required this.articleId});

  @override
  State<ReadingTestScreen> createState() => _ReadingTestScreenState();
}

class _ReadingTestScreenState extends State<ReadingTestScreen> {
  List<dynamic> _questions = [];
  List<Map<String, dynamic>> _wrongAnswers = [];

  TestState _currentState = TestState.loading;
  int _currentIndex = 0;
  int? _selectedOptionIndex;
  int _correctAnswersCount = 0;

  final Color _purple = AppColors.primary;
  final Color _orange = AppColors.orange;
  final Color _green = AppColors.accent;
  final Color _pink = AppColors.pinkLight;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    try {
      final response = await Supabase.instance.client
          .from('reading_questions')
          .select('*, culture_articles(title)')
          .eq('article_id', widget.articleId)
          .order('id', ascending: true);

      setState(() {
        _questions = response;
        _currentState =
        _questions.isEmpty ? TestState.result : TestState.playing;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
    }
  }

  Future<void> _saveProgressToDB() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _questions.isEmpty) return;

    try {
      // Высчитываем процент правильных ответов
      final int percent = ((_correctAnswersCount / _questions.length) * 100).round();

      // 1. Ищем, есть ли уже прогресс по этой статье
      final existing = await Supabase.instance.client
          .from('user_progress')
          .select('id, score_percentage')
          .eq('user_id', user.id)
          .eq('item_type', 'reading_test')
          .eq('item_id', widget.articleId)
          .maybeSingle();

      if (existing != null) {
        // 2. Если результат уже есть, обновляем его (только если новый процент выше)
        final int oldScore = (existing['score_percentage'] ?? 0) as int;
        if (percent > oldScore) {
          await Supabase.instance.client
              .from('user_progress')
              .update({
            'score_percentage': percent,
            'completed_at': DateTime.now().toIso8601String()
          })
              .eq('id', existing['id']);
        }
      } else {
        // 3. Если результата еще нет, создаем новую запись
        await Supabase.instance.client.from('user_progress').insert({
          'user_id': user.id,
          'item_type': 'reading_test',
          'item_id': widget.articleId,
          'score_percentage': percent,
          'completed_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Ошибка сохранения прогресса: $e');
    }
  }

  // Метод для записи ответа (правильный/неправильный)
  void _recordAnswer() {
    if (_selectedOptionIndex == null) return;

    final question = _questions[_currentIndex];
    final correctIndex = (question['correct_index'] as int?) ?? 0;

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
    // Если пользователь не нажал "Проверить", а сразу нажал "Дальше", записываем ответ
    if (_currentState == TestState.playing) {
      _recordAnswer();
    }

    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOptionIndex = null;
        _currentState = TestState.playing;
      });
    } else {
      await _saveProgressToDB();
      setState(() {
        _currentState = TestState.result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentState == TestState.loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // ─── TOP HEADER ───────────────────────────────────────────────────────────
  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                '0 ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                ),
              ),
              const Icon(Icons.local_fire_department_outlined,
                  color: Colors.orange),
              const SizedBox(width: 16),
              Icon(Icons.notifications_none, color: _purple),
            ],
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Text(
                'Начинающий - А1',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                ),
              ),
              Icon(Icons.keyboard_arrow_down, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEEEE),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              if (_questions.isNotEmpty)
                LayoutBuilder(
                  builder: (context, constraints) => Container(
                    width: constraints.maxWidth *
                        ((_currentIndex + 1) / _questions.length),
                    height: 6,
                    decoration: BoxDecoration(
                      color: _green,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'А1-начинающий',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── BODY ROUTER ─────────────────────────────────────────────────────────
  Widget _buildBody() {
    switch (_currentState) {
      case TestState.playing:
      case TestState.checking:
        return _buildTestContent();
      case TestState.result:
        return _buildResultContent();
      case TestState.review:
        return _buildReviewContent();
      default:
        return const SizedBox();
    }
  }

  // ─── TEST CONTENT (playing + checking) ───────────────────────────────────
  Widget _buildTestContent() {
    final question = _questions[_currentIndex];
    final options = List<String>.from(question['options']);
    final correctIndex = (question['correct_index'] as int?) ?? 0;
    final isChecking = _currentState == TestState.checking;
    final hasSelected = _selectedOptionIndex != null;
    final isLastQuestion = _currentIndex == _questions.length - 1;
    final articleTitle = question['culture_articles']?['title'] ?? 'Чтение';
    final isWrong = isChecking &&
        _selectedOptionIndex != null &&
        _selectedOptionIndex != correctIndex;

    final questionText = question['question_de'] ?? question['question_ru'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ТЕСТ',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
              fontFamily: 'Poppins',
            ),
          ),
          Container(
            height: 4,
            width: double.infinity,
            color: _purple,
            margin: const EdgeInsets.only(top: 8, bottom: 16),
          ),

          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              articleTitle,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                fontFamily: 'Poppins',
              ),
            ),
          ),

          const SizedBox(height: 8),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_currentIndex + 1}. Выбери правильный вариант',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      questionText,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'Poppins',
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),

                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: List.generate(options.length, (index) {
                        final isSelected = _selectedOptionIndex == index;
                        final isCorrect = correctIndex == index;

                        Color bgColor = _purple;
                        double opacity;

                        if (isChecking) {
                          opacity = isCorrect ? 1.0 : 0.4;
                        } else {
                          opacity = isSelected ? 1.0 : 0.4;
                        }

                        return GestureDetector(
                          onTap: isChecking
                              ? null
                              : () => setState(
                                  () => _selectedOptionIndex = index),
                          child: Opacity(
                            opacity: opacity,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 10),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Text(
                                options[index],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),

                if (isWrong)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _orange,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 18),
                    ),
                  ),
              ],
            ),
          ),

          if (isChecking) ...[
            const SizedBox(height: 16),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'Poppins',
                  color: Colors.black87,
                ),
                children: [
                  const TextSpan(text: 'Правильный ответ: '),
                  TextSpan(
                    text: options[correctIndex],
                    style: TextStyle(
                      color: _purple,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (question['explanation'] != null) ...[
              const SizedBox(height: 12),
              const Text(
                'Объяснение',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                question['explanation'],
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: _PillButton(
                text: isLastQuestion ? 'Завершить' : 'Дальше',
                color: _green,
                textColor: Colors.black,
                onPressed: _nextQuestion,
              ),
            ),
          ],

          if (!isChecking) ...[
            const SizedBox(height: 32),
            Row(
              children: [
                _PillButton(
                  text: 'Проверить',
                  color: _orange,
                  textColor: Colors.black,
                  onPressed: hasSelected ? _checkAnswer : null,
                ),
                const Spacer(),
                _PillButton(
                  text: isLastQuestion ? 'Завершить тест' : 'Дальше',
                  color: _green,
                  textColor: Colors.black,
                  onPressed: hasSelected ? _nextQuestion : null,
                ),
              ],
            ),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildResultContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ты молодец!',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
              fontFamily: 'Poppins',
            ),
          ),
          Container(
            height: 4,
            width: double.infinity,
            color: _purple,
            margin: const EdgeInsets.only(top: 8, bottom: 32),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/images/reading/result_character_1.png',
                        height: 220,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/images/reading/result_character_1.png',
                          height: 220,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08), // Замени на .withValues(alpha: 0.08) если Flutter ругается
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Text(
                          'А ты крут ;)',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Poppins',
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  '$_correctAnswersCount из ${_questions.length} правильных ответов',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Poppins',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: _PillButton(
                  text: 'Далее',
                  color: _orange,
                  textColor: Colors.black,
                  // ИСПРАВЛЕНО: Передаем true (тест успешно завершен)
                  onPressed: () => Navigator.pop(context, true),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _PillButton(
                      text: 'Вернуться к статье',
                      color: _pink,
                      textColor: Colors.black,
                      // ИСПРАВЛЕНО: Передаем false (просто закрыть тест, остаться на статье)
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PillButton(
                      text: 'Разбор ошибок',
                      color: _green,
                      textColor: Colors.black,
                      onPressed: _wrongAnswers.isEmpty
                          ? null
                          : () => setState(
                              () => _currentState = TestState.review),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

// ─── REVIEW ──────────────────────────────────────────────────────────────
  Widget _buildReviewContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Давай разберем ошибки!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                  fontFamily: 'Poppins',
                ),
              ),
              Container(
                height: 4,
                width: double.infinity,
                color: _purple,
                margin: const EdgeInsets.only(top: 8, bottom: 8),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            itemCount: _wrongAnswers.length + 1,
            itemBuilder: (context, index) {
              if (index == _wrongAnswers.length) {
                return Column(
                  children: [
                    const SizedBox(height: 24),
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          Image.asset(
                            'assets/images/grammer/review_character.png',
                            height: 160,
                            errorBuilder: (_, __, ___) => Image.asset(
                              'assets/images/grammer/review_character.png',
                              height: 160,
                            ),
                          ),
                          Positioned(
                            right: -40,
                            top: 10,
                            child: Container(
                              width: 160,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: const Text(
                                'Ты молодец! Ошибки это часть обучения )',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: _PillButton(
                        text: 'Продолжить обучение',
                        color: _orange,
                        textColor: Colors.black,
                        // ИСПРАВЛЕНО: Передаем true (тест успешно завершен)
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              }

              final review = _wrongAnswers[index];
              final q = review['question'];
              final options = List<String>.from(q['options']);
              final userAnswer = review['selected_index'] as int?;
              final correctAns = (q['correct_index'] as int?) ?? 0;
              final questionText = q['question_de'] ?? q['question_ru'] ?? '';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.07),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${index + 1}. Выбери правильный вариант',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              questionText,
                              style: const TextStyle(
                                fontSize: 14,
                                fontFamily: 'Poppins',
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children:
                              List.generate(options.length, (optIdx) {
                                final isCorrect = optIdx == correctAns;
                                final opacity = isCorrect ? 1.0 : 0.4;

                                return Opacity(
                                  opacity: opacity,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _purple,
                                      borderRadius:
                                      BorderRadius.circular(24),
                                    ),
                                    child: Text(
                                      options[optIdx],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: _orange,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'Poppins',
                        color: Colors.black87,
                      ),
                      children: [
                        const TextSpan(text: 'Правильный ответ: '),
                        TextSpan(
                          text: options[correctAns],
                          style: TextStyle(
                            color: _purple,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (q['explanation'] != null) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Объяснение',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      q['explanation'],
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;
  final VoidCallback? onPressed;

  const _PillButton({
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
        disabledBackgroundColor: color.withOpacity(0.35),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        elevation: 0,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: onPressed == null ? textColor.withOpacity(0.45) : textColor,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          fontFamily: 'Poppins',
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}