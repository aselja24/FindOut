import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_colors.dart';

class SetupTimeScreen extends StatefulWidget {
  const SetupTimeScreen({super.key});
  @override
  State<SetupTimeScreen> createState() => _SetupTimeScreenState();
}

class _SetupTimeScreenState extends State<SetupTimeScreen> {
  String? _selectedTime;
  bool _isUpdating = false;

  final List<Map<String, String>> _times = [
    {'label': '5 минут', 'value': '5'},
    {'label': '10 минут', 'value': '10'},
    {'label': '15 минут', 'value': '15'},
    {'label': '20 минут', 'value': '20'},
  ];

  Future<void> _saveTime() async {
    setState(() => _isUpdating = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({'daily_time_target': _selectedTime})
            .eq('id', userId);
      }
      if (mounted) context.go(Routes.home);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, centerTitle: true, title: const Text('Выполнено 4/4', style: TextStyle(color: Colors.black))),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('Сколько времени в день ты готов уделять?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 32),
            ..._times.map((t) {
              final isSelected = _selectedTime == t['value'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTime = t['value']),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withOpacity(0.1) : const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent, width: 2),
                    ),
                    child: Center(child: Text(t['label']!, style: TextStyle(fontWeight: FontWeight.w700, color: isSelected ? AppColors.primary : Colors.black))),
                  ),
                ),
              );
            }),
            const Spacer(),
            SizedBox(
              width: double.infinity, height: 58,
              child: ElevatedButton(
                onPressed: _selectedTime == null || _isUpdating ? null : _saveTime,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: _isUpdating ? const CircularProgressIndicator(color: Colors.white) : const Text('Начать обучение'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
