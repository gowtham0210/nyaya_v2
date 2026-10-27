import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/presentation/widgets/law_illustration.dart';

/// Painted artwork for the intro slides, generated to sit on the Warm Cream
/// background. If a file is missing the slide falls back to a flat,
/// drawn-in-code stand-in.
abstract final class IntroArt {
  static const hero = 'assets/images/onboarding_hero.webp';
  static const lessons = 'assets/images/onboarding_lessons.webp';
  static const practice = 'assets/images/onboarding_practice.webp';
}

TextStyle _serif(BuildContext context, double size, {Color? color, bool display = true}) => AppTheme.serif(
      TextStyle(fontSize: size, height: 1.12, color: color ?? context.colors.onSurface),
      display: display,
    );

/// Three swipeable value slides with Skip, dot indicator, a round next button
/// and a final "Get Started". [onDone] continues the onboarding flow.
class IntroSlides extends StatefulWidget {
  const IntroSlides({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<IntroSlides> createState() => _IntroSlidesState();
}

class _IntroSlidesState extends State<IntroSlides> {
  static const _count = 3;
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _count - 1) return widget.onDone();
    _controller.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final last = _page == _count - 1;
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, AppSpacing.sm, 0),
            child: TextButton(
              onPressed: widget.onDone,
              style: TextButton.styleFrom(
                foregroundColor: context.colors.onSurface,
                textStyle: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
              ),
              child: Text(l.onbSkip),
            ),
          ),
        ),
        Expanded(
          child: PageView(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            children: const [_BrandSlide(), _LessonsSlide(), _PracticeSlide()],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page + 4, AppSpacing.sm, AppSpacing.page, AppSpacing.lg),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: last
                ? Column(
                    key: const ValueKey('last'),
                    children: [
                      _Dots(count: _count, page: _page),
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: widget.onDone,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 62),
                            shape: const StadiumBorder(),
                            textStyle: _serif(context, 21, display: false),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(l.onbGetStarted),
                              const SizedBox(width: 12),
                              const Icon(Icons.arrow_forward_rounded, size: 22),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    key: const ValueKey('next'),
                    children: [
                      _Dots(count: _count, page: _page),
                      const Spacer(),
                      SizedBox.square(
                        dimension: 72,
                        child: IconButton.filled(
                          tooltip: l.commonContinue,
                          onPressed: _next,
                          icon: const Icon(Icons.arrow_forward_rounded, size: 30),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.page});

  final int count;
  final int page;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == page ? context.colors.primary : context.colors.outlineVariant,
            ),
          ),
      ],
    );
  }
}

/// Small spaced-capitals label above a slide title ("STRUCTURED LEARNING").
class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: context.text.labelLarge?.copyWith(
          color: context.colors.primary,
          fontWeight: FontWeight.w600,
          letterSpacing: 3,
        ),
      );
}

/// Which edges of an image fade into the page. A right-pinned image keeps its
/// right edge, which already meets the screen edge.
enum _Fade { none, vertical, exceptRight }

/// Shows [asset], or [fallback] while the generated image has not been added.
/// [fade] blends the image's edges into the page, so small differences between
/// the painting's cream and Warm Cream leave no visible seam.
class _Art extends StatelessWidget {
  const _Art({
    required this.asset,
    required this.fallback,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.fade = _Fade.none,
  });

  final String asset;
  final Widget fallback;
  final BoxFit fit;
  final Alignment alignment;
  final _Fade fade;

  static Widget _mask(Widget child, {required bool horizontal}) => ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => LinearGradient(
          begin: horizontal ? Alignment.centerLeft : Alignment.topCenter,
          end: horizontal ? Alignment.centerRight : Alignment.bottomCenter,
          colors: const [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
          stops: horizontal ? const [0, 0.1, 1, 1] : const [0, 0.08, 0.94, 1],
        ).createShader(bounds),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      asset,
      fit: fit,
      alignment: alignment,
      excludeFromSemantics: true,
      errorBuilder: (context, error, stack) => fallback,
    );
    return switch (fade) {
      _Fade.none => image,
      _Fade.vertical => _mask(image, horizontal: false),
      _Fade.exceptRight => _mask(_mask(image, horizontal: false), horizontal: true),
    };
  }
}

