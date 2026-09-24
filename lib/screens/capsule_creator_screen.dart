import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/benchpad_api.dart';
import '../services/capsule_store.dart';
import '../theme/benchpad_dark_theme.dart';
import 'advertise_screen.dart';

/// Capsule Creator — multi-step capsule form, ported from
/// capsule-creator.html. Includes the Avatar step (preset emoji grid or
/// uploaded photo with zoom/X/Y crop sliders) — this is purely local
/// preview decoration in the PWA too, never sent to the server.
class CapsuleCreatorScreen extends StatefulWidget {
  final String type; // "core" | "standard" (ignored server-side when sphere is 'orbit')
  final int number;
  final String? ownerKey; // when provided (via Capsule Access), pre-authorizes editing an existing capsule
  final String sphere; // 'vault' (Time Capsule 1) | 'orbit' (Time Capsule 2 / Time Capsule 2)

  const CapsuleCreatorScreen({super.key, required this.type, required this.number, this.ownerKey, this.sphere = 'vault'});

  @override
  State<CapsuleCreatorScreen> createState() => _CapsuleCreatorScreenState();
}

class _CapsuleCreatorScreenState extends State<CapsuleCreatorScreen> {
  final _api = BenchpadApi();
  final _picker = ImagePicker();

  int _step = 0; // 0..5: Identity, Avatar, Compose, Opening rules, Preview, Complete
  static const _titles = ['Identity', 'Avatar', 'Compose', 'Opening rules', 'Preview', 'Complete'];

  // Avatar — session-only presentational state (ported from
  // capsule-creator.html; the PWA itself never sends avatarData/
  // avatarPreset to the server, it's purely local preview decoration).
  static const _avatarPresets = [
    ['nature', '🌿'], ['pet', '🐾'], ['flower', '🌸'], ['world', '🌍'], ['city', '🏙️'],
    ['planet', '🪐'], ['book', '📚'], ['ocean', '🌊'], ['spark', '✨'], ['peace', '🕊️'],
  ];
  String _avatarPreset = '';
  File? _avatarSource;
  double _avatarZoom = 1.0;
  double _avatarX = 0;
  double _avatarY = 0;

  final _ownerController = TextEditingController();
  final _countryController = TextEditingController();
  final _messageController = TextEditingController();
  DateTime _openingDate = DateTime.now().add(const Duration(days: 365 * 3));
  TimeOfDay _openingTime = const TimeOfDay(hour: 12, minute: 0);
  String _visibility = 'public';
  Uint8List? _composedPhoto; // final flattened JPEG (photo + text baked in), produced by AdvertiseScreen's compose-only mode
  Uint8List? _sourcePhotoBytes; // the un-composited photo, kept so re-opening Compose doesn't double-bake text

  bool _busy = false;
  String? _ownerKey;
  String? _existingImageData;
  bool _loadingExisting = true;
  bool _readOnly = false;
  bool _justSealed = false;

  String get _displayId => widget.sphere == 'orbit'
      ? 'BP-ORB-${widget.number.toString().padLeft(6, '0')}'
      : widget.sphere == 'hex'
          ? 'BP-HEX-${widget.number.toString().padLeft(6, '0')}'
          : widget.type == 'core'
              ? 'BP-CORE-${widget.number.toString().padLeft(2, '0')}'
              : 'BP-TC-${widget.number.toString().padLeft(6, '0')}';

