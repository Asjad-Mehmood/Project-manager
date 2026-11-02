// The banner: the project's title (click to rename it), the clock and the month's calendar,
// and the four KPIs. Parts step aside on a narrow window exactly where v6.2's did.
import 'dart:async';

import 'package:flutter/material.dart';

import '../brand.dart';
import '../core/format.dart';
import '../state/app_model.dart';
import 'theme.dart';
import 'widgets.dart';

class Header extends StatelessWidget {
  const Header({super.key, required this.model, required this.width, required this.onEditTitle, this.clock});
  final AppModel model;
  final double width;
  final VoidCallback onEditTitle;

  /// Fixed time for screenshots
  final DateTime? clock;

  @override
  Widget build(BuildContext context) {
    final (mods, onDisk, indexed, missing) = model.kpis;
    final narrow = width < 1120;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 9, 18, 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [C.headerTop, C.headerBottom],
        ),
        border: Border(bottom: BorderSide(color: C.headerEdge)),
        boxShadow: [BoxShadow(color: Color(0x8C000000), blurRadius: 12, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 38,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _Title(model.title, onEditTitle),
                if (!narrow) ...[
                  const SizedBox(height: 3),
                  Text(
                    '$appName  ·  $appTagline  ·  v$appVersion',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t(11, color: C.subtitle, ls: .6),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: ClockAndCalendar(width: width, fixed: clock),
          ),
          Expanded(
            flex: 38,
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Kpi(mods, 'MODULES'),
                    Kpi(onDisk, 'ON DISK'),
                    if (width >= 1250) Kpi(indexed, 'INDEXED', color: C.amber, glow: const Color(0xFFAA6600)),
                    if (width >= 1120) Kpi(missing, 'MISSING', color: C.red, glow: const Color(0xFF992222)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text, this.onTap);
  final String text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Hover(
    cursor: SystemMouseCursors.click,
    builder: (context, h) => Tooltip(
      message: 'Click to rename this project',
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t(23, color: h ? C.tealHi : C.title, w: FontWeight.bold, ls: .6).copyWith(
            shadows: const [Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 2))],
          ),
        ),
      ),
    ),
  );
}

/// The clock, the date, and a little calendar you can step through month by month
class ClockAndCalendar extends StatefulWidget {
  const ClockAndCalendar({super.key, required this.width, this.fixed});
  final double width;
  final DateTime? fixed;
  @override
  State<ClockAndCalendar> createState() => _ClockAndCalendarState();
}

class _ClockAndCalendarState extends State<ClockAndCalendar> {
  Timer? _timer;
  late DateTime _now;
  late int _y, _m;

  @override
  void initState() {
    super.initState();
    _now = widget.fixed ?? DateTime.now();
    _y = _now.year;
    _m = _now.month;
    if (widget.fixed == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

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
    final w = widget.width;
    final big = w >= 1000;
    final showCal = w >= 1150;
    final clock = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          clockText(_now),
          style: t(
            big ? 28 : 22,
            color: C.teal,
            w: FontWeight.bold,
            ls: 2,
            m: true,
            h: 1,
          ).copyWith(shadows: const [Shadow(color: Color(0x7313A8A8), blurRadius: 12)]),
        ),
        const SizedBox(height: 3),
        Text(longDate(_now), style: t(11, color: C.softer)),
      ],
    );
    if (!showCal) return clock;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.only(right: 14),
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: C.fieldEdge)),
          ),
          child: clock,
        ),
        const SizedBox(width: 14),
        _calendar(),
      ],
    );
  }

  Widget _calendar() {
    final weeks = monthGrid(_y, _m);
    final isThisMonth = _now.year == _y && _now.month == _m;
    Widget arrow(IconData i, int d, String tip) => Tooltip(
      message: tip,
      child: InkWell(
        onTap: () => _move(d),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Icon(i, size: 11, color: C.teal),
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            arrow(Icons.arrow_left, -1, 'Month before'),
            Tooltip(
              message: 'Back to today',
              child: InkWell(
                onTap: () => setState(() {
                  _y = _now.year;
                  _m = _now.month;
                }),
                child: Text('${months[_m - 1].substring(0, 3).toUpperCase()} $_y', style: t(10, w: FontWeight.bold)),
              ),
            ),
            arrow(Icons.arrow_right, 1, 'Month after'),
          ],
        ),
        const SizedBox(height: 2),
        Table(
          defaultColumnWidth: const FixedColumnWidth(17),
          children: [
            TableRow(
              children: [
                for (final d in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                  Center(
                    child: Text(d, style: t(8, color: C.muted, h: 1.25)),
                  ),
              ],
            ),
            for (final wk in weeks)
              TableRow(
                children: [
                  for (final d in wk)
                    Container(
                      height: 12,
                      alignment: Alignment.center,
                      decoration: isThisMonth && d == _now.day
                          ? BoxDecoration(color: C.teal, borderRadius: BorderRadius.circular(2))
                          : null,
                      child: Text(
                        d == 0 ? '' : '$d',
                        style: isThisMonth && d == _now.day
                            ? t(9, color: C.ink, w: FontWeight.bold, h: 1.2)
                            : t(9, color: const Color(0xFF8FA8BD), h: 1.2),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
