import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import 'reading_test_screen.dart';

class ReadingDetailScreen extends StatelessWidget {
  final Map<String, dynamic> article;
  final bool isFromLessonFlow;

  const ReadingDetailScreen({
    super.key,
    required this.article,
    this.isFromLessonFlow = false,
  });

  @override
  Widget build(BuildContext context) {
    final title = article['title'] ?? 'Статья';
    final contentRu = article['content_ru'] ?? '';
    final contentDe = article['content_de'] ?? ''; // Возвращаем немецкий текст
    final level = article['level_restriction'] ?? 'A1';
    final category = article['category'] ?? 'Культура';
    final vocabList = article['vocabulary'] as List<dynamic>? ?? []; // Возвращаем словарь

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                level,
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF2D2D2D), fontFamily: 'Poppins', height: 1.2),
                  ),
                  const SizedBox(height: 24),

                  // Вывод русского текста
                  if (contentRu.isNotEmpty) ...[
                    Text(
                      contentRu,
                      style: const TextStyle(fontSize: 15, height: 1.7, color: Color(0xFF444444), fontFamily: 'Poppins'),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Divider(color: Color(0xFFEEEEEE), thickness: 1),
                    ),
                  ],

                  // Вывод немецкого текста
                  if (contentDe.isNotEmpty) ...[
                    Text(
                      contentDe,
                      style: const TextStyle(fontSize: 15, height: 1.7, color: Color(0xFF444444), fontFamily: 'Poppins'),
                    ),
                    const SizedBox(height: 40),
                  ],

                  // Вывод словаря
                  if (vocabList.isNotEmpty) ...[
                    const Text('Слова и выражения', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, fontFamily: 'Poppins', color: Colors.black87)),
                    Container(height: 4, width: 80, color: const Color(0xFFFF9D66), margin: const EdgeInsets.only(top: 8, bottom: 20)),

                    ...vocabList.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text.rich(
                          TextSpan(
                              text: '${item['word']} - ',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, fontFamily: 'Poppins', color: Colors.black87),
                              children: [
                                TextSpan(text: item['translation'], style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black54)),
                              ]
                          )
                      ),
                    )),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  final int articleId = (article['id'] as num).toInt();

                  if (isFromLessonFlow) {
                    Navigator.pop(context, true);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ReadingTestScreen(articleId: articleId)),
                    ).then((result) {
                      if (context.mounted && result == true) {
                        Navigator.pop(context, true);
                      }
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  elevation: 0,
                ),
                child: const Text(
                  'Перейти к тесту',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Poppins'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}