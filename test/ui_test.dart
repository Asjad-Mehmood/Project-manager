// The window itself: every layout at four window sizes with nothing cut off, and the main jobs
// done with the mouse and the keyboard. With --dart-define=SHOTS=true it also saves pictures of
// the window to docs/screenshots (fonts close to Windows' own: Inter for Segoe UI, JetBrains
// Mono for Consolas).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:project_folder_manager/src/app.dart';
import 'package:project_folder_manager/src/core/indexer.dart';
import 'package:project_folder_manager/src/core/search_index.dart';
import 'package:project_folder_manager/src/ui/widgets.dart';

import 'fakes.dart';

const shots = bool.fromEnvironment('SHOTS');
final _frame = GlobalKey();
final _clock = DateTime(2026, 10, 16, 15, 38, 59);

Future<void> _fonts() async {
  Future<void> load(String family, List<String> files) async {
    final l = FontLoader(family);
    for (final f in files) {
      if (File(f).existsSync()) l.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
    }
    await l.load();
  }

  await load('Segoe UI', ['test/fonts/Inter_400Regular.ttf', 'test/fonts/Inter_700Bold.ttf']);
  await load('Consolas', ['test/fonts/JetBrainsMono_500Medium.ttf', 'test/fonts/JetBrainsMono_700Bold.ttf']);
  final flutter = Platform.environment['FLUTTER_ROOT'] ?? p.dirname(p.dirname(p.dirname(Platform.resolvedExecutable)));
  await load('MaterialIcons', [
    p.join(flutter, 'bin', 'cache', 'artifacts', 'material_fonts', 'MaterialIcons-Regular.otf'),
  ]);
}

Harness _project({bool index = true}) {
  final h = Harness.make(settingsJson: '{"v6Checked": true, "options": {"autoIndex": false}}');
  h.model.start();
  if (Directory(h.root.path).existsSync()) {
    h.model.setRoot(h.root.path);
    h.model.setTitle('North Gas Field');
    Directory(h.at('40_Telecom')).createSync();
    Directory(h.at('60_Utilities/Water')).createSync(recursive: true);
    Directory(h.at('70_Facilities/Buildings')).createSync(recursive: true);
    Directory(h.at('80_Roads/Access Road')).createSync(recursive: true);
    Directory(h.at('90_Design & Drawings/Issued')).createSync(recursive: true);
    for (final f in ['Topo_Survey_2026.dwg', 'Levels.xlsx', 'Site photo 01.jpg', 'Control.kml']) {
      File(h.at('10_Survey/02_Topographic Survey/$f')).writeAsStringSync('x' * (f.length * 9000));
    }
    h.model.scan();
    h.model.project!.modules.sort((a, b) => a.name.compareTo(b.name));
  }
  if (index) {
    final idx = SearchIndex(built: DateTime.now().subtract(const Duration(hours: 2)), root: h.root.path);
    walk(
      IndexJob(seeds: [h.root.path], depth: 6, files: true, wholeDrives: false),
      (pg) => pg.lines.forEach(idx.addLine),
    );
    h.model.index = idx;
  }
  h.model.say('ready');
  return h;
}

Future<void> _show(WidgetTester tester, Harness h, {Size size = const Size(1600, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _frame,
      child: FolderManagerApp(model: h.model, clock: _clock, checkUpdates: false),
    ),
  );
  await tester.pump();
}

