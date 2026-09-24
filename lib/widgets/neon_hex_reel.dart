import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Visual status of one hex cell — mirrors the capsule lifecycle used
/// by Time Capsule 1 and 2 (Vault/Memory), so all three Time Capsules
/// share one reservation model: empty (open to anyone) -> locked
/// (reserved, still editable) -> sealed (locked in, awaiting its
/// publish date) -> open (published).
enum HexCellStatus { empty, locked, sealed, open }

class HexCellData {
  final String id;
  final String label; // short text/number shown inside the cell
  final HexCellStatus status;
  final int number; // 1-based capsule number
  final String ownerName;
  final String ownerCountry;
  final String message;
  final String openingDate;
  final String visibility;

  const HexCellData({
    required this.id,
    required this.label,
    required this.status,
    this.number = 0,
    this.ownerName = '',
    this.ownerCountry = '',
    this.message = '',
    this.openingDate = '',
    this.visibility = 'Private',
  });
}

/// Flat-top hexagon grid math laid onto a cylinder: [cylinderRadius] (in
/// pixels) is the radius of the circular wall the cells sit on. Each
/// column maps to an angle around that circle instead of a straight x
/// offset — the same idea as the spheres' rotation, just curving around
/// one axis instead of two. Columns near the center of the view face
/// the camera (full size, bright); toward the edges they curve away,
/// shrink, and dim — the visual cue that this is a wall going around a
/// circle, not a flat strip. [rows] is however many rows the caller
/// decided fit the available height.
class HexReelGeometry {
  final double size;
  final int rows;
  final double cylinderRadius;
  const HexReelGeometry(this.size, this.rows, this.cylinderRadius);

  double get colSpacing => size * 1.5;
  double get rowSpacing => size * math.sqrt(3);

  // Columns curving past this angle (radians, ~89°) are edge-on to the
  // camera or behind it — not drawn.
  static const maxAngle = 1.55;

  double angleFor(int col, double scrollX) => (col * colSpacing - scrollX) / cylinderRadius;

  int firstColFor(double scrollX) => ((scrollX - maxAngle * cylinderRadius) / colSpacing).floor() - 1;
  int lastColFor(double scrollX) => ((scrollX + maxAngle * cylinderRadius) / colSpacing).ceil() + 1;

  /// Projects tile (col,row) onto the screen. Returns null once the
  /// column has curved past the visible edge of the wall.
  HexProjection? project(int col, int row, Offset center, double scrollX) {
    final angle = angleFor(col, scrollX);
    if (angle.abs() > maxAngle) return null;
    final zUnit = math.cos(angle); // 1 = facing the viewer, 0 = edge-on
    final xUnit = math.sin(angle);
    final depth = zUnit.clamp(0.0, 1.0);
    // The viewer sits at the center of the circular wall, so every tile
    // is the same true distance away — nothing should shrink overall
    // purely from depth (that uniform shrink is what read as a convex
    // surface bulging toward the viewer). Tiles foreshorten
    // horizontally toward the rim at the same rate columns bunch
    // together on screen (cos(angle), i.e. `depth`) — that also
    // prevents neighboring tiles from overlapping near the rim.
    //
    // (A local dip right at dead-center was tried here and reverted —
    // it made the wall look worse, not better.)
    final widthScale = depth;
    final x = center.dx + xUnit * cylinderRadius;
    final yOffset = col.isOdd ? rowSpacing / 2 : 0.0;
    // Odd columns are shifted down by half a row for the honeycomb
    // stagger, but that shift isn't part of the centering math below —
    // so the grid's true visual center sits about a quarter-row below
    // the container's actual center (slack at the top, clipping at the
    // bottom). Pull everything up by that amount to recenter it. No
    // depth scaling here — row height doesn't foreshorten with a
    // horizontal rotation, only width does.
    final yLocal = (row - (rows - 1) / 2) * rowSpacing + yOffset - rowSpacing / 4;
    return HexProjection(pos: Offset(x, center.dy + yLocal), depth: depth, widthScale: widthScale);
  }

  Path hexPath(Offset c) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = math.pi / 180 * (60 * i);
      final p = Offset(c.dx + size * math.cos(angle), c.dy + size * math.sin(angle));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }
}

class HexProjection {
  final Offset pos;
  final double depth; // 0..1, 1 = directly facing the viewer
  final double widthScale; // horizontal-only foreshortening, 0..1
  const HexProjection({required this.pos, required this.depth, required this.widthScale});
}

/// Maps a (column, row) grid coordinate to a cyclic index into a finite
/// [cells] list — the same "endless, wraps around" trick used by the
/// spheres, just laid out as a straight reel instead of a globe.
int hexCellIndexAt(int col, int row, int rows, int total) {
  final logical = col * rows + row;
  return ((logical % total) + total) % total;
}

const hexEmptyColor = Color(0xFF75E7FF);
const hexLockedColor = Color(0xFFFFD84D);
const hexSealedColor = Color(0xFFFF4D68);
const hexOpenColor = Color(0xFF4ADE80);

Color hexStatusColor(HexCellStatus status) => switch (status) {
      HexCellStatus.empty => hexEmptyColor,
      HexCellStatus.locked => hexLockedColor,
      HexCellStatus.sealed => hexSealedColor,
      HexCellStatus.open => hexOpenColor,
    };

