import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/benchpad_api.dart';
import '../theme/neumorphic_theme.dart';
import '../widgets/community_pulse_globe.dart';
import '../widgets/home_back_leading.dart';
import 'founding_certificates_admin_screen.dart';

/// Community — Founders Wall + Community Pulse globe, ported from
/// benchpad-community.html.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _api = BenchpadApi();
  final _picker = ImagePicker();
  final _ideaController = TextEditingController();
  final _contactController = TextEditingController();
  List<Map<String, dynamic>> _founders = [];
  String? _error;
  String? _ideaStatus;
  bool _ideaIsError = false;
  bool _sending = false;

  bool _isOwner = false;
  List<Map<String, dynamic>> _allFounders = [];
  bool _showEditor = false;
  String? _editingId;
  final _displayNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _messageController = TextEditingController();
  String _editTier = 'urban_hero';
  String _editStatus = 'draft';
  String _editReservation = 'reserved';
  bool _editConsent = false;
  bool _editCertificatePublic = false;
  XFile? _editImage;
  String? _editImageDataExisting;
  String? _ownerMsg;
  bool _savingFounder = false;

  List<Map<String, dynamic>> _pulseLocations = [];
  String? _pulseNotice;
  bool _globeInteracting = false;

  static const _tiers = {
    'urban_hero': ('Urban Heroes', Color(0xFFF0C45E)),
    'sustainability_champion': ('Sustainability Champions', Color(0xFF70DF78)),
    'founding_supporter': ('Founding Supporters', Color(0xFF75E7FF)),
  };

  @override
  void initState() {
    super.initState();
    _load();
    _checkOwner();
    _loadPulse();
  }

  Future<void> _loadPulse() async {
    try {
      final data = await _api.getCommunityPulse();
      if (!mounted) return;
      setState(() {
        _pulseLocations = (data['locations'] as List? ?? []).cast<Map<String, dynamic>>();
        _pulseNotice = data['configurationNotice'] as String?;
      });
    } catch (_) {
      if (mounted) setState(() => _pulseNotice = 'Community globe temporarily unavailable.');
    }
  }

  @override
  void dispose() {
    _api.dispose();
    _ideaController.dispose();
    _contactController.dispose();
    _displayNameController.dispose();
    _locationController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _checkOwner() async {
    final owner = await _api.getOwnerStatus();
    if (mounted) setState(() => _isOwner = owner);
    if (owner) _loadAllFounders();
  }

  Future<void> _loadAllFounders() async {
    try {
      final all = await _api.getAllFoundersForManagement();
      if (mounted) setState(() => _allFounders = all);
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final founders = await _api.getFounders();
      if (mounted) setState(() { _founders = founders; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _resetEditor() {
    setState(() {
      _editingId = null;
      _displayNameController.clear();
      _locationController.clear();
      _messageController.clear();
      _editTier = 'urban_hero';
      _editStatus = 'draft';
      _editReservation = 'reserved';
      _editConsent = false;
      _editCertificatePublic = false;
      _editImage = null;
      _editImageDataExisting = null;
      _ownerMsg = null;
    });
  }

  void _startEditFounder(Map<String, dynamic> f) {
    setState(() {
      _showEditor = true;
      _editingId = f['id']?.toString();
      _displayNameController.text = (f['displayName'] ?? '') as String;
      _locationController.text = (f['location'] ?? '') as String;
      _messageController.text = (f['message'] ?? '') as String;
      _editTier = (f['tier'] ?? 'urban_hero') as String;
      _editStatus = (f['status'] ?? 'draft') as String;
      _editReservation = (f['reservationStatus'] ?? 'reserved') as String;
      _editConsent = (f['consentConfirmed'] as bool?) ?? false;
      _editCertificatePublic = (f['certificatePublic'] as bool?) ?? false;
      _editImage = null;
      _editImageDataExisting = f['imageData'] as String?;
      _ownerMsg = null;
    });
  }

  Future<void> _pickFounderImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _editImage = picked);
  }

  Future<void> _saveFounder() async {
    setState(() { _savingFounder = true; _ownerMsg = 'Saving…'; });
    try {
      String imageData = _editImageDataExisting ?? '';
      if (_editImage != null) {
        final bytes = await _editImage!.readAsBytes();
        imageData = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }
      await _api.saveFounder(
        id: _editingId,
        fields: {
          'tier': _editTier,
          'status': _editStatus,
          'displayName': _displayNameController.text.trim(),
          'location': _locationController.text.trim(),
          'message': _messageController.text.trim(),
          'imageData': imageData,
          'consentConfirmed': _editConsent,
          'certificatePublic': _editCertificatePublic,
          'reservationStatus': _editReservation,
        },
      );
      _resetEditor();
      setState(() => _ownerMsg = 'Saved.');
      await _load();
      await _loadAllFounders();
    } catch (e) {
      setState(() => _ownerMsg = e.toString());
    } finally {
      if (mounted) setState(() => _savingFounder = false);
    }
  }

  Future<void> _quickStatus(Map<String, dynamic> f, String status) async {
    try {
      await _api.saveFounder(id: f['id']?.toString(), fields: {
        'tier': f['tier'],
        'status': status,
        'displayName': f['displayName'],
        'location': f['location'],
        'message': f['message'],
        'imageData': f['imageData'] ?? '',
        'consentConfirmed': status == 'published' ? true : (f['consentConfirmed'] ?? false),
        'certificatePublic': f['certificatePublic'] ?? false,
        'reservationStatus': f['reservationStatus'] ?? 'reserved',
      });
      await _load();
      await _loadAllFounders();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  Future<void> _deleteFounderRecord(Map<String, dynamic> f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeumorphicPalette.background,
        titleTextStyle: const TextStyle(color: NeumorphicPalette.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        contentTextStyle: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 14),
        title: const Text('Delete this founder record?'),
        content: const Text('Delete an unpublished record, or archive a previously published one.', style: TextStyle(color: NeumorphicPalette.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: NeumorphicPalette.danger))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteFounder(f['id']?.toString() ?? '');
      if (_editingId == f['id']?.toString()) _resetEditor();
      await _load();
      await _loadAllFounders();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  Future<void> _sendIdea() async {
    final message = _ideaController.text.trim();
    if (message.isEmpty) return;
    setState(() { _sending = true; _ideaStatus = 'Sending…'; _ideaIsError = false; });
    try {
      await _api.sendFeedback(message: message, contact: _contactController.text.trim());
      setState(() { _ideaStatus = 'Thanks for the idea!'; });
      _ideaController.clear();
      _contactController.clear();
    } catch (e) {
      setState(() { _ideaStatus = e.toString(); _ideaIsError = true; });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  List<Map<String, dynamic>> _byTier(String tier) => _founders.where((f) => f['tier'] == tier).toList();

  String _initials(String? name) {
    final n = (name ?? 'BP').trim();
    if (n.isEmpty) return 'BP';
    final parts = n.split(RegExp(r'\s+')).take(2);
    return parts.map((p) => p.isNotEmpty ? p[0] : '').join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final urbanHeroes = _byTier('urban_hero');
    final published = _founders.length;
    final certificates = _founders.where((f) => f['certificateUrl'] != null).length;

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
        appBar: AppBar(
          leading: Builder(builder: backLeading),
          leadingWidth: 64,
          centerTitle: true,
          title: const Text('Community'),
        ),
        body: NotificationListener<OverscrollIndicatorNotification>(
          onNotification: (n) {
            n.disallowIndicator();
            return true;
          },
          child: RefreshIndicator(
            onRefresh: () async {
              await _load();
              await _loadPulse();
            },
            child: ListView(
              physics: _globeInteracting ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                const Text('FOUNDERS WALL · VERIFIED SUPPORTERS', style: TextStyle(color: Color(0xFF9857E0), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
                const SizedBox(height: 6),
                const Text('THE FIRST PEOPLE BEHIND BENCHPAD', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary)),
                const SizedBox(height: 8),
                const Text(
                  'A permanent digital record for Founding Supporters, Sustainability Champions and Urban Heroes.',
                  style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 20),
                const Text('COMMUNITY PULSE', style: TextStyle(color: Color(0xFF2A9BB8), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                const SizedBox(height: 8),
                CommunityPulseGlobe(
                  locations: _pulseLocations,
                  emptyNotice: _pulseNotice,
                  onInteracting: (interacting) => setState(() => _globeInteracting = interacting),
                ),
                const SizedBox(height: 20),
                if (_error != null) Text(_error!, style: const TextStyle(color: NeumorphicPalette.danger)),
                if (_isOwner) ...[_buildOwnerPanel(), const SizedBox(height: 20)],
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
              childAspectRatio: 1.1,
              children: [
                _metric('PUBLISHED', '$published'),
                _metric('FIRST TWELVE', '${urbanHeroes.length} / 12'),
                _metric('CERTIFICATES', '$certificates'),
              ],
            ),
            const SizedBox(height: 20),
            const Text('THE FIRST TWELVE', style: TextStyle(color: Color(0xFFF0C45E), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
            const SizedBox(height: 4),
            const Text('Twelve permanent numbered positions. Unfilled positions remain reserved.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.85),
              itemCount: 12,
              itemBuilder: (context, i) {
                final n = i + 1;
                Map<String, dynamic>? found;
                for (final f in urbanHeroes) {
                  final match = RegExp(r'(\d+)').firstMatch('${f['founderNumber']}');
                  if (match != null && int.tryParse(match.group(1)!) == n) { found = f; break; }
                }
                final filled = found != null;
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: filled
                        ? null
                        : [
                            BoxShadow(color: NeumorphicPalette.shadowDark.withOpacity(0.55), offset: const Offset(3, 3), blurRadius: 6),
                            const BoxShadow(color: Colors.white, offset: Offset(-3, -3), blurRadius: 6),
                          ],
                    color: filled ? const Color(0xFFF0C45E).withOpacity(0.08) : NeumorphicPalette.background,
                    border: Border.all(color: filled ? const Color(0xFFF0C45E).withOpacity(0.4) : Colors.transparent),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(n.toString().padLeft(2, '0'), style: const TextStyle(color: Color(0xFFB88B2D), fontSize: 8, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled ? NeumorphicPalette.background : const Color(0xFFF0C45E).withOpacity(0.12),
                          border: filled ? null : Border.all(color: const Color(0xFFF0C45E).withOpacity(0.5), width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: filled
                            ? Text(_initials(found!['displayName'] as String?), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFB88B2D)))
                            : const Icon(Icons.person_outline, size: 20, color: Color(0xFFF0C45E)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        filled ? '${found!['displayName']}' : 'Reserved',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            ..._tiers.entries.map((entry) => _buildTierSection(entry.key, entry.value.$1, entry.value.$2)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFBD6CFF).withOpacity(0.06), borderRadius: BorderRadius.circular(14), border: const Border(left: BorderSide(color: Color(0xFFBD6CFF), width: 3))),
              child: const Text(
                "Privacy: a real name, nickname, image and optional location are published only with the participant's approval.",
                style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11),
              ),
            ),
            const SizedBox(height: 20),
            const Text('GOT AN IDEA?', style: TextStyle(color: Color(0xFF83CFE1), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
            const SizedBox(height: 4),
            const Text("Tell us what you'd like to see — goes straight to the BenchPad team.", style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12)),
            const SizedBox(height: 10),
            TextField(controller: _ideaController, maxLines: 4, maxLength: 2000, decoration: const InputDecoration(hintText: 'What would make BenchPad better?')),
            TextField(controller: _contactController, decoration: const InputDecoration(labelText: "Email (optional, if you'd like a reply)")),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: _sending ? null : _sendIdea, child: Text(_sending ? 'Sending…' : 'Send idea')),
            if (_ideaStatus != null) ...[
              const SizedBox(height: 8),
              Text(_ideaStatus!, style: TextStyle(color: _ideaIsError ? NeumorphicPalette.danger : const Color(0xFF9BDFF0), fontSize: 11)),
            ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOwnerPanel() {
    return NeumorphicBox(
      flat: true,
      borderRadius: 16,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _showEditor = !_showEditor),
              child: Row(
                children: [
                  const Expanded(child: Text('OWNER · MANAGE FOUNDERS', style: TextStyle(color: NeumorphicPalette.accent, fontWeight: FontWeight.w800, fontSize: 11))),
                  Icon(_showEditor ? Icons.expand_less : Icons.expand_more, color: NeumorphicPalette.accent),
                ],
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FoundingCertificatesAdminScreen())),
              icon: const Icon(Icons.workspace_premium_outlined, size: 16),
              label: const Text('MANAGE CERTIFICATE LINKS'),
            ),
            if (_showEditor) ...[
              const SizedBox(height: 12),
              if (_editingId != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: NeumorphicPalette.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Text('Editing an existing founder', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 11)),
                ),
              TextField(controller: _displayNameController, decoration: const InputDecoration(labelText: 'Display name')),
              const SizedBox(height: 8),
              TextField(controller: _locationController, decoration: const InputDecoration(labelText: 'Location')),
              const SizedBox(height: 8),
              TextField(controller: _messageController, maxLines: 3, decoration: const InputDecoration(labelText: 'Message')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                style: const TextStyle(color: NeumorphicPalette.textPrimary, fontSize: 14),
                dropdownColor: NeumorphicPalette.background,
                value: _editTier,
                decoration: const InputDecoration(labelText: 'Tier'),
                items: _tiers.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.$1, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (v) => setState(() => _editTier = v ?? 'urban_hero'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                style: const TextStyle(color: NeumorphicPalette.textPrimary, fontSize: 14),
                dropdownColor: NeumorphicPalette.background,
                value: _editStatus,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'draft', child: Text('Draft')),
                  DropdownMenuItem(value: 'published', child: Text('Published')),
                  DropdownMenuItem(value: 'archived', child: Text('Archived')),
                ],
                onChanged: (v) => setState(() => _editStatus = v ?? 'draft'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                style: const TextStyle(color: NeumorphicPalette.textPrimary, fontSize: 14),
                dropdownColor: NeumorphicPalette.background,
                value: _editReservation,
                decoration: const InputDecoration(labelText: 'Reservation status'),
                items: const [
                  DropdownMenuItem(value: 'reserved', child: Text('Reserved')),
                  DropdownMenuItem(value: 'confirmed', child: Text('Confirmed')),
                ],
                onChanged: (v) => setState(() => _editReservation = v ?? 'reserved'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: _pickFounderImage, icon: const Icon(Icons.photo_library_outlined), label: Text(_editImage != null ? 'Photo selected' : 'Choose photo')),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _editConsent,
                onChanged: (v) => setState(() => _editConsent = v ?? false),
                title: const Text('Consent confirmed', style: TextStyle(fontSize: 12, color: NeumorphicPalette.textPrimary)),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _editCertificatePublic,
                onChanged: (v) => setState(() => _editCertificatePublic = v ?? false),
                title: const Text('Certificate public', style: TextStyle(fontSize: 12, color: NeumorphicPalette.textPrimary)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _savingFounder ? null : _saveFounder,
                      child: Text(_savingFounder ? 'Saving…' : (_editingId != null ? 'SAVE FOUNDER' : 'ADD FOUNDER')),
                    ),
                  ),
                  if (_editingId != null) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(onPressed: _resetEditor, child: const Text('CANCEL')),
                  ],
                ],
              ),
              if (_ownerMsg != null) ...[
                const SizedBox(height: 8),
                Text(_ownerMsg!, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
              ],
              const SizedBox(height: 16),
              const Text('ALL FOUNDER RECORDS', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 9, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (_allFounders.isEmpty)
                const Text('No founder records yet.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12))
              else
                ..._allFounders.map((f) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: NeumorphicPalette.background, borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text('${f['displayName'] ?? 'Unnamed'}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                              Text('${f['status']}', style: const TextStyle(color: NeumorphicPalette.accent, fontSize: 10, fontWeight: FontWeight.w800)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (f['status'] != 'published')
                                TextButton(onPressed: () => _quickStatus(f, 'published'), child: const Text('PUBLISH')),
                              if (f['status'] == 'published')
                                TextButton(onPressed: () => _quickStatus(f, 'archived'), child: const Text('ARCHIVE')),
                              TextButton(onPressed: () => _startEditFounder(f), child: const Text('EDIT')),
                              TextButton(
                                onPressed: () => _deleteFounderRecord(f),
                                style: TextButton.styleFrom(foregroundColor: NeumorphicPalette.danger),
                                child: const Text('DELETE'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )),
            ],
          ],
        ),
    );
  }

  Widget _metric(String label, String value) {
    return Container(
      decoration: BoxDecoration(color: NeumorphicPalette.background, borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 7, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildTierSection(String tierKey, String title, Color color) {
    final items = _byTier(tierKey);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
              Text('${items.length} PUBLISHED', style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 9)),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: NeumorphicPalette.background, borderRadius: BorderRadius.circular(14)),
              child: const Text('No published profiles yet.', textAlign: TextAlign.center, style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12)),
            )
          else
            ...items.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: NeumorphicBox(
                    flat: true,
                    borderRadius: 14,
                    child: Row(
                      children: [
                        CircleAvatar(radius: 22, backgroundColor: NeumorphicPalette.background, child: Text(_initials(f['displayName'] as String?), style: TextStyle(color: color, fontSize: 12))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${f['displayName']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              if (f['location'] != null) Text('${f['location']}', style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10)),
                              if (f['message'] != null && (f['message'] as String).isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('"${f['message']}"', style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11, fontStyle: FontStyle.italic)),
                                ),
                            ],
                          ),
                        ),
                        Text('${f['founderNumber']}', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}
