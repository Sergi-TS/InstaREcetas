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
        createdAt: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Error parseando JSON: $e\nTexto recibido: $cleanedJson');
    }
  }
}
