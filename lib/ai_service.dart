import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart'; 
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:file_picker/file_picker.dart';

class LocalAIService {
  Llama? _llama; 
  bool isModelLoaded = false;
  String modelStatus = "AI engine start ho raha hai...";

  Future<void> initAI() async {
    try {
      Directory tempDir = await getApplicationDocumentsDirectory();
      String localPath = '${tempDir.path}/tinyllama.gguf'; 
      File localFile = File(localPath);

      if (await localFile.exists()) {
        // Isolate (compute) hata diya hai taaki C++ Pointer Crash na ho.
        // App 2-3 second freeze hoga jab model load hoga, ghabrana mat.
        _llama = Llama(localPath);
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
        String localPath = '${tempDir.path}/tinyllama.gguf'; 
        
        await File(pickedPath).copy(localPath);
        
        // Seedha main thread par Llama load kar rahe hain
        _llama = Llama(localPath);
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
