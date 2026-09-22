import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/broadcast_calendar.dart';
import '../services/broadcast_calendar_store.dart';
import '../theme/neumorphic_theme.dart';

/// Broadcast Calendar — schedule a capsule's publication moment, ported
/// from broadcast-calendar.html.
///
/// This is a local-only feature in the PWA itself (no server calls at
/// all — bookings live in localStorage there, SharedPreferences here).
class BroadcastCalendarScreen extends StatefulWidget {
  final String sphere;
  final String capsuleType;
  final int capsuleNumber;
  final String ownerName;
  final String ownerCountry;
  final bool contentReady;

  const BroadcastCalendarScreen({
    super.key,
    required this.sphere,
    required this.capsuleType,
    required this.capsuleNumber,
    this.ownerName = '',
    this.ownerCountry = '',
    this.contentReady = false,
  });

  String get _capsuleKey => '$sphere:$capsuleType:$capsuleNumber';

  @override
  State<BroadcastCalendarScreen> createState() => _BroadcastCalendarScreenState();
}

class _BroadcastCalendarScreenState extends State<BroadcastCalendarScreen> {
  final _store = BroadcastCalendarStore();

  String _selectedBenchId = 'BP-AMS-001';
  DateTime? _selectedDate;
  DateTime _monthCursor = DateTime(DateTime.now().year, DateTime.now().month);
  String _mode = 'standard';
  TimeOfDay _selectedTime = const TimeOfDay(hour: 14, minute: 25);
  String _displaySelection = 'AUTO';

  BroadcastHold? _hold;
  BroadcastBooking? _booking;
  Timer? _countdownTimer;
  Duration _holdRemaining = Duration.zero;

  List<BroadcastInterval> _dayIntervals = [];
  Map<String, dynamic>? _dayAvailability;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final target = DateTime.now().add(const Duration(days: 7));
    _selectedDate = target;
    _monthCursor = DateTime(target.year, target.month);
    _load();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String get _dateStr => _selectedDate == null
      ? ''
      : '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';

