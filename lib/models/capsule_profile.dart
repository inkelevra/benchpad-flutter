/// One capsule "profile" in the Memory Sphere — a person's time capsule
/// entry. Loaded from the real /api/capsules/sphere endpoint (only
/// non-empty capsules come back; positions with no matching row are
/// genuinely empty) — was briefly a bundled demo JSON with all 500
/// positions fabricated, replaced once that turned out misleading for
/// a public build.
class CapsuleProfile {
  final int index; // 0-based position in the sphere
  final int privateNumber; // 1-500, shown to the user for lookup
  final String flag;
  final String country;
  final String name;
  final String worldId;
  final String capsuleId;
  final String memberSince; // ISO date
  final String openingDate; // ISO date
  final String status; // "empty" | "locked" | "sealed" | "open"
  final String message;
  final double avatarHue;
  final String initials;
  final String createdVia;
  final String openedOn;
  final String visibility; // "Public" | "Private"

  CapsuleProfile({
    required this.index,
    required this.privateNumber,
    required this.flag,
    required this.country,
    required this.name,
    required this.worldId,
    required this.capsuleId,
    required this.memberSince,
    required this.openingDate,
    required this.status,
    required this.message,
    required this.avatarHue,
    required this.initials,
    required this.createdVia,
    required this.openedOn,
    required this.visibility,
  });

  factory CapsuleProfile.fromJson(Map<String, dynamic> json) => CapsuleProfile(
        index: json['index'] as int,
        privateNumber: json['privateNumber'] as int,
        flag: json['flag'] as String? ?? '',
        country: json['country'] as String? ?? '',
        name: json['name'] as String? ?? '',
        worldId: json['worldId'] as String? ?? '',
        capsuleId: json['capsuleId'] as String? ?? '',
        memberSince: json['memberSince'] as String? ?? '',
        openingDate: json['openingDate'] as String? ?? '',
        status: json['status'] as String? ?? 'empty',
        message: json['message'] as String? ?? '',
        avatarHue: (json['avatarHue'] as num?)?.toDouble() ?? 0,
        initials: json['initials'] as String? ?? '',
        createdVia: json['createdVia'] as String? ?? '',
        openedOn: json['openedOn'] as String? ?? '',
        visibility: json['visibility'] as String? ?? 'Public',
      );
}
