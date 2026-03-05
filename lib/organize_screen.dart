import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:io';

import 'pdf_services.dart';

class OrganizeScreen extends StatefulWidget {
  const OrganizeScreen({super.key});

  @override
  State<OrganizeScreen> createState() => _OrganizeScreenState();
}

class _OrganizeScreenState extends State<OrganizeScreen> {
  File? _selectedFile;
  int _totalPages = 0;
  bool _isProcessing = false;
  
  // Jo pages delete karne hain unki list (0-based index)
  List<int> _selectedPagesToDelete = [];

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
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
        _selectedPagesToDelete.clear(); // Nayi file par purani selection clear kar do
      });
    }
  }

  void _togglePageSelection(int index) {
    setState(() {
      if (_selectedPagesToDelete.contains(index)) {
        _selectedPagesToDelete.remove(index);
      } else {
        _selectedPagesToDelete.add(index);
      }
    });
  }

  Future<void> _applyChanges() async {
    if (_selectedFile == null || _selectedPagesToDelete.isEmpty) return;

    // Agar user saare hi pages delete kar raha hai toh rokna padega
    if (_selectedPagesToDelete.length == _totalPages) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You cannot delete all pages!'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final dir = await getApplicationDocumentsDirectory();
      final outputPath = '${dir.path}/organized_${DateTime.now().millisecondsSinceEpoch}.pdf';

      await PdfServices.removePages(
        inputPath: _selectedFile!.path,
        outputPath: outputPath,
        pagesToDelete: _selectedPagesToDelete,
      );

      setState(() => _isProcessing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pages Deleted Successfully! Check Recent Files.'), backgroundColor: Colors.green));
        Navigator.pop(context); // Wapas Home par bhej dega
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error organizing PDF.'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organize Pages', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Tap on the pages you want to DELETE. They will turn red.', style: TextStyle(color: Colors.grey)),
          ),
          
          Center(
            child: ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open),
              label: Text(_selectedFile == null ? 'Select PDF File' : 'Change File'),
            ),
          ),
          
          const SizedBox(height: 10),

          // Pages ka GridView
          Expanded(
            child: _selectedFile == null
                ? const Center(child: Text('Please select a PDF to view pages.', style: TextStyle(color: Colors.grey)))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, // Ek line mein 3 pages
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.75, // Page jaisa lamba shape
                    ),
                    itemCount: _totalPages,
                    itemBuilder: (context, index) {
                      bool isSelected = _selectedPagesToDelete.contains(index);
                      
                      return GestureDetector(
                        onTap: () => _togglePageSelection(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.red.withOpacity(0.8) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isSelected ? Colors.red : Colors.grey.shade300, width: 2),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(2, 2))
                            ]
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.insert_drive_file, color: isSelected ? Colors.white : Colors.grey, size: 40),
                                  const SizedBox(height: 8),
                                  Text('Page ${index + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87)),
                                ],
                              ),
                              if (isSelected)
                                const Positioned(
                                  top: 5, right: 5,
                                  child: Icon(Icons.delete, color: Colors.white, size: 20),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Delete Button (Neeche)
          if (_selectedFile != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, -5))]),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _selectedPagesToDelete.isEmpty || _isProcessing ? null : _applyChanges,
                    icon: _isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.delete_sweep),
                    label: Text(_isProcessing ? 'Processing...' : 'Delete Selected (${_selectedPagesToDelete.length})'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            )
        ],
      ),
    );
  }
}
