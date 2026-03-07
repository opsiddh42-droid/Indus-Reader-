import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart'; // <-- NAYA IMPORT (Syncfusion)
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

class LocalAIService {
  LlamaContext? _aiModel;
  bool isModelLoaded = false;

  // App start hone par ye function call karein
  Future<void> initAI() async {
    try {
      print("Model copy ho raha hai... (Pehli baar thoda time lag sakta hai)");
      
      Directory tempDir = await getApplicationDocumentsDirectory();
      String localPath = '${tempDir.path}/tinyllama.gguf';
      File localFile = File(localPath);

      if (!await localFile.exists()) {
        ByteData data = await rootBundle.load('assets/models/tinyllama.gguf');
        List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await localFile.writeAsBytes(bytes);
        print("Model phone storage me copy ho gaya!");
      }

      _aiModel = LlamaContext(modelParams: ModelParams(modelPath: localPath));
      isModelLoaded = true;
      print("AI Model successfully load ho gaya hai aur ready hai!");

    } catch (e) {
      print("Model setup karne me error: $e");
    }
  }

  // PDF read karne ka logic Syncfusion ke dwara
  Future<String> extractTextFromCurrentPage(String pdfFilePath, int pageNumber) async {
    try {
      // PDF document open karein
      PdfDocument document = PdfDocument(inputBytes: File(pdfFilePath).readAsBytesSync());
      PdfTextExtractor extractor = PdfTextExtractor(document);
      
      // Syncfusion me page index 0 se shuru hota hai (jaise page 1 ka index 0)
      int pageIndex = pageNumber - 1;
      if (pageIndex < 0) pageIndex = 0;

      // Sirf current page ka text nikalna
      String pageText = extractor.extractText(startPageIndex: pageIndex, endPageIndex: pageIndex);
      
      // Memory bachane ke liye document close karein
      document.dispose();
      
      return pageText;
    } catch (e) {
      return "Error: PDF read nahi ho payi.";
    }
  }

  // AI se Q&A karne ka logic
  Future<String> askAIAboutPdf({
    required String pdfFilePath, 
    required int pageNumber, 
    required String userCommand
  }) async {
    if (!isModelLoaded || _aiModel == null) {
      return "AI model abhi ready nahi hai. Kripya thoda wait karein.";
    }

    String pdfText = await extractTextFromCurrentPage(pdfFilePath, pageNumber);

    if (pdfText.isEmpty || pdfText.contains("Error")) {
      return "Is page par AI ko padhne ke liye koi text nahi mila.";
    }

    // AI Prompt
    String prompt = '''Answer the command using ONLY the given text.
    Text: $pdfText
    Command: $userCommand
    Answer:''';

    // Output generate karna
    final response = _aiModel!.prompt(prompt);
    return response; 
  }
}
