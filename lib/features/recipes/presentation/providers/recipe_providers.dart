import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recipecatcher/features/recipes/data/recipe_repository.dart';
import 'package:recipecatcher/features/recipes/data/recipe_model.dart';

final recipesStreamProvider = StreamProvider<List<Recipe>>((ref) {
  final repository = ref.watch(recipeRepositoryProvider);
  return repository.getRecipes();
});

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void updateQuery(String query) {
    state = query;
  }
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(() {
  return SearchQueryNotifier();
});

final filteredRecipesProvider = Provider<List<Recipe>>((ref) {
  final recipes = ref.watch(recipesStreamProvider).value ?? [];
  final searchQuery = ref.watch(searchQueryProvider).toLowerCase();

  if (searchQuery.isEmpty) {
    return recipes;
  }

  return recipes.where((recipe) {
    return recipe.title.toLowerCase().contains(searchQuery) ||
           recipe.category.toLowerCase().contains(searchQuery);
  }).toList();
});