class _SlideText extends StatelessWidget {
  const _SlideText({this.eyebrow, required this.title, required this.body});

  final String? eyebrow;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[_Eyebrow(eyebrow!), const SizedBox(height: 12)],
          Text(title, style: _serif(context, 40)).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08),
          const SizedBox(height: AppSpacing.md),
          Text(
            body,
            style: context.text.bodyLarge?.copyWith(color: context.nyaya.textSecondary, height: 1.5),
          ).animate().fadeIn(delay: 100.ms, duration: 350.ms),
        ],
      ),
    );
  }
}

// ── Slide 1: brand, hero artwork, promise ──────────────────────────────────

class _BrandSlide extends StatelessWidget {
  const _BrandSlide();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page + 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.appName, style: _serif(context, 58, color: context.colors.primary)),
              Container(width: 30, height: 3, color: context.colors.primary),
              const SizedBox(height: AppSpacing.md),
              Text(l.onbBrandTagline, style: _serif(context, 22, display: false)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Square, pinned to the right edge, so the fade mask matches the image.
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => Align(
              alignment: Alignment.centerRight,
              child: SizedBox.square(
                dimension: box.maxWidth < box.maxHeight ? box.maxWidth : box.maxHeight,
                child: const _Art(asset: IntroArt.hero, fade: _Fade.exceptRight, fallback: _HeroFallback()),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _SlideText(title: l.onbIntro1Title, body: l.onbIntro1Body),
      ],
    );
  }
}

/// Terracotta sun, scales and the court — a flat stand-in for the hero image.
class _HeroFallback extends StatelessWidget {
  const _HeroFallback();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final s = box.biggest.shortestSide;
        return Stack(
          children: [
            Positioned(
              right: box.maxWidth * 0.12,
              top: 0,
              child: Container(
                width: s * 0.72,
                height: s * 0.72,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppPalette.burntClay),
              ),
            ),
            Positioned(left: box.maxWidth * 0.06, top: s * 0.04, width: s * 0.55, height: s * 0.6, child: const LawIllustration(art: LawArt.scales)),
            Positioned(right: 0, bottom: 0, width: box.maxWidth * 0.78, height: s * 0.62, child: const LawIllustration(art: LawArt.court)),
          ],
        );
      },
    );
  }
}

// ── Slide 2: structured learning ───────────────────────────────────────────

class _LessonsSlide extends StatelessWidget {
  const _LessonsSlide();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        _SlideText(eyebrow: l.onbIntro2Label, title: l.onbIntro2Title, body: l.onbIntro2Body),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const _Art(
                asset: IntroArt.lessons,
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                fade: _Fade.vertical,
                fallback: _ArchesFallback(warm: false),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page + 20, AppSpacing.md, AppSpacing.page + 20, 0),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topCenter,
                  child: Transform.rotate(angle: -0.035, child: const _LessonCardMock()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Soft arches behind the demo cards (stand-in for the generated backdrops).
class _ArchesFallback extends StatelessWidget {
  const _ArchesFallback({required this.warm});

  final bool warm;

  @override
  Widget build(BuildContext context) {
    final a = warm ? AppPalette.burntClay : AppPalette.sand.withValues(alpha: 0.55);
    final b = warm ? AppPalette.terracotta.withValues(alpha: 0.85) : const Color(0xFFF1DDD2);
    Widget arch(Color c, double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.vertical(top: Radius.circular(w / 2))),
        );
    return LayoutBuilder(
      builder: (context, box) => Stack(
        children: [
          Positioned(left: -box.maxWidth * 0.08, bottom: 0, child: arch(a, box.maxWidth * 0.5, box.maxHeight * 0.72)),
          Positioned(right: -box.maxWidth * 0.1, top: 0, child: arch(b, box.maxWidth * 0.55, box.maxHeight * 0.9)),
        ],
      ),
    );
  }
}

class _LessonCardMock extends StatelessWidget {
  const _LessonCardMock();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lessons = [
      (l.onbDemoLesson1, Icons.check_circle_rounded, context.colors.primary),
      (l.onbDemoLesson2, Icons.play_circle_fill_rounded, context.colors.onSurface),
      (l.onbDemoLesson3, Icons.lock_outline_rounded, context.nyaya.textSecondary),
      (l.onbDemoLesson4, Icons.lock_outline_rounded, context.nyaya.textSecondary),
    ];
    return Container(
      width: 320,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      decoration: _mockCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.onbDemoChapter, style: _serif(context, 22, display: false)),
                    const SizedBox(height: 2),
                    Text(l.onbDemoChapterSub, style: context.text.bodySmall?.copyWith(color: context.nyaya.textSecondary)),
                  ],
                ),
              ),
              const _IconBadge(icon: Icons.bookmark_border_rounded, size: 32),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: Text(l.onbDemoProgress, style: context.text.bodyMedium)),
              Text('60%', style: context.text.bodyMedium),
            ],
          ),
          const SizedBox(height: 8),
          const _MockBar(value: 0.6),
          const SizedBox(height: 16),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(color: context.colors.primary, borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    l.onbDemoContinue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _serif(context, 17, color: context.colors.onPrimary, display: false),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.arrow_forward_rounded, size: 18, color: context.colors.onPrimary),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (final (title, icon, color) in lessons) ...[
            Divider(height: 1, color: context.nyaya.cardBorder),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  const _IconBadge(icon: Icons.menu_book_rounded, size: 34, square: true),
                  const SizedBox(width: 14),
                  Expanded(child: Text(title, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w500))),
                  Icon(icon, size: 22, color: color),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Slide 3: practice & apply ──────────────────────────────────────────────

