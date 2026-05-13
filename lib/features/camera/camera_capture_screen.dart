import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key, required this.initialFile});
  final XFile initialFile;

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  late XFile _file;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _file = widget.initialFile;
  }

  Future<void> _tryAgain() async {
    setState(() => _picking = true);
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
      if (picked != null && mounted) setState(() => _file = picked);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Preview'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop<XFile?>(null),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  child: Image.file(File(_file.path), fit: BoxFit.contain),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              MediaQuery.of(context).padding.bottom + AppSpacing.lg,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _GhostButton(
                    label: 'Try again',
                    onTap: _picking ? null : _tryAgain,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _FilledButton(
                    label: 'Use this picture',
                    onTap: () => Navigator.of(context).pop<XFile?>(_file),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: AppSpacing.minTap,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white54, width: 1.5),
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
        alignment: Alignment.center,
        child: Text(label, style: AppText.button(color: onTap == null ? Colors.white24 : Colors.white70)),
      ),
    );
  }
}

class _FilledButton extends StatelessWidget {
  const _FilledButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: AppSpacing.minTap,
        decoration: BoxDecoration(
          color: AppColors.terracotta,
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          boxShadow: AppShadows.button(AppColors.terracotta),
        ),
        alignment: Alignment.center,
        child: Text(label, style: AppText.button()),
      ),
    );
  }
}
