import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';

class GrammarDetailScreen extends StatelessWidget {
  final Map<String, dynamic> lesson;

  const GrammarDetailScreen({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    final title = lesson['title'] ?? 'Урок грамматики';
    final ruleText = lesson['rule_text'] ?? '';
    final level = lesson['level'] ?? 'A1';
    final tablesData = lesson['tables_data'] as List<dynamic>?;

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
                '$level-начинающий',
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
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2D2D2D),
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: AppColors.primary, thickness: 2, endIndent: 250),
                  const SizedBox(height: 24),
                  Text(
                    ruleText,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: Color(0xFF555555),
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (tablesData != null && tablesData.isNotEmpty)
                    ...tablesData.map((table) => _buildGrammarTable(table)).toList(),
                  const SizedBox(height: 32),
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
                  // Достаем id урока (убедись, что ключ совпадает с тем, как он приходит из БД)
                  final int lessonId = lesson['id'] as int;
                  context.push('/grammar/test', extra: lessonId);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  elevation: 0,
                ),
                child: const Text(
                  'Пройти тест!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Poppins'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrammarTable(dynamic tableData) {
    final String? tableTitle = tableData['title'];
    final List<dynamic>? headers = tableData['headers'];
    final List<dynamic>? rows = tableData['rows'];

    if (rows == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tableTitle != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 16),
            child: Text(
              tableTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFEEEEEE)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Table(
              border: TableBorder.all(color: const Color(0xFFEEEEEE), width: 1),
              children: [
                if (headers != null)
                  TableRow(
                    decoration: const BoxDecoration(color: Color(0xFFF9F9F9)),
                    children: headers.map((h) => Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(h.toString(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    )).toList(),
                  ),
                ...rows.map((row) => TableRow(
                  children: (row as List<dynamic>).map((cell) => Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(cell.toString(), style: const TextStyle(fontSize: 13)),
                  )).toList(),
                )).toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
