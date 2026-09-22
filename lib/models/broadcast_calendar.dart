/// A bookable BenchPad location. Ported from the static BENCHES array in
/// assets/broadcast-calendar-store.js.
class BroadcastBench {
  final String id;
  final String name;
  final String city;
  final String country;
  final String timezone;
  final String status;
  final bool bookable;
  final List<String> displays; // e.g. ["LEFT", "CENTER", "RIGHT"] or ["AUTO"]
  final String note;
  final String? resolvesTo;

  const BroadcastBench({
    required this.id,
    required this.name,
    required this.city,
    required this.country,
    required this.timezone,
    required this.status,
    required this.bookable,
    required this.displays,
    required this.note,
    this.resolvesTo,
  });

  static const all = [
    BroadcastBench(
      id: 'BP-AMS-001',
      name: 'Amsterdam · BP-AMS-001',
      city: 'Amsterdam',
      country: 'Netherlands',
      timezone: 'Europe/Amsterdam',
      status: 'ONLINE',
      bookable: true,
      displays: ['LEFT', 'CENTER', 'RIGHT'],
      note: 'Active Amsterdam prototype · three 13-inch E-Ink displays',
    ),
    BroadcastBench(
      id: 'AUTO-NL',
      name: 'First available BenchPad',
      city: 'Netherlands network',
      country: 'Netherlands',
      timezone: 'Europe/Amsterdam',
      status: 'SMART MATCH',
      bookable: true,
      displays: ['AUTO'],
      note: 'The platform selects the first compatible active BenchPad.',
      resolvesTo: 'BP-AMS-001',
    ),
    BroadcastBench(
      id: 'BP-AMS-002',
      name: 'Future BenchPad location',
      city: 'Amsterdam',
      country: 'Netherlands',
      timezone: 'Europe/Amsterdam',
      status: 'PLANNED',
      bookable: false,
      displays: [],
      note: 'Future installation · booking opens after commissioning.',
    ),
    BroadcastBench(
      id: 'ANY-COUNTRY',
      name: 'Any BenchPad in selected country',
      city: 'Selected country',
      country: 'BenchPad World',
      timezone: 'UTC',
      status: 'WAITLIST',
      bookable: false,
      displays: [],
      note: 'Network-wide country selection becomes active as new locations launch.',
    ),
  ];

  /// Resolves "AUTO-NL" (Smart Match) down to the real bench it points to,
  /// same as bench() in the JS store.
  static BroadcastBench resolve(String id) {
    final found = all.firstWhere((b) => b.id == id, orElse: () => all.first);
    if (found.resolvesTo != null) return resolve(found.resolvesTo!);
    return found;
  }
}

/// A fixed high-demand date, ported from specialEvent() in the JS store.
class SpecialEvent {
  final String id;
  final String name;
  final List<String> formats;

  SpecialEvent({required this.id, required this.name, required this.formats});

  static SpecialEvent? forDate(DateTime date) {
    final m = date.month, d = date.day, y = date.year;
    if (m == 12 && d == 31) {
      return SpecialEvent(id: 'NYE-${y + 1}', name: 'New Year ${y + 1} · Amsterdam', formats: ['Midnight Moment', 'Celebration Rotation', 'First Message of the Year', 'Global New Year Wave']);
    }
    if (m == 1 && d == 1) {
      return SpecialEvent(id: 'NYD-$y', name: 'First Day of $y', formats: ['First Message of the Year', 'Celebration Rotation']);
    }
    if (m == 2 && d == 14) {
      return SpecialEvent(id: 'VAL-$y', name: "Valentine's Day $y", formats: ['Special Moment', 'Celebration Rotation']);
    }
    if (m == 4 && d == 27) {
      return SpecialEvent(id: 'KING-$y', name: "King's Day $y", formats: ['Special Moment', 'Celebration Rotation']);
    }
    return null;
  }
}

/// One occupied interval on a given day (demo reservation, real booking,
/// or technical block) — used to compute availability and conflicts.
class BroadcastInterval {
  final String id;
  final String start; // "HH:mm"
  final String end;
  final String displayId; // "LEFT" | "CENTER" | "RIGHT" | "ALL" | "ALLOCATION"
  final String label;
  final bool technical;

  BroadcastInterval({required this.id, required this.start, required this.end, required this.displayId, required this.label, this.technical = false});
}

/// A confirmed broadcast booking, ported from saveBooking()'s record shape.
class BroadcastBooking {
  final String id;
  final String capsuleKey;
  final String sphere;
  final String capsuleType;
  final int capsuleNumber;
  final String capsuleId;
  final String owner;
  final String country;
  final String benchId;
  final String benchSelectionId;
  final String benchName;
  final String timezone;
  final String date; // "YYYY-MM-DD"
  final String localStart;
  final String localEnd;
  final DateTime startUtc;
  final DateTime endUtc;
  final String displayId;
  final String mode; // "standard" | "special"
  final String? specialFormat;
  final String status;
  final DateTime contentDeadline;
  final bool allocationRequest;
  final Map<String, dynamic>? proof;

