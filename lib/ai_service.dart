import 'dart:io';
import 'dart:typed_data'; // <--- NAYA IMPORT (Bytes ke liye)
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

      // YAHAN MODEL BADAL DIYA HAI LIMIT ISSUE FIX KARNE KE LIYE
      _model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
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

  // Normal PDF se text nikalne ke liye
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

  // NAYA FUNCTION: Agar page Scanned Image hai, toh us ek page ki alag file banakar AI ko dene ke liye
  Future<Uint8List> extractPageAsPdfBytes(String pdfFilePath, int pageNumber) async {
    PdfDocument document = PdfDocument(inputBytes: File(pdfFilePath).readAsBytesSync());
    PdfDocument singlePageDoc = PdfDocument();

    int pageIndex = (pageNumber - 1) < 0 ? 0 : pageNumber - 1;
    PdfPage originalPage = document.pages[pageIndex];

    // Original page ka size copy karke naya page banaya aur us par photo (template) draw kar di
    singlePageDoc.pageSettings.size = originalPage.size;
    singlePageDoc.pages.add().graphics.drawPdfTemplate(originalPage.createTemplate(), const Offset(0, 0));

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
      // Step 1: Pehle check karo ki normal text hai kya
      String pdfText = await extractTextFromCurrentPage(pdfFilePath, pageNumber);

      // Agar text mil gaya (Normal digital PDF hai)
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
      
      // Step 2: Agar text NAHI mila (Yaani Scanned Photo / Image PDF hai)
      else {
        // Us 1 page ko mini-pdf bytes mein convert kar liya
        Uint8List pageBytes = await extractPageAsPdfBytes(pdfFilePath, pageNumber);

        // Prompt with DataPart (Gemini 1.5 natively image OCR karta hai!)
        final prompt = TextPart("""
        You are an intelligent and helpful document reading assistant. 
        Attached is a 1-page scanned PDF document (image-based). Please extract the visual text/information from it using OCR and answer the user's question based strictly on this document.
        
        CRITICAL RULE: Answer in the exact same language as written in the attached document.

        USER QUESTION:
        $userCommand
        """);

        final pdfPart = DataPart('application/pdf', pageBytes);

        // Gemini ko command aur PDF file dono bhej di
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
