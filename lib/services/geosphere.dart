import 'dart:math' as math;

/// A point in 3D space on (or near) the unit sphere.
class Vec3 {
  final double x, y, z;
  const Vec3(this.x, this.y, this.z);

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);

  double get length => math.sqrt(x * x + y * y + z * z);

  Vec3 get normalized {
    final l = length;
    return l == 0 ? this : Vec3(x / l, y / l, z / l);
  }

  /// Rounds to a fixed precision — used as a dictionary key so two
  /// vertices produced by subdividing adjacent icosahedron faces (and
  /// landing on the same point in space) are recognized as the same
  /// vertex instead of duplicated.
  String get key => '${(x * 1e6).round()},${(y * 1e6).round()},${(z * 1e6).round()}';
}

/// One tile of the finished geosphere — a hexagon (6 corners) or, at
/// exactly 12 of the tiles (the original icosahedron vertices),
/// a pentagon (5 corners). [center] is the tile's own point on the
/// sphere (what a capsule "sits at"); [corners] are the polygon
/// boundary to actually draw, in order around the tile.
class GeoTile {
  final int index;
  final Vec3 center;
  final List<Vec3> corners;
  const GeoTile({required this.index, required this.center, required this.corners});
}

/// Builds a geosphere by subdividing a regular icosahedron [subdivisions]
/// times and taking the dual mesh (Goldberg polyhedron) — the same
/// construction hexasphere.js uses. Vertex count (= tile count) follows
/// 10*n*n + 2 for subdivision level n: 12, 42, 92, 162, 252, 362, 492, 642...
class Geosphere {
  static List<GeoTile>? _cache;
  static int? _cachedSubdivisions;

  static List<GeoTile> build({required int subdivisions}) {
    if (_cache != null && _cachedSubdivisions == subdivisions) return _cache!;

    final t = (1.0 + math.sqrt(5.0)) / 2.0;
    final rawVerts = <Vec3>[
      Vec3(-1, t, 0), Vec3(1, t, 0), Vec3(-1, -t, 0), Vec3(1, -t, 0),
      Vec3(0, -1, t), Vec3(0, 1, t), Vec3(0, -1, -t), Vec3(0, 1, -t),
      Vec3(t, 0, -1), Vec3(t, 0, 1), Vec3(-t, 0, -1), Vec3(-t, 0, 1),
    ].map((v) => v.normalized).toList();

    const rawFaces = [
      [0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
      [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
      [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
      [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
    ];

    // Subdivide every icosahedron face into subdivisions^2 small
    // triangles, deduplicating shared vertices via a rounded-position key.
    final vertexByKey = <String, int>{};
    final vertices = <Vec3>[];
    final triangles = <List<int>>[]; // each: 3 vertex indices

    int vertexIndex(Vec3 v) {
      final nv = v.normalized;
      final k = nv.key;
      final existing = vertexByKey[k];
      if (existing != null) return existing;
      vertices.add(nv);
      vertexByKey[k] = vertices.length - 1;
      return vertices.length - 1;
    }

    for (final face in rawFaces) {
      final a = rawVerts[face[0]], b = rawVerts[face[1]], c = rawVerts[face[2]];
      final n = subdivisions;
      // Grid of points across the triangle via barycentric interpolation.
      final grid = <List<int>>[];
      for (int i = 0; i <= n; i++) {
        final row = <int>[];
        final ab = a + (b - a) * (i / n);
        final ac = a + (c - a) * (i / n);
        for (int j = 0; j <= i; j++) {
          final p = i == 0 ? a : ab + (ac - ab) * (j / i);
          row.add(vertexIndex(p));
        }
        grid.add(row);
      }
      for (int i = 0; i < n; i++) {
        for (int j = 0; j < i + 1; j++) {
          triangles.add([grid[i][j], grid[i + 1][j], grid[i + 1][j + 1]]);
          if (j < i) triangles.add([grid[i][j], grid[i + 1][j + 1], grid[i][j + 1]]);
        }
      }
    }

    // Dual mesh: for every vertex, find the triangles touching it, walk
    // them in order around the vertex (each pair of consecutive
    // triangles shares an edge), and connect their centroids — that
    // ordered ring of centroids is the tile boundary.
    final trianglesByVertex = List.generate(vertices.length, (_) => <int>[]);
    for (int ti = 0; ti < triangles.length; ti++) {
      for (final vi in triangles[ti]) trianglesByVertex[vi].add(ti);
    }

    final tiles = <GeoTile>[];
    for (int vi = 0; vi < vertices.length; vi++) {
      final touching = trianglesByVertex[vi];
      final ordered = _orderTrianglesAroundVertex(vi, touching, triangles);
      final corners = ordered.map((ti) {
        final tri = triangles[ti];
        final centroid = (vertices[tri[0]] + vertices[tri[1]] + vertices[tri[2]]) * (1 / 3);
        return centroid.normalized;
      }).toList();
      tiles.add(GeoTile(index: vi, center: vertices[vi], corners: corners));
    }

    _cache = tiles;
    _cachedSubdivisions = subdivisions;
    return tiles;
  }

  /// Walks the triangles touching [vertex] in order (each consecutive
  /// pair shares an edge that includes [vertex]) so the resulting
  /// centroids trace the tile boundary correctly instead of in
  /// arbitrary/crossing order.
  static List<int> _orderTrianglesAroundVertex(int vertex, List<int> touching, List<List<int>> triangles) {
    if (touching.isEmpty) return touching;
    final remaining = List<int>.from(touching);
    final ordered = <int>[remaining.removeAt(0)];

    Set<int> otherVerts(int triIndex) => triangles[triIndex].where((v) => v != vertex).toSet();

    while (remaining.isNotEmpty) {
      final lastOthers = otherVerts(ordered.last);
      int? nextIdx;
      for (int i = 0; i < remaining.length; i++) {
        final candidateOthers = otherVerts(remaining[i]);
        if (candidateOthers.intersection(lastOthers).isNotEmpty) {
          nextIdx = i;
          break;
        }
      }
      if (nextIdx == null) break; // shouldn't happen on a closed mesh
      ordered.add(remaining.removeAt(nextIdx));
    }
    return ordered;
  }
}
