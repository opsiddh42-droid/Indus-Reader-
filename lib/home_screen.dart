import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart'; // NAYA: Scanner ke liye
import 'dart:io';
import 'dart:ui'; 

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

  // --- NAYA: DOCUMENT SCANNER FUNCTION ---
  Future<void> _scanDocument() async {
    try {
      // Scanner ki settings (Direct PDF banayega)
      final documentScanner = DocumentScanner(
        options: DocumentScannerOptions(
          documentFormat: DocumentFormat.pdf,
          mode: ScannerMode.full,
          pageLimit: 20, // Ek baar mein 20 page scan kar sakte hain
          isGalleryImportAllowed: true, // Gallery se photo bhi utha sakte hain
        ),
      );

      // Scanner open karna
      final result = await documentScanner.scanDocument();
      
      // Agar user ne scan karke PDF bana di hai
      if (result.pdf != null) {
        String scannedPdfPath = result.pdf!.uri;
        // Prefix 'file://' hatana (agar URI format mein hai toh)
        if (scannedPdfPath.startsWith('file://')) {
          scannedPdfPath = scannedPdfPath.replaceFirst('file://', '');
        }
        
        setState(() {
          _selectedPdf = File(scannedPdfPath);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document Scanned Successfully!')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scanning Cancelled or Failed.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, 
      
      // --- NAYA: SLIDE BAR (DRAWER) YAHAN HAI ---
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blueAccent),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.picture_as_pdf, size: 50, color: Colors.white),
                  SizedBox(height: 10),
                  Text('Indus Reader', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.document_scanner, color: Colors.blue),
              title: const Text('Scan Document', style: TextStyle(fontSize: 16)),
              subtitle: const Text('Camera se naya PDF banayein'),
              onTap: () {
                Navigator.pop(context); // Menu band karna
                _scanDocument(); // Scanner chalana
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Open File'),
              onTap: () {
                Navigator.pop(context);
                _pickPdf();
              },
            ),
          ],
        ),
      ),

      appBar: AppBar(
        title: const Text('Indus Reader', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white.withOpacity(0.4),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87), // Drawer icon (hamburger menu) automatic yahan aa jayega
        
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(color: Colors.transparent),
          ),
        ),

        actions: [
          IconButton(icon: const Icon(Icons.folder_open), onPressed: _pickPdf),
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
                          text: text.isNotEmpty ? text : "INDUS", color: Colors.red, opacity: opacity,
                          position: position, allPages: allPages, currentPageIndex: _getCurrentPage(),
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
                SfPdfViewer.file(
                  _selectedPdf!, 
                  controller: _pdfViewerController, 
                  enableTextSelection: !_isDrawingMode,
                  pageSpacing: 4, 
                  canShowScrollHead: false, 
                  interactionMode: PdfInteractionMode.pan,
                ),
                
                if (_isDrawingMode)
                  Positioned.fill(
                    child: Container(
                      color: Colors.white.withOpacity(0.1), 
                      child: DrawingCanvas(
                        onClose: () => setState(() => _isDrawingMode = false),
                        onSave: (lines) async {
                           setState(() => _isDrawingMode = false);
                           if (lines.isEmpty) return;
                           
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saving Drawing to PDF...')));
                           final dir = await getApplicationDocumentsDirectory();
                           final outputPath = '${dir.path}/drawn_${DateTime.now().millisecondsSinceEpoch}.pdf';
                           
                           await PdfServices.saveDrawing(
                             inputPath: _selectedPdf!.path, outputPath: outputPath,
                             pageIndex: _getCurrentPage(), lines: lines,
                           );
                           _reloadEditedPdf(outputPath);
                        },
                      ),
                    ),
                  ),
              ],
            )
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              ),
              child: const Center(
                child: Text('Upar folder icon se PDF select karein ya Menu se Scan karein', style: TextStyle(fontSize: 16, color: Colors.black54)),
              ),
            ),
    );
  }
}
