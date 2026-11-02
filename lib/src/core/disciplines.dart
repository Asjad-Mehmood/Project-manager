// Disciplines and their colours, the numbered modules' defaults, and the colour of each file
// type's chip: the same lists as v6.2.
import 'dart:ui' show Color;

/// Every discipline a module can have, in the order the picker shows them
const disciplines = <String, Color>{
  'Admin': Color(0xFF8899A6),
  'Survey': Color(0xFF13A8A8),
  'Piping': Color(0xFF2BB7C9),
  'Electrical': Color(0xFFE8A33D),
  'Telecom': Color(0xFF9B7BD4),
  'Civil Works': Color(0xFF5CB85C),
  'Utilities': Color(0xFF7FB069),
  'Facilities': Color(0xFF4A90D9),
  'Roads': Color(0xFFC39B7B),
  'Design & Drawings': Color(0xFF3DA5D9),
  'Archive': Color(0xFFA98467),
  'Mechanical': Color(0xFF4A90D9),
  'HSE': Color(0xFFE8734A),
  'QA / QC': Color(0xFFD4C13D),
  'Documents & Reports': Color(0xFFC39B7B),
  'Correspondence': Color(0xFFE85A9B),
  uncategorised: Color(0xFF6C7A89),
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
  'dwg': Color(0xFFF5A524),
  'dxf': Color(0xFFF5A524),
  'pdf': Color(0xFFE8574A),
  'xls': Color(0xFF5CB85C),
  'xlsx': Color(0xFF5CB85C),
  'xlsm': Color(0xFF5CB85C),
  'csv': Color(0xFF5CB85C),
  'doc': Color(0xFF4A90D9),
  'docx': Color(0xFF4A90D9),
  'ppt': Color(0xFFE8734A),
  'pptx': Color(0xFFE8734A),
  'jpg': Color(0xFFB07BD4),
  'jpeg': Color(0xFFB07BD4),
  'png': Color(0xFFB07BD4),
  'tif': Color(0xFFB07BD4),
  'zip': Color(0xFF8899A6),
  'rar': Color(0xFF8899A6),
  'txt': Color(0xFF9FB6C7),
  'kml': Color(0xFF13A8A8),
  'kmz': Color(0xFF13A8A8),
  'gsi': Color(0xFF13A8A8),
  'dat': Color(0xFF13A8A8),
  'xml': Color(0xFFC39B7B),
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
