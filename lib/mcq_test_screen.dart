import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart'; // Naya package animation ke liye

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
  
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    // Confetti controller setup
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
    _parseJsonData();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _parseJsonData() {
    try {
      final List<dynamic> decodedData = json.decode(widget.aiJsonResponse);
      setState(() {
        quizList = decodedData.map((item) => MCQModel.fromJson(item)).toList();
      });
    } catch (e) {
      setState(() { isError = true; });
      debugPrint("JSON Parse Error: $e");
    }
  }

  void nextQuestion() {
    if (currentIndex < quizList.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  void prevQuestion() {
    if (currentIndex > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  void submitTest() {
    // Submit karne par Result Screen par bhejenge
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(builder: (context) => ResultScreen(quizList: quizList))
    );
  }

  @override
  Widget build(BuildContext context) {
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
                const Text("AI ne sahi format mein questions generate nahi kiye. Please dusri settings try karein.", textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Go Back"))
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Question ${currentIndex + 1}/${quizList.length}"),
        backgroundColor: Colors.deepPurpleAccent,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: submitTest, 
            child: const Text("SUBMIT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          )
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            // Ab user swipe (slide) karke bhi next ja sakta hai
            physics: const BouncingScrollPhysics(), 
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
                      Text("Q${index + 1}: ${mcq.question}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      
                      ...mcq.options.map((option) => buildOption(mcq, option)),
                      
                      if (mcq.selectedOption != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade200)),
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
          
          // Confetti Animation Layer (Phool uchhalne ke liye)
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: 3.14 / 2, // Niche ki taraf
              maxBlastForce: 20,
              minBlastForce: 10,
              emissionFrequency: 0.05,
              numberOfParticles: 30,
              gravity: 0.2,
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              onPressed: currentIndex == 0 ? null : prevQuestion,
              icon: const Icon(Icons.arrow_back_ios, size: 16),
              label: const Text("Previous"),
            ),
            if (currentIndex == quizList.length - 1)
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: submitTest,
                child: const Text("Submit Test", style: TextStyle(fontWeight: FontWeight.bold)),
              )
            else
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent, foregroundColor: Colors.white),
                onPressed: nextQuestion,
                child: const Row(mainAxisSize: MainAxisSize.min, children: [Text("Next"), SizedBox(width: 8), Icon(Icons.arrow_forward_ios, size: 16)]),
              ),
          ],
        ),
      ),
    );
  }

  Widget buildOption(MCQModel mcq, String optionText) {
    bool isSelected = mcq.selectedOption == optionText;
    bool isCorrect = optionText == mcq.answer;
    bool showResult = mcq.selectedOption != null; 

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
        if (mcq.selectedOption == null) {
          setState(() { mcq.selectedOption = optionText; });
          
          if (optionText == mcq.answer) {
            _confettiController.play(); // Correct hone par animation chalega
          }
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
            Expanded(child: Text(optionText, style: TextStyle(fontSize: 16, color: showResult && (isCorrect || isSelected) ? Colors.black87 : Colors.black54, fontWeight: showResult && (isCorrect || isSelected) ? FontWeight.bold : FontWeight.normal))),
            if (trailingIcon != null) Icon(trailingIcon, color: iconColor),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// SCORECARD SCREEN (Naya Result UI)
// ==========================================
class ResultScreen extends StatelessWidget {
  final List<MCQModel> quizList;

  const ResultScreen({super.key, required this.quizList});

  @override
  Widget build(BuildContext context) {
    int total = quizList.length;
    int attempted = 0;
    int correct = 0;
    int wrong = 0;

    for (var mcq in quizList) {
      if (mcq.selectedOption != null) {
        attempted++;
        if (mcq.selectedOption == mcq.answer) {
          correct++;
        } else {
          wrong++;
        }
      }
    }

    int skipped = total - attempted;
    // Right +1, Wrong -0.33
    double score = (correct * 1.0) - (wrong * 0.33);
    if (score < 0) score = 0; // Negative total score ko 0 dikhane ke liye (optional)

    double accuracy = attempted > 0 ? (correct / attempted) * 100 : 0.0;
    double percentage = (score / total) * 100;
    if (percentage < 0) percentage = 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text("Test Scorecard"), backgroundColor: Colors.deepPurpleAccent, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Score Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Colors.deepPurpleAccent, Colors.purpleAccent]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text("Your Score", style: TextStyle(color: Colors.white70, fontSize: 18)),
                  const SizedBox(height: 8),
                  Text("${score.toStringAsFixed(2)} / $total", style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("Accuracy: ${accuracy.toStringAsFixed(1)}%  |  ${percentage.toStringAsFixed(1)}%", style: const TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Statistics Grid
            Row(
              children: [
                _buildStatCard("Total", total.toString(), Colors.blue),
                _buildStatCard("Attempted", attempted.toString(), Colors.orange),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatCard("Correct (+1)", correct.toString(), Colors.green),
                _buildStatCard("Wrong (-0.33)", wrong.toString(), Colors.red),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatCard("Skipped (0)", skipped.toString(), Colors.grey),
              ],
            ),
            
            const SizedBox(height: 40),
            
            // Buttons
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent, foregroundColor: Colors.white),
                icon: const Icon(Icons.fact_check),
                label: const Text("View Solutions & Explanations", style: TextStyle(fontSize: 16)),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => SolutionScreen(quizList: quizList)));
                },
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Wapas home screen par
              },
              child: const Text("Back to PDF Reader", style: TextStyle(color: Colors.deepPurple, fontSize: 16)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(color: Colors.black54, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// SOLUTIONS SCREEN (Saare Answers & Solutions)
// ==========================================
class SolutionScreen extends StatelessWidget {
  final List<MCQModel> quizList;

  const SolutionScreen({super.key, required this.quizList});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Solutions"), backgroundColor: Colors.deepPurpleAccent, foregroundColor: Colors.white),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: quizList.length,
        itemBuilder: (context, index) {
          final mcq = quizList[index];
          bool isAttempted = mcq.selectedOption != null;
          bool isCorrect = isAttempted && mcq.selectedOption == mcq.answer;

          return Card(
            margin: const EdgeInsets.only(bottom: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isAttempted ? (isCorrect ? Colors.green.shade100 : Colors.red.shade100) : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isAttempted ? (isCorrect ? "Correct" : "Wrong") : "Skipped",
                          style: TextStyle(color: isAttempted ? (isCorrect ? Colors.green : Colors.red) : Colors.grey.shade800, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text("Q${index + 1}: ${mcq.question}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Options List
                  ...mcq.options.map((opt) {
                    bool isThisCorrectAns = opt == mcq.answer;
                    bool isThisUserPick = opt == mcq.selectedOption;
                    
                    Color bgColor = Colors.transparent;
                    Color borderColor = Colors.grey.shade300;
                    if (isThisCorrectAns) {
                      bgColor = Colors.green.shade50;
                      borderColor = Colors.green;
                    } else if (isThisUserPick && !isCorrect) {
                      bgColor = Colors.red.shade50;
                      borderColor = Colors.red;
                    }

                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: bgColor, border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(8)),
                      child: Text(opt, style: TextStyle(fontWeight: isThisCorrectAns || isThisUserPick ? FontWeight.bold : FontWeight.normal)),
                    );
                  }),
                  
                  const Divider(height: 30),
                  const Text("Explanation:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  const SizedBox(height: 4),
                  Text(mcq.explanation, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
