import 'package:archery/archery/archery.dart';

class Helpers {

  static Future<void> benchMark(Future<void> Function() code) async {

    final watch = Stopwatch()..start();

    await code();

    watch.stop();
    print("Benchmark: ${watch.elapsedMilliseconds}ms");
  }

  static dynamic sortRecursive(dynamic item) {
    if (item is Map) {
      final sortedKeys = item.keys.toList()..sort();
      return {
        for (var key in sortedKeys) key: sortRecursive(item[key]),
      };
    } else if (item is List) {
      return item.map(sortRecursive).toList();
    }
    return item;
  }

}


