// One calm row under the banner. Every v6.2 option is still here, grouped where you'd look for it:
//   [Project ▾]  [🔍 Search …] DEEP [Discipline ▾]          LIST ▾  INDEX ▾  GO TO ▾  [▣ ▾]  ⋯
//   Project ▾  switch project, open a folder (BROWSE), type a path (ROOT PATH + SET), FIND,
//              rename the project, OPEN ROOT, take it off the list
//   LIST ▾     ALWAYS TREE, MISSING, COLLAPSE, SCAN, REBUILD, FIX NAMES, REFRESH
//   INDEX ▾    this project / whole drive / all drives, STOP, and how the index is made
//   GO TO ▾    pinned folders, every drive, the DRIVES strip
//   ▣ ▾        the six VIEW layouts (Alt+1 … Alt+6)
//   ⋯          bring in v6 settings, updates, shortcuts, about
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

class Toolbar extends StatelessWidget {
  const Toolbar({
    super.key,
    required this.model,
    required this.cmd,
    required this.searchField,
    required this.searchFocus,
    required this.onCheckUpdates,
  });

  final AppModel model;
  final Commands cmd;
  final TextEditingController searchField;
  final FocusNode searchFocus;
  final VoidCallback onCheckUpdates;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) => _build(box.maxWidth));

  Widget _build(double w) {
    final o = model.options;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 14, 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [C.barTop, C.barBottom],
        ),
        border: Border(bottom: BorderSide(color: C.barEdge)),
      ),
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 8,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: [
              _ProjectPicker(model: model, cmd: cmd, width: (w * .27).clamp(250, 440)),
              const SizedBox(width: 14),
              _search((w * .2).clamp(200, 340)),
              Btn(
                'DEEP',
                kind: BtnKind.ghost,
                lit: o.deep,
                onTap: () => model.setDeep(!o.deep),
                tip: o.deep ? 'Searching every folder and file in the index' : 'Searching module names only',
              ),
              const SizedBox(width: 8),
              Select<String>(
                value: model.discipline,
                items: ['', ...disciplines.keys],
                label: (d) => d.isEmpty ? 'All disciplines' : d,
                onChanged: model.filterDiscipline,
                width: 170,
                tip: 'Show one discipline only',
              ),
            ],
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: [
              _list(),
              _index(),
              _goTo(),
              _ViewPicker(model: model),
              _more(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _search(double width) => SizedBox(
    width: width,
    height: 28,
    child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          searchField.clear();
          model.setQuery('');
        },
      },
      child: _searchBox(),
    ),
  );

  Widget _searchBox() => SizedBox(
    child: TextField(
      controller: searchField,
      focusNode: searchFocus,
      style: t(12),
      onChanged: model.setQuery,
      decoration:
          fieldDecoration(
            hint: model.options.deep && !model.index.isEmpty
                ? 'Search every folder and file  (Ctrl+F)'
                : 'Search modules  (Ctrl+F)',
          ).copyWith(
            prefixIcon: const Icon(Icons.search, size: 16, color: C.label),
            prefixIconConstraints: const BoxConstraints(minWidth: 30),
            suffixIcon: model.query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear  (Esc)',
                    iconSize: 14,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    icon: const Icon(Icons.close, color: C.label),
                    onPressed: () {
                      searchField.clear();
                      model.setQuery('');
                    },
                  ),
          ),
    ),
  );

  Widget _list() {
    final o = model.options;
    return MenuBtn(
      'LIST',
      icon: Icons.account_tree_outlined,
      tip: 'How the module list shows, and keeping it in step with the disk',
      items: () => [
        menuHeading('SHOW'),
        menuItem('Always open the whole tree', () => model.setTree(!o.tree), on: o.tree),
        menuItem('Hide modules that are missing', () => model.setHideMissing(!o.hideMissing), on: o.hideMissing),
        menuItem('Collapse everything', model.collapseAll, icon: Icons.unfold_less),
        const PopupMenuDivider(height: 8),
        menuHeading('KEEP IN STEP WITH THE DISK'),
        menuItem('Scan: add new folders', cmd.scan, icon: Icons.add_circle_outline),
        menuItem('Fix names: follow renamed folders', cmd.fixNames, icon: Icons.build_outlined),
        menuItem('Rebuild the list from this PC', cmd.rebuild, icon: Icons.recycling),
        menuItem('Refresh from the disk  (F5)', model.refresh, icon: Icons.refresh),
      ],
    );
  }

  Widget _index() {
    final o = model.options;
    final idx = model.index;
    final pg = model.progress;
    final drive = p.rootPrefix(model.root);
    return MenuBtn(
      model.indexing ? 'INDEXING ${pg?.percent ?? 0}%' : 'INDEX',
      icon: Icons.bolt,
      lit: model.indexing,
      tip: idx.isEmpty
          ? 'No index yet: search finds module names only'
          : 'Index: ${idx.length} items in ${idx.scopeName}'
                '${idx.built == null ? '' : ', made ${ago(idx.built!, model.now())}'}',
      items: () => [
        if (model.indexing) ...[
          menuItem('Stop, and keep what was found', model.stopIndex, icon: Icons.stop),
          const PopupMenuDivider(height: 8),
        ],
        menuHeading('READ EVERYTHING ONCE, SO SEARCH IS INSTANT'),
        menuItem(
          'Index this project',
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
          'Index the project by itself',
          () => model.setAutoIndex(!o.autoIndex),
          on: o.autoIndex,
          sub: 'in the background, when it is new or more than ${staleAfter.inHours} hours old',
        ),
        menuItem('Files too, not only folders', () {
          o.files = !o.files;
          model.optionsChanged();
        }, on: o.files),
        menuItem(
          'Levels in a project: ${o.depth}',
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

  Widget _goTo() {
    final pins = model.settings.pinned;
    String driveLine(DriveInfo d) => '${d.letter}:  ${d.label.isEmpty ? d.type : d.label}';
    return MenuBtn(
      'GO TO',
      icon: Icons.star_border,
      tip: 'Pinned folders and drives',
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
            menuItem(
              driveLine(d),
              () => cmd.view(d.root),
              icon: Icons.storage,
              sub: '${driveSize(d.free)} free of ${driveSize(d.total)}',
            ),
          menuItem('Show the drives strip', () => model.setDrives(!model.options.drives), on: model.options.drives),
        ];
      },
    );
  }

  Widget _more() => MenuBtn(
    '',
    icon: Icons.more_horiz,
    caret: false,
    tip: 'More',
    items: () => [
      menuItem('Bring in settings from v6 ...', cmd.importV6, icon: Icons.file_download_outlined),
      menuItem('Look for an update', onCheckUpdates, icon: Icons.system_update_alt),
      menuItem('Keyboard shortcuts', cmd.shortcuts, icon: Icons.keyboard_outlined),
      menuItem('About', cmd.about, icon: Icons.info_outline),
    ],
  );
}

/// The project: its name and folder, a click away from everything about it
class _ProjectPicker extends StatelessWidget {
  const _ProjectPicker({required this.model, required this.cmd, required this.width});
  final AppModel model;
  final Commands cmd;
  final double width;

  List<PopupMenuEntry<VoidCallback>> _items() {
    final s = model.settings;
    final has = model.project != null;
    return [
      if (s.projects.isNotEmpty) menuHeading('YOUR PROJECTS'),
      for (var i = 0; i < s.projects.length; i++)
        menuItem(
          s.projects[i].title.isEmpty ? p.basename(s.projects[i].root) : s.projects[i].title,
          i == s.current ? () {} : () => model.switchProject(i),
          checked: i == s.current,
          icon: Icons.folder_outlined,
          sub: s.projects[i].root,
        ),
      if (s.projects.isNotEmpty) const PopupMenuDivider(height: 8),
      menuHeading('OPEN A PROJECT'),
      menuItem('Pick its folder ...', cmd.browse, icon: Icons.folder_open),
      menuItem('Type or paste its path ...', cmd.typePath, icon: Icons.edit_note),
      menuItem('Find projects on my drives ...', cmd.find, icon: Icons.search),
      if (has) ...[
        const PopupMenuDivider(height: 8),
        menuHeading('THIS PROJECT'),
        menuItem('Open the root folder in Explorer', cmd.openRoot, icon: Icons.bolt),
        menuItem('Rename the project ...', cmd.editTitle, icon: Icons.edit),
        menuItem('Take it off the list', () => cmd.forgetProject(s.current), icon: Icons.playlist_remove),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final has = model.project != null;
    return Builder(
      builder: (ctx) => Hover(
        cursor: SystemMouseCursors.click,
        builder: (context, h) => Tooltip(
          message: 'Switch or open a project',
          child: GestureDetector(
            onTap: () => showMenuBelow(ctx, _items()),
            child: Container(
              width: width,
              height: 30,
              padding: const EdgeInsets.only(left: 8, right: 4),
              decoration: BoxDecoration(
                color: C.field,
                border: Border.all(color: h ? C.teal : C.fieldEdge),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Row(
                children: [
                  folderIcon,
                  const SizedBox(width: 8),
                  if (!has)
                    Expanded(
                      child: Text('Open a project ...', style: t(12, color: C.soft)),
                    )
                  else
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: model.project!.title.isEmpty ? p.basename(model.root) : model.project!.title,
                              style: t(12, color: C.white, w: FontWeight.bold),
                            ),
                            TextSpan(
                              text: '   ${model.root}',
                              style: t(11, color: C.amber, m: true),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Icon(Icons.arrow_drop_down, size: 18, color: h ? C.tealHi : C.label),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// VIEW: one button showing the layout in use; the six are in its menu
class _ViewPicker extends StatelessWidget {
  const _ViewPicker({required this.model});
  final AppModel model;

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
          ]),
          child: Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.fromLTRB(3, 2, 0, 2),
            decoration: BoxDecoration(
              color: h ? const Color(0x2213A8A8) : null,
              border: Border.all(color: h ? C.fieldEdge : Colors.transparent),
              borderRadius: BorderRadius.circular(3),
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
