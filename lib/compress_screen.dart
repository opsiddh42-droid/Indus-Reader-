import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'pdf_services.dart';

class CompressScreen extends StatefulWidget {
  const CompressScreen({super.key});

  @override
  State<CompressScreen> createState() => _CompressScreenState();
}

class _CompressScreenState extends State<CompressScreen> {
  File? _selectedFile;
  String _originalSize = "";
  bool _isCompressing = false;

  // File ka size MB ya KB mein nikalne ka formula
  String _getFileSizeString(int bytes) {
    if (bytes <= 0) return "0 B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(2)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      String path = result.files.single.path!;
      int sizeInBytes = File(path).lengthSync();
      
      setState(() {
        _selectedFile = File(path);
        _originalSize = _getFileSizeString(sizeInBytes);
      });
    }
  }

  Future<void> _startCompress() async {
    if (_selectedFile == null) return;

    setState(() => _isCompressing = true);

    try {
      final dir = await getApplicationDocumentsDirectory();
      final outputPath = '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.pdf';

      // Backend ko call lagana
      await PdfServices.compressPdf(
        inputPath: _selectedFile!.path,
        outputPath: outputPath,
      );

      // Nayi file ka size check karna
      int newSizeInBytes = File(outputPath).lengthSync();
      String newSize = _getFileSizeString(newSizeInBytes);

      setState(() => _isCompressing = false);

      if (mounted) {
        // Success dialog dikhana jisme dono size likhe honge
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Compression Complete! 🎉', style: TextStyle(color: Colors.green)),
            content: Text('Original Size: $_originalSize\nNew Size: $newSize'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Dialog band karna
                  Navigator.pop(context); // Wapas Home par bhej dena
                },
                child: const Text('Great!'),
              )
            ],
          )
        );
      }
    } catch (e) {
      setState(() => _isCompressing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error compressing PDF.'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compress PDF', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reduce your PDF file size while maintaining the best possible quality.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            
            Center(
              child: ElevatedButton.icon(
                onPressed: _isCompressing ? null : _pickFile,
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
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.green, size: 40),
                  title: Text(_selectedFile!.path.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('Current Size: $_originalSize', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              
              const Spacer(),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isCompressing ? null : _startCompress,
                  icon: _isCompressing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.compress),
                  label: Text(_isCompressing ? 'Compressing...' : 'Compress Now'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
