// FIND: looks on every drive for folders that look like a project. v6.2 only knew one name
// (a top-level folder starting with "04_"); v7 looks for a folder holding at least three numbered
// modules ("00_Admin", "10 Survey" …), at the top of each drive and one level down.
import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'indexer.dart' show skipAtTop;

final _numbered = RegExp(r'^\d{2}[ _\-.]');

/// How many of [folder]'s sub-folders are numbered modules
int numberedModules(String folder) {
  try {
    return Directory(folder)
        .listSync(followLinks: false)
        .whereType<Directory>()
        .where((d) => _numbered.hasMatch(p.basename(d.path)))
        .length;
  } catch (_) {
    return 0;
  }
}

class Candidate {
  const Candidate(this.path, this.modules);
  final String path;
  final int modules;
}

/// Folders under [roots] (and one level down) holding at least [min] numbered modules, the
/// most modules first. v6.2's "04_" folders are always included.
Future<List<Candidate>> findProjects(List<String> roots, {int min = 3, bool Function()? cancelled}) async {
  final out = <Candidate>[];
  Future<void> look(String dir, int depth) async {
    if (cancelled?.call() == true) return;
    List<FileSystemEntity> kids;
    try {
      kids = await Directory(dir).list(followLinks: false).toList();
    } catch (_) {
      return;
    }
    for (final k in kids.whereType<Directory>()) {
      final name = p.basename(k.path);
      if (depth == 0 && skipAtTop.contains(name.toLowerCase())) continue;
      if (name.startsWith(r'$') || name.startsWith('.')) continue;
      final n = numberedModules(k.path);
      if (n >= min || (depth == 0 && name.startsWith('04_'))) {
        out.add(Candidate(k.path, n));
      } else if (depth == 0) {
        await look(k.path, 1);
      }
      await Future<void>.delayed(Duration.zero);
    }
  }

  for (final r in roots) {
    await look(r, 0);
  }
  out.sort((a, b) => b.modules.compareTo(a.modules));
  return out;
}
