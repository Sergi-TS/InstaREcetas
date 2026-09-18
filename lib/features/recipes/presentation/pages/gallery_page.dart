import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recipecatcher/features/recipes/presentation/providers/recipe_providers.dart';
import 'package:recipecatcher/features/recipes/data/recipe_model.dart';
import 'package:recipecatcher/features/recipes/presentation/pages/recipe_detail_page.dart';
import 'package:recipecatcher/features/import_recipe/presentation/pages/import_recipe_page.dart';
import 'package:recipecatcher/core/theme/app_theme.dart';

class GalleryPage extends ConsumerWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredRecipes = ref.watch(filteredRecipesProvider);
    final recipesAsync = ref.watch(recipesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('RecipeCatcher'),
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) => ref.read(searchQueryProvider.notifier).updateQuery(value),
              decoration: const InputDecoration(
                hintText: 'Buscar por título o categoría...',
                prefixIcon: Icon(Icons.search, color: AppTheme.primaryColor),
              ),
            ),
          ),
          
          // Lista/Grid de recetas
          Expanded(
            child: recipesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Text('Error al cargar recetas: $error'),
              ),
              data: (_) {
                if (filteredRecipes.isEmpty) {
                  return const Center(
                    child: Text('No se encontraron recetas.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredRecipes.length,
                  itemBuilder: (context, index) {
                    final recipe = filteredRecipes[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: _RecipeCard(recipe: recipe),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ImportRecipePage()),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;

  const _RecipeCard({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecipeDetailPage(recipe: recipe),
          ),
        );
      },
      child: Card(
        child: SizedBox(
          height: 100, // Altura fija muy compacta
          child: Row(
            children: [
              // Imagen a la izquierda
              Container(
                width: 100,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  image: recipe.imageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(recipe.imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: recipe.imageUrl == null
                    ? const Icon(
                        Icons.restaurant_menu,
                        size: 32,
                        color: AppTheme.primaryColor,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              // Textos a la derecha
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        recipe.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        recipe.category,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
