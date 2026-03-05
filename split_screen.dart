import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:io';

import 'pdf_services.dart';

class SplitScreen extends StatefulWidget {
  const SplitScreen({super.key});

  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> {
  File? _selectedFile;
  int _totalPages = 0;
  bool _isSplitting = false;
  
  // Page number type karne ke liye controllers
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      String path = result.files.single.path!;
      
      // PDF khol kar check karna ki usme total kitne page hain
      final List<int> bytes = File(path).readAsBytesSync();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      int pages = document.pages.count;
      document.dispose();

      setState(() {
        _selectedFile = File(path);
        _totalPages = pages;
        _startController.text = "1"; // Default start page 1
        _endController.text = pages.toString(); // Default end page aakhiri wala
      });
    }
  }

  Future<void> _startSplit() async {
    if (_selectedFile == null) return;

    int start = int.tryParse(_startController.text) ?? 1;
    int end = int.tryParse(_endController.text) ?? _totalPages;

    if (start < 1 || end > _totalPages || start > end) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Page Range!'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSplitting = true);

    try {
      final dir = await getApplicationDocumentsDirectory();
      final outputPath = '${dir.path}/split_${DateTime.now().millisecondsSinceEpoch}.pdf';

      await PdfServices.splitPdf(
        inputPath: _selectedFile!.path,
        outputPath: outputPath,
        startPage: start,
        endPage: end,
      );

      setState(() => _isSplitting = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF Split Successfully! Check Recent Files.'), backgroundColor: Colors.green));
        Navigator.pop(context); // Wapas Home par bhej dega
      }
    } catch (e) {
      setState(() => _isSplitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error splitting PDF.'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Split PDF', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select a PDF file and enter the page range you want to extract.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            
            // File select karne ka button
            Center(
              child: ElevatedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.folder_open),
                label: Text(_selectedFile == null ? 'Select PDF File' : 'Change File'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
              ),
            ),
            
            const SizedBox(height: 30),

            if (_selectedFile != null) ...[
              Card(
                elevation: 2,
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.orange, size: 40),
                  title: Text(_selectedFile!.path.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('Total Pages: $_totalPages', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 30),
              
              const Text('Pages to Extract:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _startController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'From Page', border: OutlineInputBorder()),
                    ),
                  ),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16.0), child: Text('TO', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(
                    child: TextField(
                      controller: _endController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'To Page', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              
              const Spacer(),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSplitting ? null : _startSplit,
                  icon: _isSplitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.call_split),
                  label: Text(_isSplitting ? 'Splitting...' : 'Extract Pages'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
