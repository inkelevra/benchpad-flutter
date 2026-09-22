import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../theme/neumorphic_theme.dart';
import '../services/benchpad_api.dart';
import '../widgets/home_back_leading.dart';

/// Roadmap screen — ported from benchpad-roadmap.html.
///
/// Shows: prototype readiness (7 owner-confirmed technical areas),
/// public network milestone (verified installations toward 30), progress
/// photo cards, and the installation register. If the account is an
/// owner account (checked via /api/owner-access/status), an editing
/// panel appears to publish, edit, and delete "Progress in pictures"
/// cards.
class RoadmapScreen extends StatefulWidget {
  const RoadmapScreen({super.key});

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen> {
  final _api = BenchpadApi();
  final _picker = ImagePicker();
  final _descriptionController = TextEditingController();
  RoadmapData? _data;
  String? _error;

  bool _isOwner = false;
  bool _showEditor = false;
  String? _editingId;
  XFile? _newPhoto;
  String? _editorMessage;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
    _checkOwner();
  }

  @override
  void dispose() {
    _api.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _checkOwner() async {
    final owner = await _api.getOwnerStatus();
    if (mounted) setState(() => _isOwner = owner);
  }

  Future<void> _load() async {
    try {
      final data = await _api.getRoadmap();
      if (mounted) setState(() { _data = data; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _startEdit(RoadmapCard card) {
    setState(() {
      _showEditor = true;
      _editingId = card.id;
      _descriptionController.text = card.description;
      _newPhoto = null;
      _editorMessage = 'Editing this card. Choose a new photo only if you want to replace it.';
    });
  }

  void _resetEditor([String? message]) {
    setState(() {
      _editingId = null;
      _descriptionController.clear();
      _newPhoto = null;
      _editorMessage = message;
    });
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _newPhoto = picked);
  }

  Future<void> _saveCard() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      setState(() => _editorMessage = 'Write a description.');
      return;
    }
    String? imageData;
    if (_newPhoto != null) {
      final bytes = await _newPhoto!.readAsBytes();
      imageData = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    } else if (_editingId == null) {
      setState(() => _editorMessage = 'Choose a photograph.');
      return;
    }
    setState(() { _saving = true; _editorMessage = _editingId != null ? 'Saving changes…' : 'Publishing…'; });
    try {
      await _api.saveRoadmapCard(id: _editingId, description: description, imageData: imageData ?? '');
      _resetEditor(_editingId != null ? 'Changes saved.' : 'Published.');
      await _load();
    } catch (e) {
      setState(() => _editorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteCard(RoadmapCard card) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeumorphicPalette.background,
        titleTextStyle: const TextStyle(color: NeumorphicPalette.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        contentTextStyle: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 14),
        title: const Text('Delete this card?'),
        content: const Text('This permanently removes the photograph too.', style: TextStyle(color: NeumorphicPalette.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: NeumorphicPalette.danger))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteRoadmapCard(card.id);
      if (_editingId == card.id) _resetEditor('Card deleted.');
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  /// Decodes a "data:image/...;base64,XXXX" string to bytes for Image.memory.
  Uint8List? _decodeDataUrl(String? dataUrl) {
    if (dataUrl == null) return null;
    final commaIndex = dataUrl.indexOf(',');
    if (commaIndex == -1) return null;
    try {
      return base64Decode(dataUrl.substring(commaIndex + 1));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
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
        appBar: AppBar(leading: Builder(builder: backLeading), leadingWidth: 64, centerTitle: true, title: const Text('Roadmap')),
        body: NotificationListener<OverscrollIndicatorNotification>(
          onNotification: (n) {
            n.disallowIndicator();
            return true;
          },
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'FROM PROTOTYPE TO PUBLIC NETWORK',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: NeumorphicPalette.textPrimary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'A simple visual record of the BenchPad project. Each update is one photograph with a short description beneath it.',
                  style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: NeumorphicPalette.danger))
                else if (data == null)
                  const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: NeumorphicPalette.accent)))
                else ...[
                  _buildMilestoneCards(data),
                  const SizedBox(height: 20),
                  _buildReadinessSection(data),
                  const SizedBox(height: 20),
                  if (_isOwner) ...[_buildOwnerPanel(), const SizedBox(height: 20)],
                  _buildCardsSection(data),
                  const SizedBox(height: 20),
                  _buildInstallationsSection(data),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMilestoneCards(RoadmapData data) {
    final overall = data.overallReadinessPercent;
    final networkFraction = data.target == 0 ? 0.0 : (data.verifiedCount / data.target).clamp(0, 1).toDouble();
    return Column(
      children: [
        _buildMilestoneCard(
          kicker: 'PROTOTYPE READINESS',
          title: 'First working BenchPad',
          value: '$overall%',
          progress: overall / 100,
          note: 'Calculated from seven owner-confirmed technical areas.',
          accent: NeumorphicPalette.accent,
        ),
        const SizedBox(height: 12),
        _buildMilestoneCard(
          kicker: 'PUBLIC NETWORK MILESTONE',
          title: 'Verified operational installations',
          value: '${data.verifiedCount} / ${data.target}',
          progress: networkFraction,
          note: data.verifiedCount >= data.target
              ? 'Milestone reached. Final activation remains subject to verification.'
              : 'Network-based functions remain locked.',
          accent: const Color(0xFFF1BC42),
        ),
      ],
    );
  }

  Widget _buildMilestoneCard({
    required String kicker,
    required String title,
    required String value,
    required double progress,
    required String note,
    required Color accent,
  }) {
    return NeumorphicBox(
      flat: true,
      borderRadius: 18,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(kicker, style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress.clamp(0, 1),
                minHeight: 8,
                backgroundColor: NeumorphicPalette.background,
                color: accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(note, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
          ],
        ),
    );
  }

  Widget _buildReadinessSection(RoadmapData data) {
    if (data.readiness.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Readiness breakdown', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ...data.readiness.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(width: 130, child: Text(r.label, style: const TextStyle(fontSize: 11))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: r.percent / 100,
                        minHeight: 6,
                        backgroundColor: NeumorphicPalette.background,
                        color: NeumorphicPalette.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(width: 36, child: Text('${r.percent}%', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11))),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildOwnerPanel() {
    return NeumorphicBox(
      flat: true,
      borderRadius: 18,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _showEditor = !_showEditor),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('OWNER · PUBLISH A PROGRESS CARD', style: TextStyle(color: NeumorphicPalette.accent, fontWeight: FontWeight.w800, fontSize: 11)),
                  ),
                  Icon(_showEditor ? Icons.expand_less : Icons.expand_more, color: NeumorphicPalette.accent),
                ],
              ),
            ),
            if (_showEditor) ...[
              const SizedBox(height: 12),
              if (_editingId != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: NeumorphicPalette.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Text('Editing an existing card', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 11)),
                ),
              OutlinedButton.icon(onPressed: _pickPhoto, icon: const Icon(Icons.photo_library_outlined), label: Text(_newPhoto != null ? 'Photo selected' : 'Choose photograph')),
              const SizedBox(height: 10),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveCard,
                      child: Text(_saving ? 'Saving…' : (_editingId != null ? 'SAVE CHANGES' : 'PUBLISH')),
                    ),
                  ),
                  if (_editingId != null) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(onPressed: _saving ? null : () => _resetEditor(), child: const Text('CANCEL')),
                  ],
                ],
              ),
              if (_editorMessage != null) ...[
                const SizedBox(height: 8),
                Text(_editorMessage!, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
              ],
            ],
          ],
        ),
    );
  }

  Widget _buildCardsSection(RoadmapData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Progress in pictures', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            _buildPill('${data.cards.length} ${data.cards.length == 1 ? "CARD" : "CARDS"}'),
          ],
        ),
        const SizedBox(height: 10),
        if (data.cards.isEmpty)
          _buildEmptyState('No roadmap photographs yet.')
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.78,
            ),
            itemCount: data.cards.length,
            itemBuilder: (context, i) {
              final card = data.cards[i];
              final bytes = _decodeDataUrl(card.imageData);
              return Container(
                decoration: BoxDecoration(
                  color: NeumorphicPalette.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 10,
                          child: bytes != null
                              ? Image.memory(bytes, fit: BoxFit.cover)
                              : Container(color: NeumorphicPalette.background),
                        ),
                        if (_isOwner)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Row(
                              children: [
                                _cardIconButton(Icons.edit_outlined, () => _startEdit(card)),
                                const SizedBox(width: 4),
                                _cardIconButton(Icons.delete_outline, () => _deleteCard(card), danger: true),
                              ],
                            ),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        card.description,
                        style: const TextStyle(fontSize: 11, color: NeumorphicPalette.textPrimary),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildInstallationsSection(RoadmapData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Public installation register', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            _buildPill('${data.installations.length} RECORDS'),
          ],
        ),
        const SizedBox(height: 10),
        if (data.installations.isEmpty)
          _buildEmptyState('No public installation records yet.')
        else
          ...data.installations.map((inst) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: NeumorphicBox(
                  flat: true,
                  borderRadius: 14,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(inst.benchId, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: NeumorphicPalette.textPrimary)),
                            const SizedBox(height: 3),
                            Text(
                              [inst.location, if (inst.siteType != null) inst.siteType!, if (inst.installedOn != null) inst.installedOn!].join(' · '),
                              style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildPill(inst.status),
                          const SizedBox(height: 4),
                          _buildPill(inst.verified ? 'VERIFIED' : 'NOT VERIFIED'),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
      ],
    );
  }

  Widget _cardIconButton(IconData icon, VoidCallback onTap, {bool danger = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), shape: BoxShape.circle),
        child: Icon(icon, size: 14, color: danger ? NeumorphicPalette.danger : Colors.white),
      ),
    );
  }

  Widget _buildPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: NeumorphicPalette.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: TextStyle(color: NeumorphicPalette.accent, fontSize: 9, fontWeight: FontWeight.w800)),
    );
  }

  Widget _buildEmptyState(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: NeumorphicPalette.background, borderRadius: BorderRadius.circular(14)),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12)),
    );
  }
}