class _PracticeSlide extends StatelessWidget {
  const _PracticeSlide();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        _SlideText(eyebrow: l.onbIntro3Label, title: l.onbIntro3Title, body: l.onbIntro3Body),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const _Art(
                asset: IntroArt.practice,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                fade: _Fade.vertical,
                fallback: _ArchesFallback(warm: true),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: 390,
                  height: 380,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 24,
                        top: 8,
                        width: 280,
                        child: _FeatureMock(
                          icon: Icons.edit_note_rounded,
                          title: l.onbDemoQuiz,
                          sub: l.onbDemoQuizSub,
                          progress: 0.6,
                        ),
                      ),
                      Positioned(
                        right: 16,
                        top: 132,
                        width: 270,
                        child: _FeatureMock(
                          icon: Icons.newspaper_rounded,
                          title: l.onbDemoUpdates,
                          sub: l.onbDemoUpdatesSub,
                        ),
                      ),
                      Positioned(
                        left: 44,
                        top: 254,
                        width: 300,
                        child: _FeatureMock(
                          icon: Icons.lightbulb_outline_rounded,
                          title: l.onbDemoScenarios,
                          sub: l.onbDemoScenariosSub,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeatureMock extends StatelessWidget {
  const _FeatureMock({required this.icon, required this.title, required this.sub, this.progress});

  final IconData icon;
  final String title;
  final String sub;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _mockCard(context),
      child: Row(
        children: [
          _IconBadge(icon: icon, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _serif(context, 18, display: false)),
                const SizedBox(height: 4),
                Text(sub, style: context.text.bodySmall?.copyWith(color: context.nyaya.textSecondary, height: 1.4)),
                if (progress != null) ...[const SizedBox(height: 10), _MockBar(value: progress!)],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_rounded, size: 20, color: context.colors.primary),
        ],
      ),
    );
  }
}

BoxDecoration _mockCard(BuildContext context) => BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md + 2),
      boxShadow: [
        BoxShadow(color: AppPalette.deepEarth.withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, 10)),
      ],
    );

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.size, this.square = false});

  final IconData icon;
  final double size;
  final bool square;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: context.colors.primaryContainer,
          shape: square ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: square ? BorderRadius.circular(8) : null,
        ),
        child: Icon(icon, size: size * 0.55, color: context.colors.primary),
      );
}

class _MockBar extends StatelessWidget {
  const _MockBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: value,
          minHeight: 7,
          color: context.colors.primary,
          backgroundColor: context.colors.outlineVariant,
        ),
      );
}
