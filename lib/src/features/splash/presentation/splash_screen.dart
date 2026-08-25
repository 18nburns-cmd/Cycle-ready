import 'dart:async';
import 'dart:math' as math;

import 'package:cycle_ready/src/features/splash/domain/motivational_quotes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
    timer = Timer(const Duration(milliseconds: 2200), _continue);
  }

  @override
  void dispose() {
    timer?.cancel();
    animation.dispose();
    super.dispose();
  }

  void _continue() {
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final quote = quoteForDay(DateTime.now());
    final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    return Scaffold(
      body: InkWell(
        onTap: _continue,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.surface,
                const Color(0xFF0B2830),
                const Color(0xFF07141C),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: FadeTransition(
                opacity: fade,
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    ScaleTransition(
                      scale: Tween(begin: .82, end: 1.0).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutBack,
                        ),
                      ),
                      child: SizedBox.square(
                        dimension: 138,
                        child: CustomPaint(
                          painter: _LaunchMarkPainter(colors),
                          child: Icon(
                            Icons.directions_bike_rounded,
                            size: 60,
                            color: colors.onPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'CycleReady',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.8,
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'RIDE  •  RECOVER  •  PROGRESS',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colors.primary,
                            letterSpacing: 2.1,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(flex: 2),
                    const Icon(
                      Icons.format_quote_rounded,
                      color: Color(0xFF54D6B8),
                      size: 30,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '“${quote.text}”',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '— ${quote.author}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                    const Spacer(flex: 3),
                    SizedBox(
                      width: 90,
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        borderRadius: BorderRadius.circular(3),
                        color: const Color(0xFF54D6B8),
                        backgroundColor: Colors.white12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tap to continue',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: Colors.white54),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LaunchMarkPainter extends CustomPainter {
  const _LaunchMarkPainter(this.colors);
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: centre, radius: size.width * .45);
    canvas.drawCircle(
      centre,
      size.width * .36,
      Paint()..color = colors.primary,
    );
    canvas.drawArc(
      rect,
      -math.pi * .75,
      math.pi * 1.35,
      false,
      Paint()
        ..color = const Color(0xFF54D6B8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      rect,
      math.pi * .72,
      math.pi * .25,
      false,
      Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _LaunchMarkPainter oldDelegate) =>
      oldDelegate.colors != colors;
}
