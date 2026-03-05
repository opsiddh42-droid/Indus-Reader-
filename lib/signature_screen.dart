import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:io';

import 'pdf_services.dart';
import 'drawing_canvas.dart'; // DrawnLine model ke liye

class SignatureScreen extends StatefulWidget {
  const SignatureScreen({super.key});

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  File? _selectedFile;
  int _totalPages = 0;
  bool _isProcessing = false;
  
  // Page number ke liye controller
  final TextEditingController _pageController = TextEditingController(text: "1");
  
  // Signature draw karne ke variables
  List<DrawnLine> _lines = [];
  DrawnLine? _currentLine;

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['pdf'],
    );

    if (result != null) {
      String path = result.files.single.path!;
      final List<int> bytes = File(path).readAsBytesSync();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      int pages = document.pages.count;
      document.dispose();

      setState(() {
        _selectedFile = File(path);
        _totalPages = pages;
        _pageController.text = "1";
      });
    }
  }

  // Signature ko clear karne ka function
  void _clearSignature() {
    setState(() {
      _lines.clear();
      _currentLine = null;
    });
  }

  Future<void> _applySignature() async {
    if (_selectedFile == null) return;
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please draw your signature first!'), backgroundColor: Colors.red));
      return;
    }

    int pageNum = int.tryParse(_pageController.text) ?? 1;
    if (pageNum < 1 || pageNum > _totalPages) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Page Number!'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final dir = await getApplicationDocumentsDirectory();
      final outputPath = '${dir.path}/signed_${DateTime.now().millisecondsSinceEpoch}.pdf';

      // Backend ko call karna (page index 0 se shuru hota hai isliye -1 kiya)
      await PdfServices.addSignature(
        inputPath: _selectedFile!.path,
        outputPath: outputPath,
        pageIndex: pageNum - 1,
        lines: _lines,
      );

      setState(() => _isProcessing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signature Added Successfully! Check Recent Files.'), backgroundColor: Colors.green));
        Navigator.pop(context); // Wapas Home par bhej dega
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error adding signature.'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('E-Signature', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select a PDF, draw your signature, and it will be placed at the bottom right of the page.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            
            // File Select Button
            Center(
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _pickFile,
                icon: const Icon(Icons.folder_open),
                label: Text(_selectedFile == null ? 'Select PDF File' : 'Change File'),
              ),
            ),
            
            const SizedBox(height: 20),

            if (_selectedFile != null) ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.edit_document, color: Colors.blueAccent),
                  title: Text(_selectedFile!.path.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('Total Pages: $_totalPages'),
                ),
              ),
              const SizedBox(height: 20),
              
              const Text('Page number to sign:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextField(
                controller: _pageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
              ),
              
              const SizedBox(height: 30),
              const Text('Draw your signature below:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),

              // SIGNATURE PAD UI
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.blueAccent, width: 2, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    const Center(child: Text('Sign Here', style: TextStyle(color: Colors.black12, fontSize: 30, fontWeight: FontWeight.bold))),
                    GestureDetector(
                      onPanStart: (details) {
                        setState(() {
                          RenderBox box = context.findRenderObject() as RenderBox;
                          Offset point = box.globalToLocal(details.globalPosition);
                          
                          // --- YAHAN ERROR FIX KIYA HAI ---
                          _currentLine = DrawnLine(path: [point], color: Colors.black, width: 3.0);
                        });
                      },
                      onPanUpdate: (details) {
                        setState(() {
                          RenderBox box = context.findRenderObject() as RenderBox;
                          Offset point = box.globalToLocal(details.globalPosition);
                          _currentLine?.path.add(point);
                        });
                      },
                      onPanEnd: (details) {
                        setState(() {
                          if (_currentLine != null) {
                            _lines.add(_currentLine!);
                            _currentLine = null;
                          }
                        });
                      },
                      child: CustomPaint(
                        painter: SignaturePainter(lines: _lines, currentLine: _currentLine),
                        size: Size.infinite,
                      ),
                    ),
                  ],
                ),
              ),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _clearSignature,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Signature'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ),

              const SizedBox(height: 20),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _applySignature,
                  icon: _isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.draw),
                  label: Text(_isProcessing ? 'Applying Signature...' : 'Apply Signature'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

// Custom Painter signature draw karne ke liye
class SignaturePainter extends CustomPainter {
  final List<DrawnLine> lines;
  final DrawnLine? currentLine;

  SignaturePainter({required this.lines, this.currentLine});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()..color = Colors.black..strokeCap = StrokeCap.round..strokeWidth = 3.0;

    for (var line in lines) {
      for (int i = 0; i < line.path.length - 1; i++) {
        // Adjusting Y coordinate to match the container
        canvas.drawLine(Offset(line.path[i].dx, line.path[i].dy - 380), Offset(line.path[i + 1].dx, line.path[i + 1].dy - 380), paint);
      }
    }

    if (currentLine != null) {
      for (int i = 0; i < currentLine!.path.length - 1; i++) {
        canvas.drawLine(Offset(currentLine!.path[i].dx, currentLine!.path[i].dy - 380), Offset(currentLine!.path[i + 1].dx, currentLine!.path[i + 1].dy - 380), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
