// The DRIVES strip, the status line at the bottom with its thin index bar, and the bar that
// shows a copy or move going on, with CANCEL.
import 'package:flutter/material.dart';

import '../brand.dart';
import '../core/format.dart';
import '../platform/shell.dart';
import '../state/app_model.dart';
import 'commands.dart';
import 'theme.dart';
import 'widgets.dart';

class DrivesStrip extends StatelessWidget {
  const DrivesStrip({super.key, required this.model, required this.cmd});
  final AppModel model;
  final Commands cmd;

  @override
  Widget build(BuildContext context) {
    final drives = model.drives;
    final rootLetter = model.root.isEmpty ? '' : model.root[0].toUpperCase();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: const BoxDecoration(
        color: C.driveStrip,
        border: Border(bottom: BorderSide(color: C.driveStripEdge)),
      ),
      child: drives.isEmpty
          ? const Lbl('no drives could be read on this PC')
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [for (final d in drives) _tile(d, d.letter == rootLetter)]),
            ),
    );
  }

  Widget _tile(DriveInfo d, bool isRoot) {
    final name = d.label.isNotEmpty ? d.label : d.type;
    final pct = d.usedPercent;
    final bar = pct >= 90 ? C.barHot : (pct >= 75 ? C.barMid : C.barOk);
    return Opacity(
      opacity: d.ready ? 1 : .45,
      child: Hover(
        cursor: d.ready ? SystemMouseCursors.click : SystemMouseCursors.basic,
        builder: (context, h) => Tooltip(
          message: d.ready ? 'Open ${d.root} in the panel' : 'No media in this drive',
          child: GestureDetector(
            onTap: d.ready ? () => cmd.view(d.root) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 196,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
              decoration: BoxDecoration(
                color: h && d.ready ? C.rowHoverTop : C.driveTop,
                border: Border.all(color: h && d.ready ? C.teal : (isRoot ? C.rowHoverEdge : C.driveEdge)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${d.letter}:',
                        style: t(13, color: C.tealHi, w: FontWeight.bold),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t(12, color: C.title, w: FontWeight.w600),
                        ),
                      ),
                      if (isRoot)
                        const Padding(
                          padding: EdgeInsets.only(left: 5),
                          child: Tooltip(
                            message: 'The open folder is on this drive',
                            child: Icon(Icons.circle, size: 7, color: C.teal),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    d.ready ? '${driveSize(d.free)} free of ${driveSize(d.total)}' : '${d.type}, not ready',
                    style: t(10, color: C.muted),
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
          ),
        ),
      ),
    );
  }
}

class StatusBar extends StatelessWidget {
  const StatusBar({super.key, required this.model, required this.width});
  final AppModel model;
  final double width;

  @override
  Widget build(BuildContext context) {
    final idx = model.index;
    final pg = model.progress;
    String right;
    if (model.indexing && pg != null) {
      right = 'indexing ${pg.percent}%';
    } else if (idx.isEmpty) {
      right = 'no index yet';
    } else {
      right = 'index ${idx.length} items${idx.built == null ? '' : ', ${ago(idx.built!, model.now())}'}';
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 2,
          child: pg == null
              ? null
              : Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: pg.percent / 100,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: C.teal,
                        boxShadow: [BoxShadow(color: C.teal, blurRadius: 10)],
                      ),
                    ),
                  ),
                ),
        ),
        Container(
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: const BoxDecoration(
            color: C.status,
            border: Border(top: BorderSide(color: C.barEdge)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  model.status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t(11, color: C.label),
                ),
              ),
              if (width >= 700) Text(right, style: t(10, color: C.faint, ls: 1)),
              if (width >= 900) ...[
                const SizedBox(width: 18),
                Text('$appName v$appVersion  ·  Excel to KML', style: t(10, color: C.faint, ls: 1)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// "Copying 3 of 10 · name" with CANCEL, over the bottom of the window
class OpBar extends StatelessWidget {
  const OpBar({super.key, required this.model});
  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final op = model.op!;
    final verb = model.clipCut ? 'Moving' : 'Copying';
    return Material(
      color: C.clip,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: C.teal)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: C.teal)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                op.count == 0
                    ? 'working ...'
                    : '$verb ${op.index} of ${op.count}  ·  ${op.name}${op.files > 0 ? '  ·  ${plural(op.files, 'file')}' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t(12),
              ),
            ),
            Btn('CANCEL', icon: Icons.close, onTap: model.cancelOp),
          ],
        ),
      ),
    );
  }
}
