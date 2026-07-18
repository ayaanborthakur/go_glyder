import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:go_glyder/core/theme.dart';
import 'package:go_glyder/services/firestore_service.dart';
import 'package:go_glyder/services/school_calendar_service.dart';

/// Admin-only: upload / manage the school-wide calendars. The admin exports
/// their Google Calendar as an .ics file and uploads it here; it's parsed on
/// device, recurring events expanded, and stored as a JSON blob in Cloud
/// Storage (only a tiny version pointer goes to Firestore).
class AdminCalendarPage extends StatefulWidget {
  final String schoolId;
  final String schoolName;
  const AdminCalendarPage({
    super.key,
    required this.schoolId,
    required this.schoolName,
  });

  @override
  State<AdminCalendarPage> createState() => _AdminCalendarPageState();
}

class _AdminCalendarPageState extends State<AdminCalendarPage> {
  final _cal = SchoolCalendarService.instance;
  bool _uploading = false;

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ics'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      _notify('Could not read that file.');
      return;
    }

    // Ask for a display name (defaults to the file name).
    final defaultName = file.name.replaceAll(RegExp(r'\.ics$'), '');
    final name = await _askName(defaultName);
    if (name == null) return;

    setState(() => _uploading = true);
    try {
      await _cal.uploadCalendar(
        schoolId: widget.schoolId,
        calendarName: name,
        icsContent: utf8.decode(bytes),
      );
      _notify('Calendar published to your school.');
    } on GroupException catch (e) {
      _notify(e.message);
    } catch (e) {
      _notify('Upload failed. Please try again.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<String?> _askName(String initial) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name this calendar'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'e.g. Oakwood 2026–27',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = c.text.trim();
              if (v.isNotEmpty) Navigator.of(context).pop(v);
            },
            child: const Text('Upload'),
          ),
        ],
      ),
    );
  }

  Future<void> _remove(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove calendar?'),
        content: Text('"$name" will no longer appear for your community.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _cal.removeCalendar(widget.schoolId, id);
    }
  }

  void _notify(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('School calendar')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _upload,
        icon: _uploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Icon(Icons.upload_file_rounded),
        label: Text(_uploading ? 'Uploading…' : 'Upload .ics'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.instance.schools
            .doc(widget.schoolId)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final calendars =
              ((snap.data!.data()?['calendars'] as List?) ?? const [])
                  .cast<Map<String, dynamic>>();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
            children: [
              _howTo(),
              const SizedBox(height: 20),
              const Text('Published calendars',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              if (calendars.isEmpty)
                _empty()
              else
                for (final c in calendars) _calendarTile(c),
            ],
          );
        },
      ),
    );
  }

  Widget _howTo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brandTint,
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline_rounded, color: AppColors.brandDark, size: 18),
              SizedBox(width: 8),
              Text('How to export',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: AppColors.brandDark)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'In Google Calendar → Settings → Import & export → Export. Unzip '
            'the download, then upload the .ics file here. Everyone at '
            '${widget.schoolName} sees it on their calendar automatically.',
            style: const TextStyle(
                color: AppColors.brandDark, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
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
          const Icon(Icons.event_note_rounded,
              size: 40, color: AppColors.brandGreen),
          const SizedBox(height: 10),
          const Text('No calendars uploaded yet',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Tap “Upload .ics” to publish your school calendar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _calendarTile(Map<String, dynamic> c) {
    final updated = (c['updatedAt'] as Timestamp?)?.toDate();
    final version = c['version'] as int?;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        boxShadow: kCardShadow,
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.brandTint,
          child: Icon(Icons.calendar_today_rounded, color: AppColors.brandDark),
        ),
        title: Text((c['name'] ?? 'Calendar') as String,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text([
          if (version != null) 'v$version',
          if (updated != null) 'updated ${DateFormat('MMM d').format(updated)}',
        ].join(' · ')),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded),
          color: AppColors.textTertiary,
          onPressed: () => _remove(
            (c['id'] ?? '') as String,
            (c['name'] ?? 'this calendar') as String,
          ),
        ),
      ),
    );
  }
}
