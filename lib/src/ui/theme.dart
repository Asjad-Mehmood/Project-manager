// The colours, fonts and sizes: 6.2's teal and amber, on calmer, flatter surfaces (7.1).
import 'package:flutter/material.dart';

abstract final class C {
  // v7.1: the same teal and amber as 6.2, on calm, flat surfaces with soft rounded edges
  static const bg = Color(0xFF0B121C);
  static const text = Color(0xFFDCE6EE);
  static const white = Color(0xFFF4F8FB);
  static const teal = Color(0xFF4FA6A1);
  static const tealHi = Color(0xFF8CC9C5);
  static const tealEdge = Color(0xFF6DB5B0);
  static const amber = Color(0xFFCFA766);
  static const amberHi = Color(0xFFDDBE88);
  static const gold = Color(0xFFC4A06A);
  static const red = Color(0xFFC98A76);
  static const green = Color(0xFF87AE82);
  static const ink = Color(0xFF04121E); // text on a bright button
  static const label = Color(0xFF8297AA);
  static const muted = Color(0xFF64798D);
  static const soft = Color(0xFFA9BCCB);
  static const softer = Color(0xFF9FB2C2);
  static const faint = Color(0xFF3F566C);
  static const title = Color(0xFFF1F6FA);
  static const subtitle = Color(0xFF7D93A6);

  // the top bar
  static const top = Color(0xFF101A27);
  static const topEdge = Color(0xFF1C2A3B);
  static const mark = Color(0xFF0E2E33);

  static const barTop = top;
  static const barBottom = top;
  static const barEdge = topEdge;
  static const field = Color(0xFF0A121C);
  static const fieldEdge = Color(0xFF243548);
  static const btnTop = Color(0xFF172536);
  static const btnBottom = Color(0xFF172536);
  static const btnText = Color(0xFFCAD8E4);
  static const onTop = Color(0xFF4FA6A1);
  static const onBottom = Color(0xFF4FA6A1);

  static const rowTop = Color(0xFF111B28);
  static const rowBottom = Color(0xFF111B28);
  static const rowEdge = Color(0xFF1A2737);
  static const rowHoverTop = Color(0xFF15233A);
  static const rowHoverBottom = Color(0xFF15233A);
  static const rowHoverEdge = Color(0xFF28505A);
  static const kidTop = Color(0xFF0E1723);
  static const kidBottom = Color(0xFF0E1723);
  static const subBg = Color(0xFF0F2E33);
  static const subEdge = Color(0xFF1A4A50);

  static const panelTop = Color(0xFF0D1520);
  static const panelBottom = Color(0xFF0D1520);
  static const panelHeadTop = Color(0xFF111C29);
  static const panelHeadBottom = Color(0xFF111C29);
  static const tools = Color(0xFF0D1520);
  static const tools2 = Color(0xFF0F1823);
  static const toolsEdge = Color(0xFF1A2737);
  static const vrowEdge = Color(0xFF151F2C);
  static const vrowHover = Color(0xFF142131);
  static const vrowHoverEdge = Color(0xFF2A6470);
  static const selected = Color(0xFF173246);
  static const goBg = Color(0xFF12383A);
  static const goEdge = Color(0xFF1D5C5C);
  static const clip = Color(0xFF102033);
  static const status = Color(0xFF0D1520);
  static const dialog = Color(0xFF111C29);

  static const driveTop = Color(0xFF111B28);
  static const driveBottom = Color(0xFF111B28);
  static const driveEdge = Color(0xFF1C2B3C);
  static const driveStrip = Color(0xFF0D1520);
  static const driveStripEdge = Color(0xFF1A2737);
  static const barTrack = Color(0xFF0A1420);
  static const barOk = Color(0xFF5E9E95);
  static const barMid = Color(0xFFBFA45E);
  static const barHot = Color(0xFFB97E68);

  static const chipGrey = Color(0xFF3A4A58);
}

/// The corner rounding used everywhere
const radius = 6.0;

const sans = 'Segoe UI';
const sansFallback = ['Tahoma', 'Arial', 'sans-serif'];
const mono = 'Consolas';
const monoFallback = ['Courier New', 'monospace'];

TextStyle t(double size, {Color color = C.text, FontWeight? w, double? ls, bool m = false, double? h}) => TextStyle(
  fontFamily: m ? mono : sans,
  fontFamilyFallback: m ? monoFallback : sansFallback,
  fontSize: size,
  color: color,
  fontWeight: w,
  letterSpacing: ls,
  height: h,
);

ThemeData pfmTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    fontFamily: sans,
    fontFamilyFallback: sansFallback,
    scaffoldBackgroundColor: C.bg,
    colorScheme: const ColorScheme.dark(
      primary: C.teal,
      secondary: C.amber,
      surface: C.dialog,
      onSurface: C.text,
      error: C.red,
    ),
    visualDensity: VisualDensity.compact,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    useMaterial3: true,
  );
  return base.copyWith(
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: C.teal,
      selectionColor: Color(0x664FA6A1),
      selectionHandleColor: C.teal,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: const Color(0xFF0C2033),
        border: Border.all(color: C.fieldEdge),
        borderRadius: BorderRadius.circular(radius),
      ),
      textStyle: t(11, color: C.text),
      waitDuration: const Duration(milliseconds: 500),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: C.dialog,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: C.fieldEdge),
        borderRadius: BorderRadius.circular(8),
      ),
      elevation: 3,
      textStyle: t(12),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.all(const Color(0xFF23364A)),
      thickness: WidgetStateProperty.all(8),
      radius: const Radius.circular(4),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: C.clip,
      contentTextStyle: t(12),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: C.fieldEdge),
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: C.dialog,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: C.fieldEdge),
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}
