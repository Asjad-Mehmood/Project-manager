// The left side: the project's modules (each with its discipline, sub-folders, on-disk dot,
// VIEW and OPEN), the tree under them, and DEEP search results from the index. New in v7:
// right-click menus, dropping files from the panel onto a folder, and a start page that helps.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../core/disciplines.dart';
import '../core/disk.dart';
import '../core/file_ops.dart';
import '../core/search_index.dart';
import '../state/app_model.dart';
import 'commands.dart';
import 'theme.dart';
import 'widgets.dart';

class ModuleList extends StatelessWidget {
  const ModuleList({super.key, required this.model, required this.cmd, required this.width});
  final AppModel model;
  final Commands cmd;

  /// The list's own width: chips step aside before a name gets squeezed (v6.2's rule)
  final double width;

  @override
  Widget build(BuildContext context) {
    if (model.project == null) return _Welcome(cmd: cmd);
    if (!model.rootExists) return _RootMissing(model: model, cmd: cmd);
    if (model.showingResults) return _Results(model: model, cmd: cmd, width: width);
    final rows = model.moduleRows();
    if (rows.isEmpty) {
      return _Empty(model: model, cmd: cmd);
    }
    final lines = <Object>[];
    void kids(String path, int depth) {
      for (final e in model.cache.folders(path)) {
        lines.add((e, depth));
        if (model.isOpen(e.path)) kids(e.path, depth + 1);
      }
    }

    for (final r in rows) {
      lines.add(r);
      if (r.exists && model.isOpen(r.path)) kids(r.path, 1);
    }
    return Scrollbar(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        itemCount: lines.length,
        itemBuilder: (context, i) {
          final l = lines[i];
          if (l is ModuleRow) return _ModuleTile(row: l, model: model, cmd: cmd, width: width);
          final (e, depth) = l as (Entry, int);
          return _KidTile(entry: e, depth: depth, model: model, cmd: cmd, width: width);
        },
      ),
    );
  }
}

/// Clicks on a row: double-click and right-click, without slowing the single click down
class _Clicks extends StatefulWidget {
  const _Clicks({required this.child, this.onDouble, this.onRight});
  final Widget child;
  final VoidCallback? onDouble;
  final void Function(Offset)? onRight;
  @override
  State<_Clicks> createState() => _ClicksState();
}

class _ClicksState extends State<_Clicks> {
  DateTime _last = DateTime(0);
  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (e) {
      if (e.buttons == kSecondaryMouseButton) {
        widget.onRight?.call(e.position);
      } else if (e.buttons == kPrimaryMouseButton) {
        final now = DateTime.now();
        if (now.difference(_last) < kDoubleTapTimeout) {
          _last = DateTime(0);
          widget.onDouble?.call();
        } else {
          _last = now;
        }
      }
    },
    child: widget.child,
  );
}

/// Drop items from the panel onto a folder row
class FolderDrop extends StatelessWidget {
  const FolderDrop({super.key, required this.path, required this.cmd, required this.builder});
  final String path;
  final Commands cmd;
  final Widget Function(BuildContext, bool over) builder;

  @override
  Widget build(BuildContext context) => DragTarget<List<Item>>(
    onWillAcceptWithDetails: (d) => d.data.every((i) => !isSameOrInside(path, i.path)),
    onAcceptWithDetails: (d) => cmd.drop(d.data, path),
    builder: (context, cand, rej) => builder(context, cand.isNotEmpty),
  );
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({required this.row, required this.model, required this.cmd, required this.width});
  final ModuleRow row;
  final AppModel model;
  final Commands cmd;
  final double width;

