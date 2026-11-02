// Disciplines and their colours, the numbered modules' defaults, and the colour of each file
// type's chip: the same lists as v6.2.
import 'dart:ui' show Color;

/// Every discipline a module can have, in the order the picker shows them
const disciplines = <String, Color>{
  'Admin': Color(0xFF8E9BA8),
  'Survey': Color(0xFF5FB0AB),
  'Piping': Color(0xFF6CADBC),
  'Electrical': Color(0xFFCDA86C),
  'Telecom': Color(0xFFA197C6),
  'Civil Works': Color(0xFF87AE82),
  'Utilities': Color(0xFF9DB38E),
  'Facilities': Color(0xFF7D9CC4),
  'Roads': Color(0xFFBDA38E),
  'Design & Drawings': Color(0xFF79A8C6),
  'Archive': Color(0xFFAA9583),
  'Mechanical': Color(0xFF8798C2),
  'HSE': Color(0xFFC7917D),
  'QA / QC': Color(0xFFC0B47A),
  'Documents & Reports': Color(0xFFB9A792),
  'Correspondence': Color(0xFFC291A9),
  uncategorised: Color(0xFF7D8894),
};

const uncategorised = 'Uncategorised';

/// The eleven numbered modules of a standard project, and the discipline each one starts with
const standardModules = <(String, String)>[
  ('00', 'Admin'),
  ('10', 'Survey'),
  ('20', 'Piping'),
  ('30', 'Electrical'),
  ('40', 'Telecom'),
  ('50', 'Civil Works'),
  ('60', 'Utilities'),
  ('70', 'Facilities'),
  ('80', 'Roads'),
  ('90', 'Design & Drawings'),
  ('99', 'Archive'),
];

/// The folder names of a new standard project: "00_Admin", "50_Civil Works" … "99_Archive"
List<String> standardFolderNames() => [for (final (n, d) in standardModules) '${n}_$d'];

Color disciplineColor(String discipline) => disciplines[discipline] ?? disciplines[uncategorised]!;

/// The discipline a folder starts with, from its two-digit number: "10_Survey" → Survey
String guessDiscipline(String folderName) {
  final t = folderName.trim();
  final k = t.length >= 2 ? t.substring(0, 2) : t;
  for (final (n, d) in standardModules) {
    if (n == k) return d;
  }
  return uncategorised;
}

const _extColors = <String, Color>{
  'dwg': Color(0xFFCDA86C),
  'dxf': Color(0xFFCDA86C),
  'pdf': Color(0xFFC98479),
  'xls': Color(0xFF87AE82),
  'xlsx': Color(0xFF87AE82),
  'xlsm': Color(0xFF87AE82),
  'csv': Color(0xFF87AE82),
  'doc': Color(0xFF7D9CC4),
  'docx': Color(0xFF7D9CC4),
  'ppt': Color(0xFFC7917D),
  'pptx': Color(0xFFC7917D),
  'jpg': Color(0xFFA197C6),
  'jpeg': Color(0xFFA197C6),
  'png': Color(0xFFA197C6),
  'tif': Color(0xFFA197C6),
  'zip': Color(0xFF8E9BA8),
  'rar': Color(0xFF8E9BA8),
  'txt': Color(0xFF9FB6C7),
  'kml': Color(0xFF5FB0AB),
  'kmz': Color(0xFF5FB0AB),
  'gsi': Color(0xFF5FB0AB),
  'dat': Color(0xFF5FB0AB),
  'xml': Color(0xFFBDA38E),
};

/// A file's extension, lower case, without the dot; '' when it has none (".gitignore" has none)
String extOf(String name) {
  final i = name.lastIndexOf('.');
  return i > 0 ? name.substring(i + 1).toLowerCase() : '';
}

/// The colour of a file type's chip, or null for the plain grey one
Color? extColor(String ext) => _extColors[ext.toLowerCase()];

/// What a file type's chip says: "DWG", "FILE" when there is none, at most five letters
String extLabel(String name) {
  final e = extOf(name);
  if (e.isEmpty) return 'FILE';
  return (e.length > 5 ? e.substring(0, 5) : e).toUpperCase();
}
