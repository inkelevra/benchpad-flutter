import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../theme/neumorphic_theme.dart';

/// A neumorphic 3-way slider switch: an inset ("pressed") track holding
/// N icons, with a raised thumb that animates to sit behind whichever
/// one is selected — like a physical slide switch with N stops, rather
/// than N separate buttons fused into one row.
///
/// By default sizes each cell to [cellSize]. Pass [expand]: true to
/// instead fill whatever width the parent gives it (e.g. inside an
/// Expanded), splitting that width evenly across the cells — used to
/// make this match the width/height of a sibling element for a
/// symmetric layout.
class NeumorphicSlideSwitch<T> extends StatelessWidget {
  final List<T> values;
  final List<IconData> icons;
  final T value;
  final ValueChanged<T> onChanged;
  final double cellSize;
  final double height;
  final bool expand;

  const NeumorphicSlideSwitch({
    super.key,
    required this.values,
    required this.icons,
    required this.value,
    required this.onChanged,
    this.cellSize = 38,
    this.height = 38,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final selectedIndex = values.indexOf(value).clamp(0, values.length - 1);

    Widget track(double cellWidth) {
      return SizedBox(
        width: cellWidth * values.length,
        height: height,
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              left: selectedIndex * cellWidth,
              top: 0,
              child: Container(
                width: cellWidth,
                height: height,
                decoration: BoxDecoration(
                  color: NeumorphicPalette.background,
                  borderRadius: BorderRadius.circular(height / 2.6),
                  boxShadow: [
                    BoxShadow(color: NeumorphicPalette.shadowDark, offset: const Offset(2, 2), blurRadius: 5),
                    BoxShadow(color: NeumorphicPalette.shadowLight, offset: const Offset(-2, -2), blurRadius: 5),
                  ],
                ),
              ),
            ),
            Row(
              children: List.generate(values.length, (i) {
                final selected = i == selectedIndex;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.vibrate();
                    onChanged(values[i]);
                  },
                  child: SizedBox(
                    width: cellWidth,
                    height: height,
                    child: Icon(icons[i], size: 16, color: selected ? NeumorphicPalette.accent : NeumorphicPalette.textSecondary),
                  ),
                );
              }),
            ),
          ],
        ),
      );
    }

    return NeumorphicBox(
      pressed: true,
      borderRadius: (height + 6) / 2,
      padding: const EdgeInsets.all(3),
      child: expand
          ? LayoutBuilder(builder: (context, constraints) => track(constraints.maxWidth / values.length))
          : track(cellSize),
    );
  }
}
