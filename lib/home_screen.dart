import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 
import 'dart:io';
import 'dart:ui'; 

import 'pdf_services.dart';
import 'watermark_dialog.dart';
import 'link_dialog.dart';
import 'drawing_canvas.dart';
import 'merge_screen.dart'; // NAYA IMPORT: Merge Screen ko jodne ke liye

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _selectedPdf;
  final PdfViewerController _pdfViewerController = PdfViewerController();
  bool _isDrawingMode = false;
  
  List<String> _recentPdfs = [];

  @override
  void initState() {
    super.initState();
    _loadRecentPdfs();
  }

  Future<void> _loadRecentPdfs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentPdfs = prefs.getStringList('recent_pdfs') ?? [];
    });
  }

  Future<void> _saveToRecent(String path) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!_recentPdfs.contains(path)) {
      _recentPdfs.insert(0, path); 
      await prefs.setStringList('recent_pdfs', _recentPdfs);
      setState(() {}); 
    }
  }

  Future<void> _pickPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result != null) {
      String path = result.files.single.path!;
      await _saveToRecent(path);
      setState(() => _selectedPdf = File(path));
    }
  }

  Future<void> _reloadEditedPdf(String newPath) async {
    await _saveToRecent(newPath); 
    setState(() => _selectedPdf = File(newPath));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF Updated Successfully!')));
  }

  int _getCurrentPage() {
    int page = _pdfViewerController.pageNumber - 1;
    return page < 0 ? 0 : page;
  }

  Future<void> _scanDocument() async {
    try {
      final documentScanner = DocumentScanner(
        options: DocumentScannerOptions(
          mode: ScannerMode.full,
          pageLimit: 20, 
        ),
      );

      final result = await documentScanner.scanDocument();
      
      if (result.pdf != null) {
        String scannedPdfPath = result.pdf!.uri;
        if (scannedPdfPath.startsWith('file://')) {
          scannedPdfPath = scannedPdfPath.replaceFirst('file://', '');
        }
        
        await _saveToRecent(scannedPdfPath);
        setState(() {
          _selectedPdf = File(scannedPdfPath);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document Scanned Successfully!')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scanning Cancelled.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, 
      
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
                  Text('Indus Reader Pro', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open, color: Colors.black87),
              title: const Text('Open File'),
              onTap: () {
                Navigator.pop(context);
                _pickPdf();
              },
            ),
            ListTile(
              leading: const Icon(Icons.document_scanner, color: Colors.blue),
              title: const Text('Scan Document'),
              onTap: () {
                Navigator.pop(context); 
                _scanDocument(); 
              },
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
              child: Text('PDF TOOLS', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            
            // --- YAHAN MERGE BUTTON KO NAYE PAGE SE JODA HAI ---
            ListTile(
              leading: const Icon(Icons.merge_type, color: Colors.purple),
              title: const Text('Merge PDFs'),
              onTap: () {
                Navigator.pop(context); // Menu band karna
                // Nayi Merge screen par le jana
                Navigator.push(context, MaterialPageRoute(builder: (context) => const MergeScreen()));
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.call_split, color: Colors.orange),
              title: const Text('Split PDF'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Split feature screen coming next!')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.compress, color: Colors.green),
              title: const Text('Compress PDF'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compress feature screen coming next!')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.layers, color: Colors.teal),
              title: const Text('Organize Pages'),
              subtitle: const Text('Add, Delete, Reorder', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Page Organizer screen coming next!')));
              },
            ),
          ],
        ),
      ),

      appBar: AppBar(
        title: const Text('Indus Reader', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white.withOpacity(0.4),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87), 
        
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
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              ),
              child: _recentPdfs.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text(
                          'Tap the folder icon to open a PDF or open the menu to scan a document.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                      ),
                    )
                  : SafeArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 20, top: 80, bottom: 10),
                            child: Text('Recent Files', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _recentPdfs.length,
                              itemBuilder: (context, index) {
                                String path = _recentPdfs[index];
                                String fileName = path.split('/').last;
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                      child: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                                    ),
                                    title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    subtitle: Text('Tap to open', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                    onTap: () => setState(() => _selectedPdf = File(path)),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
    );
  }
}
