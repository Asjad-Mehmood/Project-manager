import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:project_folder_manager/src/core/bulk_rename.dart';
import 'package:project_folder_manager/src/core/disk.dart';
import 'package:project_folder_manager/src/core/file_ops.dart';
import 'package:project_folder_manager/src/core/indexer.dart';
import 'package:project_folder_manager/src/core/search_index.dart';

import 'fakes.dart';

void main() {
  late Directory base;
  late Directory root;
  setUp(() {
    base = Directory.systemTemp.createTempSync('pfm-ops');
    root = makeProject(base);
  });
  tearDown(() => base.deleteSync(recursive: true));
  String at(String rel) => p.join(root.path, rel);

  group('index', () {
    test('reads v6.2\'s index file', () {
      final idx = SearchIndex.parse('project\r\nF\tD:\\P\\10_Survey\r\nX\tD:\\P\\10_Survey\\a.pdf\r\njunk\r\n');
      expect(idx.length, 2);
      expect(idx.scope, 'project');
      expect(idx.built, isNull);
    });

    test('v7 file round trip, with when and for which project', () {
      final idx = SearchIndex(scope: 'D:\\', built: DateTime.utc(2026, 11, 2, 9), root: r'D:\P')
        ..add(r'D:\P\a', false)
        ..add(r'D:\P\a\b.dwg', true);
      final back = SearchIndex.parse(idx.serialize());
      expect(back.length, 2);
      expect(back.scope, 'D:\\');
      expect(back.built, DateTime.utc(2026, 11, 2, 9));
      expect(back.root, r'D:\P');
      expect(back.scopeName, 'drive D:');
    });

    SearchIndex sample() => SearchIndex()
      ..add('/p/10_Survey', false)
      ..add('/p/10_Survey/survey.pdf', true)
      ..add('/p/10_Survey/Old Survey Notes.txt', true)
      ..add('/p/20_Piping/as-built survey.dwg', true)
      ..add('/p/20_Piping', false)
      ..add('/p/20_Piping/Isometrics', false);

    test('every word must match; exact name first, then names that start with it', () {
      final r = sample().search('survey');
      expect(r.total, 4);
      expect(
        [for (final h in r.hits) h.name],
        [
          'survey.pdf', // starts with "survey"
          '10_Survey',
          'Old Survey Notes.txt',
          'as-built survey.dwg',
        ],
      );
      expect(sample().search('survey.pdf').hits.first.name, 'survey.pdf'); // the exact name
      expect(sample().search('survey notes').hits.single.name, 'Old Survey Notes.txt');
      expect(sample().search('  ').total, 0);
    });

    test('folders only, files only, one type, a limit, and a filter by place', () {
      final s = sample();
      expect(s.search('survey', kind: Kind.folders).hits.single.name, '10_Survey');
      expect(s.search('survey', kind: Kind.files).total, 3);
      expect(s.search('survey', type: 'dwg').hits.single.name, 'as-built survey.dwg');
      final lim = s.search('survey', limit: 2);
      expect(lim.hits, hasLength(2));
      expect(lim.total, 4);
      expect(s.search('survey', where: (x) => x.startsWith('/p/20')).total, 1);
    });

    test('renames, moves and deletes made in the program keep the index right', () {
      final s = sample()..moved('/p/10_Survey', '/p/11_Survey');
      expect(s.search('11_survey').total, 1);
      expect(s.contains('/p/11_Survey/survey.pdf'), isTrue);
      expect(s.contains('/p/10_Survey/survey.pdf'), isFalse);
      s.removed('/p/20_Piping');
      expect(s.length, 3);
    });

    test('the walk reads shallow levels first, honours the depth and can leave files out', () {
      final lines = <String>[];
      var done = false;
      walk(IndexJob(seeds: [root.path], depth: 6, files: true, wholeDrives: false), (pg) {
        lines.addAll(pg.lines);
        done = pg.done;
      }, every: Duration.zero);
      expect(done, isTrue);
      expect(lines.first, startsWith('F\t'));
      expect(lines.where((l) => l.startsWith('X\t')), hasLength(3));
      expect(lines, contains('F\t${at('10_Survey')}'));

      final shallow = <String>[];
      walk(IndexJob(seeds: [root.path], depth: 1, files: false, wholeDrives: false), (pg) => shallow.addAll(pg.lines));
      expect(shallow, hasLength(6)); // just the modules
    });

    test('a drive-wide index skips Windows\' own folders at the top', () {
      Directory(p.join(base.path, 'Windows', 'System32')).createSync(recursive: true);
      final lines = <String>[];
      walk(IndexJob(seeds: [base.path], depth: 3, files: false, wholeDrives: true), (pg) => lines.addAll(pg.lines));
      expect(lines.any((l) => l.contains('System32')), isFalse);
      expect(lines.any((l) => l.endsWith('Project')), isTrue);
    });

    test('in the background: progress arrives and the run ends', () async {
      final run = await IndexRun.start(IndexJob(seeds: [root.path], depth: 6, files: true, wholeDrives: false));
      final got = await run.progress.toList();
      expect(got.last.done, isTrue);
      expect(got.expand((g) => g.lines).length, greaterThan(15));
    });

    test('STOP ends the run', () async {
      final run = await IndexRun.start(IndexJob(seeds: [base.path], depth: 30, files: true, wholeDrives: false));
      run.stop();
      await run.progress.toList(); // finishes
      expect(run.stopped, isTrue);
    });
  });

  group('copy, move and the clash question', () {
    Future<(Clash, bool)> never(String n, String d) async => fail('asked about $n');

    test('copy a folder and a file', () async {
      final dst = at('99_Archive');
      final r = await paste(
        items: [Item(at('10_Survey/01_Control Points'), true), Item(at('10_Survey/Survey_Report_Rev2.pdf'), false)],
        destination: dst,
        move: false,
        ask: never,
      );
      expect(r.ok, 2);
      expect(File(p.join(dst, '01_Control Points', 'CP_list.csv')).existsSync(), isTrue);
      expect(File(at('10_Survey/Survey_Report_Rev2.pdf')).existsSync(), isTrue);
      expect(r.undo!.created, hasLength(2));
    });

    test('move, then UNDO puts it back', () async {
      final r = await paste(
        items: [Item(at('20_Piping/Isometrics'), true)],
        destination: at('99_Archive'),
        move: true,
        ask: never,
      );
      expect(r.ok, 1);
      expect(Directory(at('99_Archive/Isometrics')).existsSync(), isTrue);
      expect(Directory(at('20_Piping/Isometrics')).existsSync(), isFalse);
      final failed = await undoStep(r.undo!, (_) async => const []);
      expect(failed, isEmpty);
      expect(File(at('20_Piping/Isometrics/ISO-001.dwg')).existsSync(), isTrue);
    });

    test('a clash asks; keep both, skip, replace for all, cancel', () async {
      final asked = <String>[];
      final src = at('10_Survey/Survey_Report_Rev2.pdf');
      final dst = at('10_Survey');
      var r = await paste(
        items: [Item(src, false)],
        destination: dst,
        move: false,
        ask: (n, d) async {
          asked.add(n);
          return (Clash.keepBoth, false);
        },
      );
      expect(asked, ['Survey_Report_Rev2.pdf']);
      expect(File(p.join(dst, 'Survey_Report_Rev2 (2).pdf')).existsSync(), isTrue);

      r = await paste(
        items: [Item(src, false)],
        destination: dst,
        move: false,
        ask: (n, d) async => (Clash.skip, false),
      );
      expect(r.skipped, 1);

      // replace, for every remaining clash: asked once for two items
      File(at('99_Archive/a.txt')).writeAsStringSync('old');
      File(at('99_Archive/b.txt')).writeAsStringSync('old');
      File(at('00_Admin/a.txt')).writeAsStringSync('new');
      File(at('00_Admin/b.txt')).writeAsStringSync('new');
      var asks = 0;
      r = await paste(
        items: [Item(at('00_Admin/a.txt'), false), Item(at('00_Admin/b.txt'), false)],
        destination: at('99_Archive'),
        move: false,
        ask: (n, d) async {
          asks++;
          return (Clash.replace, true);
        },
      );
      expect(asks, 1);
      expect(r.ok, 2);
      expect(File(at('99_Archive/b.txt')).readAsStringSync(), 'new');

      r = await paste(
        items: [Item(at('00_Admin/a.txt'), false)],
        destination: at('99_Archive'),
        move: false,
        ask: (n, d) async => (Clash.cancel, false),
      );
      expect(r.cancelled, isTrue);
      expect(r.ok, 0);
    });

    test('moving a folder onto one with its name merges them', () async {
      Directory(at('99_Archive/Isometrics')).createSync();
      File(at('99_Archive/Isometrics/old.dwg')).writeAsStringSync('old');
      final r = await paste(
        items: [Item(at('20_Piping/Isometrics'), true)],
        destination: at('99_Archive'),
        move: true,
        ask: (n, d) async => (Clash.replace, false),
      );
      expect(r.ok, 1);
      expect(File(at('99_Archive/Isometrics/old.dwg')).existsSync(), isTrue);
      expect(File(at('99_Archive/Isometrics/ISO-001.dwg')).existsSync(), isTrue);
      expect(Directory(at('20_Piping/Isometrics')).existsSync(), isFalse);
    });

    test('what PASTE refuses before it starts', () {
      expect(pasteProblem([], at('00_Admin'), move: false), contains('empty'));
      expect(pasteProblem([Item(at('10_Survey'), true)], at('10_Survey/03_As-Built'), move: false), contains('itself'));
      expect(pasteProblem([Item(at('10_Survey/03_As-Built'), true)], at('10_Survey'), move: true), contains('already'));
      expect(pasteProblem([Item(at('10_Survey'), true)], at('nope'), move: false), contains('destination'));
      expect(pasteProblem([Item(at('10_Survey/03_As-Built'), true)], at('00_Admin'), move: true), isNull);
    });

    test('CANCEL stops between files', () async {
      var n = 0;
      final r = await paste(
        items: [Item(at('10_Survey'), true)],
        destination: at('99_Archive'),
        move: false,
        ask: never,
        cancelled: () => ++n > 2,
      );
      expect(r.cancelled, isTrue);
    });

    test('rename, new folder and their UNDO', () async {
      final undo = UndoStep('t');
      expect(await renameItem(at('00_Admin/Minutes'), 'Meeting Minutes', undo: undo), isNull);
      expect(Directory(at('00_Admin/Meeting Minutes')).existsSync(), isTrue);
      expect(await renameItem(at('00_Admin/Contracts'), 'Meeting Minutes'), contains('already'));
      expect(await renameItem(at('00_Admin/Contracts'), 'a:b'), contains('character'));
      expect(await renameItem(at('00_Admin/Contracts'), 'contracts'), isNull); // only the case
      final made = await newFolder(at('00_Admin'), 'Drawings');
      undo.created.add(made);
      expect(() => newFolder(at('00_Admin'), 'Drawings'), throwsA(isA<FileSystemException>()));
      final removed = <String>[];
      await undoStep(undo, (paths) async {
        removed.addAll(paths);
        return const [];
      });
      expect(Directory(at('00_Admin/Minutes')).existsSync(), isTrue);
      expect(removed, [made]);
    });
  });

  group('LIST / EDIT', () {
    List<Entry> listed() => readFolder(at('10_Survey'));
    bool exists(String n) => anyExists(at('10_Survey/$n'));

    test('the same checks as v6.2', () {
      final names = [for (final e in listed()) e.name];
      expect(planRenames(listed(), names.take(2).join('\n'), exists).countProblem, isNotNull);
      final bad = [...names]..[0] = 'a|b';
      expect(planRenames(listed(), bad.join('\r\n'), exists).problems.single.$2, contains('character'));
      final twice = [...names]..[1] = names[0];
      expect(planRenames(listed(), twice.join('\n'), exists).problems.map((x) => x.$2), contains('appears twice'));
      final none = planRenames(listed(), '${names.join('\n')}\n\n', exists);
      expect(none.ok, isTrue);
      expect(none.changes, isEmpty);
    });

    test('swaps work through temporary names; UNDO puts them back', () async {
      final names = [for (final e in listed()) e.name];
      final swapped = [...names]
        ..[0] = names[1]
        ..[1] = names[0];
      final plan = planRenames(listed(), swapped.join('\n'), exists);
      expect(plan.ok, isTrue, reason: '${plan.problems}');
      expect(plan.changes, hasLength(2));
      final (done, failed, undo) = await applyRenames(plan, at('10_Survey'));
      expect(failed, isEmpty);
      expect(done, 2);
      expect(File(at('10_Survey/02_Topographic Survey/CP_list.csv')).existsSync(), isTrue);
      await undoStep(undo, (_) async => const []);
      expect(File(at('10_Survey/01_Control Points/CP_list.csv')).existsSync(), isTrue);
    });

    test('a new name already on the disk is refused', () {
      final names = [for (final e in listed()) e.name];
      final clash = [...names]..[0] = 'Survey_Report_Rev2.pdf';
      final plan = planRenames(listed(), clash.join('\n'), exists);
      expect(plan.ok, isFalse);
    });

    test('quick tools', () {
      const l = ['survey report.pdf', 'Old Notes', 'cp list.csv'];
      expect(findReplace(l, 'SURVEY', 'Topo'), ['Topo report.pdf', 'Old Notes', 'cp list.csv']);
      expect(findReplace(l, 'SURVEY', 'Topo', matchCase: true), l);
      expect(addText(l, before: 'A_', after: '_rev1'), [
        'A_survey report_rev1.pdf',
        'A_Old Notes_rev1',
        'A_cp list_rev1.csv',
      ]);
      expect(number(l, start: 5, step: 5), ['05_survey report.pdf', '10_Old Notes', '15_cp list.csv']);
      expect(number(l, atStart: false, digits: 3, separator: '-'), [
        'survey report-001.pdf',
        'Old Notes-002',
        'cp list-003.csv',
      ]);
      expect(changeCase(l, CaseChange.title), ['Survey Report.pdf', 'Old Notes', 'Cp List.csv']);
      expect(changeCase(l, CaseChange.upper), ['SURVEY REPORT.pdf', 'OLD NOTES', 'CP LIST.csv']);
      expect(changeCase(l, CaseChange.lower, keepExt: false).last, 'cp list.csv');
      expect(swapSpaces(l).first, 'survey_report.pdf');
      expect(swapSpaces(['a_b'], toUnderscore: false), ['a b']);
    });
  });
}
