import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:receive_sharing_intent/receive_sharing_intent.dart'; 
import 'dart:async'; 
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
import 'password_screen.dart'; 
import 'ocr_screen.dart'; 
import 'signature_screen.dart'; 
import 'image_to_pdf_screen.dart'; 

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

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  PdfTextSearchResult? _searchResult;

  bool _isNightMode = false;

  StreamSubscription? _intentDataStreamSubscription;

  @override
  void initState() {
    super.initState();
    _loadRecentPdfs();

    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _openPdf(value.first.path);
      }
    }, onError: (err) {
      debugPrint("Intent Stream Error: $err");
    });

    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _openPdf(value.first.path);
      }
    });
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }

  // --- NAYA JUGAAAD: AUTO-SCAN APP FOLDER WALA FIX ---
  Future<void> _loadRecentPdfs() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      List<FileSystemEntity> files = dir.listSync();
      List<File> appPdfs = [];
      
      for (var file in files) {
        if (file.path.toLowerCase().endsWith('.pdf')) {
          appPdfs.add(File(file.path));
        }
      }
      appPdfs.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> savedPaths = prefs.getStringList('recent_pdfs') ?? [];
      List<String> finalRecentList = [];
      
      for(var f in appPdfs) finalRecentList.add(f.path);
      for(String path in savedPaths) {
        if(!finalRecentList.contains(path) && File(path).existsSync()) finalRecentList.add(path);
      }
      setState(() { _recentPdfs = finalRecentList; });
    } catch (e) {
      debugPrint("Error loading recent: $e");
    }
  }

  Future<void> _saveToRecent(String path) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> current = prefs.getStringList('recent_pdfs') ?? [];
    if (!current.contains(path)) {
      current.insert(0, path); 
      await prefs.setStringList('recent_pdfs', current);
    }
  }

  Future<void> _openPdf(String path) async {
    if (path.startsWith('file://')) {
      path = path.replaceFirst('file://', '');
    }
    
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int savedPage = prefs.getInt('page_$path') ?? 1;

    await _saveToRecent(path);
    
    setState(() {
      _initialPage = savedPage; 
      _selectedPdf = File(path); 
      _isDrawingMode = false; 
      _isSearching = false;
      _searchController.clear();
      _searchResult?.clear();
    });

    _loadRecentPdfs(); // File khulte hi list refresh hogi

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

  // --- NAYA FIX: JUMP TO PAGE DIALOG ---
  void _showJumpToPageDialog() {
    TextEditingController pageCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Go to Page'),
        content: TextField(
          controller: pageCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: 'Total Pages: ${_pdfViewerController.pageCount}', border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              int? page = int.tryParse(pageCtrl.text);
              if (page != null && page >= 1 && page <= _pdfViewerController.pageCount) {
                _pdfViewerController.jumpToPage(page);
              }
              Navigator.pop(context);
            },
            child: const Text('Go'),
          )
        ],
      ),
    );
  }

  Future<void> _scanDocument() async {
    try {
      final documentScanner = DocumentScanner(
        options: DocumentScannerOptions(mode: ScannerMode.full, pageLimit: 20),
      );
      final result = await documentScanner.scanDocument();
      
      if (result.pdf != null) {
        String tempPdfPath = result.pdf!.uri;
        if (tempPdfPath.startsWith('file://')) {
          tempPdfPath = tempPdfPath.replaceFirst('file://', '');
        }

        if (!mounted) return;
        
        TextEditingController nameController = TextEditingController();
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Save Scanned PDF', style: TextStyle(fontWeight: FontWeight.bold)),
            content: TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Enter File Name',
                hintText: 'e.g. My_Notes',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); 
                  _saveAndOpenScannedPdf(tempPdfPath, 'Scanned_${DateTime.now().millisecondsSinceEpoch}');
                },
                child: const Text('Save Default', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(context);
                  String fileName = nameController.text.trim();
                  if (fileName.isEmpty) {
                    fileName = 'Scanned_${DateTime.now().millisecondsSinceEpoch}';
                  }
                  _saveAndOpenScannedPdf(tempPdfPath, fileName);
                },
                child: const Text('Save File'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scanning Cancelled.')));
      }
    }
  }

  Future<void> _saveAndOpenScannedPdf(String tempPath, String fileName) async {
    try {
      if (!fileName.toLowerCase().endsWith('.pdf')) {
        fileName += '.pdf';
      }
      final dir = await getApplicationDocumentsDirectory();
      final savedPath = '${dir.path}/$fileName';
      
      await File(tempPath).copy(savedPath);
      _openPdf(savedPath); 
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved as $fileName'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error saving file!'), backgroundColor: Colors.red));
      }
    }
  }

  void _showHighlighterSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _isNightMode ? Colors.grey.shade900 : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Color textColor = _isNightMode ? Colors.white : Colors.black87;
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Highlighter Style', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 20),
                  Text('Select Color:', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
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
                            border: Border.all(color: _highlightColor == color ? ( _isNightMode ? Colors.white : Colors.black) : Colors.transparent, width: 3),
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  Text('Transparency (Opacity):', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                  
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
    Color appBarBgColor = _isNightMode ? Colors.black.withOpacity(0.7) : Colors.white.withOpacity(0.4);
    Color iconTextColor = _isNightMode ? Colors.white : Colors.black87;

    return Scaffold(
      extendBodyBehindAppBar: true, 
      backgroundColor: _isNightMode ? const Color(0xFF121212) : Colors.white,
      
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
                _loadRecentPdfs(); // Refresh
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
            // --- NAYA FIX: AWAIT aur AUTO-REFRESH add kiya saare tools mein ---
            ListTile(
              leading: const Icon(Icons.merge_type, color: Colors.purple),
              title: const Text('Merge PDFs'),
              onTap: () async { Navigator.pop(context); await Navigator.push(context, MaterialPageRoute(builder: (context) => const MergeScreen())); _loadRecentPdfs(); },
            ),
            ListTile(
              leading: const Icon(Icons.call_split, color: Colors.orange),
              title: const Text('Split PDF'),
              onTap: () async { Navigator.pop(context); await Navigator.push(context, MaterialPageRoute(builder: (context) => const SplitScreen())); _loadRecentPdfs(); },
            ),
            ListTile(
              leading: const Icon(Icons.compress, color: Colors.green),
              title: const Text('Compress PDF'),
              onTap: () async { Navigator.pop(context); await Navigator.push(context, MaterialPageRoute(builder: (context) => const CompressScreen())); _loadRecentPdfs(); },
            ),
            ListTile(
              leading: const Icon(Icons.layers, color: Colors.teal),
              title: const Text('Organize Pages'),
              onTap: () async { Navigator.pop(context); await Navigator.push(context, MaterialPageRoute(builder: (context) => const OrganizeScreen())); _loadRecentPdfs(); },
            ),
            ListTile(
              leading: const Icon(Icons.security, color: Colors.indigoAccent),
              title: const Text('Protect / Unlock PDF'),
              onTap: () async { Navigator.pop(context); await Navigator.push(context, MaterialPageRoute(builder: (context) => const PasswordScreen())); _loadRecentPdfs(); },
            ),
            ListTile(
              leading: const Icon(Icons.image, color: Colors.pinkAccent),
              title: const Text('Image to PDF'),
              onTap: () async { Navigator.pop(context); await Navigator.push(context, MaterialPageRoute(builder: (context) => const ImageToPdfScreen())); _loadRecentPdfs(); },
            ),
            ListTile(
              leading: const Icon(Icons.text_snippet, color: Colors.deepPurpleAccent),
              title: const Text('Image to Text (OCR)'),
              onTap: () async { Navigator.pop(context); await Navigator.push(context, MaterialPageRoute(builder: (context) => const OcrScreen())); _loadRecentPdfs(); },
            ),
            ListTile(
              leading: const Icon(Icons.draw, color: Colors.blueGrey),
              title: const Text('Add E-Signature'),
              onTap: () async { Navigator.pop(context); await Navigator.push(context, MaterialPageRoute(builder: (context) => const SignatureScreen())); _loadRecentPdfs(); },
            ),
          ],
        ),
      ),

      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: iconTextColor),
                decoration: InputDecoration(
                  hintText: 'Search text...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: _isNightMode ? Colors.grey : Colors.black54),
                ),
                onSubmitted: (String text) async {
                  if (text.isNotEmpty) {
                    _searchResult = await _pdfViewerController.searchText(text);
                    setState(() {});
                  }
                },
              )
            : Text('Indus Reader', style: TextStyle(color: iconTextColor, fontWeight: FontWeight.bold)),
        backgroundColor: appBarBgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: iconTextColor), 
        flexibleSpace: ClipRect(
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), child: Container(color: Colors.transparent)),
        ),
        actions: _isSearching 
          ? [
              IconButton(icon: const Icon(Icons.keyboard_arrow_up), onPressed: () => _searchResult?.previousInstance()),
              IconButton(icon: const Icon(Icons.keyboard_arrow_down), onPressed: () => _searchResult?.nextInstance()),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () => setState(() { _isSearching = false; _searchResult?.clear(); _searchController.clear(); }),
              ),
            ]
          : [
              IconButton(
                icon: Icon(_isNightMode ? Icons.wb_sunny : Icons.nightlight_round, color: _isNightMode ? Colors.yellow : Colors.indigo),
                tooltip: 'Toggle Night Mode',
                onPressed: () {
                  setState(() {
                    _isNightMode = !_isNightMode;
                  });
                },
              ),

              if (_selectedPdf != null && !_isDrawingMode)
                IconButton(icon: const Icon(Icons.search), onPressed: () => setState(() => _isSearching = true)),

              // --- NAYA FIX: JUMP TO PAGE ICON ---
              if (_selectedPdf != null && !_isDrawingMode) 
                IconButton(icon: const Icon(Icons.find_in_page), tooltip: 'Go to Page', onPressed: _showJumpToPageDialog),

              IconButton(icon: const Icon(Icons.folder_open), onPressed: _pickPdf),
              
              if (_selectedPdf != null && !_isDrawingMode)
                IconButton(icon: const Icon(Icons.border_color, color: Colors.orangeAccent), onPressed: _showHighlighterSettings),

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
                              inputPath: _selectedPdf!.path, outputPath: outputPath, text: text.isNotEmpty ? text : "INDUS", color: Colors.red, opacity: opacity, position: position, allPages: allPages, currentPageIndex: _getCurrentPage(),
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
                            await PdfServices.manageLinks(inputPath: _selectedPdf!.path, outputPath: outputPath, pageIndex: _getCurrentPage(), action: action, url: url);
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
                _isNightMode
                  ? ColorFiltered(
                      colorFilter: const ColorFilter.matrix([
                        -1,  0,  0, 0, 255, 
                         0, -1,  0, 0, 255, 
                         0,  0, -1, 0, 255, 
                         0,  0,  0, 1,   0, 
                      ]),
                      child: SfPdfViewer.file(
                        _selectedPdf!, 
                        controller: _pdfViewerController, 
                        enableTextSelection: !_isDrawingMode,
                        pageSpacing: 4, 
                        // --- NAYA FIX: SCROLLBAR AUR PAGE NUMBER TRUE KIYA ---
                        canShowScrollHead: true, 
                        canShowScrollStatus: true,
                        interactionMode: PdfInteractionMode.pan,
                        initialPageNumber: _initialPage,
                        onPageChanged: (PdfPageChangedDetails details) => _saveCurrentPage(details.newPageNumber),
                      ),
                    )
                  : SfPdfViewer.file(
                      _selectedPdf!, 
                      controller: _pdfViewerController, 
                      enableTextSelection: !_isDrawingMode,
                      pageSpacing: 4, 
                      // --- NAYA FIX: SCROLLBAR AUR PAGE NUMBER TRUE KIYA ---
                      canShowScrollHead: true, 
                      canShowScrollStatus: true,
                      interactionMode: PdfInteractionMode.pan,
                      initialPageNumber: _initialPage,
                      onPageChanged: (PdfPageChangedDetails details) => _saveCurrentPage(details.newPageNumber),
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
                           
                           final Size screenSize = MediaQuery.of(context).size;
                           final Offset scrollOffset = _pdfViewerController.scrollOffset;
                           final double zoomLevel = _pdfViewerController.zoomLevel;

                           await PdfServices.saveDrawing(
                             inputPath: _selectedPdf!.path, 
                             outputPath: outputPath, 
                             pageIndex: _getCurrentPage(), 
                             lines: lines,
                             screenSize: screenSize,
                             scrollOffset: scrollOffset,
                             zoomLevel: zoomLevel,
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
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isNightMode 
                      ? [const Color(0xFF1E1E1E), const Color(0xFF000000)] 
                      : [const Color(0xFFE3F2FD), const Color(0xFFBBDEFB)], 
                  begin: Alignment.topCenter, end: Alignment.bottomCenter
                ),
              ),
              child: _recentPdfs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          'Tap the folder icon to open a PDF or open the menu to scan a document.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: _isNightMode ? Colors.white70 : Colors.black54),
                        ),
                      ),
                    )
                  : SafeArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 20, top: 80, bottom: 10),
                            child: Text('Recent Files', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: iconTextColor)),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _recentPdfs.length,
                              itemBuilder: (context, index) {
                                String path = _recentPdfs[index];
                                String fileName = path.split('/').last;
                                return Card(
                                  color: _isNightMode ? Colors.grey.shade800 : Colors.white,
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
                                    title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, color: iconTextColor)),
                                    subtitle: Text('Tap to open', style: TextStyle(color: _isNightMode ? Colors.white54 : Colors.grey[600], fontSize: 13)),
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
