import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart'; 
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

class LocalAIService {
  Llama? _llama; // <-- Changed this
  bool isModelLoaded = false;

  Future<void> initAI() async {
    try {
      Directory tempDir = await getApplicationDocumentsDirectory();
      String localPath = '${tempDir.path}/tinyllama.gguf';
      File localFile = File(localPath);

      if (!await localFile.exists()) {
        ByteData data = await rootBundle.load('assets/models/tinyllama.gguf');
        List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await localFile.writeAsBytes(bytes);
      }

      // Naya Tarika: Direct Llama class use karein
      _llama = Llama(localPath); 
      isModelLoaded = true;
      print("AI Model Ready!");

    } catch (e) {
      print("AI Error: $e");
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
    if (!isModelLoaded || _llama == null) return "AI loading...";

    String pdfText = await extractTextFromCurrentPage(pdfFilePath, pageNumber);
    if (pdfText.isEmpty) return "No text found on this page.";

    String prompt = "Text: $pdfText\nQuestion: $userCommand\nAnswer:";

    // Naya Tarika: prompt method ki jagah seedha use karein
    try {
      final response = _llama!.setPrompt(prompt); // Kuch versions me setPrompt hota hai
      // Agar setPrompt kaam na kare to hum sirf response return karenge
      return response.toString();
    } catch (e) {
      // Alternate method if setPrompt fails
      return "AI processing error. Please check model compatibility.";
    }
  }
}
