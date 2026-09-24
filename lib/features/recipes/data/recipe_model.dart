import 'package:cloud_firestore/cloud_firestore.dart';

class Recipe {
  final String id;
  final String title;
  final List<String> ingredients;
  final List<String> steps;
  final String category;
  final String? sourceUrl;
  final String? imageUrl;
  final String? prepTime;
  final String? calories;
  final DateTime createdAt;

  Recipe({
    required this.id,
    required this.title,
    required this.ingredients,
    required this.steps,
    required this.category,
    this.sourceUrl,
    this.imageUrl,
    this.prepTime,
    this.calories,
    required this.createdAt,
  });

  factory Recipe.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Recipe(
      id: doc.id,
      title: data['title'] ?? '',
      ingredients: List<String>.from(data['ingredients'] ?? []),
      steps: List<String>.from(data['steps'] ?? []),
      category: data['category'] ?? 'Sin Categoría',
      sourceUrl: data['sourceUrl'],
      imageUrl: data['imageUrl'],
      prepTime: data['prepTime'],
      calories: data['calories'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'ingredients': ingredients,
      'steps': steps,
      'category': category,
      'sourceUrl': sourceUrl,
      'imageUrl': imageUrl,
      'prepTime': prepTime,
      'calories': calories,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
