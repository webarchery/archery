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

/// Log severity levels with associated numeric codes.
///
/// Levels are ordered from most severe to least:
/// ```
/// error (0) < success (1) < warn (2) < info (3) < debug (4) < trace (5)
/// ```
enum LogLevel {
  /// Critical error — application may not continue.
  error(0),

  /// Successful operation (e.g., request completed, job finished).
  success(1),

  /// Warning — non-fatal issue that requires attention.
  warn(2),

  /// General informational message.
  info(3),

  /// Debug-level diagnostic information.
  debug(4),

  /// Fine-grained tracing for development.
  trace(5);

  /// Numeric code for filtering or transport-level decisions.
  final int code;

  const LogLevel(this.code);

  /// Uppercase name of the level (e.g., `ERROR`, `INFO`).
  String get name => toString().split('.').last.toUpperCase();

  /// Converts a numeric [code] back to a [LogLevel].
  ///
  /// Defaults to [LogLevel.info] if not found.
  static LogLevel fromCode(int code) {
    return values.firstWhere((level) => level.code == code, orElse: () => LogLevel.info);
  }
}

/// Immutable log entry containing structured data.
///
/// Includes:
/// - Timestamp (UTC)
/// - Log level
/// - Message
/// - Context (inherited from logger)
/// - Optional metadata (per-log)
final class LogEntry {
  /// UTC timestamp when the log was created.
  final DateTime timestamp;

  /// Severity level.
  final LogLevel level;

  /// Primary log message.
  final String message;

  /// Contextual data inherited from the logger (e.g., request ID, user).
  final Map<String, dynamic> context;

  /// Optional one-off metadata for this log entry.
  final Map<String, dynamic>? metadata;

  /// Creates a new log entry.
  ///
  /// [context] defaults to empty map if `null`.
  LogEntry({required this.level, required this.message, this.metadata, Map<String, dynamic>? context}) : timestamp = DateTime.now().toUtc(), context = context ?? {};

  /// Serializes the entry to JSON-compatible map.
  ///
  /// Includes all fields. Context is shallow-copied.
  Map<String, dynamic> toJson() {
    return {
      "level": level.name,
      "code": level.code,
      "timestamp": timestamp.toIso8601String(),
      "message": message,
      "context": {...context},
      if (metadata != null) "metadata": metadata,
    };
  }

  /// Human-readable string representation.
  ///
  /// Format: `[LEVEL] message`
  @override
  String toString() {
    return "[${level.name}] $message";
  }
}

/// Abstract interface for log transports.
///
/// Transports receive [LogEntry] instances and handle persistence,
/// formatting, or transmission (e.g., console, file, network).
abstract class LogTransport {
  /// Logs a single [entry].
  Future<void> log(LogEntry entry);

  /// Cleans up resources (close files, flush buffers, etc.).
  Future<void> dispose();
}

/// Central logging facility with support for:
/// - Multiple transports
/// - Hierarchical context via `child()`
/// - Structured logging
/// - Async, fault-tolerant delivery
///
/// Example:
/// ```dart
/// final logger = Logger(transports: [ConsoleTransport()]);
/// await logger.info('Server started', {'port': 8080});
/// ```
final class Logger {
  /// Registered transports that receive every log entry.
  final List<LogTransport> _transports;

  /// Base context inherited by all child loggers and entries.
  final Map<String, dynamic> _context;

  /// Creates a logger with optional [transports] and [context].
  Logger({List<LogTransport>? transports, Map<String, dynamic>? context}) : _transports = transports ?? [], _context = context ?? {};

  /// Internal: creates and dispatches a [LogEntry] to all transports.
  ///
  /// Catches and reports transport errors to `stderr`.
  Future<void> _log(LogLevel level, String message, [Map<String, dynamic>? metadata]) async {
    final entry = LogEntry(level: level, message: message, metadata: metadata, context: _context);

    for (final transport in _transports) {
      try {
        await transport.log(entry);
      } catch (e) {
        stderr.writeln('Log transport error: $e');
      }
    }
  }

  /// Logs an **error** message.
  Future<void> error(String message, [Map<String, dynamic>? metadata]) => _log(LogLevel.error, message, metadata);

  /// Logs a **success** message.
  Future<void> success(String message, [Map<String, dynamic>? metadata]) => _log(LogLevel.success, message, metadata);

  /// Logs a **warning** message.
  Future<void> warn(String message, [Map<String, dynamic>? metadata]) => _log(LogLevel.warn, message, metadata);

  /// Logs an **info** message.
  Future<void> info(String message, [Map<String, dynamic>? metadata]) => _log(LogLevel.info, message, metadata);

  /// Logs a **debug** message.
  Future<void> debug(String message, [Map<String, dynamic>? metadata]) => _log(LogLevel.debug, message, metadata);

  /// Logs a **trace** message.
  Future<void> trace(String message, [Map<String, dynamic>? metadata]) => _log(LogLevel.trace, message, metadata);

  /// Creates a child logger with additional [context].
  ///
  /// Useful for request-scoped logging:
  /// ```dart
  /// final requestLogger = logger.child({'requestId': 'abc123'});
  /// ```
  Logger child([Map<String, dynamic>? additionalContext]) {
    return Logger(transports: _transports, context: {..._context, ...?additionalContext});
  }

  /// Disposes all transports.
  ///
  /// Should be called on application shutdown.
  Future<void> dispose() async {
    for (final transport in _transports) {
      await transport.dispose();
    }
  }
}

