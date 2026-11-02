// The docked panel: one folder's contents, with v6.2's three tool rows (UP ↻ +FOLDER RENAME
// PATH LIST/EDIT; ALL NONE COPY CUT PASTE RENAME DELETE; EXPLORER and the filters) and the
// clipboard line. New in v7: BACK / FORWARD, a clickable path, sort, dates, UNDO, a pin, drag
// and drop, right-click menus and the arrow keys.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../core/disk.dart';
import '../core/file_ops.dart';
import '../core/format.dart';
import '../state/app_model.dart';
import 'commands.dart';
import 'module_list.dart' show FolderDrop;
import 'theme.dart';
import 'widgets.dart';

class SidePanel extends StatefulWidget {
  const SidePanel({super.key, required this.model, required this.cmd, required this.filter, required this.edge});
  final AppModel model;
  final Commands cmd;
  final TextEditingController filter;

  /// Which side the edge line is on: the panel's left (side by side) or top (above / below)
  final AxisDirection edge;

  @override
  State<SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends State<SidePanel> {
  final _scroll = ScrollController();

  AppModel get m => widget.model;
  Commands get cmd => widget.cmd;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = m.panelPath!;
    final items = m.panelEntries();
    final (nd, nf) = m.panelCounts;
    final sel = m.selected.length;
    return LayoutBuilder(
      builder: (context, box) => Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [C.panelTop, C.panelBottom],
          ),
          border: widget.edge == AxisDirection.left
              ? const Border(left: BorderSide(color: C.topEdge))
              : widget.edge == AxisDirection.up
              ? const Border(top: BorderSide(color: C.topEdge))
              : null,
          boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 20, offset: Offset(-6, 0))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // the tool rows scroll when a small window leaves no room, so the list keeps its space
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: box.maxHeight * .6),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _head(path),
                    _navBar(box.maxWidth),
                    _actionBar(items.length, nd, nf, sel),
                    if (m.clip.isNotEmpty) _clipBar(),
                  ],
                ),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        nd + nf == 0 ? 'This folder is empty.' : 'Nothing to show with these filters.',
                        style: t(13, color: C.muted),
                      ),
                    )
                  : Scrollbar(
                      controller: _scroll,
                      child: ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                        itemCount: items.length,
                        itemBuilder: (context, i) =>
                            _Row(entry: items[i], model: m, cmd: cmd, wide: box.maxWidth >= 560),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _head(String path) {
    final pinned = m.isPinned(path);
    final name = p.basename(path).isEmpty ? path : p.basename(path);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [C.panelHeadTop, C.panelHeadBottom],
        ),
        border: Border(bottom: BorderSide(color: C.barEdge)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    folderIcon,
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t(16, color: C.white, w: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                _Crumbs(path: path, onTap: (x) => cmd.view(x)),
              ],
            ),
          ),
          Btn(
            '',
            icon: Icons.content_copy,
            kind: BtnKind.ghost,
            tip: 'Copy this folder\'s path',
            onTap: () => cmd.copyText(path, 'path copied: $path'),
          ),
          Btn(
            '',
            icon: pinned ? Icons.star : Icons.star_border,
            kind: BtnKind.ghost,
            lit: pinned,
            tip: pinned ? 'Unpin this folder' : 'Pin this folder for quick access',
            onTap: () => m.togglePin(path),
          ),
          Btn('', icon: Icons.close, kind: BtnKind.ghost, tip: 'Close the panel  (Alt+1)', onTap: m.closePanel),
        ],
      ),
    );
  }

  /// Getting around: back, forward, up, read again; then find, show and sort
  Widget _navBar(double w) {
    Widget nav(IconData i, String tip, VoidCallback? f) => Btn('', icon: i, kind: BtnKind.ghost, tip: tip, onTap: f);
    final filtered = m.show != Show.all || m.panelType.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: const BoxDecoration(
        color: C.tools,
        border: Border(bottom: BorderSide(color: C.toolsEdge)),
      ),
      child: Row(
        children: [
          nav(Icons.arrow_back, 'Back  (Alt+Left)', m.canBack ? m.panelBack : null),
          nav(Icons.arrow_forward, 'Forward  (Alt+Right)', m.canForward ? m.panelForward : null),
          nav(Icons.arrow_upward, 'The folder above  (Backspace)', m.panelUp),
          nav(Icons.refresh, 'Read this folder again  (F5)', m.refreshPanel),
          const SizedBox(width: 8),
          Expanded(
            child: Field(
              controller: widget.filter,
              hint: 'Filter this folder',
              onChanged: m.setPanelFilter,
              onEscape: () {
                widget.filter.clear();
                m.setPanelFilter('');
              },
            ),
          ),
          MenuBtn(
            w < 520 ? '' : (filtered ? 'SHOWING SOME' : 'SHOW'),
            icon: Icons.filter_list,
            lit: filtered,
            tip: 'Folders, files, or one type of file',
            items: () => [
              for (final x in Show.values) menuItem(x.label, () => m.setShow(x), checked: m.show == x),
              const PopupMenuDivider(height: 8),
              menuHeading('TYPE OF FILE'),
              menuItem('All types', () => m.setPanelType(''), checked: m.panelType.isEmpty),
              for (final ty in m.panelTypes()) menuItem(ty, () => m.setPanelType(ty), checked: m.panelType == ty),
            ],
          ),
          MenuBtn(
            w >= 520 ? 'SORT' : '',
            icon: Icons.sort,
            tip: 'Sort by ${m.sortBy.label.toLowerCase()}${m.sortDown ? ', reversed' : ''}',
            items: () => [
              for (final x in SortBy.values)
                menuItem(
                  x.label,
                  () => m.setSort(x),
                  checked: m.sortBy == x,
                  sub: m.sortBy == x
                      ? (m.sortDown ? 'reversed: pick again for the usual order' : 'pick again to reverse')
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// What you can do now: with a selection, its jobs; without, the folder's
  Widget _actionBar(int shown, int nd, int nf, int sel) {
    final undo = m.lastUndo;
    final List<Widget> left, right;
    if (sel > 0) {
      left = [
        Text(
          plural(sel, 'item'),
          style: t(12, color: C.amber, w: FontWeight.bold),
        ),
        Text('  selected', style: t(12, color: C.soft)),
        Btn('', icon: Icons.close, kind: BtnKind.ghost, small: true, tip: 'Select none  (Esc)', onTap: m.selectNone),
      ];
      right = [
        Btn('COPY', icon: Icons.copy, kind: BtnKind.ghost, tip: 'Ctrl+C', onTap: () => cmd.copy()),
        Btn('CUT', icon: Icons.content_cut, kind: BtnKind.ghost, tip: 'Ctrl+X', onTap: () => cmd.cut()),
        if (sel == 1) Btn('RENAME', icon: Icons.edit, kind: BtnKind.ghost, tip: 'F2', onTap: () => cmd.rename()),
        Btn(
          'DELETE',
          icon: Icons.delete_outline,
          kind: BtnKind.ghost,
          tip: 'To the Recycle Bin  (Delete)',
          onTap: () => cmd.delete(),
        ),
      ];
    } else {
      left = [
        Text(
          shown == nd + nf ? '${plural(nd, 'folder')}, ${plural(nf, 'file')}' : '$shown of ${nd + nf} shown',
          style: t(11, color: C.label, ls: .3),
        ),
        Btn('SELECT ALL', kind: BtnKind.ghost, small: true, tip: 'Ctrl+A', onTap: shown == 0 ? null : m.selectAll),
      ];
      right = [
        Btn('NEW FOLDER', icon: Icons.create_new_folder_outlined, kind: BtnKind.ghost, onTap: () => cmd.newFolder()),
        Btn(
          'LIST / EDIT',
          icon: Icons.list,
          kind: BtnKind.ghost,
          tip: 'The names in a box you can copy, or edit to rename many at once',
          onTap: cmd.listAndEdit,
        ),
        Btn(
          'EXPLORER',
          icon: Icons.open_in_new,
          kind: BtnKind.amber,
          small: true,
          tip: 'Open this folder in Explorer',
          onTap: () => cmd.open(m.panelPath!),
        ),
      ];
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 10, 4),
      constraints: const BoxConstraints(minHeight: 36),
      decoration: const BoxDecoration(
        color: C.tools2,
        border: Border(bottom: BorderSide(color: C.toolsEdge)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 4,
        children: [
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: left),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...right,
              if (undo != null)
                Btn('', icon: Icons.undo, kind: BtnKind.ghost, tip: 'Undo ${undo.label}  (Ctrl+Z)', onTap: cmd.undo),
            ],
          ),
        ],
      ),
    );
  }

  Widget _clipBar() {
    final c = m.clip;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 5, 14, 5),
      decoration: const BoxDecoration(
        color: C.clip,
        border: Border(bottom: BorderSide(color: C.toolsEdge)),
      ),
      child: Row(
        children: [
          Text(
            m.clipCut ? 'CUT' : 'COPIED',
            style: t(11, color: C.amber, w: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${plural(c.length, 'item')}  ·  ${c.first.name}${c.length > 1 ? ' and ${c.length - 1} more' : ''}  ·  '
              'go to the folder you want them in',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t(11, color: C.softer),
            ),
          ),
          Btn(
            'PASTE HERE',
            icon: Icons.content_paste,
            kind: BtnKind.amber,
            small: true,
            tip: 'Ctrl+V',
            onTap: () => cmd.paste(),
          ),
          Btn('', icon: Icons.close, kind: BtnKind.ghost, small: true, tip: 'Empty the clipboard', onTap: m.clearClip),
        ],
      ),
    );
  }
}

