import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class BulkModifyScreen extends StatefulWidget {
  const BulkModifyScreen({super.key});

  @override
  State<BulkModifyScreen> createState() => _BulkModifyScreenState();
}

class _BulkModifyScreenState extends State<BulkModifyScreen> {
  List<File> _selectedPdfs = [];
  bool _isProcessing = false;
  int _currentProcessingIndex = 0;

  // Watermark Settings
  bool _applyWatermark = false;
  final TextEditingController _watermarkCtrl = TextEditingController(text: 'INDUS READER');
  int _watermarkFreq = 1; // 1 means All, 5 means every 5 pages

  // Promo PDF Settings
  bool _applyPromo = false;
  File? _promoPdf;
  int _promoFreq = 5;

  // Link Settings
  bool _applyLink = false;
  final TextEditingController _linkCtrl = TextEditingController(text: 'https://');

  Future<void> _pickPdfs() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result != null) {
      setState(() {
        // Maximum 50 PDFs allow karenge
        _selectedPdfs = result.paths.take(50).map((path) => File(path!)).toList();
      });
    }
  }

  Future<void> _pickPromoPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null) {
      setState(() {
        _promoPdf = File(result.files.single.path!);
      });
    }
  }

  Future<void> _processBulkPdfs() async {
    if (_selectedPdfs.isEmpty) return;
    setState(() => _isProcessing = true);

    final dir = await getApplicationDocumentsDirectory();

    PdfDocument? promoDoc;
    PdfPageTemplateElement? promoTemplate;
    if (_applyPromo && _promoPdf != null) {
      promoDoc = PdfDocument(inputBytes: _promoPdf!.readAsBytesSync());
      if (promoDoc.pages.count > 0) {
        promoTemplate = promoDoc.pages[0].createTemplate();
      }
    }

    try {
      for (int i = 0; i < _selectedPdfs.length; i++) {
        setState(() => _currentProcessingIndex = i + 1);
        File pdfFile = _selectedPdfs[i];
        
        final List<int> bytes = pdfFile.readAsBytesSync();
        final PdfDocument document = PdfDocument(inputBytes: bytes);
        final PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, 40, style: PdfFontStyle.bold);
        final PdfColor color = PdfColor(255, 0, 0); // Red watermark

        // 1. Promo Pages Insert karna (Ulta loop chalana padega taaki index kharab na ho)
        if (promoTemplate != null) {
          for (int p = document.pages.count - 1; p >= 0; p--) {
            if ((p + 1) % _promoFreq == 0) {
              final PdfPage newPage = document.pages.insert(p + 1);
              newPage.graphics.drawPdfTemplate(promoTemplate, const Offset(0, 0));
            }
          }
        }

        // 2. Watermark aur Link apply karna
        for (int p = 0; p < document.pages.count; p++) {
          final PdfPage page = document.pages[p];

          // Watermark
          if (_applyWatermark && ((p + 1) % _watermarkFreq == 0 || _watermarkFreq == 1)) {
            page.graphics.save();
            page.graphics.setTransparency(0.3); // 30% Opacity
            page.graphics.drawString(
              _watermarkCtrl.text, font,
              brush: PdfSolidBrush(color),
              bounds: Rect.fromLTWH(50, page.size.height / 2, page.size.width, 100),
            );
            page.graphics.restore();
          }

          // Link
          if (_applyLink && _linkCtrl.text.isNotEmpty) {
            page.annotations.add(PdfUriAnnotation(
              bounds: Rect.fromLTWH(0, 0, page.size.width, page.size.height), // Poore page par link
              uri: _linkCtrl.text,
            ));
          }
        }

        // Save file with "_modified"
        String originalName = pdfFile.path.split('/').last.replaceAll('.pdf', '');
        String outputPath = '${dir.path}/${originalName}_modified.pdf';
        
        File(outputPath).writeAsBytesSync(await document.save());
        document.dispose();
      }

      promoDoc?.dispose();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All PDFs Modified Successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Wapas home par bhejna
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Modify (Premium)', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.amber.shade700,
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text('Processing $_currentProcessingIndex of ${_selectedPdfs.length} PDFs...'),
                  const Text('Please do not close the app.', style: TextStyle(color: Colors.red)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // File Selection
                ElevatedButton.icon(
                  onPressed: _pickPdfs,
                  icon: const Icon(Icons.library_books),
                  label: Text(_selectedPdfs.isEmpty ? 'Select PDFs (Max 50)' : '${_selectedPdfs.length} PDFs Selected'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.all(15)),
                ),
                const SizedBox(height: 20),

                // 1. Watermark Section
                SwitchListTile(
                  title: const Text('Add Watermark', style: TextStyle(fontWeight: FontWeight.bold)),
                  value: _applyWatermark,
                  onChanged: (val) => setState(() => _applyWatermark = val),
                  activeColor: Colors.amber.shade700,
                ),
                if (_applyWatermark) ...[
                  TextField(controller: _watermarkCtrl, decoration: const InputDecoration(labelText: 'Watermark Text', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: _watermarkFreq,
                    decoration: const InputDecoration(labelText: 'Show on pages:', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('All Pages')),
                      DropdownMenuItem(value: 5, child: Text('Every 5 Pages')),
                      DropdownMenuItem(value: 10, child: Text('Every 10 Pages')),
                      DropdownMenuItem(value: 20, child: Text('Every 20 Pages')),
                    ],
                    onChanged: (val) => setState(() => _watermarkFreq = val!),
                  ),
                  const SizedBox(height: 10),
                ],
                const Divider(),

                // 2. Promo PDF Section
                SwitchListTile(
                  title: const Text('Insert Promo/Ad Page', style: TextStyle(fontWeight: FontWeight.bold)),
                  value: _applyPromo,
                  onChanged: (val) => setState(() => _applyPromo = val),
                  activeColor: Colors.amber.shade700,
                ),
                if (_applyPromo) ...[
                  OutlinedButton.icon(
                    onPressed: _pickPromoPdf,
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                    label: Text(_promoPdf == null ? 'Select Promo PDF File' : 'Promo PDF Selected'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: _promoFreq,
                    decoration: const InputDecoration(labelText: 'Insert Promo after:', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 2, child: Text('Every 2 Pages')),
                      DropdownMenuItem(value: 5, child: Text('Every 5 Pages')),
                      DropdownMenuItem(value: 10, child: Text('Every 10 Pages')),
                      DropdownMenuItem(value: 20, child: Text('Every 20 Pages')),
                    ],
                    onChanged: (val) => setState(() => _promoFreq = val!),
                  ),
                  const SizedBox(height: 10),
                ],
                const Divider(),

                // 3. Link Section
                SwitchListTile(
                  title: const Text('Add Web Link', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Makes the whole page clickable'),
                  value: _applyLink,
                  onChanged: (val) => setState(() => _applyLink = val),
                  activeColor: Colors.amber.shade700,
                ),
                if (_applyLink) ...[
                  TextField(controller: _linkCtrl, decoration: const InputDecoration(labelText: 'Website URL', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                ],
                
                const SizedBox(height: 30),
                
                // Final Action Button
                ElevatedButton(
                  onPressed: _selectedPdfs.isNotEmpty ? _processBulkPdfs : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800, foregroundColor: Colors.white, padding: const EdgeInsets.all(20)),
                  child: const Text('START BULK MODIFY ⚡', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
    );
  }
}
