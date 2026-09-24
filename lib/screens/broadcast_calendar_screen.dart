import 'dart:async';
import 'package:flutter/material.dart';
import '../models/broadcast_calendar.dart';
import '../services/benchpad_api.dart';
import '../services/broadcast_calendar_store.dart';
import '../theme/benchpad_dark_theme.dart';
import 'advertise_screen.dart';

/// Broadcast Calendar — pick a date and exact minute for a capsule's
/// publication, then hand off straight into the real, working "Post to
/// BenchPad" flow (AdvertiseScreen -> PublishFlowScreen) with that
/// moment attached as scheduledAt. The backend already holds a job
/// until its scheduled_at passes (`scheduled_at IS NULL OR
/// scheduled_at<=now()` gates every dispatch query) — no new backend
/// work needed, this screen only had to stop creating a separate,
/// disconnected local booking and start reusing the real publish
/// pipeline instead.
///
/// Deliberately stripped down from the original port: with one real
/// physical BenchPad and one real display, the bench picker,
/// LEFT/CENTER/RIGHT display picker, and Standard/Special-Moment mode
/// toggle were all choices with only one real answer — removed rather
/// than left as decoration.
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

  @override
  State<BroadcastCalendarScreen> createState() => _BroadcastCalendarScreenState();
}

class _BroadcastCalendarScreenState extends State<BroadcastCalendarScreen> {
  final _store = BroadcastCalendarStore();
  final _api = BenchpadApi();

  // Single real BenchPad, single real display — neither is a user
  // choice anymore (see class doc).
  static const _benchId = 'AUTO-NL'; // resolves to BP-AMS-001

  DateTime? _selectedDate;
  DateTime _monthCursor = DateTime(DateTime.now().year, DateTime.now().month);
  TimeOfDay _selectedTime = const TimeOfDay(hour: 14, minute: 25);

  Map<String, dynamic>? _dayAvailability;
  List<BroadcastInterval> _dayIntervals = [];

  @override
  void initState() {
    super.initState();
    final target = DateTime.now().add(const Duration(days: 7));
    _selectedDate = target;
    _monthCursor = DateTime(target.year, target.month);
    _loadDay();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  String get _dateStr => _selectedDate == null
      ? ''
      : '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';

  String get _timeStr => '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

  Future<void> _loadDay() async {
    if (_selectedDate == null) return;
    final bench = BroadcastBench.resolve(_benchId);
    final intervals = await _store.intervals(_dateStr, bench.id);
    final availability = await _store.availability(_dateStr, bench.id);
    if (mounted) setState(() { _dayIntervals = intervals; _dayAvailability = availability; });
  }

  bool _checkingSlot = false;

  Future<void> _continueToPost() async {
    if (_selectedDate == null) return;
    final d = _selectedDate!;
    final scheduledAt = DateTime(d.year, d.month, d.day, _selectedTime.hour, _selectedTime.minute);
    if (scheduledAt.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That moment is already in the past — pick a later date or time.')));
      return;
    }

    setState(() => _checkingSlot = true);
    bool conflict;
    try {
      // The display is shared across all three Time Capsules — this
      // checks every scheduled job, not just ones from this capsule.
      conflict = await _api.checkSlotConflict(scheduledAt);
    } catch (e) {
      if (!mounted) return;
      setState(() => _checkingSlot = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not check that time slot: $e')));
      return;
    }
    if (!mounted) return;
    setState(() => _checkingSlot = false);

    if (conflict) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That moment is already taken by another publication (from any Time Capsule) — pick a different time.')));
      return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => AdvertiseScreen(scheduledAt: scheduledAt)));
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: BPColors.bg,
        appBarTheme: const AppBarTheme(
          backgroundColor: BPColors.bg,
          foregroundColor: BPColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        textTheme: Theme.of(context).textTheme.apply(bodyColor: BPColors.textPrimary, displayColor: BPColors.textPrimary),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(backgroundColor: BPColors.yellow, foregroundColor: BPColors.bg, disabledBackgroundColor: BPColors.border, disabledForegroundColor: BPColors.textSecondary),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(foregroundColor: BPColors.textPrimary, disabledForegroundColor: BPColors.textSecondary, side: const BorderSide(color: BPColors.yellow)),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: BPColors.yellow),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: BPColors.card,
          labelStyle: const TextStyle(color: BPColors.textSecondary),
          floatingLabelStyle: const TextStyle(color: BPColors.yellow),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: BPColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: BPColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: BPColors.yellow, width: 1.5)),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text('Schedule Your Moment')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Choose the date and exact starting minute for your capsule publication on BP-AMS-001.',
              style: TextStyle(color: BPColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            _buildCalendar(),
            const SizedBox(height: 20),
            _buildTimeSelector(),
          ],
        ),
      ),
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
        const Text('CHOOSE A DATE', style: TextStyle(color: BPColors.yellow, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
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
                  color: isSelected ? BPColors.yellow.withOpacity(0.15) : BPColors.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isSelected ? BPColors.yellow : Colors.transparent),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${date.day}', style: TextStyle(fontSize: 11, color: isOther || isPast ? BPColors.textSecondary : BPColors.textPrimary)),
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
            const Expanded(child: Text('SELECT THE EXACT STARTING MINUTE', style: TextStyle(color: BPColors.yellow, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1))),
            Text(availabilityLabel.toUpperCase(), style: const TextStyle(fontSize: 9, color: BPColors.textSecondary)),
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
                const Text('HIGH-DEMAND DATE', style: TextStyle(color: Color(0xFFB486FF), fontSize: 8, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(specialEvent.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                const SizedBox(height: 4),
                const Text('This date sees more requests than usual — your slot may fill up faster.', style: TextStyle(color: BPColors.textSecondary, fontSize: 10)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            final picked = await showTimePicker(context: context, initialTime: _selectedTime);
            if (picked != null) setState(() => _selectedTime = picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: BPColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: BPColors.yellow.withOpacity(0.6)),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: BPColors.yellow, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('BenchPad local start', style: TextStyle(color: BPColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                Text(_timeStr, style: const TextStyle(color: BPColors.yellow, fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_dayIntervals.isNotEmpty) ...[
          const Text('DAY OCCUPANCY', style: TextStyle(color: BPColors.textSecondary, fontSize: 9, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          ..._dayIntervals.map((i) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: BPColors.card, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Text('${i.start}–${i.end}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(i.label, style: const TextStyle(fontSize: 10, color: BPColors.textSecondary))),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 12),
        ],
        ElevatedButton(
          onPressed: _checkingSlot ? null : _continueToPost,
          child: Text(_checkingSlot ? 'CHECKING SLOT…' : 'CONTINUE TO POST'),
        ),
      ],
    );
  }
}
