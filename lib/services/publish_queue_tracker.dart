import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One publish job the user has submitted, tracked locally so it can
/// be shown in the "My Publications" queue list.
class TrackedPublishJob {
  final String jobCode;
  final DateTime submittedAt;

  TrackedPublishJob({required this.jobCode, required this.submittedAt});

  /// The number the backend actually assigns (BP-JOB-000311 -> 000311),
  /// shown to the user as "№ 000311" per their own reference format.
  String get displayNumber => numberFromCode(jobCode);

  static String numberFromCode(String jobCode) {
    final match = RegExp(r'(\d+)$').firstMatch(jobCode);
    return match?.group(1) ?? jobCode;
  }

  Map<String, dynamic> toJson() => {'jobCode': jobCode, 'submittedAt': submittedAt.toIso8601String()};

  factory TrackedPublishJob.fromJson(Map<String, dynamic> json) => TrackedPublishJob(
        jobCode: json['jobCode'] as String,
        submittedAt: DateTime.parse(json['submittedAt'] as String),
      );
}

/// Keeps a local history of the user's own submitted publish jobs
/// (most recent first), persisted via SharedPreferences. The live
/// queue position/status for each is fetched on demand by whatever
/// screen displays this list (PublishQueueScreen) — this class only
/// tracks WHICH jobs to ask about, not their live status.
class PublishQueueTracker extends ChangeNotifier {
  static const _prefsKey = 'benchpadPublishQueueHistory';
  static const _maxEntries = 20;

  List<TrackedPublishJob> _jobs = [];
  List<TrackedPublishJob> get jobs => List.unmodifiable(_jobs);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      _jobs = list.map(TrackedPublishJob.fromJson).toList();
      notifyListeners();
    } catch (_) {
      // Corrupt/old-format data — start fresh rather than crash.
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_jobs.map((j) => j.toJson()).toList()));
  }

  Future<void> addJob(String jobCode) async {
    _jobs.insert(0, TrackedPublishJob(jobCode: jobCode, submittedAt: DateTime.now()));
    if (_jobs.length > _maxEntries) {
      _jobs = _jobs.sublist(0, _maxEntries);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> removeJob(String jobCode) async {
    _jobs.removeWhere((j) => j.jobCode == jobCode);
    notifyListeners();
    await _persist();
  }
}
