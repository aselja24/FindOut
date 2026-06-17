import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class ColoredModuleCard extends StatelessWidget {
  final String title;
  final int termsCount;
  final String authorName;
  final String? authorAvatarUrl;
  final Color backgroundColor;
  final VoidCallback onStudyPressed;
  final VoidCallback onMorePressed;

  const ColoredModuleCard({
    super.key,
    required this.title,
    required this.termsCount,
    required this.authorName,
    required this.backgroundColor,
    required this.onStudyPressed,
    required this.onMorePressed,
    this.authorAvatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Заголовок
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontFamily: 'Poppins',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // Количество терминов
                Text(
                  '$termsCount терминов',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 24),
                // Блок автора
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.white.withOpacity(0.5),
                      backgroundImage: authorAvatarUrl != null ? NetworkImage(authorAvatarUrl!) : null,
                      child: authorAvatarUrl == null ? const Icon(Icons.person, size: 16, color: Colors.black54) : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      authorName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Правая часть (Кнопки)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: onMorePressed,
                child: const Icon(Icons.more_vert_rounded, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: onStudyPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary, // Розовый цвет (0xFFFD65BD)
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: const Text(
                    'Изучить',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'Poppins'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}