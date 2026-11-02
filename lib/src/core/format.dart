// Sizes, dates and the clock, written the way v6.2 wrote them.

/// A file's size: "512 B", "48 KB", "2.1 MB", "1.4 GB"
String fileSize(int? bytes) {
  if (bytes == null) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1048576) return '${(bytes / 1024).round()} KB';
  if (bytes < 1073741824) return '${(bytes / 104857.6).round() / 10} MB';
  return '${(bytes / 107374182.4).round() / 10} GB';
}

/// A drive's size: "75 GB", "8.4 GB", "1.8 TB"
String driveSize(int bytes) {
  if (bytes <= 0) return '0 GB';
  final g = bytes / 1073741824;
  if (g >= 1024) return '${(g / 102.4).round() / 10} TB';
  if (g >= 10) return '${g.round()} GB';
  return '${(g * 10).round() / 10} GB';
}

String two(int n) => n.toString().padLeft(2, '0');

const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "15:38:59"
String clockText(DateTime d) => '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';

/// "Friday, 16 October 2026"
String longDate(DateTime d) => '${weekdays[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';

/// "16 Oct 2026 15:38": a file's date in the side panel
String shortDateTime(DateTime d) =>
    '${d.day} ${months[d.month - 1].substring(0, 3)} ${d.year} ${two(d.hour)}:${two(d.minute)}';

/// How long ago, for the index: "just now", "5 min ago", "3 h ago", "2 days ago"
String ago(DateTime then, DateTime now) {
  final d = now.difference(then);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  final days = d.inDays;
  return days == 1 ? '1 day ago' : '$days days ago';
}

/// The weeks of a month for the little calendar, Sunday first like v6.2: each week is seven day
/// numbers, 0 where the day belongs to the month before or after.
List<List<int>> monthGrid(int year, int month) {
  final first = DateTime(year, month, 1).weekday % 7; // Sunday = 0
  final days = DateTime(year, month + 1, 0).day;
  final weeks = <List<int>>[];
  var day = 1 - first;
  while (day <= days) {
    weeks.add([for (var i = 0; i < 7; i++, day++) (day >= 1 && day <= days) ? day : 0]);
  }
  return weeks;
}

/// "1 item", "3 items"
String plural(int n, String one, [String? many]) => '$n ${n == 1 ? one : (many ?? '${one}s')}';
