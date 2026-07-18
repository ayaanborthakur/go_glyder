import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:go_glyder/core/theme.dart';
import 'package:go_glyder/features/account/presentation/profile_page.dart';
import 'package:go_glyder/features/community/presentation/group_trips_page.dart';
import 'package:go_glyder/services/firestore_service.dart';

/// A single group inside a school: its info, carpool rides, its own small
/// event list, and members. Membership is open (joined from the directory),
/// so there's no invite code or QR here anymore.
class GroupDetailPage extends StatefulWidget {
  final String schoolId;
  final String groupId;
  final String groupName;
  final String? schoolName;

  const GroupDetailPage({
    super.key,
    required this.schoolId,
    required this.groupId,
    required this.groupName,
    this.schoolName,
  });

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  FirestoreService get _fs => FirestoreService.instance;

  Future<void> _leave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave group?'),
        content: Text('You\'ll no longer see "${widget.groupName}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _fs.leaveGroup(widget.schoolId, widget.groupId);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.groupName)),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _fs
            .schools
            .doc(widget.schoolId)
            .collection('groups')
            .doc(widget.groupId)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data?.data() ?? const {};
          final description = (data['description'] ?? '') as String;
          final pickupArea = (data['pickupArea'] ?? '') as String;
          final members = (data['members'] ?? 0) as int;
          final events = ((data['events'] as List?) ?? const [])
              .cast<Map<String, dynamic>>();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _aboutCard(pickupArea, members),
              const SizedBox(height: 14),
              _ridesButton(),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _eventsSection(events),
              const SizedBox(height: 24),
              _membersSection(),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _leave,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Leave group'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  minimumSize: const Size.fromHeight(50),
                  side: BorderSide(
                    color: AppColors.danger.withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _ridesButton() {
    return Material(
      color: AppColors.brandDark,
      borderRadius: AppRadius.lgAll,
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GroupTripsPage(
              schoolId: widget.schoolId,
              groupId: widget.groupId,
              groupName: widget.groupName,
              schoolName: widget.schoolName,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(
                Icons.directions_car_filled_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Carpool rides',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Post a ride or request a seat',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _aboutCard(String pickupArea, int members) {
    Widget row(IconData icon, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.brandGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.schoolName != null && widget.schoolName!.isNotEmpty)
            row(Icons.school_outlined, widget.schoolName!),
          if (pickupArea.isNotEmpty) row(Icons.place_outlined, pickupArea),
          row(Icons.groups_outlined, '$members member${members == 1 ? '' : 's'}'),
        ],
      ),
    );
  }

  // ---- Group's own events (inline list) ----
  Widget _eventsSection(List<Map<String, dynamic>> events) {
    events.sort((a, b) {
      final da = (a['date'] as Timestamp?)?.toDate() ?? DateTime(2100);
      final dbb = (b['date'] as Timestamp?)?.toDate() ?? DateTime(2100);
      return da.compareTo(dbb);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Group events',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            TextButton.icon(
              onPressed: _addEvent,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (events.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.lgAll,
              boxShadow: kCardShadow,
            ),
            child: Text(
              'No events yet. Add practices, games, or trips — they\'ll show '
              'on everyone\'s calendar.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.lgAll,
              boxShadow: kCardShadow,
            ),
            child: Column(
              children: [
                for (var i = 0; i < events.length; i++)
                  _eventTile(events[i], last: i == events.length - 1),
              ],
            ),
          ),
      ],
    );
  }

  Widget _eventTile(Map<String, dynamic> e, {required bool last}) {
    final date = (e['date'] as Timestamp?)?.toDate();
    final sub = [
      if (date != null) DateFormat('EEE, MMM d').format(date),
      if ((e['time'] ?? '').toString().isNotEmpty) e['time'],
      if ((e['location'] ?? '').toString().isNotEmpty) e['location'],
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: ListTile(
        leading: const Icon(Icons.event_rounded, color: AppColors.brandGreen),
        title: Text(
          (e['title'] ?? 'Event') as String,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: sub.isEmpty ? null : Text(sub),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, size: 20),
          color: AppColors.textTertiary,
          onPressed: () => _fs.removeGroupEvent(
            widget.schoolId,
            widget.groupId,
            (e['id'] ?? '') as String,
          ),
        ),
      ),
    );
  }

  Future<void> _addEvent() async {
    final titleC = TextEditingController();
    final locC = TextEditingController();
    DateTime date = DateTime.now();
    TimeOfDay? time;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: const Text('Add group event'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleC,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: locC,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Location (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(DateFormat('MMM d').format(date)),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 1),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (d != null) setInner(() => date = d);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time, size: 18),
                        label: Text(time == null ? 'Time' : time!.format(context)),
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (t != null) setInner(() => time = t);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleC.text.trim().isEmpty) return;
                Navigator.of(context).pop(true);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      await _fs.addGroupEvent(
        schoolId: widget.schoolId,
        groupId: widget.groupId,
        title: titleC.text.trim(),
        date: date,
        time: time?.format(context) ?? 'All Day',
        location: locC.text.trim(),
      );
    }
    titleC.dispose();
    locC.dispose();
  }

  Widget _membersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Members',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _fs.streamGroupMembers(widget.schoolId, widget.groupId),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final docs = snap.data!.docs;
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.lgAll,
                boxShadow: kCardShadow,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < docs.length; i++)
                    _memberTile(
                      docs[i].id,
                      (docs[i].data()['displayName'] ?? 'Member') as String,
                      last: i == docs.length - 1,
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _memberTile(String uid, String name, {required bool last}) {
    return Container(
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: ListTile(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProfilePage(uid: uid, fallbackName: name),
          ),
        ),
        leading: CircleAvatar(
          backgroundColor: AppColors.brandTint,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
              color: AppColors.brandDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}
