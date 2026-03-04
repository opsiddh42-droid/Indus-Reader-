import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'pdf_services.dart';
import 'watermark_dialog.dart';
import 'link_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _selectedPdf;
  final PdfViewerController _pdfViewerController = PdfViewerController();

  Future<void> _pickPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result != null) setState(() => _selectedPdf = File(result.files.single.path!));
  }

  Future<void> _reloadEditedPdf(String newPath) async {
    setState(() => _selectedPdf = File(newPath));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF Updated Successfully!')));
  }

  int _getCurrentPage() {
    int page = _pdfViewerController.pageNumber - 1;
    return page < 0 ? 0 : page;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Indus Reader'),
        actions: [
          IconButton(icon: const Icon(Icons.folder_open), onPressed: _pickPdf),
          if (_selectedPdf != null)
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
                          text: text.isNotEmpty ? text : "INDUS",
                          color: Colors.red, opacity: opacity,
                          position: position, allPages: allPages,
                          currentPageIndex: _getCurrentPage(),
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
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'watermark', child: Text('Add/Edit Watermark')),
                const PopupMenuItem(value: 'links', child: Text('Manage Links')),
              ],
            ),
        ],
      ),
      body: _selectedPdf != null
          ? SfPdfViewer.file(_selectedPdf!, controller: _pdfViewerController, enableTextSelection: true)
          : const Center(child: Text('Open a PDF to edit')),
    );
  }
}
