import 'dart:io';
import 'dart:typed_data'; 
import 'dart:ui'; 
import 'package:syncfusion_flutter_pdf/pdf.dart'; 
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LocalAIService {
  bool isModelLoaded = false;
  String modelStatus = "Cloud AI Initializing...";
  late final GenerativeModel _model;

  Future<void> initAI() async {
    try {
      final String apiKey = dotenv.env['GEMINI_API_KEY'] ?? ""; 
      
      if (apiKey.isEmpty) {
        modelStatus = "API Key missing! GitHub secrets aur .env file check karein.";
        return;
      }

      // YAHAN EXACT MODEL NAME UPDATE KAR DIYA HAI: gemini-3.1-flash-lite-preview
      _model = GenerativeModel(model: 'gemini-3.1-flash-lite-preview', apiKey: apiKey);
      isModelLoaded = true;
      modelStatus = "AI Model Ready!";
    } catch (e) {
      modelStatus = "AI Error: $e";
      print("Init AI Error: $e");
    }
  }

  Future<bool> pickAndLoadModel() async {
    isModelLoaded = true;
    modelStatus = "Cloud AI is active and ready!";
    return true; 
  }

  Future<String> extractTextFromCurrentPage(String pdfFilePath, int pageNumber) async {
    try {
      PdfDocument document = PdfDocument(inputBytes: File(pdfFilePath).readAsBytesSync());
      PdfTextExtractor extractor = PdfTextExtractor(document);
      int pageIndex = (pageNumber - 1) < 0 ? 0 : pageNumber - 1;
      String pageText = extractor.extractText(startPageIndex: pageIndex, endPageIndex: pageIndex);
      document.dispose();
      return pageText;
    } catch (e) {
      return "";
    }
  }

  Future<Uint8List> extractPageAsPdfBytes(String pdfFilePath, int pageNumber) async {
    PdfDocument document = PdfDocument(inputBytes: File(pdfFilePath).readAsBytesSync());
    PdfDocument singlePageDoc = PdfDocument();

    int pageIndex = (pageNumber - 1) < 0 ? 0 : pageNumber - 1;
    PdfPage originalPage = document.pages[pageIndex];

    singlePageDoc.pageSettings.size = originalPage.size;
    singlePageDoc.pages.add().graphics.drawPdfTemplate(originalPage.createTemplate(), Offset(0, 0));

    List<int> bytes = singlePageDoc.saveSync();
    singlePageDoc.dispose();
    document.dispose();

    return Uint8List.fromList(bytes);
  }

  Future<String> askAIAboutPdf({
    required String pdfFilePath, 
    required int pageNumber, 
    required String userCommand
  }) async {
    if (!isModelLoaded) {
      return "ERROR_MODEL_MISSING"; 
    }

    try {
      String pdfText = await extractTextFromCurrentPage(pdfFilePath, pageNumber);

      // Agar digital PDF hai (Text easily mil gaya)
      if (pdfText.trim().length > 20) {
        String prompt = """
        You are an intelligent and helpful PDF reading assistant. 
        Read the provided text extracted from a PDF page and answer the user's question based strictly on this text.
        
        CRITICAL RULE: Identify the primary language of the 'PDF TEXT' provided below. You MUST generate your final answer in that exact same language.

        PDF TEXT:
        $pdfText

        USER QUESTION:
        $userCommand
        """;

        final response = await _model.generateContent([Content.text(prompt)]);
        return response.text ?? "AI ne koi jawab nahi diya.";
      } 
      
      // Agar scanned photo / image PDF hai (Vision OCR trigger hoga)
      else {
        Uint8List pageBytes = await extractPageAsPdfBytes(pdfFilePath, pageNumber);

        final prompt = TextPart("""
        You are an intelligent and helpful document reading assistant. 
        Attached is a 1-page scanned PDF document (image-based). Please extract the visual text/information from it using OCR and answer the user's question based strictly on this document.
        
        CRITICAL RULE: Answer in the exact same language as written in the attached document.

        USER QUESTION:
        $userCommand
        """);

        final pdfPart = DataPart('application/pdf', pageBytes);

        final response = await _model.generateContent([
          Content.multi([prompt, pdfPart])
        ]);

        return response.text ?? "AI is scanned page ko padh nahi paya.";
      }
    } catch (e) {
      return "AI processing error: $e";
    }
  }
}
