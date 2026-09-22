import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/benchpad_api.dart';
import '../theme/neumorphic_theme.dart';

/// Backup & Export — ported from benchpad-backup.html.
///
/// Simplification notes:
/// - The PWA also offers a "FULL ZIP + CSV" export bundling backup.json
///   + three CSVs into one .zip via a hand-rolled writer — this pass
///   covers JSON and the three individual CSV exports (same data, one
///   file per share instead of bundled); ZIP bundling is deferred.
/// - Import uses paste-JSON-text instead of a native file picker. Three
///   different file-picker plugin versions (8.x, 12.x, 11.x) each hit a
///   different Android build conflict in this project (hardcoded old
///   compileSdk, a win32 version clash with share_plus, then a Kotlin/
///   Java plugin-registration compile-order failure) — rather than
///   keep chasing plugin version combinations for a lightly-used admin
///   feature, paste avoids the native dependency entirely. The person
///   can open the JSON file in any app, copy its contents, and paste
///   here — same validation and import behavior either way.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _api = BenchpadApi();
  Map<String, dynamic>? _backup;
  String _lastExport = 'Never';
  int _founders = 0;
  int _evidence = 0;
  String? _exportStatus;
  String? _importStatus;
  Map<String, dynamic>? _validatedBackup;
  String _mode = 'merge';
  bool _busy = false;
  final _pasteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    _pasteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _api.exportBackup();
      final backup = data['backup'] as Map<String, dynamic>;
      final backupData = backup['data'] as Map<String, dynamic>;
      final lastExportRaw = data['lastExport'] as String?;
      final lastExportDisplay = lastExportRaw == null
          ? 'Never'
          : lastExportRaw.replaceAll('T', ' ').substring(0, lastExportRaw.length < 16 ? lastExportRaw.length : 16);
      setState(() {
        _backup = backup;
        _lastExport = lastExportDisplay;
        _founders = (backupData['founders'] as List).length;
        _evidence = (backupData['evidence'] as List).length;
      });
    } catch (e) {
      setState(() => _exportStatus = e.toString());
    }
  }

  String _names() => 'benchpad-world-${DateTime.now().toIso8601String().substring(0, 10)}';

  String _csvQuote(dynamic v) => '"${(v?.toString() ?? '').replaceAll('"', '""')}"';

  String _csv(List<dynamic> rows, List<List<String>> fields) {
    final header = fields.map((f) => _csvQuote(f[0])).join(',');
    final lines = rows.map((r) {
      final row = r as Map<String, dynamic>;
      return fields.map((f) => _csvQuote(row[f[1]])).join(',');
    });
    return ([header, ...lines]).join('\n');
  }

  String _foundersCsv() => _csv((_backup!['data'] as Map)['founders'] as List, [
        ['Number', 'founder_number'],
        ['Name', 'display_name'],
        ['Tier', 'tier'],
        ['Status', 'status'],
        ['Location', 'location'],
        ['Created', 'created_at'],
      ]);

  String _evidenceCsv() => _csv((_backup!['data'] as Map)['evidence'] as List, [
        ['Phase', 'phase'],
        ['Title', 'title'],
        ['Category', 'category'],
        ['Readiness', 'readiness_percent'],
        ['Verification', 'verification_status'],
        ['Visibility', 'visibility'],
        ['Created', 'created_at'],
      ]);

  String _installationCsv() => _csv((_backup!['data'] as Map)['installations'] as List, [
        ['Bench ID', 'bench_id'],
        ['Location', 'location'],
        ['Site Type', 'site_type'],
        ['Status', 'status'],
        ['Verified', 'verified'],
        ['Public', 'public_visible'],
        ['Installed', 'installed_on'],
      ]);

  Future<void> _shareText(String content, String filename) async {
    await Share.shareXFiles([XFile.fromData(utf8.encode(content), name: filename, mimeType: 'text/plain')], subject: filename);
  }

  Future<void> _validatePasted() async {
    setState(() { _importStatus = null; _validatedBackup = null; });
    final text = _pasteController.text.trim();
    if (text.isEmpty) {
      setState(() => _importStatus = 'Paste the backup JSON first.');
      return;
    }
    try {
      final parsed = jsonDecode(text) as Map<String, dynamic>;
      final data = parsed['data'] as Map<String, dynamic>?;
      if (data == null || data['founders'] == null || data['evidence'] == null || data['installations'] == null) {
        throw Exception('This is not a complete BenchPad World backup.');
      }
      setState(() {
        _validatedBackup = parsed;
        _importStatus = 'Valid backup: ${(data['founders'] as List).length} founders, '
            '${(data['evidence'] as List).length} evidence items, '
            '${(data['installations'] as List).length} installations.';
      });
    } catch (e) {
      setState(() => _importStatus = e.toString());
    }
  }

  Future<void> _import() async {
    if (_validatedBackup == null) return;
    if (_mode == 'restore') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: NeumorphicPalette.background,
          titleTextStyle: const TextStyle(color: NeumorphicPalette.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
          contentTextStyle: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 14),
          title: const Text('Restore and replace?'),
          content: const Text(
            'Restore will replace current BenchPad World records. A safety snapshot will be created first. Continue?',
            style: TextStyle(color: NeumorphicPalette.textSecondary),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore', style: TextStyle(color: NeumorphicPalette.danger))),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() { _busy = true; _importStatus = 'Importing…'; });
    try {
      await _api.importBackup(mode: _mode, backup: _validatedBackup!);
      await _load();
      setState(() => _importStatus = 'Import completed.');
    } catch (e) {
      setState(() => _importStatus = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
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
      appBar: AppBar(title: const Text('Backup & Export')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('OWNER TOOL · PRIVATE DATA', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(height: 6),
          const Text(
            'Download a complete copy of BenchPad World data. Import first validates the backup before any database change.',
            style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.1,
            children: [
              _metric('LAST EXPORT', _lastExport),
              _metric('FOUNDERS', '$_founders'),
              _metric('ROADMAP ITEMS', '$_evidence'),
            ],
          ),
          const SizedBox(height: 20),
          _sectionCard(
            title: 'Export',
            subtitle: 'JSON is the complete restorable backup.',
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _backup == null ? null : () => _shareText(const JsonEncoder.withIndent('  ').convert(_backup), '${_names()}.json'),
                    child: const Text('COMPLETE JSON'),
                  ),
                  OutlinedButton(
                    onPressed: _backup == null ? null : () => _shareText(_foundersCsv(), '${_names()}-founders.csv'),
                    child: const Text('FOUNDERS CSV'),
                  ),
                  OutlinedButton(
                    onPressed: _backup == null ? null : () => _shareText(_evidenceCsv(), '${_names()}-roadmap.csv'),
                    child: const Text('ROADMAP CSV'),
                  ),
                  OutlinedButton(
                    onPressed: _backup == null ? null : () => _shareText(_installationCsv(), '${_names()}-installations.csv'),
                    child: const Text('INSTALLATIONS CSV'),
                  ),
                ],
              ),
              if (_exportStatus != null) ...[
                const SizedBox(height: 8),
                Text(_exportStatus!, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
              ],
            ],
          ),
          _sectionCard(
            title: 'Import',
            subtitle: 'Merge adds or updates records. Restore replaces data after a safety snapshot.',
            children: [
              const Text('Paste the backup JSON (open the file in any app, copy its contents):', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
              const SizedBox(height: 8),
              TextField(
                controller: _pasteController,
                maxLines: 6,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                decoration: const InputDecoration(hintText: '{"data": {"founders": [...], ...}}'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: _validatePasted, icon: const Icon(Icons.check_circle_outline), label: const Text('Validate backup')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                style: const TextStyle(color: NeumorphicPalette.textPrimary, fontSize: 14),
                dropdownColor: NeumorphicPalette.background,
                value: _mode,
                decoration: const InputDecoration(labelText: 'Mode'),
                items: const [
                  DropdownMenuItem(value: 'merge', child: Text('Merge with current data')),
                  DropdownMenuItem(value: 'restore', child: Text('Restore and replace current data')),
                ],
                onChanged: (v) => setState(() => _mode = v ?? 'merge'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _validatedBackup == null || _busy ? null : _import,
                style: ElevatedButton.styleFrom(backgroundColor: _mode == 'restore' ? NeumorphicPalette.danger : null),
                child: Text(_busy ? 'Importing…' : 'IMPORT BACKUP'),
              ),
              if (_importStatus != null) ...[
                const SizedBox(height: 8),
                Text(_importStatus!, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
              ],
            ],
          ),
        ],
      ),
    ));
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
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required String subtitle, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeumorphicBox(
        flat: true,
        borderRadius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
