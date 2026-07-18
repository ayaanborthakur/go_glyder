import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:go_glyder/core/theme.dart';
import 'package:go_glyder/services/firestore_service.dart';

/// Form for a driver to post a carpool trip in a group. Returns `true` on
/// success. Destination is pre-filled with the group's school when known.
class PostRidePage extends StatefulWidget {
  final String schoolId;
  final String groupId;
  final String? schoolName;

  const PostRidePage({
    super.key,
    required this.schoolId,
    required this.groupId,
    this.schoolName,
  });

  @override
  State<PostRidePage> createState() => _PostRidePageState();
}

class _PostRidePageState extends State<PostRidePage> {
  final _formKey = GlobalKey<FormState>();
  final _originC = TextEditingController();
  final _destC = TextEditingController();
  final _milesC = TextEditingController();
  final _notesC = TextEditingController();

  DateTime? _date;
  TimeOfDay? _time;
  int _seats = 3;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.schoolName != null && widget.schoolName!.isNotEmpty) {
      _destC.text = widget.schoolName!;
    }
  }

  @override
  void dispose() {
    _originC.dispose();
    _destC.dispose();
    _milesC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_date == null || _time == null) {
      _showError('Please pick a date and time.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      await FirestoreService.instance.createTrip(
        schoolId: widget.schoolId,
        groupId: widget.groupId,
        origin: _originC.text.trim(),
        destination: _destC.text.trim(),
        date: _date!,
        time: _time!.format(context),
        seats: _seats,
        distanceMiles: double.tryParse(_milesC.text.trim()) ?? 0,
        notes: _notesC.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on GroupException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Could not post the ride. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post a Ride')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _label('Pickup location'),
            TextFormField(
              controller: _originC,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Where you start from',
                prefixIcon: Icon(Icons.trip_origin_rounded),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a pickup point' : null,
            ),
            const SizedBox(height: 18),
            _label('Drop-off'),
            TextFormField(
              controller: _destC,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'School or destination',
                prefixIcon: Icon(Icons.place_rounded),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a destination' : null,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _picker(
                  label: 'Date',
                  icon: Icons.calendar_today_rounded,
                  value: _date == null
                      ? 'Select'
                      : DateFormat('EEE, MMM d').format(_date!),
                  onTap: _pickDate,
                )),
                const SizedBox(width: 12),
                Expanded(child: _picker(
                  label: 'Time',
                  icon: Icons.access_time_rounded,
                  value: _time == null ? 'Select' : _time!.format(context),
                  onTap: _pickTime,
                )),
              ],
            ),
            const SizedBox(height: 18),
            _label('Seats available'),
            _seatStepper(),
            const SizedBox(height: 18),
            _label('Approx. one-way distance  (miles)'),
            TextFormField(
              controller: _milesC,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: 'e.g. 4',
                prefixIcon: Icon(Icons.eco_rounded),
                helperText: 'Each rider you carpool banks this many carbon miles.',
              ),
            ),
            const SizedBox(height: 18),
            _label('Notes  (optional)'),
            TextFormField(
              controller: _notesC,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Recurring days, car details, etc.',
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text('Post ride'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        fontSize: 13,
      ),
    ),
  );

  Widget _picker({
    required String label,
    required IconData icon,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.smAll,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.smAll,
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.brandGreen),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w600,
                  )),
                  Text(value, style: const TextStyle(
                    fontSize: 14.5,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seatStepper() {
    Widget btn(IconData icon, VoidCallback? onTap) => Material(
      color: AppColors.brandTint,
      borderRadius: AppRadius.smAll,
      child: InkWell(
        borderRadius: AppRadius.smAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: AppColors.brandDark, size: 22),
        ),
      ),
    );

    return Row(
      children: [
        btn(Icons.remove_rounded, _seats > 1 ? () => setState(() => _seats--) : null),
        Expanded(
          child: Text(
            '$_seats seat${_seats == 1 ? '' : 's'}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        btn(Icons.add_rounded, _seats < 7 ? () => setState(() => _seats++) : null),
      ],
    );
  }
}
