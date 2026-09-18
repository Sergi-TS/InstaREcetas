import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recipecatcher/features/import_recipe/data/gemini_service.dart';
import 'package:recipecatcher/features/recipes/data/recipe_repository.dart';

class ImportRecipePage extends ConsumerStatefulWidget {
  const ImportRecipePage({super.key});

  @override
  ConsumerState<ImportRecipePage> createState() => _ImportRecipePageState();
}

class _ImportRecipePageState extends ConsumerState<ImportRecipePage> {
  final _textController = TextEditingController();
  bool _isLoading = false;

  Future<void> _processRecipe() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final geminiService = ref.read(geminiServiceProvider);
      final repository = ref.read(recipeRepositoryProvider);

      // 1. Extraer receta con IA
      final extractedRecipe = await geminiService.extractRecipeFromText(text);

      // 2. Guardar en Firestore (sin await para que no se quede colgado esperando la red de Firebase)
      repository.saveRecipe(extractedRecipe);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receta guardada exitosamente!')),
        );
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Añadir Receta'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Pega el texto, enlace o la descripción de Instagram/Facebook aquí:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Ej. "Receta de Tarta de Manzana..."',
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _processRecipe,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Procesar con IA y Guardar',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
