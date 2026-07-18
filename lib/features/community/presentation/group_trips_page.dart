import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:go_glyder/core/theme.dart';
import 'package:go_glyder/features/community/presentation/post_ride_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_glyder/services/firestore_service.dart';

/// Carpool trips for a single group: the feed of posted rides, plus the
/// request/accept matching flow.
class GroupTripsPage extends StatelessWidget {
  final String schoolId;
  final String groupId;
  final String groupName;
  final String? schoolName;

  const GroupTripsPage({
    super.key,
    required this.schoolId,
    required this.groupId,
    required this.groupName,
    this.schoolName,
  });

  FirestoreService get _fs => FirestoreService.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rides')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PostRidePage(
              schoolId: schoolId,
              groupId: groupId,
              schoolName: schoolName,
            ),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Post a ride'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _fs.streamGroupTrips(schoolId, groupId),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Could not load rides'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final trips = snap.data!.docs;
          if (trips.isEmpty) return _empty();
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: trips.length,
            itemBuilder: (context, i) => _TripCard(
              schoolId: schoolId,
              groupId: groupId,
              tripId: trips[i].id,
              data: trips[i].data(),
            ),
          );
        },
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_car_outlined,
                size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            const Text('No rides posted yet',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Be the first to offer a carpool for your group.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final String schoolId;
  final String groupId;
  final String tripId;
  final Map<String, dynamic> data;

  const _TripCard({
    required this.schoolId,
    required this.groupId,
    required this.tripId,
    required this.data,
  });

  FirestoreService get _fs => FirestoreService.instance;

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid;
    final driverId = data['driverId'] as String?;
    final isDriver = me != null && me == driverId;
    final riders = (data['riders'] as List?)?.cast<String>() ?? const [];
    final isRider = me != null && riders.contains(me);
    final total = (data['seatsTotal'] ?? 0) as int;
    final taken = (data['seatsTaken'] ?? 0) as int;
    final status = (data['status'] ?? 'open') as String;
    final ts = data['date'] as Timestamp?;
    final dateStr = ts != null ? DateFormat('EEE, MMM d').format(ts.toDate()) : '';
    final notes = (data['notes'] ?? '') as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.brandTint,
                child: Text(
                  (data['driverName'] as String?)?.isNotEmpty == true
                      ? (data['driverName'] as String)[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppColors.brandDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${data['driverName'] ?? 'Driver'}${isDriver ? ' (you)' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('$dateStr · ${data['time'] ?? ''}',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              _statusBadge(status, taken, total),
            ],
          ),
          const SizedBox(height: 14),
          _leg(Icons.trip_origin_rounded, data['origin'] as String? ?? ''),
          Padding(
            padding: const EdgeInsets.only(left: 9),
            child: Container(width: 2, height: 14, color: AppColors.divider),
          ),
          _leg(Icons.place_rounded, data['destination'] as String? ?? ''),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(notes, style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.event_seat_rounded, size: 18, color: AppColors.brandGreen),
              const SizedBox(width: 6),
              Text('$taken of $total seats taken',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
              const Spacer(),
              _action(context, isDriver: isDriver, isRider: isRider, status: status),
            ],
          ),
        ],
      ),
    );
  }

  Widget _leg(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 20, color: AppColors.brandGreen),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600))),
    ],
  );

  Widget _statusBadge(String status, int taken, int total) {
    late Color color;
    late String label;
    switch (status) {
      case 'cancelled':
        color = AppColors.textTertiary;
        label = 'Cancelled';
        break;
      case 'full':
        color = AppColors.accentOrange;
        label = 'Full';
        break;
      default:
        color = AppColors.success;
        label = 'Open';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  Widget _action(BuildContext context,
      {required bool isDriver, required bool isRider, required String status}) {
    if (status == 'cancelled') return const SizedBox.shrink();
    if (isDriver) {
      return TextButton(
        onPressed: () => _openRequests(context),
        child: const Text('Manage requests'),
      );
    }
    if (isRider) {
      return const _Chip(text: "You're in", color: AppColors.success);
    }
    // Non-driver, not yet a rider: reflect their request status.
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _fs.streamMyTripRequest(schoolId, groupId, tripId),
      builder: (context, snap) {
        final reqStatus = snap.data?.data()?['status'] as String?;
        if (reqStatus == 'pending') {
          return const _Chip(text: 'Requested', color: AppColors.textTertiary);
        }
        if (reqStatus == 'declined') {
          return const _Chip(text: 'Declined', color: AppColors.danger);
        }
        if (status == 'full') {
          return const _Chip(text: 'Full', color: AppColors.accentOrange);
        }
        return ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () async {
            try {
              await _fs.requestSeat(schoolId, groupId, tripId);
            } catch (_) {}
          },
          child: const Text('Request seat'),
        );
      },
    );
  }

  void _openRequests(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          _RequestsSheet(schoolId: schoolId, groupId: groupId, tripId: tripId),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.smAll,
      ),
      child: Text(text,
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }
}

/// Bottom sheet where the driver accepts/declines pending seat requests.
class _RequestsSheet extends StatelessWidget {
  final String schoolId;
  final String groupId;
  final String tripId;
  const _RequestsSheet({
    required this.schoolId,
    required this.groupId,
    required this.tripId,
  });

  FirestoreService get _fs => FirestoreService.instance;

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
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Seat requests',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _fs.streamTripRequests(schoolId, groupId, tripId),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final reqs = snap.data!.docs;
              final pending =
                  reqs.where((r) => r.data()['status'] == 'pending').toList();
              if (pending.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No pending requests right now.',
                      style: TextStyle(color: AppColors.textSecondary)),
                );
              }
              return Column(
                children: pending.map((r) {
                  final d = r.data();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.brandTint,
                          child: Text(
                            (d['riderName'] as String?)?.isNotEmpty == true
                                ? (d['riderName'] as String)[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: AppColors.brandDark,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(d['riderName'] ?? 'Rider',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppColors.danger),
                          onPressed: () => _fs.respondToRequest(
                            schoolId: schoolId,
                            groupId: groupId,
                            tripId: tripId,
                            riderId: r.id,
                            accept: false,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.check_circle_rounded,
                              color: AppColors.success),
                          onPressed: () => _fs.respondToRequest(
                            schoolId: schoolId,
                            groupId: groupId,
                            tripId: tripId,
                            riderId: r.id,
                            accept: true,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
