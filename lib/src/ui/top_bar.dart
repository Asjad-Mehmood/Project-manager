// The top of the window, in one calm bar (7.1, in place of 6.2's banner and toolbar):
//   [▣ Folder name ▾]   [🔍 Search …            DEEP] [Discipline ▾]    INDEX ▾  GO TO ▾  [▣ ▾]  ⋯   15:38
//                                                                                                Fri 16 Oct
//   Folder ▾   recent folders, open a drive, choose a folder, type a path, find projects;
//              this folder: Explorer, rename, remove from the list
//   INDEX ▾    this folder / whole drive / all drives, STOP, and how the index is made
//   GO TO ▾    pinned folders and every drive, in the panel
//   ▣ ▾        the six layouts (Alt+1 … Alt+6) and the drives strip
//   ⋯          bring in 6.2 settings, updates, shortcuts, about
//   15:38      the clock; click it for the calendar
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../core/disciplines.dart';
import '../core/format.dart';
import '../core/settings.dart';
import '../platform/shell.dart';
import '../state/app_model.dart';
import 'commands.dart';
import 'theme.dart';
import 'widgets.dart';

class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.model,
    required this.cmd,
    required this.searchField,
    required this.searchFocus,
    required this.onCheckUpdates,
    this.clock,
  });

  final AppModel model;
  final Commands cmd;
  final TextEditingController searchField;
  final FocusNode searchFocus;
  final VoidCallback onCheckUpdates;

  /// A fixed time, for screenshots
  final DateTime? clock;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) => _build(box.maxWidth));

  Widget _build(double w) {
    final compact = w < 1180;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 9, 16, 9),
      decoration: const BoxDecoration(
        color: C.top,
        border: Border(bottom: BorderSide(color: C.topEdge)),
      ),
      child: Row(
        children: [
          _FolderSwitcher(model: model, cmd: cmd, width: (w * .26).clamp(200, 360)),
          if (model.project == null) ...[
            // nothing open yet: only what helps to start
            const Spacer(),
            _manual(false),
            _more(),
            ..._clock(w),
          ] else
            ..._tools(w, compact),
        ],
      ),
    );
  }

  List<Widget> _clock(double w) => [
    if (w >= 1000) ...[
      Container(width: 1, height: 28, margin: const EdgeInsets.only(left: 10, right: 12), color: C.topEdge),
      Clock(fixed: clock),
    ],
  ];

  List<Widget> _tools(double w, bool compact) => [
    const SizedBox(width: 14),
    Expanded(
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: _search()),
      ),
    ),
    if (w >= 900) ...[
      const SizedBox(width: 8),
      Select<String>(
        value: model.discipline,
        items: ['', ...disciplines.keys],
        label: (d) => d.isEmpty ? 'All disciplines' : d,
        onChanged: model.filterDiscipline,
        width: compact ? 140 : 160,
        tip: 'Show one discipline only',
      ),
    ],
    const SizedBox(width: 12),
    _index(compact),
    _goTo(compact),
    _ViewPicker(model: model, cmd: cmd),
    _manual(compact),
    _more(),
    ..._clock(w),
  ];

  void _clear() {
    searchField.clear();
    model.setQuery('');
  }

  Widget _search() {
    final deep = model.options.deep;
    return SizedBox(
      height: 34,
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _clear},
        child: TextField(
          controller: searchField,
          focusNode: searchFocus,
          style: t(13),
          onChanged: model.setQuery,
          decoration:
              fieldDecoration(
                hint: deep && !model.index.isEmpty
                    ? 'Search every folder and file   Ctrl+F'
                    : 'Search folders   Ctrl+F',
              ).copyWith(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                hintStyle: t(13, color: C.muted),
                prefixIcon: const Icon(Icons.search, size: 18, color: C.label),
                prefixIconConstraints: const BoxConstraints(minWidth: 34),
                suffixIconConstraints: const BoxConstraints(minHeight: 30),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (model.query.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear  (Esc)',
                        iconSize: 15,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        icon: const Icon(Icons.close, color: C.label),
                        onPressed: _clear,
                      ),
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Btn(
                        'DEEP',
                        small: true,
                        kind: BtnKind.ghost,
                        lit: deep,
                        onTap: () => model.setDeep(!deep),
                        tip: deep
                            ? 'On: searching every folder and file in the index'
                            : 'Off: searching the folder names in the list. Click to search everything',
                      ),
                    ),
                  ],
                ),
              ),
        ),
      ),
    );
  }

  Widget _index(bool compact) {
    final o = model.options;
    final idx = model.index;
    final pg = model.progress;
    final drive = p.rootPrefix(model.root);
    return MenuBtn(
      model.indexing ? '${pg?.percent ?? 0}%' : (compact ? '' : 'INDEX'),
      icon: Icons.bolt,
      lit: model.indexing,
      tip: idx.isEmpty
          ? 'Index: not made yet, so search finds folder names only'
          : 'Index: ${idx.length} items in ${idx.scopeName}'
                '${idx.built == null ? '' : ', made ${ago(idx.built!, model.now())}'}',
      items: () => [
        if (model.indexing) ...[
          menuItem('Stop, and keep what was found', model.stopIndex, icon: Icons.stop),
          const PopupMenuDivider(height: 8),
        ],
        menuHeading('READ EVERYTHING ONCE, SO SEARCH IS INSTANT'),
        menuItem(
          'Index this folder',
          model.indexing ? null : () => cmd.index(IndexScope.project),
          icon: Icons.folder_outlined,
          checked: !idx.isEmpty && idx.scope == 'project',
        ),
        menuItem(
          'Index the whole drive${drive.isEmpty ? '' : '  ($drive)'}',
          model.indexing ? null : () => cmd.index(IndexScope.drive),
          icon: Icons.storage,
          checked: !idx.isEmpty && idx.scope != 'project' && idx.scope != 'all drives',
        ),
        menuItem(
          'Index all drives',
          model.indexing ? null : () => cmd.index(IndexScope.allDrives),
          icon: Icons.dns_outlined,
          checked: !idx.isEmpty && idx.scope == 'all drives',
        ),
        const PopupMenuDivider(height: 8),
        menuItem(
          'Index the folder by itself',
          () => model.setAutoIndex(!o.autoIndex),
          on: o.autoIndex,
          sub: 'in the background, when it is new or more than ${staleAfter.inHours} hours old',
        ),
        menuItem('Files too, not only folders', () {
          o.files = !o.files;
          model.optionsChanged();
        }, on: o.files),
        menuItem(
          'Levels deep: ${o.depth}',
          () {
            const steps = [3, 6, 10, 20];
            o.depth = steps[(steps.indexOf(o.depth) + 1) % steps.length];
            model.optionsChanged();
          },
          icon: Icons.layers_outlined,
          sub: 'click for 3, 6, 10 or 20',
        ),
      ],
    );
  }

  Widget _goTo(bool compact) {
    final pins = model.settings.pinned;
    return MenuBtn(
      compact ? '' : 'GO TO',
      icon: Icons.star_border,
      tip: 'Pinned folders and drives, in the panel',
      items: () {
        final drives = model.shell.drives().where((d) => d.ready).toList();
        return [
          menuHeading('PINNED'),
          for (final x in pins)
            menuItem(p.basename(x).isEmpty ? x : p.basename(x), () => cmd.view(x), icon: Icons.star, sub: x),
          if (pins.isEmpty) menuItem('Nothing yet: right-click a folder and choose Pin', null),
          if (model.panelPath != null)
            menuItem(
              model.isPinned(model.panelPath!) ? 'Unpin the panel\'s folder' : 'Pin the panel\'s folder',
              () => model.togglePin(model.panelPath!),
              icon: Icons.push_pin_outlined,
            ),
          const PopupMenuDivider(height: 8),
          menuHeading('DRIVES'),
          for (final d in drives)
            menuItem(driveLine(d), () => cmd.view(d.root), icon: Icons.storage, sub: driveFree(d)),
        ];
      },
    );
  }

  Widget _manual(bool compact) => Btn(
    compact ? '' : 'MANUAL',
    icon: Icons.menu_book_outlined,
    kind: BtnKind.ghost,
    tip: 'How to use the program  (F1)',
    onTap: cmd.manual,
  );

  Widget _more() => MenuBtn(
    '',
    icon: Icons.more_horiz,
    caret: false,
    tip: 'More',
    items: () => [
      menuItem('Bring in settings from 6.2 ...', cmd.importV6, icon: Icons.file_download_outlined),
      menuItem('Look for an update', onCheckUpdates, icon: Icons.system_update_alt),
      menuItem('Manual  (F1)', cmd.manual, icon: Icons.menu_book_outlined),
      menuItem('Keyboard shortcuts', cmd.shortcuts, icon: Icons.keyboard_outlined),
      menuItem('About', cmd.about, icon: Icons.info_outline),
    ],
  );
}