  BroadcastBooking({
    required this.id,
    required this.capsuleKey,
    required this.sphere,
    required this.capsuleType,
    required this.capsuleNumber,
    required this.capsuleId,
    required this.owner,
    required this.country,
    required this.benchId,
    required this.benchSelectionId,
    required this.benchName,
    required this.timezone,
    required this.date,
    required this.localStart,
    required this.localEnd,
    required this.startUtc,
    required this.endUtc,
    required this.displayId,
    required this.mode,
    this.specialFormat,
    required this.status,
    required this.contentDeadline,
    required this.allocationRequest,
    this.proof,
  });

  BroadcastBooking copyWith({String? status, Map<String, dynamic>? proof}) => BroadcastBooking(
        id: id,
        capsuleKey: capsuleKey,
        sphere: sphere,
        capsuleType: capsuleType,
        capsuleNumber: capsuleNumber,
        capsuleId: capsuleId,
        owner: owner,
        country: country,
        benchId: benchId,
        benchSelectionId: benchSelectionId,
        benchName: benchName,
        timezone: timezone,
        date: date,
        localStart: localStart,
        localEnd: localEnd,
        startUtc: startUtc,
        endUtc: endUtc,
        displayId: displayId,
        mode: mode,
        specialFormat: specialFormat,
        status: status ?? this.status,
        contentDeadline: contentDeadline,
        allocationRequest: allocationRequest,
        proof: proof ?? this.proof,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'capsuleKey': capsuleKey,
        'sphere': sphere,
        'capsuleType': capsuleType,
        'capsuleNumber': capsuleNumber,
        'capsuleId': capsuleId,
        'owner': owner,
        'country': country,
        'benchId': benchId,
        'benchSelectionId': benchSelectionId,
        'benchName': benchName,
        'timezone': timezone,
        'date': date,
        'localStart': localStart,
        'localEnd': localEnd,
        'startUtc': startUtc.toIso8601String(),
        'endUtc': endUtc.toIso8601String(),
        'displayId': displayId,
        'mode': mode,
        'specialFormat': specialFormat,
        'status': status,
        'contentDeadline': contentDeadline.toIso8601String(),
        'allocationRequest': allocationRequest,
        'proof': proof,
      };

  factory BroadcastBooking.fromJson(Map<String, dynamic> j) => BroadcastBooking(
        id: j['id'] as String,
        capsuleKey: j['capsuleKey'] as String,
        sphere: j['sphere'] as String,
        capsuleType: j['capsuleType'] as String,
        capsuleNumber: j['capsuleNumber'] as int,
        capsuleId: j['capsuleId'] as String,
        owner: j['owner'] as String,
        country: j['country'] as String,
        benchId: j['benchId'] as String,
        benchSelectionId: j['benchSelectionId'] as String,
        benchName: j['benchName'] as String,
        timezone: j['timezone'] as String,
        date: j['date'] as String,
        localStart: j['localStart'] as String,
        localEnd: j['localEnd'] as String,
        startUtc: DateTime.parse(j['startUtc'] as String),
        endUtc: DateTime.parse(j['endUtc'] as String),
        displayId: j['displayId'] as String,
        mode: j['mode'] as String,
        specialFormat: j['specialFormat'] as String?,
        status: j['status'] as String,
        contentDeadline: DateTime.parse(j['contentDeadline'] as String),
        allocationRequest: j['allocationRequest'] as bool,
        proof: j['proof'] as Map<String, dynamic>?,
      );
}

/// A temporary 10-minute hold on a slot, ported from holdSlot()'s record.
class BroadcastHold {
  final String id;
  final String capsuleKey;
  final String sphere;
  final String capsuleType;
  final int capsuleNumber;
  final String benchId;
  final String benchSelectionId;
  final String benchName;
  final String timezone;
  final String date;
  final String start;
  final String end;
  final String displayId;
  final String mode;
  final bool allocationRequest;
  final DateTime expiresAt;

  BroadcastHold({
    required this.id,
    required this.capsuleKey,
    required this.sphere,
    required this.capsuleType,
    required this.capsuleNumber,
    required this.benchId,
    required this.benchSelectionId,
    required this.benchName,
    required this.timezone,
    required this.date,
    required this.start,
    required this.end,
    required this.displayId,
    required this.mode,
    required this.allocationRequest,
    required this.expiresAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'capsuleKey': capsuleKey,
        'sphere': sphere,
        'capsuleType': capsuleType,
        'capsuleNumber': capsuleNumber,
        'benchId': benchId,
        'benchSelectionId': benchSelectionId,
        'benchName': benchName,
        'timezone': timezone,
        'date': date,
        'start': start,
        'end': end,
        'displayId': displayId,
        'mode': mode,
        'allocationRequest': allocationRequest,
        'expiresAt': expiresAt.toIso8601String(),
      };

  factory BroadcastHold.fromJson(Map<String, dynamic> j) => BroadcastHold(
        id: j['id'] as String,
        capsuleKey: j['capsuleKey'] as String,
        sphere: j['sphere'] as String,
        capsuleType: j['capsuleType'] as String,
        capsuleNumber: j['capsuleNumber'] as int,
        benchId: j['benchId'] as String,
        benchSelectionId: j['benchSelectionId'] as String,
        benchName: j['benchName'] as String,
        timezone: j['timezone'] as String,
        date: j['date'] as String,
        start: j['start'] as String,
        end: j['end'] as String,
        displayId: j['displayId'] as String,
        mode: j['mode'] as String,
        allocationRequest: j['allocationRequest'] as bool,
        expiresAt: DateTime.parse(j['expiresAt'] as String),
      );
}
