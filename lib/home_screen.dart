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
import 'merge_screen.dart'; 
import 'split_screen.dart'; 
import 'compress_screen.dart'; 
import 'organize_screen.dart'; 

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
  int _initialPage = 1; 

  Color _highlightColor = Colors.yellow;
  double _highlightOpacity = 0.5;

  // --- NAYA: SEARCH FEATURE KE VARIABLES ---
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  PdfTextSearchResult? _searchResult;

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

  Future<void> _openPdf(String path) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int savedPage = prefs.getInt('page_$path') ?? 1;

    await _saveToRecent(path);
    
    setState(() {
      _initialPage = savedPage; 
      _selectedPdf = File(path); 
      _isDrawingMode = false; 
      // Nayi file khulne par search band kar do
      _isSearching = false;
      _searchController.clear();
      _searchResult?.clear();
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      try {
        _pdfViewerController.annotationSettings.highlight.color = _highlightColor.withOpacity(_highlightOpacity);
      } catch (e) {
        debugPrint('Highlight setting error: $e');
      }
    });
  }

  Future<void> _saveCurrentPage(int pageNumber) async {
    if (_selectedPdf != null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt('page_${_selectedPdf!.path}', pageNumber);
    }
  }

  Future<void> _pickPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result != null) {
      _openPdf(result.files.single.path!);
    }
  }

  Future<void> _scanDocument() async {
    try {
      final documentScanner = DocumentScanner(
        options: DocumentScannerOptions(mode: ScannerMode.full, pageLimit: 20),
      );
      final result = await documentScanner.scanDocument();
      if (result.pdf != null) {
        String scannedPdfPath = result.pdf!.uri;
        if (scannedPdfPath.startsWith('file://')) {
          scannedPdfPath = scannedPdfPath.replaceFirst('file://', '');
        }
        _openPdf(scannedPdfPath);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document Scanned Successfully!')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scanning Cancelled.')));
    }
  }

  void _showHighlighterSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Highlighter Style', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  const Text('Select Color:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Colors.yellow, Colors.green, Colors.lightBlue, Colors.pink, Colors.purple, Colors.red, Colors.orange
                      ].map((color) => GestureDetector(
                        onTap: () {
                          setSheetState(() => _highlightColor = color);
                          setState(() {
                            _highlightColor = color;
                            try {
                              _pdfViewerController.annotationSettings.highlight.color = _highlightColor.withOpacity(_highlightOpacity);
                            } catch (e) {}
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 15),
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: _highlightColor == color ? Colors.black : Colors.transparent, width: 3),
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  const Text('Transparency (Opacity):', style: TextStyle(fontWeight: FontWeight.bold)),
                  
                  Slider(
                    value: _highlightOpacity,
                    min: 0.1,
                    max: 1.0,
                    activeColor: _highlightColor,
                    onChanged: (val) {
                      setSheetState(() => _highlightOpacity = val);
                      setState(() {
                        _highlightOpacity = val;
                        try {
                           _pdfViewerController.annotationSettings.highlight.color = _highlightColor.withOpacity(_highlightOpacity);
                        } catch (e) {}
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          }
        );
      }
    );
  }

  int _getCurrentPage() {
    int page = _pdfViewerController.pageNumber - 1;
    return page < 0 ? 0 : page;
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
              leading: const Icon(Icons.home, color: Colors.indigo),
              title: const Text('Home / Recent Files', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context); 
                setState(() => _selectedPdf = null);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.folder_open, color: Colors.black87),
              title: const Text('Open File'),
              onTap: () { Navigator.pop(context); _pickPdf(); },
            ),
            ListTile(
              leading: const Icon(Icons.document_scanner, color: Colors.blue),
              title: const Text('Scan Document'),
              onTap: () { Navigator.pop(context); _scanDocument(); },
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
              child: Text('PDF TOOLS', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.merge_type, color: Colors.purple),
              title: const Text('Merge PDFs'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const MergeScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.call_split, color: Colors.orange),
              title: const Text('Split PDF'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SplitScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.compress, color: Colors.green),
              title: const Text('Compress PDF'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const CompressScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.layers, color: Colors.teal),
              title: const Text('Organize Pages'),
              subtitle: const Text('Add, Delete, Reorder', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const OrganizeScreen()));
              },
            ),
          ],
        ),
      ),

      // --- UPDATED APP BAR WITH SEARCH FEATURE ---
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(
                  hintText: 'Search text...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.black54),
                ),
                onSubmitted: (String text) async {
                  if (text.isNotEmpty) {
                    _searchResult = await _pdfViewerController.searchText(text);
                    setState(() {});
                  }
                },
              )
            : const Text('Indus Reader', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white.withOpacity(0.4),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87), 
        flexibleSpace: ClipRect(
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), child: Container(color: Colors.transparent)),
        ),
        actions: _isSearching 
          ? [
              // Search Navigation Icons
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up),
                tooltip: 'Previous result',
                onPressed: () {
                  _searchResult?.previousInstance();
                },
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down),
                tooltip: 'Next result',
                onPressed: () {
                  _searchResult?.nextInstance();
                },
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                tooltip: 'Cancel Search',
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchResult?.clear();
                    _searchController.clear();
                  });
                },
              ),
            ]
          : [
              // Normal Icons
              if (_selectedPdf != null && !_isDrawingMode)
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Search Text',
                  onPressed: () {
                    setState(() {
                      _isSearching = true;
                    });
                  },
                ),

              IconButton(icon: const Icon(Icons.folder_open), onPressed: _pickPdf),
              
              if (_selectedPdf != null && !_isDrawingMode)
                IconButton(
                  icon: const Icon(Icons.border_color, color: Colors.orangeAccent),
                  tooltip: 'Highlighter Settings',
                  onPressed: _showHighlighterSettings, 
                ),

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
                            _openPdf(outputPath);
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
                            _openPdf(outputPath);
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
                    const PopupMenuItem(value: 'draw', child: Text('Draw / Freehand')),
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
                  initialPageNumber: _initialPage,
                  onPageChanged: (PdfPageChangedDetails details) {
                    _saveCurrentPage(details.newPageNumber);
                  },
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
                           _openPdf(outputPath);
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
                                    onTap: () => _openPdf(path),
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
