import 'dart:convert';
import 'package:flutter/material.dart';

// --- MCQ Model Data Class ---
class MCQModel {
  final String question;
  final List<String> options;
  final String answer;
  final String explanation;
  String? selectedOption; // User ne jo choose kiya

  MCQModel({
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
  });

  factory MCQModel.fromJson(Map<String, dynamic> json) {
    return MCQModel(
      question: json['question'] ?? 'Question missing',
      options: List<String>.from(json['options'] ?? []),
      answer: json['answer'] ?? '',
      explanation: json['explanation'] ?? 'No explanation provided.',
    );
  }
}

// --- MCQ Test UI Screen ---
class MCQTestScreen extends StatefulWidget {
  final String aiJsonResponse;

  const MCQTestScreen({super.key, required this.aiJsonResponse});

  @override
  State<MCQTestScreen> createState() => _MCQTestScreenState();
}

class _MCQTestScreenState extends State<MCQTestScreen> {
  List<MCQModel> quizList = [];
  final PageController _pageController = PageController();
  int currentIndex = 0;
  bool isError = false;

  @override
  void initState() {
    super.initState();
    _parseJsonData();
  }

  void _parseJsonData() {
    try {
      // AI se aaya hua text JSON mein convert kar rahe hain
      final List<dynamic> decodedData = json.decode(widget.aiJsonResponse);
      setState(() {
        quizList = decodedData.map((item) => MCQModel.fromJson(item)).toList();
      });
    } catch (e) {
      setState(() {
        isError = true;
      });
      debugPrint("JSON Parse Error: $e");
    }
  }

  void nextQuestion() {
    if (currentIndex < quizList.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void prevQuestion() {
    if (currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Agar JSON galat format mein aaya
    if (isError || quizList.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("MCQ Test Error")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 60),
                const SizedBox(height: 16),
                const Text(
                  "AI ne sahi format mein questions generate nahi kiye. Please wapas jakar thode kam pages ya dusri settings ke sath try karein.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Go Back"),
                )
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Test (${currentIndex + 1}/${quizList.length})"),
        backgroundColor: Colors.deepPurpleAccent,
        foregroundColor: Colors.white,
      ),
      body: PageView.builder(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // Swipe disable (buttons use karne ke liye)
        onPageChanged: (index) => setState(() => currentIndex = index),
        itemCount: quizList.length,
        itemBuilder: (context, index) {
          final mcq = quizList[index];
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Q${index + 1}: ${mcq.question}",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  
                  // Options List
                  ...mcq.options.map((option) => buildOption(mcq, option)),
                  
                  // Explanation Box (Sirf tab dikhega jab user koi option choose kar lega)
                  if (mcq.selectedOption != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.lightbulb_outline, color: Colors.blue),
                              SizedBox(width: 8),
                              Text("Explanation", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                            ],
                          ),
                          const Divider(color: Colors.blue),
                          const SizedBox(height: 8),
                          Text(mcq.explanation, style: const TextStyle(fontSize: 15, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
          ]
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              onPressed: currentIndex == 0 ? null : prevQuestion,
              icon: const Icon(Icons.arrow_back_ios, size: 16),
              label: const Text("Previous"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent, foregroundColor: Colors.white),
              onPressed: currentIndex == quizList.length - 1 ? null : nextQuestion,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Next"),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Option UI Logic
  Widget buildOption(MCQModel mcq, String optionText) {
    bool isSelected = mcq.selectedOption == optionText;
    bool isCorrect = optionText == mcq.answer;
    bool showResult = mcq.selectedOption != null; // True if user has clicked any option

    Color cardColor = Colors.white;
    Color borderColor = Colors.grey.shade300;
    IconData? trailingIcon;
    Color iconColor = Colors.transparent;

    if (showResult) {
      if (isCorrect) {
        cardColor = Colors.green.shade50;
        borderColor = Colors.green;
        trailingIcon = Icons.check_circle;
        iconColor = Colors.green;
      } else if (isSelected) {
        cardColor = Colors.red.shade50;
        borderColor = Colors.red;
        trailingIcon = Icons.cancel;
        iconColor = Colors.red;
      }
    }

    return GestureDetector(
      onTap: () {
        // Ek baar choose karne ke baad lock ho jayega
        if (mcq.selectedOption == null) {
          setState(() {
            mcq.selectedOption = optionText;
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: isSelected || (showResult && isCorrect) ? 2 : 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                optionText, 
                style: TextStyle(
                  fontSize: 16,
                  color: showResult && (isCorrect || isSelected) ? Colors.black87 : Colors.black54,
                  fontWeight: showResult && (isCorrect || isSelected) ? FontWeight.bold : FontWeight.normal
                )
              )
            ),
            if (trailingIcon != null) Icon(trailingIcon, color: iconColor),
          ],
        ),
      ),
    );
  }
}
