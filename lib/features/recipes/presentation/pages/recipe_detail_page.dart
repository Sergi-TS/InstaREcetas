import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recipecatcher/features/recipes/data/recipe_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:recipecatcher/core/theme/app_theme.dart';
import 'package:recipecatcher/features/recipes/data/recipe_repository.dart';
import 'package:recipecatcher/features/fridge/presentation/providers/fridge_provider.dart';

class RecipeDetailPage extends ConsumerWidget {
  final Recipe recipe;
  final bool isPreview;

  const RecipeDetailPage({super.key, required this.recipe, this.isPreview = false});

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $urlString');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isPreview ? 'Receta Sugerida' : 'Detalle de Receta'),
        actions: [
            IconButton(
              icon: const Icon(Icons.restaurant_menu, color: Colors.green),
              tooltip: '¡Cocinar esta receta!',
              onPressed: () {
                _showCookDialog(context, ref);
              },
            ),
          if (!isPreview)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: () async {
              // Confirmar antes de borrar
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Borrar receta'),
                  content: const Text('¿Estás seguro de que deseas borrar esta receta?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Borrar', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                final repository = ref.read(recipeRepositoryProvider);
                repository.deleteRecipe(recipe.id); // Sin await para que no se congele
                if (context.mounted) {
                  Navigator.pop(context); // Volver a la galería
                }
              }
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen de portada
            if (recipe.imageUrl != null)
              Container(
                width: double.infinity,
                height: 250,
                margin: const EdgeInsets.only(bottom: 24.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    image: NetworkImage(recipe.imageUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            // Título
            Text(
              recipe.title,
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 8),
            
            // Categoría, Tiempo y Calorías
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    recipe.category,
                    style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                  ),
                ),
                if (recipe.prepTime != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer, size: 16, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(recipe.prepTime!, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                if (recipe.calories != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department, size: 16, color: Colors.red),
                        const SizedBox(width: 4),
                        Text(recipe.calories!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Ingredientes
            const Text(
              'Ingredientes',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...recipe.ingredients.map((ingredient) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.circle, size: 8, color: AppTheme.primaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      ingredient,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 24),

            // Pasos
            const Text(
              'Preparación',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...recipe.steps.asMap().entries.map((entry) {
              int index = entry.key;
              String step = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppTheme.primaryColor,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        step,
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 32),
            
            // Origen / URL
            if (recipe.sourceUrl != null && recipe.sourceUrl!.isNotEmpty)
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.link),
                  label: const Text('Ver Origen Original'),
                  onPressed: () => _launchUrl(recipe.sourceUrl!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor),
                  ),
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      floatingActionButton: isPreview ? FloatingActionButton.extended(
        onPressed: () async {
          try {
            final repository = ref.read(recipeRepositoryProvider);
            await repository.saveRecipe(recipe);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('¡Receta guardada!')),
              );
              Navigator.pop(context); // Vuelve a la nevera
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
              );
            }
          }
        },
        icon: const Icon(Icons.save),
        label: const Text('Guardar Receta'),
      ) : null,
    );
  }

  void _showCookDialog(BuildContext context, WidgetRef ref) {
    final fridgeItems = ref.read(fridgeProvider);
    if (fridgeItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu nevera está vacía.')),
      );
      return;
    }

    final selectedIds = <String>{};

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('¿Qué ingredientes usaste?'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: fridgeItems.length,
                  itemBuilder: (context, index) {
                    final item = fridgeItems[index];
                    final isSelected = selectedIds.contains(item.id);
                    return CheckboxListTile(
                      title: Text(item.name),
                      subtitle: item.quantity != null ? Text(item.quantity!) : null,
                      value: isSelected,
                      onChanged: (bool? val) {
                        setState(() {
                          if (val == true) {
                            selectedIds.add(item.id);
                          } else {
                            selectedIds.remove(item.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    for (final id in selectedIds) {
                      ref.read(fridgeProvider.notifier).removeItem(id);
                    }
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Se descontaron ${selectedIds.length} ingredientes de tu nevera.')),
                    );
                  },
                  child: const Text('Descontar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
