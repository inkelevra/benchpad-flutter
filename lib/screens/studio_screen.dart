import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/neumorphic_theme.dart';
import '../services/benchpad_api.dart';
import '../widgets/spinning_ring_loader.dart';

enum _StudioMode { text, generate, transform }

/// BenchPad AI Studio — ported from benchpad-ai.html.
///
/// Restyle pass: same neumorphic look as the rest of the app, with the
/// PWA's own violet AI accent kept as-is (not swapped for the app's
/// blue accent) — #A963FF / gradient #6734D8→#A64FFF / glow #A75CFF,
/// matching benchpad-ai.html's own .btn.primary and .orb styling, per
/// explicit request to keep "the same tones".
///
/// The preview compositing is simplified — text is drawn with a Stack
/// overlay on the photo rather than pixel-perfect canvas compositing
/// like the PWA's renderTextPreview(); candidate for a later pass.
class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key});

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  static const _aiAccent = Color(0xFFA963FF);
  static const _aiGradientStart = Color(0xFF6734D8);
  static const _aiGradientEnd = Color(0xFFA64FFF);
  static const _aiGlow = Color(0xFFA75CFF);

  final _api = BenchpadApi();
  final _picker = ImagePicker();
  final _ideaController = TextEditingController();
  final _sessionId = 'fl-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(99999)}';

  int _step = 1;
  _StudioMode _mode = _StudioMode.text;

  File? _photo;
  String _selectedStyle = 'photographic';
  double _photoPositionY = 0;
  double _strength = 62;
  String _transformTarget = 'whole';
  bool _preserveSource = true;
  bool _preserveDisplays = true;

  bool _generating = false;
  String? _generateError;
  List<StudioTextDirection> _textDirections = [];
  List<StudioImageVariant> _imageVariants = [];
  int? _selectedIndex;

  final _editMain = TextEditingController();
  final _editAccent = TextEditingController();
  final _editSub = TextEditingController();

  bool _publishing = false;
  String? _publishStatus;
  Timer? _pollTimer;

  static const _styles = ['photographic', 'illustration', 'minimal', 'retro', 'neon', 'watercolor'];

  @override
  void dispose() {
    _api.dispose();
    _ideaController.dispose();
    _editMain.dispose();
    _editAccent.dispose();
    _editSub.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 88);
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  Future<String> _cropDataUrl() async {
    if (_photo == null) return '';
    final bytes = await _photo!.readAsBytes();
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  Future<void> _startGeneration() async {
    setState(() {
      _step = 3;
      _generating = true;
      _generateError = null;
    });
    try {
      if (_mode == _StudioMode.text) {
        final directions = await _api.createCampaign(
          idea: _ideaController.text.trim(),
          imageData: await _cropDataUrl(),
          sessionId: _sessionId,
        );
        setState(() {
          _textDirections = directions;
          _imageVariants = [];
        });
      } else if (_mode == _StudioMode.generate) {
        final variants = await _api.generateImage(
          prompt: _ideaController.text.trim(),
          style: _selectedStyle,
          sessionId: _sessionId,
        );
        setState(() {
          _imageVariants = variants;
          _textDirections = [];
        });
      } else {
        final variants = await _api.transformImage(
          prompt: _ideaController.text.trim(),
          imageData: await _cropDataUrl(),
          style: _selectedStyle,
          strength: _strength.round(),
          target: _transformTarget,
          preserveSource: _preserveSource,
          preserveDisplays: _preserveDisplays,
          sessionId: _sessionId,
        );
        setState(() {
          _imageVariants = variants;
          _textDirections = [];
        });
      }
      setState(() {
        _generating = false;
        _step = 4;
        _selectedIndex = 0;
        _syncEditFields();
      });
    } catch (e) {
      setState(() {
        _generating = false;
        _generateError = e.toString();
      });
    }
  }

  void _syncEditFields() {
    if (_mode == _StudioMode.text && _selectedIndex != null && _textDirections.isNotEmpty) {
      final d = _textDirections[_selectedIndex!];
      _editMain.text = d.main;
      _editAccent.text = d.accent;
      _editSub.text = d.sub;
    }
  }

  Future<void> _publish() async {
    if (_selectedIndex == null) return;
    setState(() {
      _publishing = true;
      _publishStatus = 'Checking your final content…';
    });

    try {
      Map<String, dynamic> payload;
      if (_mode == _StudioMode.text) {
        final main = _editMain.text.trim();
        final accent = _editAccent.text.trim();
        final sub = _editSub.text.trim();
        final crop = await _cropDataUrl();
        payload = {
          'main': main,
          'accent': accent,
          'sub': sub,
          'moderationImageData': crop,
          'finalImageData': crop,
          'photoIdentity': '',
          'imagePositionY': _photoPositionY,
          'deviceId': 'BP-AMS-001',
          'displayId': 'CENTRAL',
          'source': 'BENCHPAD_AI',
          'sessionId': _sessionId,
        };
      } else {
        final v = _imageVariants[_selectedIndex!];
        final isGenerate = _mode == _StudioMode.generate;
        final crop = isGenerate ? v.imageData : await _cropDataUrl();
        payload = {
          'main': _ideaController.text.trim().isEmpty ? (isGenerate ? 'AI generated image' : 'AI image transformation') : _ideaController.text.trim(),
          'accent': v.label,
          'sub': isGenerate ? 'BenchPad AI Generate · $_selectedStyle' : 'BenchPad AI Transform · $_selectedStyle',
          'moderationImageData': crop,
          'finalImageData': v.imageData,
          'photoIdentity': '',
          'imagePositionY': isGenerate ? 0 : _photoPositionY,
          'deviceId': 'BP-AMS-001',
          'displayId': 'CENTRAL',
          'source': isGenerate ? 'BENCHPAD_AI_GENERATE' : 'BENCHPAD_AI_TRANSFORM',
          'sessionId': _sessionId,
        };
      }

      final result = await _api.aiPublish(payload);
      if (result.confirmedDisplayed) {
        setState(() {
          _publishing = false;
          _step = 6;
        });
      } else {
        setState(() => _publishStatus = 'Waiting for physical display...');
        _pollTimer?.cancel();
        _pollTimer = Timer.periodic(const Duration(seconds: 2), (t) async {
          try {
            final response = await _api.getPublishStatus(result.jobCode);
            final job = response['job'] as Map<String, dynamic>? ?? response;
            if (job['status'] == 'DISPLAYED') {
              t.cancel();
              setState(() {
                _publishing = false;
                _step = 6;
              });
            }
          } catch (_) {}
        });
      }
    } on PublishException catch (e) {
      setState(() {
        _publishing = false;
        _publishStatus = e.reasonCode == 'cooldown'
            ? 'Next publication available in ${e.cooldownSeconds ?? 30} seconds'
            : e.reasonCode == 'needs_review'
                ? '${e.jobCode ?? "Submission"} needs review · other approved jobs continue'
                : 'Content not approved · ${e.reasonCode}';
      });
    } catch (e) {
      setState(() {
        _publishing = false;
        _publishStatus = 'Something went wrong: $e';
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
        sliderTheme: SliderThemeData(activeTrackColor: _aiAccent, thumbColor: _aiAccent, inactiveTrackColor: NeumorphicPalette.shadowDark.withOpacity(0.4)),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('BenchPad AI ✦'),
          leading: _step > 1 && _step < 6 ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _step = max(1, _step - 1))) : null,
        ),
        body: NotificationListener<OverscrollIndicatorNotification>(
          onNotification: (n) {
            n.disallowIndicator();
            return true;
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildProgressDots(),
                const SizedBox(height: 16),
                Expanded(child: _buildStep()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressDots() {
    return Row(
      children: List.generate(5, (i) {
        final on = i < _step;
        return Expanded(
          child: Container(
            height: 5,
            margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
            decoration: BoxDecoration(
              color: on ? _aiAccent : NeumorphicPalette.shadowDark.withOpacity(0.4),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 1:
        return _buildStep1Idea();
      case 2:
        return _buildStep2Photo();
      case 3:
        return _buildStep3Generating();
      case 4:
        return _buildStep4Results();
      case 5:
        return _buildStep5Preview();
      case 6:
        return _buildStep6Success();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _primaryButton(String label, VoidCallback? onTap) {
    final enabled = onTap != null;
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: enabled ? const LinearGradient(colors: [_aiGradientStart, _aiGradientEnd]) : null,
        color: enabled ? null : NeumorphicPalette.shadowDark.withOpacity(0.3),
        boxShadow: enabled ? [BoxShadow(color: _aiGlow.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 8))] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Center(child: Text(label, style: TextStyle(color: enabled ? Colors.white : NeumorphicPalette.textSecondary, fontWeight: FontWeight.w800, fontSize: 14))),
        ),
      ),
    );
  }

  Widget _secondaryButton(String label, VoidCallback? onTap) {
    return NeumorphicBox(
      soft: true,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(vertical: 15),
      onTap: onTap,
      child: Center(child: Text(label, style: const TextStyle(color: NeumorphicPalette.textPrimary, fontWeight: FontWeight.w800, fontSize: 13))),
    );
  }

  Widget _buildStep1Idea() {
    return ListView(
      children: [
        const Text('What do you want people nearby to know?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary)),
        const SizedBox(height: 6),
        const Text('Write it naturally. It does not need to sound like an advertisement.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12)),
        const SizedBox(height: 16),
        _buildModeSwitch(),
        const SizedBox(height: 16),
        NeumorphicBox(
          flat: true,
          borderRadius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: TextField(
            controller: _ideaController,
            maxLines: 5,
            maxLength: 500,
            style: const TextStyle(fontSize: 13, color: NeumorphicPalette.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Example: We have 20% discount on fresh pastries and coffee from 17:00 today.',
              hintStyle: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 13),
              border: InputBorder.none,
              filled: false,
              counterStyle: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 16),
        _primaryButton('CONTINUE', _ideaController.text.trim().isEmpty ? null : () => setState(() => _step = 2)),
      ],
    );
  }

  Widget _buildModeSwitch() {
    final modes = [
      (_StudioMode.text, 'Text AI', 'Generate clear local ad directions from your idea.'),
      (_StudioMode.generate, 'Generate Image', 'Draw a brand new image from your description, no photo needed.'),
      (_StudioMode.transform, 'Image Transform', 'Turn one image into several visual AI-style versions.'),
    ];
    return Column(
      children: modes.map((m) {
        final active = _mode == m.$1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: NeumorphicBox(
            soft: true,
            pressed: active,
            borderRadius: 16,
            onTap: () => setState(() => _mode = m.$1),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(m.$2, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: active ? _aiAccent : NeumorphicPalette.textPrimary)),
                        const SizedBox(height: 3),
                        Text(m.$3, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedOpacity(
                    opacity: active ? 1 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: _aiAccent.withOpacity(0.15)),
                      child: Icon(Icons.check, size: 15, color: _aiAccent),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStep2Photo() {
    final needsPhoto = _mode == _StudioMode.transform;
    final needsStyle = _mode == _StudioMode.generate || _mode == _StudioMode.transform;

    return ListView(
      children: [
        const Text('Add a photo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary)),
        const SizedBox(height: 6),
        Text(
          needsPhoto ? 'A photo is required for Image Transform mode.' : 'Optional — upload a photo if it helps BenchPad AI.',
          style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 4 / 3,
          child: NeumorphicBox(
            flat: true,
            borderRadius: 16,
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _photo != null ? Image.file(_photo!, fit: BoxFit.cover) : const Center(child: Icon(Icons.image_outlined, size: 40, color: NeumorphicPalette.textSecondary)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _photoPickButton(Icons.photo_library_outlined, 'Upload', () => _pickPhoto(ImageSource.gallery))),
            const SizedBox(width: 10),
            Expanded(child: _photoPickButton(Icons.camera_alt_outlined, 'Camera', () => _pickPhoto(ImageSource.camera))),
          ],
        ),
        if (needsStyle) ...[
          const SizedBox(height: 20),
          _sectionLabel('VISUAL STYLE'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _styles.map((s) => _pillChip(s, _selectedStyle == s, () => setState(() => _selectedStyle = s))).toList(),
          ),
        ],
        if (_photo != null) ...[
          const SizedBox(height: 20),
          _sectionLabel('VISIBLE PHOTO AREA'),
          Slider(value: _photoPositionY, min: -100, max: 100, onChanged: (v) => setState(() => _photoPositionY = v)),
        ],
        if (_mode == _StudioMode.transform) ...[
          _sectionLabel('TRANSFORMATION STRENGTH'),
          Slider(value: _strength, min: 15, max: 100, onChanged: (v) => setState(() => _strength = v)),
          const SizedBox(height: 8),
          _sectionLabel('TRANSFORMATION TARGET'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ('whole', 'WHOLE IMAGE'),
              ('subject', 'MAIN OBJECT'),
              ('background', 'BACKGROUND ONLY'),
            ].map((t) => _pillChip(t.$2, _transformTarget == t.$1, () => setState(() => _transformTarget = t.$1))).toList(),
          ),
          const SizedBox(height: 12),
          _checkRow('Preserve recognizable source features', _preserveSource, (v) => setState(() => _preserveSource = v)),
          const SizedBox(height: 8),
          _checkRow('For BenchPad: preserve three E-Ink displays', _preserveDisplays, (v) => setState(() => _preserveDisplays = v)),
        ],
        const SizedBox(height: 20),
        _primaryButton('CREATE WITH AI ✦', (needsPhoto && _photo == null) ? null : _startGeneration),
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(text, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1));

  Widget _photoPickButton(IconData icon, String label, VoidCallback onTap) {
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

  Widget _pillChip(String label, bool selected, VoidCallback onTap) {
    return NeumorphicBox(
      soft: true,
      pressed: selected,
      borderRadius: 999,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      onTap: onTap,
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? _aiAccent : NeumorphicPalette.textPrimary)),
    );
  }

  Widget _checkRow(String label, bool value, ValueChanged<bool> onChanged) {
    return NeumorphicBox(
      soft: true,
      borderRadius: 14,
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          Icon(value ? Icons.check_circle : Icons.circle_outlined, size: 20, color: value ? _aiAccent : NeumorphicPalette.textSecondary),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: NeumorphicPalette.textPrimary))),
        ],
      ),
    );
  }

  Widget _buildStep3Generating() {
    if (_generateError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: NeumorphicPalette.danger, size: 40),
            const SizedBox(height: 12),
            Text(_generateError!, textAlign: TextAlign.center, style: const TextStyle(color: NeumorphicPalette.danger)),
            const SizedBox(height: 20),
            _secondaryButton('BACK TO EDIT', () => setState(() => _step = 2)),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SpinningRingLoader(size: 140, centerImageAsset: 'assets/images/kinesus-flower-logo.webp'),
          const SizedBox(height: 20),
          const Text('Creating your BenchPad ideas...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: NeumorphicPalette.textPrimary)),
          const SizedBox(height: 8),
          const Text('BenchPad AI · content checks active', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildStep4Results() {
    final isText = _mode == _StudioMode.text;
    final count = isText ? _textDirections.length : _imageVariants.length;

    return ListView(
      children: [
        const Text('Choose the one you like', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary)),
        const SizedBox(height: 12),
        for (int i = 0; i < count; i++) _buildResultCard(i, isText),
        if (isText && _selectedIndex != null) ...[
          const SizedBox(height: 16),
          _sectionLabel('EDIT TEXT'),
          const SizedBox(height: 8),
          _editField(_editMain, 'Headline', 70),
          const SizedBox(height: 8),
          _editField(_editAccent, 'Accent', 40),
          const SizedBox(height: 8),
          _editField(_editSub, 'Subline', 90),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _secondaryButton('START OVER', () => setState(() => _step = 1))),
            const SizedBox(width: 10),
            Expanded(child: _primaryButton('USE THIS RESULT', _selectedIndex == null ? null : () => setState(() => _step = 5))),
          ],
        ),
      ],
    );
  }

  Widget _editField(TextEditingController controller, String label, int maxLength) {
    return NeumorphicBox(
      flat: true,
      borderRadius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        style: const TextStyle(fontSize: 13, color: NeumorphicPalette.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12),
          border: InputBorder.none,
          filled: false,
          counterStyle: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10),
        ),
      ),
    );
  }

  Widget _buildResultCard(int i, bool isText) {
    final selected = _selectedIndex == i;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeumorphicBox(
        flat: true,
        borderRadius: 16,
        padding: EdgeInsets.zero,
        onTap: () => setState(() {
          _selectedIndex = i;
          _syncEditFields();
        }),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: selected ? _aiAccent : Colors.transparent, width: 2)),
          clipBehavior: Clip.antiAlias,
          child: isText ? _buildTextResultPreview(_textDirections[i]) : _buildImageResultPreview(_imageVariants[i]),
        ),
      ),
    );
  }

  Widget _buildTextResultPreview(StudioTextDirection d) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(d.label, style: const TextStyle(color: _aiAccent, fontSize: 10, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(d.main, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary)),
          if (d.accent.isNotEmpty) Text(d.accent, style: const TextStyle(color: _aiAccent, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(d.sub, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildImageResultPreview(StudioImageVariant v) {
    final bytes = _decodeDataUrl(v.imageData);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: bytes != null ? Image.memory(bytes, fit: BoxFit.cover) : Container(color: NeumorphicPalette.surface),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(v.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: NeumorphicPalette.textPrimary)),
        ),
      ],
    );
  }

  Uint8List? _decodeDataUrl(String dataUrl) {
    final commaIndex = dataUrl.indexOf(',');
    if (commaIndex == -1) return null;
    try {
      return base64Decode(dataUrl.substring(commaIndex + 1));
    } catch (_) {
      return null;
    }
  }

  Widget _buildStep5Preview() {
    final isText = _mode == _StudioMode.text;
    return ListView(
      children: [
        const Text('Final Preview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary)),
        const SizedBox(height: 4),
        const Text('WHAT YOU SEE IS WHAT WILL BE PUBLISHED · Central Display', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 4 / 3,
          child: NeumorphicBox(
            flat: true,
            borderRadius: 18,
            padding: EdgeInsets.zero,
            child: ClipRRect(borderRadius: BorderRadius.circular(18), child: _buildFinalPreview(isText)),
          ),
        ),
        const SizedBox(height: 12),
        NeumorphicBox(
          flat: true,
          borderRadius: 999,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: const Center(child: Text('BP-AMS-001 · CENTRAL DISPLAY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: NeumorphicPalette.textPrimary))),
        ),
        const SizedBox(height: 8),
        const Text('Content is checked again before publishing', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
        if (_publishStatus != null) ...[
          const SizedBox(height: 12),
          Text(_publishStatus!, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12)),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _secondaryButton('BACK', _publishing ? null : () => setState(() => _step = 4))),
            const SizedBox(width: 10),
            Expanded(child: _primaryButton(_publishing ? 'Publishing...' : 'PUBLISH TO BENCHPAD', _publishing ? null : _publish)),
          ],
        ),
      ],
    );
  }

  Widget _buildFinalPreview(bool isText) {
    if (isText) {
      final main = _editMain.text;
      final accent = _editAccent.text;
      final sub = _editSub.text;
      final photoBytes = _photo != null ? _photo!.readAsBytesSync() : null;
      return Stack(
        fit: StackFit.expand,
        children: [
          if (photoBytes != null) Image.memory(photoBytes, fit: BoxFit.cover) else Container(color: const Color(0xFF11161D)),
          Container(color: Colors.black.withOpacity(0.25)),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Align(
              alignment: Alignment.topLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(main, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, height: 1)),
                  if (accent.isNotEmpty) Text(accent, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFFFD33D))),
                  const SizedBox(height: 8),
                  Text(sub, style: const TextStyle(fontSize: 12, color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      final v = _imageVariants[_selectedIndex!];
      final bytes = _decodeDataUrl(v.imageData);
      return bytes != null ? Image.memory(bytes, fit: BoxFit.cover) : Container(color: NeumorphicPalette.surface);
    }
  }

  Widget _buildStep6Success() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(color: NeumorphicPalette.success.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.check, color: NeumorphicPalette.success, size: 44),
          ),
          const SizedBox(height: 20),
          const Text('Your BenchPad is updated.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary)),
          const SizedBox(height: 6),
          const Text('Your result is displayed on BP-AMS-001.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12)),
          const SizedBox(height: 24),
          SizedBox(
            width: 220,
            child: _primaryButton('CREATE ANOTHER', () => setState(() {
                  _step = 1;
                  _ideaController.clear();
                  _photo = null;
                  _textDirections = [];
                  _imageVariants = [];
                  _selectedIndex = null;
                  _publishStatus = null;
                })),
          ),
        ],
      ),
    );
  }
}
