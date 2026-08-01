import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/spatial_object.dart';

class ApiService {
  static const String baseUrl = 'http://10.45.183.144:4000';

  static Future<bool> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/health'));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Health check failed: $e');
      return false;
    }
  }

  static Future<List<SpatialObject>> fetchObjectsInViewport({
    required double minX,
    required double minY,
    required double maxX,
    required double maxY,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/objects?minX=$minX&minY=$minY&maxX=$maxX&maxY=$maxY',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch objects: ${response.statusCode}');
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    final List<dynamic> rawObjects = data['objects'];

    return rawObjects
        .map((json) => SpatialObject.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  static Future<SpatialObject> updateObjectPosition(
    String id,
    double x,
    double y,
  ) async {
    final uri = Uri.parse('$baseUrl/api/objects/$id');

    final response = await http.patch(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'x': x, 'y': y}),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed to update object');
    }

    final data = jsonDecode(response.body);
    return SpatialObject.fromJson(data['object']);
  }
}
