import 'package:flutter/material.dart';
import 'dart:math' as math;

class ColorPickerDialog extends StatefulWidget {
  final Color initialColor;

  const ColorPickerDialog({super.key, required this.initialColor});

  static Future<Color?> show(BuildContext context, Color initialColor) {
    return showDialog<Color>(
      context: context,
      builder: (_) => ColorPickerDialog(initialColor: initialColor),
    );
  }

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late double _hue;
  late double _saturation;
  late double _value;
  late int _r;
  late int _g;
  late int _b;

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initialColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
    _updateRgbFromHsv();
  }

  void _updateRgbFromHsv() {
    final c = HSVColor.fromAHSV(1, _hue, _saturation, _value).toColor();
    _r = (c.r * 255.0).round().clamp(0, 255);
    _g = (c.g * 255.0).round().clamp(0, 255);
    _b = (c.b * 255.0).round().clamp(0, 255);
  }

  void _updateHsvFromRgb() {
    final c = Color.fromARGB(255, _r, _g, _b);
    final hsv = HSVColor.fromColor(c);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
  }

  void _onWheelInteraction(Offset pos, Size size) {
    const ringWidth = 28.0;
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius - ringWidth;

    final dx = pos.dx - center.dx;
    final dy = pos.dy - center.dy;
    final dist = math.sqrt(dx * dx + dy * dy);

    if (dist >= innerRadius && dist <= outerRadius) {
      var angle = math.atan2(dy, dx) * 180 / math.pi + 90;
      if (angle < 0) angle += 360;
      setState(() {
        _hue = angle.clamp(0, 359);
        _updateRgbFromHsv();
      });
      return;
    }

    if (dist < innerRadius) {
      final squareSize = innerRadius * math.sqrt2;
      final left = center.dx - squareSize / 2;
      final top = center.dy - squareSize / 2;
      final s = ((pos.dx - left) / squareSize).clamp(0.0, 1.0);
      final v = (1 - (pos.dy - top) / squareSize).clamp(0.0, 1.0);
      setState(() {
        _saturation = s;
        _value = v;
        _updateRgbFromHsv();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Custom Accent Color'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onPanDown: (details) => _onWheelInteraction(
                  details.localPosition,
                  const Size(240, 240),
                ),
                onPanUpdate: (details) => _onWheelInteraction(
                  details.localPosition,
                  const Size(240, 240),
                ),
                child: CustomPaint(
                  size: const Size(240, 240),
                  painter: _ColorWheelPainter(
                    hue: _hue,
                    saturation: _saturation,
                    value: _value,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 40,
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, _r, _g, _b),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'RGB($_r, $_g, $_b)',
                    style: TextStyle(
                      color: (_r * 0.299 + _g * 0.587 + _b * 0.114) > 128
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildRgbSlider(
                label: 'R',
                value: _r,
                color: Colors.red,
                onChanged: (v) => setState(() {
                  _r = v;
                  _updateHsvFromRgb();
                }),
              ),
              _buildRgbSlider(
                label: 'G',
                value: _g,
                color: Colors.green,
                onChanged: (v) => setState(() {
                  _g = v;
                  _updateHsvFromRgb();
                }),
              ),
              _buildRgbSlider(
                label: 'B',
                value: _b,
                color: Colors.blue,
                onChanged: (v) => setState(() {
                  _b = v;
                  _updateHsvFromRgb();
                }),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, Color.fromARGB(255, _r, _g, _b)),
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _buildRgbSlider({
    required String label,
    required int value,
    required Color color,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 16,
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 255,
            activeColor: color,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _ColorWheelPainter extends CustomPainter {
  final double hue;
  final double saturation;
  final double value;

  _ColorWheelPainter({
    required this.hue,
    required this.saturation,
    required this.value,
  });

  static const double _ringWidth = 28;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius - _ringWidth;

    _drawHueRing(canvas, center, outerRadius, innerRadius);
    _drawSvSquare(canvas, center, innerRadius);
    _drawHueThumb(canvas, center, outerRadius, innerRadius);
    _drawSvThumb(canvas, center, innerRadius);
  }

  void _drawHueRing(
    Canvas canvas,
    Offset center,
    double outerR,
    double innerR,
  ) {
    const steps = 360;
    for (var i = 0; i < steps; i++) {
      final startAngle = (i - 90) * math.pi / 180;
      final sweepAngle = 1.5 * math.pi / 180;
      final color = HSVColor.fromAHSV(1, i.toDouble(), 1, 1).toColor();
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerR - innerR;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: (outerR + innerR) / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  void _drawSvSquare(Canvas canvas, Offset center, double innerR) {
    final squareSize = innerR * math.sqrt2;
    final left = center.dx - squareSize / 2;
    final top = center.dy - squareSize / 2;
    final squareRect = Rect.fromLTWH(left, top, squareSize, squareSize);

    final clipPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: innerR));
    canvas.save();
    canvas.clipPath(clipPath);

    final hueColor = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    canvas.drawRect(squareRect, Paint()..color = hueColor);

    final whitePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Colors.white, const Color(0x00FFFFFF)],
      ).createShader(squareRect);
    canvas.drawRect(squareRect, whitePaint);

    final blackPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black],
      ).createShader(squareRect);
    canvas.drawRect(squareRect, blackPaint);

    canvas.restore();
  }

  void _drawHueThumb(
    Canvas canvas,
    Offset center,
    double outerR,
    double innerR,
  ) {
    final angle = (hue - 90) * math.pi / 180;
    final thumbR = (outerR + innerR) / 2;
    final thumbX = center.dx + thumbR * math.cos(angle);
    final thumbY = center.dy + thumbR * math.sin(angle);

    canvas.drawCircle(
      Offset(thumbX, thumbY),
      10,
      Paint()..color = HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
    );
    canvas.drawCircle(
      Offset(thumbX, thumbY),
      10,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawSvThumb(Canvas canvas, Offset center, double innerR) {
    final squareSize = innerR * math.sqrt2;
    final left = center.dx - squareSize / 2;
    final top = center.dy - squareSize / 2;

    final thumbX = left + saturation * squareSize;
    final thumbY = top + (1 - value) * squareSize;

    final color = HSVColor.fromAHSV(1, hue, saturation, value).toColor();
    canvas.drawCircle(Offset(thumbX, thumbY), 8, Paint()..color = color);
    canvas.drawCircle(
      Offset(thumbX, thumbY),
      8,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _ColorWheelPainter oldDelegate) =>
      oldDelegate.hue != hue ||
      oldDelegate.saturation != saturation ||
      oldDelegate.value != value;
}
