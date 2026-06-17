import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_colors.dart';

class GoalSelectScreen extends StatefulWidget {
  const GoalSelectScreen({super.key});
  @override
  State<GoalSelectScreen> createState() => _GoalSelectScreenState();
}

class _GoalSelectScreenState extends State<GoalSelectScreen> {
  String? _selected;

  final List<Map<String, String>> _goals = [
    {'label': 'Путешествия', 'icon': '✈️'},
    {'label': 'Учёба', 'icon': '🎓'},
    {'label': 'Работа', 'icon': '💼'},
    {'label': 'Общение', 'icon': '💬'},
    {'label': 'Саморазвитие', 'icon': '📈'},
    {'label': 'Культура', 'icon': '🎭'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const Text('Выполнено 2/4',
            style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),
            const Text('Зачем ты учишь язык?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black)),
            const SizedBox(height: 32),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _goals.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final goal = _goals[i];
                  final isSelected = _selected == goal['label'];
                  return GestureDetector(
                    onTap: () => setState(() => _selected = goal['label']),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withOpacity(0.08) : const Color(0xFFF2F2F2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : const Color(0xFFD9D9D9),
                              shape: BoxShape.circle,
                            ),
                            child: Center(child: Text(goal['icon']!, style: const TextStyle(fontSize: 20))),
                          ),
                          const SizedBox(width: 16),
                          Text(goal['label']!,
                              style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700,
                                color: isSelected ? AppColors.primary : Colors.black,
                              )),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity, height: 58,
                child: ElevatedButton(
                  onPressed: _selected == null ? null : () => context.push(Routes.setupLevel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('Далее', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
