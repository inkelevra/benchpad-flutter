import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/benchpad_api.dart';
import '../theme/neumorphic_theme.dart';
import '../widgets/category_check_option.dart';
import '../widgets/glass_radio_selector.dart';
import '../widgets/glow_blob_field.dart';
import '../widgets/home_back_leading.dart';
import '../widgets/report_certificate.dart';

/// Report / Feedback — local issue reporting with photo, location,
/// privacy mode, and community confirm/follow, ported from
/// report-feedback.html.
///
/// Simplification note: the PWA's interactive Leaflet map for picking a
/// location point is replaced with three simpler location choices
/// (this BenchPad's fixed point, device GPS, or free text), and the
/// PWA's 4-step wizard is consolidated into one scrollable form (same
/// fields, same API) — see the note on BenchpadApi's local-reports
/// methods for the map simplification's own reasoning.
///
/// Field order deliberately does NOT match the PWA's step order —
/// photo first, privacy last right before submit, per explicit
/// request (found the PWA's own order — category+privacy first,
/// location+photo second — confusing).
class ReportFeedbackScreen extends StatefulWidget {
  const ReportFeedbackScreen({super.key});

  @override
  State<ReportFeedbackScreen> createState() => _ReportFeedbackScreenState();
}

class _ReportFeedbackScreenState extends State<ReportFeedbackScreen> {
  final _api = BenchpadApi();
  final _picker = ImagePicker();
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();
  String? _clientId;

  static const _types = ['Safety issue', 'Damaged BenchPad', 'Accessibility issue', 'Cleaning or maintenance', 'General feedback', 'Other'];
  String? _type;
  String _privacy = 'PUBLIC';
  String _locationMode = 'bench';
  String _location = 'This BenchPad · BP-AMS-001';
  double? _latitude = 52.3676;
  double? _longitude = 4.9041;
  XFile? _photo;
  bool _responseRequested = false;

  bool _submitting = false;
  final _certKey = GlobalKey();
  bool _exportingCert = false;
  Map<String, dynamic>? _lastReport;
  List<Map<String, dynamic>> _reports = [];
  String _tab = 'form';

  @override
  void initState() {
    super.initState();
    _initClientId();
  }

  @override
  void dispose() {
    _api.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _initClientId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('benchpad_report_client_id');
    if (id == null) {
      id = 'client-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}-${Random().nextInt(999999).toRadixString(36)}';
      await prefs.setString('benchpad_report_client_id', id);
    }
    if (mounted) setState(() => _clientId = id);
    _loadReports();
  }

  Future<void> _loadReports() async {
    if (_clientId == null) return;
    try {
      final reports = await _api.getLocalReports(_clientId!);
      if (mounted) setState(() => _reports = reports);
    } catch (_) {}
  }

  void _setLocationMode(String mode) {
    setState(() {
      _locationMode = mode;
      if (mode == 'bench') {
        _location = 'This BenchPad · BP-AMS-001';
        _latitude = 52.3676;
        _longitude = 4.9041;
      } else if (mode == 'text') {
        _location = '';
        _latitude = null;
        _longitude = null;
      }
    });
    if (mode == 'gps') _useGps();
  }

