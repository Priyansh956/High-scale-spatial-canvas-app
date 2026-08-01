import 'package:flutter/material.dart';

class QuadPoint<T> {
  final Offset position;
  final T data;
  QuadPoint(this.position, this.data);
}

class QuadTree<T> {
  final Rect boundary;
  final int capacity;
  final List<QuadPoint<T>> _points = [];
  bool _divided = false;

  QuadTree<T>? _topLeft;
  QuadTree<T>? _topRight;
  QuadTree<T>? _bottomLeft;
  QuadTree<T>? _bottomRight;

  QuadTree(this.boundary, {this.capacity = 8});

  bool insert(QuadPoint<T> point) {
    if (!boundary.contains(point.position)) return false;

    if (_points.length < capacity && !_divided) {
      _points.add(point);
      return true;
    }

    if (!_divided) _subdivide();

    return _topLeft!.insert(point) ||
        _topRight!.insert(point) ||
        _bottomLeft!.insert(point) ||
        _bottomRight!.insert(point);
  }

  void _subdivide() {
    final cx = boundary.center.dx;
    final cy = boundary.center.dy;

    _topLeft = QuadTree<T>(
      Rect.fromLTRB(boundary.left, boundary.top, cx, cy),
      capacity: capacity,
    );
    _topRight = QuadTree<T>(
      Rect.fromLTRB(cx, boundary.top, boundary.right, cy),
      capacity: capacity,
    );
    _bottomLeft = QuadTree<T>(
      Rect.fromLTRB(boundary.left, cy, cx, boundary.bottom),
      capacity: capacity,
    );
    _bottomRight = QuadTree<T>(
      Rect.fromLTRB(cx, cy, boundary.right, boundary.bottom),
      capacity: capacity,
    );

    // Re-insert points already stored at this node into the new children,
    // since a node can't hold points once it becomes an internal node.
    for (final p in _points) {
      _topLeft!.insert(p) ||
          _topRight!.insert(p) ||
          _bottomLeft!.insert(p) ||
          _bottomRight!.insert(p);
    }
    _points.clear();
    _divided = true;
  }

  /// Returns all points whose position falls inside [range].
  List<QuadPoint<T>> queryRange(Rect range) {
    final found = <QuadPoint<T>>[];
    if (!boundary.overlaps(range)) return found;

    for (final p in _points) {
      if (range.contains(p.position)) found.add(p);
    }

    if (_divided) {
      found.addAll(_topLeft!.queryRange(range));
      found.addAll(_topRight!.queryRange(range));
      found.addAll(_bottomLeft!.queryRange(range));
      found.addAll(_bottomRight!.queryRange(range));
    }

    return found;
  }

  /// Finds the single closest point to [target] within [maxDistance],
  /// or null if nothing is close enough.
  /// Kept for reference/backwards compatibility — prefer [hitTest] for
  /// tap-to-select, since this method ignores each object's own visual size.
  QuadPoint<T>? findNearest(Offset target, double maxDistance) {
    final searchArea = Rect.fromCircle(center: target, radius: maxDistance);
    final candidates = queryRange(searchArea);
    if (candidates.isEmpty) return null;

    QuadPoint<T>? closest;
    double closestDist = double.infinity;
    for (final c in candidates) {
      final dist = (c.position - target).distance;
      if (dist < closestDist && dist <= maxDistance) {
        closest = c;
        closestDist = dist;
      }
    }
    return closest;
  }

  /// Finds the best hit-test match for [target], where each candidate's own
  /// [getRadius] determines whether the tap actually landed on it — not a
  /// single global tolerance. [extraBufferWorld] is added on top of each
  /// object's own radius as a small forgiveness margin (world units).
  /// Prefers a direct hit (tap landed inside the shape) over a near-miss,
  /// even if the near-miss candidate's center happens to be numerically
  /// closer to the tap point — this matches what a person visually expects.
  QuadPoint<T>? hitTest(
    Offset target,
    double Function(T data) getRadius,
    double extraBufferWorld,
  ) {
    // Search radius needs to be generous enough to catch any candidate
    // whose own radius could plausibly reach the tap point.
    const maxPossibleObjectRadius = 50.0; // generous upper bound for seeded object sizes
    final searchRadius = maxPossibleObjectRadius + extraBufferWorld;
    final candidates = queryRange(Rect.fromCircle(center: target, radius: searchRadius));
    if (candidates.isEmpty) return null;

    QuadPoint<T>? bestDirectHit;
    double bestDirectHitDist = double.infinity;

    QuadPoint<T>? bestNearMiss;
    double bestNearMissDist = double.infinity;

    for (final c in candidates) {
      final dist = (c.position - target).distance;
      final radius = getRadius(c.data);

      if (dist <= radius) {
        if (dist < bestDirectHitDist) {
          bestDirectHit = c;
          bestDirectHitDist = dist;
        }
      } else if (dist <= radius + extraBufferWorld) {
        if (dist < bestNearMissDist) {
          bestNearMiss = c;
          bestNearMissDist = dist;
        }
      }
    }

    return bestDirectHit ?? bestNearMiss;
  }

  /// Debug helper — total points stored in this node and all children.
  int count() {
    int total = _points.length;
    if (_divided) {
      total += _topLeft!.count() +
          _topRight!.count() +
          _bottomLeft!.count() +
          _bottomRight!.count();
    }
    return total;
  }
}