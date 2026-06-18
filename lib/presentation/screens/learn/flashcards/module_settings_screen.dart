import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';


class ModuleSettingsScreen extends StatefulWidget {
  final bool isPublic;
  final bool isEditableByOthers;
  final Function(bool isPublic, bool isEditable) onSave;

  const ModuleSettingsScreen({
    super.key,
    required this.isPublic,
    required this.isEditableByOthers,
    required this.onSave,
  });

  @override
  State<ModuleSettingsScreen> createState() => _ModuleSettingsScreenState();
}

class _ModuleSettingsScreenState extends State<ModuleSettingsScreen> {
  late bool _isPublic;
  late bool _isEditable;

  @override
  void initState() {
    super.initState();
    _isPublic = widget.isPublic;
    _isEditable = widget.isEditableByOthers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () {
            widget.onSave(_isPublic, _isEditable);
            Navigator.pop(context);
          },
        ),
        title: const Text('Настройки', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Text('Конфиденциальность', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontFamily: 'Poppins')),
            const SizedBox(height: 16),

            _buildSettingRow('Видно', _isPublic ? 'Всем' : 'Только мне', () {
              setState(() => _isPublic = !_isPublic);
            }),
            _buildSettingRow('Редактируется', _isEditable ? 'Всем' : 'Только мной', () {
              setState(() => _isEditable = !_isEditable);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow(String title, String value, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, color: AppColors.textPrimary, fontFamily: 'Poppins')),
            Text(value, style: const TextStyle(fontSize: 16, color: AppColors.primary, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
          ],
        ),
      ),
    );
  }
}