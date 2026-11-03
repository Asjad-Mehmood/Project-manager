// The manual: how to use the program, inside the program. Opened from MANUAL in the top bar,
// with F1, or from the start page. Topics down the left, the chosen one on the right; on a narrow
// window the topics sit in a row above.
import 'package:flutter/material.dart';

import '../../brand.dart';
import '../theme.dart';
import '../widgets.dart';

class _Topic {
  const _Topic(this.icon, this.title, this.intro, this.steps);
  final IconData icon;
  final String title;
  final String intro;

  /// (what you see or press, what it does)
  final List<(String, String)> steps;
}

const _topics = [
  _Topic(
    Icons.rocket_launch_outlined,
    'Getting started',
    'Open a drive or a folder, and the program shows the folders in it.',
    [
      (
        'First time',
        'The start page shows your drives: click one to open it. Or CHOOSE A FOLDER, TYPE A PATH, or FIND PROJECTS to look on every drive for project folders.',
      ),
      (
        'Change the folder',
        'Click the folder name at the top left. The menu has your recent folders, every drive, Choose a folder, Type a path and Find projects.',
      ),
      ('Rename it here', 'In the same menu: the name shown at the top changes; nothing on the disk changes.'),
      ('Remove from the list', 'Takes a folder off the recent list. The folder itself stays on the disk.'),
      (
        'Empty folder',
        'A folder with nothing inside offers to make the standard project folders, 00_Admin to 99_Archive.',
      ),
    ],
  ),
  _Topic(
    Icons.folder_copy_outlined,
    'The folder list',
    'Each folder inside the open folder, with its discipline. The list follows the disk by itself: folders made, renamed or deleted in Explorer show up within a few seconds.',
    [
      ('Folder name or VIEW', 'Shows the folder in the side panel.'),
      ('OPEN or double-click', 'Opens the folder in Windows Explorer.'),
      (
        'The arrow',
        'Opens the folder\'s sub-folders under it. EXPAND ALL opens everything three levels deep; COLLAPSE closes it all.',
      ),
      (
        'The coloured chip',
        'Its discipline (Survey, Piping, Civil Works …). Click it to choose another; it is remembered by folder name.',
      ),
      ('"3 sub"', 'How many folders are inside.'),
      ('Right-click', 'More: open, view, new folder inside, rename, pin, copy the path, properties.'),
      ('Refresh (F5)', 'Reads the disk again straight away.'),
    ],
  ),
  _Topic(Icons.search, 'Search', 'Find any folder or file in seconds.', [
    ('Type in the search box', 'Filters the folder list as you type. Ctrl+F jumps to the box; Esc clears it.'),
    (
      'DEEP',
      'Turn it on to search every folder and file in the index, not just the list. Every word you type must be in the name, in any order.',
    ),
    ('ALL / FOLDERS / FILES', 'Above DEEP results: show only folders or only files.'),
    ('All disciplines', 'The list next to the search box shows one discipline only.'),
    ('In a result', 'VIEW shows it in the panel (a file is selected in its folder); OPEN or double-click opens it.'),
  ]),
  _Topic(
    Icons.bolt,
    'The index',
    'The index is a list of every folder and file, read once so that DEEP search is instant.',
    [
      (
        'By itself',
        'The open folder is indexed in the background when it is new or the index is more than 12 hours old. You can keep working.',
      ),
      (
        'INDEX ▾',
        'Index this folder, the whole drive or all drives. While it runs the button shows the percentage; Stop keeps what was found.',
      ),
      ('Files too / Levels deep', 'In the same menu: whether files are indexed, and how many folder levels deep.'),
      ('Above the list', 'Shows how many items are indexed and how long ago.'),
    ],
  ),
  _Topic(
    Icons.view_sidebar_outlined,
    'The side panel',
    'One folder\'s contents, to work with its files without leaving the program.',
    [
      (
        'Back, forward, up',
        'The arrows at the top (Alt+Left, Alt+Right, Backspace). The path under the name is clickable.',
      ),
      (
        'Filter, SHOW, SORT',
        'Narrow the list by name, show folders or files only or one file type, and sort by name, type, size or date.',
      ),
      (
        'Select',
        'Click; Ctrl+click for more; Shift+click for a range; Ctrl+A for all; the arrow keys too. Esc selects none.',
      ),
      (
        'COPY, CUT, PASTE HERE',
        'Appear when something is selected (Ctrl+C, Ctrl+X, Ctrl+V). When a name is already there you choose: replace, keep both or skip.',
      ),
      ('Drag and drop', 'Drag items onto any folder in the list or the panel to move them there.'),
      ('RENAME (F2), DELETE', 'Delete sends items to the Recycle Bin, after asking.'),
      ('NEW FOLDER, EXPLORER', 'Make a folder here, or open this folder in Explorer.'),
      ('UNDO (Ctrl+Z)', 'Undoes the last renames, moves, copies and new folders, one step at a time.'),
    ],
  ),
  _Topic(
    Icons.edit_note,
    'LIST / EDIT',
    'Every name in the panel\'s folder in a box: copy the list, or rename many at once.',
    [
      ('Copy the list', 'Select the text and copy it, for a report or an email.'),
      (
        'Rename many',
        'Edit the lines (one name per line, same order). The preview shows every change and any problem before anything is renamed.',
      ),
      (
        'Quick tools',
        'Find and replace, add text before or after, number 01_ 02_ …, and change case, for every line at once.',
      ),
      ('APPLY RENAMES', 'Renames them all after you confirm. UNDO puts them back.'),
    ],
  ),
  _Topic(Icons.dashboard_outlined, 'Views, pins and drives', 'Arrange the window the way you like it.', [
    (
      'View ▾ (the small picture)',
      'Six layouts: tree only, tree wide, side by side, panel wide, above and below, panel only. Alt+1 to Alt+6.',
    ),
    ('Drives strip', 'In the View menu: every drive with its free space; click one to see it in the panel.'),
    (
      'GO TO ▾',
      'Your pinned folders and every drive. Pin a folder by right-clicking it, or with the star in the panel.',
    ),
    ('The clock', 'Top right; click it for the calendar.'),
  ]),
  _Topic(Icons.keyboard_outlined, 'Keyboard', 'Shortcuts, anywhere and in the panel.', [
    ('F1', 'This manual'),
    ('Alt+1 … Alt+6', 'The six views'),
    ('Ctrl+F', 'Search'),
    ('F5', 'Read the disk again'),
    ('Up / Down', 'Move in the panel (Shift: select more)'),
    ('Enter', 'Open'),
    ('Backspace', 'The folder above'),
    ('Alt+Left / Right', 'Back / forward'),
    ('Ctrl+A, Esc', 'Select all, select none'),
    ('Ctrl+C / X / V', 'Copy, cut, paste'),
    ('F2, Delete', 'Rename; to the Recycle Bin'),
    ('Ctrl+Z', 'Undo'),
  ]),
  _Topic(Icons.system_update_alt, 'Updates and settings', 'The program looks after itself.', [
    (
      'Updates',
      'A few seconds after it opens, the program checks for a new version and offers it. ⋯ → Look for an update checks now.',
    ),
    (
      'Settings from 6.2',
      '⋯ → Bring in settings from 6.2 reads the old Project_Folder_Manager_config.txt (folder, title, disciplines, view).',
    ),
    (
      'Where things are kept',
      'Settings in %APPDATA%\\Excel to KML\\Project Folder Manager, the index in %LOCALAPPDATA%\\Excel to KML\\Project Folder Manager.',
    ),
    ('Uninstall', 'Windows Settings → Apps → Project Folder Manager.'),
  ]),
];

