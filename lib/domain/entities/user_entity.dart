class UserEntity {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final String targetLanguage;
  final String languageLevel;
  final int dailyGoal;
  final int streakDays;
  final int totalXp;
  final DateTime createdAt;
  final DateTime? lastActiveAt;

  const UserEntity({
    required this.id, required this.email, required this.name,
    this.avatarUrl, required this.targetLanguage, required this.languageLevel,
    this.dailyGoal = 5, this.streakDays = 0, this.totalXp = 0,
    required this.createdAt, this.lastActiveAt,
  });
}
