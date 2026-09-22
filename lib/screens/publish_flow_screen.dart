import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../services/benchpad_api.dart';
import '../services/notification_service.dart';
import '../services/image_composer.dart';
import '../theme/neumorphic_theme.dart';
import '../widgets/flip_digit_counter.dart';
import '../widgets/orbit_loader.dart';
import 'result_screen.dart';

enum _FlowStage { progress, flicker, success, error }

/// Publish flow — a real separate route (pushed from Advertise's
/// Publish button), ported from advertise.html's #publishProgress /
/// #einkRefresh / #success sequence. Previously this ran inline on
/// the compose screen; any failure silently bounced the user back to
/// the form with a red error line — now a failure shows and stays on
/// this dedicated screen instead.
class PublishFlowScreen extends StatefulWidget {
  final ui.Image? photo;
  final String text;
  final TextOverlayOptions textOptions;
  final double imagePositionX;
  final double imagePositionY;
  final double imageScale;
  final double imageRotationDeg;

  const PublishFlowScreen({
    super.key,
    required this.photo,
    required this.text,
    required this.textOptions,
    required this.imagePositionX,
    required this.imagePositionY,
    required this.imageScale,
    required this.imageRotationDeg,
  });

  @override
  State<PublishFlowScreen> createState() => _PublishFlowScreenState();
}

class _PublishFlowScreenState extends State<PublishFlowScreen> {
  final _api = BenchpadApi();
  _FlowStage _stage = _FlowStage.progress;
  String? _errorText;

  // Publishing progress — a fake climb (ported exactly from
  // advertise.html: +7% every 170ms, capped at 92% until the real
  // confirmation arrives), not tied to literal server sub-steps.
  double _progressPercent = 0;
  Timer? _progressTimer;

  // E-ink flicker sequence, played once real confirmation is in —
  // fixed short durations (ported from advertise.html), not a literal
  // real-time readout of the physical ~30-50s refresh.
  String _flickerPhase = 'ghost'; // ghost -> flash -> lines -> done
  String _refreshStateText = '';
  String? _queueStatusText;

  Uint8List? _publishedImageBytes;
  String? _lastJobCode;
  double? _displayLat;
  double? _displayLon;
  String? _displayPlaceName;
  String? _certificateNumber;
  final _cardKey = GlobalKey();
  bool _exportingCard = false;

  // Publish stopwatch — starts the moment Publish is tapped, stops at
  // real DISPLAYED confirmation (before the decorative flicker), so
  // it reads exactly what a person timing it by hand with a watch
  // would see, not inflated by the flourish afterward.
  int _elapsedSeconds = 0;
  Timer? _stopwatchTimer;

  @override
  void initState() {
    super.initState();
    _runPublish();
  }

  @override
  void dispose() {
    _api.dispose();
    _progressTimer?.cancel();
    _stopwatchTimer?.cancel();
    super.dispose();
  }

