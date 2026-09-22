import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/benchpad_api.dart';
import '../theme/neumorphic_theme.dart';

/// Capsule Creator — multi-step capsule form, ported from
/// capsule-creator.html. Includes the Avatar step (preset emoji grid or
/// uploaded photo with zoom/X/Y crop sliders) — this is purely local
/// preview decoration in the PWA too, never sent to the server.
class CapsuleCreatorScreen extends StatefulWidget {
  final String type; // "core" | "standard"
  final int number;
  final String? ownerKey; // when provided (via Capsule Access), pre-authorizes editing an existing capsule

  const CapsuleCreatorScreen({super.key, required this.type, required this.number, this.ownerKey});

  @override
  State<CapsuleCreatorScreen> createState() => _CapsuleCreatorScreenState();
}

class _CapsuleCreatorScreenState extends State<CapsuleCreatorScreen> {
  final _api = BenchpadApi();
  final _picker = ImagePicker();

  int _step = 0; // 0..6, matches the PWA's 7 content steps
  static const _titles = ['Identity', 'Avatar', 'Message', 'Photograph', 'Opening rules', 'Preview', 'Complete'];

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
  File? _photo;

  bool _busy = false;
  String? _ownerKey;
  String? _existingImageData;
  bool _loadingExisting = true;
  bool _readOnly = false;