const hexGapFactor = 0.86; // <1.0 shrinks the drawn hex toward its own
// center, leaving a visible gap between neighbors (same trick used on
// the spheres) — grid spacing itself is untouched, only the drawn
// polygon shrinks. This also fixes selection highlights only showing on
// 3 of 6 sides: with edge-to-edge hexes, a later-drawn neighbor painted
// right over the shared edge was hiding half of the selected hex's
// outline.
Path hexPathAt(Offset c, double size) {
  final path = Path();
  for (int i = 0; i < 6; i++) {
    final angle = math.pi / 180 * (60 * i);
    final p = Offset(c.dx + size * math.cos(angle), c.dy + size * math.sin(angle));
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  path.close();
  return path;
}

/// Same hexagon, but foreshortened horizontally only — [widthScale]
/// squashes the x-extent while the y-extent stays at [size]. This is
/// what a tile on a cylinder wall the viewer sits inside actually looks
/// like as it curves away: it narrows, it doesn't shrink overall.
Path hexPathAtAniso(Offset c, double size, double widthScale) {
  final path = Path();
  for (int i = 0; i < 6; i++) {
    final angle = math.pi / 180 * (60 * i);
    final p = Offset(c.dx + size * widthScale * math.cos(angle), c.dy + size * math.sin(angle));
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  path.close();
  return path;
}

/// Paints the honeycomb for the current [scrollX] offset. No
/// MaskFilter.blur anywhere (that was the source of real stutter when
/// first tried on the spheres) — the glow is faked with a wider,
/// more-transparent solid stroke under a crisp one, which is cheap.
class HexReelPainter extends CustomPainter {
  final List<HexCellData> cells;
  final double scrollX;
  final double hexSize;
  final int rows;
  final double cylinderRadius;
  final String? selectedId;
  final HexCellStatus? filterStatus; // null = show all statuses at full brightness

  HexReelPainter({
    required this.cells,
    required this.scrollX,
    required this.hexSize,
    required this.rows,
    required this.cylinderRadius,
    this.selectedId,
    this.filterStatus,
  });

  static final Map<String, TextPainter> _labelCache = {};
  static TextPainter _labelPainter(String label) {
    return _labelCache.putIfAbsent(label, () {
      final tp = TextPainter(
        text: TextSpan(text: label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      return tp;
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (cells.isEmpty || rows <= 0) return;
    final geo = HexReelGeometry(hexSize, rows, cylinderRadius);
    final center = Offset(size.width / 2, size.height / 2);

    final firstCol = geo.firstColFor(scrollX);
    final lastCol = geo.lastColFor(scrollX);

    for (int col = firstCol; col <= lastCol; col++) {
      for (int row = 0; row < rows; row++) {
        final proj = geo.project(col, row, center, scrollX);
        if (proj == null) continue;

        final cell = cells[hexCellIndexAt(col, row, rows, cells.length)];
        final path = hexPathAtAniso(proj.pos, geo.size * hexGapFactor, proj.widthScale);
        final glow = hexStatusColor(cell.status);
        final isLocked = cell.status == HexCellStatus.locked;
        final isSelected = selectedId != null && selectedId == cell.id;
        final d = proj.depth;
        // Stroke width follows depth, not the horizontal squash — a
        // foreshortened tile's outline is still drawn at full weight
        // along its (unsquashed) height, so a strong width-only taper
        // here would look wrong. Kept a mild depth-based falloff with a
        // floor so far tiles don't vanish to hairlines.
        final strokeScale = 0.5 + 0.5 * d;
        // Filtering here dims non-matching tiles in place rather than
        // removing them from the honeycomb — pulling matched cells out
        // of the list would reflow every cell into new grid positions,
        // breaking the "these are fixed numbered cells" mental model
        // this grid (unlike the point-cloud spheres) actually depends
        // on.
        final dim = (filterStatus == null || cell.status == filterStatus) ? 1.0 : 0.12;

        canvas.drawPath(path, Paint()..color = glow.withOpacity((isLocked ? 0.08 : 0.12) * (0.75 + 0.25 * d) * dim)..style = PaintingStyle.fill);
        canvas.drawPath(
          path,
          Paint()
            ..color = glow.withOpacity((isLocked ? 0.18 : 0.35) * (0.75 + 0.25 * d) * dim)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6 * strokeScale,
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = glow.withOpacity((isLocked ? 0.5 : 0.95) * (0.8 + 0.2 * d) * dim)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1 * strokeScale,
        );

        if (isSelected) {
          canvas.drawPath(path, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.2 * strokeScale);
        }

        if (proj.widthScale > 0.45 && dim > 0.5) {
          // Skip labels on tiles curved close to edge-on (they'd be
          // squashed illegible anyway) and on dimmed-out filtered
          // tiles (the label would just be visual noise there).
          final tp = _labelPainter(cell.label);
          canvas.save();
          canvas.translate(proj.pos.dx, proj.pos.dy);
          canvas.scale(proj.widthScale, 1.0);
          tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
          canvas.restore();
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant HexReelPainter oldDelegate) =>
      oldDelegate.scrollX != scrollX ||
      oldDelegate.rows != rows ||
      oldDelegate.cylinderRadius != cylinderRadius ||
      oldDelegate.selectedId != selectedId ||
      oldDelegate.filterStatus != filterStatus ||
      oldDelegate.cells.length != cells.length;
}
