import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/neumorphic_theme.dart';
import '../widgets/home_back_leading.dart';

/// Kinesus Info — ported 1:1 from index.html's #kinesusInfoView: the
/// same copy, the same purple (#9a66ff) icon colour, the same website/
/// email contact rows, the same QR card (same PNG asset), the same 4
/// feature cards, and the same collapsible Environmental Impact and
/// Privacy Policy sections — restyled in the app's neumorphic look.
class KinesusInfoScreen extends StatefulWidget {
  const KinesusInfoScreen({super.key});

  @override
  State<KinesusInfoScreen> createState() => _KinesusInfoScreenState();
}

class _KinesusInfoScreenState extends State<KinesusInfoScreen> {
  static const _purple = Color(0xFF9A66FF);

  bool _impactExpanded = false;
  bool _privacyExpanded = false;
  bool _creditsExpanded = false;
  bool _petitionsExpanded = false;

  final _impactKey = GlobalKey();
  final _privacyKey = GlobalKey();
  final _creditsKey = GlobalKey();
  final _petitionsKey = GlobalKey();

  Future<void> _openUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  /// Expanding a collapsible section previously left the newly-revealed
  /// content off-screen with no visual sign anything happened until
  /// the user scrolled manually — this brings it into view right away.
  void _scrollIntoView(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 260), curve: Curves.easeOut, alignment: 0.05);
      }
    });
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
        appBar: AppBar(leading: Builder(builder: homeBackLeading), leadingWidth: 72, centerTitle: true, title: const Text('Kinesus Info')),
        body: NotificationListener<OverscrollIndicatorNotification>(
          onNotification: (n) {
            n.disallowIndicator();
            return true;
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(),
              const SizedBox(height: 18),
              NeumorphicBox(
                flat: true,
                borderRadius: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Kinesus develops smart urban solutions that connect communities, technology and sustainable development.',
                      style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 13, height: 1.55),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Our mission is to create innovative systems that improve urban life and public communication.',
                      style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 13, height: 1.55),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'We focus on solutions such as BenchPad — an intelligent platform for urban benches that provides real-time information, supports local communities and reduces environmental impact through energy-efficient and sustainable technology.',
                      style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 13, height: 1.55),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _buildContactRow(icon: Icons.public, label: 'Website', value: 'https://kinesus.nl', onTap: () => _openUrl('https://kinesus.nl/')),
              const SizedBox(height: 10),
              _buildContactRow(icon: Icons.mail_outline, label: 'Email', value: 'kinesus@yahoo.com', onTap: () => _openUrl('mailto:kinesus@yahoo.com')),
              const SizedBox(height: 20),
              const Text('WHAT WE DO', style: TextStyle(color: _purple, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.95,
                children: [
                  _buildFeature(Icons.event_seat_outlined, 'Smart Benches', 'Real-time information where people are.'),
                  _buildFeature(Icons.groups_outlined, 'Stronger Communities', 'Connecting local businesses and residents.'),
                  _buildFeature(Icons.eco_outlined, 'Sustainable Impact', 'Low power, long life, less environmental footprint.'),
                  _buildFeature(Icons.hub_outlined, 'Innovative Technology', 'Built for cities that care about the future.'),
                ],
              ),
              const SizedBox(height: 16),
              _buildImpactSection(),
              const SizedBox(height: 10),
              _buildPetitionsSection(),
              const SizedBox(height: 10),
              _buildPrivacySection(),
              const SizedBox(height: 10),
              _buildCreditsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: NeumorphicPalette.background,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: NeumorphicPalette.shadowDark, offset: const Offset(3, 3), blurRadius: 7),
              BoxShadow(color: NeumorphicPalette.shadowLight, offset: const Offset(-3, -3), blurRadius: 7),
            ],
          ),
          child: Image.asset('assets/images/kinesus-logo.png', fit: BoxFit.contain),
        ),
        const SizedBox(width: 14),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kinesus Info', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary)),
            SizedBox(height: 2),
            Text('Smart Urban Solutions', style: TextStyle(fontSize: 12, color: NeumorphicPalette.textSecondary)),
          ],
        ),
      ],
    );
  }

  Widget _buildContactRow({required IconData icon, required String label, required String value, required VoidCallback onTap}) {
    return NeumorphicBox(
      soft: true,
      borderRadius: 16,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _purple.withOpacity(0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: _purple, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: NeumorphicPalette.textSecondary)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: NeumorphicPalette.textPrimary)),
              ],
            ),
          ),
          const Icon(Icons.north_east, size: 16, color: NeumorphicPalette.textSecondary),
        ],
      ),
    );
  }

  Widget _buildFeature(IconData icon, String title, String text) {
    return NeumorphicBox(
      flat: true,
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _purple, size: 24),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary), maxLines: 2),
          const SizedBox(height: 4),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 10, color: NeumorphicPalette.textSecondary, height: 1.35)),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleHeader({required String icon, required String kicker, required String title, required bool expanded, required VoidCallback onTap, IconData? iconData}) {
    return NeumorphicBox(
      soft: true,
      borderRadius: 14,
      onTap: onTap,
      child: Row(
        children: [
          if (iconData != null)
            Icon(iconData, size: 18, color: _purple)
          else
            Text(icon, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _purple)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kicker, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: NeumorphicPalette.textSecondary, letterSpacing: 0.5)),
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: NeumorphicPalette.textPrimary)),
              ],
            ),
          ),
          AnimatedRotation(
            turns: expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 150),
            child: const Icon(Icons.expand_more_rounded, size: 20, color: NeumorphicPalette.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactSection() {
    Widget metric(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: NeumorphicPalette.textSecondary, letterSpacing: 0.4)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: NeumorphicPalette.textPrimary)),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCollapsibleHeader(
          icon: 'CO₂',
          kicker: 'SUSTAINABILITY',
          title: 'Environmental Impact',
          expanded: _impactExpanded,
          onTap: () {
            setState(() => _impactExpanded = !_impactExpanded);
            if (_impactExpanded) _scrollIntoView(_impactKey);
          },
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          child: !_impactExpanded
              ? const SizedBox(width: double.infinity)
              : Padding(
                  key: _impactKey,
                  padding: const EdgeInsets.only(top: 10),
                  child: NeumorphicBox(
                    flat: true,
                    borderRadius: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            metric('SOLAR ENERGY', 'Awaiting telemetry'),
                            metric('ESTIMATED CO₂ IMPACT', 'Measurement pending'),
                            metric('PAPER REDUCTION', 'Methodology pending'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'BenchPad will publish measured energy and environmental indicators only after the physical power system is connected and the calculation method is documented.',
                          style: TextStyle(fontSize: 10.5, color: NeumorphicPalette.textSecondary, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPetitionsSection() {
    Widget petitionButton(String platform, String url) {
      return Expanded(
        child: NeumorphicBox(
          soft: true,
          borderRadius: 12,
          onTap: () => _openUrl(url),
          child: SizedBox(
            height: 48,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.campaign_outlined, size: 16, color: NeumorphicPalette.accent),
                const SizedBox(height: 4),
                Text(platform, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCollapsibleHeader(
          icon: '',
          iconData: Icons.how_to_vote_outlined,
          kicker: 'ADVOCACY',
          title: 'Petitions',
          expanded: _petitionsExpanded,
          onTap: () {
            setState(() => _petitionsExpanded = !_petitionsExpanded);
            if (_petitionsExpanded) _scrollIntoView(_petitionsKey);
          },
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          child: !_petitionsExpanded
              ? const SizedBox(width: double.infinity)
              : Padding(
                  key: _petitionsKey,
                  padding: const EdgeInsets.only(top: 10),
                  child: NeumorphicBox(
                    flat: true,
                    borderRadius: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Same petition, calling for a faster shift away from paper and non-digital billboard advertising toward sustainable outdoor advertising in Amsterdam — hosted on two platforms.',
                          style: TextStyle(fontSize: 10.5, color: NeumorphicPalette.textSecondary, height: 1.5),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            petitionButton('change.org', 'https://www.change.org/p/versnel-de-overgang-naar-duurzame-buitenreclame-in-amsterdam'),
                            const SizedBox(width: 10),
                            petitionButton('petities.nl', 'https://petities.nl/petitions/versnel-de-overgang-naar-duurzame-buitenreclame-in-amsterdam?locale=nl'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPrivacySection() {
    Widget h4(String text) => Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary)),
        );
    Widget p(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(text, style: const TextStyle(fontSize: 10.5, color: NeumorphicPalette.textSecondary, height: 1.5)),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCollapsibleHeader(
          icon: '',
          iconData: Icons.shield_outlined,
          kicker: 'PRIVACY & DATA',
          title: 'Privacy Policy',
          expanded: _privacyExpanded,
          onTap: () {
            setState(() => _privacyExpanded = !_privacyExpanded);
            if (_privacyExpanded) _scrollIntoView(_privacyKey);
          },
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          child: !_privacyExpanded
              ? const SizedBox(width: double.infinity)
              : Padding(
                  key: _privacyKey,
                  padding: const EdgeInsets.only(top: 10),
                  child: NeumorphicBox(
                    flat: true,
                    borderRadius: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Data controller', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary)),
                        const SizedBox(height: 2),
                        const Text('Shapi Shakhshaev · BenchPad / Kinesus project', style: TextStyle(fontSize: 10.5, color: NeumorphicPalette.textSecondary)),
                        GestureDetector(
                          onTap: () => _openUrl('mailto:kinesus@yahoo.com'),
                          child: const Text('kinesus@yahoo.com', style: TextStyle(fontSize: 10.5, color: _purple)),
                        ),
                        const Text('Last updated: 25 August 2026', style: TextStyle(fontSize: 10.5, color: NeumorphicPalette.textSecondary)),
                        h4('Technical infrastructure'),
                        p('BenchPad uses Cloudflare infrastructure to protect and deliver the service. When the PWA is opened, Cloudflare may automatically process technical request data, including the IP address, date and time, browser or device information, the requested page and security signals. This processing supports delivery, security, abuse prevention, stability and error diagnosis.'),
                        h4('Community Pulse'),
                        p("BenchPad may estimate a visitor's country and settlement from technical location information. The public visualisation places one point at the general centre of a city, town, village or other settlement and combines visitors from the same settlement."),
                        p('IP addresses, street addresses, districts, precise GPS positions, device IDs, session IDs and individual browsing histories are not displayed publicly.'),
                        h4('Usage statistics'),
                        p('Limited statistics may include page views, unique and returning visitors, QR or NFC entry, functions used, device category, interface language, and successful or failed platform actions.'),
                        h4('Reports, feedback and ideas'),
                        p('When you submit a report through Report / Feedback, BenchPad stores the category, description, location, privacy choice and any photo you attach. If you request a response, your email address is stored to allow a reply and is never shown publicly. Public reports show only the category, description, location and status to other visitors — never your email.'),
                        p('When you submit an idea through the "Got an idea?" form, BenchPad stores the message and, if you provide one, an email address to allow a reply.'),
                        h4('Purpose and legal basis'),
                        p('Essential technical processing is based on the legitimate interest in securing, delivering and improving the service. Optional functions that legally require consent will be activated only after the relevant choice is made.'),
                        h4('Retention and your rights'),
                        p('Technical and analytical data is retained only for as long as reasonably necessary. Aggregated statistics that no longer identify an individual may be retained for historical project reporting.'),
                        p('You may request access, correction, deletion, restriction or object to relevant processing by contacting kinesus@yahoo.com. You may also lodge a complaint with the competent data-protection authority.'),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCreditsSection() {
    Widget credit(String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: NeumorphicPalette.textPrimary)),
              const SizedBox(height: 4),
              Text(body, style: const TextStyle(fontSize: 10.5, color: NeumorphicPalette.textSecondary, height: 1.5)),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCollapsibleHeader(
          icon: '',
          iconData: Icons.favorite_border,
          kicker: 'ABOUT',
          title: 'Credits',
          expanded: _creditsExpanded,
          onTap: () {
            setState(() => _creditsExpanded = !_creditsExpanded);
            if (_creditsExpanded) _scrollIntoView(_creditsKey);
          },
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          child: !_creditsExpanded
              ? const SizedBox(width: double.infinity)
              : Padding(
                  key: _creditsKey,
                  padding: const EdgeInsets.only(top: 10),
                  child: NeumorphicBox(
                    flat: true,
                    borderRadius: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        credit('Weather icons', 'Weather icons designed by upklyak — Magnific.com\n\nUsed under the Free for Commercial Use (with Attribution) license.'),
                        credit('Neumorphic design system', 'App-wide light neumorphic ("soft UI") look adapted from the open-source neumorphism-ui-bootstrap kit by Themesberg.\n\ngithub.com/themesberg/neumorphism-ui-bootstrap'),
                        credit('UI elements — Uiverse.io', 'Several widgets (loading indicators, checkboxes, the glass radio selector, the glow blob field) adapted from community submissions on Uiverse.io.\n\nAll content on Uiverse.io is published under the MIT license.'),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
