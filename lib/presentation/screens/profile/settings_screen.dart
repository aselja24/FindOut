import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _nameController = TextEditingController();

  String _email = '';
  bool _isLoading = true;
  bool _isSaving = false;

  final Color _purple = const Color(0xFF7B4DFE);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _email = user.email ?? '';

    try {
      final data = await _supabase
          .from('profiles')
          .select('first_name')
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) {
        _nameController.text = data['first_name'] ?? '';
      }
    } catch (e) {
      debugPrint('Error loading profile for edit: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    final user = _supabase.auth.currentUser;

    if (user != null) {
      try {
        await _supabase
            .from('profiles')
            .update({'first_name': _nameController.text.trim()})
            .eq('id', user.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Профиль успешно обновлен!')));
          context.pop(); // Возвращаемся назад
        }
      } catch (e) {
        debugPrint('Error saving profile: $e');
      }
    }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Редактировать профиль', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: [
          if (_isSaving)
            const Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text('Готово', style: TextStyle(color: Color(0xFF7B4DFE), fontWeight: FontWeight.bold, fontSize: 16)),
            )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const Divider(color: Color(0xFFEEEEEE), thickness: 1),

            // Имя пользователя
            _buildEditRow(
                'Имя пользователя',
                TextField(
                  controller: _nameController,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                )
            ),
            const Divider(color: Color(0xFFEEEEEE), thickness: 1, height: 1),

            // Аватар
            _buildEditRow(
                'Аватар',
                CircleAvatar(radius: 20, backgroundColor: _purple, child: const Icon(Icons.person_outline, color: Colors.white))
            ),
            const Divider(color: Color(0xFFEEEEEE), thickness: 1, height: 1),

            // E-mail (только для чтения, согласно макету)
            _buildEditRow(
                'E-mail',
                Text(_email, style: const TextStyle(color: Colors.grey, fontSize: 16))
            ),
            const Divider(color: Color(0xFFEEEEEE), thickness: 1, height: 1),

            // Пароль
            _buildEditRow(
                'Пароль',
                const Text('********', style: TextStyle(color: Colors.grey, fontSize: 16))
            ),
            const Divider(color: Color(0xFFEEEEEE), thickness: 1, height: 1),

            // Сменить пароль
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: GestureDetector(
                  onTap: () {
                    // Логика смены пароля (отправка письма на сброс и т.д.)
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Функция в разработке')));
                  },
                  child: const Text('Сменить пароль', style: TextStyle(color: Color(0xFFE86B43), fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const Divider(color: Color(0xFFEEEEEE), thickness: 1, height: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildEditRow(String label, Widget trailing) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: trailing,
            ),
          ),
        ],
      ),
    );
  }
}