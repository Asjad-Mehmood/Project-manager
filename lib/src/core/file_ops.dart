// Copy, move, rename and new folder, the way v6.2 did them, with three additions: a folder that
// already exists is merged (as Explorer does) instead of failing, the window stays responsive
// while big folders copy, and each step can be undone (UNDO, Ctrl+Z).
import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'disk.dart';
import 'names.dart';

/// Something on the program's own clipboard
class Item {
  const Item(this.path, this.isDir);
  final String path;
  final bool isDir;
  String get name => p.basename(path);
}

/// The answer to "name already exists"
enum Clash { replace, keepBoth, skip, cancel }

/// Asks what to do about [name]; the bool is "do the same for every remaining clash"
typedef ClashAsker = Future<(Clash, bool)> Function(String name, String destination);

class OpProgress {
  const OpProgress(this.index, this.count, this.name, this.files);

  /// Item [index] of [count] (from 1)
  final int index;
  final int count;
  final String name;

  /// Files copied so far, in all items
  final int files;
}

class OpResult {
  int ok = 0;
  int skipped = 0;
  bool cancelled = false;
  final failed = <(String, String)>[];

  /// What UNDO puts back
  UndoStep? undo;
}

/// One step UNDO can reverse: renames/moves are moved back (last first), new things are removed
class UndoStep {
  UndoStep(this.label);
  final String label;
  final moves = <(String from, String to)>[];
  final created = <String>[];
  bool get isEmpty => moves.isEmpty && created.isEmpty;
}

/// Why a paste can't start, or null
String? pasteProblem(List<Item> items, String destination, {required bool move}) {
  if (items.isEmpty) return 'The clipboard is empty.\n\nSelect items and press COPY or CUT first.';
  if (!folderExists(destination)) return 'Open a destination folder first.';
  for (final it in items) {
    if (it.isDir && isSameOrInside(destination, it.path)) {
      return 'A folder can\'t go inside itself:\n\n   ${it.name}';
    }
  }
  if (move && items.every((it) => pathKey(p.dirname(it.path)) == pathKey(destination))) {
    return 'Those items are already in this folder.';
  }
  return null;
}

/// COPY / CUT then PASTE into [destination]
Future<OpResult> paste({
  required List<Item> items,
  required String destination,
  required bool move,
  required ClashAsker ask,
  void Function(OpProgress)? progress,
  bool Function()? cancelled,
}) async {
  final r = OpResult();
  final undo = UndoStep(move ? 'move ${items.length == 1 ? items.first.name : '${items.length} items'}' : 'copy');
  Clash? forAll;
  var files = 0;
  void tick(String name, int i) => progress?.call(OpProgress(i + 1, items.length, name, files));

  for (var i = 0; i < items.length; i++) {
    if (cancelled?.call() == true) {
      r.cancelled = true;
      break;
    }
    final it = items[i];
    if (move && pathKey(p.dirname(it.path)) == pathKey(destination)) {
      r.skipped++; // already here
      continue;
    }
    var target = p.join(destination, it.name);
    var merge = false;
    if (anyExists(target)) {
      var act = forAll;
      if (act == null) {
        final (c, all) = await ask(it.name, destination);
        act = c;
        if (all && c != Clash.cancel) forAll = c;
      }
      if (act == Clash.cancel) {
        r.cancelled = true;
        break;
      }
      if (act == Clash.skip) {
        r.skipped++;
        continue;
      }
      if (act == Clash.keepBoth) {
        target = p.join(destination, freeName(it.name, (c) => anyExists(p.join(destination, c))));
      } else {
        merge = true; // replace: files are overwritten, folders merged
      }
    }
    tick(it.name, i);
    try {
      if (move) {
        if (merge) {
          await _mergeMove(it, target, () => tick(it.name, i), () => files++);
        } else {
          await _move(it, target, () => files++);
          undo.moves.add((it.path, target));
        }
      } else {
        final existed = anyExists(target);
        await _copy(it, target, () {
          files++;
          if (files % 20 == 0) tick(it.name, i);
        }, cancelled);
        if (!existed) undo.created.add(target);
      }
      r.ok++;
    } on _Cancelled {
      r.cancelled = true;
      break;
    } catch (e) {
      r.failed.add((it.name, _why(e)));
    }
    await Future<void>.delayed(Duration.zero); // let the window draw
  }
  if (!undo.isEmpty) r.undo = undo;
  return r;
}

