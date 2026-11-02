// Everything the window shows and does, in one place: the projects and their modules, the tree,
// the search and its index, the side panel (folder, filters, selection, clipboard), copy / move /
// rename / delete with UNDO, and the switches v6.2 kept in its settings file.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../core/bulk_rename.dart';
import '../core/disciplines.dart';
import '../core/disk.dart';
import '../core/file_ops.dart';
import '../core/indexer.dart';
import '../core/modules.dart';
import '../core/search_index.dart';
import '../core/settings.dart';
import '../platform/shell.dart';
import 'store.dart';

/// The index is made again by itself when it is older than this (with "auto index" on)
const staleAfter = Duration(hours: 12);

enum Show {
  all('Folders + files'),
  folders('Folders only'),
  files('Files only');

  const Show(this.label);
  final String label;
}

enum SortBy {
  name('Name'),
  type('Type'),
  size('Size'),
  date('Date modified');

  const SortBy(this.label);
  final String label;
}

/// One module in the list, with what the disk says about it
class ModuleRow {
  const ModuleRow(this.number, this.module, this.path, this.exists, this.subCount);
  final int number;
  final Module module;
  final String path;
  final bool exists;
  final int subCount;
}

/// The layouts: 0 tree only, 1 tree wide, 2 side by side, 3 panel wide, 4 above/below, 5 panel only
const layoutNames = [
  'Tree only',
  'Tree wide, panel narrow',
  'Side by side',
  'Tree narrow, panel wide',
  'Tree above, panel below',
  'Panel only',
];

class AppModel extends ChangeNotifier {
  AppModel({required this.store, required this.shell, DateTime Function()? clock, this.env})
    : now = clock ?? DateTime.now;

  final Store store;
  final Shell shell;
  final DateTime Function() now;

  /// Environment for finding v6.2's settings (tests pass their own)
  final Map<String, String>? env;

  late Settings settings;
  final cache = FolderCache();
  SearchIndex index = SearchIndex();

  String status = 'ready';

  // ---------------------------------------------------------------- start

  /// Loads the settings; on the very first start, brings in a v6.2 copy's settings if one is found
  void start() {
    final loaded = store.loadSettings();
    settings = loaded ?? Settings();
    if (!settings.v6Checked) {
      settings.v6Checked = true;
      if (settings.projects.isEmpty) {
        for (final f in findV6Configs(env ?? Platform.environment)) {
          if (importV6(f.path) == null) break;
        }
      }
      _save();
    }
    _openCurrent();
  }

  /// Brings in a v6.2 Project_Folder_Manager_config.txt; returns why not, or null
  String? importV6(String file) {
    V6Config? c;
    try {
      c = parseV6Config(File(file).readAsStringSync());
    } catch (_) {
      c = null;
    }
    if (c == null) return 'That isn\'t a Project Folder Manager settings file.';
    final o = c.options;
    settings.options
      ..tree = o.tree
      ..deep = o.deep
      ..hideMissing = o.hideMissing
      ..depth = o.depth
      ..files = o.files
      ..drives = o.drives
      ..layout = o.layout == 0 ? 2 : o.layout;
    final at = _projectIndex(c.project.root);
    if (at >= 0) {
      settings.projects[at] = c.project;
      settings.current = at;
    } else {
      settings.projects.add(c.project);
      settings.current = settings.projects.length - 1;
    }
    _save();
    _openCurrent();
    say('settings brought in from v6: ${c.project.root}');
    return null;
  }

  int _projectIndex(String root) => settings.projects.indexWhere((x) => pathKey(x.root) == pathKey(root));

  void _save() {
    try {
      store.saveSettings(settings);
    } catch (_) {
      say('the settings could not be saved');
    }
  }

  void say(String s) {
    status = s;
    notifyListeners();
  }

  // ---------------------------------------------------------------- projects

  Project? get project => settings.project;
  String get root => project?.root ?? '';
  bool get rootExists => folderExists(root);
  Options get options => settings.options;

  /// Top left: the title the user gave the project, or the program's name
  String get title {
    final t = project?.title.trim() ?? '';
    return t.isEmpty ? 'PROJECT FOLDER MANAGER' : t;
  }