String driveLine(DriveInfo d) => '${d.letter}:  ${d.label.isEmpty ? d.type : d.label}';
String driveFree(DriveInfo d) => '${driveSize(d.free)} free of ${driveSize(d.total)}';

/// Top left: the folder that is open, its name and path; click to change it
class _FolderSwitcher extends StatelessWidget {
  const _FolderSwitcher({required this.model, required this.cmd, required this.width});
  final AppModel model;
  final Commands cmd;
  final double width;

  List<PopupMenuEntry<VoidCallback>> _items() {
    final s = model.settings;
    final has = model.project != null;
    final drives = model.shell.drives().where((d) => d.ready).toList();
    return [
      if (s.projects.isNotEmpty) menuHeading('RECENT'),
      for (var i = 0; i < s.projects.length; i++)
        menuItem(
          folderName(s.projects[i]),
          i == s.current ? () {} : () => model.switchProject(i),
          checked: i == s.current,
          icon: Icons.folder_outlined,
          sub: s.projects[i].root,
        ),
      if (s.projects.isNotEmpty) const PopupMenuDivider(height: 8),
      menuHeading('OPEN'),
      menuItem('Choose a folder ...', cmd.browse, icon: Icons.folder_open),
      menuItem('Type or paste a path ...', cmd.typePath, icon: Icons.edit_note),
      menuItem('Find projects on my drives ...', cmd.find, icon: Icons.search),
      for (final d in drives)
        menuItem('Drive ${driveLine(d)}', () => cmd.setRoot(d.root), icon: Icons.storage, sub: driveFree(d)),
      if (has) ...[
        const PopupMenuDivider(height: 8),
        menuHeading('THIS FOLDER'),
        menuItem('Open it in Explorer', cmd.openRoot, icon: Icons.open_in_new),
        menuItem('Rename it here ...', cmd.editTitle, icon: Icons.edit, sub: 'only the name shown at the top'),
        menuItem('Remove it from the list', () => cmd.forgetProject(s.current), icon: Icons.playlist_remove),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final pr = model.project;
    return Builder(
      builder: (ctx) => Hover(
        cursor: SystemMouseCursors.click,
        builder: (context, h) => Tooltip(
          message: 'Change the folder',
          child: GestureDetector(
            onTap: () => showMenuBelow(ctx, _items()),
            child: Container(
              width: width,
              padding: const EdgeInsets.fromLTRB(5, 4, 4, 4),
              decoration: BoxDecoration(
                color: h ? C.rowHoverTop : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: C.mark,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: C.teal.withValues(alpha: .45)),
                    ),
                    child: const Icon(Icons.folder_copy_outlined, size: 19, color: C.tealHi),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          pr == null ? 'Open a folder' : model.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t(15, color: C.title, w: FontWeight.w600, h: 1.2),
                        ),
                        Text(
                          pr == null ? 'a drive, or any folder' : model.root,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t(11, color: C.subtitle, h: 1.3),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.expand_more, size: 20, color: h ? C.tealHi : C.label),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The name shown for a folder in the list: the one the user gave it, or the folder's own
String folderName(Project pr) {
  if (pr.title.trim().isNotEmpty) return pr.title.trim();
  final b = p.basename(pr.root);
  return b.isEmpty || b == pr.root ? pr.root : b;
}

/// The layout in use, as a small picture; the six layouts and the drives strip are in its menu
class _ViewPicker extends StatelessWidget {
  const _ViewPicker({required this.model, required this.cmd});
  final AppModel model;
  final Commands cmd;

  @override
  Widget build(BuildContext context) => Builder(
    builder: (ctx) => Hover(
      cursor: SystemMouseCursors.click,
      builder: (context, h) => Tooltip(
        message: 'View: ${layoutNames[model.layout].toLowerCase()}   (Alt+1 … Alt+6)',
        child: GestureDetector(
          onTap: () => showMenuBelow(ctx, [
            menuHeading('VIEW'),
            for (var i = 0; i < 6; i++)
              PopupMenuItem<VoidCallback>(
                value: () => model.setLayout(i),
                height: 34,
                child: Row(
                  children: [
                    LayoutPicture(i, on: model.layout == i),
                    const SizedBox(width: 12),
                    Expanded(child: Text(layoutNames[i], style: t(12))),
                    Text('Alt+${i + 1}', style: t(11, color: C.muted, m: true)),
                  ],
                ),
              ),
            const PopupMenuDivider(height: 8),
            menuItem('Show the drives strip', () => model.setDrives(!model.options.drives), on: model.options.drives),
          ]),
          child: Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.fromLTRB(5, 4, 1, 4),
            decoration: BoxDecoration(
              color: h ? C.teal.withValues(alpha: .13) : null,
              border: Border.all(color: h ? C.fieldEdge : Colors.transparent),
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LayoutPicture(model.layout, on: true),
                Icon(Icons.arrow_drop_down, size: 18, color: h ? C.tealHi : C.label),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// The time and the date, small, top right; a click shows the calendar
class Clock extends StatefulWidget {
  const Clock({super.key, this.fixed});
  final DateTime? fixed;
  @override
  State<Clock> createState() => _ClockState();
}

class _ClockState extends State<Clock> {
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = widget.fixed ?? DateTime.now();
    if (widget.fixed == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final n = DateTime.now();
        if (n.minute != _now.minute || n.day != _now.day) setState(() => _now = n);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Builder(
    builder: (ctx) => Hover(
      cursor: SystemMouseCursors.click,
      builder: (context, h) => Tooltip(
        message: '${longDate(_now)}\nClick for the calendar',
        child: GestureDetector(
          onTap: () => showMenuBelow(ctx, [_Plain(MonthCalendar(today: _now), height: 230)]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                clockText(_now).substring(0, 5),
                style: t(17, color: h ? C.tealHi : C.teal, w: FontWeight.w600, m: true, h: 1.1, ls: 1),
              ),
              Text(
                '${weekdays[_now.weekday - 1].substring(0, 3)} ${_now.day} ${months[_now.month - 1].substring(0, 3)}',
                style: t(11, color: C.subtitle, h: 1.3),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A menu entry that is just a widget (the calendar)
class _Plain extends PopupMenuEntry<VoidCallback> {
  const _Plain(this.child, {required this.height});
  final Widget child;
  @override
  final double height;
  @override
  bool represents(VoidCallback? value) => false;
  @override
  State<_Plain> createState() => _PlainState();
}

class _PlainState extends State<_Plain> {
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), child: widget.child);
}

/// The month, with today marked; step through the months with the arrows, back to today with the title
class MonthCalendar extends StatefulWidget {
  const MonthCalendar({super.key, required this.today});
  final DateTime today;
  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<MonthCalendar> {
  late int _y = widget.today.year, _m = widget.today.month;

  void _move(int d) => setState(() {
    _m += d;
    if (_m < 1) {
      _m = 12;
      _y--;
    } else if (_m > 12) {
      _m = 1;
      _y++;
    }
  });

  @override
  Widget build(BuildContext context) {
    final now = widget.today;
    final thisMonth = now.year == _y && now.month == _m;
    Widget arrow(IconData i, int d, String tip) => IconButton(
      tooltip: tip,
      iconSize: 18,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      icon: Icon(i, color: C.teal),
      onPressed: () => _move(d),
    );
    return SizedBox(
      width: 238,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              arrow(Icons.chevron_left, -1, 'Month before'),
              Expanded(
                child: Tooltip(
                  message: 'Back to today',
                  child: InkWell(
                    onTap: () => setState(() {
                      _y = now.year;
                      _m = now.month;
                    }),
                    child: Text(
                      '${months[_m - 1]} $_y',
                      textAlign: TextAlign.center,
                      style: t(13, color: C.title, w: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              arrow(Icons.chevron_right, 1, 'Month after'),
            ],
          ),
          const SizedBox(height: 6),
          Table(
            defaultColumnWidth: const FixedColumnWidth(34),
            children: [
              TableRow(
                children: [
                  for (final d in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                    Center(
                      child: Text(d, style: t(10, color: C.muted, h: 1.6)),
                    ),
                ],
              ),
              for (final wk in monthGrid(_y, _m))
                TableRow(
                  children: [
                    for (final d in wk)
                      Container(
                        height: 24,
                        margin: const EdgeInsets.all(1),
                        alignment: Alignment.center,
                        decoration: thisMonth && d == now.day
                            ? BoxDecoration(color: C.teal, borderRadius: BorderRadius.circular(radius))
                            : null,
                        child: Text(
                          d == 0 ? '' : '$d',
                          style: thisMonth && d == now.day
                              ? t(11, color: C.ink, w: FontWeight.bold)
                              : t(11, color: C.soft),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
