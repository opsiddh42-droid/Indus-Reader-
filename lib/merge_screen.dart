import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'pdf_services.dart';

class MergeScreen extends StatefulWidget {
  const MergeScreen({super.key});

  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> {
  List<String> _selectedFiles = [];
  bool _isMerging = false;

  // Multiple files select karne ka function
  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );

    if (result != null) {
      List<String> validPaths = result.paths.where((path) => path != null).cast<String>().toList();
      setState(() {
        _selectedFiles.addAll(validPaths);
      });
    }
  }

  // Files ko list se hatane ka function
  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  // Merge process start karna
  Future<void> _startMerge() async {
    if (_selectedFiles.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least 2 PDFs to merge.'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isMerging = true);

    try {
      final dir = await getApplicationDocumentsDirectory();
      final outputPath = '${dir.path}/merged_${DateTime.now().millisecondsSinceEpoch}.pdf';

      await PdfServices.mergePdfs(inputPaths: _selectedFiles, outputPath: outputPath);

      setState(() => _isMerging = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDFs Merged Successfully! Check Recent Files on Home.'), backgroundColor: Colors.green));
        Navigator.pop(context); 
      }
    } catch (e) {
      setState(() => _isMerging = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error merging PDFs.'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Merge PDFs', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Select 2 or more PDF files to combine them into a single file. You can add more files or remove them from the list.', style: TextStyle(color: Colors.grey)),
          ),
          
          Expanded(
            child: _selectedFiles.isEmpty
                ? const Center(child: Text('No files selected yet.', style: TextStyle(fontSize: 16, color: Colors.grey)))
                : ListView.builder(
                    itemCount: _selectedFiles.length,
                    itemBuilder: (context, index) {
                      String fileName = _selectedFiles[index].split('/').last;
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: ListTile(
                          leading: const CircleAvatar(backgroundColor: Colors.purple, child: Icon(Icons.picture_as_pdf, color: Colors.white)),
                          title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                            // YAHAN FIX KIYA HAI: onTap ki jagah onPressed aayega
                            onPressed: () => _removeFile(index), 
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Neeche ke Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isMerging ? null : _pickFiles,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Files'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isMerging ? null : _startMerge,
                      icon: _isMerging ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.merge_type),
                      label: Text(_isMerging ? 'Merging...' : 'Merge Now'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