  void _openCurrent() {
    cache.clear();
    openFolders.clear();
    _searchCache = null;
    _stopIndexQuietly();
    final pr = project;
    index = SearchIndex();
    if (pr == null) {
      notifyListeners();
      return;
    }
    pr.opened = now();
    if (folderExists(pr.root)) {
      final otherPc = pr.pc.isNotEmpty && pr.pc != shell.computerName;
      if (otherPc || healNeeded(pr.modules, (n) => folderExists(p.join(pr.root, n)))) {
        _rebuild(quiet: true);
      }
      pr.pc = shell.computerName;
    }
    index = store.loadIndex(pr.root) ?? SearchIndex(root: pr.root);
    if (options.tree) expandAll();
    _save();
    status = index.isEmpty ? 'tip: the project is indexed by itself in the background; INDEX has more' : 'ready';
    notifyListeners();
    autoIndexIfStale();
  }

  /// SET: opens [path] as the project, adding it to the list if it is new; returns why not
  String? setRoot(String path) {
    final r = path.trim();
    if (!folderExists(r)) return 'That folder does not exist:\n\n   $r';
    final at = _projectIndex(r);
    if (at >= 0) {
      settings.current = at;
    } else {
      settings.projects.add(Project(root: r, pc: shell.computerName));
      settings.current = settings.projects.length - 1;
      _rebuild(quiet: true);
    }
    _save();
    _openCurrent();
    say('project opened: $r');
    return null;
  }

  void switchProject(int i) {
    if (i < 0 || i >= settings.projects.length || i == settings.current) return;
    settings.current = i;
    closePanel();
    _save();
    _openCurrent();
    say('project: ${project!.root}');
  }

  /// Takes a project off the list (nothing on the disk changes)
  void forgetProject(int i) {
    if (i < 0 || i >= settings.projects.length) return;
    final wasCurrent = i == settings.current;
    settings.projects.removeAt(i);
    if (settings.current >= i && settings.current > 0) settings.current--;
    _save();
    if (wasCurrent) {
      closePanel();
      _openCurrent();
    } else {
      notifyListeners();
    }
  }

  void setTitle(String t) {
    project?.title = t.trim();
    _save();
    say(t.trim().isEmpty ? 'title cleared' : 'title set to: ${t.trim()}');
  }

  List<String> _diskModules() => [for (final e in cache.folders(root)) e.name];

  void _rebuild({bool quiet = false}) {
    final pr = project;
    if (pr == null) return;
    cache.forget(pr.root);
    final next = rebuildModules(pr.modules, _diskModules());
    pr.modules
      ..clear()
      ..addAll(next);
    if (!quiet) {
      _save();
      notifyListeners();
    }
  }

  /// REBUILD; returns how many folders are in the list now
  int rebuild() {
    _rebuild();
    openFolders.clear();
    say('list rebuilt: ${project?.modules.length ?? 0} folder(s) on this PC');
    return project?.modules.length ?? 0;
  }

  /// SCAN; returns the folders added
  List<String> scan() {
    final pr = project;
    if (pr == null) return const [];
    cache.forget(root);
    final added = addNewModules(pr.modules, _diskModules());
    _save();
    say(added.isEmpty ? 'no new top-level folders on disk' : '${added.length} new folder(s) added');
    return added;
  }

  FixResult fixNames() {
    final pr = project;
    if (pr == null) return FixResult();
    cache.forget(root);
    final r = fixModuleNames(pr.modules, _diskModules());
    _save();
    say('${r.fixed.length} name(s) repaired${r.lost.isEmpty ? '' : ', ${r.lost.length} not found'}');
    return r;
  }

  /// New in v7: makes the folders of modules that aren't on the disk; returns those that failed
  Future<List<String>> createMissing() async {
    final failed = <String>[];
    for (final m in project?.modules ?? <Module>[]) {
      final path = p.join(root, m.name);
      if (folderExists(path)) continue;
      try {
        await Directory(path).create(recursive: true);
      } catch (e) {
        failed.add(m.name);
      }
    }
    cache.clear();
    say('missing folders made');
    return failed;
  }

