import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../providers/fridge_provider.dart';
import 'package:intl/intl.dart';
import 'package:recipecatcher/features/import_recipe/data/gemini_service.dart';
import 'package:recipecatcher/features/recipes/presentation/pages/recipe_detail_page.dart';

class FridgePage extends ConsumerStatefulWidget {
  const FridgePage({super.key});

  @override
  ConsumerState<FridgePage> createState() => _FridgePageState();
}

class _FridgePageState extends ConsumerState<FridgePage> {
  bool _isGenerating = false;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  void _showManualAddDialog() {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Añadir a la Nevera'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Ingrediente (ej. Tomate)'),
                  ),
                  TextField(
                    controller: quantityController,
                    decoration: const InputDecoration(labelText: 'Cantidad (opcional)'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(selectedDate == null 
                          ? 'Sin fecha de caducidad' 
                          : 'Caduca: ${DateFormat('dd/MM/yyyy').format(selectedDate!)}'
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(const Duration(days: 3)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() {
                              selectedDate = date;
                            });
                          }
                        },
                        child: const Text('Seleccionar'),
                      )
                    ],
                  )
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty) {
                    ref.read(fridgeProvider.notifier).addItem(
                      name: nameController.text.trim(),
                      quantity: quantityController.text.trim().isEmpty ? null : quantityController.text.trim(),
                      expirationDate: selectedDate,
                    );
                    Navigator.pop(context);
                  }
                },
                child: const Text('Añadir'),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _scanWithCamera() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.camera);
    if (xfile == null) return;
    
    setState(() => _isGenerating = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Analizando imagen...')));
    
    try {
      final bytes = await File(xfile.path).readAsBytes();
      final base64Image = base64Encode(bytes);
      
      final aiService = ref.read(geminiServiceProvider);
      final newIngredients = await aiService.extractIngredientsFromImage(base64Image);
      
      for (final ing in newIngredients) {
        ref.read(fridgeProvider.notifier).addItem(name: ing);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Se añadieron ${newIngredients.length} ingredientes.')));
      }
    } catch(e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _listenWithMicrophone() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Escuchando... Di los ingredientes.'),
        duration: Duration(seconds: 4),
      ));
      
      _speech.listen(
        onResult: (result) async {
          if (result.finalResult) {
            setState(() => _isListening = false);
            setState(() => _isGenerating = true);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Procesando audio...')));
            
            try {
              final aiService = ref.read(geminiServiceProvider);
              final newIngredients = await aiService.extractIngredientsFromText(result.recognizedWords);
              
              for (final ing in newIngredients) {
                final name = ing['name'] as String?;
                final exp = ing['expirationDate'] as String?;
                if (name != null && name.isNotEmpty) {
                  DateTime? parsedDate;
                  if (exp != null) {
                    try {
                      parsedDate = DateTime.parse(exp);
                    } catch (_) {}
                  }
                  ref.read(fridgeProvider.notifier).addItem(
                    name: name,
                    expirationDate: parsedDate,
                  );
                }
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Se añadieron ${newIngredients.length} ingredientes.')));
              }
            } catch(e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
              }
            } finally {
              if (mounted) setState(() => _isGenerating = false);
            }
          }
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microfono no disponible.')));
    }
  }

  void _showAddOptionsSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Añadir Ingredientes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Escribir manualmente'),
                onTap: () {
                  Navigator.pop(context);
                  _showManualAddDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Hacer una foto a la nevera'),
                onTap: () {
                  Navigator.pop(context);
                  _scanWithCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.mic),
                title: const Text('Dictar ingredientes'),
                onTap: () {
                  Navigator.pop(context);
                  _listenWithMicrophone();
                },
              ),
            ],
          ),
        );
      }
    );
  }

  String _getEmojiForIngredient(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('tomate')) return '🍅';
    if (lower.contains('cebolla')) return '🧅';
    if (lower.contains('pimiento')) return '🫑';
    if (lower.contains('leche')) return '🥛';
    if (lower.contains('pollo')) return '🍗';
    if (lower.contains('huevo')) return '🥚';
    if (lower.contains('queso')) return '🧀';
    if (lower.contains('carne')) return '🥩';
    if (lower.contains('pescado')) return '🐟';
    if (lower.contains('manzana')) return '🍎';
    if (lower.contains('zanahoria')) return '🥕';
    if (lower.contains('patata')) return '🥔';
    if (lower.contains('limón') || lower.contains('limon')) return '🍋';
    if (lower.contains('ajo')) return '🧄';
    if (lower.contains('pan')) return '🥖';
    if (lower.contains('arroz')) return '🍚';
    return '🍽️';
  }

  @override
  Widget build(BuildContext context) {
    final fridgeItems = ref.watch(fridgeProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Mi Nevera', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: fridgeItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, spreadRadius: 5)
                      ],
                    ),
                    child: const Text('🧊', style: TextStyle(fontSize: 64)),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Tu nevera está vacía',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '¡Añade ingredientes para empezar\na crear recetas mágicas!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.5),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: fridgeItems.length,
              itemBuilder: (context, index) {
                final item = fridgeItems[index];
                bool isExpiringSoon = false;
                bool isExpired = false;
                if (item.expirationDate != null) {
                  final daysLeft = item.expirationDate!.difference(DateTime.now()).inDays;
                  isExpired = daysLeft < 0;
                  isExpiringSoon = daysLeft >= 0 && daysLeft <= 2;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isExpired 
                            ? Colors.red.withValues(alpha: 0.1) 
                            : (isExpiringSoon ? Colors.orange.withValues(alpha: 0.1) : const Color(0xFFF0F4FF)),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Center(
                        child: Text(
                          _getEmojiForIngredient(item.name),
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    title: Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        if (item.quantity != null) 
                          Text('Cantidad: ${item.quantity}', style: const TextStyle(color: Colors.black54)),
                        if (item.expirationDate != null) 
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today, 
                                size: 14, 
                                color: isExpired ? Colors.red : (isExpiringSoon ? Colors.orange : Colors.grey)
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isExpired ? 'Caducado' : 'Caduca: ${DateFormat('dd/MM/yyyy').format(item.expirationDate!)}',
                                style: TextStyle(
                                  color: isExpired ? Colors.red : (isExpiringSoon ? Colors.orange : Colors.grey),
                                  fontWeight: (isExpiringSoon || isExpired) ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () {
                        ref.read(fridgeProvider.notifier).removeItem(item.id);
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (fridgeItems.isNotEmpty)
            FloatingActionButton.extended(
              heroTag: 'generateRecipe',
              onPressed: _isGenerating ? null : () async {
                try {
                  setState(() => _isGenerating = true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Generando receta con IA... ✨')),
                  );
                  
                  final aiService = ref.read(geminiServiceProvider);
                  final ingredientsList = fridgeItems.map((e) => e.name).toList();
                  
                  final recipe = await aiService.generateRecipeFromIngredients(ingredientsList);
                  
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RecipeDetailPage(recipe: recipe, isPreview: true)),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() => _isGenerating = false);
                  }
                }
              },
              elevation: 4,
              icon: _isGenerating 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome, color: Colors.white),
              label: Text(
                _isGenerating ? 'Creando...' : 'Crear Receta Mágica',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: const Color(0xFF6B4EFF), // Un morado premium para la IA
            ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'addIngredient',
            onPressed: _showAddOptionsSheet,
            backgroundColor: Colors.white,
            elevation: 4,
            child: Icon(
              _isListening ? Icons.mic : Icons.add,
              color: const Color(0xFF6B4EFF),
            ),
          ),
        ],
      ),
    );
  }
}
