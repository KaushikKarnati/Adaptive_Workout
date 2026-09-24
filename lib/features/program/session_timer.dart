import 'dart:async';

import 'package:flutter/material.dart';

import '../../ui/app_haptics.dart';

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
    this.active = true,
    this.now = DateTime.now,
  });
  final DateTime start;
  final DateTime? end;
  final RestCountdown rest;
  final bool active;
  final DateTime Function() now;

  @override
  State<SessionTimerPanel> createState() => _SessionTimerPanelState();
}

class _SessionTimerPanelState extends State<SessionTimerPanel>
    with WidgetsBindingObserver {
  Timer? _ticker;
  bool _completionArmed = false;
  bool _foreground = true;
  bool get _visible => widget.active && _foreground;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    widget.rest.addListener(_restChanged);
    _armCompletion();
    _syncTicker();
  }

  void _armCompletion() {
    _completionArmed =
        _visible &&
        widget.end == null &&
        widget.rest.started &&
        widget.rest.remaining(widget.now()) > Duration.zero;
  }

  void _restChanged() => _armCompletion();

  void _syncTicker() {
    _ticker?.cancel();
    if (_visible && widget.end == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (_completionArmed &&
            widget.rest.remaining(widget.now()) == Duration.zero) {
          _completionArmed = false;
          AppHaptics.of(context).success();
        }
        setState(() {});
      });
    }
  }

  @override
  void didUpdateWidget(SessionTimerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rest != widget.rest) {
      oldWidget.rest.removeListener(_restChanged);
      widget.rest.addListener(_restChanged);
    }
    if (oldWidget.end != widget.end ||
        oldWidget.active != widget.active ||
        oldWidget.rest != widget.rest) {
      _armCompletion();
      _syncTicker();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _armCompletion();
    if (_foreground) {
      setState(() {});
      _syncTicker();
    } else {
      _ticker?.cancel();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    widget.rest.removeListener(_restChanged);
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
                    onPressed: () {
                      widget.rest.clear();
                      AppHaptics.of(context).selection();
                    },
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
