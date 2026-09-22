import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/neumorphic_theme.dart';
import '../widgets/home_back_leading.dart';
import '../services/image_composer.dart';
import '../services/template_cards.dart';
import '../widgets/advertise_preview_placeholder.dart';
import '../widgets/neumorphic_slider.dart';
import '../widgets/social_platform_button.dart';
import 'publish_flow_screen.dart';
import 'studio_screen.dart';

class _ComposerSnapshot {
  final double x, y, scale, rotation;
  final String text;
  final TextOverlayOptions options;
  _ComposerSnapshot(this.x, this.y, this.scale, this.rotation, this.text, this.options);
}

/// Advertise screen — ported from advertise.html.
///
/// A generated quick-template card is now treated exactly like a
/// picked photo (matching the PWA's adoptImage(), which every
/// template — including Culture/Quote — funnels through): it decodes
/// into the same base image, so Position/Zoom and an additional
/// message still apply on top of it, instead of being a separate
/// "final, uneditable" bypass.
class AdvertiseScreen extends StatefulWidget {
  /// When set (arrived via Android's Share sheet — see
  /// share_intent_service.dart), this photo loads automatically on
  /// open instead of the empty placeholder.
  final Uint8List? initialImageBytes;

  const AdvertiseScreen({super.key, this.initialImageBytes});

  @override
  State<AdvertiseScreen> createState() => _AdvertiseScreenState();
}

class _AdvertiseScreenState extends State<AdvertiseScreen> {
  final _picker = ImagePicker();
  final _messageController = TextEditingController();
  final _messageFocusNode = FocusNode();
  final _socialHandleController = TextEditingController();

  ui.Image? _decodedPhoto;

  double _imagePositionX = 0;
  double _imagePositionY = 0;
  double _imageScale = 1.0;
  double _imageRotation = 0;
  TextOverlayOptions _textOptions = const TextOverlayOptions();

  final List<_ComposerSnapshot> _history = [];

  bool _quickTemplatesExpanded = false;
  bool _textStyleExpanded = false;
  bool _fontPickerExpanded = false;

  String? _errorText;

  /// Which single template button is currently loading — was a shared
  /// bool before, which made every button show a spinner at once.
  String? _loadingTemplateKey;
  String? _templateError;
  bool _socialPanelOpen = false;
  String? _socialPlatform;

  @override
  void initState() {
    super.initState();
    // Undo previously had nothing to restore if the only edit made was
    // typing a message (no slider/chip/font tap ever ran
    // _pushHistory()) — this captures the pre-edit state once when
    // the field gains focus, not on every keystroke.
    _messageFocusNode.addListener(() {
      if (_messageFocusNode.hasFocus) _pushHistory();
    });
    if (widget.initialImageBytes != null) {
      // Post-frame so the first build (with the empty placeholder)
      // completes before swapping in the shared photo.
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPhotoBytes(widget.initialImageBytes!));
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
    _socialHandleController.dispose();
    super.dispose();
  }

  void _pushHistory() {
    _history.add(_ComposerSnapshot(_imagePositionX, _imagePositionY, _imageScale, _imageRotation, _messageController.text, _textOptions));
    if (_history.length > 30) _history.removeAt(0);
  }

