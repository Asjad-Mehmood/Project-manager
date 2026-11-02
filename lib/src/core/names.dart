// What Windows allows as a file or folder name. v6.2 only caught \ / : * ? " < > |; Windows
// also refuses names that end in a dot or a space, and the old device names (CON, NUL, COM1 …).

const illegalCharacters = r'\ / : * ? " < > |';
final _illegal = RegExp(r'[\\/:*?"<>|\x00-\x1F]');
final _reserved = RegExp(r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\..*)?$', caseSensitive: false);

/// Longest name the program lets you type (v6.2's limit)
const maxNameLength = 120;

/// Why [name] can't be used, or null when it can
String? nameProblem(String name) {
  if (name.trim().isEmpty) return 'the name is empty';
  if (name != name.trim()) return 'the name starts or ends with a space';
  if (_illegal.hasMatch(name)) return 'it has a character Windows doesn\'t allow:  $illegalCharacters';
  if (name.endsWith('.')) return 'Windows doesn\'t allow a name that ends with a dot';
  if (name == '.' || name == '..') return 'that name is reserved';
  if (_reserved.hasMatch(name)) return '"${name.split('.').first.toUpperCase()}" is reserved by Windows';
  if (name.length > maxNameLength) return 'the name is longer than $maxNameLength characters';
  return null;
}

/// "Report.pdf" → "Report (2).pdf", the first free one; [taken] says whether a name is used
String freeName(String name, bool Function(String candidate) taken) {
  final dot = name.lastIndexOf('.');
  final base = dot > 0 ? name.substring(0, dot) : name;
  final ext = dot > 0 ? name.substring(dot) : '';
  for (var i = 2; i < 1000; i++) {
    final c = '$base ($i)$ext';
    if (!taken(c)) return c;
  }
  return '$base (${DateTime.now().millisecondsSinceEpoch})$ext';
}