  String get _displayId => widget.type == 'core'
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
      final cell = await _api.getCell(type: widget.type, number: widget.number);
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

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  bool _validateStep() {
    if (_step == 0 && (_ownerController.text.trim().isEmpty || _countryController.text.trim().isEmpty)) {
      _toast('Add a name and country');
      return false;
    }
    if (_step == 2 && _messageController.text.trim().isEmpty) {
      _toast('Write a capsule message');
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
    if (_photo != null) {
      final bytes = await _photo!.readAsBytes();
      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    }
    return _existingImageData ?? '';
  }

  Future<void> _save({required bool seal}) async {
    setState(() => _busy = true);
    try {
      final result = await _api.saveCapsule(
        type: widget.type,
        number: widget.number,
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
        await _api.sealCapsule(type: widget.type, number: widget.number, accessKey: _ownerKey ?? '');
      }

      setState(() { _busy = false; _step = 6; });
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
        scaffoldBackgroundColor: NeumorphicPalette.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: NeumorphicPalette.background,
          foregroundColor: NeumorphicPalette.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(foregroundColor: NeumorphicPalette.textPrimary, disabledForegroundColor: NeumorphicPalette.textSecondary, side: const BorderSide(color: NeumorphicPalette.accent)),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: NeumorphicPalette.accent),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: NeumorphicPalette.background,
          labelStyle: const TextStyle(color: NeumorphicPalette.textSecondary),
          floatingLabelStyle: const TextStyle(color: NeumorphicPalette.accent),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NeumorphicPalette.shadowDark)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NeumorphicPalette.shadowDark)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NeumorphicPalette.accent, width: 1.5)),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text('Vault Sphere · Capsule Creator')),
        body: const Center(child: CircularProgressIndicator()),
      ));
    }
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
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(foregroundColor: NeumorphicPalette.textPrimary, disabledForegroundColor: NeumorphicPalette.textSecondary, side: const BorderSide(color: NeumorphicPalette.accent)),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: NeumorphicPalette.accent),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: NeumorphicPalette.background,
          labelStyle: const TextStyle(color: NeumorphicPalette.textSecondary),
          floatingLabelStyle: const TextStyle(color: NeumorphicPalette.accent),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NeumorphicPalette.shadowDark)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NeumorphicPalette.shadowDark)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NeumorphicPalette.accent, width: 1.5)),
        ),
      ),
      child: Scaffold(
      appBar: AppBar(title: const Text('Vault Sphere · Capsule Creator')),
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
                  decoration: BoxDecoration(color: NeumorphicPalette.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Text('This capsule is sealed and read-only.', style: TextStyle(color: NeumorphicPalette.danger, fontSize: 12)),
                ),
              if (_step < 6) ...[
                Row(
                  children: [
                    Text('STEP ${_step + 1} OF 6', style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Text(_displayId, style: const TextStyle(color: NeumorphicPalette.accent, fontSize: 11, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(_titles[_step], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(value: (_step + 1) / 6, minHeight: 5, backgroundColor: NeumorphicPalette.background, color: NeumorphicPalette.accent),
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
        return _buildMessageStep();
      case 3:
        return _buildPhotoStep();
      case 4:
        return _buildOpeningRulesStep();
      case 5:
        return _buildPreviewStep();
      default:
        return _buildCompleteStep();
    }
  }

  Widget _buildIdentityStep() {
    return ListView(
      children: [
        const Text('Your public name can be a real name or a pseudonym.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12)),
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
            style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12)),
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: NeumorphicPalette.accent.withOpacity(0.4), width: 2),
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
                  color: NeumorphicPalette.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: active ? NeumorphicPalette.accent : Colors.transparent, width: 1.5),
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
            style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10)),
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
        SizedBox(width: 90, child: Text(label, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 9, fontWeight: FontWeight.w800))),
        Expanded(child: Slider(value: value, min: min, max: max, onChanged: onChanged)),
      ],
    );
  }

  Widget _buildMessageStep() {
    return ListView(
      children: [
        const Text('This text becomes the heart of the capsule and can be shown on E-Ink when it opens.',
            style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12)),
        const SizedBox(height: 16),
        TextField(
          controller: _messageController,
          maxLines: 8,
          maxLength: 700,
          decoration: const InputDecoration(hintText: 'Write something worth carrying into the future...'),
        ),
        const SizedBox(height: 8),
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

  Widget _buildPhotoStep() {
    return ListView(
      children: [
        const Text('The photo is optional.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12)),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Container(
            decoration: BoxDecoration(color: NeumorphicPalette.background, borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: _photo != null
                ? Image.file(_photo!, fit: BoxFit.cover)
                : const Center(child: Icon(Icons.image_outlined, size: 40, color: NeumorphicPalette.textSecondary)),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: _pickPhoto, icon: const Icon(Icons.photo_library_outlined), label: const Text('Choose photo')),
        const SizedBox(height: 20),
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

  Widget _buildOpeningRulesStep() {
    return ListView(
      children: [
        const Text('Choose when the capsule opens and whether visitors may see it.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12)),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Opening date', style: TextStyle(color: NeumorphicPalette.textPrimary)),
          subtitle: Text('${_openingDate.year}-${_openingDate.month.toString().padLeft(2, '0')}-${_openingDate.day.toString().padLeft(2, '0')}', style: const TextStyle(color: NeumorphicPalette.textSecondary)),
          trailing: const Icon(Icons.calendar_today, size: 18, color: NeumorphicPalette.textSecondary),
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
          title: const Text('Opening time (your local time)', style: TextStyle(color: NeumorphicPalette.textPrimary)),
          subtitle: Text(_openingTime.format(context), style: const TextStyle(color: NeumorphicPalette.textSecondary)),
          trailing: const Icon(Icons.access_time, size: 18, color: NeumorphicPalette.textSecondary),
          onTap: () async {
            final picked = await showTimePicker(context: context, initialTime: _openingTime);
            if (picked != null) setState(() => _openingTime = picked);
          },
        ),
        const SizedBox(height: 10),
        const Text('VISIBILITY', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
        RadioListTile<String>(
          contentPadding: EdgeInsets.zero,
          value: 'public',
          groupValue: _visibility,
          onChanged: (v) => setState(() => _visibility = v!),
          title: const Text('Public on opening day', style: TextStyle(fontSize: 13)),
        ),
        RadioListTile<String>(
          contentPadding: EdgeInsets.zero,
          value: 'private',
          groupValue: _visibility,
          onChanged: (v) => setState(() => _visibility = v!),
          title: const Text('Private link only', style: TextStyle(fontSize: 13)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 3), child: const Text('BACK'))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(onPressed: () => setState(() => _step = 5), child: const Text('CONTINUE'))),
          ],
        ),
      ],
    );
  }

  Widget _buildPreviewStep() {
    return ListView(
      children: [
        const Text('This is the first visual identity of the capsule.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: NeumorphicPalette.background, borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('VAULT SPHERE', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 9, fontWeight: FontWeight.w800)),
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
                  Expanded(child: _previewFact('OPENS', '${_openingDate.year}-${_openingDate.month.toString().padLeft(2, '0')}-${_openingDate.day.toString().padLeft(2, '0')}')),
                  const SizedBox(width: 8),
                  Expanded(child: _previewFact('VISIBILITY', _visibility == 'private' ? 'Private' : 'Public')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 4), child: const Text('BACK'))),
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
      decoration: BoxDecoration(color: NeumorphicPalette.background, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 7, fontWeight: FontWeight.w800)),
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
          const SizedBox(height: 12),
          if (_ownerKey != null) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: NeumorphicPalette.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFFD84D).withOpacity(0.3))),
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
                style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11),
              ),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('RETURN TO VAULT SPHERE'),
          ),
        ],
      ),
    );
  }
}