class _Cancelled implements Exception {}

String _why(Object e) {
  if (e is FileSystemException) {
    final os = e.osError?.message.trim();
    return os != null && os.isNotEmpty ? os : e.message;
  }
  return e.toString();
}

Future<void> _copy(Item it, String target, void Function() fileDone, bool Function()? cancelled) async {
  if (!it.isDir) {
    await File(it.path).copy(target);
    fileDone();
    return;
  }
  await Directory(target).create(recursive: true);
  await for (final e in Directory(it.path).list(followLinks: false)) {
    if (cancelled?.call() == true) throw _Cancelled();
    final to = p.join(target, p.basename(e.path));
    if (e is Directory) {
      await _copy(Item(e.path, true), to, fileDone, cancelled);
    } else if (e is File) {
      await e.copy(to);
      fileDone();
    }
  }
}

Future<void> _move(Item it, String target, void Function() fileDone) async {
  try {
    if (it.isDir) {
      await Directory(it.path).rename(target);
    } else {
      await File(it.path).rename(target);
    }
  } on FileSystemException {
    // another drive: copy, then remove the original
    if (anyExists(target)) rethrow;
    await _copy(it, target, fileDone, null);
    if (it.isDir) {
      await Directory(it.path).delete(recursive: true);
    } else {
      await File(it.path).delete();
    }
  }
}

/// Move onto something that exists: a file replaces it, a folder's contents are merged into it
Future<void> _mergeMove(Item it, String target, void Function() tick, void Function() fileDone) async {
  if (!it.isDir) {
    if (FileSystemEntity.isDirectorySync(target)) throw FileSystemException('a folder has that name', target);
    await File(target).delete();
    await _move(it, target, fileDone);
    return;
  }
  if (!FileSystemEntity.isDirectorySync(target)) throw FileSystemException('a file has that name', target);
  await for (final e in Directory(it.path).list(followLinks: false)) {
    final to = p.join(target, p.basename(e.path));
    final kid = Item(e.path, e is Directory);
    if (anyExists(to)) {
      await _mergeMove(kid, to, tick, fileDone);
    } else {
      await _move(kid, to, fileDone);
    }
    tick();
  }
  await Directory(it.path).delete();
}

/// Rename one file or folder in place; returns why not, or null when it worked
Future<String?> renameItem(String path, String newName, {UndoStep? undo}) async {
  final problem = nameProblem(newName);
  if (problem != null) return problem;
  final oldName = p.basename(path);
  if (newName == oldName) return null;
  final target = p.join(p.dirname(path), newName);
  if (anyExists(target) && newName.toLowerCase() != oldName.toLowerCase()) return 'that name already exists here';
  try {
    if (FileSystemEntity.isDirectorySync(path)) {
      await Directory(path).rename(target);
    } else {
      await File(path).rename(target);
    }
    undo?.moves.add((path, target));
    return null;
  } catch (e) {
    return '${_why(e)}\n\nUsually because the item is open in another program, or the folder is open in Explorer.';
  }
}

/// + FOLDER; returns the new folder's path, or throws with why not
Future<String> newFolder(String parent, String name) async {
  final problem = nameProblem(name);
  if (problem != null) throw FileSystemException(problem);
  final path = p.join(parent, name);
  if (anyExists(path)) throw const FileSystemException('something with that name is already there');
  await Directory(path).create();
  return path;
}

/// UNDO: moves back last-first, then removes what was made (via [remove], the Recycle Bin)
Future<List<String>> undoStep(UndoStep step, Future<List<String>> Function(List<String> paths) remove) async {
  final failed = <String>[];
  for (final (from, to) in step.moves.reversed) {
    try {
      if (anyExists(from)) {
        failed.add('${p.basename(to)}: "${p.basename(from)}" is there again');
        continue;
      }
      if (FileSystemEntity.isDirectorySync(to)) {
        await Directory(to).rename(from);
      } else {
        await File(to).rename(from);
      }
    } catch (e) {
      failed.add('${p.basename(to)}: ${_why(e)}');
    }
  }
  if (step.created.isNotEmpty) failed.addAll(await remove(step.created));
  return failed;
}