  /// New in v7: an empty project gets the standard 00_Admin … 99_Archive folders
  Future<List<String>> createStandardFolders() async {
    final failed = <String>[];
    for (final n in standardFolderNames()) {
      try {
        await Directory(p.join(root, n)).create();
      } catch (_) {
        failed.add(n);
      }
    }
    cache.clear();
    scan();
    return failed;
  }

  void setDiscipline(String moduleName, String discipline) {
    for (final m in project?.modules ?? <Module>[]) {
      if (m.name == moduleName) m.discipline = discipline;
    }
    _save();
    notifyListeners();
  }

  // ---------------------------------------------------------------- module list & tree

  final openFolders = <String>{};
  String query = '';
  String discipline = '';
  Kind resultKind = Kind.all;

  bool isOpen(String path) => openFolders.contains(pathKey(path));

  void toggleOpen(String path) {
    final k = pathKey(path);
    if (!openFolders.remove(k)) openFolders.add(k);
    notifyListeners();
  }

  /// ALWAYS TREE opens three levels, as v6.2 did
  void expandAll() {
    void mark(String path, int depth) {
      if (depth >= 3) return;
      for (final e in cache.folders(path)) {
        openFolders.add(pathKey(e.path));
        mark(e.path, depth + 1);
      }
    }

    for (final m in project?.modules ?? <Module>[]) {
      final path = p.join(root, m.name);
      openFolders.add(pathKey(path));
      mark(path, 1);
    }
  }

  void collapseAll() {
    openFolders.clear();
    options.tree = false;
    _save();
    notifyListeners();
  }

  void setTree(bool on) {
    options.tree = on;
    if (on) {
      expandAll();
    } else {
      openFolders.clear();
    }
    _save();
    notifyListeners();
  }

  void setDeep(bool on) {
    options.deep = on;
    _save();
    notifyListeners();
  }

  void setHideMissing(bool on) {
    options.hideMissing = on;
    _save();
    notifyListeners();
  }

  void setDrives(bool on) {
    options.drives = on;
    if (on) refreshDrives();
    _save();
    notifyListeners();
  }

  /// A switch in the ⋯ menu changed: save it
  void optionsChanged() {
    _save();
    notifyListeners();
  }

  void setScope(IndexScope s) {
    options.scope = s;
    _save();
    notifyListeners();
  }

  void setAutoIndex(bool on) {
    options.autoIndex = on;
    _save();
    notifyListeners();
    if (on) autoIndexIfStale();
  }

  void setQuery(String q) {
    query = q;
    notifyListeners();
  }

  void filterDiscipline(String d) {
    discipline = d;
    notifyListeners();
  }

  void setResultKind(Kind k) {
    resultKind = k;
    notifyListeners();
  }

  /// REFRESH: everything is read from the disk again
  void refresh() {
    cache.clear();
    _searchCache = null;
    if (options.drives) refreshDrives();
    say('re-read from disk${index.isEmpty ? '' : ' - INDEX → Index this project refreshes the index too'}');
  }

  /// The four numbers top right: modules, on disk, indexed, missing
  (int, int, int, int) get kpis {
    final mods = project?.modules ?? const <Module>[];
    final on = mods.where((m) => folderExists(p.join(root, m.name))).length;
    return (mods.length, on, _building?.length ?? index.length, mods.length - on);
  }

  /// The module list as filtered by MISSING, DISCIPLINE and the search box
  List<ModuleRow> moduleRows() {
    final q = query.trim().toLowerCase();
    final out = <ModuleRow>[];
    var n = 0;
    for (final m in project?.modules ?? const <Module>[]) {
      final path = p.join(root, m.name);
      final ex = folderExists(path);
      if (options.hideMissing && !ex) continue;
      if (discipline.isNotEmpty && m.discipline != discipline) continue;
      if (q.isNotEmpty && !m.name.toLowerCase().contains(q)) continue;
      n++;
      out.add(ModuleRow(n, m, path, ex, ex ? cache.folderCount(path) : 0));
    }
    return out;
  }

  /// True when the list shows search results from the index instead of the modules
  bool get showingResults => query.trim().isNotEmpty && options.deep && index.length > 0;

  (String, String, Kind)? _searchKey;
  SearchResult? _searchCache;

