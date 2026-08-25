import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Adds interactive, horizontal navigation to the five primary app pages.
///
/// The page follows the user's finger, settles back after a short/slow drag,
/// and completes with a short ease-out animation after an intentional swipe.
class SwipePage extends StatefulWidget {
  const SwipePage({
    required this.index,
    required this.child,
    super.key,
  });

  final int index;
  final Widget child;

  static const routes = [
    '/',
    '/activities',
    '/performance',
    '/plan',
    '/connections',
  ];

  @override
  State<SwipePage> createState() => _SwipePageState();
}

class _SwipePageState extends State<SwipePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Animation<double>? _animation;
  double _dragOffset = 0;
  double _width = 1;
  bool _finishingNavigation = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 210),
    )..addListener(() {
        final animation = _animation;
        if (animation != null && mounted) {
          setState(() => _dragOffset = animation.value);
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    if (_finishingNavigation) return;
    _controller.stop();
    _animation = null;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_finishingNavigation) return;
    var next = (_dragOffset + details.delta.dx).clamp(-_width, _width);
    final atFirstPage = widget.index == 0 && next > 0;
    final atLastPage = widget.index == SwipePage.routes.length - 1 && next < 0;
    if (atFirstPage || atLastPage) {
      // Resistance at the ends makes it clear there is no adjacent page.
      next = next * .28;
    }
    setState(() => _dragOffset = next);
  }

  Future<void> _onDragEnd(DragEndDetails details) async {
    if (_finishingNavigation) return;
    final velocity = details.primaryVelocity ?? 0;
    final intentional =
        _dragOffset.abs() >= _width * .18 || velocity.abs() >= 500;
    final direction = _dragOffset.abs() > 8
        ? (_dragOffset < 0 ? 1 : -1)
        : (velocity < 0 ? 1 : -1);
    final nextIndex = widget.index + direction;
    final valid =
        intentional && nextIndex >= 0 && nextIndex < SwipePage.routes.length;

    if (!valid) {
      await _animateTo(0, const Duration(milliseconds: 180));
      return;
    }

    _finishingNavigation = true;
    final exit = direction > 0 ? -_width : _width;
    final remaining = ((exit - _dragOffset).abs() / _width).clamp(.2, 1.0);
    await _animateTo(
      exit,
      Duration(milliseconds: (190 * remaining).round()),
    );
    if (!mounted) return;
    context.go(SwipePage.routes[nextIndex]);
  }

  Future<void> _animateTo(double target, Duration duration) async {
    _controller
      ..stop()
      ..duration = duration
      ..reset();
    _animation = Tween<double>(begin: _dragOffset, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    await _controller.forward();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          _width = constraints.maxWidth;
          final progress = (_dragOffset.abs() / _width).clamp(0.0, 1.0);
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: _onDragStart,
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            onHorizontalDragCancel: () =>
                _animateTo(0, const Duration(milliseconds: 180)),
            child: Transform.translate(
              offset: Offset(_dragOffset, 0),
              child: Opacity(
                opacity: 1 - progress * .16,
                child: widget.child,
              ),
            ),
          );
        },
      );
}
