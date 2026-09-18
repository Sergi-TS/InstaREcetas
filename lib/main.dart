import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/recipes/presentation/pages/gallery_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Cargar variables de entorno
  await dotenv.load(fileName: ".env");

  // Inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Iniciar sesión anónima si no hay usuario
  try {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  } on FirebaseAuthException catch (e) {
    print("Error de Firebase Auth (¿está habilitado el login anónimo en la consola?): ${e.message}");
  } catch (e) {
    print("Error desconocido en autenticación: $e");
  }

  runApp(
    const ProviderScope(
      child: RecipeCatcherApp(),
    ),
  );
}

class RecipeCatcherApp extends StatelessWidget {
  const RecipeCatcherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RecipeCatcher',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const GalleryPage(),
    );
  }
}