  Future<void> _useGps() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() => _locationMode = 'bench');
        _setLocationMode('bench');
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _location = 'Current GPS location';
      });
    } catch (_) {
      _setLocationMode('bench');
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 1500);
    if (picked != null) setState(() => _photo = picked);
  }

  Future<void> _submit() async {
    if (_type == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a report category')));
      return;
    }
    if (_responseRequested && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_emailController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a valid email address')));
      return;
    }
    setState(() => _submitting = true);
    try {
      String photoData = '';
      if (_photo != null) {
        final bytes = await _photo!.readAsBytes();
        photoData = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }
      final report = await _api.submitLocalReport(
        clientId: _clientId!,
        type: _type!,
        privacyMode: _privacy,
        location: _locationMode == 'text' ? _location : _location,
        latitude: _latitude,
        longitude: _longitude,
        description: _descriptionController.text.trim(),
        photoData: photoData,
        responseRequested: _responseRequested,
        contactEmail: _emailController.text.trim(),
      );
      setState(() {
        _lastReport = report;
        _tab = 'success';
      });
      await _loadReports();
      if (_responseRequested) _sendCertificateEmailAfterRender();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Report could not be sent: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Uint8List? _decodeDataUrl(String dataUrl) {
    final i = dataUrl.indexOf(',');
    if (i == -1) return null;
    try {
      return base64Decode(dataUrl.substring(i + 1));
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> _captureCertificateBytes() async {
    final boundary = _certKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('capture_failed');
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('encode_failed');
    return byteData.buffer.asUint8List();
  }

  /// Renders the certificate right after the success screen appears
  /// and sends it to the server so the reporter's confirmation email
  /// can attach the real certificate image (not just the photo).
  /// Silent best-effort — the report itself is already saved either
  /// way, so a failure here shouldn't alarm the person.
  Future<void> _sendCertificateEmailAfterRender() async {
    // Let the success screen actually build (and the certificate
    // widget lay out) before trying to capture it.
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    try {
      final bytes = await _captureCertificateBytes();
      final dataUrl = 'data:image/png;base64,${base64Encode(bytes)}';
      await _api.sendReportCertificateEmail(reportCode: '${_lastReport?['reportCode']}', certificateImageDataUrl: dataUrl);
    } catch (_) {
      // Best-effort — not shown to the user, the report itself already succeeded.
    }
  }

  Future<void> _exportCertificate() async {
    setState(() => _exportingCert = true);
    try {
      final bytes = await _captureCertificateBytes();
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: 'benchpad-report-${_lastReport?['reportCode'] ?? DateTime.now().millisecondsSinceEpoch}.png', mimeType: 'image/png')],
        subject: 'BenchPad Report Certificate',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _exportingCert = false);
    }
  }

  void _startNewReport() {
    setState(() {
      _tab = 'form';
      _lastReport = null;
      _type = null;
      _descriptionController.clear();
      _emailController.clear();
      _photo = null;
      _responseRequested = false;
    });
  }

  Future<void> _confirm(String reportCode, String signal) async {
    if (_clientId == null) return;
    try {
      await _api.confirmLocalReportSignal(clientId: _clientId!, reportCode: reportCode, signal: signal);
      await _loadReports();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Confirmation added')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Widget _sectionLabel(String text) => Text(text, style: const TextStyle(color: NeumorphicPalette.accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1));

  /// Colour for the description field's glow, keyed to the selected
  /// category so it's meaningful rather than purely decorative.
  Color _categoryColor(String? type) {
    switch (type) {
      case 'Safety issue':
        return const Color(0xFFE53935);
      case 'Damaged BenchPad':
        return const Color(0xFFFB8C00);
      case 'Accessibility issue':
        return const Color(0xFF1E88E5);
      case 'Cleaning or maintenance':
        return const Color(0xFF00897B);
      case 'General feedback':
        return NeumorphicPalette.accent;
      default:
        return const Color(0xFF8E8E93);
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
      ),
      child: Scaffold(
        appBar: AppBar(
          leading: Builder(builder: homeBackLeading),
          leadingWidth: 72,
          centerTitle: true,
          title: const Text('Report / Feedback'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: NeumorphicBox(
                pressed: true,
                borderRadius: 14,
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    Expanded(child: _tabButton('NEW REPORT', _tab != 'reports', () => setState(() => _tab = 'form'))),
                    Expanded(
                      child: _tabButton('MY REPORTS', _tab == 'reports', () {
                        setState(() => _tab = 'reports');
                        _loadReports();
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: NotificationListener<OverscrollIndicatorNotification>(
          onNotification: (n) {
            n.disallowIndicator();
            return true;
          },
          child: _tab == 'reports' ? _buildReportsList() : (_tab == 'success' ? _buildSuccess() : _buildForm()),
        ),
      ),
    );
  }

  Widget _tabButton(String label, bool selected, VoidCallback onTap) {
    return NeumorphicBox(
      soft: true,
      pressed: selected,
      borderRadius: 11,
      padding: const EdgeInsets.symmetric(vertical: 9),
      onTap: onTap,
      child: Center(child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: selected ? NeumorphicPalette.accent : NeumorphicPalette.textSecondary))),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Photo first — per explicit request, ahead of the PWA's own
        // step order (category/privacy first there).
        _sectionLabel('PHOTO'),
        const SizedBox(height: 8),
        if (_photo != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.file(File(_photo!.path), fit: BoxFit.cover),
              ),
            ),
          ),
        Row(
          children: [
            Expanded(child: _photoButton(Icons.camera_alt_outlined, 'Camera', () => _pickPhoto(ImageSource.camera))),
            const SizedBox(width: 10),
            Expanded(child: _photoButton(Icons.photo_library_outlined, 'Gallery', () => _pickPhoto(ImageSource.gallery))),
          ],
        ),
        const SizedBox(height: 22),
        _sectionLabel('LOCATION'),
        const SizedBox(height: 8),
        GlassRadioSelector(
          labels: const ['This BenchPad', 'My GPS location', 'Describe it'],
          selectedIndex: const ['bench', 'gps', 'text'].indexOf(_locationMode),
          onChanged: (i) => _setLocationMode(['bench', 'gps', 'text'][i]),
        ),
        const SizedBox(height: 10),
        if (_locationMode == 'text')
          NeumorphicBox(
            flat: true,
            borderRadius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: TextField(
              style: const TextStyle(fontSize: 13, color: NeumorphicPalette.textPrimary),
              decoration: const InputDecoration(
                hintText: 'e.g. Near the main entrance',
                hintStyle: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 13),
                border: InputBorder.none,
                filled: false,
              ),
              onChanged: (v) => _location = v,
            ),
          )
        else
          Text(_location, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12)),
        const SizedBox(height: 22),
        _sectionLabel('CATEGORY'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 2,
          crossAxisSpacing: 0,
          childAspectRatio: 0.85,
          children: _types.map((t) => Align(alignment: Alignment.topCenter, child: CategoryCheckOption(label: t, color: _categoryColor(t), selected: _type == t, onTap: () => setState(() => _type = t)))).toList(),
        ),
        const SizedBox(height: 22),
        _sectionLabel('DESCRIPTION'),
        const SizedBox(height: 8),
        GlowBlobField(
          color: _categoryColor(_type),
          borderRadius: 14,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: TextField(
              controller: _descriptionController,
              maxLines: 4,
              maxLength: 600,
              style: const TextStyle(fontSize: 13, color: NeumorphicPalette.textPrimary),
              decoration: const InputDecoration(
                hintText: 'What did you notice? Where exactly is it? What should be checked?',
                hintStyle: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 13),
                border: InputBorder.none,
                filled: false,
                counterStyle: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        NeumorphicBox(
          soft: true,
          borderRadius: 14,
          onTap: () => setState(() => _responseRequested = !_responseRequested),
          child: Row(
            children: [
              Icon(_responseRequested ? Icons.check_circle : Icons.circle_outlined, size: 20, color: _responseRequested ? NeumorphicPalette.accent : NeumorphicPalette.textSecondary),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('I would like a response', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NeumorphicPalette.textPrimary)),
                    Text('Add an email for a future reply. It will not appear publicly.', style: TextStyle(fontSize: 10, color: NeumorphicPalette.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_responseRequested) ...[
          const SizedBox(height: 10),
          NeumorphicBox(
            flat: true,
            borderRadius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: TextField(
              controller: _emailController,
              style: const TextStyle(fontSize: 13, color: NeumorphicPalette.textPrimary),
              decoration: const InputDecoration(
                hintText: 'you@example.com',
                hintStyle: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 13),
                border: InputBorder.none,
                filled: false,
              ),
            ),
          ),
        ],
        const SizedBox(height: 22),
        // Privacy last, right before submit — per explicit request.
        _sectionLabel('PRIVACY'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _privacyOption('Public report', 'May be shown after checks so others can confirm the issue.', _privacy == 'PUBLIC', () => setState(() => _privacy = 'PUBLIC'))),
            const SizedBox(width: 10),
            Expanded(child: _privacyOption('Confidential', 'Only visible to you and the responsible team.', _privacy == 'CONFIDENTIAL', () => setState(() => _privacy = 'CONFIDENTIAL'))),
          ],
        ),
        const SizedBox(height: 22),
        NeumorphicBox(
          borderRadius: 16,
          onTap: _submitting ? null : _submit,
          child: Center(
            child: Text(
              _submitting ? 'Sending...' : 'SUBMIT REPORT',
              style: TextStyle(color: _submitting ? NeumorphicPalette.textSecondary : NeumorphicPalette.accent, fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _photoButton(IconData icon, String label, VoidCallback onTap) {
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

  Widget _privacyOption(String title, String subtitle, bool selected, VoidCallback onTap) {
    return NeumorphicBox(
      soft: true,
      pressed: selected,
      borderRadius: 14,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: selected ? NeumorphicPalette.accent : NeumorphicPalette.textSecondary, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: selected ? NeumorphicPalette.accent : NeumorphicPalette.textPrimary))),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: NeumorphicPalette.textSecondary, height: 1.3)),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    final report = _lastReport;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 20),
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: NeumorphicPalette.success.withOpacity(0.15), shape: BoxShape.circle),
          child: const Icon(Icons.check, color: NeumorphicPalette.success, size: 34),
        ),
        const SizedBox(height: 18),
        const Center(child: Text('Report recorded', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary))),
        const SizedBox(height: 4),
        const Center(child: Text('Your report is stored and ready to follow.', style: TextStyle(fontSize: 12, color: NeumorphicPalette.textSecondary))),
        const SizedBox(height: 20),
        if (report != null) ...[
          ReportCertificate(
            boundaryKey: _certKey,
            reportCode: '${report['reportCode']}',
            submittedAt: DateTime.tryParse('${report['createdAt']}') ?? DateTime.now(),
            location: '${report['location']}',
            category: '${report['type']}',
            description: '${report['description'] ?? ''}',
            photoBytes: _decodeDataUrl('${report['photoData'] ?? ''}'),
          ),
          const SizedBox(height: 14),
          NeumorphicBox(
            soft: true,
            borderRadius: 14,
            onTap: _exportingCert ? null : _exportCertificate,
            child: Center(
              child: _exportingCert
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: NeumorphicPalette.accent))
                  : const Text('DOWNLOAD CERTIFICATE', style: TextStyle(color: NeumorphicPalette.accent, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ),
        ],
        const SizedBox(height: 20),
        NeumorphicBox(
          borderRadius: 16,
          onTap: _startNewReport,
          child: const Center(child: Text('SUBMIT ANOTHER', style: TextStyle(color: NeumorphicPalette.accent, fontWeight: FontWeight.w800, fontSize: 13))),
        ),
      ],
    );
  }

  Widget _buildReportsList() {
    return RefreshIndicator(
      onRefresh: _loadReports,
      child: _reports.isEmpty
          ? ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: Text('No reports recorded or followed on this device yet.', style: TextStyle(color: NeumorphicPalette.textSecondary))),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _reports.length,
              itemBuilder: (context, i) {
                final r = _reports[i];
                final code = r['reportCode'] as String? ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: NeumorphicBox(
                    flat: true,
                    borderRadius: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text('${r['type']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: NeumorphicPalette.textPrimary))),
                            Text('${r['status']}', style: const TextStyle(color: NeumorphicPalette.accent, fontSize: 10, fontWeight: FontWeight.w800)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('${r['location']} · $code', style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10)),
                        if ((r['description'] as String?)?.isNotEmpty == true) ...[
                          const SizedBox(height: 6),
                          Text('${r['description']}', style: const TextStyle(fontSize: 11, color: NeumorphicPalette.textPrimary)),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: NeumorphicBox(
                                soft: true,
                                borderRadius: 10,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                onTap: () => _confirm(code, 'SEE_TOO'),
                                child: const Center(child: Text('I SEE THIS TOO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary))),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: NeumorphicBox(
                                soft: true,
                                borderRadius: 10,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                onTap: () => _confirm(code, 'STILL_PRESENT'),
                                child: const Center(child: Text('STILL PRESENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary))),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