  SearchResult results() {
    final key = (query, discipline, resultKind);
    if (_searchCache != null && _searchKey == key) return _searchCache!;
    bool Function(String)? where;
    if (discipline.isNotEmpty) {
      final roots = [
        for (final m in project?.modules ?? const <Module>[])
          if (m.discipline == discipline) p.join(root, m.name),
      ];
      where = (path) => roots.any((r) => isSameOrInside(path, r));
    }
    _searchKey = key;
    return _searchCache = index.search(query, kind: resultKind, where: where);
  }

  /// The discipline of the module [path] is in, if it is inside the project
  String? disciplineOf(String path) {
    for (final m in project?.modules ?? const <Module>[]) {
      if (isSameOrInside(path, p.join(root, m.name))) return m.discipline;
    }
    return null;
  }

  // ---------------------------------------------------------------- index

  IndexRun? _run;
  bool _starting = false;
  SearchIndex? _building;
  IndexProgress? progress;
  bool get indexing => _run != null;

  /// INDEX: returns why it can't start, or null
  Future<String?> startIndex({IndexScope? scope, bool quiet = false}) async {
    if (_run != null || _starting) return null;
    final sc = scope ?? options.scope;
    final List<String> seeds;
    switch (sc) {
      case IndexScope.project:
        if (!rootExists) return 'Root folder not found on this PC:\n\n   $root';
        seeds = [root];
      case IndexScope.drive:
        final d = p.rootPrefix(root);
        if (d.isEmpty || !folderExists(d)) return 'Drive not ready:\n\n   $d';
        seeds = [d];
      case IndexScope.allDrives:
        seeds = [
          for (final d in shell.drives())
            if (d.ready && d.type == 'Local Disk') d.root,
        ];
        if (seeds.isEmpty) return 'No drive available to index.';
    }
    final built = SearchIndex(
      scope: switch (sc) {
        IndexScope.project => 'project',
        IndexScope.drive => p.rootPrefix(root),
        IndexScope.allDrives => 'all drives',
      },
      root: root,
    );
    final forRoot = root;
    _starting = true;
    final IndexRun run;
    try {
      run = await IndexRun.start(
        IndexJob(
          seeds: seeds,
          depth: sc == IndexScope.project ? options.depth : 14,
          files: options.files,
          wholeDrives: sc != IndexScope.project,
        ),
      );
    } finally {
      _starting = false;
    }
    if (_disposed || forRoot != root) {
      run.stop(); // closed, or another project opened meanwhile
      return null;
    }
    _building = built;
    _run = run;
    if (!quiet) say('indexing ...');
    notifyListeners();
    run.progress.listen(
      (pg) {
        for (final l in pg.lines) {
          built.addLine(l);
        }
        progress = pg;
        if (!quiet || pg.done) {
          status = pg.done
              ? 'index ready  ·  ${built.length} items searchable'
              : 'indexing  ${pg.foldersRead} folders read  ·  ${built.length} items found  ·  '
                    '${pg.queued} queued  ·  press STOP to keep what is found';
        }
        notifyListeners();
      },
      onDone: () {
        if (_disposed || !identical(_run, run)) return; // stopped quietly: closed or another project
        final stopped = run.stopped;
        _run = null;
        _building = null;
        progress = null;
        if (forRoot != root) return; // the project changed meanwhile
        built.built = now();
        index = built;
        _searchCache = null;
        store.saveIndex(root, built);
        status =
            'index ready  ·  ${built.length} items searchable${stopped ? ' (stopped early)' : ''}'
            '${built.length >= indexCap ? ' (limit reached)' : ''}';
        notifyListeners();
      },
    );
    return null;
  }

  /// STOP: keeps what was found
  void stopIndex() => _run?.stop();

  void _stopIndexQuietly() {
    final r = _run;
    if (r == null) return;
    _run = null;
    _building = null;
    progress = null;
    r.stop();
  }

  /// New in v7: the project indexes itself in the background when its index is missing or old
  void autoIndexIfStale() {
    if (!options.autoIndex || !rootExists || _run != null) return;
    if (indexIsStale) unawaited(startIndex(scope: IndexScope.project, quiet: true));
  }

  /// No index, or a project index that is old or was made for another folder. A drive-wide index
  /// the user asked for is left alone.
  bool get indexIsStale {
    if (index.isEmpty) return true;
    if (index.scope != 'project') return false;
    final b = index.built;
    if (b == null || now().difference(b) > staleAfter) return true;
    return index.root.isNotEmpty && pathKey(index.root) != pathKey(root);
  }

