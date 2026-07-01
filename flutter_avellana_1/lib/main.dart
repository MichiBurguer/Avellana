import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'views/welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Avellana App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(

        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.lightBlue,
          primary: Colors.lightBlue[400],
          secondary: Colors.tealAccent[400],
        ),
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
    );
  }
}