class WordEntity {
  final String id;
  final String word;
  final String language;
  final String translation;
  final String partOfSpeech;
  final String? transcription;
  final String? romanization;
  final List<String> examples;
  final List<String> synonyms;
  final String? audioUrl;
  final String level;
  final bool isSaved;

  const WordEntity({
    required this.id, required this.word, required this.language,
    required this.translation, required this.partOfSpeech,
    this.transcription, this.romanization, this.examples = const [],
    this.synonyms = const [], this.audioUrl, required this.level,
    this.isSaved = false,
  });
}
