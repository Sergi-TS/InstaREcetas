import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:recipecatcher/features/recipes/data/recipe_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});

class GeminiService {
  Future<Recipe> extractRecipeFromText(String text) async {
    String contentToAnalyze = text;
    String? sourceUrl;
    String? extractedImageUrl;

    // Verificar si el texto es una URL
    final urlRegex = RegExp(r'^(https?://[^\s]+)$');
    if (urlRegex.hasMatch(text.trim())) {
      sourceUrl = text.trim();
      try {
        final response = await http.get(Uri.parse(sourceUrl));
        if (response.statusCode == 200) {
          final html = response.body;

          // Intentar extraer imagen og:image (cubriendo varios órdenes de atributos)
          final ogImageMatch = RegExp(r'<meta[^>]+property=["'']og:image["''][^>]+content=["'']([^"'']+)["'']', caseSensitive: false).firstMatch(html) ??
                               RegExp(r'<meta[^>]+content=["'']([^"'']+)["''][^>]+property=["'']og:image["'']', caseSensitive: false).firstMatch(html);
          
          if (ogImageMatch != null) {
            extractedImageUrl = ogImageMatch.group(1);
          } else {
            // Fallback: coger la primera imagen normal que encontremos
            final imgMatch = RegExp(r'<img[^>]+src=["''](https?://[^"'']+)["'']', caseSensitive: false).firstMatch(html);
            if (imgMatch != null) {
              extractedImageUrl = imgMatch.group(1);
            }
          }
          
          // Asignar plainText antes de limpiar
          String plainText = html;

          // Eliminar scripts y estilos
          plainText = plainText.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), ' ');
          plainText = plainText.replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), ' ');
          // Eliminar todas las etiquetas HTML
          plainText = plainText.replaceAll(RegExp(r'<[^>]+>'), ' ');
          // Eliminar espacios extra
          plainText = plainText.replaceAll(RegExp(r'\s+'), ' ').trim();
          
          // Groq capa gratuita tiene un límite estricto de 7000 tokens por minuto.
          // 20000 caracteres son aprox 5000 tokens, más que suficiente para una receta entera.
          if (plainText.length > 20000) {
            plainText = plainText.substring(0, 20000);
          }
          