  /// Keeps the index in step with what the program itself changed
  void _indexAdd(String path) {
    if (index.isEmpty) return;
    var budget = 5000;
    void add(String x) {
      if (budget-- <= 0) return;
      final dir = FileSystemEntity.isDirectorySync(x);
      if (!dir && !options.files) return;
      index.add(x, !dir);
      if (dir) {
        try {
          for (final e in Directory(x).listSync(followLinks: false)) {
            add(e.path);
          }
        } catch (_) {}
      }
    }

    add(path);
    _searchCache = null;
    store.saveIndex(root, index);
  }

  void _indexMoved(String from, String to) {
    index.moved(from, to);
    _searchCache = null;
  }

  void _indexRemoved(String path) {
    index.removed(path);
    _searchCache = null;
  }

  void _indexSave() {
    if (!index.isEmpty) store.saveIndex(root, index);
  }

  // ---------------------------------------------------------------- side panel

  String? panelPath;
  bool get panelOpen => panelPath != null;
  final _back = <String>[];
  final _forward = <String>[];
  bool get canBack => _back.isNotEmpty;
  bool get canForward => _forward.isNotEmpty;
  String panelFilter = '';
  Show show = Show.all;
  String panelType = '';
  SortBy sortBy = SortBy.name;
  bool sortDown = false;
  final selected = <String>{};
  String? _anchor;

  /// The file to point out when the panel opens on a search result
  String highlight = '';

  /// VIEW: shows [path] in the panel; returns why not
  String? openPanel(String path, {String highlightName = '', bool history = true}) {
    if (!folderExists(path)) return 'Folder not found:\n\n   $path';
    if (history && panelPath != null && pathKey(panelPath!) != pathKey(path)) {
      _back.add(panelPath!);
      if (_back.length > 50) _back.removeAt(0);
      _forward.clear();
    }
    panelPath = path;
    cache.forget(path);
    panelFilter = '';
    show = Show.all;
    if (!panelTypes().contains(panelType)) panelType = '';
    selected.clear();
    _anchor = null;
    highlight = highlightName.toLowerCase();
    if (options.layout == 0) options.layout = 2;
    if (highlight.isNotEmpty) {
      final hit = panelEntries().where((e) => e.name.toLowerCase() == highlight).firstOrNull;
      if (hit != null) {
        selected.add(pathKey(hit.path));
        _anchor = hit.path;
      }
    }
    notifyListeners();
    return null;
  }

  /// VIEW on a search result that is a file: its folder, with the file pointed out
  String? showFile(String path) => openPanel(p.dirname(path), highlightName: p.basename(path));

  void closePanel() {
    panelPath = null;
    selected.clear();
    _back.clear();
    _forward.clear();
    notifyListeners();
  }

  void panelUp() {
    final cur = panelPath;
    if (cur == null) return;
    final up = p.dirname(cur);
    if (up != cur && folderExists(up)) openPanel(up, highlightName: p.basename(cur));
  }

  void panelBack() {
    if (_back.isEmpty || panelPath == null) return;
    _forward.add(panelPath!);
    openPanel(_back.removeLast(), history: false);
  }

  void panelForward() {
    if (_forward.isEmpty || panelPath == null) return;
    _back.add(panelPath!);
    openPanel(_forward.removeLast(), history: false);
  }

  void refreshPanel() {
    if (panelPath == null) return;
    cache.forget(panelPath!);
    notifyListeners();
  }

  /// The six VIEW buttons (Alt+1 … Alt+6)
  void setLayout(int n) {
    if (n == 0) {
      panelPath = null;
      selected.clear();
      say('view: tree only');
      return;
    }
    options.layout = n;
    _save();
    if (panelPath == null) {
      final last = _back.isNotEmpty ? _back.last : root;
      openPanel(folderExists(last) ? last : root);
    }
    say('view: ${layoutNames[n].toLowerCase()}   (Alt+1 to Alt+6 switch views)');
  }

  /// The layout as it is on screen: 0 when the panel is closed
  int get layout => panelOpen ? (options.layout == 0 ? 2 : options.layout) : 0;

