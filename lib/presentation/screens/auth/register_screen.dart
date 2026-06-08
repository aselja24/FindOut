import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/theme/app_colors.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _surnameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  bool _loading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;
  String? _error;
  XFile? _avatarFile;

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _avatarFile = picked);
  }

  String _formatError(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('rate limit')) return 'Слишком много попыток. Подождите немного.';
    if (m.contains('already')) return 'Этот E-mail адрес уже зарегистрирован.';
    return msg;
  }

  Future<void> _register() async {
    final name = _nameCtrl.text.trim();
    final surname = _surnameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final pass2 = _pass2Ctrl.text;

    if (name.isEmpty || surname.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Пожалуйста, заполните все обязательные поля');
      return;
    }

    if (pass != pass2) {
      setState(() => _error = 'Пароли не совпадают');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. Создаем пользователя в Auth. Данные уходят в метадату, откуда их автоматически заберет твой SQL-триггер для создания профиля
      final authResponse = await Supabase.instance.client.auth.signUp(
        email: email,
        password: pass,
        data: {
          'first_name': name,
          'last_name': surname,
        },
      );

      final user = authResponse.user;
      if (user == null) throw const AuthException('Не удалось создать аккаунт.');

      // 2. Синхронизируем базовые текстовые данные профиля.
      // Названия полей изменены под твою схему таблицы: 'first_name' и 'last_name'. Поле 'email' убрано.
      await Supabase.instance.client.from('profiles').update({
        'first_name': name,
        'last_name': surname,
      }).eq('id', user.id);

      // 3. Если добавлена аватарка — загружаем её в бакет 'avatars'
      if (_avatarFile != null) {
        final file = File(_avatarFile!.path);
        final fileExt = _avatarFile!.name.split('.').last;
        final fileName = '${user.id}/avatar.$fileExt';

        await Supabase.instance.client.storage
            .from('avatars')
            .upload(fileName, file, fileOptions: const FileOptions(upsert: true));

        final String avatarUrl = Supabase.instance.client.storage
            .from('avatars')
            .getPublicUrl(fileName);

        // Обновляем ссылку на аватар в профиле
        await Supabase.instance.client
            .from('profiles')
            .update({'avatar_url': avatarUrl})
            .eq('id', user.id);
      }

      if (mounted) {
        context.push(Routes.setupLanguage);
      }
    } on AuthException catch (e) {
      debugPrint('AUTH ERROR: ${e.message}');
      setState(() => _error = _formatError(e.message));
    } catch (e, stackTrace) {
      debugPrint('ERROR: $e');
      debugPrint('$stackTrace');
      setState(() => _error = 'Ошибка при сохранении данных: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _surnameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Регистрация',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 32, fontWeight: FontWeight.w800, color: Colors.black)),
              const SizedBox(height: 8),
              const Text('Создай аккаунт для начала обучения',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 16, color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onTap: _loading ? null : _pickAvatar,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xFFF2F2F2),
                        backgroundImage: _avatarFile != null ? FileImage(File(_avatarFile!.path)) : null,
                        child: _avatarFile == null
                            ? const Icon(Icons.person_outline, size: 40, color: Color(0xFFAAAAAA))
                            : null,
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
              ],
              _buildField('Имя', _nameCtrl, 'Иван', false, null, TextInputType.name),
              const SizedBox(height: 16),
              _buildField('Фамилия', _surnameCtrl, 'Иванов', false, null, TextInputType.name),
              const SizedBox(height: 16),
              _buildField('E-mail', _emailCtrl, 'example@mail.com', false, null, TextInputType.emailAddress),
              const SizedBox(height: 16),
              _buildField('Пароль', _passCtrl, '••••••••', _obscure1, () => setState(() => _obscure1 = !_obscure1), TextInputType.visiblePassword),
              const SizedBox(height: 16),
              _buildField('Повторите пароль', _pass2Ctrl, '••••••••', _obscure2, () => setState(() => _obscure2 = !_obscure2), TextInputType.visiblePassword),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity, height: 58,
                child: ElevatedButton(
                  onPressed: _loading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _loading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Зарегистрироваться', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Уже есть аккаунт? ',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 15, color: AppColors.textSecondary),
                  ),
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Text(
                      'Войти',
                      style: TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, String hint, bool obscure, VoidCallback? toggle, TextInputType type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black)),
        ),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType: type,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontWeight: FontWeight.w400),
            filled: true,
            fillColor: const Color(0xFFF2F2F2),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            suffixIcon: toggle != null
                ? IconButton(
                icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFFAAAAAA)),
                onPressed: toggle)
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
      ],
    );
  }
}