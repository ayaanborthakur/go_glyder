import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:go_glyder/core/theme.dart';
import 'package:go_glyder/core/widgets.dart';
import 'package:go_glyder/features/account/presentation/profile_page.dart';
import 'package:go_glyder/features/community/presentation/group_trips_page.dart';
import 'package:go_glyder/features/community/presentation/post_ride_page.dart';
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

class _GroupDetailPageState extends State<GroupDetailPage>
    with SingleTickerProviderStateMixin {
  FirestoreService get _fs => FirestoreService.instance;

  late final TabController _tabController;
  final TextEditingController _streamC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _streamC.dispose();
    super.dispose();
  }

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
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _fs
          .schools
          .doc(widget.schoolId)
          .collection('groups')
          .doc(widget.groupId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(title: Text(widget.groupName)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final data = snap.data?.data() ?? const {};
        final category = (data['category'] ?? '') as String;
        final description = (data['description'] ?? '') as String;
        final pickupArea = (data['pickupArea'] ?? '') as String;
        final members = (data['members'] ?? 0) as int;
        final createdBy = (data['createdBy'] ?? '') as String;
        final admins = (data['admins'] as List?)?.cast<String>() ?? const [];
        final myUid = _fs.currentUid;
        final isAdmin =
            myUid != null && (myUid == createdBy || admins.contains(myUid));
        final events = ((data['events'] as List?) ?? const [])
            .cast<Map<String, dynamic>>();
        final streamPosts = ((data['stream'] as List?) ?? const [])
            .cast<Map<String, dynamic>>();

        return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: Text(widget.groupName),
              flexibleSpace: Container(
                decoration: BoxDecoration(gradient: groupCoverGradient(category)),
              ),
              actions: [
                if (isAdmin)
                  IconButton(
                    tooltip: 'Edit group',
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: () => _editGroup(data),
                  ),
                IconButton(
                  tooltip: 'Leave group',
                  icon: const Icon(Icons.logout_rounded),
                  onPressed: _leave,
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Rides'),
                  Tab(text: 'Events'),
                  Tab(text: 'Members'),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                _overviewTab(
                  pickupArea: pickupArea,
                  members: members,
                  description: description,
                  streamPosts: streamPosts,
                  events: events,
                  isAdmin: isAdmin,
                ),
                _ridesTab(),
                _eventsTab(events),
                _membersTab(
                  createdBy: createdBy,
                  admins: admins,
                  isAdmin: isAdmin,
                ),
              ],
            ),
        );
      },
    );
  }

  // ---- Overview tab ----
  // A live dashboard: a Classroom-style stream (post + recent messages),
  // an upcoming-rides preview, an upcoming-events preview, then the about
  // card / description.
  Widget _overviewTab({
    required String pickupArea,
    required int members,
    required String description,
    required List<Map<String, dynamic>> streamPosts,
    required List<Map<String, dynamic>> events,
    required bool isAdmin,
  }) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _streamSection(streamPosts, isAdmin),
        const SizedBox(height: 22),
        _ridesPreview(),
        const SizedBox(height: 22),
        _eventsPreview(events),
        const SizedBox(height: 22),
        _aboutCard(pickupArea, members),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'About this group',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  // Small section header with an optional trailing "See all" action.
  Widget _sectionHeader(String title, {String? actionLabel, VoidCallback? onAction}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel),
          ),
      ],
    );
  }

  // ---- Stream (Classroom-style posts) ----
  Widget _streamSection(List<Map<String, dynamic>> posts, bool isAdmin) {
    final sorted = [...posts]..sort((a, b) {
      final ta = (a['at'] as Timestamp?)?.toDate() ?? DateTime(1970);
      final tb = (b['at'] as Timestamp?)?.toDate() ?? DateTime(1970);
      return tb.compareTo(ta);
    });
    final recent = sorted.take(6).toList();
    final myUid = _fs.currentUid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Stream'),
        const SizedBox(height: 8),
        _streamComposer(),
        const SizedBox(height: 12),
        if (recent.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.lgAll,
              boxShadow: kCardShadow,
            ),
            child: Text(
              'Nothing here yet. Share an update, ask a question, or drop a '
              'reminder — everyone in the group sees it.',
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
                for (var i = 0; i < recent.length; i++)
                  _postTile(
                    recent[i],
                    canDelete: isAdmin || recent[i]['uid'] == myUid,
                    last: i == recent.length - 1,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _streamComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        boxShadow: kCardShadow,
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_note_rounded, color: AppColors.brandGreen),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _streamC,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Share something with the group…',
                border: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: (_) => _submitPost(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: AppColors.brandGreen),
            onPressed: _submitPost,
          ),
        ],
      ),
    );
  }

  Future<void> _submitPost() async {
    final text = _streamC.text.trim();
    if (text.isEmpty) return;
    _streamC.clear();
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _fs.postToGroupStream(
        schoolId: widget.schoolId,
        groupId: widget.groupId,
        text: text,
      );
    } catch (e) {
      if (mounted) {
        _streamC.text = text;
        messenger.showSnackBar(
          SnackBar(content: Text('Couldn\'t post: $e')),
        );
      }
    }
  }

  Widget _postTile(
    Map<String, dynamic> p, {
    required bool canDelete,
    required bool last,
  }) {
    final name = (p['name'] ?? 'Member') as String;
    final text = (p['text'] ?? '') as String;
    final at = (p['at'] as Timestamp?)?.toDate();
    final photoUrl = p['photoUrl'] as String?;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(name: name, size: 36, photoUrl: photoUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (at != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        _relativeTime(at),
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: const TextStyle(fontSize: 14, height: 1.35),
                ),
              ],
            ),
          ),
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              color: AppColors.textTertiary,
              onPressed: () => _fs.removeGroupStreamPost(
                schoolId: widget.schoolId,
                groupId: widget.groupId,
                postId: (p['id'] ?? '') as String,
              ),
            ),
        ],
      ),
    );
  }

  // ---- Rides preview ----
  Widget _ridesPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Upcoming rides',
          actionLabel: 'Open',
          onAction: _openRides,
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _fs.streamGroupTrips(widget.schoolId, widget.groupId),
          builder: (context, snap) {
            if (!snap.hasData) {
              return _previewCard(
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              );
            }
            final open = snap.data!.docs
                .map((d) => d.data())
                .where((t) => (t['status'] ?? 'open') == 'open')
                .toList()
              ..sort((a, b) {
                final da = (a['date'] as Timestamp?)?.toDate() ?? DateTime(2100);
                final db = (b['date'] as Timestamp?)?.toDate() ?? DateTime(2100);
                return da.compareTo(db);
              });
            if (open.isEmpty) {
              return _previewCard(
                child: Text(
                  'No rides posted yet. Offer a ride you\'re driving from '
                  'the Rides tab.',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13.5),
                ),
              );
            }
            final show = open.take(2).toList();
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.lgAll,
                boxShadow: kCardShadow,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < show.length; i++)
                    _rideTile(show[i], last: i == show.length - 1),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _rideTile(Map<String, dynamic> t, {required bool last}) {
    final origin = (t['origin'] ?? '') as String;
    final dest = (t['destination'] ?? '') as String;
    final date = (t['date'] as Timestamp?)?.toDate();
    final time = (t['time'] ?? '') as String;
    final seatsTotal = (t['seatsTotal'] ?? 0) as int;
    final seatsTaken = (t['seatsTaken'] ?? 0) as int;
    final seatsLeft = (seatsTotal - seatsTaken).clamp(0, seatsTotal);
    final driver = (t['driverName'] ?? 'Driver') as String;
    final sub = [
      if (date != null) DateFormat('EEE, MMM d').format(date),
      if (time.isNotEmpty) time,
      driver,
    ].join(' · ');

    return InkWell(
      onTap: _openRides,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            const Icon(Icons.directions_car_filled_rounded,
                color: AppColors.brandGreen),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    origin.isEmpty && dest.isEmpty ? 'Ride' : '$origin → $dest',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (sub.isNotEmpty)
                    Text(sub,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.brandTint,
                borderRadius: AppRadius.smAll,
              ),
              child: Text(
                seatsLeft == 0
                    ? 'Full'
                    : '$seatsLeft seat${seatsLeft == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: AppColors.brandDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Events preview ----
  Widget _eventsPreview(List<Map<String, dynamic>> events) {
    final upcoming = [...events]
      ..sort((a, b) {
        final da = (a['date'] as Timestamp?)?.toDate() ?? DateTime(2100);
        final db = (b['date'] as Timestamp?)?.toDate() ?? DateTime(2100);
        return da.compareTo(db);
      });
    final show = upcoming.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Upcoming events',
          actionLabel: 'See all',
          onAction: () => _tabController.animateTo(2),
        ),
        const SizedBox(height: 8),
        if (show.isEmpty)
          _previewCard(
            child: Text(
              'No events yet. Add practices, games, or trips from the '
              'Events tab.',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
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
                for (var i = 0; i < show.length; i++)
                  _eventPreviewTile(show[i], last: i == show.length - 1),
              ],
            ),
          ),
      ],
    );
  }

  Widget _eventPreviewTile(Map<String, dynamic> e, {required bool last}) {
    final date = (e['date'] as Timestamp?)?.toDate();
    final rsvps = ((e['rsvps'] as List?) ?? const []).length;
    final sub = [
      if (date != null) DateFormat('EEE, MMM d').format(date),
      if ((e['time'] ?? '').toString().isNotEmpty) e['time'],
      if ((e['location'] ?? '').toString().isNotEmpty) e['location'],
    ].join(' · ');

    return InkWell(
      onTap: () => _tabController.animateTo(2),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_rounded, color: AppColors.brandGreen),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (e['title'] ?? 'Event') as String,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (sub.isNotEmpty)
                    Text(sub,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            if (rsvps > 0)
              Text('$rsvps going',
                  style: const TextStyle(
                      color: AppColors.textTertiary, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }

  Widget _previewCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        boxShadow: kCardShadow,
      ),
      child: child,
    );
  }

  // Overview's "Open" / ride tiles just switch to the Rides tab, which now
  // shows the feed directly.
  void _openRides() => _tabController.animateTo(1);

  // "3m", "2h", "4d", or a date for anything older than a week.
  String _relativeTime(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return DateFormat('MMM d').format(t);
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

  // ---- Rides tab ----
  // The rides feed shows directly in the tab — no intermediate "open" page.
  // The "Post a ride" button rides along as a floating action inside the tab.
  Widget _ridesTab() {
    return Stack(
      children: [
        GroupTripsView(schoolId: widget.schoolId, groupId: widget.groupId),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PostRidePage(
                  schoolId: widget.schoolId,
                  groupId: widget.groupId,
                  schoolName: widget.schoolName,
                ),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Post a ride'),
          ),
        ),
      ],
    );
  }

  // ---- Events tab ----
  Widget _eventsTab(List<Map<String, dynamic>> events) {
    events.sort((a, b) {
      final da = (a['date'] as Timestamp?)?.toDate() ?? DateTime(2100);
      final dbb = (b['date'] as Timestamp?)?.toDate() ?? DateTime(2100);
      return da.compareTo(dbb);
    });

    return ListView(
      padding: const EdgeInsets.all(20),
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
    final eventId = (e['id'] ?? '') as String;
    final rsvps = ((e['rsvps'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    final myUid = _fs.currentUid;
    final going = myUid != null && rsvps.any((r) => r['uid'] == myUid);
    final rsvpNames =
        rsvps.map((r) => (r['name'] ?? 'Member') as String).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_rounded, color: AppColors.brandGreen),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (e['title'] ?? 'Event') as String,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (sub.isNotEmpty)
                      Text(sub,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: AppColors.textTertiary,
                onPressed: () =>
                    _fs.removeGroupEvent(widget.schoolId, widget.groupId, eventId),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _RsvpButton(
                going: going,
                onTap: () => _fs.toggleEventRsvp(
                  schoolId: widget.schoolId,
                  groupId: widget.groupId,
                  eventId: eventId,
                ),
              ),
              const SizedBox(width: 12),
              if (rsvpNames.isNotEmpty) ...[
                AvatarStack(names: rsvpNames, size: 26),
                const SizedBox(width: 8),
                Text(
                  rsvpNames.length == 1
                      ? '1 going'
                      : '${rsvpNames.length} going',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12.5),
                ),
              ] else
                const Text(
                  'Be the first to RSVP',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 12.5),
                ),
            ],
          ),
        ],
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

  // ---- Members tab ----
  Widget _membersTab({
    required String createdBy,
    required List<String> admins,
    required bool isAdmin,
  }) {
    return ListView(
      padding: const EdgeInsets.all(20),
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
                      docs[i].data()['photoUrl'] as String?,
                      isOwner: docs[i].id == createdBy,
                      isMemberAdmin: docs[i].id == createdBy ||
                          admins.contains(docs[i].id),
                      viewerIsAdmin: isAdmin,
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

  Widget _memberTile(
    String uid,
    String name,
    String? photoUrl, {
    required bool isOwner,
    required bool isMemberAdmin,
    required bool viewerIsAdmin,
    required bool last,
  }) {
    final roleLabel = isOwner ? 'Owner' : (isMemberAdmin ? 'Admin' : null);
    // Admins can manage everyone except the owner and themselves.
    final canManage =
        viewerIsAdmin && !isOwner && uid != _fs.currentUid;

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
        leading: Avatar(name: name, size: 44, photoUrl: photoUrl),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: roleLabel == null
            ? null
            : Text(
                roleLabel,
                style: const TextStyle(
                  color: AppColors.brandGreen,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
        trailing: canManage
            ? TextButton(
                onPressed: () => _fs.setGroupAdmin(
                  schoolId: widget.schoolId,
                  groupId: widget.groupId,
                  memberUid: uid,
                  isAdmin: !isMemberAdmin,
                ),
                child: Text(isMemberAdmin ? 'Remove admin' : 'Make admin'),
              )
            : const Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary),
      ),
    );
  }

  // ---- Edit group (admin) ----
  Future<void> _editGroup(Map<String, dynamic> data) async {
    final nameC = TextEditingController(text: (data['name'] ?? '') as String);
    final areaC =
        TextEditingController(text: (data['pickupArea'] ?? '') as String);
    final descC =
        TextEditingController(text: (data['description'] ?? '') as String);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit group'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameC,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: areaC,
                textCapitalization: TextCapitalization.words,
                decoration:
                    const InputDecoration(labelText: 'Pickup area (optional)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descC,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: 'Description (optional)'),
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
              if (nameC.text.trim().isEmpty) return;
              Navigator.of(context).pop(true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true) {
      await _fs.updateGroup(
        schoolId: widget.schoolId,
        groupId: widget.groupId,
        name: nameC.text.trim(),
        pickupArea: areaC.text.trim(),
        description: descC.text.trim(),
      );
    }
    nameC.dispose();
    areaC.dispose();
    descC.dispose();
  }
}

/// A pill toggle for an event RSVP — filled when the user is going.
class _RsvpButton extends StatelessWidget {
  final bool going;
  final VoidCallback onTap;
  const _RsvpButton({required this.going, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: going ? AppColors.brandGreen : AppColors.brandTint,
      borderRadius: AppRadius.smAll,
      child: InkWell(
        borderRadius: AppRadius.smAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                going ? Icons.check_circle_rounded : Icons.add_rounded,
                size: 17,
                color: going ? Colors.white : AppColors.brandDark,
              ),
              const SizedBox(width: 6),
              Text(
                going ? 'Going' : "I'm going",
                style: TextStyle(
                  color: going ? Colors.white : AppColors.brandDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
