import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:ui'; // Premium Glass blur effect ke liye

import 'pdf_services.dart';
import 'watermark_dialog.dart';
import 'link_dialog.dart';
import 'drawing_canvas.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _selectedPdf;
  final PdfViewerController _pdfViewerController = PdfViewerController();
  
  // Draw Mode track karne ke liye
  bool _isDrawingMode = false;

  Future<void> _pickPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result != null) setState(() => _selectedPdf = File(result.files.single.path!));
  }

  Future<void> _reloadEditedPdf(String newPath) async {
    setState(() => _selectedPdf = File(newPath));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF Updated Successfully!')));
  }

  int _getCurrentPage() {
    int page = _pdfViewerController.pageNumber - 1;
    return page < 0 ? 0 : page;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // App bar ke peeche PDF scroll hone ke liye
      appBar: AppBar(
        title: const Text('Indus Reader', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white.withOpacity(0.4),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        
        // Glass Blur Effect
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(color: Colors.transparent),
          ),
        ),

        actions: [
          IconButton(icon: const Icon(Icons.folder_open), onPressed: _pickPdf),
          // Agar Draw Mode on hai toh Edit menu hide kar do
          if (_selectedPdf != null && !_isDrawingMode)
            PopupMenuButton<String>(
              icon: const Icon(Icons.edit),
              onSelected: (value) {
                if (value == 'watermark') {
                  showDialog(
                    context: context,
                    builder: (context) => WatermarkDialog(
                      onApply: (text, position, opacity, allPages) async {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Applying Watermark...')));
                        final dir = await getApplicationDocumentsDirectory();
                        final outputPath = '${dir.path}/wm_${DateTime.now().millisecondsSinceEpoch}.pdf';
                        
                        await PdfServices.addAdvancedWatermark(
                          inputPath: _selectedPdf!.path, outputPath: outputPath,
                          text: text.isNotEmpty ? text : "INDUS",
                          color: Colors.red, opacity: opacity,
                          position: position, allPages: allPages,
                          currentPageIndex: _getCurrentPage(),
                        );
                        _reloadEditedPdf(outputPath);
                      },
                    ),
                  );
                } else if (value == 'links') {
                  showDialog(
                    context: context,
                    builder: (context) => LinkDialog(
                      onApply: (action, url) async {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updating Links...')));
                        final dir = await getApplicationDocumentsDirectory();
                        final outputPath = '${dir.path}/link_${DateTime.now().millisecondsSinceEpoch}.pdf';
                        
                        await PdfServices.manageLinks(
                          inputPath: _selectedPdf!.path, outputPath: outputPath,
                          pageIndex: _getCurrentPage(), action: action, url: url,
                        );
                        _reloadEditedPdf(outputPath);
                      },
                    ),
                  );
                } else if (value == 'draw') {
                  // Draw Mode ON karna
                  setState(() => _isDrawingMode = true);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'watermark', child: Text('Add/Edit Watermark')),
                const PopupMenuItem(value: 'links', child: Text('Manage Links')),
                const PopupMenuItem(value: 'draw', child: Text('Draw / Highlight')),
              ],
            ),
        ],
      ),
      body: _selectedPdf != null
          ? Stack(
              children: [
                // Neeche aapki asli PDF 
                SfPdfViewer.file(
                  _selectedPdf!, 
                  controller: _pdfViewerController, 
                  enableTextSelection: !_isDrawingMode, // Draw mode mein text copy band
                  pageSpacing: 4, 
                  canShowScrollHead: false, 
                  interactionMode: PdfInteractionMode.pan,
                ),
                
                // Upar Invisible Canvas (Jab Draw Mode ON ho)
                if (_isDrawingMode)
                  Positioned.fill(
                    child: Container(
                      color: Colors.white.withOpacity(0.1), 
                      child: DrawingCanvas(
                        onClose: () => setState(() => _isDrawingMode = false),
                        // JAB AAP SAVE DABAYENGE TOH YE CODE CHALEGA
                        onSave: (lines) async {
                           setState(() => _isDrawingMode = false);
                           
                           if (lines.isEmpty) return; // Agar kuch draw nahi kiya toh wapas aao
                           
                           ScaffoldMessenger.of(context).showSnackBar(
                             const SnackBar(content: Text('Saving Drawing to PDF...'))
                           );
                           
                           final dir = await getApplicationDocumentsDirectory();
                           final outputPath = '${dir.path}/drawn_${DateTime.now().millisecondsSinceEpoch}.pdf';
                           
                           // Asli PDF ke andar save karna
                           await PdfServices.saveDrawing(
                             inputPath: _selectedPdf!.path,
                             outputPath: outputPath,
                             pageIndex: _getCurrentPage(),
                             lines: lines,
                           );
                           
                           // Nayi update hui PDF ko screen par dikhana
                           _reloadEditedPdf(outputPath);
                        },
                      ),
                    ),
                  ),
              ],
            )
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                ),
              ),
              child: const Center(
                child: Text('Upar folder icon se PDF select karein', style: TextStyle(fontSize: 16, color: Colors.black54)),
              ),
            ),
    );
  }
}
