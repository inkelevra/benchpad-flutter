import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'cookie_jar.dart';

/// Thrown when the backend rejects a publish (cooldown, moderation, etc).
/// Ported from the PWA's throw new Error("cooldown_..."/"needs_review_...")
/// pattern in advertise.html, but as a typed exception instead of parsing
/// error message strings.
class PublishException implements Exception {
  final String reasonCode;
  final int? cooldownSeconds;
  final String? jobCode;

  PublishException(this.reasonCode, {this.cooldownSeconds, this.jobCode});

  @override
  String toString() => 'PublishException($reasonCode)';
}

/// Result of a successful publish call.
class PublishResult {
  final String jobCode;
  final String? contentHash;
  final bool confirmedDisplayed;

  PublishResult({
    required this.jobCode,
    this.contentHash,
    this.confirmedDisplayed = false,
  });
}

/// One AI-generated text direction (Text AI mode) — headline/accent/subline.
class StudioTextDirection {
  final String label;
  final String main;
  final String accent;
  final String sub;

  StudioTextDirection({required this.label, required this.main, required this.accent, required this.sub});
}

/// One AI-generated image variant (Generate Image / Image Transform modes).
class StudioImageVariant {
  final String label;
  final String imageData; // base64 data URL

  StudioImageVariant({required this.label, required this.imageData});
}

/// One Time Capsule 1 cell (12 "core" pentagons + 150 "standard" hexagons).
/// Ported from the sphere payload in benchpad-time-capsule.html /
/// assets/time-capsule-store.js's describe()/normalizeRecord().
class VaultCell {
  final String type; // "core" | "standard"
  final int number;
  final String status; // "empty" | "locked" | "sealed" | "open"
  final String? ownerName;
  final String? ownerCountry;
  final String? message;
  final String? openingDate;
  final String? imageData;
  final String visibility;

  VaultCell({
    required this.type,
    required this.number,
    required this.status,
    this.ownerName,
    this.ownerCountry,
    this.message,
    this.openingDate,
    this.imageData,
    this.visibility = 'public',
  });

  /// Matches describe()'s displayId format: "BP-CORE-01" / "BP-TC-000001".
  String get displayId => type == 'core' ? 'BP-CORE-${number.toString().padLeft(2, '0')}' : 'BP-TC-${number.toString().padLeft(6, '0')}';

  factory VaultCell.fromJson(Map<String, dynamic> json) => VaultCell(
        type: (json['cellType'] ?? json['type'] ?? 'standard') as String,
        number: (json['cellNumber'] ?? json['number'] as num?)?.toInt() ?? 0,
        status: (json['status'] ?? 'empty') as String,
        ownerName: json['ownerName'] as String?,
        ownerCountry: json['ownerCountry'] as String?,
        message: json['message'] as String?,
        openingDate: json['openingDate'] as String?,
        imageData: json['imageData'] as String?,
        visibility: (json['visibility'] ?? 'public') as String,
      );
}

/// One display lock — which job currently owns a physical display.
class DisplayLock {
  final String deviceId;
  final String displayId;
  final String? currentJobCode;
  final String? visibleUntil;
  final String? lockExpiresAt;

  DisplayLock({required this.deviceId, required this.displayId, this.currentJobCode, this.visibleUntil, this.lockExpiresAt});

  factory DisplayLock.fromJson(Map<String, dynamic> json) => DisplayLock(
        deviceId: (json['deviceId'] ?? '') as String,
        displayId: (json['displayId'] ?? '') as String,
        currentJobCode: json['currentJobCode'] as String?,
        visibleUntil: json['visibleUntil'] as String?,
        lockExpiresAt: json['lockExpiresAt'] as String?,
      );
}

/// One publish job row (queue list). Ported from publish-jobs.html.
class PublishJobSummary {
  final String jobCode;
  final String source;
  final String deviceId;
  final String displayId;
  final int priority;
  final String status;
  final String? moderationStatus;
  final String? moderationReasonCode;
  final int minimumVisibleSeconds;
  final String? createdAt;
  final String? displayedAt;
  final String? visibleUntil;
  final String? completedAt;
  final int attemptCount;
  final String? receiverType;
  final String? contentText;
  final String contentHash;

  PublishJobSummary({
    required this.jobCode,
    required this.source,
    required this.deviceId,
    required this.displayId,
    required this.priority,
    required this.status,
    this.moderationStatus,
    this.moderationReasonCode,
    this.minimumVisibleSeconds = 60,
    this.createdAt,
    this.displayedAt,
    this.visibleUntil,
    this.completedAt,
    this.attemptCount = 0,
    this.receiverType,
    this.contentText,
    this.contentHash = '',
  });

  factory PublishJobSummary.fromJson(Map<String, dynamic> json) => PublishJobSummary(
        jobCode: (json['jobCode'] ?? '') as String,
        source: (json['source'] ?? '') as String,
        deviceId: (json['deviceId'] ?? '') as String,
        displayId: (json['displayId'] ?? '') as String,
        priority: (json['priority'] as num?)?.toInt() ?? 0,
        status: (json['status'] ?? '') as String,
        moderationStatus: json['moderationStatus'] as String?,
        moderationReasonCode: json['moderationReasonCode'] as String?,
        minimumVisibleSeconds: (json['minimumVisibleSeconds'] as num?)?.toInt() ?? 60,
        createdAt: json['createdAt'] as String?,
        displayedAt: json['displayedAt'] as String?,
        visibleUntil: json['visibleUntil'] as String?,
        completedAt: json['completedAt'] as String?,
        attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
        receiverType: json['receiverType'] as String?,
        contentText: json['contentText'] as String?,
        contentHash: (json['contentHash'] ?? '') as String,
      );
}

/// Full publish-jobs response: summary counts + locks + job list.
class PublishQueueData {
  final int queued, needsReview, liveNow, completed, failed, jobs24h;
  final String publicPublishing;
  final List<DisplayLock> locks;
  final List<PublishJobSummary> jobs;

  PublishQueueData({
    required this.queued,
    required this.needsReview,
    required this.liveNow,
    required this.completed,
    required this.failed,
    required this.jobs24h,
    required this.publicPublishing,
    required this.locks,
    required this.jobs,
  });

