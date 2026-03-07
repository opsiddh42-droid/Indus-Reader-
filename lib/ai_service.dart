import 'dart:io';
import 'package:pdf_text/pdf_text.dart';
// Note: pubspec.yaml me llama_cpp_dart add karna hoga
import 'package:llama_cpp_dart/llama_cpp_dart.dart'; 

class LocalAIService {
  LlamaContext? _aiModel;
  bool isModelLoaded = false;

  // 1. App start hone par AI Model Load karna
  Future<void> initAI(String modelPath) async {
    try {
      // Model file (jaise qwen-0.5b.gguf) device storage me honi chahiye
      _aiModel = LlamaContext(modelParams: ModelParams(modelPath: modelPath));
      isModelLoaded = true;
      print("AI Model successfully load ho gaya hai!");
    } catch (e) {
      print("Model load karne me error: $e");
    }
  }

  // 2. PDF ke current page ka text nikalna
  Future<String> extractTextFromCurrentPage(String pdfFilePath, int pageNumber) async {
    try {
      PDFDoc doc = await PDFDoc.fromPath(pdfFilePath);
      PDFPage page = doc.pageAt(pageNumber);
      String pageText = await page.text;
      return pageText;
    } catch (e) {
      return "Error: PDF read nahi ho payi.";
    }
  }

  // 3. AI se sawal puchna (MCQ, Summary, etc.)
  Future<String> askAIAboutPdf({
    required String pdfFilePath, 
    required int pageNumber, 
    required String userCommand
  }) async {
    if (!isModelLoaded || _aiModel == null) {
      return "AI model abhi load nahi hua hai.";
    }

    // Pehle text extract karein
    String pdfText = await extractTextFromCurrentPage(pdfFilePath, pageNumber);

    if (pdfText.isEmpty || pdfText.contains("Error")) {
      return "Is page par koi text nahi mila.";
    }

    // AI ke liye Prompt taiyar karein
    String prompt = '''You are a helpful assistant. Use the following text to fulfill the user's request.
    Text: $pdfText
    Command: $userCommand
    Answer:''';

    // AI ko prompt bhejein aur answer generate karein
    final response = _aiModel!.prompt(prompt);
    
    return response; 
  }
}
