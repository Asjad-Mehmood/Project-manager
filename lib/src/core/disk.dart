// Reading folders from the disk, folders first then files, A to Z ignoring case (as v6.2 did),
// kept in a cache until something changes or REFRESH is pressed.
import 'dart:io';

import 'package:path/path.dart' as p;

class Entry {
  const Entry({required this.name, required this.path, required this.isDir, this.size, this.modified});
  final String name;
  final String path;
  final bool isDir;
  final int? size;
  final DateTime? modified;

  bool get isFile => !isDir;
}

/// A key for a path that ignores case and a trailing separator (Windows paths ignore case)
String pathKey(String path) {
  var n = p.normalize(path);
  if (n.length > 1 && (n.endsWith(r'\') || n.endsWith('/')) && !RegExp(r'^[A-Za-z]:[\\/]$').hasMatch(n)) {
    n = n.substring(0, n.length - 1);
  }
  return n.toLowerCase();
}

/// True when [inner] is [outer] or somewhere inside it
bool isSameOrInside(String inner, String outer) {
  final a = pathKey(inner), b = pathKey(outer);
  if (a == b) return true;
  final sep = b.endsWith(r'\') || b.endsWith('/') ? '' : p.separator;
  return a.startsWith('$b$sep');
}

int compareEntries(Entry a, Entry b) {
  if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

/// What is in a folder; empty when it isn't there or can't be read
List<Entry> readFolder(String path) {
  final out = <Entry>[];
  try {
    for (final e in Directory(path).listSync(followLinks: false)) {
      final name = p.basename(e.path);
      FileStat st;
      try {
        st = FileStat.statSync(e.path); // follows a link to what it points at
      } catch (_) {
        continue;
      }
      if (st.type == FileSystemEntityType.directory) {
        out.add(Entry(name: name, path: e.path, isDir: true, modified: st.modified));
      } else if (st.type == FileSystemEntityType.file) {
        out.add(Entry(name: name, path: e.path, isDir: false, size: st.size, modified: st.modified));
      }
    }
  } on FileSystemException {
    // not there, no access, or the drive went away
  }
  out.sort(compareEntries);
  return out;
}

bool folderExists(String path) {
  try {
    return path.isNotEmpty && Directory(path).existsSync();
  } catch (_) {
    return false;
  }
}

bool anyExists(String path) {
  try {
    return FileSystemEntity.typeSync(path, followLinks: true) != FileSystemEntityType.notFound;
  } catch (_) {
    return false;
  }
}

class FolderCache {
  final _kids = <String, List<Entry>>{};

  List<Entry> entries(String path) => _kids.putIfAbsent(pathKey(path), () => readFolder(path));

  List<Entry> folders(String path) => entries(path).where((e) => e.isDir).toList();

  /// Number of sub-folders, for the "3 sub" chip
  int folderCount(String path) => entries(path).where((e) => e.isDir).length;

  /// Read [path] again next time
  void forget(String path) => _kids.remove(pathKey(path));

  /// [path] has been read and is kept
  bool has(String path) => _kids.containsKey(pathKey(path));

  void clear() => _kids.clear();
}
