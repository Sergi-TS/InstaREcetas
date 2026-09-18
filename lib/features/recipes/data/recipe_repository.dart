import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'recipe_model.dart';

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return RecipeRepository(FirebaseFirestore.instance);
});

class RecipeRepository {
  final FirebaseFirestore _firestore;

  RecipeRepository(this._firestore);

  CollectionReference get _recipesCollection => 
    _firestore.collection('recipes');

  // Obtener todas las recetas (Stream para actualizaciones en tiempo real)
  Stream<List<Recipe>> getRecipes() {
    return _recipesCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Recipe.fromFirestore(doc))
          .toList();
    });
  }

  // Guardar una nueva receta
  Future<void> saveRecipe(Recipe recipe) async {
    // Si la receta tiene un ID, usamos set() con merge
    await _recipesCollection
        .doc(recipe.id)
        .set(recipe.toFirestore(), SetOptions(merge: true));
  }

  // Eliminar una receta
  Future<void> deleteRecipe(String recipeId) async {
    await _recipesCollection.doc(recipeId).delete();
  }
}
