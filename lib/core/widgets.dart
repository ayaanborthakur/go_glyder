// lib/core/widgets.dart
//
// Small shared widgets used across features — kept separate from theme.dart
// (which is pure design tokens/ThemeData) since these are actual widgets.

import 'package:flutter/material.dart';

import 'theme.dart';

/// Deterministic on-brand avatar gradient so each person/group keeps a
/// stable color derived from their name.
LinearGradient avatarGradient(String name) {
  const palettes = [
    [Color(0xFF0A5C36), Color(0xFF2FBF71)],
    [Color(0xFF0E7490), Color(0xFF22D3EE)],
    [Color(0xFF4338CA), Color(0xFF818CF8)],
    [Color(0xFFB45309), Color(0xFFFBBF24)],
    [Color(0xFF9D174D), Color(0xFFF472B6)],
    [Color(0xFF115E59), Color(0xFF2DD4BF)],
  ];
  final colors = palettes[name.hashCode.abs() % palettes.length];
  return LinearGradient(
    colors: colors,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// A person's avatar: renders their photo when [photoUrl] is available,
/// otherwise falls back to a deterministic gradient with their initial.
class Avatar extends StatelessWidget {
  final String name;
  final double size;
  final String? photoUrl;

  const Avatar({super.key, required this.name, this.size = 52, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: hasPhoto ? null : avatarGradient(name),
        ),
        alignment: Alignment.center,
        child: hasPhoto
            ? Image.network(
                photoUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _initial(),
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : _initial(),
              )
            : _initial(),
      ),
    );
  }

  Widget _initial() {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: avatarGradient(name)),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// A tight, overlapping stack of avatars (e.g. "who's in this group") with
/// a trailing "+N" bubble when there are more members than fit.
class AvatarStack extends StatelessWidget {
  final List<String> names;
  final double size;
  final int max;

  const AvatarStack({
    super.key,
    required this.names,
    this.size = 28,
    this.max = 4,
  });

  @override
  Widget build(BuildContext context) {
    final shown = names.take(max).toList();
    final overflow = names.length - shown.length;
    final overlap = size * 0.62;

    return SizedBox(
      height: size,
      width: shown.isEmpty
          ? 0
          : overlap * (shown.length - 1) + size + (overflow > 0 ? overlap : 0),
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: overlap * i,
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    BorderSide(color: Colors.white, width: 2),
                  ),
                ),
                child: Avatar(name: shown[i], size: size),
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: overlap * shown.length,
              child: Container(
                width: size,
                height: size,
                decoration: const BoxDecoration(
                  color: AppColors.brandTint,
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    BorderSide(color: Colors.white, width: 2),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+$overflow',
                  style: const TextStyle(
                    color: AppColors.brandDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
