import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/neumorphic_theme.dart';

/// Certificate of Submission — downloadable confirmation card for a
/// Report/Feedback submission, matching the same neumorphic "raised
/// bezel" language as the Advertise publish confirmation card
/// (embossed text, thick raised photo frame, QR + Kinesus seal),
/// laid out per the reference design: QR top-left, title pill,
/// BenchPad mark top-right, photo, PROBLEM OVERVIEW, and a right-hand
/// column of REFERENCE NUMBER / DATE OF SUBMISSION / LOCATION /
/// ISSUE CATEGORY fields, seal bottom-right.
class ReportCertificate extends StatelessWidget {
  final GlobalKey boundaryKey;
  final String reportCode;
  final DateTime submittedAt;
  final String location;
  final String category;
  final String description;
  final Uint8List? photoBytes;

  const ReportCertificate({
    super.key,
    required this.boundaryKey,
    required this.reportCode,
    required this.submittedAt,
    required this.location,
    required this.category,
    required this.description,
    required this.photoBytes,
  });

  TextStyle _embossedStyle({required double fontSize, required FontWeight weight, Color? color}) {
    final c = color ?? NeumorphicPalette.textPrimary;
    return TextStyle(
      fontSize: fontSize,
      fontWeight: weight,
      color: c,
      shadows: [
        Shadow(color: Colors.white.withOpacity(0.7), offset: const Offset(0.5, 0.5)),
        Shadow(color: NeumorphicPalette.shadowDark.withOpacity(0.5), offset: const Offset(-0.5, -0.5)),
      ],
    );
  }

  TextStyle _signatureStyle() {
    return GoogleFonts.marckScript(fontSize: 22, color: NeumorphicPalette.textPrimary);
  }

  Widget _field(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _embossedStyle(fontSize: 9, weight: FontWeight.w800, color: NeumorphicPalette.textSecondary).copyWith(letterSpacing: 0.6)),
        const SizedBox(height: 5),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: NeumorphicPalette.background,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: NeumorphicPalette.shadowDark, offset: const Offset(2, 2), blurRadius: 3),
              BoxShadow(color: NeumorphicPalette.shadowLight, offset: const Offset(-2, -2), blurRadius: 3),
            ],
          ),
          child: Text(value, style: _embossedStyle(fontSize: 10.5, weight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = '${submittedAt.day.toString().padLeft(2, '0')}/${submittedAt.month.toString().padLeft(2, '0')}/${submittedAt.year}';

    return RepaintBoundary(
      key: boundaryKey,
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(color: NeumorphicPalette.shadowDark, offset: const Offset(2, 2), blurRadius: 4),
                      BoxShadow(color: NeumorphicPalette.shadowLight, offset: const Offset(-2, -2), blurRadius: 4),
                    ],
                  ),
                  child: QrImageView(data: 'https://kinesus.nl/', padding: EdgeInsets.zero, backgroundColor: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: NeumorphicPalette.background,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(color: NeumorphicPalette.shadowDark, offset: const Offset(2, 2), blurRadius: 5),
                        BoxShadow(color: NeumorphicPalette.shadowLight, offset: const Offset(-2, -2), blurRadius: 5),
                      ],
                    ),
                    child: Center(
                      child: Text('CERTIFICATE OF SUBMISSION', textAlign: TextAlign.center, style: _embossedStyle(fontSize: 11, weight: FontWeight.w900).copyWith(letterSpacing: 0.5)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: NeumorphicPalette.background,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: NeumorphicPalette.shadowDark, offset: const Offset(4, 4), blurRadius: 10),
                              BoxShadow(color: NeumorphicPalette.shadowLight, offset: const Offset(-4, -4), blurRadius: 10),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: AspectRatio(
                              aspectRatio: 4 / 3,
                              child: photoBytes != null ? Image.memory(photoBytes!, fit: BoxFit.cover) : Container(color: NeumorphicPalette.surface, child: const Icon(Icons.image_not_supported_outlined, color: NeumorphicPalette.textSecondary)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text('PROBLEM OVERVIEW', style: _embossedStyle(fontSize: 9, weight: FontWeight.w800, color: NeumorphicPalette.textSecondary).copyWith(letterSpacing: 0.6)),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: NeumorphicPalette.background,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: NeumorphicPalette.shadowDark, offset: const Offset(2, 2), blurRadius: 4),
                              BoxShadow(color: NeumorphicPalette.shadowLight, offset: const Offset(-2, -2), blurRadius: 4),
                            ],
                          ),
                          child: Text(
                            description.isEmpty ? 'No additional details provided.' : description,
                            style: _embossedStyle(fontSize: 11.5, weight: FontWeight.w600).copyWith(height: 1.4),
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 26,
                          child: Image.asset('assets/images/benchpad-wordmark.png', fit: BoxFit.contain, alignment: Alignment.centerLeft),
                        ),
                        const SizedBox(height: 14),
                        Text('Shapi Shakhshaev', style: _signatureStyle()),
                        const SizedBox(height: 3),
                        Container(height: 1, width: 120, color: NeumorphicPalette.shadowDark.withOpacity(0.6)),
                        const SizedBox(height: 3),
                        Text('Founder & Developer, BenchPad / Kinesus', style: _embossedStyle(fontSize: 8.5, weight: FontWeight.w600, color: NeumorphicPalette.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _field('REFERENCE NUMBER', reportCode),
                        const SizedBox(height: 12),
                        _field('DATE OF SUBMISSION', dateStr),
                        const SizedBox(height: 12),
                        _field('LOCATION', location),
                        const SizedBox(height: 12),
                        _field('ISSUE CATEGORY', category),
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            width: 70,
                            height: 70,
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
                                padding: const EdgeInsets.all(11),
                                child: Image.asset('assets/images/kinesus-flower-logo.webp', fit: BoxFit.contain),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'This certificate confirms your submission to BenchPad — it is not proof of resolution.',
              style: TextStyle(fontSize: 9.5, color: NeumorphicPalette.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
