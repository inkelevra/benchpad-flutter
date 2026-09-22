import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/broadcast_calendar.dart';

/// Local-only broadcast calendar store, ported from
/// assets/broadcast-calendar-store.js. Matches the PWA's current
/// behavior exactly: bookings/holds live only on this device
/// (SharedPreferences here, localStorage there) — there is no server
/// persistence yet in either version.
class BroadcastCalendarStore {
  static const _bookingKey = 'benchpad_broadcast_bookings_v1';
  static const _holdKey = 'benchpad_broadcast_holds_v1';

  final _random = Random();

  String _uid(String prefix) {
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final rand = _random.nextInt(0xFFFFFF).toRadixString(36).padLeft(4, '0');
    return '$prefix-$ts-$rand'.toUpperCase();
  }

  int _minutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  String _timeFromMinutes(int value) {
    if (value == 1440) return '24:00';
    final h = (value ~/ 60) % 24;
    final m = value % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// Europe/Amsterdam DST approximation: CEST (+2) from last Sunday of
  /// March to last Sunday of October, CET (+1) otherwise. A reasonable
  /// tradeoff for a single hardcoded bench in a local-only booking flow
  /// without pulling in the full `timezone` package + tzdata.
  int _amsterdamOffsetHours(DateTime utcDate) {
    final year = utcDate.year;
    DateTime lastSundayOf(int month) {
      final last = DateTime.utc(year, month + 1, 0);
      return last.subtract(Duration(days: last.weekday % 7));
    }
    final dstStart = lastSundayOf(3);
    final dstEnd = lastSundayOf(10);
    return (utcDate.isAfter(dstStart) && utcDate.isBefore(dstEnd)) ? 2 : 1;
  }

  DateTime zonedToUtc(String dateString, String timeString, String timezone) {
    final dateParts = dateString.split('-').map(int.parse).toList();
    final timeParts = timeString.split(':').map(int.parse).toList();
    final wall = DateTime.utc(dateParts[0], dateParts[1], dateParts[2], timeParts[0], timeParts[1]);
    if (timezone != 'Europe/Amsterdam') return wall;
    final offset = _amsterdamOffsetHours(wall);
    return wall.subtract(Duration(hours: offset));
  }

  String formatInZone(DateTime utc, String timezone) {
    DateTime local;
    if (timezone == 'Europe/Amsterdam') {
      local = utc.add(Duration(hours: _amsterdamOffsetHours(utc)));
    } else {
      local = utc.toLocal();
    }
    return '${local.day.toString().padLeft(2, '0')} ${_monthAbbr(local.month)} ${local.year}, '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _monthAbbr(int m) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];

  // -- Persistence -----------------------------------------------------

  Future<List<BroadcastBooking>> _readBookings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bookingKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => BroadcastBooking.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeBookings(List<BroadcastBooking> bookings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bookingKey, jsonEncode(bookings.map((b) => b.toJson()).toList()));
  }