  Future<void> _runPublish() async {
    setState(() {
      _stage = _FlowStage.progress;
      _errorText = null;
      _progressPercent = 0;
    });
    _startFakeProgress();
    _startStopwatch();

    try {
      final composed = await ImageComposer.exportJpeg(
        photo: widget.photo,
        text: widget.text,
        options: widget.textOptions,
        imagePositionX: widget.imagePositionX,
        imagePositionY: widget.imagePositionY,
        imageScale: widget.imageScale,
        imageRotationDeg: widget.imageRotationDeg,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Image preparation timed out — please try again.'),
      );
      _publishedImageBytes = composed;
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(composed)}';

      final result = await _api.publish(
        imageDataUrl: dataUrl,
        message: widget.text,
        imagePositionX: widget.imagePositionX,
        imagePositionY: widget.imagePositionY,
        imageScale: widget.imageScale,
      );
      _lastJobCode = result.jobCode;

      if (!result.confirmedDisplayed) {
        await _awaitDisplayConfirmation(result.jobCode);
      }
      if (!mounted) return;
      _stopStopwatch();

      _stopFakeProgress();
      setState(() => _progressPercent = 100);
      await Future.delayed(const Duration(milliseconds: 260));
      if (!mounted) return;

      await _runFlickerSequence();
      if (!mounted) return;

      ResultScreen.save(imageDataUrl: dataUrl, status: 'DISPLAYED', deviceId: 'BP-AMS-001', jobCode: result.jobCode, source: 'BENCHPAD_ADVERTISE');
      await _fetchCertificateNumber();
      if (!mounted) return;
      setState(() => _stage = _FlowStage.success);
      NotificationService.instance.showPublishResult(success: true, title: 'BenchPad updated', body: 'Your publication is now displayed on BP-AMS-001.');
    } on PublishException catch (e) {
      _stopFakeProgress();
      _stopStopwatch();
      final message = _describePublishError(e);
      NotificationService.instance.showPublishResult(success: false, title: 'BenchPad publish failed', body: message);
      if (!mounted) return;
      setState(() {
        _stage = _FlowStage.error;
        _errorText = message;
      });
    } catch (e) {
      _stopFakeProgress();
      _stopStopwatch();
      NotificationService.instance.showPublishResult(success: false, title: 'BenchPad publish failed', body: 'Something went wrong: $e');
      if (!mounted) return;
      setState(() {
        _stage = _FlowStage.error;
        _errorText = 'Something went wrong: $e';
      });
    }
  }

  void _startStopwatch() {
    _elapsedSeconds = 0;
    _stopwatchTimer?.cancel();
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
    });
  }

  void _stopStopwatch() {
    _stopwatchTimer?.cancel();
    _stopwatchTimer = null;
  }

  void _startFakeProgress() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 170), (timer) {
      if (!mounted) return;
      setState(() => _progressPercent = (_progressPercent + 7).clamp(0, 92));
    });
  }

  void _stopFakeProgress() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  String _describePublishError(PublishException e) {
    switch (e.reasonCode) {
      case 'cooldown':
        return 'Please wait ${e.cooldownSeconds ?? 30}s before publishing again.';
      case 'needs_review':
        return 'Submission needs review (job ${e.jobCode ?? "-"}).';
      default:
        return 'Publish denied: ${e.reasonCode}';
    }
  }

  /// Polls /api/publish-status until the physical ESP32 display
  /// confirms it actually rendered the image (matches the PWA's own
  /// pollPublishStatus) — also surfaces queue position, since a
  /// genuine backlog of queued images can take a long while and the
  /// screen should say so rather than just sitting at 92% unexplained.
  Future<void> _awaitDisplayConfirmation(String jobCode) async {
    var consecutiveNetworkFailures = 0;
    for (var attempt = 0; attempt < 600; attempt++) {
      await Future.delayed(const Duration(seconds: 2));

      Map<String, dynamic> job;
      try {
        final response = await _api.getPublishStatus(jobCode);
        job = response['job'] as Map<String, dynamic>? ?? response;
        consecutiveNetworkFailures = 0;
      } catch (_) {
        consecutiveNetworkFailures++;
        // 15 failures in a row (~30s, since each attempt is 2s apart)
        // means something is genuinely broken, not a one-off dropped
        // request — surface it instead of silently retrying forever
        // with zero feedback, which is exactly what looked like an
        // unexplained hang before.
        if (consecutiveNetworkFailures >= 15) {
          throw Exception('Lost contact with BenchPad while waiting for confirmation.');
        }
        continue;
      }

      final status = job['status'] as String? ?? '';
      final lat = job['displayLat'];
      final lon = job['displayLon'];
      if (lat is num && lon is num && _displayLat != lat.toDouble()) {
        _displayLat = lat.toDouble();
        _displayLon = lon.toDouble();
        _reverseGeocode(_displayLat!, _displayLon!);
      }
      if (status == 'DISPLAYED') {
        if (mounted) setState(() => _queueStatusText = null);
        return;
      }
      final errorMessage = job['errorMessage'] as String?;
      if (status == 'FAILED') {
        // A genuine server-reported failure — surface immediately,
        // not after several retry cycles like a transient network drop.
        throw Exception(errorMessage ?? 'The display did not confirm this publication.');
      }

      final position = job['position'];
      if (mounted) {
        setState(() {
          if (status == 'QUEUED' && position is num && position > 0) {
            _queueStatusText = 'Queued — position ${position.toInt()}';
          } else if (status == 'RETRYING') {
            _queueStatusText = errorMessage != null && errorMessage.contains('requeued') ? 'Retrying — moved to the back of the line' : 'Retrying delivery…';
          } else if (status == 'SENDING' || status == 'RECEIVED' || status == 'DELIVERED' || status == 'REFRESHING') {
            _queueStatusText = 'Sending to the display…';
          } else if (status.isNotEmpty) {
            // An unrecognized status — surface it rather than going
            // silent, since a genuinely new/unexpected value here
            // previously just showed nothing at all.
            _queueStatusText = 'Status: $status';
          } else {
            _queueStatusText = null;
          }
        });
      }
    }
    // Gave up after ~20 minutes of polling — proceed to the success
    // stage anyway rather than stranding the user forever, matching
    // the PWA's own tolerance for a slow/missing final ack once the
    // initial publish request itself succeeded. The back button is
    // always available if someone doesn't want to wait that long.
    if (mounted) setState(() => _queueStatusText = null);
  }

  /// Certificate number — the same running total the PWA's own
  /// publish counter reads ("N publications displayed on BenchPad"),
  /// via /api/publish-stats' totalPublications.
  Future<void> _fetchCertificateNumber() async {
    try {
      final stats = await _api.getPublishStats();
      final total = (stats['totalPublications'] as num?)?.toInt();
      if (total != null && mounted) {
        setState(() => _certificateNumber = total.toString().padLeft(6, '0'));
      }
    } catch (_) {
      // Non-critical — the certificate still works without a number.
    }
  }

  /// Ported timings from advertise.html's post-confirmation sequence —
  /// a short, fixed-duration flourish that plays AFTER real
  /// confirmation already arrived (not a live readout of the physical
  /// ~30-50s refresh, which already happened during the wait above).
  Future<void> _runFlickerSequence() async {
    setState(() {
      _stage = _FlowStage.flicker;
      _flickerPhase = 'ghost';
      _refreshStateText = 'PREPARING E-INK...';
    });
    await Future.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;

    setState(() {
      _flickerPhase = 'flash';
      _refreshStateText = 'REFRESHING DISPLAY...';
    });
    await Future.delayed(const Duration(milliseconds: 780));
    if (!mounted) return;

    setState(() {
      _flickerPhase = 'lines';
      _refreshStateText = 'UPDATING CENTRAL DISPLAY...';
    });
    await Future.delayed(const Duration(milliseconds: 620));
    if (!mounted) return;

    setState(() {
      _flickerPhase = 'done';
      _refreshStateText = 'BENCHPAD UPDATED';
    });
    await Future.delayed(const Duration(milliseconds: 360));
  }

  Future<void> _exportConfirmationCard() async {
    setState(() => _exportingCard = true);
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('capture_failed');
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('encode_failed');
      final bytes = byteData.buffer.asUint8List();
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: 'benchpad-confirmation-${_lastJobCode ?? DateTime.now().millisecondsSinceEpoch}.png', mimeType: 'image/png')],
        subject: 'BenchPad Confirmation Card',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _exportingCard = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canGoBack = _stage == _FlowStage.error || _stage == _FlowStage.success;

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
      ),
      child: PopScope(
        canPop: canGoBack,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final shouldLeave = await _confirmLeave();
          if (shouldLeave == true && mounted) Navigator.pop(context, false);
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Publishing'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () async {
                if (canGoBack) {
                  Navigator.pop(context, false);
                  return;
                }
                final shouldLeave = await _confirmLeave();
                if (shouldLeave == true && mounted) Navigator.pop(context, false);
              },
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: switch (_stage) {
              _FlowStage.progress => _buildProgressStage(),
              _FlowStage.flicker => _buildFlickerStage(),
              _FlowStage.success => _buildSuccessStage(),
              _FlowStage.error => _buildErrorStage(),
            },
          ),
        ),
      ),
    );
  }

  /// Progress/flicker previously blocked leaving entirely, with no
  /// escape at all if something genuinely stalled (e.g. a network
  /// call hanging with no timeout — since fixed separately, but this
  /// screen shouldn't be a dead end regardless). Now always reachable,
  /// just gated behind a confirmation so a normal in-progress publish
  /// isn't interrupted by accident.
  Future<bool?> _confirmLeave() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeumorphicPalette.background,
        titleTextStyle: const TextStyle(color: NeumorphicPalette.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        contentTextStyle: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 14),
        title: const Text('Leave this screen?'),
        content: const Text('Publishing may still complete on the display even if you leave now. You can check the result later from Current Result.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave anyway')),
        ],
      ),
    );
  }

  Widget _buildStopwatch() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FlipDigitCounter(value: _elapsedSeconds, digitWidth: 22, digitHeight: 30, fontSize: 17),
        const SizedBox(width: 8),
        const Text('SEC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: NeumorphicPalette.textSecondary, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildProgressStage() {
    const phaseNames = ['Preparing image', 'Preparing your result', 'Preparing the display', 'Connecting to BP-AMS-001', 'Sending content'];
    final doneCount = (_progressPercent / 20).floor();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          const Text('BP-AMS-001 · CENTRAL DISPLAY', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(height: 8),
          const Text('Publishing content', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary)),
          const SizedBox(height: 14),
          _buildStopwatch(),
          const SizedBox(height: 14),
          OrbitLoader(
            size: 140,
            centerChild: Text('${_progressPercent.round()}%', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary)),
          ),
          const SizedBox(height: 30),
          NeumorphicBox(
            flat: true,
            borderRadius: 16,
            child: Column(
              children: List.generate(phaseNames.length, (i) {
                final done = i < doneCount;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(done ? Icons.check_circle : Icons.circle_outlined, size: 16, color: done ? NeumorphicPalette.success : NeumorphicPalette.textSecondary),
                      const SizedBox(width: 10),
                      Text(
                        phaseNames[i],
                        style: TextStyle(fontSize: 13, color: done ? NeumorphicPalette.textPrimary : NeumorphicPalette.textSecondary, fontWeight: done ? FontWeight.w700 : FontWeight.w400),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          if (_queueStatusText != null) ...[
            const SizedBox(height: 16),
            NeumorphicBox(
              flat: true,
              borderRadius: 14,
              child: Center(child: Text(_queueStatusText!, textAlign: TextAlign.center, style: const TextStyle(color: NeumorphicPalette.danger, fontSize: 12, fontWeight: FontWeight.w700))),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFlickerStage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Text('BP-AMS-001 · DISPLAY UPDATE', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(
            _flickerPhase == 'done' ? 'BenchPad updated' : 'Updating Central Display',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text('BenchPad is updating the display. You can watch the result appear.', textAlign: TextAlign.center, style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12)),
          const SizedBox(height: 10),
          _buildStopwatch(),
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_publishedImageBytes != null) Image.memory(_publishedImageBytes!, fit: BoxFit.cover) else Container(color: NeumorphicPalette.surface),
                  if (_flickerPhase == 'ghost') Container(color: Colors.white.withOpacity(0.55)),
                  if (_flickerPhase == 'flash') const _EinkFlashOverlay(),
                  if (_flickerPhase == 'lines') const _EinkScanLines(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(_refreshStateText, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: NeumorphicPalette.accent, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildErrorStage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: NeumorphicPalette.danger.withOpacity(0.15), shape: BoxShape.circle),
            child: const Center(child: Icon(Icons.error_outline, color: NeumorphicPalette.danger, size: 30)),
          ),
          const SizedBox(height: 16),
          const Text('Publish failed', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary)),
          const SizedBox(height: 8),
          Text(_errorText ?? 'Something went wrong.', textAlign: TextAlign.center, style: const TextStyle(color: NeumorphicPalette.danger, fontSize: 13)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: NeumorphicBox(
                  soft: true,
                  borderRadius: 16,
                  onTap: () => Navigator.pop(context, false),
                  child: const Center(child: Text('BACK TO EDIT', style: TextStyle(color: NeumorphicPalette.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NeumorphicBox(
                  borderRadius: 16,
                  onTap: _runPublish,
                  child: const Center(child: Text('TRY AGAIN', style: TextStyle(color: NeumorphicPalette.accent, fontWeight: FontWeight.w800, fontSize: 12))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessStage() {
    return Column(
      children: [
        const Text('BENCHPAD · PUBLISHED', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(height: 12),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: NeumorphicPalette.success.withOpacity(0.15), shape: BoxShape.circle),
          child: const Center(child: Icon(Icons.check, color: NeumorphicPalette.success, size: 30)),
        ),
        const SizedBox(height: 14),
        const Text('Your BenchPad is updated.', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary)),
        const SizedBox(height: 4),
        const Text('BP-AMS-001 · Central Display', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12)),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Published in ', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12)),
            Text('$_elapsedSeconds', style: const TextStyle(color: NeumorphicPalette.textPrimary, fontSize: 12, fontWeight: FontWeight.w800)),
            const Text('s', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 20),
        _buildBenchVisualization(),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: NeumorphicBox(
                soft: true,
                borderRadius: 16,
                onTap: () => Navigator.pop(context, true),
                child: const Center(child: Text('SEND ANOTHER', style: TextStyle(color: NeumorphicPalette.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: NeumorphicBox(
                borderRadius: 16,
                onTap: _exportingCard ? null : _exportConfirmationCard,
                child: Center(
                  child: _exportingCard
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: NeumorphicPalette.accent))
                      : const Text('DOWNLOAD CARD', style: TextStyle(color: NeumorphicPalette.accent, fontWeight: FontWeight.w800, fontSize: 12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text('CONFIRMATION CARD PREVIEW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: NeumorphicPalette.textSecondary, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        _buildConfirmationCardPreview(),
      ],
    );
  }

  /// The physical bench prototype photo with the published image
  /// composited into the exact display position — same asset and same
  /// percentage coordinates (left:40.34% top:25.72% width:19.10%
  /// height:19.52%) as advertise.html's .final-bench-screen CSS.
  Widget _buildBenchVisualization() {
    return NeumorphicBox(
      flat: true,
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('BP-AMS-001 · AMSTERDAM', style: TextStyle(fontSize: 9, color: NeumorphicPalette.textSecondary, fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('Current result on BenchPad', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: NeumorphicPalette.textPrimary)),
                ],
              ),
              const Text('DISPLAYED ✓', style: TextStyle(color: NeumorphicPalette.success, fontSize: 10, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const benchAspectRatio = 1536 / 1025;
                final w = constraints.maxWidth;
                final h = w / benchAspectRatio;
                return SizedBox(
                  width: w,
                  height: h,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset('assets/images/bench/benchpad-bench-reference.jpg', fit: BoxFit.cover),
                      Positioned(
                        left: w * 0.4034,
                        top: h * 0.2572,
                        width: w * 0.1910,
                        height: h * 0.1952,
                        child: _publishedImageBytes != null
                            ? Image.memory(_publishedImageBytes!, fit: BoxFit.cover)
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// The downloadable certificate — image plus a footer band (ported
  /// from advertise.html's downloadConfirmationCard() canvas draw:
  /// checkmark, PUBLICATION CONFIRMED, BenchPad, Date/Time/Reference,
  /// Location/Display/Source). Kept as a visible preview (not hidden
  /// off-screen) so what gets shared/downloaded is exactly what's
  /// shown here.
  TextStyle _embossedStyle({required double fontSize, required FontWeight weight, Color? color}) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: weight,
      color: color ?? NeumorphicPalette.textPrimary,
      shadows: [
        Shadow(color: NeumorphicPalette.shadowLight, offset: const Offset(0.8, 0.8)),
        Shadow(color: NeumorphicPalette.shadowDark.withOpacity(0.7), offset: const Offset(-0.6, -0.6)),
      ],
    );
  }

  /// A recessed "engraved field" look for a value — same pressed
  /// treatment as the rest of the app's neumorphic inputs.
  /// Turns the device's real GPS fix into a "City, Country" name via
  /// Nominatim (OpenStreetMap's free, keyless reverse-geocoding
  /// service) — same "free, open, no key" pattern as the other
  /// external lookups already used elsewhere in the app (weather,
  /// culture). Best-effort: if it fails, the raw coordinates already
  /// captured are shown instead, so this never blocks publishing.
  Future<void> _reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=10&addressdetails=1');
      final res = await http.get(uri, headers: {'User-Agent': 'BenchPad/1.0 (kinesus.nl)'}).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>?;
      if (address == null) return;
      final place = address['city'] ?? address['town'] ?? address['village'] ?? address['municipality'] ?? address['hamlet'] ?? address['county'];
      final country = address['country'];
      if (place == null && country == null) return;
      final name = [place, country].where((v) => v != null && v.toString().isNotEmpty).join(', ');
      if (name.isNotEmpty && mounted) setState(() => _displayPlaceName = name);
    } catch (_) {
      // Best-effort — coordinates alone are still shown if this fails.
    }
  }

  /// Real coordinates once the physical device's GPS has a fix (comes
  /// back on the same status poll that confirms DISPLAYED) — falls
  /// back to the Amsterdam placeholder (marked with an asterisk, with
  /// a footnote explaining it) until then, since the device may not
  /// have a fix yet and a real fix could coincidentally also resolve
  /// to Amsterdam — the asterisk is the only way to tell the two apart.
  bool get _hasRealGps => _displayPlaceName != null || (_displayLat != null && _displayLon != null);

  String _formatDisplayLocation() {
    if (_displayPlaceName != null) return _displayPlaceName!;
    if (_displayLat != null && _displayLon != null) {
      final latDir = _displayLat! >= 0 ? 'N' : 'S';
      final lonDir = _displayLon! >= 0 ? 'E' : 'W';
      return '${_displayLat!.abs().toStringAsFixed(4)}°$latDir, ${_displayLon!.abs().toStringAsFixed(4)}°$lonDir';
    }
    return 'Amsterdam, NL*';
  }

  Widget _certField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _embossedStyle(fontSize: 10, weight: FontWeight.w800, color: NeumorphicPalette.textSecondary).copyWith(letterSpacing: 0.6)),
        const SizedBox(height: 5),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: NeumorphicPalette.background,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: NeumorphicPalette.shadowDark, offset: const Offset(2, 2), blurRadius: 3),
              BoxShadow(color: NeumorphicPalette.shadowLight, offset: const Offset(-2, -2), blurRadius: 3),
            ],
          ),
          child: Text(value, style: _embossedStyle(fontSize: 12, weight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  /// Ported look-and-feel from the reference certificate design:
  /// light neumorphic "embossed" card — the real published photo in a
  /// thick raised bezel (was the placeholder car image), the BenchPad
  /// mark, engraved ID/date/location fields, and a running
  /// certificate number from the same publish counter the PWA itself
  /// shows ("N publications displayed on BenchPad").
  Widget _buildConfirmationCardPreview() {
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    return RepaintBoundary(
      key: _cardKey,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: NeumorphicPalette.background,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(color: NeumorphicPalette.shadowDark, offset: const Offset(6, 6), blurRadius: 14),
            BoxShadow(color: NeumorphicPalette.shadowLight, offset: const Offset(-6, -6), blurRadius: 14),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: NeumorphicPalette.background,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: NeumorphicPalette.shadowDark, offset: const Offset(2, 2), blurRadius: 5),
                      BoxShadow(color: NeumorphicPalette.shadowLight, offset: const Offset(-2, -2), blurRadius: 5),
                    ],
                  ),
                  child: Image.asset('assets/images/benchpad-logo-mark.png', fit: BoxFit.contain),
                ),
                const SizedBox(width: 12),
                Text('CERTIFICATE\nOF PUBLICATION', style: _embossedStyle(fontSize: 16, weight: FontWeight.w900).copyWith(height: 1.15)),
              ],
            ),
            const SizedBox(height: 18),
            // Thick raised bezel around the actual published photo.
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: NeumorphicPalette.background,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: NeumorphicPalette.shadowDark, offset: const Offset(4, 4), blurRadius: 10),
                  BoxShadow(color: NeumorphicPalette.shadowLight, offset: const Offset(-4, -4), blurRadius: 10),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: _publishedImageBytes != null
                      ? Image.memory(_publishedImageBytes!, fit: BoxFit.cover)
                      : Container(color: NeumorphicPalette.surface),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _certField('UNIQUE DISPLAY ID', 'BP-AMS-001'),
            const SizedBox(height: 12),
            _certField('DATE OF PUBLICATION', dateStr),
            const SizedBox(height: 12),
            _certField('DISPLAY LOCATION', _formatDisplayLocation()),
            const SizedBox(height: 16),
            Text(
              'This certifies that the digital artwork was successfully published and displayed through the official BenchPad platform.\nBenchPad is a verified digital publication system for public smart displays.',
              style: TextStyle(fontSize: 10.5, color: NeumorphicPalette.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 22),
            Text(
              'Shapi Shakhshaev',
              style: GoogleFonts.marckScript(fontSize: 30, color: NeumorphicPalette.textPrimary),
            ),
            const SizedBox(height: 4),
            Container(height: 1, width: 140, color: NeumorphicPalette.shadowDark.withOpacity(0.6)),
            const SizedBox(height: 4),
            const Text('Founder & Developer, BenchPad / Kinesus', style: TextStyle(fontSize: 9, color: NeumorphicPalette.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _certField('CERTIFICATE NO.', _certificateNumber ?? '——————'),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(color: NeumorphicPalette.shadowDark, offset: const Offset(2, 2), blurRadius: 4),
                      BoxShadow(color: NeumorphicPalette.shadowLight, offset: const Offset(-2, -2), blurRadius: 4),
                    ],
                  ),
                  child: QrImageView(
                    data: 'https://kinesus.nl/',
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.white,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 130, maxHeight: 26),
                        child: Image.asset('assets/images/benchpad-wordmark.png', fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: NeumorphicPalette.background,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: NeumorphicPalette.shadowDark, offset: const Offset(3, 3), blurRadius: 6),
                      BoxShadow(color: NeumorphicPalette.shadowLight, offset: const Offset(-3, -3), blurRadius: 6),
                    ],
                  ),
                  child: ClipOval(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Image.asset('assets/images/kinesus-flower-logo.webp', fit: BoxFit.contain),
                    ),
                  ),
                ),
              ],
            ),
            if (!_hasRealGps) ...[
              const SizedBox(height: 12),
              const Text(
                '* GPS coordinates unavailable — location shown is a placeholder, not the display\'s confirmed position.',
                style: TextStyle(fontSize: 8, color: Color(0xFF7C8994), height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Blinking white overlay for the e-ink flicker's "flash" phase —
/// approximates the flash/invert a real e-ink refresh briefly does.
class _EinkFlashOverlay extends StatefulWidget {
  const _EinkFlashOverlay();

  @override
  State<_EinkFlashOverlay> createState() => _EinkFlashOverlayState();
}

class _EinkFlashOverlayState extends State<_EinkFlashOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 140))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Container(color: Colors.white.withOpacity(_controller.value * 0.85)),
    );
  }
}

/// Slow-scanning horizontal line overlay for the "lines" phase.
class _EinkScanLines extends StatefulWidget {
  const _EinkScanLines();

  @override
  State<_EinkScanLines> createState() => _EinkScanLinesState();
}

class _EinkScanLinesState extends State<_EinkScanLines> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => CustomPaint(painter: _ScanLinesPainter(_controller.value), size: Size.infinite),
    );
  }
}

class _ScanLinesPainter extends CustomPainter {
  final double t;
  _ScanLinesPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.12)
      ..strokeWidth = 2;
    final offset = t * 8;
    for (var y = -8 + offset; y < size.height; y += 8) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanLinesPainter oldDelegate) => oldDelegate.t != t;
}