Future<void> _shot(WidgetTester tester, String name) async {
  if (!shots) return;
  await tester.pump(const Duration(milliseconds: 300));
  final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(_frame));
  await tester.runAsync(() async {
    final img = await ro.toImage();
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('docs/screenshots/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Finder _btn(String label) => find.widgetWithText(Btn, label);

Future<void> _keys(WidgetTester tester, List<LogicalKeyboardKey> hold, LogicalKeyboardKey key) async {
  for (final k in hold) {
    await tester.sendKeyDownEvent(k);
  }
  await tester.sendKeyEvent(key);
  for (final k in hold.reversed) {
    await tester.sendKeyUpEvent(k);
  }
  await tester.pump();
}

void main() {
  setUpAll(_fonts);

  testWidgets('every layout at four window sizes, nothing cut off', (tester) async {
    final h = _project();
    addTearDown(h.dispose);
    for (final size in const [Size(1920, 1080), Size(1600, 900), Size(1366, 768), Size(1024, 700), Size(800, 600)]) {
      await _show(tester, h, size: size);
      for (var lay = 0; lay < 6; lay++) {
        if (lay > 0 && !h.model.panelOpen) h.model.openPanel(h.at('10_Survey'));
        h.model.setLayout(lay);
        await tester.pump();
        final ex = tester.takeException();
        expect(ex, isNull, reason: '$size layout $lay: $ex');
      }
      h.model.setDrives(true);
      await tester.pump();
      final ex = tester.takeException();
      expect(ex, isNull, reason: '$size with drives: $ex');
      h.model.setDrives(false);
      h.model.setLayout(0);
    }
  });

  testWidgets('the dashboard: modules with disciplines, sub-folders and KPIs; VIEW opens the panel', (tester) async {
    final h = _project();
    addTearDown(h.dispose);
    await _show(tester, h);
    expect(find.text('North Gas Field'), findsOneWidget);
    expect(find.text('15:38:59'), findsOneWidget);
    expect(find.text('Friday, 16 October 2026'), findsOneWidget);
    expect(find.text('10_Survey'), findsOneWidget);
    expect(find.text('Civil Works'), findsWidgets);
    expect(find.text('MODULES'), findsOneWidget);
    await _shot(tester, '1-dashboard');

    await tester.tap(_btn('VIEW').at(1)); // 10_Survey
    await tester.pump();
    expect(h.model.panelPath, h.at('10_Survey'));
    expect(find.text('Survey_Report_Rev2.pdf'), findsOneWidget);
    expect(find.text('PDF'), findsWidgets);

    await tester.tap(find.text('02_Topographic Survey'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('02_Topographic Survey'));
    await tester.pump();
    expect(h.model.panelPath, h.at('10_Survey/02_Topographic Survey')); // double-click goes in
    h.model.setDrives(true);
    await tester.pump();
    await _shot(tester, '2-panel');
    h.model.setDrives(false);

    await _keys(tester, [LogicalKeyboardKey.alt], LogicalKeyboardKey.digit5);
    expect(h.model.layout, 4);
    await _keys(tester, [LogicalKeyboardKey.alt], LogicalKeyboardKey.digit1);
    expect(h.model.panelOpen, isFalse);
  });

  testWidgets('the panel\'s keys: arrows, Ctrl+A, Ctrl+C, Esc, Backspace; Delete and F2 ask first', (tester) async {
    final h = _project();
    addTearDown(h.dispose);
    await _show(tester, h);
    h.model.openPanel(h.at('10_Survey'));
    await tester.pump();
    await _keys(tester, [], LogicalKeyboardKey.arrowDown);
    expect(h.model.focused!.name, '01_Control Points');
    await _keys(tester, [LogicalKeyboardKey.shift], LogicalKeyboardKey.arrowDown);
    expect(h.model.selected, hasLength(2));
    await _keys(tester, [LogicalKeyboardKey.control], LogicalKeyboardKey.keyA);
    expect(h.model.selected, hasLength(4));
    await _keys(tester, [LogicalKeyboardKey.control], LogicalKeyboardKey.keyC);
    expect(h.model.clip, hasLength(4));
    expect(find.text('COPIED'), findsOneWidget);
    await _keys(tester, [], LogicalKeyboardKey.escape);
    expect(h.model.selected, isEmpty);

    await _keys(tester, [], LogicalKeyboardKey.arrowDown);
    await _keys(tester, [], LogicalKeyboardKey.delete);
    expect(find.textContaining('RECYCLE BIN'), findsOneWidget);
    await tester.tap(_btn('CANCEL'));
    await tester.pumpAndSettle();
    expect(Directory(h.at('10_Survey/01_Control Points')).existsSync(), isTrue);

    await _keys(tester, [], LogicalKeyboardKey.f2);
    expect(find.text('RENAME'), findsWidgets);
    await tester.enterText(find.byType(TextField).last, 'a|b');
    await tester.tap(_btn('RENAME').last);
    await tester.pump();
    expect(find.textContaining('doesn\'t allow'), findsOneWidget);
    await tester.tap(_btn('CANCEL'));
    await tester.pumpAndSettle();

    // keys typed in a text box belong to the text, not to the panel
    await tester.enterText(find.byType(TextField).first, 'abc');
    await _keys(tester, [], LogicalKeyboardKey.backspace);
    await _keys(tester, [LogicalKeyboardKey.control], LogicalKeyboardKey.keyA);
    expect(h.model.panelPath, h.at('10_Survey'));
    expect(h.model.selected, hasLength(1)); // Ctrl+A selected the text, not the four items
    await tester.tap(find.text('1 item')); // back to the window
    await tester.pump();
    h.model.setQuery('');

    await _keys(tester, [], LogicalKeyboardKey.backspace);
    expect(h.model.panelPath, h.root.path);
  });

  testWidgets('the discipline chip opens the picker; the title renames the project', (tester) async {
    final h = _project();
    addTearDown(h.dispose);
    await _show(tester, h);
    await tester.tap(find.widgetWithText(DisciplineChip, 'Survey'));
    await tester.pumpAndSettle();
    expect(find.text('Choose the discipline for this folder'), findsOneWidget);
    await _shot(tester, '5-discipline');
    await tester.tap(find.text('HSE'));
    await tester.pumpAndSettle();
    expect(h.model.project!.modules.firstWhere((m) => m.name == '10_Survey').discipline, 'HSE');

    await tester.tap(find.text('North Gas Field'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'South Pipeline');
    await tester.tap(_btn('OK'));
    await tester.pumpAndSettle();
    expect(h.model.title, 'South Pipeline');
  });

  testWidgets('DEEP search lists folders and files from the index, with their discipline', (tester) async {
    final h = _project();
    addTearDown(h.dispose);
    await _show(tester, h);
    await tester.enterText(find.byType(TextField).first, 'survey');
    await tester.pump();
    expect(h.model.showingResults, isTrue);
    expect(find.text('Survey_Report_Rev2.pdf'), findsOneWidget);
    expect(find.text('02_Topographic Survey'), findsOneWidget);
    expect(find.textContaining('match(es)'), findsOneWidget);
    await _shot(tester, '3-search');
    await tester.tap(_btn('FILES'));
    await tester.pump();
    expect(find.text('02_Topographic Survey'), findsNothing);
    await tester.tap(_btn('VIEW').first);
    await tester.pump();
    expect(h.model.panelPath, h.at('10_Survey'));
    expect(h.model.selection().single.name, 'Survey_Report_Rev2.pdf');
  });

  testWidgets('LIST / EDIT shows each rename and each problem before anything changes', (tester) async {
    final h = _project();
    addTearDown(h.dispose);
    await _show(tester, h);
    h.model.openPanel(h.at('10_Survey/02_Topographic Survey'));
    await tester.pump();
    await tester.tap(_btn('LIST / EDIT'));
    await tester.pumpAndSettle();
    expect(find.text('LIST & EDIT'), findsOneWidget);
    await tester.tap(_btn('01_ NUMBER'));
    await tester.pump();
    expect(find.textContaining('4 CHANGE(S)'), findsOneWidget);
    expect(find.textContaining('→  ', findRichText: true), findsNWidgets(4));
    await _shot(tester, '4-list-edit');
    await tester.enterText(find.byType(TextField).last, 'a\nb');
    await tester.pump();
    expect(find.textContaining('LINE COUNT DOES NOT MATCH'), findsOneWidget);
    await tester.tap(_btn('CLOSE'));
    await tester.pumpAndSettle();
    expect(File(h.at('10_Survey/02_Topographic Survey/Control.kml')).existsSync(), isTrue);
  });

  testWidgets('every v6.2 option is still there, in the toolbar\'s menus', (tester) async {
    final h = _project();
    addTearDown(h.dispose);
    await _show(tester, h);
    Future<void> open(Finder f) async {
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    Future<void> close() async {
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    }

    // project: SET / BROWSE / FIND / OPEN ROOT, rename, switch
    await open(find.byTooltip('Switch or open a project'));
    for (final x in [
      'YOUR PROJECTS',
      'Pick its folder ...',
      'Type or paste its path ...',
      'Find projects on my drives ...',
      'Open the root folder in Explorer',
      'Rename the project ...',
    ]) {
      expect(find.text(x), findsOneWidget, reason: x);
    }
    await _shot(tester, '7-menu-project');
    await close();

    // LIST: ALWAYS TREE, MISSING, COLLAPSE, SCAN, FIX NAMES, REBUILD, REFRESH
    await open(find.text('LIST'));
    for (final x in [
      'Always open the whole tree',
      'Hide modules that are missing',
      'Collapse everything',
      'Scan: add new folders',
      'Fix names: follow renamed folders',
      'Rebuild the list from this PC',
      'Refresh from the disk  (F5)',
    ]) {
      expect(find.text(x), findsOneWidget, reason: x);
    }
    await _shot(tester, '8-menu-list');
    await tester.tap(find.text('Always open the whole tree'));
    await tester.pumpAndSettle();
    expect(h.model.options.tree, isTrue);

    // INDEX: the three scopes, STOP, how it is made
    await open(find.text('INDEX'));
    for (final x in [
      'Index this project',
      'Index all drives',
      'Index the project by itself',
      'Files too, not only folders',
    ]) {
      expect(find.text(x), findsOneWidget, reason: x);
    }
    expect(find.textContaining('Index the whole drive'), findsOneWidget);
    await close();

    // GO TO: pins and DRIVES
    await open(find.text('GO TO'));
    expect(find.text('Show the drives strip'), findsOneWidget);
    expect(find.text('D:  Projects'), findsOneWidget);
    await tester.tap(find.text('Show the drives strip'));
    await tester.pumpAndSettle();
    expect(h.model.options.drives, isTrue);

    // VIEW: the six layouts
    await open(find.byType(LayoutPicture).first);
    expect(find.text('Tree above, panel below'), findsOneWidget);
    await tester.tap(find.text('Panel only'));
    await tester.pumpAndSettle();
    expect(h.model.layout, 5);
  });

  testWidgets('with no project: a start page that says what to do', (tester) async {
    final h = Harness.make(settingsJson: '{"v6Checked": true, "options": {"autoIndex": false}}', project: false);
    addTearDown(h.dispose);
    h.model.start();
    await _show(tester, h);
    expect(find.text('Point it at your project folder'), findsOneWidget);
    expect(_btn('BRING IN v6 SETTINGS'), findsOneWidget);
    await _shot(tester, '6-start');
  });
}
