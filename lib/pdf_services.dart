import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'drawing_canvas.dart'; // NAYA: Drawing ka data lene ke liye

class PdfServices {
  
  // 1. ADVANCED WATERMARK FUNCTION
  static Future<void> addAdvancedWatermark({
    required String inputPath,
    required String outputPath,
    required String text,
    required Color color,
    required double opacity,
    required String position,
    required bool allPages,
    required int currentPageIndex,
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

      page.graphics.drawString(
        text, 
        font,
        brush: PdfSolidBrush(pdfColor),
        bounds: Rect.fromLTWH(x, y, 300, 100),
      );
    }

    if (allPages) {
      for (int i = 0; i < document.pages.count; i++) {
        drawWatermarkOnPage(document.pages[i]);
      }
    } else {
      if (currentPageIndex < document.pages.count) {
        drawWatermarkOnPage(document.pages[currentPageIndex]);
      }
    }

    File(outputPath).writeAsBytesSync(await document.save());
    document.dispose();
  }

  // 2. LINK MANAGER (Remove old or Add new)
  static Future<void> manageLinks({
    required String inputPath,
    required String outputPath,
    required int pageIndex,
    required String action, 
    String? url,
  }) async {
    final List<int> bytes = File(inputPath).readAsBytesSync();
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final PdfPage page = document.pages[pageIndex];

    if (action == 'remove') {
      page.annotations.clear(); 
    } else if (action == 'add' && url != null) {
      final PdfUriAnnotation uriAnnotation = PdfUriAnnotation(
        bounds: Rect.fromLTWH(0, 0, page.size.width, 100), 
        uri: url,
      );
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

  // 4. NAYA: DRAWING AUR HIGHLIGHT SAVE KARNE KA FUNCTION
  static Future<void> saveDrawing({
    required String inputPath,
    required String outputPath,
    required int pageIndex,
    required List<DrawnLine> lines,
  }) async {
    final List<int> bytes = File(inputPath).readAsBytesSync();
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final PdfPage page = document.pages[pageIndex];

    for (var line in lines) {
      // Flutter ke Color ko PDF ke Color mein badalna
      PdfColor pdfColor = PdfColor(line.color.red, line.color.green, line.color.blue);
      // Pen ka size set karna
      PdfPen pen = PdfPen(pdfColor, width: line.width);
      
      // State save karna taaki dusri lines par asar na pade
      page.graphics.save();
      // Highlighter effect ke liye transparency lagana
      page.graphics.setTransparency(line.color.opacity);

      // Path ke andar jitne bhi points hain, unhe jod kar PDF par line draw karna
      for (int i = 0; i < line.path.length - 1; i++) {
        Offset p1 = line.path[i];
        Offset p2 = line.path[i + 1];
        page.graphics.drawLine(pen, p1, p2);
      }
      
      // State wapas normal karna
      page.graphics.restore();
    }

    File(outputPath).writeAsBytesSync(await document.save());
    document.dispose();
  }
}
