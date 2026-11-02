// LIST / EDIT: a folder's names as lines of text; edit them and APPLY RENAMES. The checks are
// v6.2's (same number of lines, no character Windows refuses, no name twice, nothing already on
// the disk) and Windows' other rules. New in v7: names may swap (A→B and B→A), and quick tools
// change every line at once: find and replace, add before or after, number, upper or lower case.
import 'dart:io';

import 'package:path/path.dart' as p;

import 'disk.dart';
import 'file_ops.dart';
import 'names.dart';

class RenameLine {
  const RenameLine(this.from, this.to, this.path);
  final String from;
  final String to;
  final String path;
}

class RenamePlan {
  final changes = <RenameLine>[];
  final problems = <(String, String)>[];

  /// Set when the box has a different number of lines
  String? countProblem;
  bool get ok => countProblem == null && problems.isEmpty;
}

/// The lines in the box, without empty ones, trimmed (as v6.2 read them)
List<String> boxLines(String text) =>
    text.split('\n').map((l) => l.replaceAll('\r', '').trim()).where((l) => l.isNotEmpty).toList();

/// Compares the box with the names listed; [exists] says whether a name is in the folder
RenamePlan planRenames(List<Entry> listed, String text, bool Function(String name) exists) {
  final plan = RenamePlan();
  final lines = boxLines(text);
  if (lines.length != listed.length) {
    plan.countProblem =
        'Listed in the folder: ${listed.length}, lines in the box: ${lines.length}.\n'
        'Renaming works line by line, so edit the lines but don\'t add or remove any.';
    return plan;
  }
  final renamedFrom = <String>{};
  for (var i = 0; i < lines.length; i++) {
    if (lines[i] != listed[i].name) renamedFrom.add(listed[i].name.toLowerCase());
  }
  final finalNames = <String>{};
  for (var i = 0; i < lines.length; i++) {
    final key = lines[i].toLowerCase();
    if (!finalNames.add(key)) plan.problems.add((lines[i], 'appears twice'));
  }
  for (var i = 0; i < lines.length; i++) {
    final to = lines[i], from = listed[i].name;
    if (to == from) continue;
    final problem = nameProblem(to);
    if (problem != null) {
      plan.problems.add((to, problem));
      continue;
    }
    final key = to.toLowerCase();
    // free if it isn't on the disk, is this item's own name in other case, or is being renamed away
    if (exists(to) && key != from.toLowerCase() && !renamedFrom.contains(key)) {
      plan.problems.add((to, 'already exists in this folder'));
      continue;
    }
    plan.changes.add(RenameLine(from, to, listed[i].path));
  }
  return plan;
}

/// APPLY RENAMES. When a new name is another item's old name, everything goes through a
/// temporary name first so nothing collides.
Future<(int, List<(String, String)>, UndoStep)> applyRenames(RenamePlan plan, String folder) async {
  final undo = UndoStep('rename ${plan.changes.length} items');
  final failed = <(String, String)>[];
  final olds = {for (final c in plan.changes) c.from.toLowerCase()};
  final swap = plan.changes.any((c) => olds.contains(c.to.toLowerCase()) && c.to.toLowerCase() != c.from.toLowerCase());
  var done = 0;
  if (!swap) {
    for (final c in plan.changes) {
      final why = await renameItem(c.path, c.to, undo: undo);
      if (why == null) {
        done++;
      } else {
        failed.add((c.from, why));
      }
    }
    return (done, failed, undo);
  }
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final temps = <(RenameLine, String)>[];
  for (var i = 0; i < plan.changes.length; i++) {
    final c = plan.changes[i];
    final tmp = p.join(folder, '~pfm-$stamp-$i');
    try {
      await (FileSystemEntity.isDirectorySync(c.path) ? Directory(c.path).rename(tmp) : File(c.path).rename(tmp));
      undo.moves.add((c.path, tmp));
      temps.add((c, tmp));
    } catch (e) {
      failed.add((c.from, e is FileSystemException ? (e.osError?.message ?? e.message) : '$e'));
    }
  }
  for (final (c, tmp) in temps) {
    final to = p.join(folder, c.to);
    try {
      await (FileSystemEntity.isDirectorySync(tmp) ? Directory(tmp).rename(to) : File(tmp).rename(to));
      undo.moves.add((tmp, to));
      done++;
    } catch (e) {
      failed.add((
        c.from,
        'kept as ${p.basename(tmp)}: ${e is FileSystemException ? (e.osError?.message ?? e.message) : '$e'}',
      ));
    }
  }
  return (done, failed, undo);
}

// ---- quick tools: each changes every line of the box ----

(String, String) _split(String name, bool keepExt) {
  final dot = name.lastIndexOf('.');
  if (!keepExt || dot <= 0) return (name, '');
  return (name.substring(0, dot), name.substring(dot));
}

List<String> findReplace(List<String> lines, String find, String replace, {bool matchCase = false}) {
  if (find.isEmpty) return lines;
  final re = RegExp(RegExp.escape(find), caseSensitive: matchCase);
  return [for (final l in lines) l.replaceAll(re, replace)];
}

List<String> addText(List<String> lines, {String before = '', String after = '', bool keepExt = true}) => [
  for (final l in lines)
    () {
      final (b, e) = _split(l, keepExt);
      return '$before$b$after$e';
    }(),
];

/// "01 name", "02 name" …; [start], [step] and [digits] like Explorer's numbering
List<String> number(
  List<String> lines, {
  int start = 1,
  int step = 1,
  int digits = 2,
  String separator = '_',
  bool atStart = true,
  bool keepExt = true,
}) => [
  for (var i = 0; i < lines.length; i++)
    () {
      final n = (start + i * step).toString().padLeft(digits, '0');
      final (b, e) = _split(lines[i], keepExt);
      return atStart ? '$n$separator$b$e' : '$b$separator$n$e';
    }(),
];

enum CaseChange { upper, lower, title }

List<String> changeCase(List<String> lines, CaseChange c, {bool keepExt = true}) => [
  for (final l in lines)
    () {
      final (b, e) = _split(l, keepExt);
      final out = switch (c) {
        CaseChange.upper => b.toUpperCase(),
        CaseChange.lower => b.toLowerCase(),
        CaseChange.title => b.replaceAllMapped(
          RegExp(r"[A-Za-z][A-Za-z']*"),
          (m) => m[0]![0].toUpperCase() + m[0]!.substring(1).toLowerCase(),
        ),
      };
      return '$out$e';
    }(),
];

/// Spaces become underscores, or the other way round
List<String> swapSpaces(List<String> lines, {bool toUnderscore = true}) => [
  for (final l in lines) toUnderscore ? l.replaceAll(' ', '_') : l.replaceAll('_', ' '),
];
