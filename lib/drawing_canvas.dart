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
  double opacity = 1.0; 

  // Colors list for Pen
  final List<Color> colors = [
    Colors.red, Colors.blue, Colors.green, Colors.black, Colors.yellow, Colors.purple, Colors.orange
  ];

  // NAYA: UNDO FUNCTION (Aakhiri line delete karne ke liye)
  void _undo() {
    if (lines.isNotEmpty) {
      setState(() => lines.removeLast());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // NAYA: SafeArea taaki menu app bar ke peeche na chhupe
        SafeArea(
          child: Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.white, // White background for clear visibility
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(icon: const Icon(Icons.close, color: Colors.red, size: 28), onPressed: widget.onClose),
                    
                    // UNDO BUTTON YAHAN HAI
                    IconButton(icon: const Icon(Icons.undo, color: Colors.blue, size: 28), onPressed: _undo),
                    
                    const Text('Freehand Draw', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    
                    // SAVE BUTTON YAHAN HAI (Jo PDF mein save karega)
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green, size: 32), 
                      onPressed: () => widget.onSave(lines), 
                    ),
                  ],
                ),
                // Color Picker
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: colors.map((color) => GestureDetector(
                      onTap: () => setState(() => selectedColor = color),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        width: 35, height: 35,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: selectedColor == color ? Colors.black : Colors.transparent, width: 3),
                        ),
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 5),
                // Size and Transparency Sliders
                Row(
                  children: [
                    const Icon(Icons.line_weight, size: 20),
                    Expanded(
                      child: Slider(value: strokeWidth, min: 1, max: 20, onChanged: (val) => setState(() => strokeWidth = val)),
                    ),
                    const Icon(Icons.opacity, size: 20),
                    Expanded(
                      child: Slider(value: opacity, min: 0.1, max: 1.0, onChanged: (val) => setState(() => opacity = val)),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
        
        // DRAWING AREA
        Expanded(
          child: GestureDetector(
            // NAYA: localPosition use kiya hai jisse touch offset bilkul accurate rahega
            onPanStart: (details) {
              setState(() {
                currentLine = DrawnLine(
                  path: [details.localPosition], 
                  color: selectedColor.withOpacity(opacity),
                  width: strokeWidth,
                );
              });
            },
            onPanUpdate: (details) {
              setState(() {
                currentLine?.path.add(details.localPosition); 
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
            child: Container(
              color: Colors.transparent, // Yeh line touch detect karne ke liye zaroori hai
              width: double.infinity,
              height: double.infinity,
              child: CustomPaint(
                painter: CanvasPainter(lines: lines, currentLine: currentLine),
                size: Size.infinite,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class DrawnLine {
  final List<Offset> path;
  final Color color;
  final double width;
  DrawnLine({required this.path, required this.color, required this.width});
}

class CanvasPainter extends CustomPainter {
  final List<DrawnLine> lines;
  final DrawnLine? currentLine;

  CanvasPainter({required this.lines, this.currentLine});

  @override
  void paint(Canvas canvas, Size size) {
    for (var line in lines) _drawLine(canvas, line);
    if (currentLine != null) _drawLine(canvas, currentLine!);
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
