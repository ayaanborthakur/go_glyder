import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:go_glyder/core/theme.dart';
import 'package:go_glyder/core/widgets.dart';
import 'package:go_glyder/features/community/presentation/community_feed_page.dart';
import 'package:go_glyder/features/community/presentation/create_group_page.dart';
import 'package:go_glyder/features/community/presentation/group_detail_page.dart';
import 'package:go_glyder/services/firestore_service.dart';

/// School-scoped community: pick one of your schools, browse/search its
/// groups, and join or open them. Membership is open — no join codes.
class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  final FirestoreService _fs = FirestoreService.instance;
  final TextEditingController _searchC = TextEditingController();

  String? _selectedSchoolId;
  String _query = '';

  // The set of group ids the user has already joined (kept live so the
  // directory can show Join vs Open without an extra read per card).
  Set<String> _myGroupIds = {};
  Map<String, String> _mySchoolNames = {}; // id -> name
  StreamSubscription? _myGroupsSub;

  @override
  void initState() {
    super.initState();
    _myGroupsSub = _fs.streamMyGroups().listen((snap) {
      if (mounted) {
        setState(() => _myGroupIds = snap.docs.map((d) => d.id).toSet());
      }
    });
    _searchC.addListener(
      () => setState(() => _query = _searchC.text.trim().toLowerCase()),
    );
  }

  @override
  void dispose() {
    _myGroupsSub?.cancel();
    _searchC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Community')),
      body: StreamBuilder<List<String>>(
        stream: _fs.streamMySchoolIds(),
        builder: (context, schoolSnap) {
          if (!schoolSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final mySchoolIds = schoolSnap.data!;
          if (mySchoolIds.isEmpty) return _noSchoolView();

          // Default the selector to the first joined school.
          final selected = (_selectedSchoolId != null &&
                  mySchoolIds.contains(_selectedSchoolId))
              ? _selectedSchoolId!
              : mySchoolIds.first;

          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                _heroHeader(_mySchoolNames[selected]),
                _schoolChips(mySchoolIds, selected),
                const TabBar(
                  labelColor: AppColors.brandDark,
                  unselectedLabelColor: AppColors.textTertiary,
                  indicatorColor: AppColors.brandGreen,
                  labelStyle: TextStyle(fontWeight: FontWeight.w700),
                  tabs: [
                    Tab(text: 'Groups'),
                    Tab(text: 'Feed'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      Column(
                        children: [
                          _searchBar(),
                          Expanded(child: _directory(selected)),
                        ],
                      ),
                      CommunityFeed(schoolId: selected),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---- Hero header ----
  Widget _heroHeader(String? schoolName) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brandDark, AppColors.brandGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.xlAll,
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            schoolName ?? 'Your community',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Discover groups, carpools, and events happening around you.',
            style: TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.3),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.08, end: 0);
  }

  // ---- No school yet ----
  Widget _noSchoolView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.school_rounded, size: 64, color: AppColors.brandGreen),
            const SizedBox(height: 16),
            const Text(
              'Join your school',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Groups, carpools, and the calendar all live under your school. '
              'Join one to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 50,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _joinSchoolFlow,
                icon: const Icon(Icons.add),
                label: const Text('Join a school'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- School selector chips ----
  Widget _schoolChips(List<String> mySchoolIds, String selected) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _fs.streamSchools(),
      builder: (context, snap) {
        _mySchoolNames = {
          for (final d in snap.data?.docs ?? [])
            if (mySchoolIds.contains(d.id))
              d.id: (d.data()['name'] ?? 'School') as String,
        };
        return SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              for (final id in mySchoolIds)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_mySchoolNames[id] ?? 'School'),
                    selected: id == selected,
                    onSelected: (_) => setState(() => _selectedSchoolId = id),
                    selectedColor: AppColors.brandDark,
                    labelStyle: TextStyle(
                      color: id == selected
                          ? Colors.white
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: AppColors.surface,
                  ),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Join school'),
                onPressed: _joinSchoolFlow,
                backgroundColor: AppColors.surface,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        controller: _searchC,
        decoration: InputDecoration(
          hintText: 'Search groups…',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => _searchC.clear(),
                ),
        ),
      ),
    );
  }

  // ---- Group directory for the selected school ----
  Widget _directory(String schoolId) {
    final schoolName = _mySchoolNames[schoolId];
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _fs.streamGroupsInSchool(schoolId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snap.data!.docs;
        final groups = _query.isEmpty
            ? all
            : all
                  .where(
                    (d) => ((d.data()['name'] ?? '') as String)
                        .toLowerCase()
                        .contains(_query),
                  )
                  .toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  schoolName == null ? 'Groups' : 'Groups at $schoolName',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _createGroup(schoolId, schoolName),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (groups.isEmpty)
              _emptyDirectory(all.isEmpty)
            else
              for (var i = 0; i < groups.length; i++)
                _groupCard(schoolId, schoolName, groups[i], i),
          ],
        );
      },
    );
  }

  Widget _emptyDirectory(bool noneAtAll) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        boxShadow: kCardShadow,
      ),
      child: Column(
        children: [
          const Icon(Icons.groups_outlined,
              size: 40, color: AppColors.brandGreen),
          const SizedBox(height: 10),
          Text(
            noneAtAll
                ? 'No groups at this school yet'
                : 'No groups match your search',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            noneAtAll
                ? 'Be the first — create one for your team, class, or club.'
                : 'Try a different search, or create a new group.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _groupCard(
    String schoolId,
    String? schoolName,
    QueryDocumentSnapshot<Map<String, dynamic>> g,
    int index,
  ) {
    final data = g.data();
    final name = (data['name'] ?? 'Group') as String;
    final members = (data['members'] ?? 0) as int;
    final category = (data['category'] ?? '') as String;
    final joined = _myGroupIds.contains(g.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        boxShadow: kCardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openGroup(schoolId, g.id, name, schoolName),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover strip — gives each group a distinct visual identity by
              // category instead of a plain icon on a flat background.
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(gradient: groupCoverGradient(category)),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Icon(_iconFor(data['icon'] as String?),
                        color: Colors.white, size: 22),
                    const Spacer(),
                    if (joined)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Joined',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            category.isEmpty
                                ? '$members member${members == 1 ? '' : 's'}'
                                : '${_categoryLabel(category)} · $members member${members == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: _fs.streamGroupMembersPreview(
                              schoolId,
                              g.id,
                            ),
                            builder: (context, memberSnap) {
                              final previewNames = (memberSnap.data?.docs ?? [])
                                  .map((m) =>
                                      (m.data()['displayName'] ?? 'Member')
                                          as String)
                                  .toList();
                              if (previewNames.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return AvatarStack(
                                names: previewNames,
                                totalCount: members,
                                size: 24,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    joined
                        ? const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textTertiary)
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 38),
                            ),
                            onPressed: () =>
                                _joinGroup(schoolId, g.id, name, data),
                            child: const Text('Join'),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate(delay: (40 * index).ms).fadeIn(duration: 280.ms).slideY(
      begin: 0.06,
      end: 0,
      curve: Curves.easeOut,
    );
  }

  // ---- Actions ----
  Future<void> _joinSchoolFlow() async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _SchoolPickerSheet(),
    );
    if (chosen == null) return;
    try {
      await _fs.joinSchool(chosen);
      if (mounted) setState(() => _selectedSchoolId = chosen);
    } catch (_) {
      _notify('Could not join that school.');
    }
  }

  Future<void> _joinGroup(
    String schoolId,
    String groupId,
    String name,
    Map<String, dynamic> data,
  ) async {
    try {
      await _fs.joinGroup(
        schoolId: schoolId,
        groupId: groupId,
        groupName: name,
        icon: (data['icon'] ?? 'sun') as String,
      );
      _notify('Joined $name!');
    } on GroupException catch (e) {
      _notify(e.message);
    } catch (_) {
      _notify('Could not join the group.');
    }
  }

  Future<void> _createGroup(String schoolId, String? schoolName) async {
    final result = await Navigator.of(context).push<(String, String)>(
      MaterialPageRoute(
        builder: (_) =>
            CreateGroupPage(schoolId: schoolId, schoolName: schoolName),
      ),
    );
    if (result != null && mounted) {
      _openGroup(schoolId, result.$1, result.$2, schoolName);
    }
  }

  void _openGroup(
    String schoolId,
    String groupId,
    String name,
    String? schoolName,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupDetailPage(
          schoolId: schoolId,
          groupId: groupId,
          groupName: name,
          schoolName: schoolName,
        ),
      ),
    );
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  IconData _iconFor(String? key) {
    switch (key) {
      case 'sports':
        return Icons.sports_soccer;
      case 'schedule':
        return Icons.schedule;
      case 'music':
        return Icons.music_note;
      case 'event':
        return Icons.event;
      case 'group':
        return Icons.groups_rounded;
      default:
        return Icons.wb_sunny;
    }
  }

  String _categoryLabel(String key) {
    switch (key) {
      case 'morning':
        return 'Morning drop-off';
      case 'afterschool':
        return 'After-school';
      case 'sports':
        return 'Sports';
      case 'music':
        return 'Music & Arts';
      case 'events':
        return 'Events & trips';
      default:
        return 'General';
    }
  }
}

/// Bottom sheet listing every school so a user can join one (no code needed).
class _SchoolPickerSheet extends StatelessWidget {
  const _SchoolPickerSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Join a school',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirestoreService.instance.streamSchools(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final schools = snap.data!.docs;
              if (schools.isEmpty) {
                return Text(
                  'No schools are set up yet. Ask your school to onboard '
                  'with GoGlyder.',
                  style: TextStyle(color: AppColors.textSecondary),
                );
              }
              return Column(
                children: [
                  for (final s in schools)
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.brandTint,
                        child: Icon(Icons.school_rounded,
                            color: AppColors.brandDark),
                      ),
                      title: Text((s.data()['name'] ?? 'School') as String,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      onTap: () => Navigator.of(context).pop(s.id),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
