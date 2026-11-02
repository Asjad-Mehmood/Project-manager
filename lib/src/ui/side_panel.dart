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

  /// Which side the teal edge is on: the panel's left (side by side) or top (above / below)
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
              ? const Border(left: BorderSide(color: C.teal, width: 2))
              : widget.edge == AxisDirection.up
              ? const Border(top: BorderSide(color: C.teal, width: 2))
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
                    _bar(C.tools, [
                      Btn('', icon: Icons.arrow_back, tip: 'Back  (Alt+Left)', onTap: m.canBack ? m.panelBack : null),
                      Btn(
                        '',
                        icon: Icons.arrow_forward,
                        tip: 'Forward  (Alt+Right)',
                        onTap: m.canForward ? m.panelForward : null,
                      ),
                      Btn('UP', icon: Icons.arrow_upward, tip: 'The folder above  (Backspace)', onTap: m.panelUp),
                      Btn('', icon: Icons.refresh, tip: 'Read this folder again  (F5)', onTap: m.refreshPanel),
                      Btn('FOLDER', icon: Icons.add, tip: 'New folder here', onTap: () => cmd.newFolder()),
                      Btn('RENAME', icon: Icons.edit, tip: 'Rename the selected item  (F2)', onTap: () => cmd.rename()),
                      Btn(
                        'PATH',
                        icon: Icons.content_copy,
                        tip: 'Copy this folder\'s path',
                        onTap: () => cmd.copyText(path, 'path copied: $path'),
                      ),
                      Btn(
                        'LIST / EDIT',
                        icon: Icons.list,
                        kind: BtnKind.on,
                        tip: 'The names in a box you can copy, or edit to rename many at once',
                        onTap: cmd.listAndEdit,
                      ),
                      Btn(
                        'UNDO',
                        icon: Icons.undo,
                        tip: m.lastUndo == null ? 'Nothing to undo' : 'Undo ${m.lastUndo!.label}  (Ctrl+Z)',
                        onTap: m.lastUndo == null ? null : cmd.undo,
                      ),
                    ]),
                    _bar(C.tools2, [
                      Btn('ALL', icon: Icons.check_box_outline_blank, tip: 'Ctrl+A', onTap: m.selectAll),
                      Btn('NONE', icon: Icons.check_box_outline_blank, tip: 'Esc', onTap: m.selectNone),
                      Btn('COPY', icon: Icons.copy, kind: BtnKind.on, tip: 'Ctrl+C', onTap: () => cmd.copy()),
                      Btn('CUT', icon: Icons.content_cut, kind: BtnKind.on, tip: 'Ctrl+X', onTap: () => cmd.cut()),
                      Btn(
                        'PASTE',
                        icon: Icons.content_paste,
                        kind: BtnKind.amber,
                        tip: 'Ctrl+V',
                        onTap: () => cmd.paste(),
                      ),
                      const SizedBox(width: 12),
                      Btn('RENAME', icon: Icons.edit, tip: 'F2', onTap: () => cmd.rename()),
                      Btn(
                        'DELETE',
                        icon: Icons.delete_outline,
                        tip: 'Delete key: to the Recycle Bin',
                        onTap: () => cmd.delete(),
                      ),
                      const SizedBox(width: 12),
                      Lbl(sel == 0 ? 'nothing selected' : '${plural(sel, 'item')} selected'),
                    ]),
                    if (m.clip.isNotEmpty) _clipBar(),
                    _filters(items.length, nd, nf, box.maxWidth),
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
            icon: pinned ? Icons.star : Icons.star_border,
            tip: pinned ? 'Unpin this folder' : 'Pin this folder for quick access',
            onTap: () => m.togglePin(path),
          ),
          Btn('', icon: Icons.close, tip: 'Close the panel', onTap: m.closePanel),
        ],
      ),
    );
  }

  Widget _bar(Color bg, List<Widget> children) => Container(
    padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
    decoration: BoxDecoration(
      color: bg,
      border: const Border(bottom: BorderSide(color: C.toolsEdge)),
    ),
    child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 5, children: children),
  );

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
              'press PASTE in the folder you want them in',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t(11, color: C.softer),
            ),
          ),
          Btn('clear', small: true, onTap: m.clearClip),
        ],
      ),
    );
  }

  Widget _filters(int shown, int nd, int nf, double w) => Container(
    padding: const EdgeInsets.fromLTRB(14, 6, 14, 7),
    decoration: const BoxDecoration(
      color: C.tools,
      border: Border(bottom: BorderSide(color: C.toolsEdge)),
    ),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        Btn('EXPLORER', icon: Icons.bolt, kind: BtnKind.amber, onTap: () => cmd.open(m.panelPath!)),
        Field(
          controller: widget.filter,
          width: (w * .3).clamp(140, 260),
          hint: 'filter this folder',
          onChanged: m.setPanelFilter,
          onEscape: () {
            widget.filter.clear();
            m.setPanelFilter('');
          },
        ),
        Select<Show>(value: m.show, items: Show.values, label: (s) => s.label, onChanged: m.setShow, width: 125),
        Select<String>(
          value: m.panelType,
          items: ['', ...m.panelTypes()],
          label: (x) => x.isEmpty ? 'All types' : x,
          onChanged: m.setPanelType,
          width: 110,
        ),
        Select<SortBy>(
          value: m.sortBy,
          items: SortBy.values,
          label: (s) => 'Sort: ${s.label}',
          onChanged: m.setSort,
          width: 150,
          tip: 'Pick the same one again to reverse the order',
        ),
        if (m.sortDown) const Icon(Icons.south, size: 14, color: C.label),
        Lbl('$shown shown  ·  ${plural(nd, 'folder')}, ${plural(nf, 'file')}'),
      ],
    ),
  );
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
                  icon: Icons.bolt,
                  small: true,
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
