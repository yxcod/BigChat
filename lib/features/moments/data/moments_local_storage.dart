import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/moment.dart';

abstract class MomentsLocalStorage {
  Future<List<Moment>> load();

  Future<void> save(List<Moment> moments);
}

class InMemoryMomentsStorage implements MomentsLocalStorage {
  List<Moment> _moments = const [];

  @override
  Future<List<Moment>> load() async => List<Moment>.of(_moments);

  @override
  Future<void> save(List<Moment> moments) async {
    _moments = List<Moment>.of(moments);
  }
}

class FileMomentsStorage implements MomentsLocalStorage {
  FileMomentsStorage({Future<Directory> Function()? directoryProvider})
    : _directoryProvider =
          directoryProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directoryProvider;

  Future<File> _file() async {
    final directory = await _directoryProvider();
    final storageDirectory = Directory('${directory.path}/moments');
    if (!await storageDirectory.exists()) {
      await storageDirectory.create(recursive: true);
    }
    return File('${storageDirectory.path}/own_moments.json');
  }

  @override
  Future<List<Moment>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const [];
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => Moment.fromJson(Map<String, dynamic>.from(item)))
          .where((moment) => moment.id.isNotEmpty && moment.authorId.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> save(List<Moment> moments) async {
    final file = await _file();
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode(moments.map((moment) => moment.toJson()).toList()),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }
}
