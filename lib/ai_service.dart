import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart'; 
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:file_picker/file_picker.dart';

// Isolate ke liye top-level function zaroori hai
Llama _loadLlamaModel(String path) {
  // Model parameters to reduce memory spike (LMK fix)
  final params = ModelParams()
    ..nCtx = 256 // Reduced context size
    ..nBatch = 32 // Reduced batch size
    ..nThreads = 2; // Limit CPU threads
    
  return Llama(path, params); 
}

class LocalAIService {
  Llama? _llama; 
  bool isModelLoaded = false;
  String modelStatus = "AI engine start ho raha hai...";

  Future<void> initAI() async {
    try {
      Directory tempDir = await getApplicationDocumentsDirectory();
      String localPath = '${tempDir.path}/tinyllama.gguf'; // Default path, can be any model name
      File localFile = File(localPath);

      if (await localFile.exists()) {
        // Run initialization in an Isolate to prevent ANR
        _llama = await compute(_loadLlamaModel, localPath);
        isModelLoaded = true;
        modelStatus = "AI Model Ready!";
      } else {
        modelStatus = "Model missing. Kripya AI button daba kar model select karein.";
      }
    } catch (e) {
      modelStatus = "AI Error: $e";
      print("Init AI Error: $e");
    }
  }

  Future<bool> pickAndLoadModel() async {
    try {
      modelStatus = "File manager open ho raha hai...";
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select Model (.gguf)',
      );

      if (result != null && result.files.single.path != null) {
        String pickedPath = result.files.single.path!;
        modelStatus = "Model load ho raha hai... (Wait karein)";
        
        Directory tempDir = await getApplicationDocumentsDirectory();
        // Hamesha ek hi naam se save karte hain aasan management ke liye
        String localPath = '${tempDir.path}/tinyllama.gguf'; 
        
        await File(pickedPath).copy(localPath);
        
        // Run initialization in an Isolate to prevent ANR
        _llama = await compute(_loadLlamaModel, localPath);
        isModelLoaded = true;
        modelStatus = "AI Model Ready!";
        return true;
      }
      modelStatus = "Aapne koi file select nahi ki.";
      return false;
    } catch (e) {
      modelStatus = "Load karne me error: $e";
      print("Pick Model Error: $e");
      return false;
    }
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
    if (!isModelLoaded || _llama == null) {
      return "ERROR_MODEL_MISSING"; 
    }

    String pdfText = await extractTextFromCurrentPage(pdfFilePath, pageNumber);
    if (pdfText.isEmpty) return "Is page par AI ko koi text nahi mila.";

    // Truncate text to fit the small context window
    if (pdfText.length > 500) {
        pdfText = pdfText.substring(0, 500);
    }

    String prompt = "Text: $pdfText\nQuestion: $userCommand\nAnswer:";

    try {
      _llama!.setPrompt(prompt); 
      return "✅ AI Engine has received the prompt! (Processing in background...)";
    } catch (e) {
      return "AI processing error: $e";
    }
  }
}
