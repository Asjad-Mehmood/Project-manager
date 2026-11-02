// What the program remembers: the projects (each a root folder, its title and its modules with
// their disciplines), the switches and the chosen view. v7 keeps several projects and switches
// between them; v6.2 kept one, in Project_Folder_Manager_config.txt next to the program, which
// [parseV6Config] reads so nobody has to set things up again.
import 'disciplines.dart';

class Module {
  Module(this.name, this.discipline);
  String name;
  String discipline;

  List<String> toJson() => [name, discipline];
  static Module fromJson(Object? j) {
    if (j is List && j.isNotEmpty && j[0] is String) {
      final name = j[0] as String;
      final d = j.length > 1 && j[1] is String ? j[1] as String : guessDiscipline(name);
      return Module(name, d);
    }
    throw const FormatException('module');
  }
}

/// How wide INDEX reaches
enum IndexScope {
  project('This project'),
  drive('Whole drive'),
  allDrives('All drives');

  const IndexScope(this.label);
  final String label;
}

class Options {
  /// ALWAYS TREE: keep the whole tree open
  bool tree = false;

  /// DEEP: search the whole index, every level
  bool deep = true;

  /// MISSING: hide modules that aren't on the disk
  bool hideMissing = false;

  /// Index files as well as folders
  bool files = true;

  /// How many levels INDEX reads in a project
  int depth = 6;

  /// DRIVES strip shown
  bool drives = false;

  /// The view: 0 tree only … 5 panel only (v6.2's six layouts)
  int layout = 2;

  IndexScope scope = IndexScope.project;

  /// New in v7: index the project by itself, in the background, when it is opened and the
  /// index is missing or more than [staleHours] old
  bool autoIndex = true;

  Map<String, Object> toJson() => {
    'tree': tree,
    'deep': deep,
    'miss': hideMissing,
    'files': files,
    'depth': depth,
    'drv': drives,
    'lay': layout,
    'scope': scope.name,
    'autoIndex': autoIndex,
  };

  static Options fromJson(Object? j) {
    final o = Options();
    if (j is! Map) return o;
    bool b(String k, bool d) => j[k] is bool ? j[k] as bool : d;
    int i(String k, int d) => j[k] is int ? j[k] as int : d;
    o
      ..tree = b('tree', o.tree)
      ..deep = b('deep', o.deep)
      ..hideMissing = b('miss', o.hideMissing)
      ..files = b('files', o.files)
      ..depth = i('depth', o.depth).clamp(1, 30)
      ..drives = b('drv', o.drives)
      ..layout = i('lay', o.layout).clamp(0, 5)
      ..scope = IndexScope.values.firstWhere((s) => s.name == j['scope'], orElse: () => IndexScope.project)
      ..autoIndex = b('autoIndex', o.autoIndex);
    return o;
  }
}

class Project {
  Project({required this.root, this.title = '', this.pc = '', List<Module>? modules, this.opened})
    : modules = modules ?? [];

  String root;

  /// Shown top left; empty means "PROJECT FOLDER MANAGER"
  String title;

  /// The computer the module list was last built on
  String pc;
  final List<Module> modules;
  DateTime? opened;

  Map<String, Object> toJson() => {
    'root': root,
    'title': title,
    'pc': pc,
    'modules': [for (final m in modules) m.toJson()],
    if (opened != null) 'opened': opened!.toIso8601String(),
  };

  static Project fromJson(Object? j) {
    if (j is! Map || j['root'] is! String) throw const FormatException('project');
    final mods = <Module>[];
    if (j['modules'] is List) {
      for (final m in j['modules'] as List) {
        try {
          mods.add(Module.fromJson(m));
        } on FormatException {
          // a damaged line is left out
        }
      }
    }
    return Project(
      root: j['root'] as String,
      title: j['title'] is String ? j['title'] as String : '',
      pc: j['pc'] is String ? j['pc'] as String : '',
      modules: mods,
      opened: j['opened'] is String ? DateTime.tryParse(j['opened'] as String) : null,
    );
  }
}

class Settings {
  final List<Project> projects = [];
  int current = 0;
  Options options = Options();

  /// Folders pinned for quick access (new in v7)
  final List<String> pinned = [];

  /// The v6.2 settings were looked for once already
  bool v6Checked = false;

  Project? get project => projects.isEmpty ? null : projects[current.clamp(0, projects.length - 1)];

  Map<String, Object> toJson() => {
    'format': 1,
    'current': current,
    'projects': [for (final p in projects) p.toJson()],
    'options': options.toJson(),
    'pinned': pinned,
    'v6Checked': v6Checked,
  };

  static Settings fromJson(Object? j) {
    final s = Settings();
    if (j is! Map) return s;
    if (j['projects'] is List) {
      for (final p in j['projects'] as List) {
        try {
          s.projects.add(Project.fromJson(p));
        } on FormatException {
          // left out
        }
      }
    }
    s.current = j['current'] is int
        ? (j['current'] as int).clamp(0, s.projects.isEmpty ? 0 : s.projects.length - 1)
        : 0;
    s.options = Options.fromJson(j['options']);
    if (j['pinned'] is List) s.pinned.addAll((j['pinned'] as List).whereType<String>());
    s.v6Checked = j['v6Checked'] == true;
    return s;
  }
}

/// v6.2's settings file: the root on the first line, then #PC=, #TITLE=, #OPT= and one
/// "name|discipline" line per module
class V6Config {
  V6Config(this.project, this.options);
  final Project project;
  final Options options;
}

V6Config? parseV6Config(String text) {
  final lines = text.split('\n').map((l) => l.trim()).toList();
  if (lines.isEmpty || lines.first.isEmpty || lines.first.startsWith('#')) return null;
  final p = Project(root: lines.first);
  final o = Options();
  for (final ln in lines.skip(1)) {
    if (ln.isEmpty) continue;
    if (ln.startsWith('#PC=')) {
      p.pc = ln.substring(4);
    } else if (ln.startsWith('#TITLE=')) {
      p.title = ln.substring(7);
    } else if (ln.startsWith('#OPT=')) {
      for (final kv in ln.substring(5).split(',')) {
        final parts = kv.split(':');
        if (parts.length != 2) continue;
        final v = int.tryParse(parts[1]);
        if (v == null) continue;
        switch (parts[0]) {
          case 'tree':
            o.tree = v != 0;
          case 'deep':
            o.deep = v != 0;
          case 'miss':
            o.hideMissing = v != 0;
          case 'depth':
            o.depth = v.clamp(1, 30);
          case 'files':
            o.files = v != 0;
          case 'drv':
            o.drives = v != 0;
          case 'lay':
            o.layout = v.clamp(0, 5);
        }
      }
    } else {
      final parts = ln.split('|');
      final name = parts[0];
      p.modules.add(Module(name, parts.length > 1 && parts[1].isNotEmpty ? parts[1] : guessDiscipline(name)));
    }
  }
  return V6Config(p, o);
}
