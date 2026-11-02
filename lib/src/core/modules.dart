// The project's module list: the folders directly inside the root, each with a discipline.
// REBUILD, SCAN and FIX NAMES work as in v6.2; [healNeeded] is v6.2's quiet repair when most of
// the list has gone (the folders were renamed, or the settings came from another computer).
import 'disciplines.dart';
import 'settings.dart';

/// REBUILD: the list becomes the folders on the disk; disciplines are kept for names that still
/// match and guessed from the number for the rest
List<Module> rebuildModules(List<Module> old, List<String> onDisk) {
  final kept = {for (final m in old) m.name: m.discipline};
  return [for (final n in onDisk) Module(n, kept[n] ?? guessDiscipline(n))];
}

/// SCAN: adds folders that aren't in the list yet; returns their names
List<String> addNewModules(List<Module> modules, List<String> onDisk) {
  final have = {for (final m in modules) m.name.toLowerCase()};
  final added = <String>[];
  for (final n in onDisk) {
    if (have.add(n.toLowerCase())) {
      modules.add(Module(n, guessDiscipline(n)));
      added.add(n);
    }
  }
  return added;
}

class FixResult {
  final fixed = <(String, String)>[];
  final lost = <String>[];
}

String _squash(String s) => s.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');

/// FIX NAMES: a module whose folder was renamed only in case, spaces, _ or - is pointed at the
/// folder's new name; the ones still not found are listed in [FixResult.lost]
FixResult fixModuleNames(List<Module> modules, List<String> onDisk) {
  final exact = onDisk.toSet();
  final lower = {for (final n in onDisk) n.toLowerCase(): n};
  final squashed = {for (final n in onDisk) _squash(n): n};
  final r = FixResult();
  for (final m in modules) {
    if (exact.contains(m.name)) continue;
    final to = lower[m.name.toLowerCase()] ?? squashed[_squash(m.name)];
    if (to != null) {
      r.fixed.add((m.name, to));
      m.name = to;
    } else {
      r.lost.add(m.name);
    }
  }
  return r;
}

/// More than half of the modules are missing from the disk: the list is out of date
bool healNeeded(List<Module> modules, bool Function(String name) exists) {
  if (modules.isEmpty) return true;
  final gone = modules.where((m) => !exists(m.name)).length;
  return gone > modules.length / 2;
}
