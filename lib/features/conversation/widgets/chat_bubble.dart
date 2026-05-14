import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/avatar_data.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/gemma/tutor_response.dart';
import '../../../services/illustration/illustration_registry.dart';
import 'mode_pill.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    required this.isUser,
    required this.text,
    this.mode,
    this.illustrationTopicId,
    this.imagePath,
    this.avatarId,
    super.key,
  });

  final bool isUser;
  final String text;
  final TutorMode? mode;
  final String? illustrationTopicId;
  final String? imagePath;
  final String? avatarId;

  @override
  Widget build(BuildContext context) {
    final assetPath = illustrationTopicId != null
        ? IllustrationRegistry.getAssetPath(illustrationTopicId!)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[_OwlAvatar(), const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (imagePath != null) ...[_ImageView(imagePath: imagePath!), const SizedBox(height: 6)],
                if (assetPath != null) ...[IllustrationView(assetPath: assetPath), const SizedBox(height: 6)],
                if (text.isNotEmpty) _Bubble(isUser: isUser, text: text),
                if (!isUser && mode != null) ...[const SizedBox(height: 4), ModeTag(mode: mode!)],
              ],
            ),
          ),
          if (isUser) ...[const SizedBox(width: 8), _ChildAvatar(avatarId: avatarId)],
        ],
      ),
    );
  }
}

class _ChildAvatar extends StatelessWidget {
  const _ChildAvatar({required this.avatarId});
  final String? avatarId;

  @override
  Widget build(BuildContext context) {
    final id = avatarId ?? 'default';
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AvatarData.colorFor(id),
        border: Border.all(color: AppColors.warmCreamDark, width: 1),
      ),
      alignment: Alignment.center,
      child: Text(AvatarData.emojiFor(id), style: const TextStyle(fontSize: 14)),
    );
  }
}

class _OwlAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColors.terracottaLight, AppColors.warmCreamDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.terracotta.withValues(alpha: 0.3), width: 1.2),
      ),
      alignment: Alignment.center,
      child: Text(
        'M',
        style: AppText.caption(color: AppColors.terracotta).copyWith(fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.isUser, required this.text});

  final bool isUser;
  final String text;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(isUser ? 20 : 4),
      bottomRight: Radius.circular(isUser ? 4 : 20),
    );

    if (isUser) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.terracotta, Color(0xFFB04422)],
          ),
          borderRadius: borderRadius,
          boxShadow: AppShadows.button(AppColors.terracotta),
        ),
        child: Text(text, style: AppText.body(color: Colors.white)),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius,
        boxShadow: AppShadows.card,
        border: Border.all(color: AppColors.warmCreamDark, width: 1),
      ),
      child: Text(text, style: AppText.body()),
    );
  }
}

class _ImageView extends StatelessWidget {
  const _ImageView({required this.imagePath});
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width * 0.65;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: Image.file(
        File(imagePath),
        width: w,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: w,
          height: w * 0.65,
          color: AppColors.warmCreamDark,
          alignment: Alignment.center,
          child: const Icon(Icons.image_not_supported_rounded, color: AppColors.charcoal, size: 32),
        ),
      ),
    );
  }
}

class IllustrationView extends StatefulWidget {
  const IllustrationView({required this.assetPath, super.key});
  final String assetPath;

  @override
  State<IllustrationView> createState() => _IllustrationViewState();
}

class _IllustrationViewState extends State<IllustrationView> {
  double _opacity = 0.0;
  String? _svgData;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await DefaultAssetBundle.of(context).loadString(widget.assetPath);
      if (mounted) setState(() { _svgData = data; _opacity = 1.0; });
    } catch (_) {}
  }

  void _openFullscreen() {
    final svg = _svgData;
    if (svg == null) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, _, _) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
                child: SvgPicture.string(svg, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: MediaQuery.of(ctx).padding.top + 8,
              right: 12,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
            Positioned(
              bottom: MediaQuery.of(ctx).padding.bottom + 16,
              left: 0,
              right: 0,
              child: const Text(
                'Pinch to zoom',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_svgData == null) return const SizedBox.shrink();
    final thumbWidth = MediaQuery.of(context).size.width * 0.65;
    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeIn,
      child: GestureDetector(
        onTap: _openFullscreen,
        child: Container(
          width: thumbWidth,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            boxShadow: AppShadows.card,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              SvgPicture.string(_svgData!, width: thumbWidth, fit: BoxFit.contain),
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.fullscreen, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
