// ProjectFolderManager.exe --self-check <empty folder> <report.json>
// Run by the Windows check on GitHub's machines (tool/windows_check.ps1): the installed program
// does the real jobs on a real Windows, without the window: reads the drives, makes a project,
// indexes and searches it, copies, moves, renames, undoes, sends a file to the Recycle Bin, and
// brings in a v6.2 settings file. It writes what passed to <report.json> and closes.
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'core/bulk_rename.dart';
import 'core/file_ops.dart';
import 'core/indexer.dart';
import 'core/search_index.dart';
import 'platform/shell.dart';
import 'state/app_model.dart';
import 'state/store.dart';

Future<bool> selfCheck(String folder, String reportPath) async {
  final steps = <Map<String, Object>>[];
  var ok = true;
  Future<void> step(String name, Future<void> Function() f) async {
    try {
      await f();
      steps.add({'step': name, 'ok': true});
    } catch (e) {
      ok = false;
      steps.add({'step': name, 'ok': false, 'error': '$e'});
    }
  }

  void check(bool c, String what) {
    if (!c) throw StateError(what);
  }

  final base = Directory(folder)..createSync(recursive: true);
  final shell = defaultShell();
  final store = Store(settingsDir: p.join(base.path, 'settings'), dataDir: p.join(base.path, 'data'));
  final root = Directory(p.join(base.path, 'D', 'Project'))..createSync(recursive: true);
  final m = AppModel(store: store, shell: shell, env: const {});

  await step('the drives, with free space', () async {
    final d = shell.drives();
    final c = d.where((x) => x.letter == 'C').firstOrNull;
    check(c != null && c.ready && c.total > 0 && c.free > 0, 'drive C: with its size: $d');
  });
  await step('this computer\'s name', () async => check(shell.computerName.isNotEmpty, 'no name'));

  await step('a v6.2 settings file is brought in', () async {
    final cfg = File(p.join(base.path, 'Project_Folder_Manager_config.txt'))
      ..writeAsStringSync(
        '${root.path}\r\n#PC=OLD\r\n#TITLE=Check\r\n#OPT=tree:0,deep:1,miss:0,depth:6,files:1,drv:0,lay:3\r\n',
      );
    m.start();
    check(m.importV6(cfg.path) == null, 'import');
    check(m.title == 'Check' && m.options.layout == 3, 'title and view');
  });

  await step('an empty project gets the standard folders', () async {
    check((await m.createStandardFolders()).isEmpty, 'made');
    check(m.project!.modules.length == 11, '11 modules');
    File(p.join(root.path, '10_Survey', 'Survey Report & Notes (rev 2).pdf')).writeAsStringSync('x' * 5000);
  });

  await step('index and search', () async {
    final run = await IndexRun.start(IndexJob(seeds: [root.path], depth: 6, files: true, wholeDrives: false));
    final idx = SearchIndex(root: root.path);
    await for (final pg in run.progress) {
      pg.lines.forEach(idx.addLine);
    }
    check(idx.length == 12, 'items: ${idx.length}');
    check(idx.search('report notes').hits.single.isFile, 'found the file');
  });

  final pdf = p.join(root.path, '10_Survey', 'Survey Report & Notes (rev 2).pdf');
  await step('copy, keep both, move, rename and undo', () async {
    m.openPanel(p.join(root.path, '10_Survey'));
    final r1 = await paste(
      items: [Item(pdf, false)],
      destination: p.join(root.path, '10_Survey'),
      move: false,
      ask: (n, d) async => (Clash.keepBoth, false),
    );
    check(
      r1.ok == 1 && File(p.join(root.path, '10_Survey', 'Survey Report & Notes (rev 2) (2).pdf')).existsSync(),
      'keep both',
    );
    final r2 = await paste(
      items: [Item(p.join(root.path, '20_Piping'), true)],
      destination: p.join(root.path, '99_Archive'),
      move: true,
      ask: (n, d) async => (Clash.skip, false),
    );
    check(r2.ok == 1 && Directory(p.join(root.path, '99_Archive', '20_Piping')).existsSync(), 'moved');
    await undoStep(r2.undo!, shell.recycle);
    check(Directory(p.join(root.path, '20_Piping')).existsSync(), 'moved back');
    final u = UndoStep('t');
    check(await renameItem(pdf, 'Report.pdf', undo: u) == null, 'renamed');
    check(await renameItem(p.join(root.path, '10_Survey', 'Report.pdf'), 'a|b') != null, 'refused a bad name');
    await undoStep(u, shell.recycle);
    check(File(pdf).existsSync(), 'renamed back');
  });

  await step('a swap in LIST / EDIT', () async {
    final dir = p.join(root.path, '00_Admin');
    Directory(p.join(dir, 'A')).createSync();
    Directory(p.join(dir, 'B')).createSync();
    m.openPanel(dir);
    final plan = planRenames(m.panelEntries(), 'B\r\nA', (n) => Directory(p.join(dir, n)).existsSync());
    final (done, failed, _) = await applyRenames(plan, dir);
    check(done == 2 && failed.isEmpty, 'swapped: $failed');
  });

  await step('delete goes to the Recycle Bin', () async {
    final copy = p.join(root.path, '10_Survey', 'Survey Report & Notes (rev 2) (2).pdf');
    final failed = await shell.recycle([copy]);
    check(failed.isEmpty && !File(copy).existsSync(), 'recycled: $failed');
  });

  await step('settings are saved for next time', () async {
    final again = AppModel(store: store, shell: shell, env: const {})..start();
    check(again.root == root.path && again.title == 'Check', 'reloaded');
    again.dispose();
  });

  m.dispose();
  File(reportPath)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert({'ok': ok, 'steps': steps}));
  return ok;
}
