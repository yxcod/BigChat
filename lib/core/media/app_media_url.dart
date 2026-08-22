class AppMediaUrl {
  const AppMediaUrl._();

  static String resolveMessageImage({
    required String content,
    required String? senderId,
    required String currentUserId,
    required bool isMine,
    required String Function(String ownerId, String imageName) buildServerUrl,
  }) {
    final uri = Uri.tryParse(content);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return content;
    }

    final normalizedSender = senderId?.trim() ?? '';
    final ownerId = normalizedSender.isNotEmpty
        ? normalizedSender
        : (isMine ? currentUserId : '');
    if (ownerId.isEmpty || content.trim().isEmpty) return content;
    return buildServerUrl(ownerId, content);
  }
}
