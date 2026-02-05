// SPDX-FileCopyrightText: 2025 Kwame, III <webarcherydev@gmail.com>
// SPDX-License-Identifier: BSD-3-Clause
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its contributors
//    may be used to endorse or promote products derived from this software
//    without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

// https://webarchery.dev

import 'package:archery/archery/archery.dart';

/// A thread-safe, in-memory configuration store with dot-notation key access.
///
/// Supports nested configuration via `key.nested.value`, deep copying, and
/// safe key validation to prevent path traversal attacks.
///
/// Example:
/// ```dart
/// config.set('database.host', 'localhost');
/// config.get('database.host'); // -> 'localhost'
/// ```
class ConfigRepository {
  /// Internal storage for configuration values.
  final Map<String, dynamic> _items;

  /// Creates a new repository with optional initial [items].
  ///
  /// All input data is deeply copied to prevent external mutation.
  ConfigRepository([Map<String, dynamic> items = const {}]) : _items = _deepCopy(items);

  /// Validates that a dot-notation [key] is safe and well-formed.
  ///
  /// Rejects:
  /// - Empty keys
  /// - Keys containing `..`
  /// - Keys starting or ending with `.`
  ///
  /// Prevents path traversal and ambiguous lookups.
  bool _isValidKey(String key) {
    return key.isNotEmpty && !key.contains('..') && !key.startsWith('.') && !key.endsWith('.');
  }

  /// Retrieves a value at [key] using dot-notation.
  ///
  /// Returns [defaultValue] if the key is invalid or not found.
  ///
  /// Example:
  /// ```dart
  /// config.get('app.name', 'MyApp'); // returns 'MyApp' if not set
  /// ```
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

  /// Sets a [value] at the given dot-notation [key].
  ///
  /// Automatically creates intermediate nested maps as needed.
  ///
  /// Throws [ArgumentError] if [key] is invalid.
  ///
  /// Example:
  /// ```dart
  /// config.set('cache.enabled', true);
  /// config.set('features.login', false);
  /// ```
  void set(String key, dynamic value) {
    if (!_isValidKey(key)) {
      throw ArgumentError("Invalid key format: $key");
    }
    final segments = key.split('.');
    dynamic currentItems = _items;

    // Traverse and create nested maps up to the second-to-last segment
    for (int i = 0; i < segments.length - 1; i++) {
      final segment = segments[i];

      if (!currentItems.containsKey(segment) || currentItems[segment] is! Map) {
        currentItems[segment] = <String, dynamic>{};
      }
      currentItems = currentItems[segment];
    }

    // Set the final value
    currentItems[segments.last] = value;
  }

  /// Returns a **deep copy** of the entire configuration map.
  ///
  /// Safe to modify externally without affecting the internal state.
  Map<String, dynamic> all() => _deepCopy(_items);

  /// Recursively deep-copies a [Map] or [List], preserving structure.
  ///
  /// Handles nested maps and lists. Primitive values are copied by reference.
  static Map<String, dynamic> _deepCopy(Map<String, dynamic> source) {
    final result = <String, dynamic>{};
    for (final entry in source.entries) {
      if (entry.value is Map) {
        result[entry.key] = _deepCopy(entry.value as Map<String, dynamic>);
      } else if (entry.value is List) {
        result[entry.key] = (entry.value as List).map((e) => e is Map ? _deepCopy(e as Map<String, dynamic>) : e).toList();
      } else {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  /// Replaces all current config with a deep copy of [items].
  ///
  /// Clears existing data first.
  void reset(Map<String, dynamic> items) {
    _items
      ..clear()
      ..addAll(_deepCopy(items));
  }
}

/// Internal utility class for loading `.json` config files from a directory.
///
/// Recursively scans the given [path], converts file paths to dot-notation keys,
/// and merges all JSON content into a single nested map.
///
/// File: `lib/src/config/database/connection.json` → Key: `database.connection`
class _ConfigFilesLoader {
  /// Root directory path to scan for `.json` config files.
  final String path;

  _ConfigFilesLoader(this.path);

  /// Loads and merges all `.json` files in [path] recursively.
  ///
  /// - Skips non-JSON files
  /// - Ignores parse errors (with optional logging)
  /// - Sanitizes filenames to avoid dot-notation conflicts
  ///
  /// Returns a nested map representing the full configuration.
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
        final value = content.isEmpty ? <String, dynamic>{} : jsonDecode(content);

        if (content.isEmpty) {
          // Consider logging: empty file
        }

        _setNested(config, dottedKey, value);
      } catch (e) {
        // Consider logging: JSON parse error
        continue;
      }
    }

    return config;
  }

