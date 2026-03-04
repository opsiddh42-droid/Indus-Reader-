import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

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

    // Color convert karna
    PdfColor pdfColor = PdfColor(color.red, color.green, color.blue);
    PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, 40);

    void drawWatermarkOnPage(PdfPage page) {
      // Transparency set karna
      page.graphics.setTransparency(opacity);
      
      // Page ki lambai-chaudai nikalna
      Size pageSize = page.size;
      double x = (pageSize.width / 2) - 100; // Center X
      double y = (pageSize.height / 2);      // Center Y
      
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
    required String action, // 'remove' or 'add'
    String? url,
  }) async {
    final List<int> bytes = File(inputPath).readAsBytesSync();
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final PdfPage page = document.pages[pageIndex];

    if (action == 'remove') {
      // Page se saare link annotations hata dena
      page.annotations.clear(); 
    } else if (action == 'add' && url != null) {
      // Naya link poore page ke top par dalna (Example)
      final PdfUriAnnotation uriAnnotation = PdfUriAnnotation(
        bounds: Rect.fromLTWH(0, 0, page.size.width, 100), 
        uri: url,
      );
      page.annotations.add(uriAnnotation);
    }

    File(outputPath).writeAsBytesSync(await document.save());
    document.dispose();
  }

  // (Logo Hatane wala function same rahega)
  static Future<void> hideLogo(String inputPath, String outputPath, int pageIndex, Rect logoArea) async {
    final List<int> bytes = File(inputPath).readAsBytesSync();
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final PdfPage page = document.pages[pageIndex];
    page.graphics.drawRectangle(brush: PdfSolidBrush(PdfColor(255, 255, 255)), bounds: logoArea);
    File(outputPath).writeAsBytesSync(await document.save());
    document.dispose();
  }
}
