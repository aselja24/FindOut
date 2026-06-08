class FlashcardEntity {
  final String id;
  final String deckId;
  final String word;
  final String translation;
  final String? transcription;
  final String? example;
  final String? imageUrl;
  final String? audioUrl;
  final int reviewCount;
  final int correctCount;
  final DateTime? nextReviewAt;
  final bool isCustom;
  final String userId;

  const FlashcardEntity({
    required this.id, required this.deckId, required this.word,
    required this.translation, this.transcription, this.example,
    this.imageUrl, this.audioUrl, this.reviewCount = 0,
    this.correctCount = 0, this.nextReviewAt, this.isCustom = false,
    required this.userId,
  });

  double get accuracy => reviewCount == 0 ? 0 : correctCount / reviewCount;
}

class DeckEntity {
  final String id;
  final String name;
  final String language;
  final String? description;
  final String? coverImageUrl;
  final int cardCount;
  final int learnedCount;
  final bool isOfficial;
  final String? userId;
  final String category;

  const DeckEntity({
    required this.id, required this.name, required this.language,
    this.description, this.coverImageUrl, this.cardCount = 0,
    this.learnedCount = 0, this.isOfficial = true, this.userId,
    required this.category,
  });

  double get progress => cardCount == 0 ? 0 : learnedCount / cardCount;
}
