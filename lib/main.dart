import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // NAYA IMPORT (API Key ke liye)
import 'home_screen.dart';

// main() function ko 'async' kar diya hai
void main() async {
  // Flutter bindings ko initialize karna zaroori hai async ke liye
  WidgetsFlutterBinding.ensureInitialized();
  
  // App start hone se pehle .env file se API key load kar lega
  await dotenv.load(fileName: ".env"); 
  
  runApp(const IndusReaderApp());
}

class IndusReaderApp extends StatelessWidget {
  const IndusReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Indus Reader',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
        ),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
