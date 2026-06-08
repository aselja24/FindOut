class PostEntity {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final String content;
  final String? imageUrl;
  final String languageTag;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final DateTime createdAt;

  const PostEntity({
    required this.id, required this.userId, required this.userName,
    this.userAvatarUrl, required this.content, this.imageUrl,
    required this.languageTag, this.likesCount = 0, this.commentsCount = 0,
    this.isLiked = false, required this.createdAt,
  });
}

class AchievementEntity {
  final String id;
  final String title;
  final String description;
  final String iconName;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final int xpReward;

  const AchievementEntity({
    required this.id, required this.title, required this.description,
    required this.iconName, this.isUnlocked = false,
    this.unlockedAt, this.xpReward = 50,
  });
}
