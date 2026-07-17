import 'package:flutter/material.dart';

import 'package:go_glyder/core/theme.dart';
import 'package:go_glyder/services/firestore_service.dart';

/// One category option — a label plus the keys stored on the group.
class _Category {
  final String label;
  final String key;
  final String icon;
  final IconData glyph;
  const _Category(this.label, this.key, this.icon, this.glyph);
}

const List<_Category> _categories = [
  _Category('Morning drop-off', 'morning', 'sun', Icons.wb_sunny_rounded),
  _Category('After-school pickup', 'afterschool', 'schedule', Icons.schedule_rounded),
  _Category('Sports', 'sports', 'sports', Icons.sports_soccer_rounded),
  _Category('Music & Arts', 'music', 'music', Icons.music_note_rounded),
  _Category('Events & trips', 'events', 'event', Icons.event_rounded),
  _Category('General', 'general', 'group', Icons.groups_rounded),
];

/// Full-screen form for creating a carpool group. Returns `(groupId, name)` on
/// success, or `null` if the user backs out.
class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _schoolC = TextEditingController();
  final _areaC = TextEditingController();
  final _descC = TextEditingController();

  _Category _category = _categories.first;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameC.dispose();
    _schoolC.dispose();
    _areaC.dispose();
    _descC.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final name = _nameC.text.trim();
      final id = await FirestoreService.instance.createGroup(
        name: name,
        schoolName: _schoolC.text.trim(),
        description: _descC.text.trim(),
        category: _category.key,
        icon: _category.icon,
        pickupArea: _areaC.text.trim(),
      );
      if (mounted) Navigator.of(context).pop((id, name));
    } on GroupException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Could not create the group. Please try again.');
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
      appBar: AppBar(title: const Text('Create Group')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _label('Group name'),
            TextFormField(
              controller: _nameC,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. Oakwood Morning Riders',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a group name' : null,
            ),
            const SizedBox(height: 18),
            _label('School'),
            TextFormField(
              controller: _schoolC,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Which school is this group for?',
                prefixIcon: Icon(Icons.school_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter the school name' : null,
            ),
            const SizedBox(height: 18),
            _label('Type of carpool'),
            _buildCategoryPicker(),
            const SizedBox(height: 18),
            _label('Pickup area  (optional)'),
            TextFormField(
              controller: _areaC,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Neighborhood or general area',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 18),
            _label('Description  (optional)'),
            TextFormField(
              controller: _descC,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Schedule, rules, anything members should know…',
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
                    : const Text('Create group'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'ll get a join code and QR to share with other parents.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
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

  Widget _buildCategoryPicker() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _categories.map((c) {
        final selected = c.key == _category.key;
        return GestureDetector(
          onTap: () => setState(() => _category = c),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.brandDark : Colors.white,
              borderRadius: AppRadius.smAll,
              border: Border.all(
                color: selected ? AppColors.brandDark : AppColors.divider,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  c.glyph,
                  size: 18,
                  color: selected ? Colors.white : AppColors.brandGreen,
                ),
                const SizedBox(width: 8),
                Text(
                  c.label,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
