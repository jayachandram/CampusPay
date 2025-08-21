// lib/main.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'role_selection_page.dart'; // <-- CHANGE THIS IMPORT
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const CampusPayApp());
}

class CampusPayApp extends StatelessWidget {
  const CampusPayApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ... theme data is the same
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF005A9C),
      brightness: Brightness.light,
      primary: const Color(0xFF005A9C),
      secondary: const Color(0xFFE87722),
      background: const Color(0xFFF4F7FA),
      surface: Colors.white,
    );

    return MaterialApp(
      title: 'Campus Pay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
        scaffoldBackgroundColor: colorScheme.surface,
        cardTheme: CardThemeData(
          elevation: 2,
          shadowColor: Colors.black12,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      // CHANGE THIS LINE
      home: const RoleSelectionPage(),
    );
  }
}
