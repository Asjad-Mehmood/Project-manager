import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:project_folder_manager/src/platform/shell.dart';
import 'package:project_folder_manager/src/state/app_model.dart';
import 'package:project_folder_manager/src/state/store.dart';

/// Windows' part, recorded instead of done (delete really deletes, as the Recycle Bin would remove it)
class FakeShell implements Shell {
  final opened = <String>[];
  final revealed = <String>[];
  final recycled = <String>[];
  bool fileOpens = true;
  List<DriveInfo> driveList = const [
    DriveInfo(letter: 'C', type: 'Local Disk', ready: true, total: 254000000000, free: 80000000000, label: 'Windows'),
    DriveInfo(
      letter: 'D',
      type: 'Local Disk',
      ready: true,
      total: 1000000000000,
      free: 412000000000,
      label: 'Projects',
    ),
    DriveInfo(letter: 'E', type: 'Removable', ready: false),
  ];
  String? folderToPick;

  @override
  String computerName = 'PC-1';

  @override
  Future<bool> openFolder(String path) async {
    opened.add(path);
    return true;
  }

  @override
  Future<bool> openFile(String path) async {
    opened.add(path);
    return fileOpens;
  }

  @override
  Future<void> reveal(String path) async => revealed.add(path);

  @override
  Future<void> openUrl(String url) async => opened.add(url);

  @override
  Future<List<String>> recycle(List<String> paths) async {
    for (final x in paths) {
      recycled.add(x);
      final t = FileSystemEntity.typeSync(x);
      if (t == FileSystemEntityType.directory) {
        Directory(x).deleteSync(recursive: true);
      } else if (t == FileSystemEntityType.file) {
        File(x).deleteSync();
      }
    }
    return const [];
  }

  @override
  List<DriveInfo> drives() => driveList;

  @override
  Future<String?> pickFolder({String? initial, String title = ''}) async => folderToPick;

  @override
  Future<String?> pickFile({String? initial, String label = '', List<String> extensions = const []}) async => null;
}

/// A project on disk like the screenshots on the website
Directory makeProject(Directory base, {String name = 'Project'}) {
  final root = Directory(p.join(base.path, name))..createSync(recursive: true);
  const tree = {
    '00_Admin': ['Contracts', 'Minutes'],
    '10_Survey': ['01_Control Points', '02_Topographic Survey', '03_As-Built'],
    '20_Piping': ['Isometrics', 'Line List'],
    '30_Electrical': ['Single Line'],
    '50_Civil Works': ['Foundations', 'Roads'],
    '99_Archive': ['2025'],
  };
  tree.forEach((m, kids) {
    for (final k in kids) {
      Directory(p.join(root.path, m, k)).createSync(recursive: true);
    }
  });
  File(p.join(root.path, '10_Survey', 'Survey_Report_Rev2.pdf')).writeAsStringSync('x' * 2000);
  File(p.join(root.path, '10_Survey', '01_Control Points', 'CP_list.csv')).writeAsStringSync('cp,e,n\n');
  File(p.join(root.path, '20_Piping', 'Isometrics', 'ISO-001.dwg')).writeAsStringSync('dwg');
  return root;
}

class Harness {
  Harness._(this.base, this.shell, this.store, this.model, this.root);

  static Harness make({String? settingsJson, Map<String, String>? env, bool project = true}) {
    final base = Directory.systemTemp.createTempSync('pfm');
    final shell = FakeShell();
    final store = Store(settingsDir: p.join(base.path, 'roaming'), dataDir: p.join(base.path, 'local'));
    if (settingsJson != null) {
      Directory(store.settingsDir).createSync(recursive: true);
      File(p.join(store.settingsDir, 'settings.json')).writeAsStringSync(settingsJson);
    }
    final root = project ? makeProject(base) : Directory(p.join(base.path, 'Project'));
    final model = AppModel(store: store, shell: shell, env: env ?? {'USERPROFILE': p.join(base.path, 'home')});
    return Harness._(base, shell, store, model, root);
  }

  final Directory base;
  final FakeShell shell;
  final Store store;
  final AppModel model;
  final Directory root;

  String at(String rel) => p.join(root.path, rel);

  void dispose() {
    model.dispose();
    try {
      base.deleteSync(recursive: true);
    } catch (_) {}
  }
}
