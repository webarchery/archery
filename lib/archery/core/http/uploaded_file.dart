import 'package:archery/archery/archery.dart';

class UploadedFile {
  final String filename;
  final String contentType;
  final Future<Uint8List> _cachedBytes;
  final int? _knownLength;

  UploadedFile.fromBytes({required this.filename, required Uint8List bytes, required this.contentType}) : _cachedBytes = Future.value(bytes), _knownLength = bytes.length;

  // empty factory constructor for invalid files
  factory UploadedFile.empty() {
    return UploadedFile.fromBytes(filename: '', bytes: Uint8List(0), contentType: 'application/octet-stream');
  }

  // Add validation property
  bool get isValid => filename.isNotEmpty;

  /// Get the file content as bytes
  Future<Uint8List> get bytes async => await _cachedBytes;

  /// Get the file content as string
  Future<String> get string async => utf8.decode(await _cachedBytes);

  /// Get the length
  Future<int> get length async => _knownLength ?? (await _cachedBytes).length;

  /// Check if length is known without calculating it
  bool get isLengthKnown => _knownLength != null;

  /// Stream the file content to a StreamSink (memory efficient)
  Future<void> streamTo(StreamSink<List<int>> sink) async {
    final bytes = await _cachedBytes;
    sink.add(bytes);
    // Note: No flush() - StreamSink doesn't have flush capability
    // Caller is responsible for flushing/closing the sink
  }

  /// Save the file to the specified path
  /// you must know how dart projects relate to your root folder to know exactly where to save your images
  /// use Directory("lib/src/") to hook into your codebase
  Future<File> save(String path) async {
    final file = File(path);
    final bytes = await _cachedBytes;
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<File> savePublic({bool autoName = true}) async {
    if (autoName) {
      final ext = filename.split(".").last;

      final uuid = Uuid().v4();

      final newFileName = "$uuid.$ext";
      final file = File("lib/src/http/public/img/$newFileName");

      if (!await file.exists()) await file.create(recursive: true);

      final bytes = await _cachedBytes;
      await file.writeAsBytes(bytes);
      return file;
    } else {
      final file = File("lib/src/http/public/img/$filename");

      if (!await file.exists()) await file.create(recursive: true);

      final bytes = await _cachedBytes;
      await file.writeAsBytes(bytes);
      return file;
    }
  }

  @override
  String toString() => 'UploadedFile(filename: $filename, type: $contentType, lengthKnown: $isLengthKnown)';
}