  void _undo() {
    if (_history.isEmpty) return;
    final snap = _history.removeLast();
    setState(() {
      _imagePositionX = snap.x;
      _imagePositionY = snap.y;
      _imageScale = snap.scale;
      _imageRotation = snap.rotation;
      _messageController.text = snap.text;
      _textOptions = snap.options;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked != null) {
      final bytes = await File(picked.path).readAsBytes();
      await _loadPhotoBytes(bytes);
    }
  }

  Future<void> _loadPhotoBytes(Uint8List bytes) async {
    final decoded = await ImageComposer.decodeBytes(bytes);
    if (!mounted) return;
    setState(() {
      _decodedPhoto = decoded;
      _imagePositionX = 0;
      _imagePositionY = 0;
      _imageScale = 1.0;
      _imageRotation = 0;
      _templateError = null;
      _history.clear();
    });
  }

  /// [key] identifies which of the 4 buttons is loading, so only that
  /// one shows a spinner. The result decodes into the same base photo
  /// used everywhere else — Position/Zoom and an extra message still
  /// apply on top, matching the PWA.
  Future<void> _runTemplate(String key, Future<Uint8List> Function() generator) async {
    setState(() {
      _loadingTemplateKey = key;
      _templateError = null;
    });
    try {
      final bytes = await generator();
      final decoded = await ImageComposer.decodeBytes(bytes);
      setState(() {
        _decodedPhoto = decoded;
        _imagePositionX = 0;
        _imagePositionY = 0;
        _imageScale = 1.0;
        _imageRotation = 0;
        _messageController.clear();
        _socialPanelOpen = false;
        _history.clear();
      });
    } on TemplateCardException catch (e) {
      setState(() => _templateError = e.message);
    } catch (e) {
      setState(() => _templateError = 'Something went wrong — try again in a moment.');
    } finally {
      setState(() => _loadingTemplateKey = null);
    }
  }

  Future<void> _generateSocialCard() async {
    setState(() => _templateError = null);
    if (_socialPlatform == null) {
      setState(() => _templateError = 'Pick a platform first.');
      return;
    }
    final handle = _socialHandleController.text.trim().replaceFirst(RegExp(r'^@+'), '');
    if (!TemplateCards.handlePattern.hasMatch(handle)) {
      setState(() => _templateError = 'Handle can only contain letters, numbers, dots, underscores and dashes.');
      return;
    }
    await _runTemplate('social', () => TemplateCards.social(platformKey: _socialPlatform!, handle: handle));
  }

  Future<void> _publish() async {
    if (_decodedPhoto == null && _messageController.text.trim().isEmpty) {
      setState(() => _errorText = 'Add a photo or write a message first.');
      return;
    }
    setState(() => _errorText = null);

    // A real separate route (was inline before) — a publish failure
    // now shows and stays on that dedicated screen instead of
    // silently bouncing back here.
    final shouldReset = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PublishFlowScreen(
          photo: _decodedPhoto,
          text: _messageController.text,
          textOptions: _textOptions,
          imagePositionX: _imagePositionX,
          imagePositionY: _imagePositionY,
          imageScale: _imageScale,
          imageRotationDeg: _imageRotation,
        ),
      ),
    );
    if (shouldReset == true && mounted) {
      setState(() {
        _decodedPhoto = null;
        _imagePositionX = 0;
        _imagePositionY = 0;
        _imageScale = 1;
        _imageRotation = 0;
        _textOptions = const TextOverlayOptions();
        _messageController.clear();
        _history.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: NeumorphicPalette.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: NeumorphicPalette.background,
          foregroundColor: NeumorphicPalette.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: NeumorphicPalette.accent,
          inactiveTrackColor: NeumorphicPalette.shadowDark.withOpacity(0.4),
          thumbColor: NeumorphicPalette.accent,
          overlayColor: NeumorphicPalette.accent.withOpacity(0.15),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(leading: Builder(builder: homeBackLeading), leadingWidth: 72, centerTitle: true, title: const Text('Post to BenchPad')),
        body: NotificationListener<OverscrollIndicatorNotification>(
          onNotification: (n) {
            n.disallowIndicator();
            return true;
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildPickerButtons(),
              const SizedBox(height: 10),
              _buildQuickTemplatesCollapsible(),
              const SizedBox(height: 12),
              _buildPreview(),
              const SizedBox(height: 8),
              _buildImageStatus(),
              const SizedBox(height: 8),
              _buildPositionZoomControls(),
              const SizedBox(height: 16),
              _buildMessageField(),
              const SizedBox(height: 8),
              _buildTextStyleCollapsible(),
              const SizedBox(height: 20),
              if (_errorText != null) ...[
                Text(_errorText!, style: const TextStyle(color: NeumorphicPalette.danger, fontSize: 13)),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: NeumorphicBox(
                      soft: true,
                      borderRadius: 16,
                      onTap: _history.isEmpty ? null : _undo,
                      child: Center(child: Text('UNDO', style: TextStyle(color: _history.isEmpty ? NeumorphicPalette.textSecondary : NeumorphicPalette.textPrimary, fontWeight: FontWeight.w800, fontSize: 13))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: NeumorphicBox(
                      borderRadius: 16,
                      onTap: _publish,
                      child: const Center(
                        child: Text('Publish to BenchPad', style: TextStyle(color: NeumorphicPalette.accent, fontWeight: FontWeight.w800, fontSize: 14)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildAiStudioEntry(),
            ],
          ),
        ),
      ),
    );
  }

  /// Entry point to BenchPad AI Studio — same bottom-of-page placement
  /// as the PWA's own promo card.
  Widget _buildAiStudioEntry() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudioScreen())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(colors: [Color(0xFF6734D8), Color(0xFFA64FFF)]),
          boxShadow: [BoxShadow(color: const Color(0xFFA75CFF).withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(14)),
              child: const Text('✦', style: TextStyle(fontSize: 20, color: Colors.white)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('BenchPad AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(border: Border.all(color: Colors.white54), borderRadius: BorderRadius.circular(999)),
                        child: const Text('BETA', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  const Text('Create ad ideas or transform an image with AI', style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerButtons() {
    return Row(
      children: [
        Expanded(child: _pickerButton(Icons.camera_alt_outlined, 'Camera', () => _pickImage(ImageSource.camera))),
        const SizedBox(width: 12),
        Expanded(child: _pickerButton(Icons.photo_library_outlined, 'Gallery', () => _pickImage(ImageSource.gallery))),
      ],
    );
  }

  Widget _pickerButton(IconData icon, String label, VoidCallback onTap) {
    return NeumorphicBox(
      soft: true,
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(vertical: 12),
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: NeumorphicPalette.textPrimary),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: NeumorphicPalette.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    Widget content;
    if (_decodedPhoto != null || _messageController.text.trim().isNotEmpty) {
      content = CustomPaint(
        painter: CompositionPreviewPainter(
          photo: _decodedPhoto,
          text: _messageController.text,
          options: _textOptions,
          imagePositionX: _imagePositionX,
          imagePositionY: _imagePositionY,
          imageScale: _imageScale,
          imageRotationDeg: _imageRotation,
        ),
        child: const SizedBox.expand(),
      );
    } else {
      content = const AdvertisePreviewPlaceholder();
    }

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: NeumorphicBox(flat: true, borderRadius: 22, padding: EdgeInsets.zero, child: content),
      ),
    );
  }

  Widget _buildImageStatus() {
    final ready = _decodedPhoto != null;
    return Center(
      child: Text(
        ready ? 'IMAGE READY' : 'IMAGE NOT READY',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: ready ? NeumorphicPalette.success : NeumorphicPalette.textSecondary),
      ),
    );
  }

  Widget _buildPositionZoomControls() {
    return NeumorphicBox(
      flat: true,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          _buildSlider('Zoom', _imageScale, 0.5, 2.5, (v) => setState(() => _imageScale = v)),
          _buildSlider('Y', _imagePositionY, -1, 1, (v) => setState(() => _imagePositionY = v)),
          _buildSlider('X', _imagePositionX, -1, 1, (v) => setState(() => _imagePositionX = v)),
          _buildSlider('Rotate', _imageRotation, -90, 90, (v) => setState(() => _imageRotation = v), snapPoints: const [-90, 0, 90], snapThreshold: 4),
        ],
      ),
    );
  }

  Widget _buildMessageField() {
    return NeumorphicBox(
      flat: true,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: TextField(
        controller: _messageController,
        focusNode: _messageFocusNode,
        maxLines: 3,
        maxLength: 250,
        style: const TextStyle(fontSize: 13, color: NeumorphicPalette.textPrimary),
        decoration: const InputDecoration(
          hintText: 'Optional caption to display alongside the photo',
          hintStyle: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 13),
          border: InputBorder.none,
          filled: false,
          counterStyle: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11),
        ),
        onChanged: (v) => setState(() {}),
      ),
    );
  }

  Widget _collapsibleHeader({required IconData icon, required String title, required String subtitle, required bool expanded, required VoidCallback onTap}) {
    return NeumorphicBox(
      soft: true,
      borderRadius: 14,
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: NeumorphicPalette.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: NeumorphicPalette.textPrimary)),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: NeumorphicPalette.textSecondary)),
              ],
            ),
          ),
          AnimatedRotation(
            turns: expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 150),
            child: const Icon(Icons.expand_more_rounded, size: 20, color: NeumorphicPalette.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTemplatesCollapsible() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _collapsibleHeader(
          icon: Icons.auto_awesome_outlined,
          title: 'Quick templates',
          subtitle: 'Weather, Culture, Quote, Social',
          expanded: _quickTemplatesExpanded,
          onTap: () => setState(() => _quickTemplatesExpanded = !_quickTemplatesExpanded),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          child: !_quickTemplatesExpanded
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: _templateButton('weather', Icons.wb_sunny_outlined, 'Weather', () => _runTemplate('weather', TemplateCards.weather))),
                          const SizedBox(width: 8),
                          Expanded(child: _templateButton('culture', Icons.museum_outlined, 'Culture', () => _runTemplate('culture', TemplateCards.culture))),
                          const SizedBox(width: 8),
                          Expanded(child: _templateButton('quote', Icons.format_quote_outlined, 'Quote', () => _runTemplate('quote', TemplateCards.quote))),
                          const SizedBox(width: 8),
                          Expanded(child: _templateButton('social', Icons.share_outlined, 'Social', () => setState(() => _socialPanelOpen = !_socialPanelOpen))),
                        ],
                      ),
                      if (_socialPanelOpen) ...[
                        const SizedBox(height: 12),
                        _buildSocialPanel(),
                      ],
                      if (_templateError != null) ...[
                        const SizedBox(height: 8),
                        Text(_templateError!, style: const TextStyle(color: NeumorphicPalette.danger, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  /// Compact icon-over-label block, all 4 equal width in one row —
  /// replaces the earlier icon-beside-label pill, which wrapped to 2
  /// lines and made the row uneven.
  Widget _templateButton(String key, IconData icon, String label, VoidCallback onTap) {
    final loading = _loadingTemplateKey == key;
    final disabled = _loadingTemplateKey != null;
    return NeumorphicBox(
      soft: true,
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(vertical: 12),
      onTap: disabled ? null : onTap,
      child: loading
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: NeumorphicPalette.accent))
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: NeumorphicPalette.accent),
                const SizedBox(height: 4),
                Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: NeumorphicPalette.textPrimary)),
              ],
            ),
    );
  }

  static const _socialIcons = {
    'instagram': 'assets/images/social/instagram.png',
    'tiktok': 'assets/images/social/tiktok.png',
    'x': 'assets/images/social/x.png',
    'facebook': 'assets/images/social/facebook.png',
    'pinterest': 'assets/images/social/pinterest.png',
    'youtube': 'assets/images/social/youtube.png',
    'threads': 'assets/images/social/threads.png',
    'snapchat': 'assets/images/social/snapchat.png',
  };

  // Official brand colours per platform (Simple Icons' hex values).
  static const _socialColors = {
    'instagram': Color(0xFFFF0069),
    'tiktok': Color(0xFF000000),
    'x': Color(0xFF000000),
    'facebook': Color(0xFF0866FF),
    'pinterest': Color(0xFFBD081C),
    'youtube': Color(0xFFFF0000),
    'threads': Color(0xFF000000),
    'snapchat': Color(0xFFFFFC00),
  };

  Widget _buildSocialPanel() {
    return NeumorphicBox(
      flat: true,
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 8,
            childAspectRatio: 0.78,
            children: TemplateCards.socialPlatforms.entries.map((entry) {
              final selected = _socialPlatform == entry.key;
              return SocialPlatformButton(
                iconAsset: _socialIcons[entry.key] ?? 'assets/images/social/x.png',
                color: _socialColors[entry.key] ?? NeumorphicPalette.accent,
                label: entry.value.label,
                selected: selected,
                onTap: () => setState(() => _socialPlatform = entry.key),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          NeumorphicBox(
            flat: true,
            borderRadius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: TextField(
              controller: _socialHandleController,
              style: const TextStyle(fontSize: 13, color: NeumorphicPalette.textPrimary),
              decoration: const InputDecoration(hintText: '@handle', hintStyle: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 13), border: InputBorder.none, filled: false, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
          const SizedBox(height: 10),
          NeumorphicBox(
            borderRadius: 14,
            onTap: _loadingTemplateKey != null ? null : _generateSocialCard,
            child: Center(child: Text('Generate', style: TextStyle(color: _loadingTemplateKey != null ? NeumorphicPalette.textSecondary : NeumorphicPalette.accent, fontWeight: FontWeight.w800, fontSize: 13))),
          ),
        ],
      ),
    );
  }

  Widget _buildTextStyleCollapsible() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _collapsibleHeader(
          icon: Icons.text_fields_rounded,
          title: 'More text options',
          subtitle: 'Position, background, size, alignment, colour, font',
          expanded: _textStyleExpanded,
          onTap: () => setState(() => _textStyleExpanded = !_textStyleExpanded),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          child: !_textStyleExpanded ? const SizedBox(width: double.infinity) : Padding(padding: const EdgeInsets.only(top: 10), child: _buildTextStyleControls()),
        ),
      ],
    );
  }

  Widget _buildTextStyleControls() {
    Widget sectionLabel(String text) => Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: NeumorphicPalette.textSecondary, letterSpacing: 0.5));

    return NeumorphicBox(
      flat: true,
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionLabel('FONT'),
          const SizedBox(height: 8),
          _buildFontPicker(),
          const SizedBox(height: 16),
          sectionLabel('POSITION'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _equalToggle('Top', _textOptions.position == TextVPosition.top, () => setState(() => _textOptions = _textOptions.copyWith(position: TextVPosition.top)))),
              const SizedBox(width: 8),
              Expanded(child: _equalToggle('Center', _textOptions.position == TextVPosition.center, () => setState(() => _textOptions = _textOptions.copyWith(position: TextVPosition.center)))),
              const SizedBox(width: 8),
              Expanded(child: _equalToggle('Bottom', _textOptions.position == TextVPosition.bottom, () => setState(() => _textOptions = _textOptions.copyWith(position: TextVPosition.bottom)))),
            ],
          ),
          const SizedBox(height: 16),
          sectionLabel('ALIGNMENT'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _equalToggle('Left', _textOptions.align == TextHAlign.left, () => setState(() => _textOptions = _textOptions.copyWith(align: TextHAlign.left)))),
              const SizedBox(width: 8),
              Expanded(child: _equalToggle('Center', _textOptions.align == TextHAlign.center, () => setState(() => _textOptions = _textOptions.copyWith(align: TextHAlign.center)))),
              const SizedBox(width: 8),
              Expanded(child: _equalToggle('Right', _textOptions.align == TextHAlign.right, () => setState(() => _textOptions = _textOptions.copyWith(align: TextHAlign.right)))),
            ],
          ),
          const SizedBox(height: 16),
          sectionLabel('BACKGROUND'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _equalToggle('Off', !_textOptions.background, () => setState(() => _textOptions = _textOptions.copyWith(background: false)))),
              const SizedBox(width: 8),
              Expanded(child: _equalToggle('On', _textOptions.background, () => setState(() => _textOptions = _textOptions.copyWith(background: true)))),
            ],
          ),
          const SizedBox(height: 16),
          sectionLabel('COLOUR'),
          const SizedBox(height: 8),
          _buildColorTrough(),
          const SizedBox(height: 16),
          sectionLabel('TEXT SIZE'),
          _buildSlider('', _textOptions.size, 40, 400, (v) => setState(() => _textOptions = _textOptions.copyWith(size: v)), valueLabel: '${_textOptions.size.round()}'),
        ],
      ),
    );
  }

  Widget _equalToggle(String label, bool selected, VoidCallback onTap) {
    return NeumorphicBox(
      soft: true,
      pressed: selected,
      borderRadius: 12,
      padding: const EdgeInsets.symmetric(vertical: 10),
      onTap: () {
        _pushHistory();
        onTap();
      },
      child: Center(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? NeumorphicPalette.accent : NeumorphicPalette.textPrimary))),
    );
  }

  /// Collapsible font picker — tap to reveal all 18 at once (each
  /// rendered in its own typeface), instead of a scrolling carousel
  /// that read as a static box rather than something to swipe.
  Widget _buildFontPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NeumorphicBox(
          soft: true,
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          onTap: () => setState(() => _fontPickerExpanded = !_fontPickerExpanded),
          child: Row(
            children: [
              Text('Aa', style: GoogleFonts.getFont(_textOptions.fontFamily, fontSize: 16, fontWeight: FontWeight.w700, color: NeumorphicPalette.accent)),
              const SizedBox(width: 10),
              Expanded(child: Text(_textOptions.fontFamily, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: NeumorphicPalette.textPrimary))),
              AnimatedRotation(
                turns: _fontPickerExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 150),
                child: const Icon(Icons.expand_more_rounded, size: 20, color: NeumorphicPalette.textSecondary),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          child: !_fontPickerExpanded
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.35,
                    children: TextOverlayOptions.fontChoices.map((f) {
                      final selected = _textOptions.fontFamily == f;
                      return NeumorphicBox(
                        soft: true,
                        pressed: selected,
                        borderRadius: 10,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        onTap: () {
                          _pushHistory();
                          setState(() {
                            _textOptions = _textOptions.copyWith(fontFamily: f);
                            _fontPickerExpanded = false;
                          });
                        },
                        child: Center(
                          child: Text(
                            f,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.getFont(f, fontSize: 11, fontWeight: FontWeight.w700, color: selected ? NeumorphicPalette.accent : NeumorphicPalette.textPrimary),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }

  /// Horizontal gradient trough across the Spectra 6 panel's real
  /// primaries, with a round swatch on the left showing the current
  /// pick — not a rainbow, only colours the physical display can
  /// actually produce.
  Widget _buildColorTrough() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _textOptions.textColor, border: Border.all(color: NeumorphicPalette.shadowDark, width: 1.5)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              void updateFromDx(double dx) {
                final t = (dx / constraints.maxWidth).clamp(0.0, 1.0);
                setState(() => _textOptions = _textOptions.copyWith(textColor: TextOverlayOptions.colorAtT(t)));
              }

              final currentT = _estimateColorT(_textOptions.textColor);
              return GestureDetector(
                onTapDown: (d) {
                  _pushHistory();
                  updateFromDx(d.localPosition.dx);
                },
                onPanStart: (_) => _pushHistory(),
                onPanUpdate: (d) => updateFromDx(d.localPosition.dx),
                child: Container(
                  height: 32,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: LinearGradient(colors: TextOverlayOptions.spectraStops)),
                  child: Align(
                    alignment: Alignment(currentT * 2 - 1, 0),
                    child: Container(
                      width: 20,
                      height: 38,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: Colors.black26, width: 2), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)]),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  double _estimateColorT(Color color) {
    final stops = TextOverlayOptions.spectraStops;
    var bestT = 0.0;
    var bestDist = double.infinity;
    for (var i = 0; i <= 200; i++) {
      final t = i / 200;
      final c = TextOverlayOptions.colorAtT(t);
      final dist = (c.red - color.red).abs() + (c.green - color.green).abs() + (c.blue - color.blue).abs();
      if (dist < bestDist) {
        bestDist = dist.toDouble();
        bestT = t;
      }
    }
    return bestT;
  }

  Widget _buildSlider(String label, double value, double min, double max, ValueChanged<double> onChanged, {List<double>? snapPoints, double snapThreshold = 0, String? valueLabel}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 48, child: Text(label, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12))),
          Expanded(
            child: NeumorphicSlider(
              value: value,
              min: min,
              max: max,
              snapPoints: snapPoints,
              snapThreshold: snapThreshold,
              onChangeStart: _pushHistory,
              onChanged: onChanged,
            ),
          ),
          if (valueLabel != null) ...[
            const SizedBox(width: 6),
            SizedBox(width: 34, child: Text(valueLabel, textAlign: TextAlign.right, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11))),
          ],
        ],
      ),
    );
  }
}
