import '../domain/moment.dart';

abstract class MomentsRepository {
  Future<List<Moment>> fetchOwnMoments(String userId);

  Future<Moment> publish(MomentDraft draft);

  Future<Moment> toggleLike({required String momentId, required String userId});

  Future<Moment> addComment({
    required String momentId,
    required String userId,
    required String displayName,
    required String content,
  });
}

/// Frontend-only implementation. Replace this registration with an API-backed
/// repository later; pages only depend on [MomentsRepository].
class LocalMomentsRepository implements MomentsRepository {
  LocalMomentsRepository();

  static final LocalMomentsRepository instance = LocalMomentsRepository();

  final List<Moment> _moments = [];
  int _sequence = 0;

  @override
  Future<List<Moment>> fetchOwnMoments(String userId) async {
    final result =
        _moments.where((moment) => moment.authorId == userId).toList()
          ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return List<Moment>.unmodifiable(result);
  }

  @override
  Future<Moment> publish(MomentDraft draft) async {
    final moment = Moment(
      id: _nextId('moment'),
      authorId: draft.authorId,
      authorName: draft.authorName,
      authorAvatarUrl: draft.authorAvatarUrl,
      content: draft.content.trim(),
      mediaPaths: List<String>.unmodifiable(draft.mediaPaths),
      createdAt: DateTime.now(),
      visibility: draft.visibility,
      location: draft.location,
      likeCount: 0,
      isLiked: false,
      comments: const [],
    );
    _moments.add(moment);
    return moment;
  }

  @override
  Future<Moment> toggleLike({
    required String momentId,
    required String userId,
  }) async {
    return _update(momentId, (moment) {
      final nextLiked = !moment.isLiked;
      return moment.copyWith(
        isLiked: nextLiked,
        likeCount: (moment.likeCount + (nextLiked ? 1 : -1))
            .clamp(0, 1 << 31)
            .toInt(),
      );
    });
  }

  @override
  Future<Moment> addComment({
    required String momentId,
    required String userId,
    required String displayName,
    required String content,
  }) async {
    final normalizedContent = content.trim();
    if (normalizedContent.isEmpty) {
      throw ArgumentError.value(content, 'content', '评论不能为空');
    }
    return _update(
      momentId,
      (moment) => moment.copyWith(
        comments: List<MomentComment>.unmodifiable([
          ...moment.comments,
          MomentComment(
            id: _nextId('comment'),
            userId: userId,
            displayName: displayName,
            content: normalizedContent,
            createdAt: DateTime.now(),
          ),
        ]),
      ),
    );
  }

  Moment _update(String momentId, Moment Function(Moment) transform) {
    final index = _moments.indexWhere((moment) => moment.id == momentId);
    if (index == -1) throw StateError('动态不存在: $momentId');
    final updated = transform(_moments[index]);
    _moments[index] = updated;
    return updated;
  }

  String _nextId(String prefix) {
    _sequence += 1;
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_sequence';
  }
}
