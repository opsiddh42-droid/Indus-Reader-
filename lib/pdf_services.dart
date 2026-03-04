import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfServices {
  
  // 1. Watermark Add Karne Ka Function
  static Future<void> addWatermark(String inputPath, String outputPath, String watermarkText) async {
    final List<int> bytes = File(inputPath).readAsBytesSync();
    final PdfDocument document = PdfDocument(inputBytes: bytes);

    for (int i = 0; i < document.pages.count; i++) {
      final PdfPage page = document.pages[i];
      // Watermark center mein draw hoga, red color aur thodi transparency (100) ke sath
      page.graphics.drawString(
        watermarkText, 
        PdfStandardFont(PdfFontFamily.helvetica, 40),
        brush: PdfSolidBrush(PdfColor(255, 0, 0, 100)),
        bounds: const Rect.fromLTWH(150, 300, 300, 100),
      );
    }

    File(outputPath).writeAsBytesSync(await document.save());
    document.dispose();
  }

  // 2. Page Add aur Remove Karne Ka Function
  static Future<void> managePages(String inputPath, String outputPath, {int? pageToRemove}) async {
    final List<int> bytes = File(inputPath).readAsBytesSync();
    final PdfDocument document = PdfDocument(inputBytes: bytes);

    if (pageToRemove != null && pageToRemove < document.pages.count) {
      // Agar user ne koi page delete karne bola hai (Index 0 se shuru hota hai)
      document.pages.removeAt(pageToRemove);
    } else {
      // Varna PDF ke end mein ek naya blank page add kar do
      document.pages.add();
    }

    File(outputPath).writeAsBytesSync(await document.save());
    document.dispose();
  }

  // 3. Hyperlink Add Karna (Kisi specific area par link lagana)
  static Future<void> addHyperlink(String inputPath, String outputPath, String url, int pageIndex, Rect bounds) async {
    final List<int> bytes = File(inputPath).readAsBytesSync();
    final PdfDocument document = PdfDocument(inputBytes: bytes);

    final PdfPage page = document.pages[pageIndex];
    final PdfUriAnnotation uriAnnotation = PdfUriAnnotation(
      bounds: bounds, // Jis area par click karne se link khulega
      uri: url,
    );
    
    page.annotations.add(uriAnnotation);

    File(outputPath).writeAsBytesSync(await document.save());
    document.dispose();
  }

  // 4. Normal PDF se Text Copy/Extract Karna
  static Future<String> extractText(String inputPath) async {
    final List<int> bytes = File(inputPath).readAsBytesSync();
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    
    String text = PdfTextExtractor(document).extractText();
    document.dispose();
    
    return text; 
  }

  // 5. Logo Hatana (User ke click kiye hue area par White Box draw karna)
  static Future<void> hideLogo(String inputPath, String outputPath, int pageIndex, Rect logoArea) async {
    final List<int> bytes = File(inputPath).readAsBytesSync();
    final PdfDocument document = PdfDocument(inputBytes: bytes);

    final PdfPage page = document.pages[pageIndex];

    // Background color (White) ka ek box draw karna taaki logo chhup jaye
    page.graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(255, 255, 255)), 
      bounds: logoArea, 
    );

    File(outputPath).writeAsBytesSync(await document.save());
    document.dispose();
  }
}
