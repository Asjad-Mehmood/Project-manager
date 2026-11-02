// The two rows under the banner, as v6.2 had them:
//   ROOT PATH [ … ] BROWSE FIND SET DRIVES VIEW ▢▢▢▢▢▢          OPEN ROOT SCAN REBUILD FIX NAMES
//   SEARCH [ … ] DEEP  DISCIPLINE [ … ]        ALWAYS TREE MISSING [scope] INDEX COLLAPSE REFRESH
// New in v7: PROJECTS (switch between projects), PINNED (folders kept to hand) and ⋯ (settings).
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../core/disciplines.dart';
import '../core/format.dart';
import '../core/settings.dart';
import '../state/app_model.dart';
import 'commands.dart';
import 'theme.dart';
import 'widgets.dart';

class Toolbar extends StatelessWidget {
  const Toolbar({
    super.key,
    required this.model,
    required this.cmd,
    required this.rootField,
    required this.searchField,
    required this.searchFocus,
    required this.onCheckUpdates,
  });

  final AppModel model;
  final Commands cmd;
  final TextEditingController rootField;
  final TextEditingController searchField;
  final FocusNode searchFocus;
  final VoidCallback onCheckUpdates;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) => _build(box.maxWidth));

  Widget _build(double w) {
    final o = model.options;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [C.barTop, C.barBottom],
        ),
        border: Border(bottom: BorderSide(color: C.barEdge)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _row(
            [
              const Lbl('ROOT PATH'),
              Field(
                controller: rootField,
                width: (w * .2).clamp(240, 380),
                style: t(12, color: C.amber, m: true),
                hint: r'D:\Project',
                tip: 'Paste the project folder and press Enter or SET',
                onSubmitted: cmd.setRoot,
              ),
              _projects(),
              Btn('BROWSE', onTap: cmd.browse, tip: 'Pick the project folder'),
              Btn('FIND', onTap: cmd.find, tip: 'Look on every drive for project folders'),
              Btn('SET', kind: BtnKind.on, onTap: () => cmd.setRoot(rootField.text)),
              Btn(
                'DRIVES',
                icon: Icons.storage,
                lit: o.drives,
                onTap: () => model.setDrives(!o.drives),
                tip: 'Show every drive on this PC',
              ),
              _pinned(),
              const SizedBox(width: 16),
              const Lbl('VIEW', right: 2),
              for (var i = 0; i < 6; i++)
                LayoutIcon(
                  i,
                  on: model.layout == i,
                  onTap: () => model.setLayout(i),
                  tip: '${layoutNames[i]}   (Alt+${i + 1})',
                ),
            ],
            [
              Btn('OPEN ROOT', icon: Icons.bolt, kind: BtnKind.amber, onTap: cmd.openRoot),
              Btn('SCAN', icon: Icons.refresh, onTap: cmd.scan, tip: 'Add folders that are new on the disk'),
              Btn(
                'REBUILD',
                icon: Icons.recycling,
                onTap: cmd.rebuild,
                tip: 'Make the list from the folders on this PC',
              ),
              Btn('FIX NAMES', icon: Icons.build, onTap: cmd.fixNames, tip: 'Find modules whose folder was renamed'),
              _more(),
            ],
          ),
          const SizedBox(height: 6),
          _row(
            [
              const Lbl('SEARCH'),
              Field(
                controller: searchField,
                focusNode: searchFocus,
                width: 260,
                hint: model.index.isEmpty ? 'module names' : 'every folder and file (Ctrl+F)',
                onChanged: model.setQuery,
                onEscape: () {
                  searchField.clear();
                  model.setQuery('');
                },
              ),
              Btn(
                'DEEP',
                icon: Icons.search,
                lit: o.deep,
                onTap: () => model.setDeep(!o.deep),
                tip: 'Search the whole index, every level',
              ),
              const SizedBox(width: 14),
              const Lbl('DISCIPLINE'),
              Select<String>(
                value: model.discipline,
                items: ['', ...disciplines.keys],
                label: (d) => d.isEmpty ? 'All disciplines' : d,
                onChanged: model.filterDiscipline,
                width: 180,
              ),
            ],
            [
              Btn(
                'ALWAYS TREE',
                icon: Icons.account_tree_outlined,
                lit: o.tree,
                onTap: () => model.setTree(!o.tree),
                tip: 'Keep the whole tree open every time',
              ),
              Btn(
                'MISSING',
                icon: Icons.visibility_off_outlined,
                lit: o.hideMissing,
                onTap: () => model.setHideMissing(!o.hideMissing),
                tip: 'Hide modules that are not on the disk',
              ),
              const SizedBox(width: 5),
              Select<IndexScope>(
                value: o.scope,
                items: IndexScope.values,
                label: (s) => s.label,
                onChanged: model.setScope,
                tip: 'How wide the index reaches',
              ),
              if (model.indexing)
                Btn(
                  'STOP',
                  icon: Icons.stop,
                  kind: BtnKind.amber,
                  onTap: model.stopIndex,
                  tip: 'Keep what was found so far',
                )
              else
                Btn(
                  'INDEX',
                  icon: Icons.bolt,
                  kind: BtnKind.amber,
                  onTap: cmd.index,
                  tip: 'Read everything once: makes search instant',
                ),
              Btn('COLLAPSE', icon: Icons.unfold_less, onTap: model.collapseAll),
              Btn('REFRESH', icon: Icons.refresh, onTap: model.refresh, tip: 'Read the disk again  (F5)'),
            ],
          ),
        ],
      ),
    );
  }

  /// A row: left group, right group pushed to the far side; wraps on a narrow window
  Widget _row(List<Widget> left, List<Widget> right) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    runSpacing: 6,
    children: [
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 6, children: left),
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 6, children: right),
    ],
  );

  Widget _projects() {
    final s = model.settings;
    return MenuBtn(
      '',
      icon: Icons.history,
      tip: 'Your projects: switch between them',
      items: () => [
        for (var i = 0; i < s.projects.length; i++)
          menuItem(
            s.projects[i].title.isEmpty ? p.basename(s.projects[i].root) : s.projects[i].title,
            i == s.current ? () {} : () => model.switchProject(i),
            checked: i == s.current,
            icon: Icons.folder_outlined,
            sub: s.projects[i].root,
          ),
        if (s.projects.isEmpty) menuItem('No projects yet: paste a folder and press SET', null),
        const PopupMenuDivider(height: 8),
        menuItem('Add a project ...', cmd.browse, icon: Icons.add),
        menuItem(
          'Take this project off the list',
          s.projects.isEmpty ? null : () => cmd.forgetProject(s.current),
          icon: Icons.playlist_remove,
        ),
      ],
    );
  }

  Widget _pinned() {
    final pins = model.settings.pinned;
    return MenuBtn(
      'PINNED',
      icon: Icons.star_border,
      tip: 'Folders kept to hand: right-click any folder to pin it',
      items: () => [
        for (final x in pins)
          menuItem(p.basename(x).isEmpty ? x : p.basename(x), () => cmd.view(x), icon: Icons.star, sub: x),
        if (pins.isEmpty) menuItem('Nothing pinned yet: right-click a folder and choose Pin', null),
        if (model.panelPath != null) ...[
          const PopupMenuDivider(height: 8),
          menuItem(
            model.isPinned(model.panelPath!) ? 'Unpin the panel\'s folder' : 'Pin the panel\'s folder',
            () => model.togglePin(model.panelPath!),
            icon: Icons.push_pin_outlined,
          ),
        ],
      ],
    );
  }

  Widget _more() {
    final o = model.options;
    final idx = model.index;
    return MenuBtn(
      '',
      icon: Icons.more_horiz,
      tip: 'Settings',
      items: () => [
        menuItem(
          'Index the project by itself',
          () => model.setAutoIndex(!o.autoIndex),
          checked: o.autoIndex,
          sub: 'in the background, when it is new or more than ${staleAfter.inHours} hours old',
        ),
        menuItem('Index files too, not only folders', () {
          o.files = !o.files;
          model.optionsChanged();
        }, checked: o.files),
        PopupMenuItem<VoidCallback>(
          enabled: false,
          height: 34,
          child: Row(
            children: [
              const SizedBox(width: 28),
              Text('Index depth in a project', style: t(12)),
              const Spacer(),
              for (final d in const [3, 6, 10, 20])
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Btn(
                    '$d',
                    small: true,
                    lit: o.depth == d,
                    onTap: () {
                      o.depth = d;
                      model.optionsChanged();
                    },
                  ),
                ),
            ],
          ),
        ),
        if (!idx.isEmpty)
          menuItem(
            'Index: ${idx.length} items in ${idx.scopeName}',
            null,
            sub: idx.built == null ? 'from v6' : 'made ${ago(idx.built!, DateTime.now())}',
          ),
        const PopupMenuDivider(height: 8),
        menuItem('Bring in settings from v6 ...', cmd.importV6, icon: Icons.file_download_outlined),
        menuItem('Look for an update', onCheckUpdates, icon: Icons.system_update_alt),
        menuItem('About', cmd.about, icon: Icons.info_outline),
      ],
    );
  }
}
