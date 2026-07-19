import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:go_glyder/core/theme.dart';
import 'package:go_glyder/models/calendar_entry.dart';
import 'package:go_glyder/services/school_calendar_service.dart';

/// One merged calendar across everything the user belongs to: the school-wide
/// calendars (admin .ics uploads, served from Storage + cached), plus every
/// group's own inline events. All aggregated client-side, tagged by source.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final SchoolCalendarService _cal = SchoolCalendarService.instance;

  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime.now();

  List<CalendarEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = <CalendarEntry>[];

    try {
      // School-wide calendars + each group's own inline events, gathered by
      // the shared service (same set the map's event search indexes).
      entries.addAll(await _cal.fetchAllMyEvents());
    } catch (_) {
      // Leave whatever loaded; the UI shows an empty state otherwise.
    }

    if (mounted) {
      setState(() {
        _entries = entries;
        _loading = false;
      });
    }
  }

  List<CalendarEntry> _eventsForDate(DateTime date) {
    return _entries.where((e) {
      return e.date.year == date.year &&
          e.date.month == date.month &&
          e.date.day == date.day;
    }).toList()..sort((a, b) => a.time.compareTo(b.time));
  }

  bool _hasEventsOnDate(DateTime date) => _eventsForDate(date).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _monthHeader(),
                        _grid(),
                        _dayEvents(),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _monthHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      color: AppColors.brandDark,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30),
            onPressed: () => setState(() {
              _focusedMonth =
                  DateTime(_focusedMonth.year, _focusedMonth.month - 1);
            }),
          ),
          Text(
            DateFormat('MMMM yyyy').format(_focusedMonth),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white, size: 30),
            onPressed: () => setState(() {
              _focusedMonth =
                  DateTime(_focusedMonth.year, _focusedMonth.month + 1);
            }),
          ),
        ],
      ),
    );
  }

  Widget _grid() {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final firstWeekday = firstDay.weekday % 7;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        boxShadow: kCardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandDark,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: 42,
            itemBuilder: (context, index) {
              final dayNumber = index - firstWeekday + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox();
              }
              final date =
                  DateTime(_focusedMonth.year, _focusedMonth.month, dayNumber);
              final isToday = DateUtils.isSameDay(date, DateTime.now());
              final isSelected = DateUtils.isSameDay(date, _selectedDate);
              final hasEvents = _hasEventsOnDate(date);

              return GestureDetector(
                onTap: () => setState(() => _selectedDate = date),
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.brandDark
                        : isToday
                            ? AppColors.brandTint
                            : Colors.transparent,
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected || isToday
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (hasEvents)
                        Positioned(
                          bottom: 5,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.brandGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _dayEvents() {
    final events = _eventsForDate(_selectedDate);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, MMMM d').format(_selectedDate),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.event_available_rounded,
                        size: 44, color: AppColors.textTertiary),
                    const SizedBox(height: 10),
                    Text('No events this day',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            )
          else
            for (final e in events) _eventRow(e),
        ],
      ),
    );
  }

  Widget _eventRow(CalendarEntry e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 42,
            margin: const EdgeInsets.only(top: 2, right: 12),
            decoration: BoxDecoration(
              color: e.isSchoolWide
                  ? AppColors.brandDark
                  : AppColors.brandAccent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  [
                    if (e.time.isNotEmpty) e.time,
                    if (e.location.isNotEmpty) e.location,
                  ].join(' · '),
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          _sourceTag(e),
        ],
      ),
    );
  }

  Widget _sourceTag(CalendarEntry e) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (e.isSchoolWide ? AppColors.brandDark : AppColors.brandAccent)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        e.sourceLabel,
        style: TextStyle(
          color: e.isSchoolWide ? AppColors.brandDark : AppColors.brandGreen,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
