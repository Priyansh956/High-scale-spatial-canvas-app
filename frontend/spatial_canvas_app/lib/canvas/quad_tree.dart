// import 'dart:math';
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

  QuadTree? _topLeft;
  QuadTree? _topRight;
  QuadTree? _bottomLeft;
  QuadTree? _bottomRight;

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
      found.addAll(_topLeft!.queryRange(range) as Iterable<QuadPoint<T>>);
      found.addAll(_topRight!.queryRange(range) as Iterable<QuadPoint<T>>);
      found.addAll(_bottomLeft!.queryRange(range) as Iterable<QuadPoint<T>>);
      found.addAll(_bottomRight!.queryRange(range) as Iterable<QuadPoint<T>>);
    }

    return found;
  }

  /// Finds the single closest point to [target] within [maxDistance],
  /// or null if nothing is close enough. Used for tap-to-select.
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
}