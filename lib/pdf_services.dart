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

  // --- UPDATED: 4. DRAWING SAVE (Fixed Coordinates) ---
  static Future<void> saveDrawing({
    required String inputPath, required String outputPath,
    required int pageIndex, required List<DrawnLine> lines,
    required Size screenSize, required Offset scrollOffset, required double zoomLevel
  }) async {
    final List<int> bytes = File(inputPath).readAsBytesSync();
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final PdfPage page = document.pages[pageIndex];

    Size pageSize = page.size; 
    
    // Scale nikalna: Screen ke mukable PDF kitna bada/chota hai
    double scale = pageSize.width / screenSize.width;
    double screenPageHeight = pageSize.height / scale;
    double previousPagesOffset = pageIndex * (screenPageHeight + 4); 

    for (var line in lines) {
      PdfColor pdfColor = PdfColor(line.color.red, line.color.green, line.color.blue);
      PdfPen pen = PdfPen(pdfColor, width: (line.width * scale) / zoomLevel); 
      
      page.graphics.save();
      page.graphics.setTransparency(line.color.opacity);

      for (int i = 0; i < line.path.length - 1; i++) {
        double absX1 = (line.path[i].dx + scrollOffset.dx) / zoomLevel;
        double absY1 = (line.path[i].dy + scrollOffset.dy) / zoomLevel;
        
        double absX2 = (line.path[i+1].dx + scrollOffset.dx) / zoomLevel;
        double absY2 = (line.path[i+1].dy + scrollOffset.dy) / zoomLevel;

        double localY1 = absY1 - previousPagesOffset;
        double localY2 = absY2 - previousPagesOffset;

        double pdfX1 = absX1 * scale;
        double pdfY1 = localY1 * scale;
        
        double pdfX2 = absX2 * scale;
        double pdfY2 = localY2 * scale;

        page.graphics.drawLine(pen, Offset(pdfX1, pdfY1), Offset(pdfX2, pdfY2));
      }
      page.graphics.restore();
    }
    File(outputPath).writeAsBytesSync(await document.save());
    document.dispose();
  }

  // 5. MERGE PDFs FUNCTION
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
        final PdfTemplate template = tempPage.createTemplate();
        newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
      }
      tempDoc.dispose();
    }

    File(outputPath).writeAsBytesSync(await finalDoc.save());
    finalDoc.dispose();
  }

  // 6. SPLIT PDF FUNCTION
  static Future<void> splitPdf({
    required String inputPath, required String outputPath,
    required int startPage, required int endPage,
  }) async {
    final List<int> bytes = File(inputPath).readAsBytesSync();
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final PdfDocument newDocument = PdfDocument();

    for (int i = startPage - 1; i < endPage; i++) {
      if (i >= 0 && i < document.pages.count) {
        final PdfPage tempPage = document.pages[i];
        final PdfPage newPage = newDocument.pages.add();
        final PdfTemplate template = tempPage.createTemplate();
        newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
      }
    }

    File(outputPath).writeAsBytesSync(await newDocument.save());
    newDocument.dispose();
    document.dispose();
  }

  // 7. COMPRESS PDF FUNCTION
  static Future<void> compressPdf({
    required String inputPath, required String outputPath,
  }) async {
    final List<int> bytes = File(inputPath).readAsBytesSync();
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    
    document.compressionLevel = PdfCompressionLevel.best;
    
    File(outputPath).writeAsBytesSync(await document.save());
    document.dispose();
  }

  // 8. ORGANIZE (DELETE) PAGES FUNCTION
  static Future<void> removePages({
    required String inputPath, required String outputPath,
    required List<int> pagesToDelete, 
  }) async {
    final List<int> bytes = File(inputPath).readAsBytesSync();
    final PdfDocument document = PdfDocument(inputBytes: bytes);

    pagesToDelete.sort((a, b) => b.compareTo(a));

    for (int index in pagesToDelete) {
      if (index >= 0 && index < document.pages.count) {
        document.pages.removeAt(index);
      }
    }

    File(outputPath).writeAsBytesSync(await document.save());
    document.dispose();
  }

  // 9. PASSWORD PROTECT PDF (Lock)
  static Future<void> protectPdf({
    required String inputPath, required String outputPath, required String password,
  }) async {
    final List<int> bytes = File(inputPath).readAsBytesSync();
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    
    final PdfSecurity security = document.security;
    security.userPassword = password;
    security.ownerPassword = password;
    security.algorithm = PdfEncryptionAlgorithm.aesx256Bit;

    File(outputPath).writeAsBytesSync(await document.save());
    document.dispose();
  }

  // 10. REMOVE PASSWORD (Unlock)
  static Future<void> unlockPdf({
    required String inputPath, required String outputPath, required String password,
  }) async {
    final List<int> bytes = File(inputPath).readAsBytesSync();
    final PdfDocument document = PdfDocument(inputBytes: bytes, password: password);
    
    document.security.userPassword = '';
    document.security.ownerPassword = '';

    File(outputPath).writeAsBytesSync(await document.save());
    document.dispose();
  }

  // 11. ADD E-SIGNATURE
  static Future<void> addSignature({
    required String inputPath, required String outputPath,
    required int pageIndex, required List<DrawnLine> lines,
  }) async {
    final List<int> bytes = File(inputPath).readAsBytesSync();
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    
    if (pageIndex >= 0 && pageIndex < document.pages.count) {
      final PdfPage page = document.pages[pageIndex];
      page.graphics.save();
      
      page.graphics.translateTransform(page.size.width - 320, page.size.height - 170);

      for (var line in lines) {
        PdfColor pdfColor = PdfColor(0, 0, 150); 
        PdfPen pen = PdfPen(pdfColor, width: 3); 
        
        for (int i = 0; i < line.path.length - 1; i++) {
          page.graphics.drawLine(pen, line.path[i], line.path[i + 1]);
        }
      }
      page.graphics.restore();
    }

    File(outputPath).writeAsBytesSync(await document.save());
    document.dispose();
  }
}