/// The path, each part clickable: D:\  Project  10_Survey
class _Crumbs extends StatelessWidget {
  const _Crumbs({required this.path, required this.onTap});
  final String path;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    final parts = <(String, String)>[];
    var cur = path;
    while (true) {
      final up = p.dirname(cur);
      final name = p.basename(cur);
      parts.insert(0, (name.isEmpty ? cur : name, cur));
      if (up == cur || name.isEmpty) break;
      cur = up;
    }
    return Wrap(
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0) Text(' ${p.separator} ', style: t(10, color: C.faint, m: true)),
          Hover(
            cursor: SystemMouseCursors.click,
            builder: (context, h) => GestureDetector(
              onTap: () => onTap(parts[i].$2),
              child: Text(
                parts[i].$1,
                style: t(
                  10,
                  color: h ? C.amberHi : C.amber,
                  m: true,
                ).copyWith(decoration: h ? TextDecoration.underline : null, decorationColor: C.amberHi),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({required this.entry, required this.model, required this.cmd, required this.wide});
  final Entry entry;
  final AppModel model;
  final Commands cmd;
  final bool wide;
  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  DateTime _last = DateTime(0);

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final m = widget.model;
    final sel = m.isSelected(e);
    final cut = m.isCut(e);
    final hi = m.highlight.isNotEmpty && e.name.toLowerCase() == m.highlight;

    Widget row(bool over) => Hover(
      builder: (context, h) => Opacity(
        opacity: cut ? .45 : 1,
        child: AccentBox(
          padding: const EdgeInsets.fromLTRB(6, 6, 9, 6),
          color: over ? C.vrowHover : (sel ? C.selected : (h ? C.vrowHover : null)),
          accent: over ? C.amber : (sel ? C.gold : (h ? C.vrowHoverEdge : Colors.transparent)),
          accentWidth: 3,
          radius: 3,
          bottomLine: C.vrowEdge,
          child: Row(
            children: [
              SizedBox(width: e.isDir ? 26 : 48, child: e.isDir ? folderIcon : ExtChip(e.name)),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  e.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: hi
                      ? t(13, color: C.amber, w: FontWeight.bold)
                      : e.isDir
                      ? t(13, color: C.white, w: FontWeight.bold, ls: .3)
                      : t(13, color: C.soft),
                ),
              ),
              if (widget.wide && e.modified != null)
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Text(shortDateTime(e.modified!), style: t(10, color: C.muted, m: true)),
                ),
              SizedBox(
                width: 72,
                child: Text(
                  e.isDir ? '${m.cache.folderCount(e.path)} sub' : fileSize(e.size),
                  textAlign: TextAlign.right,
                  style: t(10, color: C.muted, m: true),
                ),
              ),
              const SizedBox(width: 10),
              Opacity(
                opacity: h || sel ? 1 : .58,
                child: Btn(
                  'OPEN',
                  icon: Icons.open_in_new,
                  small: true,
                  kind: BtnKind.ghost,
                  tip: e.isDir ? 'Open this folder in Explorer' : 'Open this file',
                  onTap: () => widget.cmd.open(e.path),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    Widget body = Listener(
      onPointerDown: (ev) {
        if (ev.buttons == kSecondaryMouseButton) {
          widget.cmd.entryMenu(ev.position, e);
          return;
        }
        if (ev.buttons != kPrimaryMouseButton) return;
        final now = DateTime.now();
        if (now.difference(_last) < kDoubleTapTimeout) {
          _last = DateTime(0);
          // double-click: a folder opens here, a file in its own program
          e.isDir ? widget.cmd.view(e.path) : widget.cmd.open(e.path);
          return;
        }
        _last = now;
        final keys = HardwareKeyboard.instance;
        m.click(e, ctrl: keys.isControlPressed, shift: keys.isShiftPressed);
      },
      child: e.isDir ? FolderDrop(path: e.path, cmd: widget.cmd, builder: (context, over) => row(over)) : row(false),
    );

    // drag the selection (or this row) onto a folder in the panel or the tree
    final drag = sel ? m.selection() : [e];
    body = Draggable<List<Item>>(
      data: [for (final x in drag) Item(x.path, x.isDir)],
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: C.clip,
            border: Border.all(color: C.amber),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            drag.length == 1 ? drag.first.name : '${drag.length} items',
            style: t(12, color: C.amber, w: FontWeight.bold),
          ),
        ),
      ),
      child: body,
    );
    return Semantics(selected: sel, label: e.name, child: body);
  }
}
