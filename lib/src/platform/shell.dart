// What the program asks of Windows: open a folder in Explorer, open a file in its own program,
// show a file in Explorer, send things to the Recycle Bin, list the drives, pick a folder.
// v6.2 did these through ActiveX (Shell.Application, FileSystemObject); v7 calls Windows itself.
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:file_selector/file_selector.dart' as fs;
import 'package:win32/win32.dart' as w;

class DriveInfo {
  const DriveInfo({
    required this.letter,
    required this.type,
    required this.ready,
    this.total = 0,
    this.free = 0,
    this.label = '',
  });

  /// "D"
  final String letter;

  /// "Local Disk", "Removable", "Network", "CD Drive" …
  final String type;
  final bool ready;
  final int total;
  final int free;
  final String label;

  String get root => '$letter:\\';
  int get usedPercent => total > 0 ? ((total - free) * 100 / total).round() : 0;
}

abstract class Shell {
  /// This computer's name, to notice settings that came from another one
  String get computerName;

  /// OPEN on a folder: Explorer
  Future<bool> openFolder(String path);

  /// OPEN on a file: the program Windows has for its type; false when there is none
  Future<bool> openFile(String path);

  /// Explorer with the item selected
  Future<void> reveal(String path);

  /// A web page in the browser
  Future<void> openUrl(String url);

  /// DELETE: to the Recycle Bin. Returns "name: why" for each one that failed.
  Future<List<String>> recycle(List<String> paths);

  List<DriveInfo> drives();

  Future<String?> pickFolder({String? initial, String title = 'Pick the project root folder'});

  Future<String?> pickFile({String? initial, String label = 'Text files', List<String> extensions = const ['txt']});
}

Shell defaultShell() => Platform.isWindows ? WindowsShell() : OtherShell();

class WindowsShell implements Shell {
  WindowsShell() {
    // no "insert a disk" boxes when an empty card reader or DVD drive is read
    w.SetErrorMode(w.SEM_FAILCRITICALERRORS);
  }

  @override
  String get computerName => Platform.environment['COMPUTERNAME'] ?? Platform.localHostname;

  bool _shellExecute(String file, {String? params, String? dir}) {
    final verb = 'open'.toNativeUtf16();
    final f = file.toNativeUtf16();
    final a = params == null ? nullptr : params.toNativeUtf16();
    final d = dir == null ? nullptr : dir.toNativeUtf16();
    try {
      // anything above 32 is success
      return w.ShellExecute(0, verb, f, a, d, w.SW_SHOWNORMAL) > 32;
    } finally {
      for (final x in [verb, f, a, d]) {
        if (x != nullptr) calloc.free(x);
      }
    }
  }

  @override
  Future<bool> openFolder(String path) async => _shellExecute('explorer.exe', params: '"$path"');

  @override
  Future<bool> openFile(String path) async => _shellExecute(path, dir: File(path).parent.path);

  @override
  Future<void> reveal(String path) async => _shellExecute('explorer.exe', params: '/select,"$path"');

  @override
  Future<void> openUrl(String url) async => _shellExecute(url);

  @override
  Future<List<String>> recycle(List<String> paths) async {
    final failed = <String>[];
    for (final path in paths) {
      // pFrom is a list ending in two zero characters
      final from = calloc<Uint16>(path.length + 2);
      for (var i = 0; i < path.length; i++) {
        from[i] = path.codeUnitAt(i);
      }
      final op = calloc<w.SHFILEOPSTRUCT>();
      try {
        op.ref
          ..hwnd = 0
          ..wFunc = w.FO_DELETE
          ..pFrom = from.cast()
          ..pTo = nullptr
          ..fFlags = w.FOF_ALLOWUNDO | w.FOF_NOCONFIRMATION | w.FOF_SILENT | w.FOF_NOERRORUI | w.FOF_WANTNUKEWARNING;
        final r = w.SHFileOperation(op);
        if (r != 0 || op.ref.fAnyOperationsAborted != 0) {
          failed.add('${path.split('\\').last}: Windows answered $r (the item may be open in another program)');
        }
      } finally {
        calloc
          ..free(op)
          ..free(from);
      }
    }
    return failed;
  }

