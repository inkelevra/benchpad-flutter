import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../theme/neumorphic_theme.dart';

/// Same compact anchored-dropdown mechanism as NeumorphicCategoryFilter,
/// generalized to any value type — used for Distance/Sort so every
/// dropdown-style control in the app looks and opens the same way.
class NeumorphicSelect<T> extends StatefulWidget {
  final List<T> values;
  final List<String> labels;
  final T value;
  final ValueChanged<T> onChanged;
  final IconData leadingIcon;
  final EdgeInsetsGeometry padding;

  const NeumorphicSelect({
    super.key,
    required this.values,
    required this.labels,
    required this.value,
    required this.onChanged,
    required this.leadingIcon,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  });

  @override
  State<NeumorphicSelect<T>> createState() => _NeumorphicSelectState<T>();
}

class _NeumorphicSelectState<T> extends State<NeumorphicSelect<T>> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _boxKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  void _closeMenu() {
    if (_overlayEntry == null) return;
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() {});
  }

  void _toggleMenu(BuildContext context) {
    if (_overlayEntry != null) {
      _closeMenu();
      return;
    }
    FocusScope.of(context).unfocus();
    HapticFeedback.vibrate();

    final renderBox = _boxKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _closeMenu),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, size.height + 8),
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: size.width,
                child: NeumorphicBox(
                  borderRadius: 16,
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(widget.values.length, (i) {
                      final selected = widget.values[i] == widget.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: NeumorphicBox(
                          pressed: selected,
                          borderRadius: 11,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                          onTap: () {
                            widget.onChanged(widget.values[i]);
                            _closeMenu();
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.labels[i],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: selected ? NeumorphicPalette.accent : NeumorphicPalette.textPrimary,
                                  ),
                                ),
                              ),
                              if (selected) const Icon(Icons.check_rounded, size: 16, color: NeumorphicPalette.accent),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.values.indexOf(widget.value).clamp(0, widget.values.length - 1);
    final isOpen = _overlayEntry != null;

    return CompositedTransformTarget(
      link: _layerLink,
      child: NeumorphicBox(
        key: _boxKey,
        borderRadius: 14,
        padding: widget.padding,
        pressed: isOpen,
        onTap: () => _toggleMenu(context),
        child: Row(
          children: [
            Icon(widget.leadingIcon, size: 15, color: NeumorphicPalette.textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                widget.labels[index],
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: NeumorphicPalette.textPrimary, fontWeight: FontWeight.w600),
              ),
            ),
            AnimatedRotation(
              turns: isOpen ? 0.5 : 0,
              duration: const Duration(milliseconds: 150),
              child: const Icon(Icons.expand_more_rounded, size: 18, color: NeumorphicPalette.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
