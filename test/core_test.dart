import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:project_folder_manager/src/core/disciplines.dart';
import 'package:project_folder_manager/src/core/disk.dart';
import 'package:project_folder_manager/src/core/format.dart';
import 'package:project_folder_manager/src/core/names.dart';
import 'package:project_folder_manager/src/core/project_finder.dart';
import 'package:project_folder_manager/src/core/settings.dart';

import 'fakes.dart';

void main() {
  group('disciplines', () {
    test('the number guesses the discipline, as v6.2', () {
      expect(guessDiscipline('10_Survey'), 'Survey');
      expect(guessDiscipline('90 Design & Drawings'), 'Design & Drawings');
      expect(guessDiscipline('  99_Archive'), 'Archive');
      expect(guessDiscipline('Photos'), uncategorised);
      expect(guessDiscipline('1'), uncategorised);
    });

    test('the standard folders of a new project', () {
      expect(standardFolderNames(), hasLength(11));
      expect(standardFolderNames().first, '00_Admin');
      expect(standardFolderNames(), contains('90_Design & Drawings'));
      for (final n in standardFolderNames()) {
        expect(nameProblem(n), isNull, reason: n);
      }
    });

    test('file type chips', () {
      expect(extOf('Survey_Report_Rev2.PDF'), 'pdf');
      expect(extOf('.gitignore'), '');
      expect(extOf('README'), '');
      expect(extLabel('README'), 'FILE');
      expect(extLabel('model.backup'), 'BACKU');
      expect(extColor('dwg'), isNotNull);
      expect(extColor('xyz'), isNull);
      expect(disciplineColor('nope'), disciplines[uncategorised]);
    });
  });

  group('format', () {
    test('sizes as v6.2 wrote them', () {
      expect(fileSize(null), '');
      expect(fileSize(512), '512 B');
      expect(fileSize(48 * 1024), '48 KB');
      expect(fileSize(2200000), '2.1 MB');
      expect(fileSize(1500000000), '1.4 GB');
      expect(driveSize(0), '0 GB');
      expect(driveSize(8400000000), '7.8 GB');
      expect(driveSize(80000000000), '75 GB');
      expect(driveSize(2000000000000), '1.8 TB');
    });

    test('clock and date', () {
      final d = DateTime(2026, 10, 16, 15, 38, 59);
      expect(clockText(d), '15:38:59');
      expect(longDate(d), 'Friday, 16 October 2026');
      expect(shortDateTime(d), '16 Oct 2026 15:38');
      expect(ago(d, d.add(const Duration(seconds: 20))), 'just now');
      expect(ago(d, d.add(const Duration(minutes: 5))), '5 min ago');
      expect(ago(d, d.add(const Duration(hours: 3))), '3 h ago');
      expect(ago(d, d.add(const Duration(days: 2))), '2 days ago');
    });

    test('the calendar starts on Sunday', () {
      final oct = monthGrid(2026, 10); // 1 October 2026 is a Thursday
      expect(oct.first, [0, 0, 0, 0, 1, 2, 3]);
      expect(oct.last, [25, 26, 27, 28, 29, 30, 31]);
      expect(oct, hasLength(5));
      final feb = monthGrid(2026, 2); // starts on Sunday, 28 days
      expect(feb, hasLength(4));
      expect(feb.first.first, 1);
    });
  });

  group('names', () {
    test('what Windows refuses', () {
      expect(nameProblem('Survey Report'), isNull);
      expect(nameProblem(''), isNotNull);
      expect(nameProblem('a/b'), contains('character'));
      expect(nameProblem('what?'), contains('character'));
      expect(nameProblem('ends.'), contains('dot'));
      expect(nameProblem(' lead'), contains('space'));
      expect(nameProblem('CON'), contains('reserved'));
      expect(nameProblem('nul.txt'), contains('reserved'));
      expect(nameProblem('Console'), isNull);
      expect(nameProblem('x' * 121), contains('longer'));
    });

    test('keep both picks the first free name', () {
      final taken = {'Report (2).pdf'};
      expect(freeName('Report.pdf', taken.contains), 'Report (3).pdf');
      expect(freeName('Folder', (_) => false), 'Folder (2)');
    });
  });

  group('v6.2 settings', () {
    const v6 =
        'D:\\Project\r\n#PC=SURVEY-PC\r\n#TITLE=North Gas Field\r\n'
        '#OPT=tree:1,deep:0,miss:1,depth:4,files:1,drv:1,lay:3\r\n'
        '00_Admin|Admin\r\n10_Survey|Survey\r\nPhotos\r\n50_Civil Works|HSE\r\n';

    test('are read', () {
      final c = parseV6Config(v6)!;
      expect(c.project.root, 'D:\\Project');
      expect(c.project.pc, 'SURVEY-PC');
      expect(c.project.title, 'North Gas Field');
      expect(
        [for (final m in c.project.modules) '${m.name}|${m.discipline}'],
        ['00_Admin|Admin', '10_Survey|Survey', 'Photos|Uncategorised', '50_Civil Works|HSE'],
      );
      expect(c.options.tree, isTrue);
      expect(c.options.deep, isFalse);
      expect(c.options.hideMissing, isTrue);
      expect(c.options.depth, 4);
      expect(c.options.drives, isTrue);
      expect(c.options.layout, 3);
    });

    test('something else is not', () {
      expect(parseV6Config(''), isNull);
      expect(parseV6Config('#PC=x'), isNull);
    });

    test('v7 settings survive a save and load, and damaged parts are left out', () {
      final s = Settings()
        ..projects.add(Project(root: r'D:\A', title: 'A', modules: [Module('10_Survey', 'Survey')]))
        ..projects.add(Project(root: r'E:\B'))
        ..current = 1
        ..pinned.add(r'D:\A\10_Survey');
      s.options
        ..layout = 4
        ..scope = IndexScope.drive
        ..autoIndex = false;
      final back = Settings.fromJson(s.toJson());
      expect(back.projects, hasLength(2));
      expect(back.current, 1);
      expect(back.project!.root, r'E:\B');
      expect(back.projects.first.modules.single.discipline, 'Survey');
      expect(back.options.layout, 4);
      expect(back.options.scope, IndexScope.drive);
      expect(back.options.autoIndex, isFalse);
      expect(back.pinned, [r'D:\A\10_Survey']);

      final damaged = Settings.fromJson({
        'projects': [
          {
            'root': r'D:\A',
            'modules': [
              'bad',
              ['10_Survey'],
              7,
            ],
          },
          'nonsense',
        ],
        'current': 9,
        'options': {'lay': 99, 'depth': -2},
      });
      expect(damaged.projects.single.modules.single.discipline, 'Survey');
      expect(damaged.current, 0);
      expect(damaged.options.layout, 5);
      expect(damaged.options.depth, 1);
      expect(Settings.fromJson('x').projects, isEmpty);
    });
  });

  group('disk', () {
    late Directory base;
    setUp(() => base = Directory.systemTemp.createTempSync('pfm-disk'));
    tearDown(() => base.deleteSync(recursive: true));

    test('folders first, then files, A to Z ignoring case; sizes and dates', () {
      final root = makeProject(base);
      final e = readFolder(p.join(root.path, '10_Survey'));
      expect(
        [for (final x in e) x.name],
        ['01_Control Points', '02_Topographic Survey', '03_As-Built', 'Survey_Report_Rev2.pdf'],
      );
      expect(e.last.size, 2000);
      expect(e.last.modified, isNotNull);
      expect(readFolder(p.join(root.path, 'nope')), isEmpty);
    });

    test('path keys and inside', () {
      expect(pathKey('/a/B/'), pathKey('/a/b'));
      expect(isSameOrInside('/a/b/c', '/a/b'), isTrue);
      expect(isSameOrInside('/a/bc', '/a/b'), isFalse);
      expect(isSameOrInside('/a/b', '/a/b'), isTrue);
    });

    test('the cache reads once until told to forget', () {
      final root = makeProject(base);
      final c = FolderCache();
      expect(c.folderCount(p.join(root.path, '00_Admin')), 2);
      Directory(p.join(root.path, '00_Admin', 'New')).createSync();
      expect(c.folderCount(p.join(root.path, '00_Admin')), 2);
      c.forget(p.join(root.path, '00_Admin'));
      expect(c.folderCount(p.join(root.path, '00_Admin')), 3);
    });

    test('FIND finds folders that hold numbered modules', () async {
      makeProject(base, name: 'Job A');
      Directory(p.join(base.path, 'Deeper', 'Job B', '00_Admin')).createSync(recursive: true);
      Directory(p.join(base.path, 'Deeper', 'Job B', '10 Survey')).createSync();
      Directory(p.join(base.path, 'Deeper', 'Job B', '20-Piping')).createSync();
      Directory(p.join(base.path, 'Photos', '2024')).createSync(recursive: true);
      Directory(p.join(base.path, '04_Old Layout')).createSync();
      final found = await findProjects([base.path]);
      expect([for (final c in found) p.basename(c.path)], ['Job A', 'Job B', '04_Old Layout']);
      expect(found.first.modules, 6);
    });
  });
}