  void setPanelFilter(String f) {
    panelFilter = f;
    notifyListeners();
  }

  void setShow(Show s) {
    show = s;
    notifyListeners();
  }

  void setPanelType(String t) {
    panelType = t;
    notifyListeners();
  }

  void setSort(SortBy s) {
    if (sortBy == s) {
      sortDown = !sortDown;
    } else {
      sortBy = s;
      sortDown = false;
    }
    notifyListeners();
  }

  List<Entry> _allHere() => panelPath == null ? const [] : cache.entries(panelPath!);

  /// The file types in the folder, for the type list ("DWG", "PDF", "NO TYPE")
  List<String> panelTypes() {
    final t = <String>{};
    for (final e in _allHere()) {
      if (e.isFile) {
        final x = extOf(e.name).toUpperCase();
        t.add(x.isEmpty ? 'NO TYPE' : x);
      }
    }
    return t.toList()..sort();
  }

  (int, int) get panelCounts {
    final a = _allHere();
    final files = a.where((e) => e.isFile).length;
    return (a.length - files, files);
  }

  /// What the panel lists, filtered and sorted (folders always before files)
  List<Entry> panelEntries() {
    final q = panelFilter.trim().toLowerCase();
    final out = [
      for (final e in _allHere())
        if ((q.isEmpty || e.name.toLowerCase().contains(q)) &&
            !(show == Show.folders && e.isFile) &&
            !(show == Show.files && e.isDir) &&
            (panelType.isEmpty || e.isDir || _typeOf(e) == panelType))
          e,
    ];
    int cmp(Entry a, Entry b) {
      if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
      final r = switch (sortBy) {
        SortBy.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        SortBy.type => _typeOf(a).compareTo(_typeOf(b)),
        SortBy.size => (a.size ?? 0).compareTo(b.size ?? 0),
        SortBy.date => (a.modified ?? DateTime(0)).compareTo(b.modified ?? DateTime(0)),
      };
      final r2 = r != 0 ? r : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return sortDown ? -r2 : r2;
    }

    out.sort(cmp);
    return out;
  }

  String _typeOf(Entry e) {
    final x = extOf(e.name).toUpperCase();
    return x.isEmpty ? 'NO TYPE' : x;
  }

  // ---------------------------------------------------------------- selection

  bool isSelected(Entry e) => selected.contains(pathKey(e.path));

  /// Click, Ctrl+click for several, Shift+click for a range (as v6.2)
  void click(Entry e, {bool ctrl = false, bool shift = false}) {
    final list = panelEntries();
    final i = list.indexWhere((x) => pathKey(x.path) == pathKey(e.path));
    final a = _anchor == null ? -1 : list.indexWhere((x) => pathKey(x.path) == pathKey(_anchor!));
    if (shift && a >= 0 && i >= 0) {
      if (!ctrl) selected.clear();
      for (var k = (a < i ? a : i); k <= (a < i ? i : a); k++) {
        selected.add(pathKey(list[k].path));
      }
    } else if (ctrl) {
      if (!selected.remove(pathKey(e.path))) selected.add(pathKey(e.path));
      _anchor = e.path;
    } else {
      selected
        ..clear()
        ..add(pathKey(e.path));
      _anchor = e.path;
    }
    highlight = '';
    notifyListeners();
  }

  /// Arrow keys move the selection; with Shift they stretch it
  void moveSelection(int delta, {bool shift = false}) {
    final list = panelEntries();
    if (list.isEmpty) return;
    var i = _anchor == null ? -1 : list.indexWhere((x) => pathKey(x.path) == pathKey(_anchor!));
    i = (i < 0 ? (delta > 0 ? 0 : list.length - 1) : i + delta).clamp(0, list.length - 1);
    if (shift) {
      selected.add(pathKey(list[i].path));
    } else {
      selected
        ..clear()
        ..add(pathKey(list[i].path));
    }
    _anchor = list[i].path;
    notifyListeners();
  }

  void selectAll() {
    selected
      ..clear()
      ..addAll(panelEntries().map((e) => pathKey(e.path)));
    notifyListeners();
  }

  void selectNone() {
    selected.clear();
    _anchor = null;
    notifyListeners();
  }