/// Console-based log transport with colorized, human-readable output.
///
/// Respects `app.debug` config — **silently drops logs in production**.
///
/// Supports:
/// - ANSI colors
/// - Pretty or JSON formatting
/// - Timestamp + level + message + context + metadata
final class ConsoleTransport implements LogTransport {
  /// Enables ANSI color codes in output.
  final bool useColors;

  /// Outputs logs as indented JSON instead of formatted string.
  final bool formatJson;

  // ANSI color codes
  static const _ansiReset = '\x1B[0m';
  static const _ansiRed = '\x1B[31m';
  static const _ansiYellow = '\x1B[33m';
  static const _ansiGreen = '\x1B[32m';
  static const _ansiBlue = '\x1B[34m';
  static const _ansiCyan = '\x1B[36m';
  static const _ansiMagenta = '\x1B[35m';

  /// Creates a console transport.
  ///
  /// - [useColors]: `true` by default
  /// - [formatJson]: `false` by default (pretty format)
  ConsoleTransport({this.useColors = true, this.formatJson = false});

  @override
  Future<void> log(LogEntry entry) async {
    final config = App().container.make<AppConfig>();
    final debugMode = config.get('app.debug', false);

    // Suppress all logs unless debug mode is enabled
    if (!debugMode) return;

    if (formatJson) {
      _logJson(entry);
    } else {
      _logFormatted(entry);
    }
  }

  /// Logs entry as pretty-printed JSON.
  void _logJson(LogEntry entry) {
    final encoder = JsonEncoder.withIndent('  ');
    final json = encoder.convert(entry.toJson());
    _writeWithLevel(entry.level, json);
  }

  /// Logs entry in human-readable format:
  /// ```
  /// [14:32:10 INFO ] User login successful {"context": {...}, "metadata": {...}}
  /// ```
  void _logFormatted(LogEntry entry) {
    final time = _formatTime(entry.timestamp);
    final levelStr = _formatLevel(entry.level);
    final message = entry.message;

    var output = '[$time $levelStr] $message';

    if (entry.metadata != null && entry.metadata!.isNotEmpty) {
      output += ' ${jsonEncode({"metadata": entry.metadata})}';
    }

    if (entry.context.isNotEmpty) {
      output += ' ${jsonEncode({"context": entry.context})}';
    }

    _writeWithLevel(entry.level, output);
  }

  /// Formats UTC timestamp as `HH:MM:SS`.
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }

  /// Formats log level with optional color and padding.
  String _formatLevel(LogLevel level) {
    if (!useColors) return level.name.padRight(7);

    final color = switch (level) {
      LogLevel.error => _ansiRed,
      LogLevel.success => _ansiGreen,
      LogLevel.warn => _ansiYellow,
      LogLevel.info => _ansiBlue,
      LogLevel.debug => _ansiCyan,
      LogLevel.trace => _ansiMagenta,
    };

    return '$color${level.name.padRight(7)}$_ansiReset';
  }

  /// Writes message to stdout with level-specific coloring.
  void _writeWithLevel(LogLevel level, String message) {
    final colored = switch (level) {
      LogLevel.error => '$_ansiRed$message$_ansiReset',
      LogLevel.success => '$_ansiGreen$message$_ansiReset',
      LogLevel.warn => '$_ansiYellow$message$_ansiReset',
      LogLevel.info => '$_ansiBlue$message$_ansiReset',
      LogLevel.debug => '$_ansiCyan$message$_ansiReset',
      LogLevel.trace => '$_ansiMagenta$message$_ansiReset',
    };
    stdout.writeln(colored);
  }

  @override
  Future<void> dispose() async {
    // No resources to clean up
  }
}

/// File-based log transport with rotation support.
///
/// Logs are appended as **JSON Lines** (one JSON object per line).
///
/// Example line:
/// ```json
/// {"level":"INFO","code":3,"timestamp":"2025-04-05T12:00:00.000Z","message":"Start"}
/// ```
base class LogFileTransport implements LogTransport {
  /// Path to the log file (e.g., `storage/logs/app.log`).
  final String filePath;

  /// Maximum file size in bytes before rotation (default: 10 MB).
  final int maxFileSize;

  /// Maximum number of rotated files to keep (default: 5).
  final int maxFiles;

  /// Optional pre-opened [IOSink] (for testing or shared streams).
  final IOSink? _sink;

  /// Creates a file transport.
  ///
  /// Directory is created if it doesn't exist.
  LogFileTransport({
    required this.filePath,
    this.maxFileSize = 10 * 1024 * 1024, // 10 MB
    this.maxFiles = 5,
    IOSink? sink,
  }) : _sink = sink;

  /// Lazily creates an [IOSink] in append mode.
  IOSink _createSink() {
    final file = File(filePath);
    final directory = file.parent;

    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return file.openWrite(mode: FileMode.append);
  }

  @override
  Future<void> log(LogEntry entry) async {
    final sink = _sink ?? _createSink();
    final jsonLine = '${jsonEncode(entry.toJson())},\n';

    try {
      sink.write(jsonLine);
      await sink.flush();

      // TODO: Implement rotation when size > maxFileSize
      // final size = await File(filePath).length();
      // if (size > maxFileSize) { _rotate(); }
    } catch (e) {
      stderr.writeln('File transport error: $e');
    }
  }

  @override
  Future<void> dispose() async {
    // Close sink if we created it
    if (_sink == null) {
      // We own the sink — close it
      // Note: This requires tracking ownership
    }
  }
}
