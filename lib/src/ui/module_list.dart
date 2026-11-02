// The left side: the folders in the opened folder (each with its discipline, sub-folders, VIEW
// and OPEN), the tree under them, and DEEP search results from the index. The list is read from
// the disk, so it is never out of step. Also the start page: open a drive or a folder.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../core/disciplines.dart';
import '../core/disk.dart';
import '../core/file_ops.dart';
import '../core/format.dart';
import '../core/search_index.dart';
import '../platform/shell.dart';
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
    if (model.project == null) return StartPage(model: model, cmd: cmd);
    if (!model.rootExists) return StartPage(model: model, cmd: cmd, missing: model.root);
    if (model.showingResults) return _Results(model: model, cmd: cmd, width: width);
    final rows = model.moduleRows();
    if (rows.isEmpty) {
      return Column(
        children: [
          _ListHead(model: model, cmd: cmd, shown: 0),
          Expanded(
            child: _Empty(model: model, cmd: cmd),
          ),
        ],
      );
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
    return Column(
      children: [
        _ListHead(model: model, cmd: cmd, shown: rows.length),
        Expanded(
          child: Scrollbar(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
              itemCount: lines.length,
              itemBuilder: (context, i) {
                final l = lines[i];
                if (l is ModuleRow) return _ModuleTile(row: l, model: model, cmd: cmd, width: width);
                final (e, depth) = l as (Entry, int);
                return _KidTile(entry: e, depth: depth, model: model, cmd: cmd, width: width);
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Above the list: how many folders, the index, and expand / collapse / refresh
class _ListHead extends StatelessWidget {
  const _ListHead({required this.model, required this.cmd, required this.shown});
  final AppModel model;
  final Commands cmd;
  final int shown;

  @override
  Widget build(BuildContext context) {
    final all = model.modules.length;
    final idx = model.index;
    return LayoutBuilder(
      builder: (context, box) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 6),
        child: Row(
          children: [
            Text(
              'FOLDERS',
              style: t(11, color: C.label, w: FontWeight.w600, ls: 1.2),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(color: C.subBg, borderRadius: BorderRadius.circular(10)),
              child: Text(
                shown == all ? '$all' : '$shown of $all',
                style: t(11, color: C.tealHi, w: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: box.maxWidth < 430
                  ? const SizedBox()
                  : Text(
                      model.indexing
                          ? 'indexing: ${model.indexedCount} found so far'
                          : idx.isEmpty
                          ? 'not indexed yet'
                          : '${model.indexedCount} indexed'
                                '${idx.built == null ? '' : ', ${ago(idx.built!, model.now())}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t(11, color: C.muted),
                    ),
            ),
            Btn(
              box.maxWidth < 560 ? '' : 'EXPAND ALL',
              icon: Icons.unfold_more,
              small: true,
              kind: BtnKind.ghost,
              lit: model.options.tree,
              tip: model.options.tree
                  ? 'Every folder is open, three levels deep'
                  : 'Open every folder, three levels deep',
              onTap: () => model.setTree(!model.options.tree),
            ),
            Btn(
              box.maxWidth < 560 ? '' : 'COLLAPSE',
              icon: Icons.unfold_less,
              small: true,
              kind: BtnKind.ghost,
              tip: 'Close every folder',
              onTap: model.collapseAll,
            ),
            Btn(
              '',
              icon: Icons.refresh,
              small: true,
              kind: BtnKind.ghost,
              tip: 'Read the disk again  (F5)',
              onTap: model.refresh,
            ),
          ],
        ),
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
          onDouble: () => cmd.open(row.path),
          onRight: (at) => cmd.folderMenu(at, row.path, module: row.module),
          child: AccentBox(
            margin: const EdgeInsets.only(bottom: 5),
            color: h || over ? C.rowHoverTop : C.rowTop,
            accent: color,
            accentWidth: 3,
            edge: over ? C.amber : (h ? C.rowHoverEdge : C.rowEdge),
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Row(
              children: [
                _Arrow(open: open, onTap: row.subCount > 0 ? () => model.toggleOpen(row.path) : null),
                const SizedBox(width: 4),
                Icon(Icons.folder_rounded, size: 20, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: _Name(
                    row.module.name,
                    style: t(14, color: C.white, w: FontWeight.w600),
                    onTap: () => cmd.view(row.path),
                  ),
                ),
                const SizedBox(width: 10),
                if (width >= 700) ...[
                  DisciplineChip(row.module.discipline, onTap: () => cmd.chooseDiscipline(row.module)),
                  const SizedBox(width: 8),
                ],
                if (width >= 560) ...[SubChip(row.subCount), const SizedBox(width: 6)],
                Btn(
                  width >= 480 ? 'VIEW' : '',
                  icon: Icons.visibility_outlined,
                  kind: BtnKind.ghost,
                  tip: 'Show it in the panel',
                  onTap: () => cmd.view(row.path),
                ),
                Btn(
                  width >= 480 ? 'OPEN' : '',
                  icon: Icons.open_in_new,
                  kind: BtnKind.ghost,
                  tip: 'Open in Explorer  (double-click)',
                  onTap: () => cmd.open(row.path),
                ),
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
            margin: EdgeInsets.only(bottom: 4, left: 12.0 + depth * 22),
            color: h || over ? C.rowHoverTop : C.kidTop,
            accent: Colors.transparent,
            accentWidth: 0,
            edge: over ? C.amber : (h ? C.rowHoverEdge : C.rowEdge),
            padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
            child: Row(
              children: [
                _Arrow(open: open, onTap: subs > 0 ? () => model.toggleOpen(entry.path) : null),
                const SizedBox(width: 4),
                const Icon(Icons.folder_outlined, size: 17, color: C.label),
                const SizedBox(width: 9),
                Expanded(
                  child: _Name(
                    entry.name,
                    style: t(13, color: C.soft),
                    onTap: () => cmd.view(entry.path),
                  ),
                ),
                const SizedBox(width: 14),
                if (width >= 560) ...[SubChip(subs), const SizedBox(width: 6)],
                Btn(
                  width >= 480 ? 'VIEW' : '',
                  icon: Icons.visibility_outlined,
                  kind: BtnKind.ghost,
                  tip: 'Show it in the panel',
                  onTap: () => cmd.view(entry.path),
                ),
                Btn(
                  width >= 480 ? 'OPEN' : '',
                  icon: Icons.open_in_new,
                  kind: BtnKind.ghost,
                  tip: 'Open in Explorer  (double-click)',
                  onTap: () => cmd.open(entry.path),
                ),
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
                  kind: BtnKind.ghost,
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
                (Icons.open_in_new, 'Open', () => cmd.open(hit.path)),
                (Icons.folder_open, 'View its folder', view),
                (Icons.manage_search, 'Show in Explorer', () => model.shell.reveal(hit.path)),
                null,
                (Icons.content_copy, 'Copy the path', () => cmd.copyText(hit.path, 'path copied')),
              ])
            : cmd.folderMenu(at, hit.path),
        child: AccentBox(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.fromLTRB(8, 7, 10, 7),
          color: h ? C.rowHoverTop : C.rowTop,
          accent: d == null ? C.chipGrey : disciplineColor(d),
          accentWidth: 3,
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
              Btn(
                'VIEW',
                icon: Icons.visibility_outlined,
                kind: BtnKind.ghost,
                tip: 'Show it in the panel',
                onTap: view,
              ),
              Btn(
                'OPEN',
                icon: Icons.open_in_new,
                kind: BtnKind.ghost,
                tip: 'Open it  (double-click)',
                onTap: () => cmd.open(hit.path),
              ),
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

/// The start page: on a new setup (nothing opened yet), or when the opened folder is not on this PC.
/// Open a drive with one click, or choose any folder.
class StartPage extends StatelessWidget {
  const StartPage({super.key, required this.model, required this.cmd, this.missing});
  final AppModel model;
  final Commands cmd;

  /// The folder that was open and can't be found
  final String? missing;

  @override
  Widget build(BuildContext context) {
    final drives = model.drives;
    final v6 = missing == null && model.settings.projects.isEmpty ? model.v6File : null;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: missing == null ? C.mark : const Color(0xFF3A1E14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: (missing == null ? C.teal : C.red).withValues(alpha: .5)),
                ),
                child: Icon(
                  missing == null ? Icons.folder_copy_outlined : Icons.folder_off_outlined,
                  size: 30,
                  color: missing == null ? C.tealHi : C.red,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                missing == null ? 'Open a drive or a folder' : 'This folder is not on this PC',
                textAlign: TextAlign.center,
                style: t(24, color: C.title, w: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                missing == null
                    ? 'Choose a drive, or any folder (a project\'s master folder works best).\n'
                          'You can change it any time from the top left.'
                    : '$missing\n\nThe drive may not be connected, or the folder was moved. Open another one:',
                textAlign: TextAlign.center,
                style: t(13, color: C.soft, h: 1.55),
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [for (final d in drives) _DriveCard(drive: d, onTap: () => cmd.setRoot(d.root))],
              ),
              const SizedBox(height: 22),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 8,
                children: [
                  Btn('CHOOSE A FOLDER ...', icon: Icons.folder_open, kind: BtnKind.on, onTap: cmd.browse),
                  Btn('TYPE A PATH', icon: Icons.edit_note, onTap: cmd.typePath),
                  Btn(
                    'FIND PROJECTS',
                    icon: Icons.search,
                    onTap: cmd.find,
                    tip: 'Look on every drive for project folders',
                  ),
                  if (missing != null) ...[
                    Btn('TRY AGAIN', icon: Icons.refresh, kind: BtnKind.ghost, onTap: model.refresh),
                    Btn(
                      'REMOVE FROM THE LIST',
                      icon: Icons.playlist_remove,
                      kind: BtnKind.ghost,
                      onTap: () => cmd.forgetProject(model.settings.current),
                    ),
                  ],
                ],
              ),
              if (v6 != null) ...[
                const SizedBox(height: 26),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                  decoration: BoxDecoration(
                    color: C.rowTop,
                    border: Border.all(color: C.rowEdge),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history, size: 16, color: C.label),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Settings from Project Folder Manager 6.2 are on this PC.',
                          style: t(12, color: C.soft),
                        ),
                      ),
                      Btn('BRING THEM IN', kind: BtnKind.ghost, onTap: () => cmd.importV6(v6.path)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DriveCard extends StatelessWidget {
  const _DriveCard({required this.drive, required this.onTap});
  final DriveInfo drive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = drive;
    final pct = d.usedPercent;
    final bar = pct >= 90 ? C.barHot : (pct >= 75 ? C.barMid : C.barOk);
    return Opacity(
      opacity: d.ready ? 1 : .45,
      child: Hover(
        cursor: d.ready ? SystemMouseCursors.click : SystemMouseCursors.basic,
        builder: (context, h) => Tooltip(
          message: d.ready ? 'Open ${d.root}' : 'No media in this drive',
          child: GestureDetector(
            onTap: d.ready ? onTap : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 220,
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
              decoration: BoxDecoration(
                color: h && d.ready ? C.rowHoverTop : C.rowTop,
                border: Border.all(color: h && d.ready ? C.teal : C.rowEdge),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.storage_rounded, size: 26, color: h && d.ready ? C.tealHi : C.label),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${d.letter}:  ',
                                style: t(14, color: C.tealHi, w: FontWeight.bold),
                              ),
                              TextSpan(
                                text: d.label.isNotEmpty ? d.label : d.type,
                                style: t(13, color: C.white, w: FontWeight.w600),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          d.ready ? '${driveSize(d.free)} free of ${driveSize(d.total)}' : '${d.type}, not ready',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t(11, color: C.muted),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: d.ready ? pct / 100 : 0,
                            minHeight: 4,
                            backgroundColor: C.barTrack,
                            color: bar,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.model, required this.cmd});
  final AppModel model;
  final Commands cmd;
  @override
  Widget build(BuildContext context) {
    final filtered = model.query.trim().isNotEmpty || model.discipline.isNotEmpty;
    if (filtered) {
      return Padding(
        padding: const EdgeInsets.all(30),
        child: Text(
          'No folder matches${model.query.trim().isNotEmpty ? ' "${model.query.trim()}"' : ''}'
          '${model.discipline.isNotEmpty ? ' in ${model.discipline}' : ''}.'
          '${model.index.isEmpty ? '' : ' Turn DEEP on to search every folder and file.'}',
          style: t(13, color: C.muted),
        ),
      );
    }
    return _Message(
      icon: Icons.create_new_folder_outlined,
      title: 'No folders in here yet',
      text:
          '${model.root}\n\nMake the standard project folders (00_Admin … 99_Archive), or add your own: they show up '
          'here by themselves.',
      actions: [
        Btn(
          'MAKE THE STANDARD FOLDERS',
          icon: Icons.create_new_folder_outlined,
          kind: BtnKind.on,
          onTap: cmd.offerStandardFolders,
        ),
        Btn('OPEN ANOTHER FOLDER', icon: Icons.folder_open, onTap: cmd.browse),
      ],
    );
  }
}