  List<Entry> selection() => [
    for (final e in panelEntries())
      if (isSelected(e)) e,
  ];

  /// The selected row the keyboard is on
  Entry? get focused {
    final a = _anchor;
    if (a == null) return null;
    return panelEntries().where((e) => pathKey(e.path) == pathKey(a)).firstOrNull;
  }

  // ---------------------------------------------------------------- clipboard and operations

  List<Item> clip = const [];
  bool clipCut = false;

  bool isCut(Entry e) => clipCut && clip.any((c) => pathKey(c.path) == pathKey(e.path));

  /// COPY / CUT; returns false when nothing is selected
  bool copySelection({required bool cut, List<Entry>? items}) {
    final a = items ?? selection();
    if (a.isEmpty) return false;
    clip = [for (final e in a) Item(e.path, e.isDir)];
    clipCut = cut;
    say(cut ? '${a.length} item(s) cut - press PASTE where you want them' : '${a.length} item(s) copied');
    return true;
  }

  void clearClip() {
    clip = const [];
    clipCut = false;
    notifyListeners();
  }

  OpProgress? op;
  bool _cancelOp = false;
  bool get busy => op != null;
  void cancelOp() => _cancelOp = true;

  final undoSteps = <UndoStep>[];
  UndoStep? get lastUndo => undoSteps.isEmpty ? null : undoSteps.last;

  void _pushUndo(UndoStep? s) {
    if (s == null || s.isEmpty) return;
    undoSteps.add(s);
    if (undoSteps.length > 20) undoSteps.removeAt(0);
  }

  void _afterChange() {
    cache.clear();
    selected.clear();
    _anchor = null;
    _indexSave();
    notifyListeners();
  }

  /// Why PASTE can't start in [destination], or null
  String? pasteCheck([String? destination]) => pasteProblem(clip, destination ?? panelPath ?? '', move: clipCut);

  /// PASTE into the panel's folder (or [destination])
  Future<OpResult> pasteHere(ClashAsker ask, {String? destination, List<Item>? items, bool? move}) async {
    final dst = destination ?? panelPath!;
    final its = items ?? clip;
    final mv = move ?? clipCut;
    _cancelOp = false;
    op = OpProgress(0, its.length, '', 0);
    notifyListeners();
    final r = await paste(
      items: its,
      destination: dst,
      move: mv,
      ask: ask,
      progress: (pg) {
        op = pg;
        notifyListeners();
      },
      cancelled: () => _cancelOp,
    );
    op = null;
    final u = r.undo;
    if (u != null) {
      for (final (from, to) in u.moves) {
        _indexMoved(from, to);
      }
      u.created.forEach(_indexAdd);
    }
    if (mv) {
      // a merge-move leaves nothing behind; take what is gone out of the index
      for (final it in its) {
        if (!anyExists(it.path)) _indexRemoved(it.path);
      }
      if (items == null && !r.cancelled) clip = const [];
    }
    _pushUndo(u);
    status =
        '${r.ok} ${mv ? 'moved' : 'copied'}${r.skipped > 0 ? ', ${r.skipped} skipped' : ''}'
        '${r.failed.isNotEmpty ? ', ${r.failed.length} failed' : ''}${r.cancelled ? ' (cancelled)' : ''}';
    _afterChange();
    return r;
  }

  /// DELETE: the selection (or [items]) to the Recycle Bin; returns what failed
  Future<List<String>> deleteItems(List<Entry> items) async {
    final failed = await shell.recycle([for (final e in items) e.path]);
    for (final e in items) {
      if (!anyExists(e.path)) _indexRemoved(e.path);
      clip = [
        for (final c in clip)
          if (!isSameOrInside(c.path, e.path)) c,
      ];
    }
    status =
        '${items.length - failed.length} sent to the Recycle Bin${failed.isEmpty ? '' : ', ${failed.length} failed'}';
    _afterChange();
    return failed;
  }

  /// RENAME (F2); returns why not
  Future<String?> rename(Entry e, String newName) async {
    final undo = UndoStep('rename ${e.name}');
    final why = await renameItem(e.path, newName.trim(), undo: undo);
    if (why != null) return why;
    final to = p.join(p.dirname(e.path), newName.trim());
    _indexMoved(e.path, to);
    _fixModuleAfterRename(e.path, to);
    _pushUndo(undo);
    status = 'renamed:  ${e.name}  →  ${newName.trim()}';
    _afterChange();
    selected.add(pathKey(to));
    _anchor = to;
    return null;
  }

