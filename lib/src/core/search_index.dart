// The INDEX: every folder (and file) under the project, a drive or all drives, read once so that
// searching afterwards is instant. The file format is v6.2's: one "F<tab>path" (folder) or
// "X<tab>path" (file) line per item, after a first line saying what was indexed. v7 adds when.
import 'dart:convert';

import 'package:path/path.dart' as p;

import 'disciplines.dart';
import 'disk.dart';

/// The most items an index holds (v6.2's limit)
const indexCap = 400000;

enum Kind { all, folders, files }

class Hit {
  const Hit(this.path, this.isFile);
  final String path;
  final bool isFile;
  String get name => p.basename(path);
}

class SearchResult {
  const SearchResult(this.hits, this.total);
  final List<Hit> hits;

  /// Every match, also the ones past the limit
  final int total;
}

class SearchIndex {
  SearchIndex({this.scope = 'project', this.built, this.root = ''});

  /// "project", a drive such as "D:\", or "all drives"
  String scope;
  DateTime? built;

  /// The project root it was made for
  String root;

  final _paths = <String>[];
  final _isFile = <bool>[];
  final _names = <String>[]; // lower case, for searching

  int get length => _paths.length;
  bool get isEmpty => _paths.isEmpty;

  void add(String path, bool isFile) {
    _paths.add(path);
    _isFile.add(isFile);
    _names.add(p.basename(path).toLowerCase());
  }

  /// "F\tD:\Project\10_Survey" / "X\tD:\Project\10_Survey\a.pdf"
  void addLine(String line) {
    if (line.length < 3 || line[1] != '\t') return;
    final k = line[0];
    if (k != 'F' && k != 'X') return;
    add(line.substring(2), k == 'X');
  }

  /// Search the names: every word must be in the name. Exact names first, then names that start
  /// with the first word, then the rest; at most [limit] are returned.
  SearchResult search(
    String query, {
    int limit = 400,
    Kind kind = Kind.all,
    bool Function(String path)? where,
    String type = '',
  }) {
    final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return const SearchResult([], 0);
    final q = query.trim().toLowerCase();
    final exact = <Hit>[], starts = <Hit>[], rest = <Hit>[];
    var total = 0;
    for (var i = 0; i < _paths.length; i++) {
      final n = _names[i];
      var ok = true;
      for (final w in words) {
        if (!n.contains(w)) {
          ok = false;
          break;
        }
      }
      if (!ok) continue;
      final f = _isFile[i];
      if (kind == Kind.folders && f || kind == Kind.files && !f) continue;
      if (type.isNotEmpty && (!f || extOf(n) != type)) continue;
      if (where != null && !where(_paths[i])) continue;
      total++;
      final bucket = n == q ? exact : (n.startsWith(words.first) ? starts : rest);
      if (bucket.length < limit) bucket.add(Hit(_paths[i], f));
    }
    final hits = [...exact, ...starts, ...rest];
    return SearchResult(hits.length > limit ? hits.sublist(0, limit) : hits, total);
  }

  /// Something was renamed or moved inside the program: its entry and everything under it follow
  void moved(String from, String to) {
    final fromKey = pathKey(from);
    for (var i = 0; i < _paths.length; i++) {
      final k = pathKey(_paths[i]);
      if (k == fromKey) {
        _paths[i] = to;
        _names[i] = p.basename(to).toLowerCase();
      } else if (isSameOrInside(_paths[i], from)) {
        _paths[i] = to + _paths[i].substring(from.length);
      }
    }
  }

  /// Something was deleted: its entry and everything under it go
  void removed(String path) {
    for (var i = _paths.length - 1; i >= 0; i--) {
      if (isSameOrInside(_paths[i], path)) {
        _paths.removeAt(i);
        _isFile.removeAt(i);
        _names.removeAt(i);
      }
    }
  }

  bool contains(String path) {
    final k = pathKey(path);
    return _paths.any((x) => pathKey(x) == k);
  }

  String serialize() {
    final b = StringBuffer()
      ..write(scope)
      ..write('\t#v7')
      ..write(built != null ? '\t${built!.toIso8601String()}' : '\t')
      ..write('\t$root\n');
    for (var i = 0; i < _paths.length; i++) {
      b
        ..write(_isFile[i] ? 'X\t' : 'F\t')
        ..write(_paths[i])
        ..write('\n');
    }
    return b.toString();
  }

  /// Reads v7's file and v6.2's Project_Folder_Manager_index.txt
  static SearchIndex parse(String text) {
    final lines = const LineSplitter().convert(text);
    final idx = SearchIndex();
    if (lines.isEmpty) return idx;
    final head = lines.first.split('\t');
    idx.scope = head.first.trim().isEmpty ? 'project' : head.first.trim();
    if (head.length >= 3 && head[1] == '#v7') {
      idx.built = DateTime.tryParse(head[2]);
      if (head.length >= 4) idx.root = head[3];
    }
    for (final ln in lines.skip(1)) {
      idx.addLine(ln.trimRight());
    }
    return idx;
  }

  /// "this project", "drive D:", "all drives"
  String get scopeName {
    if (scope == 'project' || scope.isEmpty) return 'this project';
    if (scope == 'all drives') return 'all drives';
    return 'drive ${scope.substring(0, scope.length >= 2 ? 2 : scope.length)}';
  }
}