  @override
  void initState() {
    super.initState();
    _ownerKey = widget.ownerKey;
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final cell = await _api.getCell(type: widget.type, number: widget.number, sphere: widget.sphere);
      final status = (cell['status'] ?? 'empty') as String;
      if (status != 'empty') {
        _ownerController.text = (cell['ownerName'] ?? '') as String;
        _countryController.text = (cell['ownerCountry'] ?? '') as String;
        _messageController.text = (cell['message'] ?? '') as String;
        _existingImageData = cell['imageData'] as String?;
        final visibility = cell['visibility'] as String?;
        if (visibility != null) _visibility = visibility;
        final openingDateStr = cell['openingDate'] as String?;
        if (openingDateStr != null) {
          final parsed = DateTime.tryParse(openingDateStr);
          if (parsed != null) {
            _openingDate = parsed;
            _openingTime = TimeOfDay(hour: parsed.hour, minute: parsed.minute);
          }
        }
        // Sealed/open capsules are read-only in the PWA — publishing
        // already happened or is scheduled; editing would desync the
        // server's copy.
        if (status == 'sealed' || status == 'open') _readOnly = true;
      }
    } catch (_) {
      // No existing cell yet, or network hiccup — proceed as a fresh
      // capsule; saveCapsule() will create it.
    } finally {
      if (mounted) setState(() => _loadingExisting = false);
    }
  }

  @override
  void dispose() {
    _api.dispose();
    _ownerController.dispose();
    _countryController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _processCompose() async {
    final result = await Navigator.push<ComposeResult>(
      context,
      MaterialPageRoute(
        builder: (_) => AdvertiseScreen(
          composeOnly: true,
          initialImageBytes: _sourcePhotoBytes,
          initialMessage: _messageController.text,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _composedPhoto = result.composedJpeg;
        _sourcePhotoBytes = result.sourcePhotoBytes;
        _messageController.text = result.message;
      });
    }
  }

  bool _validateStep() {
    if (_step == 0 && (_ownerController.text.trim().isEmpty || _countryController.text.trim().isEmpty)) {
      _toast('Add a name and country');
      return false;
    }
    if (_step == 2 && _messageController.text.trim().isEmpty) {
      _toast('A capsule needs a written message to be sealed — add one (a photo alone isn\'t enough here)');
      return false;
    }
    return true;
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String get _openingDateIso {
    final combined = DateTime(_openingDate.year, _openingDate.month, _openingDate.day, _openingTime.hour, _openingTime.minute);
    return combined.toIso8601String();
  }

  Future<String> _photoDataUrl() async {
    if (_composedPhoto != null) {
      return 'data:image/jpeg;base64,${base64Encode(_composedPhoto!)}';
    }
    return _existingImageData ?? '';
  }

  Future<void> _save({required bool seal}) async {
    setState(() => _busy = true);
    try {
      final result = await _api.saveCapsule(
        type: widget.type,
        number: widget.number,
        sphere: widget.sphere,
        accessKey: _ownerKey ?? '',
        ownerName: _ownerController.text.trim(),
        ownerCountry: _countryController.text.trim(),
        message: _messageController.text.trim(),
        openingDateIso: _openingDateIso,
        visibility: _visibility,
        imageData: await _photoDataUrl(),
      );
      final issuedKey = result['issuedAccessKey'] as String?;
      if (issuedKey != null) _ownerKey = issuedKey;

      if (seal) {
        await _api.sealCapsule(type: widget.type, number: widget.number, accessKey: _ownerKey ?? '', sphere: widget.sphere);
      }

      if (_ownerKey != null && _ownerKey!.isNotEmpty) {
        await CapsuleStore.remember({
          'accessKey': _ownerKey,
          'sphere': widget.sphere,
          'type': widget.type,
          'number': widget.number,
          'status': seal ? 'sealed' : 'locked',
        });
      }

      setState(() { _busy = false; _step = 5; _justSealed = seal; });
    } catch (e) {
      setState(() => _busy = false);
      _toast(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingExisting) {
      return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: BPColors.bg,
        appBarTheme: const AppBarTheme(
          backgroundColor: BPColors.bg,
          foregroundColor: BPColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(backgroundColor: BPColors.yellow, foregroundColor: BPColors.bg, disabledBackgroundColor: BPColors.border, disabledForegroundColor: BPColors.textSecondary),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(foregroundColor: BPColors.textPrimary, disabledForegroundColor: BPColors.textSecondary, side: const BorderSide(color: BPColors.yellow)),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: BPColors.yellow),
        ),
        textTheme: Theme.of(context).textTheme.apply(bodyColor: BPColors.textPrimary, displayColor: BPColors.textPrimary),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: BPColors.card,
          labelStyle: const TextStyle(color: BPColors.textSecondary),
          floatingLabelStyle: const TextStyle(color: BPColors.yellow),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: BPColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: BPColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: BPColors.yellow, width: 1.5)),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(title: Text(widget.sphere == 'orbit' ? 'Time Capsule 2 · Reserve a Position' : widget.sphere == 'hex' ? 'Time Capsule 3 · Reserve a Cell' : 'Time Capsule 1 · Reserve a Cell')),
        body: const Center(child: CircularProgressIndicator()),
      ));
    }
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: BPColors.bg,
        appBarTheme: const AppBarTheme(
          backgroundColor: BPColors.bg,
          foregroundColor: BPColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(backgroundColor: BPColors.yellow, foregroundColor: BPColors.bg, disabledBackgroundColor: BPColors.border, disabledForegroundColor: BPColors.textSecondary),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(foregroundColor: BPColors.textPrimary, disabledForegroundColor: BPColors.textSecondary, side: const BorderSide(color: BPColors.yellow)),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: BPColors.yellow),
        ),
        textTheme: Theme.of(context).textTheme.apply(bodyColor: BPColors.textPrimary, displayColor: BPColors.textPrimary),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: BPColors.card,
          labelStyle: const TextStyle(color: BPColors.textSecondary),
          floatingLabelStyle: const TextStyle(color: BPColors.yellow),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: BPColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: BPColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: BPColors.yellow, width: 1.5)),
        ),
      ),
      child: Scaffold(
      appBar: AppBar(title: Text(widget.sphere == 'orbit' ? 'Time Capsule 2 · Reserve a Position' : widget.sphere == 'hex' ? 'Time Capsule 3 · Reserve a Cell' : 'Time Capsule 1 · Reserve a Cell')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_readOnly && _step < 6)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: BPColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Text('This capsule is sealed and read-only.', style: TextStyle(color: BPColors.danger, fontSize: 12)),
                ),
              if (_step < 5) ...[
                Row(
                  children: [
                    Text('STEP ${_step + 1} OF 5', style: const TextStyle(color: BPColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Text(_displayId, style: const TextStyle(color: BPColors.yellow, fontSize: 11, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(_titles[_step], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(value: (_step + 1) / 5, minHeight: 5, backgroundColor: BPColors.bg, color: BPColors.yellow),
                ),
                const SizedBox(height: 16),
              ],
              Expanded(child: _buildStep()),
            ],
          ),
        ),
      ),
    ));
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildIdentityStep();
      case 1:
        return _buildAvatarStep();
      case 2:
        return _buildComposeStep();
      case 3:
        return _buildOpeningRulesStep();
      case 4:
        return _buildPreviewStep();
      default:
        return _buildCompleteStep();
    }
  }

  Widget _buildIdentityStep() {
    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: BPColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: BPColors.yellow.withOpacity(0.3))),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: BPColors.yellow, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'You\'re reserving this spot to publish a photo or message on the physical BenchPad display — on a date and time you choose. Six short steps, about 2 minutes.',
                  style: TextStyle(color: BPColors.textSecondary, fontSize: 12, height: 1.35),
                ),
              ),
            ],
          ),
        ),
        const Text('Your public name can be a real name or a pseudonym.', style: TextStyle(color: BPColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 16),
        TextField(controller: _ownerController, decoration: const InputDecoration(labelText: 'Name or pseudonym')),
        const SizedBox(height: 12),
        TextField(controller: _countryController, decoration: const InputDecoration(labelText: 'Country')),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: () { if (_validateStep()) setState(() => _step = 1); }, child: const Text('CONTINUE')),
      ],
    );
  }

  Widget _buildAvatarStep() {
    return ListView(
      children: [
        const Text('Select a ready-made symbol or upload any appropriate image: yourself, a flower, a pet, an object or an illustration. A real face is not required.',
            style: TextStyle(color: BPColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: BPColors.yellow.withOpacity(0.4), width: 2),
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1D536A), Color(0xFF101B2B)]),
            ),
            clipBehavior: Clip.antiAlias,
            child: _avatarSource != null
                ? ClipOval(
                    child: Transform.translate(
                      offset: Offset(_avatarX * 0.5, _avatarY * 0.5),
                      child: Transform.scale(
                        scale: _avatarZoom,
                        child: Image.file(_avatarSource!, fit: BoxFit.cover, width: 130, height: 130),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      _avatarPreset.isNotEmpty ? _avatarPresets.firstWhere((p) => p[0] == _avatarPreset)[1] : _initialsForAvatar(),
                      style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 5,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1,
          children: _avatarPresets.map((p) {
            final active = _avatarPreset == p[0];
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() { _avatarPreset = p[0]; _avatarSource = null; }),
              child: Container(
                decoration: BoxDecoration(
                  color: BPColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: active ? BPColors.yellow : Colors.transparent, width: 1.5),
                ),
                child: Center(child: Text(p[1], style: const TextStyle(fontSize: 22))),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: OutlinedButton.icon(onPressed: _pickAvatarPhoto, icon: const Icon(Icons.upload_outlined), label: const Text('UPLOAD'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: () => setState(() { _avatarPreset = ''; _avatarSource = null; }), child: const Text('USE INITIALS'))),
          ],
        ),
        if (_avatarSource != null) ...[
          const SizedBox(height: 16),
          _sliderRow('ZOOM', _avatarZoom, 1.0, 3.0, (v) => setState(() => _avatarZoom = v)),
          _sliderRow('LEFT / RIGHT', _avatarX, -100, 100, (v) => setState(() => _avatarX = v)),
          _sliderRow('UP / DOWN', _avatarY, -100, 100, (v) => setState(() => _avatarY = v)),
          const SizedBox(height: 6),
          OutlinedButton(onPressed: () => setState(() { _avatarSource = null; _avatarPreset = ''; }), child: const Text('REMOVE IMAGE')),
        ],
        const SizedBox(height: 12),
        const Text('The public avatar is cropped to a circle and, when this connects to real accounts later, will require moderation before public use.',
            style: TextStyle(color: BPColors.textSecondary, fontSize: 10)),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 0), child: const Text('BACK'))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(onPressed: () => setState(() => _step = 2), child: const Text('CONTINUE'))),
          ],
        ),
      ],
    );
  }

  String _initialsForAvatar() {
    final name = _ownerController.text.trim();
    if (name.isEmpty) return 'BW';
    final parts = name.split(RegExp(r'\s+')).take(2);
    return parts.map((p) => p.isNotEmpty ? p[0] : '').join().toUpperCase();
  }

  Future<void> _pickAvatarPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked != null) {
      setState(() {
        _avatarSource = File(picked.path);
        _avatarPreset = '';
        _avatarZoom = 1.0;
        _avatarX = 0;
        _avatarY = 0;
      });
    }
  }

  Widget _sliderRow(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(color: BPColors.textSecondary, fontSize: 9, fontWeight: FontWeight.w800))),
        Expanded(child: Slider(value: value, min: min, max: max, onChanged: onChanged)),
      ],
    );
  }

  Widget _buildComposeStep() {
    return ListView(
      children: [
        const Text(
          'Process your photo and message just like a normal BenchPad post — same photo positioning, zoom and text styling as Post to BenchPad. A written message is required to seal the capsule; the photo is optional.',
          style: TextStyle(color: BPColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Container(
            decoration: BoxDecoration(color: BPColors.card, borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: _composedPhoto != null
                ? Image.memory(_composedPhoto!, fit: BoxFit.cover)
                : (_existingImageData != null && _existingImageData!.contains(','))
                    ? Image.memory(base64Decode(_existingImageData!.split(',').last), fit: BoxFit.cover)
                    : _messageController.text.trim().isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(child: Text('"${_messageController.text.trim()}"', textAlign: TextAlign.center, style: const TextStyle(color: BPColors.textPrimary, fontStyle: FontStyle.italic))),
                          )
                        : const Center(child: Icon(Icons.image_outlined, size: 40, color: BPColors.textSecondary)),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _processCompose,
          icon: const Icon(Icons.tune),
          label: Text(_composedPhoto != null || _messageController.text.trim().isNotEmpty ? 'Edit photo & message' : 'Process photo & message'),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 1), child: const Text('BACK'))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(onPressed: () { if (_validateStep()) setState(() => _step = 3); }, child: const Text('CONTINUE'))),
          ],
        ),
      ],
    );
  }

  Widget _buildOpeningRulesStep() {
    return ListView(
      children: [
        const Text('Choose when your message publishes to the physical display, and whether visitors may see it before then.', style: TextStyle(color: BPColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Publish date', style: TextStyle(color: BPColors.textPrimary)),
          subtitle: Text('${_openingDate.year}-${_openingDate.month.toString().padLeft(2, '0')}-${_openingDate.day.toString().padLeft(2, '0')}', style: const TextStyle(color: BPColors.textSecondary)),
          trailing: const Icon(Icons.calendar_today, size: 18, color: BPColors.textSecondary),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _openingDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365 * 30)),
            );
            if (picked != null) setState(() => _openingDate = picked);
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Publish time (your local time)', style: TextStyle(color: BPColors.textPrimary)),
          subtitle: Text(_openingTime.format(context), style: const TextStyle(color: BPColors.textSecondary)),
          trailing: const Icon(Icons.access_time, size: 18, color: BPColors.textSecondary),
          onTap: () async {
            final picked = await showTimePicker(context: context, initialTime: _openingTime);
            if (picked != null) setState(() => _openingTime = picked);
          },
        ),
        const SizedBox(height: 10),
        const Text('VISIBILITY', style: TextStyle(color: BPColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
        RadioListTile<String>(
          contentPadding: EdgeInsets.zero,
          activeColor: BPColors.yellow,
          value: 'public',
          groupValue: _visibility,
          onChanged: (v) => setState(() => _visibility = v!),
          title: const Text('Public on publish day', style: TextStyle(fontSize: 13, color: BPColors.textPrimary)),
        ),
        RadioListTile<String>(
          contentPadding: EdgeInsets.zero,
          activeColor: BPColors.yellow,
          value: 'private',
          groupValue: _visibility,
          onChanged: (v) => setState(() => _visibility = v!),
          title: const Text('Private link only', style: TextStyle(fontSize: 13, color: BPColors.textPrimary)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 2), child: const Text('BACK'))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(onPressed: () => setState(() => _step = 4), child: const Text('CONTINUE'))),
          ],
        ),
      ],
    );
  }

  Widget _buildPreviewStep() {
    return ListView(
      children: [
        const Text('This is the first visual identity of the capsule.', style: TextStyle(color: BPColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: BPColors.card, borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.sphere == 'orbit' ? 'TIME CAPSULE 2' : widget.sphere == 'hex' ? 'TIME CAPSULE 3' : 'TIME CAPSULE 1', style: const TextStyle(color: BPColors.yellow, fontSize: 9, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(_displayId, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(
                '"${_messageController.text.trim().isEmpty ? "Your message will appear here." : _messageController.text.trim()}"',
                style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, height: 1.4),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _previewFact('OWNER', _ownerController.text.trim().isEmpty ? '—' : _ownerController.text.trim())),
                  const SizedBox(width: 8),
                  Expanded(child: _previewFact('COUNTRY', _countryController.text.trim().isEmpty ? '—' : _countryController.text.trim())),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _previewFact('PUBLISHES', '${_openingDate.year}-${_openingDate.month.toString().padLeft(2, '0')}-${_openingDate.day.toString().padLeft(2, '0')}')),
                  const SizedBox(width: 8),
                  Expanded(child: _previewFact('VISIBILITY', _visibility == 'private' ? 'Private' : 'Public')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: BPColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: BPColors.yellow.withOpacity(0.3))),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: BPColors.yellow, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '"Save as locked" keeps this editable — nothing publishes yet. "Seal" locks it permanently and schedules it to publish on the display at the date/time above; it can no longer be edited afterward.',
                  style: TextStyle(color: BPColors.textSecondary, fontSize: 11, height: 1.35),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 3), child: const Text('BACK'))),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => _save(seal: false),
                child: const Text('SAVE AS LOCKED'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: _busy ? null : () => _save(seal: true),
          child: Text(_busy ? 'Saving...' : 'SEAL CAPSULE'),
        ),
      ],
    );
  }

  Widget _previewFact(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: BPColors.card, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: BPColors.textSecondary, fontSize: 7, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildCompleteStep() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(color: const Color(0xFF163F28), shape: BoxShape.circle, border: Border.all(color: const Color(0xFF2B7044))),
            child: const Icon(Icons.check, color: Color(0xFF7BED9B), size: 44),
          ),
          const SizedBox(height: 20),
          const Text('Capsule saved', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _readOnly || _justSealed
                  ? 'Scheduled to publish on the physical display on ${_openingDate.year}-${_openingDate.month.toString().padLeft(2, '0')}-${_openingDate.day.toString().padLeft(2, '0')} at ${_openingTime.format(context)} (your local time).'
                  : 'Still editable — nothing has published yet. Come back and "Seal" it when you\'re ready to schedule the publish.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: BPColors.textSecondary, fontSize: 12, height: 1.4),
            ),
          ),
          const SizedBox(height: 12),
          if (_ownerKey != null) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: BPColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFFD84D).withOpacity(0.3))),
              child: Column(
                children: [
                  const Text('OWNER KEY — SAVE THIS', style: TextStyle(color: Color(0xFFFFE78A), fontSize: 9, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  SelectableText(_ownerKey!, style: const TextStyle(fontFamily: 'monospace', fontSize: 15)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'This is the key for editing your capsule later. Keep it safe.',
                textAlign: TextAlign.center,
                style: TextStyle(color: BPColors.textSecondary, fontSize: 11),
              ),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(widget.sphere == 'orbit' ? 'RETURN TO TIME CAPSULE 2' : widget.sphere == 'hex' ? 'RETURN TO TIME CAPSULE 3' : 'RETURN TO TIME CAPSULE 1'),
          ),
        ],
      ),
    );
  }
}
