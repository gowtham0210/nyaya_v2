import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// Rebuilds on an interval — for live countdowns ("resets in 3h 12m").
class TickingBuilder extends StatefulWidget {
  const TickingBuilder({super.key, required this.builder, this.interval = const Duration(seconds: 30)});

  final WidgetBuilder builder;
  final Duration interval;

  @override
  State<TickingBuilder> createState() => _TickingBuilderState();
}

class _TickingBuilderState extends State<TickingBuilder> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.interval, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
