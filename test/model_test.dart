import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:project_folder_manager/src/core/bulk_rename.dart';
import 'package:project_folder_manager/src/core/file_ops.dart';
import 'package:project_folder_manager/src/core/search_index.dart';
import 'package:project_folder_manager/src/state/app_model.dart';

import 'fakes.dart';

const noAutoIndex = '{"v6Checked": true, "options": {"autoIndex": false}}';

void main() {
  late Harness h;
  tearDown(() => h.dispose());

  AppModel started({String settings = noAutoIndex}) {
    h = Harness.make(settingsJson: settings);
    return h.model..start();
  }

  test('a new setup opens nothing and offers a 6.2 copy\'s settings, which can be brought in', () {
    h = Harness.make();
    final home = p.join(h.base.path, 'home');
    final old = Directory(p.join(home, 'Desktop', 'Project Folder Manager'))..createSync(recursive: true);
    final cfg = File(p.join(old.path, 'Project_Folder_Manager_config.txt'))
      ..writeAsStringSync(
        '${h.root.path}\n#PC=PC-1\n#TITLE=North Field\n#OPT=tree:0,deep:1,miss:0,depth:6,files:1,drv:0,lay:4\n'
        '00_Admin|Admin\n10_Survey|HSE\n',
      );
    final m = h.model..start();
    expect(m.project, isNull, reason: 'the start page asks for a drive or a folder');
    expect(m.v6File?.path, cfg.path);
    expect(m.importV6(cfg.path), isNull);
    expect(m.root, h.root.path);
    expect(m.title, 'North Field');
    expect(m.options.layout, 4);
    expect(m.modules.firstWhere((x) => x.name == '10_Survey').discipline, 'HSE');
    // saved: a second start opens it again
    final again = AppModel(store: h.store, shell: h.shell, env: const {})..start();
    expect(again.title, 'North Field');
    again.dispose();
  });

  test('a folder opens; its folders come from the disk with guessed disciplines', () {
    final m = started();
    expect(m.project, isNull);
    expect(m.setRoot(p.join(h.base.path, 'nope')), contains('does not exist'));
    expect(m.setRoot(h.root.path), isNull);
    expect(
      [for (final x in m.modules) x.name],
      ['00_Admin', '10_Survey', '20_Piping', '30_Electrical', '50_Civil Works', '99_Archive'],
    );
    expect(m.modules[4].discipline, 'Civil Works');
    expect(m.title, 'Project', reason: 'the folder\'s own name');
    m.setTitle('  North Field ');
    expect(m.title, 'North Field');
  });

  test('several projects: switch, and take one off the list', () {
    final m = started();
    final other = makeProject(h.base, name: 'Other');
    m.setRoot(h.root.path);
    m.setRoot(other.path);
    expect(m.settings.projects, hasLength(2));
    expect(m.root, other.path);
    m.switchProject(0);
    expect(m.root, h.root.path);
    m.setRoot(other.path); // already on the list: switches, no duplicate
    expect(m.settings.projects, hasLength(2));
    m.forgetProject(1);
    expect(m.settings.projects, hasLength(1));
    expect(m.root, h.root.path);
    expect(Directory(other.path).existsSync(), isTrue);
  });

  test('the list follows the disk by itself: nothing to scan or rebuild', () async {
    h = Harness.make();
    final json =
        '{"options": {"autoIndex": false}, "projects": [{"root": ${_q(h.root.path)}, "pc": "OLD-PC", '
        '"modules": [["10_Survey", "HSE"], ["Gone", "Admin"]]}]}';
    Directory(h.store.settingsDir).createSync(recursive: true);
    File(p.join(h.store.settingsDir, 'settings.json')).writeAsStringSync(json);
    final m = h.model..start();
    expect(m.modules, hasLength(6), reason: 'only what is on the disk');
    expect(m.modules.firstWhere((x) => x.name == '10_Survey').discipline, 'HSE', reason: 'a chosen discipline is kept');
    expect(m.project!.pc, 'PC-1');

    // made, renamed and deleted in Explorer
    Directory(h.at('40_Telecom')).createSync();
    Directory(h.at('20_Piping')).renameSync(h.at('20 Pipelines'));
    Directory(h.at('99_Archive')).deleteSync(recursive: true);
    var told = 0;
    m.addListener(() => told++);
    expect(m.checkDisk(), isTrue);
    expect(told, 1);
    expect(
      [for (final x in m.modules) x.name],
      ['00_Admin', '10_Survey', '20 Pipelines', '30_Electrical', '40_Telecom', '50_Civil Works'],
    );
    expect(m.modules.firstWhere((x) => x.name == '40_Telecom').discipline, 'Telecom');
    expect(m.checkDisk(), isFalse, reason: 'nothing changed since');

    // a discipline chosen for a folder that wasn't chosen before is remembered
    m.setDiscipline('40_Telecom', 'HSE');
    expect(m.modules.firstWhere((x) => x.name == '40_Telecom').discipline, 'HSE');

    final empty = Directory(p.join(h.base.path, 'Empty'))..createSync();
    m.setRoot(empty.path);
    expect(m.modules, isEmpty);
    expect(await m.createStandardFolders(), isEmpty);
    expect(m.modules, hasLength(11));
    expect(m.modules.last.name, '99_Archive');
  });

  test('at the top of a drive, Windows\' own folders are left out', () {
    h = Harness.make();
    expect(shownAtTop(r'$RECYCLE.BIN', atDrive: true), isFalse);
    expect(shownAtTop('System Volume Information', atDrive: true), isFalse);
    expect(shownAtTop('Projects', atDrive: true), isTrue);
    expect(shownAtTop('System Volume Information', atDrive: false), isTrue, reason: 'inside a folder, all show');
  });

  test('folder filters: search and discipline', () {
    final m = started()..setRoot(h.root.path);
    m.setQuery('surv');
    expect(m.moduleRows().single.module.name, '10_Survey');
    m.setQuery('');
    m.filterDiscipline('Piping');
    expect(m.moduleRows().single.module.name, '20_Piping');
    m.filterDiscipline('');
    expect(m.moduleRows(), hasLength(6));
    expect(m.moduleRows().first.subCount, 2);
  });

  test('the tree opens three levels with ALWAYS TREE and closes with COLLAPSE', () {
    final m = started()..setRoot(h.root.path);
    m.setTree(true);
    expect(m.isOpen(h.at('10_Survey')), isTrue);
    expect(m.isOpen(h.at('10_Survey/01_Control Points')), isTrue);
    m.collapseAll();
    expect(m.isOpen(h.at('10_Survey')), isFalse);
    expect(m.options.tree, isFalse);
    m.toggleOpen(h.at('20_Piping'));
    expect(m.isOpen(h.at('20_Piping')), isTrue);
  });

  test('INDEX in the background, then DEEP search with the discipline filter; the index is kept', () async {
    final m = started()..setRoot(h.root.path);
    expect(await m.startIndex(), isNull);
    expect(m.indexing, isTrue);
    await _until(() => !m.indexing);
    expect(m.index.length, greaterThan(15));
    expect(m.index.built, isNotNull);
    m.setQuery('iso');
    expect(m.showingResults, isTrue);
    expect(m.results().hits.map((x) => x.name), containsAll(['Isometrics', 'ISO-001.dwg']));
    m.filterDiscipline('Survey');
    expect(m.results().total, 0);
    m.filterDiscipline('Piping');
    expect(m.results().total, 2);
    m.setDeep(false);
    expect(m.showingResults, isFalse);
    expect(m.disciplineOf(h.at('20_Piping/Isometrics/ISO-001.dwg')), 'Piping');

    // kept on disk for next time
    expect(h.store.loadIndex(h.root.path)!.length, m.index.length);
    expect(m.indexIsStale, isFalse);
  });

  test('the project indexes itself when its index is missing (auto index on)', () async {
    h = Harness.make(settingsJson: '{"v6Checked": true}');
    final m = h.model..start();
    m.setRoot(h.root.path);
    await _until(() => !m.index.isEmpty && !m.indexing);
    expect(m.index.scope, 'project');
  });

  test('an old index is made again; a drive index is left alone', () {
    var now = DateTime(2026, 11, 2, 9);
    h = Harness.make(settingsJson: noAutoIndex);
    final m = AppModel(store: h.store, shell: h.shell, clock: () => now, env: const {})..start();
    m.setRoot(h.root.path);
    m.index = SearchIndex(built: now, root: h.root.path)..add(h.at('a'), false);
    expect(m.indexIsStale, isFalse);
    now = now.add(const Duration(hours: 13));
    expect(m.indexIsStale, isTrue);
    m.index = SearchIndex(scope: 'D:\\', built: DateTime(2020))..add('x', false);
    expect(m.indexIsStale, isFalse);
    m.dispose();
  });

  test('the panel: VIEW, UP, BACK, FORWARD, filters, sort, the six layouts', () {
    final m = started()..setRoot(h.root.path);
    expect(m.layout, 0);
    expect(m.openPanel(h.at('nope')), contains('not found'));
    m.openPanel(h.at('10_Survey'));
    expect(m.layout, 2);
    expect(m.panelEntries().map((e) => e.name), contains('Survey_Report_Rev2.pdf'));
    expect(m.panelCounts, (3, 1));
    expect(m.panelTypes(), ['PDF']);
    m.openPanel(h.at('10_Survey/01_Control Points'));
    m.panelUp();
    expect(m.panelPath, h.at('10_Survey'));
    expect(m.highlight, '01_control points');
    m.panelBack();
    expect(m.panelPath, h.at('10_Survey/01_Control Points'));
    m.panelForward();
    expect(m.panelPath, h.at('10_Survey'));

    m.setShow(Show.files);
    expect(m.panelEntries().single.name, 'Survey_Report_Rev2.pdf');
    m.setShow(Show.all);
    m.setPanelFilter('topo');
    expect(m.panelEntries().single.name, '02_Topographic Survey');
    m.setPanelFilter('');
    m.setSort(SortBy.name);
    expect(m.sortDown, isTrue);
    expect(m.panelEntries().first.name, '03_As-Built'); // folders still first, Z to A

    m.setLayout(5);
    expect(m.layout, 5);
    m.setLayout(0);
    expect(m.panelOpen, isFalse);
    m.setLayout(3);
    expect(m.panelOpen, isTrue);
    expect(m.options.layout, 3);
    m.showFile(h.at('10_Survey/Survey_Report_Rev2.pdf'));
    expect(m.selection().single.name, 'Survey_Report_Rev2.pdf');
  });

  test('selection: click, Ctrl+click, Shift+click, arrows, all, none', () {
    final m = started()..setRoot(h.root.path);
    m.openPanel(h.at('10_Survey'));
    final e = m.panelEntries();
    m.click(e[0]);
    m.click(e[2], shift: true);
    expect(m.selection(), hasLength(3));
    m.click(e[1], ctrl: true);
    expect(m.selection().map((x) => x.name), ['01_Control Points', '03_As-Built']);
    m.click(e[3]);
    expect(m.selection().single, e[3]);
    m.moveSelection(-1);
    expect(m.focused!.name, '03_As-Built');
    m.moveSelection(-1, shift: true);
    expect(m.selection(), hasLength(2));
    m.selectAll();
    expect(m.selection(), hasLength(4));
    m.selectNone();
    expect(m.selection(), isEmpty);
  });

  test('COPY, CUT, PASTE with UNDO; the index and the clipboard follow', () async {
    final m = started()..setRoot(h.root.path);
    m.index = SearchIndex(root: h.root.path)
      ..add(h.at('20_Piping/Isometrics'), false)
      ..add(h.at('20_Piping/Isometrics/ISO-001.dwg'), true);
    m.openPanel(h.at('20_Piping'));
    m.click(m.panelEntries().firstWhere((x) => x.name == 'Isometrics'));
    expect(m.copySelection(cut: true), isTrue);
    expect(m.isCut(m.panelEntries().first), isTrue);
    expect(m.pasteCheck(), contains('already'));
    m.openPanel(h.at('99_Archive'));
    final r = await m.pasteHere((n, d) async => (Clash.skip, false));
    expect(r.ok, 1);
    expect(m.clip, isEmpty);
    expect(Directory(h.at('99_Archive/Isometrics')).existsSync(), isTrue);
    expect(m.index.contains(h.at('99_Archive/Isometrics/ISO-001.dwg')), isTrue);
    expect(m.lastUndo, isNotNull);
    await m.undo();
    expect(Directory(h.at('20_Piping/Isometrics')).existsSync(), isTrue);
    expect(m.index.contains(h.at('20_Piping/Isometrics/ISO-001.dwg')), isTrue);

    // copy twice into the same folder: keep both
    m.openPanel(h.at('10_Survey'));
    m.click(m.panelEntries().last);
    m.copySelection(cut: false);
    await m.pasteHere((n, d) async => (Clash.keepBoth, false));
    expect(File(h.at('10_Survey/Survey_Report_Rev2 (2).pdf')).existsSync(), isTrue);
    expect(m.clip, isNotEmpty); // a copy can be pasted again
    await m.undo(); // the copy goes to the (fake) Recycle Bin
    expect(File(h.at('10_Survey/Survey_Report_Rev2 (2).pdf')).existsSync(), isFalse);
    expect(h.shell.recycled.single, endsWith('Survey_Report_Rev2 (2).pdf'));
  });

  test('renaming a module\'s folder in the panel keeps it in the list; UNDO renames it back', () async {
    final m = started()..setRoot(h.root.path);
    m.openPanel(h.root.path);
    final e = m.panelEntries().firstWhere((x) => x.name == '20_Piping');
    expect(await m.rename(e, 'a:b'), contains('character'));
    expect(await m.rename(e, '20_Pipelines'), isNull);
    expect(m.modules.map((x) => x.name), contains('20_Pipelines'));
    expect(m.modules.firstWhere((x) => x.name == '20_Pipelines').discipline, 'Piping');
    await m.undo();
    expect(m.modules.map((x) => x.name), contains('20_Piping'));

    // a chosen discipline goes with the folder when it is renamed here
    m.setDiscipline('30_Electrical', 'HSE');
    m.openPanel(h.root.path);
    await m.rename(m.panelEntries().firstWhere((x) => x.name == '30_Electrical'), '30_Power');
    expect(m.modules.firstWhere((x) => x.name == '30_Power').discipline, 'HSE');
  });

  test('new folder, delete to the Recycle Bin, LIST / EDIT through the model', () async {
    final m = started()..setRoot(h.root.path);
    m.openPanel(h.at('00_Admin'));
    expect(await m.makeFolder('Letters'), isNull);
    expect(m.selection().single.name, 'Letters');
    expect(await m.makeFolder('Letters'), contains('already'));
    expect(await m.deleteItems(m.selection()), isEmpty);
    expect(Directory(h.at('00_Admin/Letters')).existsSync(), isFalse);

    final listed = m.panelEntries();
    final plan = planRenames(listed, number([for (final e in listed) e.name]).join('\n'), (n) => false);
    final (done, failed) = await m.applyBulk(plan);
    expect(failed, isEmpty);
    expect(done, 2);
    expect(Directory(h.at('00_Admin/01_Contracts')).existsSync(), isTrue);
    await m.undo();
    expect(Directory(h.at('00_Admin/Contracts')).existsSync(), isTrue);
  });

  test('pins, opening in Windows, properties', () async {
    final m = started()..setRoot(h.root.path);
    m.togglePin(h.at('10_Survey'));
    expect(m.isPinned(h.at('10_Survey')), isTrue);
    m.togglePin(h.at('10_Survey'));
    expect(m.settings.pinned, isEmpty);
    expect(await m.openInWindows(h.at('10_Survey')), isTrue);
    h.shell.fileOpens = false;
    expect(await m.openInWindows(h.at('10_Survey/Survey_Report_Rev2.pdf')), isFalse);
    final (bytes, files, folders) = await AppModel.measure(h.at('10_Survey'));
    expect(bytes, greaterThan(2000));
    expect(files, 2);
    expect(folders, 3);
    m.setDrives(true);
    expect(m.drives, hasLength(3));
  });
}

String _q(String s) => '"${s.replaceAll(r'\', r'\\')}"';

Future<void> _until(bool Function() done) async {
  final sw = Stopwatch()..start();
  while (!done()) {
    if (sw.elapsed > const Duration(seconds: 20)) fail('timed out');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
