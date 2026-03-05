import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'drawing_canvas.dart'; 

class PdfServices {
  
  // 1. ADVANCED WATERMARK FUNCTION
  static Future<void> addAdvancedWatermark({
    required String inputPath, required String outputPath,
    required String text, required Color color,
    required double opacity, required String position,
    required bool allPages, required int currentPageIndex,
  }) async {
    final List<int> bytes = File(inputPath).readAsBytesSync();
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    PdfColor pdfColor = PdfColor(color.red, color.green, color.blue);
    PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, 40);

    void drawWatermarkOnPage(PdfPage page) {
      page.graphics.setTransparency(opacity);
      Size pageSize = page.size;
      double x = (pageSize.width / 2) - 100; 
      double y = (pageSize.height / 2);      
      if (position == 'Top') y = 50;
      if (position == 'Bottom') y = pageSize.height - 100;

      page.graphics.drawString(text, font, brush: PdfSolidBrush(pdfColor), bounds: Rect.fromLTWH(x, y, 300, 100));
    }

    if (allPages) {
      for (int i = 0; i < document.pages.count; i++) drawWatermarkOnPage(document.pages[i]);
    } else {
      if (currentPageIndex < document.pages.count) drawWatermarkOnPage(document.pages[currentPageIndex]);
    }

    File(outputPath).writeAsBytesSync(await document.save());
    document.dispose();
  }

  // 2. LINK MANAGER
  static Future<void> manageLinks({
    required String inputPath, required String outputPath,
    required int pageIndex, required String action, String? url,
  }) async {
    final List<int> bytes = File(inputPath).readAsBytesSync();
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final PdfPage page = document.pages[pageIndex];

    if (action == 'remove') {
      for (int i = page.annotations.count - 1; i >= 0; i--) page.annotations.remove(page.annotations[i]);
    } else if (action == 'add' && url != null) {
      final PdfUriAnnotation uriAnnotation = PdfUriAnnotation(bounds: Rect.fromLTWH(0, 0, page.size.width, 100), uri: url);
      page.annotations.add(uriAnnotation);
    }
    File(outputPath).writeAsBytesSync(await document.save());
    document.dispose();
  }

  // 3. LOGO HATANE KA FUNCTION
  static Future<void> hideLogo(String inputPath, String outputPath, int pageIndex, Rect logoArea) async {
    final List<int> bytes = File(inputPath).readAsBytesSync();
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final PdfPage page = document.pages[pageIndex];
    page.graphics.drawRectangle(brush: PdfSolidBrush(PdfColor(255, 255, 255)), bounds: logoArea);
    File(outputPath).writeAsBytesSync(await document.save());
    document.dispose();
  }

  // 4. DRAWING AUR HIGHLIGHT SAVE KARNA
  static Future<void> saveDrawing({
    required String inputPath, required String outputPath,
    required int pageIndex, required List<DrawnLine> lines,
  }) async {
    final List<int> bytes = File(inputPath).readAsBytesSync();
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final PdfPage page = document.pages[pageIndex];

    for (var line in lines) {
      PdfColor pdfColor = PdfColor(line.color.red, line.color.green, line.color.blue);
      PdfPen pen = PdfPen(pdfColor, width: line.width);
      
      page.graphics.save();
      page.graphics.setTransparency(line.color.opacity);

      for (int i = 0; i < line.path.length - 1; i++) {
        page.graphics.drawLine(pen, line.path[i], line.path[i + 1]);
      }
      page.graphics.restore();
    }
    File(outputPath).writeAsBytesSync(await document.save());
    document.dispose();
  }

  // --- NAYA: 5. MERGE PDFs FUNCTION ---
  static Future<void> mergePdfs({
    required List<String> inputPaths,
    required String outputPath,
  }) async {
    final PdfDocument finalDoc = PdfDocument();

    for (String path in inputPaths) {
      final List<int> bytes = File(path).readAsBytesSync();
      final PdfDocument tempDoc = PdfDocument(inputBytes: bytes);

      for (int i = 0; i < tempDoc.pages.count; i++) {
        final PdfPage tempPage = tempDoc.pages[i];
        final PdfPage newPage = finalDoc.pages.add();
        
        // Purane page ka template banakar naye page par chipkana
        final PdfTemplate template = tempPage.createTemplate();
        newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
      }
      tempDoc.dispose();
    }

    File(outputPath).writeAsBytesSync(await finalDoc.save());
    finalDoc.dispose();
  }
}