  Future<List<BroadcastHold>> _readHolds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_holdKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      final holds = list.map((e) => BroadcastHold.fromJson(e as Map<String, dynamic>)).toList();
      final active = holds.where((h) => h.expiresAt.isAfter(DateTime.now())).toList();
      if (active.length != holds.length) await _writeHolds(active);
      return active;
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeHolds(List<BroadcastHold> holds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_holdKey, jsonEncode(holds.map((h) => h.toJson()).toList()));
  }

  // -- Bookings ----------------------------------------------------------

  Future<List<BroadcastBooking>> listBookings() async {
    final bookings = await _readBookings();
    bookings.sort((a, b) => a.startUtc.compareTo(b.startUtc));
    return bookings;
  }

  Future<BroadcastBooking?> bookingForCapsule(String capsuleKey) async {
    final bookings = await listBookings();
    for (final b in bookings) {
      if (b.capsuleKey == capsuleKey) return b;
    }
    return null;
  }

  Future<BroadcastBooking> _saveBooking(BroadcastBooking booking) async {
    final bookings = await _readBookings();
    final index = bookings.indexWhere((b) => b.id == booking.id || b.capsuleKey == booking.capsuleKey);
    if (index >= 0) {
      bookings[index] = booking;
    } else {
      bookings.add(booking);
    }
    await _writeBookings(bookings);
    return booking;
  }

  Future<BroadcastBooking?> cancelBooking(String id) async {
    final bookings = await _readBookings();
    final index = bookings.indexWhere((b) => b.id == id);
    if (index < 0) return null;
    final cancelled = bookings[index].copyWith(status: 'cancelled');
    bookings[index] = cancelled;
    await _writeBookings(bookings);
    return cancelled;
  }

  // -- Intervals / availability -------------------------------------------

  List<BroadcastInterval> _demoReservations(String dateString, String benchId) {
    if (benchId != 'BP-AMS-001') return [];
    final day = int.parse(dateString.substring(dateString.length - 2));
    final items = <List<String>>[];
    if (day % 2 == 1) {
      items.addAll([
        ['09:00', '12:00', 'CENTER', 'Municipal information'],
        ['14:30', '17:30', 'LEFT', 'Community partner'],
        ['19:00', '22:00', 'RIGHT', 'Reserved publication'],
      ]);
    } else {
      items.addAll([
        ['10:00', '13:00', 'CENTER', 'Scheduled capsule'],
        ['16:00', '19:00', 'CENTER', 'Local campaign'],
        ['20:15', '23:15', 'LEFT', 'Reserved publication'],
      ]);
    }
    if (day % 5 == 0) items.add(['07:30', '10:30', 'RIGHT', 'Maintenance preparation']);

    return items.asMap().entries.map((e) => BroadcastInterval(
          id: 'DEMO-$dateString-${e.key}',
          start: e.value[0],
          end: e.value[1],
          displayId: e.value[2],
          label: e.value[3],
        )).toList();
  }

  Future<List<BroadcastInterval>> intervals(String dateString, String benchId) async {
    final bookings = await _readBookings();
    final bookingIntervals = bookings
        .where((b) => b.date == dateString && b.benchId == benchId && b.status != 'cancelled')
        .map((b) => BroadcastInterval(
              id: b.id,
              start: b.localStart,
              end: b.localEnd,
              displayId: b.displayId,
              label: b.mode == 'special' ? 'Special Moment' : 'Capsule broadcast',
            ))
        .toList();
    return [..._demoReservations(dateString, benchId), ...bookingIntervals];
  }

  bool _overlaps(int aStart, int aEnd, int bStart, int bEnd) => aStart < bEnd && aEnd > bStart;

  Future<BroadcastInterval?> _conflict({
    required String date,
    required String benchId,
    required String displayId,
    required String start,
    required String end,
    String? ignoreId,
  }) async {
    final startM = _minutes(start), endM = _minutes(end);
    final items = await intervals(date, benchId);
    for (final item in items) {
      if (item.id == ignoreId) continue;
      final matchesDisplay = item.displayId == 'ALL' || displayId == 'AUTO' || item.displayId == displayId;
      if (matchesDisplay && _overlaps(startM, endM, _minutes(item.start), _minutes(item.end))) {
        return item;
      }
    }
    return null;
  }

  Future<String?> _chooseDisplay(String date, String benchId, String start, String end, String requested) async {
    if (requested != 'AUTO' && await _conflict(date: date, benchId: benchId, displayId: requested, start: start, end: end) == null) {
      return requested;
    }
    for (final display in ['LEFT', 'CENTER', 'RIGHT']) {
      if (await _conflict(date: date, benchId: benchId, displayId: display, start: start, end: end) == null) {
        return display;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> availability(String dateString, String benchId) async {
    final date = DateTime.parse(dateString);
    final event = SpecialEvent.forDate(date);
    if (event != null) return {'status': 'special', 'label': 'Special event booking', 'event': event};

    final items = await intervals(dateString, benchId);
    final occupied = items.fold<int>(0, (sum, i) => sum + max(0, _minutes(i.end) - _minutes(i.start)));
    const capacity = 18 * 60 * 3;
    final ratio = occupied / capacity;
    if (ratio > 0.72) return {'status': 'full', 'label': 'Fully booked'};
    if (ratio > 0.38) return {'status': 'limited', 'label': 'Limited availability'};
    return {'status': 'open', 'label': 'Many times available'};
  }

  // -- Hold / confirm flow -------------------------------------------------

  Future<BroadcastHold?> activeHoldForCapsule(String capsuleKey) async {
    final holds = await _readHolds();
    for (final h in holds) {
      if (h.capsuleKey == capsuleKey) return h;
    }
    return null;
  }

  Future<void> releaseHold(String id) async {
    final holds = await _readHolds();
    holds.removeWhere((h) => h.id == id);
    await _writeHolds(holds);
  }

  Future<BroadcastHold> holdSlot({
    required String capsuleKey,
    required String sphere,
    required String capsuleType,
    required int capsuleNumber,
    required String benchSelectionId,
    required String date,
    required String start,
    required String displayId,
    required String mode,
  }) async {
    final bench = BroadcastBench.resolve(benchSelectionId);
    final event = SpecialEvent.forDate(DateTime.parse(date));
    final duration = mode == 'special' ? 5 : 180;
    final startMinutes = _minutes(start);
    final rawEnd = startMinutes + duration;
    if (rawEnd > 1440) {
      throw Exception(mode == 'standard'
          ? 'Choose a start no later than 21:00 for a same-day three-hour window.'
          : 'Choose a Special Moment no later than 23:55.');
    }
    final end = _timeFromMinutes(rawEnd);
    final display = await _chooseDisplay(date, bench.id, start, end, displayId);
    final allocationRequest = mode == 'special' && event != null;
    if (display == null && !allocationRequest) {
      throw Exception('This time is no longer available. Choose another minute or display.');
    }

    final hold = BroadcastHold(
      id: _uid('HOLD'),
      capsuleKey: capsuleKey,
      sphere: sphere,
      capsuleType: capsuleType,
      capsuleNumber: capsuleNumber,
      benchId: bench.id,
      benchSelectionId: benchSelectionId,
      benchName: bench.name,
      timezone: bench.timezone,
      date: date,
      start: start,
      end: end,
      displayId: display ?? 'ALLOCATION',
      mode: mode,
      allocationRequest: allocationRequest,
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
    );

    final holds = await _readHolds();
    holds.removeWhere((h) => h.capsuleKey == hold.capsuleKey);
    holds.add(hold);
    await _writeHolds(holds);
    return hold;
  }

  Future<BroadcastBooking> confirmHold(
    String holdId, {
    required String owner,
    required String country,
    required bool contentReady,
    String? specialFormat,
  }) async {
    final holds = await _readHolds();
    BroadcastHold? hold;
    for (final h in holds) {
      if (h.id == holdId) { hold = h; break; }
    }
    if (hold == null) throw Exception('The temporary hold expired. Select the time again.');

    final startUtc = zonedToUtc(hold.date, hold.start, hold.timezone);
    final endUtc = zonedToUtc(hold.date, hold.end, hold.timezone);
    final status = hold.allocationRequest ? 'allocation_requested' : (contentReady ? 'under_moderation' : 'content_required');

    final booking = BroadcastBooking(
      id: _uid('BC'),
      capsuleKey: hold.capsuleKey,
      sphere: hold.sphere,
      capsuleType: hold.capsuleType,
      capsuleNumber: hold.capsuleNumber,
      capsuleId: hold.capsuleType == 'core' ? 'BP-CORE-${hold.capsuleNumber.toString().padLeft(2, '0')}' : 'BP-TC-${hold.capsuleNumber.toString().padLeft(6, '0')}',
      owner: owner.isEmpty ? 'Capsule owner' : owner,
      country: country,
      benchId: hold.benchId,
      benchSelectionId: hold.benchSelectionId,
      benchName: hold.benchName,
      timezone: hold.timezone,
      date: hold.date,
      localStart: hold.start,
      localEnd: hold.end,
      startUtc: startUtc,
      endUtc: endUtc,
      displayId: hold.displayId,
      mode: hold.mode,
      specialFormat: specialFormat,
      status: status,
      contentDeadline: startUtc.subtract(const Duration(hours: 72)),
      allocationRequest: hold.allocationRequest,
    );

    final saved = await _saveBooking(booking);
    await releaseHold(holdId);
    return saved;
  }

  String statusLabel(String status) {
    const labels = {
      'temporarily_held': 'Temporarily held',
      'allocation_requested': 'Allocation requested',
      'reserved': 'Reserved',
      'content_required': 'Content required',
      'under_moderation': 'Under moderation',
      'approved': 'Approved',
      'scheduled': 'Scheduled',
      'live_now': 'Live now',
      'completed': 'Completed',
      'rescheduling_required': 'Rescheduling required',
      'cancelled': 'Cancelled',
    };
    return labels[status] ?? status;
  }

  int lifecycleIndex(String status) {
    const indices = {
      'temporarily_held': 1,
      'allocation_requested': 2,
      'reserved': 2,
      'content_required': 3,
      'under_moderation': 4,
      'approved': 5,
      'scheduled': 6,
      'live_now': 7,
      'completed': 8,
      'rescheduling_required': 3,
      'cancelled': 0,
    };
    return indices[status] ?? 0;
  }

  String buildIcs(BroadcastBooking booking) {
    String fmt(DateTime d) => '${d.toIso8601String().replaceAll(RegExp(r'[-:]'), '').split('.').first}Z';
    final title = booking.mode == 'special' ? 'BenchPad Special Moment · ${booking.capsuleId}' : 'BenchPad Broadcast · ${booking.capsuleId}';
    final description = 'Scheduled on ${booking.benchName}. BenchPad local time: ${booking.localStart}–${booking.localEnd} (${booking.timezone}). Status: ${statusLabel(booking.status)}.';
    return [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//BenchPad//Broadcast Calendar//EN',
      'CALSCALE:GREGORIAN',
      'BEGIN:VEVENT',
      'UID:${booking.id}@benchpad.world',
      'DTSTAMP:${fmt(DateTime.now().toUtc())}',
      'DTSTART:${fmt(booking.startUtc)}',
      'DTEND:${fmt(booking.endUtc)}',
      'SUMMARY:$title',
      'DESCRIPTION:$description',
      'LOCATION:${booking.benchName}',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n');
  }
}
