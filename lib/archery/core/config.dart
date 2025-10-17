import 'package:archery/archery/archery.dart';


class ConfigRepository {

  final Map<String, dynamic> _items;

  ConfigRepository([Map<String, dynamic> items = const {}]) : _items = _deepCopy(items);

  bool _isValidKey(String key) {
    return key.isNotEmpty &&
        !key.contains('..') &&
        !key.startsWith('.') &&
        !key.endsWith('.');
  }

  dynamic get(String key, [dynamic defaultValue]) {
    if (!_isValidKey(key)) {
      return defaultValue;
    }

    final segments = key.split('.');
    dynamic currentItems = _items;

    for (final segment in segments) {
      if (!currentItems.containsKey(segment) || currentItems is! Map) {
        return defaultValue;
      }

      currentItems = currentItems[segment];
    }

    return currentItems;
  }
  void set(String key, dynamic value) {
    if (!_isValidKey(key)) {
      throw ArgumentError("Invalid key format: $key");
    }
    final segments = key.split('.');
    dynamic currentItems = _items;

    for (int i = 0; i < segments.length - 1; i++) {
      final segment = segments[i];

      if (!currentItems.containsKey(segment) || currentItems[segment] is! Map) {
        currentItems[segment] = <String, dynamic>{};
      }
      currentItems = currentItems[segment];
    }

    currentItems[segments.last] = value;
  }
  Map<String, dynamic> all() => _deepCopy(_items);

  static Map<String, dynamic> _deepCopy(Map<String, dynamic> source) {

    final result = <String, dynamic>{};
    for(final entry in source.entries) {

      if(entry.value is Map) {
        result[entry.key] = _deepCopy(entry.value as Map<String, dynamic>);
      }
      else if(entry.value is List) {
        result[entry.key] = (entry.value as List)
            .map((e) => e is Map ? _deepCopy(e as Map<String, dynamic>) : e)
            .toList();
      }
      else {
        result[entry.key] = entry.value;
      }
    }

    return result;
  }

  void reset(Map<String, dynamic> items) {
    _items..clear()..addAll(_deepCopy(items));
  }
}
class _ConfigFilesLoader {

  final String path;

  _ConfigFilesLoader(this.path);

  Future<Map<String, dynamic>> load() async {
    final config = <String, dynamic>{};
    final dir = Directory(path);

    if (!await dir.exists()) {
      return config;
    }

    final rootAbs = dir.absolute.path.replaceAll('\\', '/');
    final rootWithSep = rootAbs.endsWith('/') ? rootAbs : '$rootAbs/';

    await for (final entity in dir.list(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;

      final dottedKey = _dottedKeyFromFile(entity, rootWithSep);

      try {
        final content = await entity.readAsString();
        final value = (content.isEmpty)
            ? <String, dynamic>{}
            : jsonDecode(content);

        if (content.isEmpty) {
          // ignore: avoid_print
          //print('Warning: Empty JSON file at ${entity.path}');
        }

        _setNested(config, dottedKey, value);
      } catch (e) {
        // ignore: avoid_print
        //print('Error parsing JSON file at ${entity.path}: $e');
        continue;
      }
    }

    return config;
  }


  String _dottedKeyFromFile(File file, String rootWithSep) {
    var abs = file.absolute.path.replaceAll('\\', '/');
    var rel = abs.startsWith(rootWithSep)
        ? abs.substring(rootWithSep.length)
        : abs;

    // Trim extension and any leading slashes
    if (rel.startsWith('/')) rel = rel.substring(1);
    if (rel.toLowerCase().endsWith('.json')) {
      rel = rel.substring(0, rel.length - 5);
    }

    final parts = rel
        .split('/')
        .where((s) => s.isNotEmpty)
        .map(_sanitizeSegment)
        .toList();

    return parts.join('.');
  }


  void _setNested(
      Map<String, dynamic> target,
      String dottedKey,
      dynamic value,
      ) {
    final segments = dottedKey.split('.');
    var current = target;

    for (var i = 0; i < segments.length - 1; i++) {
      final seg = segments[i];
      final next = current[seg];
      if (next is Map<String, dynamic>) {
        current = next;
      } else {
        final created = <String, dynamic>{};
        current[seg] = created;
        current = created;
      }
    }

    current[segments.last] = value;
  }

  // Replace dots in segment names to avoid ambiguity with dot-path traversal.
  String _sanitizeSegment(String s) => s.replaceAll('.', '_');
}
class AppConfig {
  final ConfigRepository _repository;

  final String _path;

  AppConfig._(this._repository, this._path);

  static Future<AppConfig> create({String path = "lib/src/config"}) async {
    final loader = _ConfigFilesLoader(path);
    final items = await loader.load();

    return AppConfig._(ConfigRepository(items), path);
  }

  // Retrieves a value at [key] or returns [defaultValue] if not found.
  dynamic get(String key, [dynamic defaultValue]) =>
      _repository.get(key, defaultValue);

  // Sets a configuration [value] at [key] in the in-memory store.
  void set(String key, dynamic value) => _repository.set(key, value);

  // Returns a deep-copied snapshot of the full configuration map.
  Map<String, dynamic> all() => _repository.all();


  Future<void> reload({bool keepOverrides = false}) async {
    final loader = _ConfigFilesLoader(_path);
    Map<String, dynamic> disk = await loader.load();
    _repository.reset(disk);
  }
}
