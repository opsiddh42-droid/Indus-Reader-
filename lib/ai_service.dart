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
  // UPDATED FUNCTIONS: ADVANCED PROMPTS ADDED
  // ====================================================================

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

  // UPDATED: MCQ Generate
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
      You are an expert educator and quiz creator. I have attached a PDF document.
      Generate $count Multiple Choice Questions (MCQs) in $language language based on the core topic of the attached PDF.
      
      CRITICAL INSTRUCTIONS FOR QUALITY:
      1. Difficulty Level: $level.
      2. Do not just copy lines from the PDF. Use your own external knowledge to create insightful, application-based, and challenging questions related to the PDF's topic.
      3. Explanation: Provide a highly detailed, well-structured explanation. Add extra relevant facts, context, or formulas from your own knowledge to enrich the answer.
      4. DO NOT use phrases like "According to the text", "As per the PDF", or "Here is the explanation". Just state the facts directly like an expert textbook.
      
      CRITICAL RULE: Return the response ONLY as a valid JSON array. Do not add any extra text.
      Format:
      [
        {
          "question": "Question text here?",
          "options": ["Option A", "Option B", "Option C", "Option D"],
          "answer": "Correct Option Exactly as it appears in the options array",
          "explanation": "Detailed explanation with extra facts and structure"
        }
      ]
      """);

      final pdfPart = DataPart('application/pdf', pdfBytes);

      final response = await _model.generateContent([
        Content.multi([prompt, pdfPart])
      ]);
      
      String resText = response.text ?? "[]";
      resText = resText.replaceAll("```json", "").replaceAll("```", "").trim();
      return resText;
    } catch (e) {
      return "ERROR: $e";
    }
  }

  // UPDATED: Summarize (Strictly Hindi + Structured + Extra Facts)
  Future<String> generateSummary({
    required String pdfFilePath, 
    required int startPage, 
    required int endPage,
  }) async {
    if (!isModelLoaded) return "ERROR_MODEL_MISSING";

    try {
      Uint8List pdfBytes = await extractMultiplePagesAsPdfBytes(pdfFilePath, startPage, endPage);

      final prompt = TextPart("""
      You are an expert summarizer. Analyze the attached PDF and provide a highly structured and comprehensive summary.
      
      CRITICAL INSTRUCTIONS:
      1. The summary MUST be generated in strictly HINDI language (Devanagari script).
      2. Do not just translate the document. Enhance the summary by adding relevant external facts, context, and background information from your own knowledge base to make it more educational.
      3. Format the summary beautifully using headings, subheadings, and bullet points.
      4. DO NOT use filler phrases like "This document says", "Here is the summary", or "As per the text". Start directly with the main content.
      """);

      final pdfPart = DataPart('application/pdf', pdfBytes);

      final response = await _model.generateContent([
        Content.multi([prompt, pdfPart])
      ]);
      
      return response.text ?? "Summary generation failed.";
    } catch (e) {
      return "ERROR: $e";
    }
  }

  // UPDATED: Short Notes (Strictly Hindi + Bullet Points + Extra Facts)
  Future<String> generateShortNotes({
    required String pdfFilePath, 
    required int startPage, 
    required int endPage,
    required String level 
  }) async {
    if (!isModelLoaded) return "ERROR_MODEL_MISSING";

    try {
      Uint8List pdfBytes = await extractMultiplePagesAsPdfBytes(pdfFilePath, startPage, endPage);

      final prompt = TextPart("""
      You are an expert academic note-taker. Create crisp, concise, and highly informative short notes from the attached PDF document.
      
      CRITICAL INSTRUCTIONS:
      1. The short notes MUST be generated strictly in HINDI language (Devanagari script).
      2. Detail Level: $level.
      3. Enhance the notes: Add important extra facts, historical context, or scientific details from your own knowledge base that are relevant to the topic but might be missing in the text.
      4. Structure: Use a highly readable format with bold headings, clear bullet points, and numbered lists where necessary. Make it perfect for exam revision.
      5. DO NOT use conversational fillers like "Here are your notes" or "According to the PDF". Write it like a professional study material.
      """);

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
