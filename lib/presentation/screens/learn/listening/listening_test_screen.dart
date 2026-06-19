import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/theme/app_colors.dart';

enum TestState { playing, result, review }

class ListeningTestScreen extends StatefulWidget {
  final Map<String, dynamic> testData;

  const ListeningTestScreen({super.key, required this.testData});

  @override
  State<ListeningTestScreen> createState() => _ListeningTestScreenState();
}

class _ListeningTestScreenState extends State<ListeningTestScreen> {
  final _supabase = Supabase.instance.client;

  TestState _currentState = TestState.playing;
  bool _isLoading = true;
  List<Map<String, dynamic>> _parts = [];
  int _currentPartIndex = 0;

  final Map<int, int> _selectedAnswers = {};
  bool _showTranslation = false;
  bool _isCurrentPartChecked = false; // Флаг: проверена ли текущая часть

  // Статистика
  int _correctCount = 0;
  int _totalCount = 0;
  final List<Map<String, dynamic>> _wrongAnswers = [];

  // Аудио
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _fetchTestParts();
    _setupAudioListeners();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // --- ЛОГИКА АУДИО ---

  void _setupAudioListeners() {
    _audioPlayer.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _audioPlayer.durationStream.listen((dur) {
      if (mounted) setState(() => _duration = dur ?? Duration.zero);
    });
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _isPlaying = false;
            _audioPlayer.pause();
            _audioPlayer.seek(Duration.zero);
          }
        });
      }
    });
  }

  Future<void> _loadAudioForCurrentPart() async {
    if (_parts.isEmpty) return;
    final currentPart = _parts[_currentPartIndex];
    final audioUrl = currentPart['audio_url'];

    if (audioUrl != null && audioUrl.toString().isNotEmpty) {
      try {
        await _audioPlayer.setUrl(audioUrl);
      } catch (e) {
        debugPrint('Ошибка загрузки аудио URL: $e');
      }
    } else {
      await _audioPlayer.stop();
      setState(() {
        _duration = Duration.zero;
        _position = Duration.zero;
      });
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
  }

  void _seekBackward() {
    final newPosition = _position - const Duration(seconds: 10);
    _audioPlayer.seek(newPosition.isNegative ? Duration.zero : newPosition);
  }

  void _seekForward() {
    final newPosition = _position + const Duration(seconds: 10);
    _audioPlayer.seek(newPosition > _duration ? _duration : newPosition);
  }

  String _formatDuration(Duration d) {
    String mins = (d.inMinutes % 60).toString();
    String secs = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$mins:$secs";
  }

  // --- ЛОГИКА ТЕСТА И ПРОВЕРКИ ---

  Future<void> _fetchTestParts() async {
    try {
      final data = await _supabase
          .from('listening_parts')
          .select('*, listening_questions(*)')
          .eq('test_id', widget.testData['id'])
          .order('part_number', ascending: true);

      setState(() {
        _parts = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });

      if (_parts.isNotEmpty) {
        _loadAudioForCurrentPart();
      }
    } catch (e) {
      debugPrint('Ошибка загрузки частей теста: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _checkCurrentPart() {
    final currentPart = _parts[_currentPartIndex];
    final questions = currentPart['listening_questions'] as List<dynamic>? ?? [];

    for (var q in questions) {
      final String text = q['question_text'] ?? '';
      if (text.startsWith('Beispiel:')) continue; // Пропускаем примеры

      _totalCount++;
      final qId = q['id'];
      final correctIdx = q['correct_index'] ?? 0;
      final selectedIdx = _selectedAnswers[qId];

      if (selectedIdx == correctIdx) {
        _correctCount++;
      } else {
        _wrongAnswers.add({
          'part_title': currentPart['title'],
          'question': q,
          'selected_index': selectedIdx,
          'correct_index': correctIdx,
        });
      }
    }

    setState(() {
      _isCurrentPartChecked = true;
    });
  }

  void _nextPart() {
    if (!_isCurrentPartChecked) _checkCurrentPart(); // Авто-проверка, если забыли нажать

    if (_currentPartIndex < _parts.length - 1) {
      _audioPlayer.pause();
      setState(() {
        _currentPartIndex++;
        _showTranslation = false;
        _isCurrentPartChecked = false;
      });
      _loadAudioForCurrentPart();
    } else {
      _finishTest();
    }
  }

  Future<void> _finishTest() async {
    if (!_isCurrentPartChecked) _checkCurrentPart();
    _audioPlayer.pause();

    // Сохранение прогресса
    final user = _supabase.auth.currentUser;
    if (user != null && _totalCount > 0) {
      try {
        final percent = ((_correctCount / _totalCount) * 100).round();

        final existing = await _supabase.from('user_progress')
            .select('id, score_percentage')
            .eq('user_id', user.id)
            .eq('item_type', 'listening_test')
            .eq('item_id', widget.testData['id'])
            .maybeSingle();

        if (existing != null) {
          final oldScore = (existing['score_percentage'] ?? 0) as int;
          if (percent > oldScore) {
            await _supabase.from('user_progress').update({'score_percentage': percent}).eq('id', existing['id']);
          }
        } else {
          await _supabase.from('user_progress').insert({
            'user_id': user.id,
            'item_type': 'listening_test',
            'item_id': widget.testData['id'],
            'score_percentage': percent,
          });
        }
      } catch (e) {
        debugPrint('Ошибка сохранения: $e');
      }
    }

    setState(() {
      _currentState = TestState.result;
    });
  }

  // --- ИНТЕРФЕЙС ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator()));
    }
    if (_parts.isEmpty) {
      return Scaffold(backgroundColor: Colors.white, appBar: AppBar(elevation: 0, backgroundColor: Colors.white, iconTheme: const IconThemeData(color: Colors.black)), body: const Center(child: Text('В этом тесте пока нет вопросов.', style: TextStyle(fontFamily: 'Poppins'))));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentState) {
      case TestState.playing:
        return _buildPlayingContent();
      case TestState.result:
        return _buildResultContent();
      case TestState.review:
        return _buildReviewContent();
    }
  }

  // === 1. ЭКРАН ПРОХОЖДЕНИЯ ===

  Widget _buildPlayingContent() {
    final currentPart = _parts[_currentPartIndex];
    final questions = currentPart['listening_questions'] as List<dynamic>? ?? [];
    questions.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));

    return Column(
      children: [
        _buildHeader(currentPart['title'] ?? '', currentPart['type_badge'] ?? ''),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(currentPart['instruction'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black, fontFamily: 'Poppins')),
                const SizedBox(height: 24),
                _buildAudioPlayer(),
                const SizedBox(height: 32),
                ...questions.map((q) => _buildQuestionBlock(q, _isCurrentPartChecked)),

                // Текст аудио после проверки
                if (_isCurrentPartChecked) ...[
                  const Divider(color: Color(0xFFEEEEEE)),
                  const SizedBox(height: 16),
                  const Text('Текст аудио:', style: TextStyle(fontSize: 14, decoration: TextDecoration.underline, fontFamily: 'Poppins', color: Colors.black54)),
                  const SizedBox(height: 8),
                  Text(currentPart['transcript'] ?? 'Аудиоскрипт скоро появится в базе данных.', style: const TextStyle(fontSize: 13, fontFamily: 'Poppins', color: Colors.black87, height: 1.5)),
                  const SizedBox(height: 32),
                ]
              ],
            ),
          ),
        ),
        _buildFooter(),
      ],
    );
  }

  Widget _buildHeader(String title, String badge) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black, fontFamily: 'Poppins'),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFC3F336), borderRadius: BorderRadius.circular(8)),
                child: Text(widget.testData['level'], style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFFF9DE6), borderRadius: BorderRadius.circular(8)),
                child: Text(badge, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPlayer() {
    double progressPercent = 0.0;
    if (_duration.inMilliseconds > 0) {
      progressPercent = _position.inMilliseconds / _duration.inMilliseconds;
      if (progressPercent > 1.0) progressPercent = 1.0;
    }

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: const Color(0xFFF2F2F2), borderRadius: BorderRadius.circular(30)),
      child: Row(
        children: [
          GestureDetector(onTap: _seekBackward, child: const Icon(Icons.replay_10_rounded, color: Color(0xFF7B4DFE), size: 26)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _togglePlayPause,
            child: Icon(_isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_arrow_rounded, color: const Color(0xFF7B4DFE), size: 38),
          ),
          const SizedBox(width: 8),
          GestureDetector(onTap: _seekForward, child: const Icon(Icons.forward_10_rounded, color: Color(0xFF7B4DFE), size: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    onTapDown: (details) {
                      final seekPercent = details.localPosition.dx / constraints.maxWidth;
                      _audioPlayer.seek(Duration(milliseconds: (_duration.inMilliseconds * seekPercent).toInt()));
                    },
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(height: 4, width: constraints.maxWidth, decoration: BoxDecoration(color: const Color(0xFFD9D9D9), borderRadius: BorderRadius.circular(2))),
                        Container(width: constraints.maxWidth * progressPercent, height: 4, decoration: BoxDecoration(color: const Color(0xFF7B4DFE), borderRadius: BorderRadius.circular(2))),
                      ],
                    ),
                  );
                }
            ),
          ),
          const SizedBox(width: 12),
          Text(_formatDuration(_position), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54, fontFamily: 'Poppins')),
        ],
      ),
    );
  }

  // --- БЛОК ВОПРОСА ---
  Widget _buildQuestionBlock(Map<String, dynamic> question, bool isChecking) {
    final qId = question['id'];
    final String originalText = question['question_text'] ?? '';
    final String qType = question['question_type'];
    final int correctIndex = question['correct_index'] ?? 0;

    final bool isExample = originalText.startsWith('Beispiel:');
    final String displayText = isExample ? originalText.replaceFirst('Beispiel: ', '').trim() : originalText;
    final options = List<Map<String, dynamic>>.from(question['options']);

    final selectedIdx = isExample ? correctIndex : _selectedAnswers[qId];

    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      padding: isExample ? const EdgeInsets.all(16) : EdgeInsets.zero,
      decoration: isExample ? BoxDecoration(
        color: const Color(0xFFC3F336).withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC3F336), width: 1.5),
      ) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isExample)
            const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('Beispiel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF8DB600), fontFamily: 'Poppins'))),

          Text(displayText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black, fontFamily: 'Poppins')),
          const SizedBox(height: 16),

          if (qType == 'abc')
            _buildAbcOptions(qId, options, selectedIdx, correctIndex, isExample, isChecking)
          else if (qType == 'richtig_falsch')
            _buildRichtigFalschOptions(qId, options, selectedIdx, correctIndex, isExample, isChecking)
          else if (qType == 'match')
              _buildMatchOptions(qId, options, selectedIdx, correctIndex, isExample, isChecking),
        ],
      ),
    );
  }

  Widget _buildAbcOptions(int qId, List<Map<String, dynamic>> options, int? selectedIdx, int correctIdx, bool isExample, bool isChecking) {
    return Column(
      children: List.generate(options.length, (index) {
        final isSelected = selectedIdx == index;
        final isCorrect = correctIdx == index;

        Color borderColor = const Color(0xFFAAAAAA);
        Color textColor = const Color(0xFFAAAAAA);
        String trailingText = '';

        if (!isChecking && !isExample) {
          if (isSelected) { borderColor = const Color(0xFF7B4DFE); textColor = const Color(0xFF7B4DFE); }
        } else {
          // Режим проверки или пример
          if (isCorrect) {
            borderColor = const Color(0xFF8DB600); textColor = const Color(0xFF8DB600);
            if (!isExample) trailingText = 'правильный ответ';
          } else if (isSelected) {
            borderColor = const Color(0xFFE5805E); textColor = const Color(0xFFE5805E);
            if (!isExample) trailingText = 'твой ответ';
          }
        }

        return GestureDetector(
          onTap: (isExample || isChecking) ? null : () => setState(() => _selectedAnswers[qId] = index),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor, width: 1.5),
                    color: (isSelected && isExample) ? const Color(0xFF7B4DFE).withOpacity(0.1) : Colors.transparent,
                  ),
                  child: Center(child: Text(options[index]['label'] ?? '', style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontFamily: 'Poppins'))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(options[index]['text'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87, fontFamily: 'Poppins'))),
                if (trailingText.isNotEmpty)
                  Text(trailingText, style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Poppins')),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildRichtigFalschOptions(int qId, List<Map<String, dynamic>> options, int? selectedIdx, int correctIdx, bool isExample, bool isChecking) {
    bool showCheck = (isChecking || isExample) && selectedIdx == correctIdx && selectedIdx != null;
    bool showCross = (isChecking || isExample) && selectedIdx != correctIdx && selectedIdx != null;

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildRFButton(qId, 0, 'Richtig', selectedIdx, correctIdx, isExample, isChecking)),
              const SizedBox(width: 16),
              Expanded(child: _buildRFButton(qId, 1, 'Falsch', selectedIdx, correctIdx, isExample, isChecking)),
            ],
          ),
        ),
        if (showCheck || showCross) ...[
          const SizedBox(width: 16),
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: showCheck ? const Color(0xFF8DB600) : const Color(0xFFE5805E),
              shape: BoxShape.circle,
            ),
            child: Icon(showCheck ? Icons.check : Icons.close, color: Colors.white, size: 18),
          ),
        ]
      ],
    );
  }

  Widget _buildRFButton(int qId, int index, String text, int? selectedIdx, int correctIdx, bool isExample, bool isChecking) {
    bool isSelected = selectedIdx == index;
    bool isCorrect = correctIdx == index;

    Color color = const Color(0xFFAAAAAA);
    if (!isChecking && !isExample) {
      if (isSelected) color = index == 0 ? const Color(0xFF8DB600) : const Color(0xFFE5805E);
    } else {
      if (isCorrect) {
        color = const Color(0xFF8DB600);
      } else if (isSelected) {
        color = const Color(0xFFE5805E);
      }
    }

    return GestureDetector(
      onTap: (isExample || isChecking) ? null : () => setState(() => _selectedAnswers[qId] = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15, fontFamily: 'Poppins')),
      ),
    );
  }

  Widget _buildMatchOptions(int qId, List<Map<String, dynamic>> options, int? selectedIdx, int correctIdx, bool isExample, bool isChecking) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(options.length, (index) {
        final isSelected = selectedIdx == index;
        final isCorrect = correctIdx == index;

        Color borderColor = const Color(0xFF7B4DFE);
        Color bgColor = Colors.transparent;

        if (isChecking || isExample) {
          if (isCorrect) { borderColor = const Color(0xFF8DB600); bgColor = const Color(0xFF8DB600).withOpacity(0.2); }
          else if (isSelected) { borderColor = const Color(0xFFE5805E); bgColor = const Color(0xFFE5805E).withOpacity(0.2); }
        } else if (isSelected) {
          bgColor = const Color(0xFFBCA6F6).withOpacity(0.3);
        }

        return GestureDetector(
          onTap: (isExample || isChecking) ? null : () => setState(() => _selectedAnswers[qId] = index),
          child: Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor, width: 1.5),
                ),
                child: Center(child: Text(options[index]['label'] ?? '', style: TextStyle(color: borderColor, fontWeight: FontWeight.w700, fontFamily: 'Poppins'))),
              ),
              const SizedBox(width: 8),
              Text(options[index]['text'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87, fontFamily: 'Poppins')),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildFooter() {
    final isLastScreen = _currentPartIndex == _parts.length - 1;
    final currentQuestions = _parts[_currentPartIndex]['listening_questions'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isCurrentPartChecked)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _checkCurrentPart,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9D66), elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                    child: const Text('Проверить', style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isLastScreen ? _finishTest : _nextPart,
                    style: ElevatedButton.styleFrom(backgroundColor: isLastScreen ? const Color(0xFF7B4DFE) : const Color(0xFFC3F336), elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                    child: Text(isLastScreen ? 'Завершить тест' : 'Дальше', style: TextStyle(color: isLastScreen ? Colors.white : Colors.black87, fontSize: 16, fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
                  ),
                ),
              ],
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: isLastScreen ? _finishTest : _nextPart,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC3F336), elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                child: Text(isLastScreen ? 'Завершить тест' : 'Дальше', style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
              ),
            ),

          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => setState(() => _showTranslation = !_showTranslation),
            child: const Text('Увидеть перевод вопроса', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87, decoration: TextDecoration.underline, fontFamily: 'Poppins')),
          ),
          if (_showTranslation) ...[
            const SizedBox(height: 12),
            ...currentQuestions.map((q) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(q['translation'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.black54, fontFamily: 'Poppins')),
            )),
          ]
        ],
      ),
    );
  }

  // === 2. ЭКРАН РЕЗУЛЬТАТОВ ===

  Widget _buildResultContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text('Ты молодец!', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.black87, fontFamily: 'Poppins')),
          Container(height: 4, width: double.infinity, color: const Color(0xFF7B4DFE), margin: const EdgeInsets.only(top: 8, bottom: 32)),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: Image.asset('assets/images/reading/result_character_1.png', height: 220, errorBuilder: (_, __, ___) => const Icon(Icons.star_rounded, size: 100, color: Colors.orange)),
                    ),
                    Positioned(
                      top: 10, left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10)]),
                        child: const Text('А ты крут ;)', style: TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Poppins', fontSize: 13)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text('$_correctCount из $_totalCount правильных ответов', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, fontFamily: 'Poppins'), textAlign: TextAlign.center),
              ],
            ),
          ),

          Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9D66), padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), elevation: 0),
                  child: const Text('Далее', style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9DE6), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), elevation: 0),
                      child: const Text('Завершить', style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _wrongAnswers.isEmpty ? null : () => setState(() => _currentState = TestState.review),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC3F336), disabledBackgroundColor: const Color(0xFFC3F336).withOpacity(0.4), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), elevation: 0),
                      child: const Text('Разбор ошибок', style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
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

  // === 3. ЭКРАН РАЗБОРА ОШИБОК ===

  Widget _buildReviewContent() {
    // Группируем ошибки по частям теста
    final Map<String, List<Map<String, dynamic>>> groupedErrors = {};
    for (var error in _wrongAnswers) {
      final partTitle = error['part_title'] as String;
      if (!groupedErrors.containsKey(partTitle)) groupedErrors[partTitle] = [];
      groupedErrors[partTitle]!.add(error);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text('Давай разберем ошибки!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black87, fontFamily: 'Poppins')),
              Container(height: 4, width: double.infinity, color: const Color(0xFFFF9D66), margin: const EdgeInsets.only(top: 8, bottom: 16)),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            children: [
              ...groupedErrors.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.key, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
                    const SizedBox(height: 16),
                    ...entry.value.map((error) => _buildQuestionBlock(error['question'], true)),
                  ],
                );
              }),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC3F336), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), elevation: 0),
                child: const Text('Завершить', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }
}