  String get _timeStr => '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    _booking = await _store.bookingForCapsule(widget._capsuleKey);
    _hold = await _store.activeHoldForCapsule(widget._capsuleKey);
    if (_hold != null) {
      _selectedBenchId = _hold!.benchSelectionId;
      final parts = _hold!.date.split('-').map(int.parse).toList();
      _selectedDate = DateTime(parts[0], parts[1], parts[2]);
      _mode = _hold!.mode;
      final timeParts = _hold!.start.split(':').map(int.parse).toList();
      _selectedTime = TimeOfDay(hour: timeParts[0], minute: timeParts[1]);
      _startCountdown();
    } else if (_booking != null) {
      _selectedBenchId = _booking!.benchSelectionId;
      final parts = _booking!.date.split('-').map(int.parse).toList();
      _selectedDate = DateTime(parts[0], parts[1], parts[2]);
      _mode = _booking!.mode;
    }
    await _loadDay();
    if (mounted) setState(() {});
  }

  Future<void> _loadDay() async {
    if (_selectedDate == null) return;
    final bench = BroadcastBench.resolve(_selectedBenchId);
    final intervals = await _store.intervals(_dateStr, bench.id);
    final availability = await _store.availability(_dateStr, bench.id);
    if (mounted) setState(() { _dayIntervals = intervals; _dayAvailability = availability; });
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    if (_hold == null) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final remaining = _hold!.expiresAt.difference(DateTime.now());
      if (remaining.isNegative) {
        t.cancel();
        setState(() { _hold = null; _holdRemaining = Duration.zero; });
        return;
      }
      setState(() => _holdRemaining = remaining);
    });
  }

  Future<void> _createHold() async {
    if (_selectedDate == null) return;
    setState(() => _busy = true);
    try {
      final hold = await _store.holdSlot(
        capsuleKey: widget._capsuleKey,
        sphere: widget.sphere,
        capsuleType: widget.capsuleType,
        capsuleNumber: widget.capsuleNumber,
        benchSelectionId: _selectedBenchId,
        date: _dateStr,
        start: _timeStr,
        displayId: _displaySelection,
        mode: _mode,
      );
      setState(() => _hold = hold);
      _startCountdown();
      await _loadDay();
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmBooking() async {
    if (_hold == null) return;
    setState(() => _busy = true);
    try {
      final booking = await _store.confirmHold(
        _hold!.id,
        owner: widget.ownerName,
        country: widget.ownerCountry,
        contentReady: widget.contentReady,
      );
      _countdownTimer?.cancel();
      setState(() { _booking = booking; _hold = null; });
      await _loadDay();
      _toast(booking.allocationRequest ? 'Special Moment request submitted' : 'Broadcast booking confirmed');
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _releaseHold() async {
    if (_hold == null) return;
    await _store.releaseHold(_hold!.id);
    _countdownTimer?.cancel();
    setState(() { _hold = null; _holdRemaining = Duration.zero; });
    await _loadDay();
  }

  Future<void> _cancelBooking() async {
    if (_booking == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeumorphicPalette.background,
        titleTextStyle: const TextStyle(color: NeumorphicPalette.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        contentTextStyle: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 14),
        title: const Text('Cancel this BenchPad booking?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep booking')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel booking', style: TextStyle(color: NeumorphicPalette.danger))),
        ],
      ),
    );
    if (ok != true) return;
    await _store.cancelBooking(_booking!.id);
    setState(() => _booking = null);
    await _loadDay();
    _toast('Booking cancelled');
  }

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

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
      appBar: AppBar(title: const Text('Schedule Your Moment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Choose the BenchPad, local date and exact starting minute for your capsule publication.',
            style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (_booking != null) _buildBookingCard() else ...[
            _buildBenchPicker(),
            const SizedBox(height: 20),
            _buildCalendar(),
            const SizedBox(height: 20),
            _buildTimeSelector(),
            const SizedBox(height: 16),
            if (_hold != null) _buildHoldBox(),
          ],
        ],
      ),
    ));
  }

  Widget _buildBenchPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('WHERE SHOULD YOUR MESSAGE APPEAR?', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(height: 10),
        ...BroadcastBench.all.map((bench) {
          final active = bench.id == _selectedBenchId;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: bench.bookable ? () { setState(() => _selectedBenchId = bench.id); _loadDay(); } : null,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bench.bookable ? NeumorphicPalette.background : NeumorphicPalette.background.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: active ? NeumorphicPalette.accent : Colors.transparent, width: 1.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(bench.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          const SizedBox(height: 3),
                          Text(bench.note, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 10)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: NeumorphicPalette.background, borderRadius: BorderRadius.circular(999)),
                      child: Text(bench.status, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCalendar() {
    final year = _monthCursor.year, month = _monthCursor.month;
    final first = DateTime(year, month, 1);
    final offset = (first.weekday - 1) % 7;
    final start = first.subtract(Duration(days: offset));
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CHOOSE A LOCAL BENCHPAD DATE', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _monthCursor = DateTime(year, month - 1))),
            Text('${_monthName(month)} $year', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => _monthCursor = DateTime(year, month + 1))),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, crossAxisSpacing: 4, mainAxisSpacing: 4),
          itemCount: 42,
          itemBuilder: (context, i) {
            final date = start.add(Duration(days: i));
            final isOther = date.month != month;
            final isPast = date.isBefore(today);
            final isSelected = _selectedDate != null && date.year == _selectedDate!.year && date.month == _selectedDate!.month && date.day == _selectedDate!.day;
            final isSpecial = SpecialEvent.forDate(date) != null;

            return InkWell(
              onTap: isPast ? null : () { setState(() { _selectedDate = date; }); _loadDay(); },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? NeumorphicPalette.accent.withOpacity(0.15) : NeumorphicPalette.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isSelected ? NeumorphicPalette.accent : Colors.transparent),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${date.day}', style: TextStyle(fontSize: 11, color: isOther || isPast ? NeumorphicPalette.textSecondary : NeumorphicPalette.textPrimary)),
                      if (isSpecial) const Icon(Icons.star, size: 8, color: Color(0xFFB486FF)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  String _monthName(int m) => const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][m - 1];

  Widget _buildTimeSelector() {
    final specialEvent = _selectedDate != null ? SpecialEvent.forDate(_selectedDate!) : null;
    final availabilityLabel = (_dayAvailability?['label'] as String?) ?? '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Text('SELECT THE EXACT STARTING MINUTE', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1))),
            Text(availabilityLabel.toUpperCase(), style: const TextStyle(fontSize: 9, color: NeumorphicPalette.textSecondary)),
          ],
        ),
        if (specialEvent != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFB486FF).withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SPECIAL EVENT ALLOCATION', style: TextStyle(color: Color(0xFFB486FF), fontSize: 8, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(specialEvent.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('Standard Broadcast'),
                selected: _mode == 'standard',
                onSelected: specialEvent != null ? null : (_) => setState(() => _mode = 'standard'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: const Text('Special Moment'),
                selected: _mode == 'special',
                onSelected: (_) => setState(() => _mode = 'special'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('BenchPad local start', style: TextStyle(color: NeumorphicPalette.textPrimary)),
          subtitle: Text(_timeStr, style: const TextStyle(color: NeumorphicPalette.textSecondary)),
          trailing: const Icon(Icons.access_time, color: NeumorphicPalette.textSecondary),
          onTap: () async {
            final picked = await showTimePicker(context: context, initialTime: _selectedTime);
            if (picked != null) setState(() => _selectedTime = picked);
          },
        ),
        DropdownButtonFormField<String>(
          style: const TextStyle(color: NeumorphicPalette.textPrimary, fontSize: 14),
          dropdownColor: NeumorphicPalette.background,
          value: _displaySelection,
          decoration: const InputDecoration(labelText: 'Display'),
          items: const [
            DropdownMenuItem(value: 'AUTO', child: Text('Automatically assign')),
            DropdownMenuItem(value: 'LEFT', child: Text('Left display')),
            DropdownMenuItem(value: 'CENTER', child: Text('Center display')),
            DropdownMenuItem(value: 'RIGHT', child: Text('Right display')),
          ],
          onChanged: (v) => setState(() => _displaySelection = v ?? 'AUTO'),
        ),
        const SizedBox(height: 12),
        if (_dayIntervals.isNotEmpty) ...[
          const Text('DAY OCCUPANCY', style: TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 9, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          ..._dayIntervals.map((i) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: NeumorphicPalette.background, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Text('${i.start}–${i.end}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(i.label, style: const TextStyle(fontSize: 10, color: NeumorphicPalette.textSecondary))),
                      Text(i.displayId, style: const TextStyle(fontSize: 9, color: NeumorphicPalette.accent)),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 12),
        ],
        ElevatedButton(
          onPressed: _busy || _hold != null ? null : _createHold,
          child: const Text('HOLD THIS TIME FOR 10 MINUTES'),
        ),
      ],
    );
  }

  Widget _buildHoldBox() {
    final m = _holdRemaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _holdRemaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFFFD84D).withOpacity(0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFFD84D).withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_hold!.allocationRequest ? 'Your Special Moment request is held for confirmation.' : 'This time is reserved for you.',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFFFE58B))),
          const SizedBox(height: 4),
          Text('Expires in $m:$s', style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 11)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: ElevatedButton(onPressed: _busy ? null : _confirmBooking, child: const Text('CONFIRM BOOKING'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: _releaseHold, child: const Text('RELEASE'))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard() {
    final booking = _booking!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Text('MY BROADCAST', style: TextStyle(color: NeumorphicPalette.accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFFFD84D).withOpacity(0.1), borderRadius: BorderRadius.circular(999)),
              child: Text(_store.statusLabel(booking.status).toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFFFE684))),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 2.2,
          children: [
            _summaryCell('BENCHPAD', booking.benchName),
            _summaryCell('DISPLAY', booking.displayId),
            _summaryCell('LOCAL TIME', '${booking.date} · ${booking.localStart}–${booking.localEnd}'),
            _summaryCell('DEADLINE', _store.formatInZone(booking.contentDeadline, booking.timezone)),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => Share.share(_store.buildIcs(booking), subject: '${booking.capsuleId}-BenchPad-Broadcast.ics'),
              child: const Text('SHARE .ICS'),
            ),
            OutlinedButton(
              onPressed: () {
                setState(() => _booking = null);
                _loadDay();
              },
              child: const Text('RESCHEDULE'),
            ),
            OutlinedButton(
              onPressed: _cancelBooking,
              style: OutlinedButton.styleFrom(foregroundColor: NeumorphicPalette.danger, side: const BorderSide(color: NeumorphicPalette.danger)),
              child: const Text('CANCEL BOOKING'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryCell(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: NeumorphicPalette.background, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: NeumorphicPalette.textSecondary, fontSize: 7, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
