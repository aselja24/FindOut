// lib/presentation/screens/learn/reading/reading_test_screen.dart

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
    if (user != null) {
      try {
        await Supabase.instance.client.from('user_progress').upsert({
          'user_id': user.id,
          'item_type': 'reading_test',
          'item_id': widget.articleId,
          'completed_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Ошибка сохранения прогресса: $e');
      }
    }
  }

  // Проверяет ответ и помечает состояние как "checking"
  void _checkAnswer() {
    if (_selectedOptionIndex == null) return;

    final question = _questions[_currentIndex];
    final correctIndex = (question['correct_option'] as int?) ?? 0;

    if (_selectedOptionIndex == correctIndex) {
      _correctAnswersCount++;
    } else {
      _wrongAnswers.add({
        'question': question,
        'selected_index': _selectedOptionIndex,
      });
    }

    setState(() {
      _currentState = TestState.checking;
    });
  }

  // Переходит к следующему вопросу.
  // Если ответ ещё не проверен — засчитывает автоматически перед переходом.
  void _nextQuestion() async {
    // Если пользователь нажал "Дальше" без проверки — засчитываем ответ
    if (_currentState == TestState.playing && _selectedOptionIndex != null) {
      final question = _questions[_currentIndex];
      final correctIndex = (question['correct_option'] as int?) ?? 0;

      if (_selectedOptionIndex == correctIndex) {
        _correctAnswersCount++;
      } else {
        _wrongAnswers.add({
          'question': question,
          'selected_index': _selectedOptionIndex,
        });
      }
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

  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('0 ',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins')),
              const Icon(Icons.local_fire_department_outlined,
                  color: Colors.orange),
              const SizedBox(width: 16),
              Icon(Icons.notifications_none, color: _purple),
            ],
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(
                child: Text('Начинающий - А1',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins')),
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
                      borderRadius: BorderRadius.circular(3))),
              if (_questions.isNotEmpty)
                LayoutBuilder(
                  builder: (context, constraints) => Container(
                    width: constraints.maxWidth *
                        ((_currentIndex + 1) / _questions.length),
                    height: 6,
                    decoration: BoxDecoration(
                        color: _green,
                        borderRadius: BorderRadius.circular(3)),
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
                  color: _green, borderRadius: BorderRadius.circular(20)),
              child: const Text('А1-начинающий',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins')),
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildTestContent() {
    final question = _questions[_currentIndex];
    final options = List<String>.from(question['options']);
    final correctIndex = (question['correct_option'] as int?) ?? 0;
    final isChecking = _currentState == TestState.checking;
    final articleTitle = question['culture_articles']?['title'] ?? 'Чтение';
    final hasSelected = _selectedOptionIndex != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ТЕСТ',
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                  fontFamily: 'Poppins')),
          Container(
              height: 4,
              width: double.infinity,
              color: _purple,
              margin: const EdgeInsets.only(top: 8, bottom: 24)),

          Text(articleTitle,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins')),
          const SizedBox(height: 24),

          // Карточка с вопросом
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_currentIndex + 1}. ${question['question_de']}',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins'),
                    ),
                    const SizedBox(height: 24),
                    ...List.generate(options.length, (index) {
                      final isSelected = _selectedOptionIndex == index;
                      final isCorrect = correctIndex == index;

                      Color circleColor = Colors.grey;
                      if (isSelected) circleColor = _purple;
                      if (isChecking && isCorrect) circleColor = _green;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: isChecking
                              ? null
                              : () => setState(
                                  () => _selectedOptionIndex = index),
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: circleColor, width: 2),
                                ),
                                child: (isSelected ||
                                    (isChecking && isCorrect))
                                    ? Center(
                                    child: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                            color: circleColor,
                                            shape: BoxShape.circle)))
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(options[index],
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'Poppins')),
                                    ),
                                    if (isChecking &&
                                        isSelected &&
                                        !isCorrect) ...[
                                      const SizedBox(width: 8),
                                      const Text('твой ответ',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                              fontFamily: 'Poppins')),
                                    ],
                                    if (isChecking && isCorrect) ...[
                                      const SizedBox(width: 8),
                                      const Text('правильный ответ',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                              fontFamily: 'Poppins')),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                if (isChecking && _selectedOptionIndex != correctIndex)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: _orange, shape: BoxShape.circle),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 20),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // ✅ НОВАЯ ЛОГИКА КНОПОК:
          // - "Проверить": активна если выбран ответ И ещё не проверяли
          // - "Дальше": активна если выбран ответ (проверен или нет)
          Row(
            children: [
              Expanded(
                child: _CustomButton(
                  text: 'Проверить',
                  color: _orange,
                  textColor: Colors.black,
                  // Активна только если выбран ответ и ещё не нажата проверка
                  onPressed: hasSelected && !isChecking ? _checkAnswer : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _CustomButton(
                  text: _currentIndex < _questions.length - 1
                      ? 'Дальше'
                      : 'Завершить',
                  color: _green,
                  textColor: Colors.black,
                  // Активна если выбран ответ (независимо от проверки)
                  onPressed: hasSelected ? _nextQuestion : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildResultContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Text('Ты молодец!',
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                  fontFamily: 'Poppins')),
          Container(
              height: 4,
              width: double.infinity,
              color: _purple,
              margin: const EdgeInsets.only(top: 8, bottom: 40)),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset('assets/images/onboarding/onb3.png',
                          height: 260),
                      Positioned(
                        top: 20,
                        left: -10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10)
                            ],
                          ),
                          child: const Text('А ты крут ;)',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Text(
                    '$_correctAnswersCount из ${_questions.length} правильных ответов',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Poppins'),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: _CustomButton(
                    text: 'Далее',
                    color: _orange.withOpacity(0.8),
                    textColor: Colors.black,
                    onPressed: () => context.pop(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _CustomButton(
                        text: 'Вернуться к статье',
                        color: _pink,
                        textColor: Colors.black,
                        onPressed: () => context.pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CustomButton(
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
          ),
        ],
      ),
    );
  }

  Widget _buildReviewContent() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Разбор ошибок',
            style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins')),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () =>
                setState(() => _currentState = TestState.result)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _wrongAnswers.length,
        itemBuilder: (context, index) {
          final review = _wrongAnswers[index];
          final q = review['question'];
          final options = List<String>.from(q['options']);
          final userAnswer = review['selected_index'];
          final correctAns = (q['correct_option'] as int?) ?? 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05), blurRadius: 10)
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${index + 1}. ${q['question_de']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: 'Poppins')),
                const SizedBox(height: 20),
                ...List.generate(options.length, (optIdx) {
                  final isUser = optIdx == userAnswer;
                  final isCorrect = optIdx == correctAns;

                  Color textColor = Colors.black;
                  if (isUser) textColor = Colors.red;
                  if (isCorrect) textColor = Colors.green;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(
                          isCorrect
                              ? Icons.check_circle
                              : (isUser
                              ? Icons.cancel
                              : Icons.circle_outlined),
                          size: 20,
                          color: isCorrect
                              ? Colors.green
                              : (isUser ? Colors.red : Colors.grey),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(options[optIdx],
                              style: TextStyle(
                                  color: textColor,
                                  fontWeight: (isUser || isCorrect)
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 15,
                                  fontFamily: 'Poppins')),
                        ),
                      ],
                    ),
                  );
                }),
                if (q['explanation'] != null) ...[
                  const Divider(height: 32),
                  const Text('Объяснение:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'Poppins')),
                  const SizedBox(height: 8),
                  Text(q['explanation'],
                      style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          fontFamily: 'Poppins')),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

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
        disabledBackgroundColor: color.withOpacity(0.4),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
      ),
      child: Text(
        text,
        style: TextStyle(
            color:
            onPressed == null ? textColor.withOpacity(0.5) : textColor,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            fontFamily: 'Poppins'),
        textAlign: TextAlign.center,
      ),
    );
  }
}