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

  // ====================================================================
  // NAYE FUNCTIONS (MULTI-PAGE MCQ, SUMMARY AUR SHORT NOTES KE LIYE)
  // ====================================================================

  // Selected pages ko original PDF se nikal kar ek nayi PDF (bytes) banayega
  Future<Uint8List> extractMultiplePagesAsPdfBytes(String pdfFilePath, int startPage, int endPage) async {
    PdfDocument originalDoc = PdfDocument(inputBytes: File(pdfFilePath).readAsBytesSync());
    PdfDocument newDoc = PdfDocument();

    int start = (startPage - 1) < 0 ? 0 : startPage - 1;
    int end = (endPage - 1) >= originalDoc.pages.count ? originalDoc.pages.count - 1 : endPage - 1;

    for (int i = start; i <= end; i++) {
      PdfPage originalPage = originalDoc.pages[i];
      newDoc.pageSettings.size = originalPage.size;
      newDoc.pages.add().graphics.drawPdfTemplate(originalPage.createTemplate(), const Offset(0, 0));
    }

    List<int> bytes = newDoc.saveSync();
    newDoc.dispose();
    originalDoc.dispose();

    return Uint8List.fromList(bytes);
  }

  // MCQ Generate (Direct PDF attach karke)
  Future<String> generateMCQs({
    required String pdfFilePath, 
    required int startPage, 
    required int endPage,
    required int count,
    required String level,
    required String language
  }) async {
    if (!isModelLoaded) return "ERROR_MODEL_MISSING";

    try {
      Uint8List pdfBytes = await extractMultiplePagesAsPdfBytes(pdfFilePath, startPage, endPage);

      final prompt = TextPart("""
      You are an expert quiz creator. I have attached a PDF document.
      Generate $count Multiple Choice Questions (MCQs) in $language language based strictly on the attached PDF.
      The difficulty level should be $level.
      
      CRITICAL RULE: Return the response ONLY as a valid JSON array. Do not add any extra text or markdown formatting.
      Format:
      [
        {
          "question": "Question text here?",
          "options": ["Option 1", "Option 2", "Option 3", "Option 4"],
          "answer": "Correct Option Exactly as it appears in the options array",
          "explanation": "Detailed explanation for the answer"
        }
      ]
      """);

      final pdfPart = DataPart('application/pdf', pdfBytes);

      final response = await _model.generateContent([
        Content.multi([prompt, pdfPart])
      ]);
      
      String resText = response.text ?? "[]";
      // Markdown clean-up incase AI outputs it
      resText = resText.replaceAll("```json", "").replaceAll("```", "").trim();
      return resText;
    } catch (e) {
      return "ERROR: $e";
    }
  }

  // Summarize (Direct PDF attach karke)
  Future<String> generateSummary({
    required String pdfFilePath, 
    required int startPage, 
    required int endPage,
  }) async {
    if (!isModelLoaded) return "ERROR_MODEL_MISSING";

    try {
      Uint8List pdfBytes = await extractMultiplePagesAsPdfBytes(pdfFilePath, startPage, endPage);

      final prompt = TextPart("Please provide a well-structured and comprehensive summary of the attached PDF document.");
      final pdfPart = DataPart('application/pdf', pdfBytes);

      final response = await _model.generateContent([
        Content.multi([prompt, pdfPart])
      ]);
      
      return response.text ?? "Summary generation failed.";
    } catch (e) {
      return "ERROR: $e";
    }
  }

  // Short Notes (Direct PDF attach karke)
  Future<String> generateShortNotes({
    required String pdfFilePath, 
    required int startPage, 
    required int endPage,
    required String level 
  }) async {
    if (!isModelLoaded) return "ERROR_MODEL_MISSING";

    try {
      Uint8List pdfBytes = await extractMultiplePagesAsPdfBytes(pdfFilePath, startPage, endPage);

      final prompt = TextPart("Create crisp, concise, and highly informative short notes in bullet points from the attached PDF document. The detail level should be $level.");
      final pdfPart = DataPart('application/pdf', pdfBytes);

      final response = await _model.generateContent([
        Content.multi([prompt, pdfPart])
      ]);
      
      return response.text ?? "Short notes generation failed.";
    } catch (e) {
      return "ERROR: $e";
    }
  }
}
