enum CultureCategory { history, landmarks, traditions, facts, phrasebook }

class CultureArticleEntity {
  final String id;
  final String title;
  final String language;
  final CultureCategory category;
  final String content;
  final String? imageUrl;
  final List<String> relatedWords;
  final bool isBookmarked;
  final DateTime publishedAt;

  const CultureArticleEntity({
    required this.id, required this.title, required this.language,
    required this.category, required this.content, this.imageUrl,
    this.relatedWords = const [], this.isBookmarked = false,
    required this.publishedAt,
  });
}

class PhraseEntity {
  final String id;
  final String phrase;
  final String translation;
  final String language;
  final String category;
  final String? audioUrl;
  final String? romanization;

  const PhraseEntity({
    required this.id, required this.phrase, required this.translation,
    required this.language, required this.category, this.audioUrl,
    this.romanization,
  });
}
