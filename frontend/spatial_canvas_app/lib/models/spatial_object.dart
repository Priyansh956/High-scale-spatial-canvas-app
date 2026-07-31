class SpatialObject {
  final String id;
  double x;
  double y;
  final String color;
  final String shape;
  final double size;

  SpatialObject({
    required this.id,
    required this.x,
    required this.y,
    required this.color,
    required this.shape,
    required this.size,
  });

  factory SpatialObject.fromJson(Map<String, dynamic> json) {
    final loc = json['loc'] as List<dynamic>;
    return SpatialObject(
      id: json['_id'] as String,
      x: (loc[0] as num).toDouble(),
      y: (loc[1] as num).toDouble(),
      color: json['color'] as String? ?? '#3498db',
      shape: json['shape'] as String? ?? 'circle',
      size: (json['size'] as num?)?.toDouble() ?? 8.0,
    );
  }
}