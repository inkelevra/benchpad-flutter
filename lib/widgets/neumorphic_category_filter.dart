import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../theme/neumorphic_theme.dart';

/// A collapsible category filter: one labeled neumorphic pill showing
/// the current selection, which drops open a compact neumorphic menu
/// directly beneath it — same width as the button itself — instead of
/// a bottom sheet that covered half the screen.
///
/// [categories] is a list of [value, label] pairs; [icons] maps each
/// value to an icon (the 'all'/first entry falls back to
/// [allIcon] if not present in the map).
class NeumorphicCategoryFilter extends StatefulWidget {
  final List<List<String>> categories;
  final Map<String, IconData> icons;
  final IconData allIcon;
  final String value;
  final ValueChanged<String> onChanged;
  final String sheetTitle;
  final EdgeInsetsGeometry padding;

  const NeumorphicCategoryFilter({
    super.key,
    required this.categories,
    required this.icons,
    required this.value,
    required this.onChanged,
    this.allIcon = Icons.apps_rounded,
    this.sheetTitle = 'Category',
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  });

  @override
  State<NeumorphicCategoryFilter> createState() => _NeumorphicCategoryFilterState();
}

class _NeumorphicCategoryFilterState extends State<NeumorphicCategoryFilter> {
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
          // Invisible full-screen tap catcher — tapping anywhere outside
          // the dropdown closes it.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closeMenu,
            ),
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
                    children: widget.categories.map((c) {
                      final selected = c[0] == widget.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: NeumorphicBox(
                          pressed: selected,
                          borderRadius: 11,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                          onTap: () {
                            widget.onChanged(c[0]);
                            _closeMenu();
                          },
                          child: Row(
                            children: [
                              Icon(widget.icons[c[0]] ?? widget.allIcon, size: 15, color: selected ? NeumorphicPalette.accent : NeumorphicPalette.textSecondary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  c[1],
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
                    }).toList(),
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
    final current = widget.categories.firstWhere((c) => c[0] == widget.value, orElse: () => widget.categories.first);
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
            Icon(widget.icons[widget.value] ?? widget.allIcon, size: 15, color: NeumorphicPalette.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                current[1],
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.3, color: NeumorphicPalette.textPrimary),
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
