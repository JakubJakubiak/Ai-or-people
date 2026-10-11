enum MediaType { image, video, music }

/// One round of the game: a piece of media plus the truth about who made it.
class GameItem {
  const GameItem({
    required this.url,
    required this.isAi,
    required this.type,
    this.title,
    this.artist,
    this.cover,
    this.credit,
  });

  final String url;
  final bool isAi;
  final MediaType type;
  final String? title;
  final String? artist;
  final String? cover;

  /// Attribution shown after the answer (required by CC licences).
  final String? credit;
}
