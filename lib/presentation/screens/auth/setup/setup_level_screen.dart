import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_colors.dart';

class SetupLevelScreen extends StatefulWidget {
  const SetupLevelScreen({super.key});
  @override
  State<SetupLevelScreen> createState() => _SetupLevelScreenState();
}

class _SetupLevelScreenState extends State<SetupLevelScreen> {
  String? _selectedLevel;
  bool _isUpdating = false;

  final List<Map<String, String>> _levels = [
    {'code': 'A1', 'label': 'Начинающий'},
    {'code': 'A2', 'label': 'Базовый'},
    {'code': 'B1', 'label': 'Средний'},
    {'code': 'C1', 'label': 'Продвинутый'},
  ];

  Future<void> _saveLevel(String levelCode, BuildContext modalContext) async {
    setState(() => _isUpdating = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({'language_level': levelCode})
            .eq('id', userId);
      }
      if (Navigator.canPop(modalContext)) Navigator.pop(modalContext);
      if (mounted) context.push(Routes.setupTime);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showLevelPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              ..._levels.map((level) {
                final isSelected = _selectedLevel == level['code'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: _isUpdating ? null : () {
                      setModal(() {});
                      setState(() => _selectedLevel = level['code']);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withOpacity(0.08) : const Color(0xFFF2F2F2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent, width: 2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(color: isSelected ? AppColors.primary : const Color(0xFFD9D9D9), shape: BoxShape.circle),
                            child: Center(child: Text(level['code']!, style: TextStyle(fontWeight: FontWeight.w800, color: isSelected ? Colors.white : Colors.black))),
                          ),
                          const SizedBox(width: 16),
                          Text(level['label']!, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: isSelected ? AppColors.primary : Colors.black)),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 58,
                child: ElevatedButton(
                  onPressed: _selectedLevel == null || _isUpdating ? null : () => _saveLevel(_selectedLevel!, ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _isUpdating ? const CircularProgressIndicator(color: Colors.white) : const Text('Далее'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, centerTitle: true, title: const Text('Выполнено 3/4', style: TextStyle(color: Colors.black, fontSize: 14))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text('Каков твой уровень?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const Spacer(),
              ElevatedButton(onPressed: _showLevelPicker, child: const Text('Выбрать уровень')),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
