import 'package:flutter/material.dart';

import 'theme/app_theme.dart';

typedef AvatarEntry = ({String id, String emoji, Color color});

class AvatarData {
  AvatarData._();

  static const all = <AvatarEntry>[
    (id: 'lion',      emoji: '🦁', color: Color(0xFFF4CBB8)),
    (id: 'elephant',  emoji: '🐘', color: Color(0xFFB8D8CC)),
    (id: 'butterfly', emoji: '🦋', color: Color(0xFFFFF3CC)),
    (id: 'monkey',    emoji: '🐒', color: AppColors.warmCreamDark),
    (id: 'parrot',    emoji: '🦜', color: Color(0xFFD4EAD4)),
    (id: 'fish',      emoji: '🐠', color: Color(0xFFCCE5FF)),
    (id: 'owl',       emoji: '🦉', color: Color(0xFFFAEEC2)),
    (id: 'fox',       emoji: '🦊', color: Color(0xFFFFD4B2)),
    (id: 'bear',      emoji: '🐻', color: Color(0xFFE8D5C0)),
    (id: 'frog',      emoji: '🐸', color: Color(0xFFCCE5D0)),
  ];

  static const _fallback = (id: 'default', emoji: '👤', color: AppColors.warmCreamDark);

  static String emojiFor(String id) =>
      all.firstWhere((a) => a.id == id, orElse: () => _fallback).emoji;

  static Color colorFor(String id) =>
      all.firstWhere((a) => a.id == id, orElse: () => _fallback).color;
}
