import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'pdf_services.dart';

class PasswordScreen extends StatefulWidget {
  const PasswordScreen({super.key});

  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  File? _selectedFile;
  bool _isProcessing = false;
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _passwordController.clear();
      });
    }
  }

  Future<void> _processPdf(bool isLocking) async {
    if (_selectedFile == null) return;
    
    String password = _passwordController.text.trim();
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a password!'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final dir = await getApplicationDocumentsDirectory();
      String actionName = isLocking ? 'locked' : 'unlocked';
      final outputPath = '${dir.path}/${actionName}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (isLocking) {
        await PdfServices.protectPdf(inputPath: _selectedFile!.path, outputPath: outputPath, password: password);
      } else {
        await PdfServices.unlockPdf(inputPath: _selectedFile!.path, outputPath: outputPath, password: password);
      }

      setState(() => _isProcessing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF $actionName successfully! Check Recent Files.'), backgroundColor: Colors.green));
        Navigator.pop(context); // Home par wapas
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        // Agar galat password dala unlock karte time, toh ye error aayega
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isLocking ? 'Error locking PDF.' : 'Incorrect Password or Error unlocking PDF.'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Protect & Unlock PDF', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add a password to secure your PDF, or remove an existing password (if you know it).', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            
            Center(
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _pickFile,
                icon: const Icon(Icons.folder_open),
                label: Text(_selectedFile == null ? 'Select PDF File' : 'Change File'),
              ),
            ),
            
            const SizedBox(height: 30),

            if (_selectedFile != null) ...[
              Card(
                elevation: 2,
                child: ListTile(
                  leading: const Icon(Icons.security, color: Colors.blueAccent, size: 40),
                  title: Text(_selectedFile!.path.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(height: 30),
              
              const Text('Enter Password:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              
              TextField(
                controller: _passwordController,
                obscureText: true, // Password hide karne ke liye
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
              ),
              
              const Spacer(),
              
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : () => _processPdf(false),
                      icon: const Icon(Icons.lock_open),
                      label: const Text('Unlock'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade300, foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(vertical: 16)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : () => _processPdf(true),
                      icon: _isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.lock),
                      label: Text(_isProcessing ? 'Wait...' : 'Lock PDF'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                    ),
                  ),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }
}
