import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:go_glyder/core/theme.dart';
import 'package:go_glyder/services/firestore_service.dart';

/// Where a would-be school admin proves it: pick your school and enter the
/// secret admin code your school received from GoGlyder. The code is verified
/// server-side by security rules, so it can't be faked.
class AdminClaimPage extends StatefulWidget {
  const AdminClaimPage({super.key});

  @override
  State<AdminClaimPage> createState() => _AdminClaimPageState();
}

class _AdminClaimPageState extends State<AdminClaimPage> {
  final _codeC = TextEditingController();
  String? _schoolId;
  bool _saving = false;

  @override
  void dispose() {
    _codeC.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_schoolId == null) {
      _err('Choose your school first.');
      return;
    }
    if (_codeC.text.trim().isEmpty) {
      _err('Enter your school admin code.');
      return;
    }
    setState(() => _saving = true);
    try {
      await FirestoreService.instance.claimSchoolAdmin(
        schoolId: _schoolId!,
        code: _codeC.text,
      );
      // On success the profile flips to admin and the router redirects in.
    } on GroupException catch (e) {
      _err(e.message);
    } catch (_) {
      _err('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _err(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: AppColors.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify admin')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.brandTint,
              borderRadius: AppRadius.mdAll,
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded,
                    color: AppColors.brandDark),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Admin access needs your school\'s code, issued by '
                    'GoGlyder. This keeps anyone from posing as an admin.',
                    style: TextStyle(
                        color: AppColors.brandDark, fontSize: 13.5, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text('Your school',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  fontSize: 13)),
          const SizedBox(height: 8),
          _schoolPicker(),
          const SizedBox(height: 20),
          const Text('Admin code',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _codeC,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: 'e.g. OAK-7K2P',
              prefixIcon: Icon(Icons.key_rounded),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _verify,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text('Verify & continue'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _schoolPicker() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.instance.streamSchools(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: LinearProgressIndicator(),
          );
        }
        final schools = snap.data!.docs;
        if (schools.isEmpty) {
          return Text('No schools are set up yet. Contact GoGlyder to onboard '
              'your school.',
              style: TextStyle(color: AppColors.textSecondary));
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.smAll,
            border: Border.all(color: AppColors.divider),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _schoolId,
              hint: const Text('Select your school'),
              items: schools
                  .map((d) => DropdownMenuItem(
                        value: d.id,
                        child: Text((d.data()['name'] ?? 'School') as String),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _schoolId = v),
            ),
          ),
        );
      },
    );
  }
}
