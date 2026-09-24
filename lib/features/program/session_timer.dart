import 'dart:async';

import 'package:flutter/material.dart';

/// Presentation timing only; never feeds workout or progression policies.
Duration sessionElapsed(DateTime start, DateTime? end, DateTime now) {
  final elapsed = (end ?? now).difference(start);
  return elapsed.isNegative ? Duration.zero : elapsed;
}

String timerText(Duration duration) {
  final seconds = duration.inSeconds;
  final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
  return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
}

class RestCountdown extends ChangeNotifier {
  DateTime? _deadline;
  bool get started => _deadline != null;

  Duration remaining(DateTime now) {
    final deadline = _deadline;
    if (deadline == null || !deadline.isAfter(now)) return Duration.zero;
    // Round up so zero means the full rest has elapsed.
    return Duration(
      seconds: (deadline.difference(now).inMicroseconds / 1000000).ceil(),
    );
  }

  void start(int seconds, DateTime now) {
    if (seconds <= 0) throw ArgumentError.value(seconds, 'seconds');
    _deadline = now.add(Duration(seconds: seconds));
    notifyListeners();
  }

  void clear() {
    _deadline = null;
    notifyListeners();
  }
}

class SessionTimerPanel extends StatefulWidget {
  const SessionTimerPanel({
    super.key,
    required this.start,
    required this.end,
    required this.rest,
    this.now = DateTime.now,
  });
  final DateTime start;
  final DateTime? end;
  final RestCountdown rest;
  final DateTime Function() now;

  @override
  State<SessionTimerPanel> createState() => _SessionTimerPanelState();
}

class _SessionTimerPanelState extends State<SessionTimerPanel>
    with WidgetsBindingObserver {
  Timer? _ticker;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncTicker();
  }

  void _syncTicker() {
    _ticker?.cancel();
    if (widget.end == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didUpdateWidget(SessionTimerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.end != widget.end) _syncTicker();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      _syncTicker();
    } else {
      _ticker?.cancel();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.rest,
    builder: (context, _) {
      final now = widget.now();
      final remaining = widget.rest.remaining(now);
      return Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Wrap(
              spacing: 24,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${widget.end == null ? 'Workout time' : 'Total time'}  ${timerText(sessionElapsed(widget.start, widget.end, now))}',
                  key: const Key('session_elapsed'),
                ),
                if (widget.end == null && widget.rest.started) ...[
                  Text(
                    remaining == Duration.zero
                        ? 'Rest complete'
                        : 'Rest  ${timerText(remaining)}',
                    key: const Key('rest_remaining'),
                  ),
                  TextButton(
                    onPressed: widget.rest.clear,
                    child: const Text('Clear rest'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