  /// A module's folder renamed inside the program: the list follows it
  void _fixModuleAfterRename(String from, String to) {
    if (pathKey(p.dirname(from)) != pathKey(root)) return;
    for (final m in project?.modules ?? <Module>[]) {
      if (m.name == p.basename(from)) m.name = p.basename(to);
    }
    _save();
  }

  /// + FOLDER; returns why not
  Future<String?> makeFolder(String name, [String? parent]) async {
    final dir = parent ?? panelPath;
    if (dir == null) return 'Open a folder first.';
    try {
      final path = await newFolder(dir, name.trim());
      _pushUndo(UndoStep('new folder ${name.trim()}')..created.add(path));
      _indexAdd(path);
      status = 'folder made: ${name.trim()}';
      _afterChange();
      selected.add(pathKey(path));
      _anchor = path;
      return null;
    } on FileSystemException catch (e) {
      return 'Could not make it: ${e.message}';
    }
  }

  /// APPLY RENAMES from LIST / EDIT
  Future<(int, List<(String, String)>)> applyBulk(RenamePlan plan) async {
    final dir = panelPath!;
    final (done, failed, undo) = await applyRenames(plan, dir);
    for (final (from, to) in undo.moves) {
      _indexMoved(from, to);
    }
    for (final c in plan.changes) {
      _fixModuleAfterRename(c.path, p.join(dir, c.to));
    }
    _pushUndo(undo);
    status = '$done renamed${failed.isEmpty ? '' : ', ${failed.length} failed'}';
    _afterChange();
    return (done, failed);
  }

  /// UNDO (Ctrl+Z); returns what could not be put back
  Future<List<String>> undo() async {
    final s = lastUndo;
    if (s == null) return const [];
    undoSteps.removeLast();
    final failed = await undoStep(s, shell.recycle);
    for (final (from, to) in s.moves.reversed) {
      if (anyExists(from)) {
        _indexMoved(to, from);
        _fixModuleAfterRename(to, from);
      }
    }
    for (final c in s.created) {
      if (!anyExists(c)) _indexRemoved(c);
    }
    status = 'undone: ${s.label}${failed.isEmpty ? '' : ' (${failed.length} could not be put back)'}';
    _afterChange();
    return failed;
  }

  // ---------------------------------------------------------------- opening, pins, drives

  /// OPEN: a folder in Explorer, a file in its own program. False when Windows has no program
  /// for the file (the window then offers to show it in Explorer).
  Future<bool> openInWindows(String path) async {
    if (FileSystemEntity.isDirectorySync(path)) return shell.openFolder(path);
    if (!anyExists(path)) {
      say('not found on this PC: $path');
      return true;
    }
    return shell.openFile(path);
  }

  bool isPinned(String path) => settings.pinned.any((x) => pathKey(x) == pathKey(path));

  void togglePin(String path) {
    final i = settings.pinned.indexWhere((x) => pathKey(x) == pathKey(path));
    if (i >= 0) {
      settings.pinned.removeAt(i);
      say('unpinned: ${p.basename(path)}');
    } else {
      settings.pinned.add(path);
      say('pinned: ${p.basename(path)}');
    }
    _save();
  }

  List<DriveInfo> drives = const [];

  void refreshDrives() {
    try {
      drives = shell.drives();
    } catch (_) {
      drives = const [];
    }
    notifyListeners();
  }

  /// Total size of a folder, for Properties (new in v7); counts up to [limit] files
  static Future<(int, int, int)> measure(String path, {int limit = 200000}) async {
    var bytes = 0, files = 0, folders = 0;
    try {
      await for (final e in Directory(path).list(recursive: true, followLinks: false)) {
        if (e is File) {
          files++;
          try {
            bytes += await e.length();
          } catch (_) {}
        } else if (e is Directory) {
          folders++;
        }
        if (files >= limit) break;
      }
    } catch (_) {}
    return (bytes, files, folders);
  }

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopIndexQuietly();
    super.dispose();
  }
}
