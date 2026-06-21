import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import 'reading_test_screen.dart';

class ReadingDetailScreen extends StatelessWidget {
  final Map<String, dynamic> article;
  final bool isFromLessonFlow; // <-- ДОБАВЛЕН ФЛАГ

  const ReadingDetailScreen({
    super.key,
    required this.article,
    this.isFromLessonFlow = false, // По умолчанию false
  });

  @override
  Widget build(BuildContext context) {
    final vocabList = article['vocabulary'] as List<dynamic>? ?? [];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          article['title'],
          style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8, top: 14, bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(color: const Color(0xFFDBF494), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(article['level_restriction'] ?? 'A1-A2', style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold))),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16, top: 14, bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(color: const Color(0xFFFF9DE6), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(article['category'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold))),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(height: 4, width: double.infinity, color: const Color(0xFFFF9D66)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(article['content_ru'] ?? '', style: const TextStyle(fontSize: 14, color: Color(0xFF333333), height: 1.5)),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Divider(color: Color(0xFFEEEEEE), thickness: 1),
                  ),
                  Text(article['content_de'] ?? '', style: const TextStyle(fontSize: 14, color: Color(0xFF333333), height: 1.5)),

                  const SizedBox(height: 40),
                  const Text('Слова и выражения', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Container(height: 4, width: 140, color: const Color(0xFFFF9D66), margin: const EdgeInsets.only(top: 4, bottom: 16)),

                  ...vocabList.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text.rich(
                        TextSpan(
                            text: '${item['word']} - ',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            children: [
                              TextSpan(text: item['translation'], style: const TextStyle(fontWeight: FontWeight.normal)),
                            ]
                        )
                    ),
                  )),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // ИСПРАВЛЕНО: Умная проверка пути
                      if (isFromLessonFlow) {
                        Navigator.pop(context, true);
                      } else {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => ReadingTestScreen(articleId: article['id'])),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7B4DFE),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      elevation: 0,
                    ),
                    child: const Text('Тест по статье', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC3F336),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      elevation: 0,
                    ),
                    child: const Text('Добавить всё в карточки', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}