import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class SetupScaffold extends StatelessWidget {
  final int step;
  final int total;
  final String title;
  final Widget child;
  final Widget? bottomExtra;
  final Widget? illustration;
  final VoidCallback onBack;
  final String buttonLabel;
  final bool buttonEnabled;
  final VoidCallback onButton;
  final String? secondaryButtonLabel;
  final VoidCallback? onSecondaryButton;

  const SetupScaffold({
    super.key,
    required this.step,
    required this.total,
    required this.title,
    required this.child,
    required this.onBack,
    required this.buttonLabel,
    required this.buttonEnabled,
    required this.onButton,
    this.bottomExtra,
    this.illustration,
    this.secondaryButtonLabel,
    this.onSecondaryButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: onBack,
        ),
        title: Text(
          'Выполнено $step/$total',
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (illustration != null) ...[
                      const SizedBox(height: 24),
                      Center(child: illustration!),
                    ],
                    const SizedBox(height: 24),
                    child,
                    if (bottomExtra != null) ...[
                      const SizedBox(height: 16),
                      bottomExtra!,
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: buttonEnabled ? onButton : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonEnabled
                            ? AppColors.primary
                            : AppColors.surfaceVariant,
                        foregroundColor:
                            buttonEnabled ? Colors.white : AppColors.textMuted,
                      ),
                      child: Text(buttonLabel),
                    ),
                  ),
                  if (secondaryButtonLabel != null) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      const Expanded(child: Divider()),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('или',
                            style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                                color: AppColors.textMuted)),
                      ),
                      const Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onSecondaryButton,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide.none,
                          backgroundColor: AppColors.surfaceVariant,
                          foregroundColor: AppColors.textSecondary,
                        ),
                        child: Text(secondaryButtonLabel!),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