          contentToAnalyze = plainText;
        }
      } catch (e) {
        // Falló la llamada, continuamos
      }
    }

    final prompt = '''
Eres un asistente experto en extraer información estructurada de recetas de cocina a partir de texto o código HTML de páginas web.
Analiza el siguiente contenido y extrae la información en un formato JSON válido que represente una receta.
NO devuelvas nada más que el JSON válido. Sin markdown de bloques de código. SOLO EL TEXTO JSON.

Estructura JSON requerida:
{
  "title": "Nombre de la receta (si no hay, deduce uno)",
  "ingredients": ["ingrediente 1", "ingrediente 2"],
  "steps": ["paso 1", "paso 2"],
  "category": "Desayuno, Almuerzo, Cena, Postre, Snack o Bebida",
  "prepTime": "ej. 30 minutos (opcional)",
  "calories": "ej. 400 kcal (opcional)",
  "sourceUrl": "${sourceUrl ?? 'Si hay alguna URL en el texto original, ponla aquí, sino null'}"
}

Contenido a analizar:
$contentToAnalyze
''';

    final apiKey = dotenv.env['GROQ_API_KEY'] ?? dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API Key no encontrada en .env. Necesitas añadir GROQ_API_KEY.');
    }

    final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    final requestBody = jsonEncode({
      "model": "qwen/qwen3.8-27b",
      "messages": [
        {
          "role": "system",
          "content": "You are a helpful assistant designed to output JSON."
        },
        {
          "role": "user",
          "content": prompt
        }
      ],
      "temperature": 0.2,
      "response_format": {"type": "json_object"}
    });

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: requestBody,
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Error HTTP ${response.statusCode}: ${response.body}');
    }

    final jsonResponse = jsonDecode(response.body);
    final responseText = jsonResponse['choices']?[0]?['message']?['content'];

    if (responseText == null || responseText.isEmpty) {
      throw Exception('Respuesta vacía de Gemini: ${response.body}');
    }

    String cleanedJson = responseText.trim();
    if (cleanedJson.startsWith('```json')) cleanedJson = cleanedJson.substring(7);
    if (cleanedJson.startsWith('```')) cleanedJson = cleanedJson.substring(3);
    if (cleanedJson.endsWith('```')) cleanedJson = cleanedJson.substring(0, cleanedJson.length - 3);

    try {
      final Map<String, dynamic> jsonMap = jsonDecode(cleanedJson.trim());
      return Recipe(
        id: const Uuid().v4(),
        title: jsonMap['title'] ?? 'Receta sin título',
        ingredients: List<String>.from(jsonMap['ingredients'] ?? []),
        steps: List<String>.from(jsonMap['steps'] ?? []),
        category: jsonMap['category'] ?? 'Sin Categoría',
        sourceUrl: jsonMap['sourceUrl'] ?? sourceUrl,
        imageUrl: extractedImageUrl,
        prepTime: jsonMap['prepTime'],
        calories: jsonMap['calories'],
        createdAt: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Error parseando JSON: $e\nTexto recibido: $cleanedJson');
    }
  }

  Future<List<String>> extractIngredientsFromImage(String base64Image) async {
    final prompt = '''
Analiza esta imagen del interior de una nevera (o despensa) y lista todos los ingredientes y alimentos visibles.
NO devuelvas nada más que un JSON válido. Sin markdown de bloques de código. SOLO EL TEXTO JSON.

Estructura JSON requerida:
{
  "ingredients": ["ingrediente 1", "ingrediente 2", "ingrediente 3"]
}
''';

    final apiKey = dotenv.env['GROQ_API_KEY'] ?? dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API Key no encontrada.');
    }

    final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    final requestBody = jsonEncode({
      "model": "llama-3.2-11b-vision-preview",
      "messages": [
        {
          "role": "user",
          "content": [
            {
              "type": "text",
              "text": prompt
            },
            {
              "type": "image_url",
              "image_url": {
                "url": "data:image/jpeg;base64,$base64Image"
              }
            }
          ]
        }
      ],
      "temperature": 0.2,
      "response_format": {"type": "json_object"}
    });

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: requestBody,
    );

    if (response.statusCode != 200) {
      throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
    }

    final jsonResponse = jsonDecode(response.body);
    final responseText = jsonResponse['choices']?[0]?['message']?['content'];

    if (responseText == null || responseText.isEmpty) {
      throw Exception('Respuesta vacía de Groq: ${response.body}');
    }

    String cleanedJson = responseText.trim();
    if (cleanedJson.startsWith('```json')) cleanedJson = cleanedJson.substring(7);
    if (cleanedJson.startsWith('```')) cleanedJson = cleanedJson.substring(3);
    if (cleanedJson.endsWith('```')) cleanedJson = cleanedJson.substring(0, cleanedJson.length - 3);

    try {
      final Map<String, dynamic> jsonMap = jsonDecode(cleanedJson.trim());
      return List<String>.from(jsonMap['ingredients'] ?? []);
    } catch (e) {
      throw Exception('Error parseando JSON: $e\nTexto recibido: $cleanedJson');
    }
  }

  Future<List<Map<String, dynamic>>> extractIngredientsFromText(String spokenText) async {
    final prompt = '''
Extrae los ingredientes mencionados en el siguiente texto y devuélvelos en una lista.
Si el texto menciona una fecha de caducidad o similar asociada a un ingrediente, infiere la fecha correspondiente (hoy es ${DateTime.now().toIso8601String()}) y devuélvela en formato YYYY-MM-DD.
Si no se menciona fecha, deja el valor como null.
NO devuelvas nada más que un JSON válido. Sin markdown de bloques de código. SOLO EL TEXTO JSON.

Texto: "$spokenText"

Estructura JSON requerida:
{
  "ingredients": [
    {
      "name": "ingrediente 1",
      "expirationDate": "2026-10-05"
    },
    {
      "name": "ingrediente 2",
      "expirationDate": null
    }
  ]
}
''';

    final apiKey = dotenv.env['GROQ_API_KEY'] ?? dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API Key no encontrada.');
    }

    final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    final requestBody = jsonEncode({
      "model": "qwen/qwen3.8-27b",
      "messages": [
        {
          "role": "user",
          "content": prompt
        }
      ],
      "temperature": 0.2,
      "response_format": {"type": "json_object"}
    });

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: requestBody,
    );

    if (response.statusCode != 200) {
      throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
    }

    final jsonResponse = jsonDecode(response.body);
    final responseText = jsonResponse['choices']?[0]?['message']?['content'];

    if (responseText == null || responseText.isEmpty) {
      throw Exception('Respuesta vacía de Groq: ${response.body}');
    }

    String cleanedJson = responseText.trim();
    if (cleanedJson.startsWith('```json')) cleanedJson = cleanedJson.substring(7);
    if (cleanedJson.startsWith('```')) cleanedJson = cleanedJson.substring(3);
    if (cleanedJson.endsWith('```')) cleanedJson = cleanedJson.substring(0, cleanedJson.length - 3);

    try {
      final Map<String, dynamic> jsonMap = jsonDecode(cleanedJson.trim());
      final List<dynamic> ingredientsList = jsonMap['ingredients'] ?? [];
      return ingredientsList.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      throw Exception('Error parseando JSON: $e\nTexto recibido: $cleanedJson');
    }
  }

  Future<Recipe> generateRecipeFromIngredients(List<String> ingredients) async {
    final ingredientsList = ingredients.join(', ');
    final prompt = '''
Eres un chef creativo y experto en aprovechamiento alimentario (evitar el desperdicio).
Crea una receta deliciosa y original utilizando los siguientes ingredientes que tengo en la nevera: $ingredientsList.
Puedes asumir que el usuario tiene sal, pimienta, aceite, agua y especias básicas.
NO devuelvas nada más que un JSON válido. Sin markdown de bloques de código. SOLO EL TEXTO JSON.

Estructura JSON requerida:
{
  "title": "Nombre creativo de la receta",
  "ingredients": ["ingrediente 1 con cantidades aproximadas", "ingrediente 2"],
  "steps": ["paso 1", "paso 2 detallado"],
  "category": "Desayuno, Almuerzo, Cena, Postre, Snack o Bebida",
  "prepTime": "Tiempo de preparación estimado (ej. 40 minutos)",
  "calories": "Calorías aproximadas por ración (ej. 450 kcal)"
}
''';

    final apiKey = dotenv.env['GROQ_API_KEY'] ?? dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API Key no encontrada en .env. Necesitas añadir GROQ_API_KEY.');
    }

    final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    final requestBody = jsonEncode({
      "model": "qwen/qwen3.8-27b",
      "messages": [
        {
          "role": "system",
          "content": "You are a helpful assistant designed to output JSON."
        },
        {
          "role": "user",
          "content": prompt
        }
      ],
      "temperature": 0.7,
      "response_format": {"type": "json_object"}
    });

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: requestBody,
    );

    if (response.statusCode != 200) {
      throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
    }

    final jsonResponse = jsonDecode(response.body);
    final responseText = jsonResponse['choices']?[0]?['message']?['content'];

    if (responseText == null || responseText.isEmpty) {
      throw Exception('Respuesta vacía de Groq: ${response.body}');
    }

    String cleanedJson = responseText.trim();
    if (cleanedJson.startsWith('```json')) cleanedJson = cleanedJson.substring(7);
    if (cleanedJson.startsWith('```')) cleanedJson = cleanedJson.substring(3);
    if (cleanedJson.endsWith('```')) cleanedJson = cleanedJson.substring(0, cleanedJson.length - 3);

    try {
      final Map<String, dynamic> jsonMap = jsonDecode(cleanedJson.trim());
      return Recipe(
        id: const Uuid().v4(),
        title: jsonMap['title'] ?? 'Receta Generada',
        ingredients: List<String>.from(jsonMap['ingredients'] ?? []),
        steps: List<String>.from(jsonMap['steps'] ?? []),
        category: jsonMap['category'] ?? 'Plato Principal',
        prepTime: jsonMap['prepTime'],
        calories: jsonMap['calories'],
        createdAt: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Error parseando JSON: $e\nTexto recibido: $cleanedJson');
    }
  }
}
