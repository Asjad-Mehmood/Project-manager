// Where the program keeps its things. v6.2 wrote them next to itself, which needs a folder you
// can write to; v7 uses the user's own AppData, so it works from Program Files or a network share:
//   %APPDATA%\Excel to KML\Project Folder Manager\settings.json
//   %LOCALAPPDATA%\Excel to KML\Project Folder Manager\index\<project>.txt
// Files are written to a .tmp first and then swapped in, so a crash never leaves half a file.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../core/search_index.dart';
import '../core/settings.dart';

class Store {
  Store({required this.settingsDir, required this.dataDir});

  factory Store.forThisUser() {
    final env = Platform.environment;
    if (Platform.isWindows) {
      final roaming = env['APPDATA'] ?? p.join(env['USERPROFILE'] ?? '.', 'AppData', 'Roaming');
      final local = env['LOCALAPPDATA'] ?? p.join(env['USERPROFILE'] ?? '.', 'AppData', 'Local');
      return Store(
        settingsDir: p.join(roaming, 'Excel to KML', 'Project Folder Manager'),
        dataDir: p.join(local, 'Excel to KML', 'Project Folder Manager'),
      );
    }
    final home = env['HOME'] ?? '.';
    final dir = p.join(home, '.config', 'project-folder-manager');
    return Store(settingsDir: dir, dataDir: dir);
  }

  final String settingsDir;
  final String dataDir;

  File get _settings => File(p.join(settingsDir, 'settings.json'));

  /// Settings, or null on the very first start
  Settings? loadSettings() {
    try {
      if (!_settings.existsSync()) return null;
      return Settings.fromJson(jsonDecode(_settings.readAsStringSync()));
    } catch (_) {
      return null; // damaged: start again rather than not open
    }
  }

  void saveSettings(Settings s) => _write(_settings, const JsonEncoder.withIndent('  ').convert(s.toJson()));

  File _indexFile(String root) {
    final id = sha1.convert(utf8.encode(root.toLowerCase())).toString().substring(0, 16);
    return File(p.join(dataDir, 'index', '$id.txt'));
  }

  SearchIndex? loadIndex(String root) {
    try {
      final f = _indexFile(root);
      if (!f.existsSync()) return null;
      return SearchIndex.parse(f.readAsStringSync());
    } catch (_) {
      return null;
    }
  }

  void saveIndex(String root, SearchIndex idx) {
    try {
      _write(_indexFile(root), idx.serialize());
    } catch (_) {
      // the index can always be made again
    }
  }

  void _write(File f, String text) {
    f.parent.createSync(recursive: true);
    final tmp = File('${f.path}.tmp');
    tmp.writeAsStringSync(text, flush: true);
    if (f.existsSync()) f.deleteSync();
    tmp.renameSync(f.path);
  }
}

/// v6.2's settings file name
const v6ConfigName = 'Project_Folder_Manager_config.txt';

/// Where a v6.2 copy may have kept its settings: the Survey Toolkit's folder, the Desktop,
/// Downloads and Documents, and one folder down from each
List<File> findV6Configs(Map<String, String> env) {
  final local = env['LOCALAPPDATA'] ?? '';
  final home = env['USERPROFILE'] ?? env['HOME'] ?? '';
  final places = <String>[
    if (local.isNotEmpty) p.join(local, 'Survey Toolkit', 'apps', 'Project Folder Manager'),
    if (home.isNotEmpty) ...[
      p.join(home, 'Desktop'),
      p.join(home, 'Downloads'),
      p.join(home, 'Documents'),
      p.join(home, 'OneDrive', 'Desktop'),
      p.join(home, 'OneDrive', 'Documents'),
    ],
  ];
  final found = <File>[];
  for (final dir in places) {
    final f = File(p.join(dir, v6ConfigName));
    if (f.existsSync()) found.add(f);
    try {
      for (final e in Directory(dir).listSync(followLinks: false)) {
        if (e is Directory) {
          final g = File(p.join(e.path, v6ConfigName));
          if (g.existsSync()) found.add(g);
        }
      }
    } catch (_) {
      // not there
    }
  }
  found.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
  return found;
}
