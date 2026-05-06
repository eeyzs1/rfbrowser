import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

SingleActivator? parseShortcut(String text) {
  final parts = text.split('+');
  bool control = false, shift = false, alt = false, meta = false;
  LogicalKeyboardKey? key;

  for (final part in parts) {
    switch (part.trim().toLowerCase()) {
      case 'ctrl':
      case 'control':
        control = true;
      case 'shift':
        shift = true;
      case 'alt':
        alt = true;
      case 'meta':
      case 'cmd':
        meta = true;
      default:
        key = _keyFromName(part.trim());
    }
  }
  return key == null ? null : SingleActivator(key, control: control, shift: shift, alt: alt, meta: meta);
}

LogicalKeyboardKey? _keyFromName(String name) {
  switch (name.toUpperCase()) {
    case 'A': return LogicalKeyboardKey.keyA;
    case 'B': return LogicalKeyboardKey.keyB;
    case 'C': return LogicalKeyboardKey.keyC;
    case 'D': return LogicalKeyboardKey.keyD;
    case 'E': return LogicalKeyboardKey.keyE;
    case 'F': return LogicalKeyboardKey.keyF;
    case 'G': return LogicalKeyboardKey.keyG;
    case 'H': return LogicalKeyboardKey.keyH;
    case 'I': return LogicalKeyboardKey.keyI;
    case 'J': return LogicalKeyboardKey.keyJ;
    case 'K': return LogicalKeyboardKey.keyK;
    case 'L': return LogicalKeyboardKey.keyL;
    case 'M': return LogicalKeyboardKey.keyM;
    case 'N': return LogicalKeyboardKey.keyN;
    case 'O': return LogicalKeyboardKey.keyO;
    case 'P': return LogicalKeyboardKey.keyP;
    case 'Q': return LogicalKeyboardKey.keyQ;
    case 'R': return LogicalKeyboardKey.keyR;
    case 'S': return LogicalKeyboardKey.keyS;
    case 'T': return LogicalKeyboardKey.keyT;
    case 'U': return LogicalKeyboardKey.keyU;
    case 'V': return LogicalKeyboardKey.keyV;
    case 'W': return LogicalKeyboardKey.keyW;
    case 'X': return LogicalKeyboardKey.keyX;
    case 'Y': return LogicalKeyboardKey.keyY;
    case 'Z': return LogicalKeyboardKey.keyZ;
    case '0': return LogicalKeyboardKey.digit0;
    case '1': return LogicalKeyboardKey.digit1;
    case '2': return LogicalKeyboardKey.digit2;
    case '3': return LogicalKeyboardKey.digit3;
    case '4': return LogicalKeyboardKey.digit4;
    case '5': return LogicalKeyboardKey.digit5;
    case '6': return LogicalKeyboardKey.digit6;
    case '7': return LogicalKeyboardKey.digit7;
    case '8': return LogicalKeyboardKey.digit8;
    case '9': return LogicalKeyboardKey.digit9;
    case 'ESC': case 'ESCAPE': return LogicalKeyboardKey.escape;
    case 'SPACE': return LogicalKeyboardKey.space;
    case 'ENTER': case 'RETURN': return LogicalKeyboardKey.enter;
    case 'TAB': return LogicalKeyboardKey.tab;
    case 'BACKSPACE': return LogicalKeyboardKey.backspace;
    case 'DELETE': return LogicalKeyboardKey.delete;
    case 'UP': return LogicalKeyboardKey.arrowUp;
    case 'DOWN': return LogicalKeyboardKey.arrowDown;
    case 'LEFT': return LogicalKeyboardKey.arrowLeft;
    case 'RIGHT': return LogicalKeyboardKey.arrowRight;
    case 'F1': return LogicalKeyboardKey.f1;
    case 'F2': return LogicalKeyboardKey.f2;
    case 'F3': return LogicalKeyboardKey.f3;
    case 'F4': return LogicalKeyboardKey.f4;
    case 'F5': return LogicalKeyboardKey.f5;
    case 'F6': return LogicalKeyboardKey.f6;
    case 'F7': return LogicalKeyboardKey.f7;
    case 'F8': return LogicalKeyboardKey.f8;
    case 'F9': return LogicalKeyboardKey.f9;
    case 'F10': return LogicalKeyboardKey.f10;
    case 'F11': return LogicalKeyboardKey.f11;
    case 'F12': return LogicalKeyboardKey.f12;
    default: return null;
  }
}