/// Opens the manual, at [topic] if given
Future<void> showManual(BuildContext context, {int topic = 0}) => showDialog<void>(
  context: context,
  builder: (c) => _Manual(start: topic),
);

class _Manual extends StatefulWidget {
  const _Manual({required this.start});
  final int start;
  @override
  State<_Manual> createState() => _ManualState();
}

class _ManualState extends State<_Manual> {
  late int _at = widget.start;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _go(int i) {
    setState(() => _at = i);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 820;
    return Dialog(
      backgroundColor: C.dialog,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: C.fieldEdge),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 940, maxHeight: size.height * .86),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _head(),
            const Divider(height: 1, color: C.topEdge),
            Flexible(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 230, child: _nav()),
                        const VerticalDivider(width: 1, color: C.topEdge),
                        Expanded(child: _page()),
                      ],
                    )
                  : Column(
                      children: [
                        SizedBox(height: 46, child: _nav(row: true)),
                        const Divider(height: 1, color: C.topEdge),
                        Expanded(child: _page()),
                      ],
                    ),
            ),
            const Divider(height: 1, color: C.topEdge),
            _foot(),
          ],
        ),
      ),
    );
  }

  Widget _head() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 10, 14),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: C.mark,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: C.teal.withValues(alpha: .45)),
          ),
          child: const Icon(Icons.menu_book_outlined, size: 18, color: C.tealHi),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manual',
                style: t(17, color: C.title, w: FontWeight.w600),
              ),
              Text('How to use $appName', style: t(11, color: C.subtitle)),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Close  (Esc)',
          icon: const Icon(Icons.close, size: 18, color: C.label),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    ),
  );

  Widget _nav({bool row = false}) => ListView(
    scrollDirection: row ? Axis.horizontal : Axis.vertical,
    padding: const EdgeInsets.all(8),
    children: [
      for (var i = 0; i < _topics.length; i++)
        Hover(
          cursor: SystemMouseCursors.click,
          builder: (context, h) => GestureDetector(
            onTap: () => _go(i),
            child: Container(
              margin: row ? const EdgeInsets.only(right: 4) : const EdgeInsets.only(bottom: 2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: i == _at ? C.teal.withValues(alpha: .16) : (h ? C.rowHoverTop : null),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: row ? MainAxisSize.min : MainAxisSize.max,
                children: [
                  Icon(_topics[i].icon, size: 16, color: i == _at ? C.tealHi : C.label),
                  const SizedBox(width: 10),
                  Text(
                    _topics[i].title,
                    style: t(12.5, color: i == _at ? C.title : C.soft, w: i == _at ? FontWeight.w600 : null),
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );

  Widget _page() {
    final tp = _topics[_at];
    return Scrollbar(
      controller: _scroll,
      child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        children: [
          Row(
            children: [
              Icon(tp.icon, size: 22, color: C.tealHi),
              const SizedBox(width: 10),
              Text(
                tp.title,
                style: t(19, color: C.title, w: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(tp.intro, style: t(13, color: C.soft, h: 1.5)),
          const SizedBox(height: 16),
          for (final (what, does) in tp.steps)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                color: C.rowTop,
                border: Border.all(color: C.rowEdge),
                borderRadius: BorderRadius.circular(8),
              ),
              child: LayoutBuilder(
                builder: (context, box) {
                  final label = Text(
                    what,
                    style: t(12.5, color: C.tealHi, w: FontWeight.w600, h: 1.45),
                  );
                  final text = Text(does, style: t(12.5, color: C.text, h: 1.45));
                  if (box.maxWidth < 460) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [label, const SizedBox(height: 3), text],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 170, child: label),
                      const SizedBox(width: 12),
                      Expanded(child: text),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _foot() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 14, 10),
    child: Row(
      children: [
        Text('${_at + 1} of ${_topics.length}', style: t(11, color: C.muted)),
        const Spacer(),
        Btn('PREVIOUS', icon: Icons.chevron_left, kind: BtnKind.ghost, onTap: _at == 0 ? null : () => _go(_at - 1)),
        const SizedBox(width: 4),
        _at == _topics.length - 1
            ? Btn('DONE', kind: BtnKind.on, onTap: () => Navigator.pop(context))
            : Btn('NEXT', trailing: Icons.chevron_right, kind: BtnKind.on, onTap: () => _go(_at + 1)),
      ],
    ),
  );
}
