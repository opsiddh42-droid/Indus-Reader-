import 'package:flutter/material.dart';

class DrawingCanvas extends StatefulWidget {
  final VoidCallback onClose;
  final Function(List<DrawnLine>) onSave;

  const DrawingCanvas({super.key, required this.onClose, required this.onSave});

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  List<DrawnLine> lines = [];
  DrawnLine? currentLine;
  
  Color selectedColor = Colors.red;
  double strokeWidth = 5.0;
  double opacity = 1.0; // 1.0 = solid pen, 0.3 = highlighter

  // Pen ke liye colors ki list
  final List<Color> colors = [
    Colors.red, Colors.blue, Colors.green, Colors.black, Colors.yellow, Colors.purple
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Toolbar (Controls)
        Container(
          padding: const EdgeInsets.all(8.0),
          color: Colors.white,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: widget.onClose),
                  const Text('Draw Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green), 
                    onPressed: () => widget.onSave(lines), // Save karne par lines bhej dega
                  ),
                ],
              ),
              // Color Picker (Chote circles)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: colors.map((color) => GestureDetector(
                    onTap: () => setState(() => selectedColor = color),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: selectedColor == color ? Colors.black : Colors.transparent, width: 2),
                      ),
                    ),
                  )).toList(),
                ),
              ),
              // Size aur Transparency Sliders
              Row(
                children: [
                  const Icon(Icons.line_weight, size: 20),
                  Expanded(
                    child: Slider(
                      value: strokeWidth, min: 1, max: 20,
                      onChanged: (val) => setState(() => strokeWidth = val),
                    ),
                  ),
                  const Icon(Icons.opacity, size: 20),
                  Expanded(
                    child: Slider(
                      value: opacity, min: 0.1, max: 1.0,
                      onChanged: (val) => setState(() => opacity = val),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
        
        // Drawing Area (Invisible Canvas)
        Expanded(
          child: GestureDetector(
            onPanStart: (details) {
              setState(() {
                RenderBox renderBox = context.findRenderObject() as RenderBox;
                currentLine = DrawnLine(
                  path: [renderBox.globalToLocal(details.globalPosition)],
                  color: selectedColor.withOpacity(opacity),
                  width: strokeWidth,
                );
              });
            },
            onPanUpdate: (details) {
              setState(() {
                RenderBox renderBox = context.findRenderObject() as RenderBox;
                currentLine?.path.add(renderBox.globalToLocal(details.globalPosition));
              });
            },
            onPanEnd: (details) {
              setState(() {
                if (currentLine != null) {
                  lines.add(currentLine!);
                  currentLine = null;
                }
              });
            },
            child: CustomPaint(
              painter: CanvasPainter(lines: lines, currentLine: currentLine),
              size: Size.infinite,
            ),
          ),
        ),
      ],
    );
  }
}

// Line ka Data Model
class DrawnLine {
  final List<Offset> path;
  final Color color;
  final double width;
  DrawnLine({required this.path, required this.color, required this.width});
}

// Painter class jo actual mein line draw karti hai
class CanvasPainter extends CustomPainter {
  final List<DrawnLine> lines;
  final DrawnLine? currentLine;

  CanvasPainter({required this.lines, this.currentLine});

  @override
  void paint(Canvas canvas, Size size) {
    for (var line in lines) {
      _drawLine(canvas, line);
    }
    if (currentLine != null) {
      _drawLine(canvas, currentLine!);
    }
  }

  void _drawLine(Canvas canvas, DrawnLine line) {
    Paint paint = Paint()
      ..color = line.color
      ..strokeWidth = line.width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < line.path.length - 1; i++) {
      canvas.drawLine(line.path[i], line.path[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
