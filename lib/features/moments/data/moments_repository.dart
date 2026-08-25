import '../domain/moment.dart';
import 'moments_local_storage.dart';

abstract class MomentsRepository {
  Future<List<Moment>> fetchOwnMoments(String userId);

  Future<List<Moment>> fetchUserMoments(String userId, {int? maxItems});

  Future<Moment> publish(MomentDraft draft);

  Future<Moment> toggleLike({required String momentId, required String userId});

  Future<Moment> addComment({
    required String momentId,
    required String userId,
    required String displayName,
    required String content,
  });

  Future<void> deleteMoment({required String momentId, required String userId});
}

/// Frontend-only implementation. Replace this registration with an API-backed
/// repository later; pages only depend on [MomentsRepository].
class LocalMomentsRepository implements MomentsRepository {
  LocalMomentsRepository({MomentsLocalStorage? storage})
    : _storage = storage ?? InMemoryMomentsStorage();

  static final LocalMomentsRepository instance = LocalMomentsRepository(
    storage: FileMomentsStorage(),
  );

  final MomentsLocalStorage _storage;
  final List<Moment> _moments = [];
  int _sequence = 0;
  Future<void>? _loadFuture;

  Future<void> _ensureLoaded() {
    return _loadFuture ??= () async {
      final storedMoments = await _storage.load();
      _moments
        ..clear()
        ..addAll(storedMoments);
    }();
  }

  @override
  Future<List<Moment>> fetchOwnMoments(String userId) async {
    await _ensureLoaded();
    final result =
        _moments.where((moment) => moment.authorId == userId).toList()
          ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return List<Moment>.unmodifiable(result);
  }

  @override
  Future<List<Moment>> fetchUserMoments(String userId, {int? maxItems}) async {
    final moments = await fetchOwnMoments(userId);
    if (maxItems == null || moments.length <= maxItems) return moments;
    return List<Moment>.unmodifiable(moments.take(maxItems));
  }

  @override
  Future<Moment> publish(MomentDraft draft) async {
    await _ensureLoaded();
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
    await _storage.save(_moments);
    return moment;
  }

  @override
  Future<Moment> toggleLike({
    required String momentId,
    required String userId,
  }) async {
    await _ensureLoaded();
    final updated = _update(momentId, (moment) {
      final nextLiked = !moment.isLiked;
      return moment.copyWith(
        isLiked: nextLiked,
        likeCount: (moment.likeCount + (nextLiked ? 1 : -1))
            .clamp(0, 1 << 31)
            .toInt(),
      );
    });
    await _storage.save(_moments);
    return updated;
  }

  @override
  Future<Moment> addComment({
    required String momentId,
    required String userId,
    required String displayName,
    required String content,
  }) async {
    await _ensureLoaded();
    final normalizedContent = content.trim();
    if (normalizedContent.isEmpty) {
      throw ArgumentError.value(content, 'content', '评论不能为空');
    }
    final updated = _update(
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
    await _storage.save(_moments);
    return updated;
  }

  @override
  Future<void> deleteMoment({
    required String momentId,
    required String userId,
  }) async {
    await _ensureLoaded();
    final index = _moments.indexWhere((moment) => moment.id == momentId);
    if (index == -1) throw StateError('动态不存在: $momentId');
    if (_moments[index].authorId != userId) {
      throw StateError('只能删除自己发布的动态');
    }
    _moments.removeAt(index);
    await _storage.save(_moments);
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
