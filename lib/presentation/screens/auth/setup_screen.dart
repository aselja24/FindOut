import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _step = 0;
  String? _goal, _time, _source;

  final _goals = [
    {'emoji': '✈️', 'label': 'Путешествия'},
    {'emoji': '🎓', 'label': 'Учёба'},
    {'emoji': '💼', 'label': 'Работа'},
    {'emoji': '👥', 'label': 'Общение'},
    {'emoji': '📈', 'label': 'Саморазвитие'},
    {'emoji': '🎭', 'label': 'Культура'},
  ];

  final _times = [
    {'emoji': '⚡', 'label': '5 мин/день'},
    {'emoji': '🕐', 'label': '15 мин/день'},
    {'emoji': '🕑', 'label': '30 мин/день'},
    {'emoji': '🔥', 'label': '60 мин/день'},
  ];

  final _sources = ['Друзья/семья', 'Google Play', 'YouTube', 'Instagram', 'Поиск Google', 'Подкаст'];

  void _next() {
    if (_step < 2) setState(() => _step++);
    else context.push(Routes.levelTest);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_step > 0) IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), onPressed: () => setState(() => _step--)),
                      Expanded(child: LinearProgressIndicator(
                        value: (_step + 1) / 3,
                        backgroundColor: AppColors.border,
                        valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                        borderRadius: BorderRadius.circular(4),
                      )),
                      const SizedBox(width: 12),
                      Text('${_step + 1}/3', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_stepTitle, style: AppTextStyles.h2),
                    const SizedBox(height: 24),
                    Expanded(child: _stepContent),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canProceed ? _next : null,
                  child: Text(_step == 2 ? 'Определить уровень ' : 'Далее'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _stepTitle => ['Зачем учишь язык?', 'Сколько времени в день?', 'Как узнал о RuselLang?'][_step];

  bool get _canProceed => [_goal != null, _time != null, _source != null][_step];

  Widget get _stepContent {
    if (_step == 0) return _buildChoiceList(_goals.map((g) => g['label']!).toList(), _goals.map((g) => g['emoji']!).toList(), _goal, (v) => setState(() => _goal = v));
    if (_step == 1) return _buildChoiceList(_times.map((t) => t['label']!).toList(), _times.map((t) => t['emoji']!).toList(), _time, (v) => setState(() => _time = v));
    return _buildChoiceList(_sources, List.filled(_sources.length, ''), _source, (v) => setState(() => _source = v));
  }

  Widget _buildChoiceList(List<String> labels, List<String> emojis, String? selected, Function(String) onSelect) {
    return ListView.separated(
      itemCount: labels.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final isSelected = selected == labels[i];
        return GestureDetector(
          onTap: () => onSelect(labels[i]),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.secondary.withValues(alpha: 0.1) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isSelected ? AppColors.secondary : AppColors.border, width: isSelected ? 2 : 1),
            ),
            child: Row(
              children: [
                if (emojis[i].isNotEmpty) ...[Text(emojis[i], style: const TextStyle(fontSize: 20)), const SizedBox(width: 12)],
                Expanded(child: Text(labels[i], style: AppTextStyles.bodyMedium.copyWith(color: isSelected ? AppColors.secondary : AppColors.textPrimary))),
                if (isSelected) const Icon(Icons.check_circle, color: AppColors.secondary, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