  /// Converts a file path into a safe dot-notation key.
  ///
  /// - Strips root path
  /// - Removes `.json` extension
  /// - Replaces `.` in filenames with `_` to avoid key ambiguity
  /// - Joins directory segments with `.`
  ///
  /// Example:
  /// `lib/src/config/app.settings.json` → `app.settings`
  String _dottedKeyFromFile(File file, String rootWithSep) {
    var abs = file.absolute.path.replaceAll('\\', '/');
    var rel = abs.startsWith(rootWithSep) ? abs.substring(rootWithSep.length) : abs;

    // Clean up path
    if (rel.startsWith('/')) rel = rel.substring(1);
    if (rel.toLowerCase().endsWith('.json')) {
      rel = rel.substring(0, rel.length - 5);
    }

    final parts = rel.split('/').where((s) => s.isNotEmpty).map(_sanitizeSegment).toList();

    return parts.join('.');
  }

  /// Sets a [value] at a nested [dottedKey] in [target] map.
  ///
  /// Creates intermediate maps if they don't exist.
  void _setNested(Map<String, dynamic> target, String dottedKey, dynamic value) {
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

  /// Sanitizes a path segment by replacing `.` with `_`.
  ///
  /// Prevents filename dots from being interpreted as nested keys.
  ///
  /// Example: `app.settings.json` → key `app_settings`
  String _sanitizeSegment(String s) => s.replaceAll('.', '_');
}

/// High-level facade for application configuration.
///
/// Loads `.json` files from disk on creation, provides dot-notation access,
/// in-memory overrides, and reload capability.
///
/// Usage:
/// ```dart
/// final config = await AppConfig.create();
/// print(config.get('app.name'));
/// ```
class AppConfig {
  /// Underlying in-memory configuration store.
  final ConfigRepository _repository;

  /// Directory path from which config files were loaded.
  final String _path;

  /// Private constructor. Use [create] to instantiate.
  AppConfig._(this._repository, this._path);

  /// Factory constructor that loads all `.json` files from [path].
  ///
  /// Defaults to `lib/src/config`.
  ///
  /// Returns a fully initialized [AppConfig] instance.
  static Future<AppConfig> create({String path = "lib/src/config"}) async {
    final loader = _ConfigFilesLoader(path);
    final items = await loader.load();
    return AppConfig._(ConfigRepository(items), path);
  }

  /// Retrieves a config value at [key].
  ///
  /// Returns [defaultValue] if not found or key is invalid.
  dynamic get(String key, [dynamic defaultValue]) => _repository.get(key, defaultValue);

  /// Sets a configuration [value] at [key] in memory.
  ///
  /// Does **not** persist to disk. Useful for runtime overrides.
  void set(String key, dynamic value) => _repository.set(key, value);

  /// Returns a deep copy of the entire current configuration.
  Map<String, dynamic> all() => _repository.all();

  /// Reloads configuration from disk.
  ///
  /// If [keepOverrides] is `true`, in-memory `set()` values are preserved.
  /// Otherwise, all runtime changes are discarded.
  ///
  /// **Note**: Currently discards overrides. Future versions may support merging.
  Future<void> reload({bool keepOverrides = false}) async {
    final loader = _ConfigFilesLoader(_path);
    final disk = await loader.load();

    if (keepOverrides) {
      // Future: merge strategy
      // For now, just reset
    }
    _repository.reset(disk);
  }
}
