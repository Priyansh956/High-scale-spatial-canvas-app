class ClusterPoint {
  final double x;
  final double y;
  final int count;

  ClusterPoint({required this.x, required this.y, required this.count});

  factory ClusterPoint.fromJson(Map<String, dynamic> json) {
    return ClusterPoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      count: json['count'] as int,
    );
  }
}