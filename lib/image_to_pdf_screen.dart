import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:io';

class ImageToPdfScreen extends StatefulWidget {
  const ImageToPdfScreen({super.key});

  @override
  State<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends State<ImageToPdfScreen> {
  List<String> _imagePaths = [];
  bool _isProcessing = false;

  // Gallery se multiple images select karna
  Future<void> _pickImages() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image, // Sirf images dikhayega
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        _imagePaths.addAll(result.paths.where((path) => path != null).cast<String>());
      });
    }
  }

  void _removeImage(int index) {
    setState(() => _imagePaths.removeAt(index));
  }

  // Images ko PDF mein convert karna
  Future<void> _convertToPdf() async {
    if (_imagePaths.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final PdfDocument document = PdfDocument();

      for (String path in _imagePaths) {
        final File imageFile = File(path);
        // Image ko PDF format ke liye load karna
        final PdfBitmap image = PdfBitmap(imageFile.readAsBytesSync());
        
        // Naya page add karna
        final PdfPage page = document.pages.add();
        final Size pageSize = page.getClientSize();
        
        // Image ko page par draw karna (Fit to page)
        page.graphics.drawImage(image, Rect.fromLTWH(0, 0, pageSize.width, pageSize.height));
      }

      final dir = await getApplicationDocumentsDirectory();
      final outputPath = '${dir.path}/ImgToPdf_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
      File(outputPath).writeAsBytesSync(await document.save());
      document.dispose();

      setState(() => _isProcessing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF Created Successfully! Check Recent Files.'), backgroundColor: Colors.green));
        Navigator.pop(context); // Wapas Home par bhej dega
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error creating PDF.'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image to PDF', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Select images from your gallery to convert them into a single PDF document.', style: TextStyle(color: Colors.grey)),
          ),
          
          Expanded(
            child: _imagePaths.isEmpty
                ? const Center(child: Text('No images selected yet.', style: TextStyle(fontSize: 16, color: Colors.grey)))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: _imagePaths.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(File(_imagePaths[index]), fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 0, right: 0,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                          // Image ka number dikhane ke liye
                          Positioned(
                            bottom: 5, left: 5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                              child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          )
                        ],
                      );
                    },
                  ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, -5))]),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing ? null : _pickImages,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('Add Images'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _imagePaths.isEmpty || _isProcessing ? null : _convertToPdf,
                      icon: _isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.picture_as_pdf),
                      label: Text(_isProcessing ? 'Converting...' : 'Create PDF'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
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
