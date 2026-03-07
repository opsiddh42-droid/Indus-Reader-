import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart'; 
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LocalAIService {
  bool isModelLoaded = false;
  String modelStatus = "Cloud AI Initializing...";
  late final GenerativeModel _model;

  Future<void> initAI() async {
    try {
      // .env file se secure API key fetch kar rahe hain
      final String apiKey = dotenv.env['GEMINI_API_KEY'] ?? ""; 
      
      if (apiKey.isEmpty) {
        modelStatus = "API Key missing! GitHub secrets aur .env file check karein.";
        return;
      }

      // YAHAN NAYA FAST MODEL ADD KIYA HAI: gemini-2.5-flash
      _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
      isModelLoaded = true;
      modelStatus = "AI Model Ready!";
    } catch (e) {
      modelStatus = "AI Error: $e";
      print("Init AI Error: $e");
    }
  }

  // Ab file picker ki zarurat nahi, par UI crash na ho isliye ye function wahi rakha hai
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

  Future<String> askAIAboutPdf({
    required String pdfFilePath, 
    required int pageNumber, 
    required String userCommand
  }) async {
    if (!isModelLoaded) {
      return "ERROR_MODEL_MISSING"; 
    }

    String pdfText = await extractTextFromCurrentPage(pdfFilePath, pageNumber);
    if (pdfText.isEmpty) return "Is page par AI ko koi text nahi mila.";

    // English command jo PDF ki language detect karke usi mein jawab dega
    String prompt = """
    You are an intelligent and helpful PDF reading assistant. 
    Read the provided text extracted from a PDF page and answer the user's question based strictly on this text.
    
    CRITICAL RULE: Identify the primary language of the 'PDF TEXT' provided below. You MUST generate your final answer in that exact same language. (For example, if the PDF text is in Hindi, your answer must be in Hindi. If it is in English, answer in English).

    PDF TEXT:
    $pdfText

    USER QUESTION:
    $userCommand
    
    ANSWER:
    """;

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text ?? "AI ne koi jawab nahi diya.";
    } catch (e) {
      return "AI processing error: $e";
    }
  }
}
