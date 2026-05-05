import 'package:flutter/material.dart';

import '../../services/gemma/gemma_service.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  final _service = GemmaService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  String _status = 'Tap "Load Gemma 4" to begin.';
  int _downloadProgress = 0;
  bool _loading = false;
  bool _generating = false;
  String _output = '';

  @override
  void dispose() {
    _service.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadModel() async {
    setState(() {
      _loading = true;
      _status = 'Downloading model… (check Logcat for progress)';
      _downloadProgress = 0;
    });

    try {
      await _service.initialize(
        onProgress: (p) => setState(() {
          _downloadProgress = p;
          _status = 'Downloading: $p%';
        }),
      );
      setState(() => _status = 'Model ready ✓');
    } catch (e) {
      setState(() => _status = 'Load failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty || _generating || !_service.isReady) return;

    setState(() {
      _generating = true;
      _output = '';
    });

    try {
      await for (final token in _service.generate(prompt)) {
        setState(() => _output += token);
        _scrollToBottom();
      }
    } catch (e) {
      setState(() => _output = 'Generation error: $e');
    } finally {
      setState(() => _generating = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemma-San — Diagnostic'),
        backgroundColor: cs.inversePrimary,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatusBanner(status: _status),
              const SizedBox(height: 8),
              if (_loading) _ProgressBar(progress: _downloadProgress),
              if (!_service.isReady) ...[
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _loading ? null : _loadModel,
                  child: const Text('Load Gemma 4'),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: _OutputArea(
                  output: _output,
                  scrollController: _scrollController,
                ),
              ),
              const Divider(height: 24),
              _InputRow(
                controller: _controller,
                generating: _generating,
                enabled: _service.isReady,
                onSend: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});
  final int progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        LinearProgressIndicator(value: progress / 100),
      ],
    );
  }
}

class _OutputArea extends StatelessWidget {
  const _OutputArea({required this.output, required this.scrollController});
  final String output;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        controller: scrollController,
        child: SelectableText(
          output.isEmpty ? '(response will stream here)' : output,
          style: const TextStyle(fontSize: 14, height: 1.6),
        ),
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.controller,
    required this.generating,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool generating;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Type a prompt…',
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
            minLines: 1,
            enabled: enabled && !generating,
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: enabled && !generating ? onSend : null,
          child: generating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send'),
        ),
      ],
    );
  }
}
