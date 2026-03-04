import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

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

  // Phone ki memory se Recent PDFs load karna
  Future<void> _loadRecentPdfs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentPdfs = prefs.getStringList('recent_pdfs') ?? [];
    });
  }

  // Nayi PDF file select karna aur recent list mein save karna
  Future<void> _pickPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      String path = result.files.single.path!;
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // Agar list mein pehle se nahi hai toh add karein
      if (!_recentPdfs.contains(path)) {
        _recentPdfs.insert(0, path); // Sabse upar add karein
        await prefs.setStringList('recent_pdfs', _recentPdfs);
      }

      setState(() {
        _selectedPdf = File(path);
      });
    }
  }

  // Logo par Long Press karne par Delete/Move options dikhana
  void _showLogoOptions(BuildContext context, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      items: [
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.red), 
              SizedBox(width: 8), 
              Text('Remove Logo/Image')
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'delete') {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Logo/Image par white box apply kiya ja raha hai...'))
         );
         // Yahan humara pdf_services wala logic call hoga future mein
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Indus Reader'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open), 
            onPressed: _pickPdf,
            tooltip: 'Open PDF',
          ),
        ],
      ),
      // Side Drawer (Menu) jisme Recent PDFs dikhengi
      drawer: Drawer(
        child: Column(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blueAccent),
              child: Center(
                child: Text('Indus Reader\nRecent Files', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              ),
            ),
            Expanded(
              child: _recentPdfs.isEmpty 
                ? const Center(child: Text('Koi recent file nahi hai'))
                : ListView.builder(
                    itemCount: _recentPdfs.length,
                    itemBuilder: (context, index) {
                      String path = _recentPdfs[index];
                      String fileName = path.split('/').last; // Sirf file ka naam nikalna
                      return ListTile(
                        leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                        title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () {
                          setState(() { _selectedPdf = File(path); });
                          Navigator.pop(context); // Menu band karna
                        },
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
      // Main screen jahan PDF dikhegi
      body: _selectedPdf != null
          ? GestureDetector(
              onLongPressStart: (details) => _showLogoOptions(context, details.globalPosition),
              child: SfPdfViewer.file(
                _selectedPdf!, 
                controller: _pdfViewerController,
                canShowHyperlinkDialog: true,
              ),
            )
          : const Center(
              child: Text(
                'Upar Folder icon par click karke PDF select karein',
                style: TextStyle(fontSize: 16),
              ),
            ),
    );
  }
}
