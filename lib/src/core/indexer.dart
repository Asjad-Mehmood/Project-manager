// Builds the index in the background (another isolate), so the window never freezes the way the
// v6.2 one could. It reads the shallow levels first, then deeper ones, and sends what it found
// every fraction of a second: STOP keeps everything found so far.
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import 'search_index.dart';

/// Folders a drive-wide index skips at the top of each drive (v6.2's list)
const skipAtTop = {
  'windows',
  'program files',
  'program files (x86)',
  'programdata',
  r'$recycle.bin',
  'system volume information',
  'appdata',
  'node_modules',
  'recovery',
  'msocache',
  'perflogs',
  r'$windows.~bt',
  r'$windows.~ws',
  'onedrivetemp',
};

class IndexJob {
  const IndexJob({required this.seeds, required this.depth, required this.files, required this.wholeDrives});

  /// Where to start: the project root, a drive, or every drive
  final List<String> seeds;

  /// How many levels down
  final int depth;

  /// Files too, not only folders
  final bool files;

  /// A drive or all drives: Windows' own folders are skipped at the top
  final bool wholeDrives;
}

class IndexProgress {
  const IndexProgress(this.lines, this.foldersRead, this.queued, {this.done = false});

  /// New "F\t…" / "X\t…" lines since the last report
  final List<String> lines;
  final int foldersRead;
  final int queued;
  final bool done;

  /// For the thin bar: never shows 100% until it really is done
  int get percent =>
      done ? 100 : (queued == 0 ? 96 : (foldersRead * 100 / (foldersRead + queued)).round().clamp(0, 96));
}

/// The walk itself; runs anywhere (the tests call it directly)
void walk(IndexJob job, void Function(IndexProgress) report, {Duration every = const Duration(milliseconds: 150)}) {
  final queue = <(String, int)>[for (final s in job.seeds) (s, 0)];
  var head = 0, read = 0, found = 0;
  var batch = <String>[];
  final clock = Stopwatch()..start();
  while (head < queue.length && found < indexCap) {
    final (path, depth) = queue[head++];
    read++;
    List<FileSystemEntity> kids;
    try {
      kids = Directory(path).listSync(followLinks: false);
    } catch (_) {
      continue;
    }
    for (final e in kids) {
      if (found >= indexCap) break;
      if (e is Directory) {
        if (job.wholeDrives && depth == 0 && skipAtTop.contains(p.basename(e.path).toLowerCase())) continue;
        batch.add('F\t${e.path}');
        found++;
        if (depth + 1 < job.depth) queue.add((e.path, depth + 1));
      } else if (e is File && job.files) {
        batch.add('X\t${e.path}');
        found++;
      }
    }
    if (clock.elapsed >= every) {
      report(IndexProgress(batch, read, queue.length - head));
      batch = <String>[];
      clock.reset();
    }
  }
  report(IndexProgress(batch, read, queue.length - head, done: true));
}

/// One INDEX run in another isolate. [progress] ends when it is done or stopped.
class IndexRun {
  IndexRun._();

  final _ctl = StreamController<IndexProgress>();
  final _port = ReceivePort();
  Isolate? _isolate;
  bool _stopped = false;

  Stream<IndexProgress> get progress => _ctl.stream;
  bool get stopped => _stopped;

  static Future<IndexRun> start(IndexJob job) async {
    final run = IndexRun._();
    run._port.listen((m) {
      if (m is IndexProgress && !run._ctl.isClosed) {
        run._ctl.add(m);
        if (m.done) run._finish();
      }
    });
    run._isolate = await Isolate.spawn(_entry, (job, run._port.sendPort));
    if (run._stopped) run._isolate!.kill(priority: Isolate.immediate);
    return run;
  }

  static void _entry((IndexJob, SendPort) a) {
    final (job, send) = a;
    walk(job, send.send);
  }

  void _finish() {
    _port.close();
    if (!_ctl.isClosed) unawaited(_ctl.close());
  }

  /// STOP: what was found so far stays
  void stop() {
    if (_stopped) return;
    _stopped = true;
    _isolate?.kill(priority: Isolate.immediate);
    _finish();
  }
}