  factory PublishQueueData.fromJson(Map<String, dynamic> json) {
    final summary = (json['summary'] as Map<String, dynamic>?) ?? {};
    return PublishQueueData(
      queued: (summary['queued'] as num?)?.toInt() ?? 0,
      needsReview: (summary['needsReview'] as num?)?.toInt() ?? 0,
      liveNow: (summary['liveNow'] as num?)?.toInt() ?? 0,
      completed: (summary['completed'] as num?)?.toInt() ?? 0,
      failed: (summary['failed'] as num?)?.toInt() ?? 0,
      jobs24h: (summary['jobs24h'] as num?)?.toInt() ?? 0,
      publicPublishing: (json['publicPublishing'] as String?) ?? 'ACTIVE',
      locks: ((json['locks'] as List?) ?? []).map((e) => DisplayLock.fromJson(e as Map<String, dynamic>)).toList(),
      jobs: ((json['jobs'] as List?) ?? []).map((e) => PublishJobSummary.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

/// One item in the content moderation queue. Ported from
/// content-moderation.html.
class ModerationItem {
  final String jobCode;
  final String source;
  final String deviceId;
  final String displayId;
  final String status;
  final String? moderationStatus;
  final String? moderationReasonCode;
  final String? moderationNote;
  final String? contentText;
  final String? imageData;
  final String? createdAt;

  ModerationItem({
    required this.jobCode,
    required this.source,
    required this.deviceId,
    required this.displayId,
    required this.status,
    this.moderationStatus,
    this.moderationReasonCode,
    this.moderationNote,
    this.contentText,
    this.imageData,
    this.createdAt,
  });

  factory ModerationItem.fromJson(Map<String, dynamic> json) => ModerationItem(
        jobCode: (json['jobCode'] ?? '') as String,
        source: (json['source'] ?? '') as String,
        deviceId: (json['deviceId'] ?? '') as String,
        displayId: (json['displayId'] ?? '') as String,
        status: (json['status'] ?? '') as String,
        moderationStatus: json['moderationStatus'] as String?,
        moderationReasonCode: json['moderationReasonCode'] as String?,
        moderationNote: json['moderationNote'] as String?,
        contentText: json['contentText'] as String?,
        imageData: json['imageData'] as String?,
        createdAt: json['createdAt'] as String?,
      );
}

/// Moderation queue summary + items for the active tab.
class ModerationData {
  final int needsReview, autoApproved, manualApproved, rejected;
  final List<ModerationItem> items;

  ModerationData({required this.needsReview, required this.autoApproved, required this.manualApproved, required this.rejected, required this.items});

  factory ModerationData.fromJson(Map<String, dynamic> json) {
    final summary = (json['summary'] as Map<String, dynamic>?) ?? {};
    return ModerationData(
      needsReview: (summary['needsReview'] as num?)?.toInt() ?? 0,
      autoApproved: (summary['autoApproved'] as num?)?.toInt() ?? 0,
      manualApproved: (summary['manualApproved'] as num?)?.toInt() ?? 0,
      rejected: (summary['rejected'] as num?)?.toInt() ?? 0,
      items: ((json['items'] as List?) ?? []).map((e) => ModerationItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

/// Control Room summary — queued/review/live/completed/failed counts plus
/// the two toggle states (public publishing, AI moderation).
/// Ported from control-room.html's loadStats() + loadAIModerationStatus().
class ControlRoomStatus {
  final int queued;
  final int needsReview;
  final int liveNow;
  final int completed;
  final int failed;
  final String publicPublishing; // "ACTIVE" | "PAUSED"
  final String aiModeration; // "ACTIVE" | "DISABLED"

  ControlRoomStatus({
    required this.queued,
    required this.needsReview,
    required this.liveNow,
    required this.completed,
    required this.failed,
    required this.publicPublishing,
    required this.aiModeration,
  });
}

/// One roadmap progress card (photo + description).
/// Ported from the `evidence` items in benchpad-roadmap.html.
class RoadmapCard {
  final String id;
  final String? imageData;
  final String description;
  final String createdAt;

  RoadmapCard({
    required this.id,
    required this.description,
    this.imageData,
    this.createdAt = '',
  });

  factory RoadmapCard.fromJson(Map<String, dynamic> json) => RoadmapCard(
        id: json['id']?.toString() ?? '',
        imageData: json['imageData'] as String?,
        description: (json['description'] ?? json['title'] ?? 'Roadmap update') as String,
        createdAt: json['createdAt']?.toString() ?? '',
      );
}

/// One verified public installation record.
class InstallationRecord {
  final String benchId;
  final String location;
  final String? siteType;
  final String? installedOn;
  final String status;
  final bool verified;
  final String? imageData;

  InstallationRecord({
    required this.benchId,
    required this.location,
    required this.status,
    required this.verified,
    this.siteType,
    this.installedOn,
    this.imageData,
  });

  factory InstallationRecord.fromJson(Map<String, dynamic> json) => InstallationRecord(
        benchId: (json['benchId'] ?? '') as String,
        location: (json['location'] ?? '') as String,
        siteType: json['siteType'] as String?,
        installedOn: json['installedOn'] as String?,
        status: (json['status'] ?? '') as String,
        verified: json['verified'] == true,
        imageData: json['imageData'] as String?,
      );
}

/// One readiness area (e.g. "Firmware stability") with a percent complete.
class ReadinessItem {
  final String label;
  final int percent;

  ReadinessItem({required this.label, required this.percent});

  factory ReadinessItem.fromJson(Map<String, dynamic> json) => ReadinessItem(
        label: (json['label'] ?? '') as String,
        percent: (json['percent'] as num?)?.toInt() ?? 0,
      );
}

/// Full roadmap page data — readiness bars, network milestone, cards,
/// installations. Ported from GET /api/benchpad-world/roadmap.
class RoadmapData {
  final List<ReadinessItem> readiness;
  final List<RoadmapCard> cards;
  final List<InstallationRecord> installations;
  final int verifiedCount;
  final int target;

  RoadmapData({
    required this.readiness,
    required this.cards,
    required this.installations,
    required this.verifiedCount,
    required this.target,
  });

  int get overallReadinessPercent {
    if (readiness.isEmpty) return 0;
    final sum = readiness.fold<int>(0, (a, r) => a + r.percent);
    return (sum / readiness.length).round();
  }
}

/// Wraps every BenchPad backend endpoint the app needs.
///
/// Direct port of the fetch() calls found in advertise.html,
/// control-room.html and benchpad-roadmap.html — same endpoints, same
/// payload shapes — just typed and centralized instead of scattered
/// inline in <script> tags.
class BenchpadApi {
  BenchpadApi({http.Client? client}) : _client = client ?? PersistentCookieClient(http.Client());

  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${AppConfig.apiBaseUrl}$path')
        .replace(queryParameters: query);
  }

  // ---------------------------------------------------------------------
  // Advertise
  // ---------------------------------------------------------------------

  /// GET /api/publish-queue-status?deviceId=...
  Future<Map<String, dynamic>> getQueueStatus({
    String deviceId = AppConfig.defaultDeviceId,
  }) async {
    final res = await _client.get(
      _uri('/api/publish-queue-status', {'deviceId': deviceId}),
    );
    _throwIfNotOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// GET /api/publish-status?jobCode=...
  /// Used to poll a physical (ESP32) display until it actually shows the
  /// image, mirroring pollPublishStatus() in advertise.html.
  Future<Map<String, dynamic>> getPublishStatus(String jobCode) async {
    final res = await _client
        .get(_uri('/api/publish-status', {'jobCode': jobCode}))
        .timeout(const Duration(seconds: 15));
    _throwIfNotOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// GET /api/community-pulse — aggregated visitor settlement data
  /// (city/country/lat/lon/visitor count) for the Community Pulse globe.
  Future<Map<String, dynamic>> getCommunityPulse({int periodDays = 30}) async {
    final res = await _client.get(_uri('/api/community-pulse', {'period': '$periodDays'})).timeout(const Duration(seconds: 15));
    _throwIfNotOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// GET /api/community-pulse/visits?city=X&country=Y&period=N —
  /// individual visit timestamps for one city, shown when the person
  /// taps a city card in Community Pulse.
  Future<Map<String, dynamic>> getCommunityPulseVisits({
    required String city,
    required String country,
    int periodDays = 30,
  }) async {
    final res = await _client
        .get(_uri('/api/community-pulse/visits', {'city': city, 'country': country, 'period': '$periodDays'}))
        .timeout(const Duration(seconds: 15));
    _throwIfNotOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// GET /api/publish-queue/board — all currently-active publish jobs
  /// system-wide (not just this device's own), for the public
  /// airport-style publish queue board.
  Future<Map<String, dynamic>> getPublishQueueBoard({int limit = 50}) async {
    final res = await _client.get(_uri('/api/publish-queue/board', {'limit': '$limit'})).timeout(const Duration(seconds: 15));
    _throwIfNotOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// GET /api/publish-queue/check-slot?scheduledAt=... — the one
  /// physical display is shared by all three Time Capsules, so a
  /// scheduled moment taken from any of them must be checked against
  /// every other scheduled job, not just ones from the same sphere.
  Future<bool> checkSlotConflict(DateTime scheduledAt) async {
    final res = await _client.get(_uri('/api/publish-queue/check-slot', {'scheduledAt': scheduledAt.toUtc().toIso8601String()})).timeout(const Duration(seconds: 15));
    _throwIfNotOk(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['conflict'] == true;
  }

  /// POST /api/local-reports/certificate-email — sends the reporter's
  /// confirmation email with the real rendered certificate image (and
  /// the original evidence photo) attached, once the app has actually
  /// rendered the certificate widget to a PNG. Server can't do this
  /// itself (no DOM/canvas in a Worker).
  Future<void> sendReportCertificateEmail({required String reportCode, required String certificateImageDataUrl}) async {
    final res = await _client.post(
      _uri('/api/local-reports/certificate-email'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'reportCode': reportCode, 'certificateImageDataUrl': certificateImageDataUrl}),
    ).timeout(const Duration(seconds: 20));
    _throwIfNotOk(res);
  }

  /// GET /api/publish-stats
  Future<Map<String, dynamic>> getPublishStats() async {
    final res = await _client.get(_uri('/api/publish-stats'));
    _throwIfNotOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// POST /api/benchpad-ai/publish
  ///
  /// [imageDataUrl] must be a base64 data URL, e.g. "data:image/jpeg;base64,...",
  /// matching what canvas.toDataURL("image/jpeg", .82) produced in the PWA.
  Future<PublishResult> publish({
    required String imageDataUrl,
    required String message,
    double imagePositionX = 0,
    double imagePositionY = 0,
    double imageScale = 1,
    String deviceId = AppConfig.defaultDeviceId,
    String displayId = 'CENTRAL',
    DateTime? scheduledAt,
  }) async {
    final publicationText =
        message.trim().isEmpty ? 'Image-only BenchPad manual composition' : message.trim();

    final res = await _client
        .post(
          _uri('/api/benchpad-ai/publish'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'main': publicationText,
            'accent': '',
            'sub': '',
            'moderationImageData': imageDataUrl,
            'finalImageData': imageDataUrl,
            'photoIdentity': '',
            'imagePositionX': imagePositionX,
            'imagePositionY': imagePositionY,
            'imageScale': imageScale,
            'deviceId': deviceId,
            'displayId': displayId,
            'source': 'BENCHPAD_MANUAL',
            if (scheduledAt != null) 'scheduledAt': scheduledAt.toUtc().toIso8601String(),
          }),
        )
        .timeout(const Duration(seconds: 45));

    Map<String, dynamic>? result;
    try {
      result = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      result = null;
    }

    // The server reports cooldown/needs-review as non-2xx statuses
    // (e.g. 429 for cooldown), so these must be checked before the
    // generic status-code guard below — otherwise it always throws
    // first with a raw, unparsed error and this specific handling
    // never runs.
    if (result != null) {
      if (result['cooldown'] == true) {
        final seconds = (result['cooldownSeconds'] as num?)?.toInt() ?? 30;
        throw PublishException('cooldown', cooldownSeconds: seconds);
      }
      if (result['decision'] == 'NEEDS_REVIEW') {
        final jobCode = (result['job'] as Map?)?['jobCode'] as String?;
        throw PublishException('needs_review', jobCode: jobCode);
      }
    }

    _throwIfNotOk(res);

    if (result == null) {
      throw Exception('BenchPad API: invalid response body');
    }
    if (result['decision'] != 'APPROVED') {
      final reason = (result['reasonCode'] ?? result['diagnosticCode'] ?? 'publication_denied') as String;
      throw PublishException(reason);
    }

    final job = result['job'] as Map<String, dynamic>?;
    final confirmation = result['confirmation'] as Map<String, dynamic>?;

    if (job == null || job['jobCode'] == null) {
      throw PublishException('publish_missing_job_code');
    }

    if (confirmation != null) {
      if (confirmation['jobCode'] != job['jobCode']) {
        throw PublishException('publish_confirmation_job_mismatch');
      }
      if (confirmation['contentHash'] != job['contentHash']) {
        throw PublishException('publish_confirmation_hash_mismatch');
      }
      if (confirmation['status'] != 'DISPLAYED') {
        throw PublishException('publish_confirmation_not_displayed');
      }
      return PublishResult(
        jobCode: job['jobCode'] as String,
        contentHash: job['contentHash'] as String?,
        confirmedDisplayed: true,
      );
    }

    // No instant confirmation — physical (ESP32) receiver queued the job.
    // Caller should poll getPublishStatus(jobCode) until status == DISPLAYED.
    return PublishResult(
      jobCode: job['jobCode'] as String,
      contentHash: job['contentHash'] as String?,
      confirmedDisplayed: false,
    );
  }

  // ---------------------------------------------------------------------
  // Control Room — ported from control-room.html
  // ---------------------------------------------------------------------

  /// GET /api/publish-jobs?limit=1 (summary block) +
  /// GET /api/ai-moderation/status, combined into one typed status.
  Future<ControlRoomStatus> getControlRoomStatus() async {
    final jobsRes = await _client.get(_uri('/api/publish-jobs', {'limit': '1'}));
    _throwIfNotOk(jobsRes);
    final jobsData = jsonDecode(jobsRes.body) as Map<String, dynamic>;
    final summary = (jobsData['summary'] as Map<String, dynamic>?) ?? {};

    String aiModeration = 'DISABLED';
    try {
      final modRes = await _client.get(_uri('/api/ai-moderation/status'));
      if (modRes.statusCode >= 200 && modRes.statusCode < 300) {
        final modData = jsonDecode(modRes.body) as Map<String, dynamic>;
        if (modData['ok'] == true) aiModeration = (modData['status'] ?? 'DISABLED') as String;
      }
    } catch (_) {
      // Falls back to DISABLED, matches the PWA's silent catch(e){}.
    }

    return ControlRoomStatus(
      queued: (summary['queued'] as num?)?.toInt() ?? 0,
      needsReview: (summary['needsReview'] as num?)?.toInt() ?? 0,
      liveNow: (summary['liveNow'] as num?)?.toInt() ?? 0,
      completed: (summary['completed'] as num?)?.toInt() ?? 0,
      failed: (summary['failed'] as num?)?.toInt() ?? 0,
      publicPublishing: (jobsData['publicPublishing'] as String?) ?? 'ACTIVE',
      aiModeration: aiModeration,
    );
  }

  /// POST /api/public-publishing/toggle
  Future<String> togglePublicPublishing(String nextStatus) async {
    final res = await _client.post(
      _uri('/api/public-publishing/toggle'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'status': nextStatus}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(data['error'] ?? 'Failed');
    }
    return data['status'] as String;
  }

  /// POST /api/ai-moderation/toggle
  Future<String> toggleAiModeration(String nextStatus) async {
    final res = await _client.post(
      _uri('/api/ai-moderation/toggle'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'status': nextStatus}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(data['error'] ?? 'Failed');
    }
    return data['status'] as String;
  }

  /// POST /api/publish-jobs/cancel-source — emergency stop, cancels every
  /// queued job across all sources. Returns number cancelled.
  Future<int> emergencyStopAllQueued() async {
    final res = await _client.post(
      _uri('/api/publish-jobs/cancel-source'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] != true) {
      throw Exception(data['error'] ?? 'Failed to cancel queue');
    }
    return (data['cancelled'] as num?)?.toInt() ?? 0;
  }

  /// POST /api/publish-job/cancel — cancels a single queued/retrying
  /// publish job by its jobCode, unlike emergencyStopAllQueued() which
  /// clears the entire queue. Never touches a job already SENDING/
  /// DELIVERED/DISPLAYED — those finish or complete normally.
  Future<void> cancelSingleJob(String jobCode) async {
    final res = await _client.post(
      _uri('/api/publish-job/cancel'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'jobCode': jobCode}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] != true) {
      throw Exception(data['error'] ?? 'Could not remove job');
    }
  }

  /// POST /api/capsules/admin/debug-publish — force-runs the capsule
  /// auto-publish check immediately instead of waiting for the schedule.
  Future<Map<String, dynamic>> debugForceCapsulePublish() async {
    final res = await _client.post(_uri('/api/capsules/admin/debug-publish'));
    _throwIfNotOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------
  // Roadmap — ported from benchpad-roadmap.html
  // ---------------------------------------------------------------------

  Future<bool> getOwnerStatus() async {
    try {
      final res = await _client.get(_uri('/api/owner-access/status'));
      if (res.statusCode < 200 || res.statusCode >= 300) return false;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['owner'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveRoadmapCard({String? id, required String description, required String imageData}) async {
    final updating = id != null;
    final path = updating ? '/api/benchpad-world/roadmap/evidence?id=${Uri.encodeComponent(id)}' : '/api/benchpad-world/roadmap/evidence';
    final body = jsonEncode({
      'phase': 1,
      'category': 'Full Integration',
      'title': description.length > 60 ? '${description.substring(0, 60)}…' : description,
      'readinessPercent': 0,
      'verificationStatus': 'unverified',
      'visibility': 'published',
      'description': description,
      'imageData': imageData,
    });
    final res = updating
        ? await _client.put(_uri(path), headers: {'content-type': 'application/json'}, body: body)
        : await _client.post(_uri(path), headers: {'content-type': 'application/json'}, body: body);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(data['error'] ?? (updating ? 'Save failed' : 'Publish failed'));
    }
  }

  Future<void> deleteRoadmapCard(String id) async {
    final res = await _client.delete(_uri('/api/benchpad-world/roadmap/evidence?id=${Uri.encodeComponent(id)}'));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(data['error'] ?? 'Delete failed');
    }
  }

  /// GET /api/benchpad-world/roadmap
  Future<RoadmapData> getRoadmap() async {
    final res = await _client.get(_uri('/api/benchpad-world/roadmap'));
    _throwIfNotOk(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;

    final readiness = ((data['readiness'] as List?) ?? [])
        .map((e) => ReadinessItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final cards = ((data['evidence'] as List?) ?? [])
        .map((e) => RoadmapCard.fromJson(e as Map<String, dynamic>))
        .toList()
        // chronological(), matches the PWA's sort by createdAt ascending.
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final installations = ((data['installations'] as List?) ?? [])
        .map((e) => InstallationRecord.fromJson(e as Map<String, dynamic>))
        .toList();

    return RoadmapData(
      readiness: readiness,
      cards: cards,
      installations: installations,
      verifiedCount: (data['verifiedCount'] as num?)?.toInt() ?? 0,
      target: (data['target'] as num?)?.toInt() ?? 30,
    );
  }

  // ---------------------------------------------------------------------
  // AI Studio — ported from benchpad-ai.html
  // ---------------------------------------------------------------------

  /// POST /api/benchpad-ai/create-campaign — Text AI mode, returns up to
  /// 3 text directions (headline/accent/subline).
  Future<List<StudioTextDirection>> createCampaign({
    required String idea,
    String imageData = '',
    required String sessionId,
  }) async {
    final res = await _client.post(
      _uri('/api/benchpad-ai/create-campaign'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'idea': idea, 'imageData': imageData, 'sessionId': sessionId}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['decision'] == 'DENIED') {
      throw Exception(data['publicMessage'] ?? 'Content not approved');
    }
    if (res.statusCode < 200 || res.statusCode >= 300 || data['directions'] is! List) {
      throw Exception('server_unavailable');
    }
    final directions = (data['directions'] as List).take(3);
    return directions
        .map((v) => StudioTextDirection(
              label: (v['label'] ?? 'AI').toString().toUpperCase(),
              main: (v['main'] ?? '').toString(),
              accent: (v['accent'] ?? '').toString(),
              sub: (v['sub'] ?? '').toString(),
            ))
        .toList();
  }

  /// POST /api/benchpad-ai/transform-image — Image Transform mode.
  Future<List<StudioImageVariant>> transformImage({
    required String prompt,
    required String imageData,
    required String style,
    required int strength,
    required String target,
    required bool preserveSource,
    required bool preserveDisplays,
    required String sessionId,
    int variantCount = 1,
  }) async {
    final res = await _client.post(
      _uri('/api/benchpad-ai/transform-image'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'prompt': prompt,
        'imageData': imageData,
        'style': style,
        'strength': strength,
        'target': target,
        'preserveSource': preserveSource,
        'preserveDisplays': preserveDisplays,
        'sessionId': sessionId,
        'variantCount': variantCount == 4 ? 4 : 1,
      }),
    );
    return _parseImageVariants(res, variantCount);
  }

  /// POST /api/benchpad-ai/generate-image — Generate Image mode.
  Future<List<StudioImageVariant>> generateImage({
    required String prompt,
    required String style,
    required String sessionId,
    int variantCount = 1,
  }) async {
    final res = await _client.post(
      _uri('/api/benchpad-ai/generate-image'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'prompt': prompt,
        'style': style,
        'sessionId': sessionId,
        'variantCount': variantCount == 4 ? 4 : 1,
      }),
    );
    return _parseImageVariants(res, variantCount);
  }

  List<StudioImageVariant> _parseImageVariants(http.Response res, int variantCount) {
    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}
    if (res.statusCode < 200 || res.statusCode >= 300 || data['decision'] != 'APPROVED') {
      throw Exception(data['publicMessage'] ?? data['message'] ?? 'The AI engine is unavailable.');
    }
    final expected = variantCount == 4 ? 4 : 1;
    final variants = data['variants'];
    if (variants is! List || variants.length != expected) {
      throw Exception('The image engine returned ${variants is List ? variants.length : 0} of $expected expected result(s).');
    }
    return variants
        .asMap()
        .entries
        .map((e) => StudioImageVariant(
              label: (e.value['label'] ?? 'AI VARIANT ${e.key + 1}').toString().toUpperCase(),
              imageData: (e.value['imageData'] ?? '').toString(),
            ))
        .toList();
  }

  /// POST /api/benchpad-ai/publish — same endpoint as Advertise's publish,
  /// but Studio builds a richer payload (main/accent/sub, source tag per
  /// mode). Kept as a raw-payload method here since the three modes shape
  /// the body differently.
  Future<PublishResult> aiPublish(Map<String, dynamic> payload) async {
    final res = await _client.post(
      _uri('/api/benchpad-ai/publish'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(payload),
    );
    _throwIfNotOk(res);
    final result = jsonDecode(res.body) as Map<String, dynamic>;

    if (result['cooldown'] == true) {
      final seconds = (result['cooldownSeconds'] as num?)?.toInt() ?? 30;
      throw PublishException('cooldown', cooldownSeconds: seconds);
    }
    if (result['decision'] == 'NEEDS_REVIEW') {
      final jobCode = (result['job'] as Map?)?['jobCode'] as String?;
      throw PublishException('needs_review', jobCode: jobCode);
    }
    if (result['decision'] != 'APPROVED') {
      final reason = (result['reasonCode'] ?? result['diagnosticCode'] ?? result['publicMessage'] ?? 'publication_denied') as String;
      throw PublishException(reason);
    }

    final job = result['job'] as Map<String, dynamic>?;
    final confirmation = result['confirmation'] as Map<String, dynamic>?;
    if (job == null || job['jobCode'] == null) {
      throw PublishException('publish_missing_job_code');
    }
    if (confirmation != null && confirmation['status'] == 'DISPLAYED') {
      return PublishResult(jobCode: job['jobCode'] as String, contentHash: job['contentHash'] as String?, confirmedDisplayed: true);
    }
    return PublishResult(jobCode: job['jobCode'] as String, contentHash: job['contentHash'] as String?, confirmedDisplayed: false);
  }

  // ---------------------------------------------------------------------
  // Capsules / Time Capsule 1 — ported from benchpad-time-capsule.html,
  // capsule-creator.html, assets/time-capsule-store.js addressing scheme.
  // ---------------------------------------------------------------------

  /// GET /api/capsules/sphere?sphere=vault — all cell statuses in the
  /// Vault (12 "core" + 150 "standard" cells).
  Future<List<VaultCell>> getVaultCells() async {
    final res = await _client.get(_uri('/api/capsules/sphere', {'sphere': 'vault'}));
    _throwIfNotOk(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (data['capsules'] as List?) ?? [];
    return list.map((e) => VaultCell.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /api/capsules/cell?sphere=...&type=...&number=... — single
  /// cell detail (used before opening the creator, to know if it's
  /// empty/locked/sealed/open). sphere defaults to 'vault' (Time
  /// Capsule 1); pass 'orbit' for a Time Capsule 2 (Time Capsule 2)
  /// position.
  Future<Map<String, dynamic>> getCell({required String type, required int number, String sphere = 'vault'}) async {
    final res = await _client.get(_uri('/api/capsules/cell', {'sphere': sphere, 'type': type, 'number': '$number'}));
    _throwIfNotOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// POST /api/capsules/save — create/update a capsule draft (status
  /// becomes "locked" unless immediately sealed). On first save for a
  /// position with no existing row, the server auto-generates and
  /// returns an access key (`issuedAccessKey`) — this is also how an
  /// owner can pre-reserve an empty position for someone else: save
  /// with blank name/message under an owner session, capture the
  /// returned key, hand it to that person.
  /// Turns a capsule API error code into a message that actually says
  /// what to do next, instead of the bare code — invalid_access_key in
  /// particular was showing up with zero context.
  String _friendlyCapsuleError(String? code) {
    switch (code) {
      case 'capsule_sealed_read_only':
        return 'This capsule is already sealed';
      case 'invalid_access_key':
        return 'This position\'s access key isn\'t remembered on this device (reserved elsewhere, or before this device started remembering keys). Use the code under "My Capsule" in Profile, or Owner access, to continue it.';
      case 'message_and_opening_date_required':
        return 'Add a written message before sealing — a photo alone isn\'t enough.';
      default:
        return code ?? 'Could not save';
    }
  }

  Future<Map<String, dynamic>> saveCapsule({
    required String type,
    required int number,
    String sphere = 'vault',
    String accessKey = '',
    required String ownerName,
    required String ownerCountry,
    required String message,
    required String openingDateIso,
    required String visibility,
    String imageData = '',
  }) async {
    final res = await _client.post(
      _uri('/api/capsules/save'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'sphere': sphere,
        'type': type,
        'number': number,
        'accessKey': accessKey,
        'ownerName': ownerName,
        'ownerCountry': ownerCountry,
        'message': message,
        'openingDate': openingDateIso,
        'visibility': visibility,
        'einkDay': true,
        'consent': true,
        'backupText': '',
        if (imageData.isNotEmpty) 'imageData': imageData,
      }),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_friendlyCapsuleError(data['error'] as String?));
    }
    return data;
  }

  /// POST /api/capsules/seal — locks the capsule permanently and schedules
  /// its auto-publish on the opening date.
  Future<void> sealCapsule({required String type, required int number, required String accessKey, String sphere = 'vault'}) async {
    final res = await _client.post(
      _uri('/api/capsules/seal'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'sphere': sphere, 'type': type, 'number': number, 'accessKey': accessKey}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(_friendlyCapsuleError(data['error'] as String?));
    }
  }

  /// POST /api/capsules/unlock — verifies an Owner Key against a locked
  /// cell (empty accessKey checks for owner-bypass on server side).
  Future<bool> unlockCapsule({required String type, required int number, required String accessKey, String sphere = 'vault'}) async {
    final res = await _client.post(
      _uri('/api/capsules/unlock'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'sphere': sphere, 'type': type, 'number': number, 'accessKey': accessKey}),
    );
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  /// POST /api/capsules/find-by-key — locate a capsule by its Owner Key
  /// alone (Capsule Access screen), without knowing the cell in advance.
  Future<Map<String, dynamic>> findCapsuleByKey(String accessKey) async {
    final res = await _client.post(
      _uri('/api/capsules/find-by-key'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'accessKey': accessKey}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(data['error'] ?? 'Capsule not found');
    }
    return data;
  }

  /// GET /api/publish-jobs?limit=... — full queue list + display locks +
  /// summary, used by the Publish Queue screen (control-room.html's
  /// summary is a subset of this).
  Future<PublishQueueData> getPublishJobs({int limit = 80}) async {
    final res = await _client.get(_uri('/api/publish-jobs', {'limit': '$limit'}));
    _throwIfNotOk(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return PublishQueueData.fromJson(data);
  }

  /// GET /api/publish-job?jobCode=... — single job detail including the
  /// full image preview (fetched lazily, only when a job card is opened).
  Future<Map<String, dynamic>> getPublishJobDetail(String jobCode) async {
    final res = await _client.get(_uri('/api/publish-job', {'jobCode': jobCode}));
    _throwIfNotOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// POST /api/publish-queue/tick — manually advances the queue processor
  /// instead of waiting for its normal schedule.
  Future<void> tickPublishQueue() async {
    final res = await _client.post(_uri('/api/publish-queue/tick'));
    _throwIfNotOk(res);
  }

  /// GET /api/moderation/items?status=... — moderation queue items for
  /// one tab (NEEDS_REVIEW / REJECTED / APPROVED).
  Future<ModerationData> getModerationItems(String status) async {
    final res = await _client.get(_uri('/api/moderation/items', {'status': status}));
    _throwIfNotOk(res);
    return ModerationData.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// POST /api/moderation/decision — approve / request changes / reject
  /// a job awaiting manual review.
  Future<void> moderationDecision({required String jobCode, required String action, String reason = ''}) async {
    final res = await _client.post(
      _uri('/api/moderation/decision'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'jobCode': jobCode, 'action': action, 'reason': reason}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(data['error'] ?? 'Decision failed');
    }
  }

  // ---------------------------------------------------------------------
  // Platform Access — ported from access-control.html
  // ---------------------------------------------------------------------

  Future<Map<String, dynamic>> getPlatformAccessStatus() async {
    final res = await _client.get(_uri('/api/platform-access/status'));
    _throwIfNotOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getTrustedDevices() async {
    final res = await _client.get(_uri('/api/platform-access/devices'));
    _throwIfNotOk(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return ((data['devices'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getAccessActivity() async {
    final res = await _client.get(_uri('/api/platform-access/activity'));
    _throwIfNotOk(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return ((data['events'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  Future<void> trustThisDevice(String displayName) async {
    final res = await _client.post(_uri('/api/platform-access/trust'), headers: {'content-type': 'application/json'}, body: jsonEncode({'displayName': displayName}));
    _throwIfNotOk(res);
  }

  Future<String> createRecoveryCode() async {
    final res = await _client.post(_uri('/api/platform-access/recovery/create'), headers: {'content-type': 'application/json'}, body: '{}');
    _throwIfNotOk(res);
    return (jsonDecode(res.body) as Map<String, dynamic>)['recoveryCode'] as String;
  }

  Future<void> setPlatformMode(String mode) async {
    final res = await _client.post(_uri('/api/platform-access/mode'), headers: {'content-type': 'application/json'}, body: jsonEncode({'mode': mode}));
    _throwIfNotOk(res);
  }

  Future<Map<String, dynamic>> preparePrivateMode() async {
    final res = await _client.post(_uri('/api/platform-access/private/prepare'), headers: {'content-type': 'application/json'}, body: '{}');
    _throwIfNotOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> confirmPrivateMode(String challenge) async {
    final res = await _client.post(_uri('/api/platform-access/private/confirm'), headers: {'content-type': 'application/json'}, body: jsonEncode({'challenge': challenge}));
    _throwIfNotOk(res);
  }

  Future<String> temporaryPublicAccess(int minutes) async {
    final res = await _client.post(_uri('/api/platform-access/temporary-public'), headers: {'content-type': 'application/json'}, body: jsonEncode({'minutes': minutes}));
    _throwIfNotOk(res);
    return (jsonDecode(res.body) as Map<String, dynamic>)['publicUntil'] as String;
  }

  Future<String> createGuestLink({required int minutes, required bool singleUse, required String label}) async {
    final res = await _client.post(
      _uri('/api/platform-access/guest-link'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'minutes': minutes, 'singleUse': singleUse, 'label': label}),
    );
    _throwIfNotOk(res);
    return (jsonDecode(res.body) as Map<String, dynamic>)['link'] as String;
  }

  Future<void> revokeDevice(String deviceId) async {
    final res = await _client.post(_uri('/api/platform-access/device/revoke'), headers: {'content-type': 'application/json'}, body: jsonEncode({'deviceId': deviceId}));
    _throwIfNotOk(res);
  }

  Future<void> revokeOtherDevices() async {
    final res = await _client.post(_uri('/api/platform-access/device/revoke-others'), headers: {'content-type': 'application/json'}, body: '{}');
    _throwIfNotOk(res);
  }

  // ---------------------------------------------------------------------
  // Engineering Tools — ported from engineering-tools.html
  // ---------------------------------------------------------------------

  Future<Map<String, dynamic>> getDeviceReceiver({String deviceId = 'BP-AMS-001'}) async {
    final res = await _client.get(_uri('/api/device/receiver', {'deviceId': deviceId}));
    _throwIfNotOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> setReceiverMode({
    required String deviceId,
    required String mode,
    required String controllerModel,
    required String displayResolution,
  }) async {
    final res = await _client.post(
      _uri('/api/device/receiver'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'deviceId': deviceId, 'receiverMode': mode, 'controllerModel': controllerModel, 'displayResolution': displayResolution}),
    );
    _throwIfNotOk(res);
  }

  Future<Map<String, dynamic>> claimDevice({
    required String deviceId,
    required String displayName,
    required String controllerModel,
    required String displayResolution,
    required String receiverMode,
  }) async {
    final res = await _client.post(
      _uri('/api/device/onboarding'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'deviceId': deviceId,
        'displayName': displayName,
        'modelName': 'BenchPad Prototype V1',
        'locationLabel': 'Amsterdam',
        'controllerModel': controllerModel,
        'displayResolution': displayResolution,
        'receiverMode': receiverMode,
      }),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(data['error'] ?? 'Claim failed');
    }
    return data;
  }

  Future<Map<String, dynamic>> simulateJob(String action) async {
    final res = await _client.post(_uri('/api/publish-job/simulate'), headers: {'content-type': 'application/json'}, body: jsonEncode({'action': action}));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(data['error'] ?? 'Simulation failed');
    }
    return data;
  }

  // ---------------------------------------------------------------------
  // Devices — ported from devices.html
  // ---------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getDevices() async {
    final res = await _client.get(_uri('/api/devices'));
    _throwIfNotOk(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return ((data['devices'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> checkDeviceHeartbeat(String deviceId) async {
    final res = await _client.get(_uri('/api/device/receiver', {'deviceId': deviceId}));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] != true) {
      throw Exception(data['error'] ?? 'Heartbeat status unavailable');
    }
    return data;
  }

  Future<Map<String, dynamic>> registerDevice({
    required String deviceId,
    String displayName = '',
    String modelName = 'BenchPad 13.3 Spectra 6',
    String locationLabel = '',
    String notes = '',
    String controllerModel = 'ESP32-S3 + A7670E',
    String displayResolution = '1600 × 1200',
  }) async {
    final res = await _client.post(
      _uri('/api/device/onboarding'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'deviceId': deviceId,
        'displayName': displayName,
        'modelName': modelName,
        'locationLabel': locationLabel,
        'notes': notes,
        'controllerModel': controllerModel,
        'displayResolution': displayResolution,
        'receiverMode': 'PHYSICAL',
      }),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] != true) {
      throw Exception(data['error'] ?? 'Onboarding failed');
    }
    return data;
  }

  // ---------------------------------------------------------------------
  // Interactions — ported from interactions.html
  // ---------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getRecentInteractions({String? benchId}) async {
    final query = {'limit': '50', if (benchId != null) 'bench': benchId};
    final res = await _client.get(_uri('/api/interactions/recent', query));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] != true) {
      throw Exception(data['error'] ?? 'Request failed');
    }
    return ((data['events'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  Future<void> postInteractionEvent(Map<String, dynamic> payload) async {
    await _client.post(_uri('/api/interactions/event'), headers: {'content-type': 'application/json'}, body: jsonEncode(payload));
  }

  // ---------------------------------------------------------------------
  // Backup — ported from benchpad-backup.html
  // ---------------------------------------------------------------------

  Future<Map<String, dynamic>> exportBackup() async {
    final res = await _client.get(_uri('/api/benchpad-world/backup/export'));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(data['error'] ?? 'Export unavailable');
    }
    return data;
  }

  Future<void> importBackup({required String mode, required Map<String, dynamic> backup}) async {
    final res = await _client.post(
      _uri('/api/benchpad-world/backup/import'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'mode': mode, 'backup': backup}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(data['error'] ?? 'Import failed');
    }
  }

  // ---------------------------------------------------------------------
  // Community / Founders Wall — ported from benchpad-community.html
  // ---------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getFounders() async {
    final res = await _client.get(_uri('/api/benchpad-world/founders'));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300) throw Exception(data['error'] ?? 'Founders unavailable');
    return ((data['founders'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getAllFoundersForManagement() async {
    final res = await _client.get(_uri('/api/benchpad-world/founders/manage'));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300) throw Exception(data['error'] ?? 'Founders unavailable');
    return ((data['founders'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  Future<void> saveFounder({String? id, required Map<String, dynamic> fields}) async {
    final updating = id != null;
    final path = updating ? '/api/benchpad-world/founders?id=${Uri.encodeComponent(id)}' : '/api/benchpad-world/founders';
    final body = jsonEncode(fields);
    final res = updating
        ? await _client.put(_uri(path), headers: {'content-type': 'application/json'}, body: body)
        : await _client.post(_uri(path), headers: {'content-type': 'application/json'}, body: body);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300) throw Exception(data['error'] ?? 'Could not save founder');
  }

  Future<void> deleteFounder(String id) async {
    final res = await _client.delete(_uri('/api/benchpad-world/founders?id=${Uri.encodeComponent(id)}'));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300) throw Exception(data['error'] ?? 'Delete failed');
  }

  Future<void> sendFeedback({required String message, String contact = ''}) async {
    final res = await _client.post(
      _uri('/api/network/feedback'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'message': message, 'contact': contact, 'sessionId': ''}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) throw Exception('Could not send that. Please try again.');
  }

  // ---------------------------------------------------------------------
  // Device detail + Publish — ported from device.html, publish.html
  // ---------------------------------------------------------------------

  Future<Map<String, dynamic>> getDeviceProfile(String deviceId) async {
    final res = await _client.get(_uri('/api/device/profile', {'deviceId': deviceId}));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] != true) throw Exception(data['error'] ?? 'Profile unavailable');
    return (data['profile'] as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> saveDeviceProfile({
    required String deviceId,
    required String displayName,
    required String modelName,
    required String locationLabel,
    required String notes,
  }) async {
    final res = await _client.post(
      _uri('/api/device/profile'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'deviceId': deviceId, 'displayName': displayName, 'modelName': modelName, 'locationLabel': locationLabel, 'notes': notes}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] != true) throw Exception(data['error'] ?? 'Profile save failed');
    return data['profile'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getDeviceHardware(String deviceId) async {
    final res = await _client.get(_uri('/api/device/hardware', {'deviceId': deviceId}));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] != true) throw Exception(data['error'] ?? 'Hardware configuration unavailable');
    return (data['hardware'] as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> saveDeviceHardware(Map<String, dynamic> fields) async {
    final res = await _client.post(_uri('/api/device/hardware'), headers: {'content-type': 'application/json'}, body: jsonEncode(fields));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] != true) throw Exception(data['error'] ?? 'Hardware save failed');
    return data['hardware'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getDeviceNfc(String deviceId) async {
    final res = await _client.get(_uri('/api/device/nfc', {'deviceId': deviceId}));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] != true) throw Exception(data['error'] ?? 'NFC assignment unavailable');
    return (data['assignment'] as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> saveDeviceNfc({required String deviceId, required String tagId}) async {
    final res = await _client.post(_uri('/api/device/nfc'), headers: {'content-type': 'application/json'}, body: jsonEncode({'deviceId': deviceId, 'tagId': tagId}));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] != true) throw Exception(data['error'] ?? 'NFC assignment save failed');
    return data['assignment'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> getSingleDevice(String deviceId) async {
    final devices = await getDevices();
    for (final d in devices) {
      if (d['deviceId'] == deviceId) return d;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getDeliveryJobs(String deviceId) async {
    final res = await _client.get(_uri('/api/device/jobs', {'deviceId': deviceId, 'limit': '20'}));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] != true) throw Exception(data['error'] ?? 'Jobs unavailable');
    return ((data['jobs'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> publishToDevice({
    required String deviceId,
    required String contentType,
    required String contentPayload,
  }) async {
    final res = await _client.post(
      _uri('/api/device/publish'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'deviceId': deviceId, 'contentType': contentType, 'contentPayload': contentPayload}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] != true) throw Exception(data['error'] ?? 'Publish failed');
    return data['job'] as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------
  // Owner Access — ported from owner-access.html
  // ---------------------------------------------------------------------

  Future<bool> ownerLogin(String token) async {
    final res = await _client.post(_uri('/api/owner-access/login'), headers: {'content-type': 'application/json'}, body: jsonEncode({'token': token}));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300) throw Exception(data['error'] ?? 'Access denied.');
    return true;
  }

  Future<void> ownerLogout() async {
    await _client.post(_uri('/api/owner-access/logout'));
  }

  // ---------------------------------------------------------------------
  // Access Recovery — ported from access-recovery.html
  // ---------------------------------------------------------------------

  Future<void> useRecoveryCode({required String displayName, required String recoveryCode}) async {
    final res = await _client.post(
      _uri('/api/platform-access/recovery/use'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'displayName': displayName, 'recoveryCode': recoveryCode}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300) throw Exception(data['error'] ?? 'Recovery rejected');
  }

  // ---------------------------------------------------------------------
  // Owner Analytics — ported from owner-analytics.html
  // ---------------------------------------------------------------------

  Future<Map<String, dynamic>> getAiBudget() async {
    final res = await _client.get(_uri('/api/benchpad-ai/budget'));
    _throwIfNotOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> topUpAiBudget(int amountCents) async {
    final res = await _client.post(_uri('/api/benchpad-ai/budget/topup'), headers: {'content-type': 'application/json'}, body: jsonEncode({'amountCents': amountCents}));
    _throwIfNotOk(res);
  }

  Future<Map<String, dynamic>> getOwnerAnalyticsSummary() async {
    final res = await _client.get(_uri('/api/owner-analytics/summary'));
    _throwIfNotOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------
  // Report / Feedback — ported from report-feedback.html
  //
  // Simplification note: the PWA's interactive Leaflet map for picking a
  // location point is not ported here to avoid adding a mapping plugin
  // (given recent plugin/compileSdk trouble). Location is instead: a
  // preset "this BenchPad" point, device GPS (via the geolocator
  // dependency already in use elsewhere), or a free-text description.
  // ---------------------------------------------------------------------

  Future<Map<String, dynamic>> submitLocalReport({
    required String clientId,
    required String type,
    required String privacyMode,
    required String location,
    double? latitude,
    double? longitude,
    required String description,
    String photoData = '',
    required bool responseRequested,
    String contactEmail = '',
  }) async {
    final res = await _client.post(
      _uri('/api/local-reports'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'clientId': clientId,
        'type': type,
        'privacyMode': privacyMode,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'description': description,
        'photoData': photoData,
        'responseRequested': responseRequested,
        'contactEmail': contactEmail,
      }),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] != true) throw Exception(data['error'] ?? 'report_failed');
    return data['report'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getLocalReports(String clientId) async {
    final res = await _client.get(_uri('/api/local-reports', {'clientId': clientId}));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] != true) throw Exception('unavailable');
    return ((data['reports'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getLocalReportDetail({required String reportCode, required String clientId}) async {
    final res = await _client.get(_uri('/api/local-reports/public-detail', {'reportCode': reportCode, 'clientId': clientId}));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] != true) throw Exception('unavailable');
    return data['report'] as Map<String, dynamic>;
  }

  Future<void> confirmLocalReportSignal({required String clientId, required String reportCode, required String signal}) async {
    final res = await _client.post(
      _uri('/api/local-reports/confirm'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'clientId': clientId, 'reportCode': reportCode, 'signal': signal}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] != true) throw Exception('Confirmation could not be added');
  }

  Future<Map<String, dynamic>> getMunicipalUpdates() async {
    final res = await _client.get(_uri('/api/municipal/local-updates'));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] != true || data['updates'] is! List) {
      throw Exception('no data');
    }
    return data;
  }

  Future<Map<String, dynamic>> getFounderCertificate({String? token, String? id}) async {
    final query = token != null ? {'token': token} : {'id': id ?? ''};
    final res = await _client.get(_uri('/api/benchpad-world/founder', query));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300) throw Exception(data['error'] ?? 'Certificate not available');
    return data['founder'] as Map<String, dynamic>;
  }

  Future<void> toggleCertificatePublic(Map<String, dynamic> founder, bool makePublic) async {
    final id = founder['id']?.toString() ?? '';
    final res = await _client.put(
      _uri('/api/benchpad-world/founders', {'id': id}),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({...founder, 'certificatePublic': makePublic, 'certificateRevoked': !makePublic}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300) throw Exception(data['error'] ?? 'Update failed');
  }

  Future<Map<String, dynamic>> getDeviceEngineeringStatus(String deviceId) async {
    final res = await _client.get(_uri('/api/device/status', {'deviceId': deviceId}));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] != true) throw Exception(data['error'] ?? 'Telemetry unavailable');
    return data;
  }

  /// GET /api/device/diagnostics?deviceId=... — the same data as the
  /// board's local /status.json (Network Control's Full Diagnostics),
  /// mirrored to the cloud so it can be read from anywhere, not just
  /// while the phone is on the board's own network.
  Future<Map<String, dynamic>?> getRemoteDiagnostics(String deviceId) async {
    final res = await _client.get(_uri('/api/device/diagnostics', {'deviceId': deviceId}));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] != true) throw Exception(data['error'] ?? 'Diagnostics unavailable');
    return data['device'] as Map<String, dynamic>?;
  }

  /// POST /api/device/network-command — sets which transport (WiFi or
  /// LTE) the board should prefer, relayed through the cloud so it
  /// works from anywhere (unlike Network Control's local-only toggle,
  /// which needs the phone on the board's own network).
  Future<void> setPreferredNetworkTransport(String deviceId, String transport) async {
    final res = await _client.post(
      _uri('/api/device/network-command'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'deviceId': deviceId, 'preferredTransport': transport}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] != true) throw Exception(data['error'] ?? 'Command failed');
  }

  /// v5.28 — remote counterpart of Network Control's local-only "Force
  /// WiFi off" toggle. Same /api/device/network-command endpoint as
  /// setPreferredNetworkTransport above, just the other field.
  Future<void> setWifiForceDisabled(String deviceId, bool disabled) async {
    final res = await _client.post(
      _uri('/api/device/network-command'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'deviceId': deviceId, 'wifiForceDisabled': disabled}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] != true) throw Exception(data['error'] ?? 'Command failed');
  }

  /// GET /api/capsules/sphere?sphere=orbit|vault — real capsule data
  /// from the database (only non-empty ones; positions with no row
  /// are genuinely empty). Used by Memory/Time Capsule 1 instead of the
  /// bundled demo JSON, which had every single position filled in
  /// with a fabricated name/country/message — misleading for a public
  /// build.
  Future<List<Map<String, dynamic>>> getSphereCapsules(String sphere) async {
    final res = await _client.get(_uri('/api/capsules/sphere', {'sphere': sphere}));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] != true) throw Exception(data['error'] ?? 'Could not load sphere data');
    return ((data['capsules'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> getLiveDisplay(String deviceId) async {
    final res = await _client.get(_uri('/api/live-display', {'deviceId': deviceId}));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['current'] as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>> getLiveStatus() async {
    final res = await _client.get(_uri('/api/benchpad-live/status'));
    _throwIfNotOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitLive({required String message, String imageData = '', required String sessionId}) async {
    final res = await _client.post(
      _uri('/api/benchpad-live/submit'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'message': message, 'imageData': imageData, 'sessionId': sessionId}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['decision'] == 'NEEDS_REVIEW') {
      throw PublishException('needs_review', jobCode: (data['job'] as Map?)?['jobCode'] as String?);
    }
    if (res.statusCode < 200 || res.statusCode >= 300 || data['decision'] != 'APPROVED') {
      if (data['reasonCode'] == 'COOLDOWN') {
        throw PublishException('cooldown', cooldownSeconds: (data['cooldownSeconds'] as num?)?.toInt() ?? 30);
      }
      throw Exception(data['publicMessage'] ?? data['message'] ?? 'BenchPad Live could not complete this request.');
    }
    return data;
  }

  Future<Map<String, dynamic>> getLiveResult(String token) async {
    final res = await _client.get(_uri('/api/benchpad-live/result', {'token': token}));
    _throwIfNotOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  void _throwIfNotOk(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('BenchPad API error ${res.statusCode}: ${res.body}');
    }
  }

  void dispose() => _client.close();
}
