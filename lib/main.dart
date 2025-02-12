import 'package:flutter/material.dart';
import 'custom_decks_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TMR Learning App',
      theme: ThemeData(
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: Color(0xFFEEEEEE),
          onPrimary: Colors.black,
          secondary: Color(0xFFFF9050),
          onSecondary: Colors.black,
          error: Colors.red,
          onError: Colors.white,
          background: Color(0xFF102333),
          onBackground: Color(0xFFFF9050),
          surface: Color(0xFFEEEEEE),
          onSurface: Colors.black,
        ),
        scaffoldBackgroundColor: const Color(0xFF102333),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFFF9050)),
          bodyMedium: TextStyle(color: Color(0xFFFF9050)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEEEEEE),
            foregroundColor: Colors.black,
            disabledBackgroundColor: const Color(0xFFAAAAAA),
            disabledForegroundColor: const Color(0xFF555555),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          fillColor: Color(0xFFEEEEEE),
          filled: true,
          labelStyle: TextStyle(color: Colors.black),
          hintStyle: TextStyle(color: Colors.black54),
          // Add this:
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.black54),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.black),
          ),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.black,
          selectionColor: Colors.black26,
          selectionHandleColor: Colors.black,
        ),
        dialogTheme: const DialogTheme(
          backgroundColor: Color(0xFFEEEEEE),
          titleTextStyle: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
          contentTextStyle: TextStyle(color: Colors.black),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFFEEEEEE),
          contentTextStyle: TextStyle(color: Colors.black),
        ),
      ),
      home: const CustomDecksScreen(),
    );
  }
}