  static const _types = {
    w.DRIVE_REMOVABLE: 'Removable',
    w.DRIVE_FIXED: 'Local Disk',
    w.DRIVE_REMOTE: 'Network',
    w.DRIVE_CDROM: 'CD Drive',
    w.DRIVE_RAMDISK: 'RAM Disk',
  };

  @override
  List<DriveInfo> drives() {
    final out = <DriveInfo>[];
    final mask = w.GetLogicalDrives();
    for (var i = 0; i < 26; i++) {
      if (mask & (1 << i) == 0) continue;
      final letter = String.fromCharCode(65 + i);
      final root = '$letter:\\'.toNativeUtf16();
      final freeToMe = calloc<Uint64>(), total = calloc<Uint64>(), free = calloc<Uint64>();
      final label = calloc<Uint16>(261).cast<Utf16>();
      try {
        final type = _types[w.GetDriveType(root)] ?? 'Drive';
        final ready = w.GetDiskFreeSpaceEx(root, freeToMe, total, free) != 0;
        var name = '';
        if (ready && w.GetVolumeInformation(root, label, 261, nullptr, nullptr, nullptr, nullptr, 0) != 0) {
          name = label.toDartString();
        }
        out.add(
          DriveInfo(
            letter: letter,
            type: type,
            ready: ready,
            total: ready ? total.value : 0,
            free: ready ? freeToMe.value : 0,
            label: name,
          ),
        );
      } finally {
        calloc
          ..free(root)
          ..free(freeToMe)
          ..free(total)
          ..free(free)
          ..free(label);
      }
    }
    return out;
  }

  @override
  Future<String?> pickFolder({String? initial, String title = 'Pick the project root folder'}) =>
      fs.getDirectoryPath(initialDirectory: initial, confirmButtonText: 'Choose');

  @override
  Future<String?> pickFile({
    String? initial,
    String label = 'Text files',
    List<String> extensions = const ['txt'],
  }) async {
    final f = await fs.openFile(
      initialDirectory: initial,
      acceptedTypeGroups: [fs.XTypeGroup(label: label, extensions: extensions)],
    );
    return f?.path;
  }
}

/// For trying the program on Linux or macOS while developing; the program is made for Windows
class OtherShell implements Shell {
  @override
  String get computerName => Platform.localHostname;

  Future<bool> _open(String target) async {
    try {
      final r = await Process.run(Platform.isMacOS ? 'open' : 'xdg-open', [target]);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openFolder(String path) => _open(path);
  @override
  Future<bool> openFile(String path) => _open(path);
  @override
  Future<void> reveal(String path) => _open(File(path).parent.path);
  @override
  Future<void> openUrl(String url) => _open(url);

  @override
  Future<List<String>> recycle(List<String> paths) async {
    final failed = <String>[];
    for (final path in paths) {
      try {
        await FileSystemEntity.type(path) == FileSystemEntityType.directory
            ? await Directory(path).delete(recursive: true)
            : await File(path).delete();
      } catch (e) {
        failed.add('$path: $e');
      }
    }
    return failed;
  }

  @override
  List<DriveInfo> drives() => const [];

  @override
  Future<String?> pickFolder({String? initial, String title = 'Pick the project root folder'}) =>
      fs.getDirectoryPath(initialDirectory: initial);

  @override
  Future<String?> pickFile({
    String? initial,
    String label = 'Text files',
    List<String> extensions = const ['txt'],
  }) async => (await fs.openFile(
    acceptedTypeGroups: [fs.XTypeGroup(label: label, extensions: extensions)],
  ))?.path;
}
