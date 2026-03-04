import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'pdf_services.dart'; // Humara backend logic

void main() {
  runApp(const IndusReaderApp());
}

class IndusReaderApp extends StatelessWidget {
  const IndusReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Indus Reader',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
        ),
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? _selectedPdf;
  final PdfViewerController _pdfViewerController = PdfViewerController();
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

  Future<void> _pickPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      String path = result.files.single.path!;
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      if (!_recentPdfs.contains(path)) {
        _recentPdfs.insert(0, path);
        await prefs.setStringList('recent_pdfs', _recentPdfs);
      }

      setState(() {
        _selectedPdf = File(path);
      });
    }
  }

  // Edit hone ke baad nayi PDF ko screen par reload karna
  Future<void> _reloadEditedPdf(String newPath) async {
    setState(() {
      _selectedPdf = File(newPath);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF Successfully Edited!'), backgroundColor: Colors.green),
    );
  }

  // --- EDITING FUNCTIONS ---

  Future<void> _applyWatermark() async {
    if (_selectedPdf == null) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Processing...')));
    
    final dir = await getApplicationDocumentsDirectory();
    final outputPath = '${dir.path}/watermark_${DateTime.now().millisecondsSinceEpoch}.pdf';
    
    await PdfServices.addWatermark(_selectedPdf!.path, outputPath, "INDUS READER");
    _reloadEditedPdf(outputPath);
  }

  Future<void> _addNewPage() async {
    if (_selectedPdf == null) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adding Page...')));
    
    final dir = await getApplicationDocumentsDirectory();
    final outputPath = '${dir.path}/newpage_${DateTime.now().millisecondsSinceEpoch}.pdf';
    
    await PdfServices.managePages(_selectedPdf!.path, outputPath);
    _reloadEditedPdf(outputPath);
  }

  void _showLogoOptions(BuildContext context, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      items: [
        const PopupMenuItem(
          value: 'delete',
          child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Remove Logo here')]),
        ),
      ],
    ).then((value) async {
      if (value == 'delete' && _selectedPdf != null) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removing Logo...')));
         
         final dir = await getApplicationDocumentsDirectory();
         final outputPath = '${dir.path}/nologo_${DateTime.now().millisecondsSinceEpoch}.pdf';
         
         // Current page number nikalna (0 se shuru hota hai logic mein)
         int currentPage = _pdfViewerController.pageNumber - 1;
         if(currentPage < 0) currentPage = 0;

         // Ek andaze se 100x100 ka white box us click kiye hue area par banayega
         Rect logoArea = Rect.fromLTWH(position.dx - 50, position.dy - 50, 100, 100);
         
         await PdfServices.hideLogo(_selectedPdf!.path, outputPath, currentPage, logoArea);
         _reloadEditedPdf(outputPath);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Indus Reader'),
        actions: [
          IconButton(icon: const Icon(Icons.folder_open), onPressed: _pickPdf),
          // Edit Tools Menu
          if (_selectedPdf != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.edit),
              onSelected: (value) {
                if (value == 'watermark') _applyWatermark();
                if (value == 'add_page') _addNewPage();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'watermark', child: Text('Add Watermark')),
                const PopupMenuItem(value: 'add_page', child: Text('Insert Blank Page')),
              ],
            ),
        ],
      ),
      body: _selectedPdf != null
          ? GestureDetector(
              onLongPressStart: (details) => _showLogoOptions(context, details.globalPosition),
              child: SfPdfViewer.file(
                _selectedPdf!, 
                controller: _pdfViewerController,
                enableTextSelection: true, // YEH TEXT SELECT AUR HIGHLIGHT ENABLE KAREGA
                canShowHyperlinkDialog: true,
              ),
            )
          : const Center(child: Text('Upar Folder icon par click karke PDF select karein')),
    );
  }
}