  @override
  Widget build(BuildContext context) {
    final color = disciplineColor(row.module.discipline);
    final open = model.isOpen(row.path);
    return FolderDrop(
      path: row.path,
      cmd: cmd,
      builder: (context, over) => Hover(
        builder: (context, h) => _Clicks(
          onDouble: row.exists ? () => cmd.open(row.path) : null,
          onRight: (at) => cmd.folderMenu(at, row.path, module: row.module),
          child: AccentBox(
            margin: const EdgeInsets.only(bottom: 4),
            colors: h || over ? const [C.rowHoverTop, C.rowHoverBottom] : const [C.rowTop, C.rowBottom],
            accent: h || over ? C.tealHi : color,
            edge: over ? C.amber : (h ? C.rowHoverEdge : C.rowEdge),
            shadow: true,
            padding: const EdgeInsets.fromLTRB(8, 7, 10, 7),
            child: Row(
              children: [
                _Arrow(open: open, onTap: row.exists ? () => model.toggleOpen(row.path) : null),
                if (width >= 420)
                  SizedBox(
                    width: 26,
                    child: Text(row.number.toString().padLeft(2, '0'), style: t(11, color: C.muted, m: true)),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Name(
                        row.module.name,
                        style: t(14, color: C.white, w: FontWeight.bold, ls: .3),
                        onTap: () => row.exists ? cmd.view(row.path) : null,
                      ),
                      if (width >= 500) ...[
                        const SizedBox(height: 2),
                        Text(
                          row.path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t(10, color: C.muted, m: true),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                if (width >= 760) ...[
                  DisciplineChip(row.module.discipline, onTap: () => cmd.chooseDiscipline(row.module)),
                  const SizedBox(width: 9),
                ],
                if (width >= 620) ...[SubChip(row.subCount), const SizedBox(width: 9)],
                Dot(row.exists),
                const SizedBox(width: 11),
                Btn('VIEW', icon: Icons.folder_open, onTap: row.exists ? () => cmd.view(row.path) : null),
                Btn('OPEN', icon: Icons.bolt, kind: BtnKind.amber, onTap: row.exists ? () => cmd.open(row.path) : null),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KidTile extends StatelessWidget {
  const _KidTile({
    required this.entry,
    required this.depth,
    required this.model,
    required this.cmd,
    required this.width,
  });
  final Entry entry;
  final int depth;
  final AppModel model;
  final Commands cmd;
  final double width;

  @override
  Widget build(BuildContext context) {
    final open = model.isOpen(entry.path);
    final subs = model.cache.folderCount(entry.path);
    return FolderDrop(
      path: entry.path,
      cmd: cmd,
      builder: (context, over) => Hover(
        builder: (context, h) => _Clicks(
          onDouble: () => cmd.open(entry.path),
          onRight: (at) => cmd.folderMenu(at, entry.path),
          child: AccentBox(
            margin: EdgeInsets.only(bottom: 4, left: 14.0 + depth * 22),
            colors: h || over ? const [C.rowHoverTop, C.rowHoverBottom] : const [C.kidTop, C.kidBottom],
            accent: h || over ? C.tealHi : C.teal,
            accentWidth: 3,
            edge: over ? C.amber : (h ? C.rowHoverEdge : C.rowEdge),
            padding: const EdgeInsets.fromLTRB(9, 6, 10, 6),
            child: Row(
              children: [
                _Arrow(open: open, onTap: subs > 0 ? () => model.toggleOpen(entry.path) : null),
                Expanded(
                  child: _Name(
                    entry.name,
                    style: t(13, color: C.soft),
                    onTap: () => cmd.view(entry.path),
                  ),
                ),
                const SizedBox(width: 14),
                if (width >= 620) ...[SubChip(subs), const SizedBox(width: 9)],
                Btn('VIEW', icon: Icons.folder_open, onTap: () => cmd.view(entry.path)),
                Btn('OPEN', icon: Icons.bolt, kind: BtnKind.amber, onTap: () => cmd.open(entry.path)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.open, this.onTap});
  final bool open;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
    child: GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 16,
        child: Icon(
          open ? Icons.arrow_drop_down : Icons.arrow_right,
          size: 16,
          color: onTap == null ? C.faint : C.teal,
          semanticLabel: open ? 'Close' : 'Open',
        ),
      ),
    ),
  );
}

class _Name extends StatelessWidget {
  const _Name(this.text, {required this.style, this.onTap});
  final String text;
  final TextStyle style;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
      ),
    ),
  );
}

/// DEEP search results from the index
class _Results extends StatelessWidget {
  const _Results({required this.model, required this.cmd, required this.width});
  final AppModel model;
  final Commands cmd;
  final double width;

  @override
  Widget build(BuildContext context) {
    final r = model.results();
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: C.toolsEdge)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'DEEP  ',
                        style: t(11, color: C.label, ls: 1),
                      ),
                      TextSpan(
                        text: '${r.total}',
                        style: t(12, color: C.teal, w: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            ' match(es)${r.total > r.hits.length ? ' (first ${r.hits.length} shown)' : ''} across '
                            '${model.index.length} indexed items in ${model.index.scopeName}',
                        style: t(11, color: C.label),
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              for (final k in Kind.values)
                Btn(
                  switch (k) {
                    Kind.all => 'ALL',
                    Kind.folders => 'FOLDERS',
                    Kind.files => 'FILES',
                  },
                  small: true,
                  lit: model.resultKind == k,
                  onTap: () => model.setResultKind(k),
                ),
            ],
          ),
        ),
        Expanded(
          child: r.hits.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(30),
                  child: Text('Nothing matching "${model.query.trim()}" in the index.', style: t(13, color: C.muted)),
                )
              : Scrollbar(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    itemCount: r.hits.length,
                    itemBuilder: (context, i) => _HitTile(hit: r.hits[i], model: model, cmd: cmd, width: width),
                  ),
                ),
        ),
      ],
    );
  }
}

class _HitTile extends StatelessWidget {
  const _HitTile({required this.hit, required this.model, required this.cmd, required this.width});
  final Hit hit;
  final AppModel model;
  final Commands cmd;
  final double width;

  @override
  Widget build(BuildContext context) {
    final d = model.disciplineOf(hit.path);
    void view() => hit.isFile ? cmd.showFile(hit.path) : cmd.view(hit.path);
    return Hover(
      builder: (context, h) => _Clicks(
        onDouble: () => cmd.open(hit.path),
        onRight: (at) => hit.isFile
            ? cmd.menuAt(at, [
                (Icons.bolt, 'Open', () => cmd.open(hit.path)),
                (Icons.folder_open, 'View its folder', view),
                (Icons.manage_search, 'Show in Explorer', () => model.shell.reveal(hit.path)),
                null,
                (Icons.content_copy, 'Copy the path', () => cmd.copyText(hit.path, 'path copied')),
              ])
            : cmd.folderMenu(at, hit.path),
        child: AccentBox(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.fromLTRB(8, 7, 10, 7),
          colors: h ? const [C.rowHoverTop, C.rowHoverBottom] : const [C.rowTop, C.rowBottom],
          accent: h ? C.tealHi : (d == null ? C.chipGrey : disciplineColor(d)),
          edge: h ? C.rowHoverEdge : C.rowEdge,
          child: Row(
            children: [
              SizedBox(width: 48, child: hit.isFile ? ExtChip(hit.name) : folderIcon),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Name(
                      hit.name,
                      style: hit.isFile ? t(13, color: C.soft) : t(14, color: C.white, w: FontWeight.bold),
                      onTap: view,
                    ),
                    if (width >= 500) ...[
                      const SizedBox(height: 2),
                      Text(
                        p.dirname(hit.path),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t(10, color: C.muted, m: true),
                      ),
                    ],
                  ],
                ),
              ),
              if (d != null && width >= 760) ...[const SizedBox(width: 9), DisciplineChip(d)],
              const SizedBox(width: 9),
              Btn('VIEW', icon: Icons.folder_open, onTap: view),
              Btn('OPEN', icon: Icons.bolt, kind: BtnKind.amber, onTap: () => cmd.open(hit.path)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.text, this.actions = const []});
  final IconData icon;
  final String title;
  final String text;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: C.teal),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: t(20, color: C.title, w: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: t(13, color: C.soft, h: 1.5),
            ),
            const SizedBox(height: 18),
            Wrap(alignment: WrapAlignment.center, spacing: 4, runSpacing: 8, children: actions),
          ],
        ),
      ),
    ),
  );
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.cmd});
  final Commands cmd;
  @override
  Widget build(BuildContext context) => _Message(
    icon: Icons.dashboard_customize_outlined,
    title: 'Point it at your project folder',
    text:
        'Paste the project\'s master folder into ROOT PATH and press SET, pick it with BROWSE, or let FIND look on '
        'every drive. The project is then indexed by itself in the background, so search is instant.',
    actions: [
      Btn('BROWSE', icon: Icons.folder_open, kind: BtnKind.on, onTap: cmd.browse),
      Btn('FIND', icon: Icons.search, onTap: cmd.find),
      Btn('BRING IN v6 SETTINGS', icon: Icons.file_download_outlined, onTap: cmd.importV6),
    ],
  );
}

