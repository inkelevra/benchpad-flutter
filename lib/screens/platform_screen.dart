import 'package:flutter/material.dart';
import '../services/benchpad_api.dart';
import '../theme/neumorphic_theme.dart';
import '../widgets/home_back_leading.dart';
import 'control_room_screen.dart';
import 'access_control_screen.dart';
import 'engineering_tools_screen.dart';
import 'publish_queue_screen.dart';
import 'owner_access_screen.dart';

/// Platform — grouped navigation links, ported from index.html's
/// platformPanel section.
///
/// Gated on Owner Access: these are engineering/owner tools, not
/// something an ordinary visitor should land on. Access, recovery,
/// and platform-access used to be three separate, confusingly-named
/// screens (Owner Access / Access Recovery / Platform Access) each
/// reachable as an equal-weight link here — consolidated so Owner
/// Access is the one gate, and this whole screen requires it before
/// showing anything else.
class PlatformScreen extends StatefulWidget {
  const PlatformScreen({super.key});

  @override
  State<PlatformScreen> createState() => _PlatformScreenState();
}

class _PlatformScreenState extends State<PlatformScreen> {
  final _api = BenchpadApi();
  bool? _isOwner; // null = still checking

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final owner = await _api.getOwnerStatus();
    if (mounted) setState(() => _isOwner = owner);
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
        appBar: AppBar(leading: Builder(builder: homeBackLeading), leadingWidth: 72, centerTitle: true, title: const Text('BenchPad Platform')),
        body: _buildBody(context),
      ),
    );
  }

  // Temporarily disabled per owner's request, to skip password
  // re-entry after every fresh install during active engineering/
  // testing. Re-enable (set back to false) before any public/
  // Kickstarter-facing build.
  static const _gateTemporarilyDisabled = true;

  Widget _buildBody(BuildContext context) {
    if (_gateTemporarilyDisabled) {
      return _buildPlatformList(context);
    }
    if (_isOwner == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_isOwner == false) {
      // Not signed in — show the Owner Access gate directly instead
      // of a list of links a non-owner shouldn't see at all.
      return OwnerAccessScreen(embedded: true, onOwnerVerified: () => setState(() => _isOwner = true));
    }
    return _buildPlatformList(context);
  }

  Widget _buildPlatformList(BuildContext context) {
    return NotificationListener<OverscrollIndicatorNotification>(
      onNotification: (n) {
        n.disallowIndicator();
        return true;
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('BENCHPAD ECOSYSTEM', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(height: 6),
          const Text('One organized entry point for the software, cloud and device layers.', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          const Text('PLATFORM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: NeumorphicPalette.textSecondary, letterSpacing: 1)),
          const SizedBox(height: 2),
          const Text('Essential working modules', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
          const SizedBox(height: 10),
          _link(
            context,
            icon: Icons.build_outlined,
            title: 'BenchPad Engineering Tools',
            subtitle: 'Receiver mode, device onboarding, heartbeat',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EngineeringToolsScreen())),
          ),
          _link(
            context,
            icon: Icons.tune,
            title: 'Control Room',
            subtitle: 'Publishing, capsules, devices and access in one place',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ControlRoomScreen())),
          ),
          _link(
            context,
            icon: Icons.playlist_play_outlined,
            title: 'Publish Queue',
            subtitle: 'Live display queue, locks, cancel individual jobs',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PublishQueueScreen())),
          ),
          const SizedBox(height: 14),
          const Text('OWNER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: NeumorphicPalette.textSecondary, letterSpacing: 1)),
          const SizedBox(height: 10),
          _link(
            context,
            icon: Icons.vpn_key_outlined,
            title: 'Platform Access',
            subtitle: "Controls who can reach BenchPad's public website — separate from this app's own sign-in",
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccessControlScreen())),
          ),
          _link(
            context,
            icon: Icons.logout,
            title: 'Sign Out',
            subtitle: 'End this Owner Access session on this device',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerAccessScreen())),
          ),
        ],
      ),
    );
  }

  Widget _link(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeumorphicBox(
        flat: true,
        borderRadius: 16,
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: NeumorphicPalette.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: NeumorphicPalette.accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: NeumorphicPalette.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: NeumorphicPalette.textSecondary),
          ],
        ),
      ),
    );
  }
}
