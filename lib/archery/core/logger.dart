import 'package:archery/archery/archery.dart';

enum LogLevel {

  error(0),
  success(1),
  warn(2),
  info(3),
  debug(4),
  trace(5);

  final int code;
  const LogLevel(this.code);

  String get name => toString().split(".").last.toUpperCase();

  static LogLevel fromCode(int code) {
    return LogLevel.values.firstWhere(
            (level) => level.code == code,
        orElse: () => LogLevel.info);
  }
}
class LogEntry {

  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final Map<String, dynamic> context;
  final Map<String, dynamic>? metadata;

  LogEntry({required this.level, required this.message, this.metadata, Map<String, dynamic>? context})
      :timestamp = DateTime.now().toUtc(), context = context ?? {};


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

  @override
  String toString() {

    return "[$level] $message";
  }

}
abstract class LogTransport {

  Future<void> log(LogEntry entry);
  Future<void> dispose();

}
class Logger {
  final List<LogTransport> _transports;
  final Map<String, dynamic> _context;

  Logger({List<LogTransport>? transports, Map<String, dynamic>? context,})
      :  _transports = transports ?? [], _context = context ?? {};


  Future<void> _log(LogLevel level, String message, [Map<String, dynamic>? metadata]) async {

    final entry = LogEntry(level: level, message: message, metadata: metadata, context: _context);
    for(final transport in _transports) {
      try {
        await transport.log(entry);
      } catch(e) {
        stderr.writeln("Log transport error: $e");
      }

    }
  }

  Future<void> error(String message, [Map<String, dynamic>? metadata]) => _log(LogLevel.error, message, metadata);
  Future<void> success(String message, [Map<String, dynamic>? metadata]) => _log(LogLevel.success, message, metadata);
  Future<void> warn(String message, [Map<String, dynamic>? metadata]) => _log(LogLevel.warn, message, metadata);
  Future<void> info(String message, [Map<String, dynamic>? metadata]) => _log(LogLevel.info, message, metadata);
  Future<void> debug(String message, [Map<String, dynamic>? metadata]) => _log(LogLevel.debug, message, metadata);
  Future<void> trace(String message, [Map<String, dynamic>? metadata]) => _log(LogLevel.trace, message, metadata);

  Logger child([Map<String, dynamic>? additionalContext]) {
    return Logger(transports: _transports, context: {..._context, ...?additionalContext});
  }

  Future<void> dispose() async {
    for(final transport in _transports) {
      await transport.dispose();
    }
  }

}
class ConsoleTransport implements LogTransport {
  final bool useColors;
  final bool formatJson;

  static const _ansiReset = '\x1B[0m';
  static const _ansiRed = '\x1B[31m';
  static const _ansiYellow = '\x1B[33m';
  static const _ansiGreen = '\x1B[32m';
  static const _ansiBlue = '\x1B[34m';
  static const _ansiCyan = '\x1B[36m';
  static const _ansiMagenta = '\x1B[35m';

  ConsoleTransport({this.useColors = true, this.formatJson = false});

  @override
  Future<void> log(LogEntry entry) async {
    final config = App().container.make<AppConfig>();

    final debugMode = config.get('app.debug');

    if(!debugMode) return;

    if (formatJson) {
      _logJson(entry);
    } else {
      _logFormatted(entry);
    }
  }

  void _logJson(LogEntry entry) {
    final JsonEncoder encoder = JsonEncoder.withIndent(
      '  ',
    ); // Two spaces for indentation

    final json = encoder.convert(entry.toJson());

    _writeWithLevel(entry.level, json);
  }

  void _logFormatted(LogEntry entry) {
    final time = _formatTime(entry.timestamp);
    final levelStr = _formatLevel(entry.level);
    final message = entry.message;

    var output = '[$time $levelStr] $message ';

    if (entry.metadata != null && entry.metadata!.isNotEmpty) {
      output += jsonEncode({"metadata": entry.metadata});
    }

    output += ' ';

    output += jsonEncode({"context": entry.context});

    _writeWithLevel(entry.level, output);
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}:';
  }

  String _formatLevel(LogLevel level) {
    if (!useColors) return level.name.padRight(5);

    final color = switch (level) {
      LogLevel.error => _ansiRed,
      LogLevel.success => _ansiGreen,
      LogLevel.warn => _ansiYellow,
      LogLevel.info => _ansiBlue,
      LogLevel.debug => _ansiCyan,
      LogLevel.trace => _ansiMagenta,
    };

    return "$color${level.name.padRight(5)}$_ansiReset";
  }

  void _writeWithLevel(LogLevel level, String message) {
    switch (level) {
      case LogLevel.success:
        stdout.writeln('$_ansiGreen$message$_ansiReset');
        break;
      case LogLevel.error:
        stdout.writeln('$_ansiRed$message$_ansiReset');
        break;
      case LogLevel.warn:
        stdout.writeln('$_ansiYellow$message$_ansiReset');

      case LogLevel.info:
        stdout.writeln('$_ansiBlue$message$_ansiReset');

      case LogLevel.debug:
        stdout.writeln('$_ansiCyan$message$_ansiReset');

      case LogLevel.trace:
        stdout.writeln('$_ansiMagenta$message$_ansiReset');
    }
  }

  @override
  Future<void> dispose() {
    // TODO: implement dispose
    throw UnimplementedError();
  }
}
class LogFileTransport implements LogTransport {

  final String filePath;
  final int maxFileSize;
  final int maxFiles;
  final IOSink? _sink;
  final bool _manageSink;

  LogFileTransport({
    required this.filePath,
    this.maxFileSize = 10 * 1024 * 1024, // 10MB
    this.maxFiles = 5,
    IOSink? sink,
  }) : _sink = sink, _manageSink = sink == null;


  IOSink _createSink() {
    final file = File(filePath);
    final directory = file.parent;

    if(!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return file.openWrite(mode: FileMode.append);
  }


  @override
  Future<void> log(LogEntry entry) async {
    final sink = _sink ?? _createSink();
    final jsonLine = '\n${jsonEncode(entry.toJson())},';

    try {
      sink.write(jsonLine);
      await sink.flush();
    } catch(e) {
      stderr.writeln("File transport error: $e");
    }
  }

  @override
  Future<void> dispose() async {

  }

}