class _RootMissing extends StatelessWidget {
  const _RootMissing({required this.model, required this.cmd});
  final AppModel model;
  final Commands cmd;
  @override
  Widget build(BuildContext context) => _Message(
    icon: Icons.folder_off_outlined,
    title: 'Root folder not found on this PC',
    text:
        '${model.root}\n\nThe drive may not be connected, or the folder was moved. Use BROWSE or FIND, or pick another project.',
    actions: [
      Btn('BROWSE', icon: Icons.folder_open, kind: BtnKind.on, onTap: cmd.browse),
      Btn('FIND', icon: Icons.search, onTap: cmd.find),
      Btn('TRY AGAIN', icon: Icons.refresh, onTap: model.refresh),
    ],
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.model, required this.cmd});
  final AppModel model;
  final Commands cmd;
  @override
  Widget build(BuildContext context) {
    final filtered = model.query.trim().isNotEmpty || model.discipline.isNotEmpty || model.options.hideMissing;
    if (filtered) {
      return Padding(
        padding: const EdgeInsets.all(30),
        child: Text(
          'No module matches${model.query.trim().isNotEmpty ? ' "${model.query.trim()}"' : ''}'
          '${model.discipline.isNotEmpty ? ' in ${model.discipline}' : ''}.'
          '${model.index.isEmpty ? '' : ' Turn DEEP on to search every folder and file.'}',
          style: t(13, color: C.muted),
        ),
      );
    }
    return _Message(
      icon: Icons.create_new_folder_outlined,
      title: 'No folders in this project yet',
      text:
          '${model.root}\n\nMake the standard modules (00_Admin … 99_Archive), or add your own folders and press SCAN.',
      actions: [
        Btn(
          'MAKE THE STANDARD FOLDERS',
          icon: Icons.create_new_folder_outlined,
          kind: BtnKind.on,
          onTap: cmd.offerStandardFolders,
        ),
        Btn('SCAN', icon: Icons.refresh, onTap: cmd.scan),
      ],
    );
  }
}
