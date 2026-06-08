class GrammarTopicEntity {
  final String id;
  final String title;
  final String language;
  final String level;
  final String description;
  final String content;
  final List<GrammarExampleEntity> examples;
  final bool isCompleted;
  final int xpReward;

  const GrammarTopicEntity({
    required this.id, required this.title, required this.language,
    required this.level, required this.description, required this.content,
    this.examples = const [], this.isCompleted = false, this.xpReward = 10,
  });
}

class GrammarExampleEntity {
  final String original;
  final String translation;
  final String? explanation;

  const GrammarExampleEntity({
    required this.original, required this.translation, this.explanation,
  });
}
