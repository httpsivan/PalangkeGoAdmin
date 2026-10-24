import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Redesigned PalengkeGo Onboarding / Get Started Screen
///
/// Features a modern, clean, mobile-friendly design based on the PalengkeGo design system:
/// - Naga City People's Mall entrance photograph with rounded corners & shadow
/// - PalengkeGo branding with existing logo asset
/// - Atmospheric fresh-green botanical background accents
/// - Headline with leafy brand mark & supporting text
/// - Progress indicator capsule/dots matching the design specification
/// - High-contrast "Get Started →" primary action button with touch feedback
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  // Palette constants defined by the PalengkeGo design system
  static const Color primaryDarkGreen = Color(0xFF073B2C);
  static const Color buttonGreen = Color(0xFF07503A);
  static const Color buttonGreenHover = Color(0xFF0B634A);
  static const Color freshGreenAccent = Color(0xFF58A83B);
  static const Color supportingText = Color(0xFF667085);
  static const Color inactiveIndicator = Color(0xFFD9DEDB);
  static const Color decorBackground = Color(0xFFEDF5EA);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Subtle organic light-green leaf decorations around the background
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _OnboardingDecorPainter(),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;
                final isSmall = width < 360;
                final isShort = height < 700;

                // Responsive image sizing (88-90% width, max 350, aspect-ratio preserved)
                final imageWidth = isSmall
                    ? (width - 40).clamp(260.0, 320.0)
                    : (width * 0.88).clamp(280.0, 350.0);
                final imageHeight = isShort
                    ? (imageWidth * 0.86).clamp(210.0, 270.0)
                    : imageWidth;

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: height),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmall ? 20.0 : 24.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(height: isShort ? 10 : 16),

                            // 1. PalengkeGo logo & branding
                            const _OnboardingLogo(),

                            SizedBox(height: isShort ? 12 : 20),

                            // 2. Main Market Image: Naga City People's Mall
                            _buildMarketImage(imageWidth, imageHeight),

                            SizedBox(height: isShort ? 16 : 24),

                            // 3. Main Headline with leaf accent
                            _buildHeadline(isSmall),

                            const SizedBox(height: 12),

                            // 4. Supporting Description
                            Text(
                              'Find fresh produce and local goods from the comfort of your home.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: isSmall ? 14 : 15,
                                fontWeight: FontWeight.w400,
                                color: supportingText,
                                height: 1.45,
                              ),
                            ),

                            SizedBox(height: isShort ? 16 : 24),

                            // 5. Onboarding Progress Indicator
                            const _OnboardingProgressIndicators(),

                            const Spacer(),

                            SizedBox(height: isShort ? 14 : 20),

                            // 6. Get Started Button
                            Padding(
                              padding: const EdgeInsets.only(bottom: 24.0),
                              child: _GetStartedButton(
                                onPressed: () async {
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setBool('hasSeenOnboarding', true);
                                  if (context.mounted) {
                                    if (context.canPop()) {
                                      context.pop();
                                    } else {
                                      context.go('/overview');
                                    }
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketImage(double width, double height) {
    return Center(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: primaryDarkGreen.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 10),
              spreadRadius: -2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Image.asset(
            'assets/images/naga_city_mall.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (context, error, stackTrace) => Container(
              color: primaryDarkGreen,
              child: const Center(
                child: Icon(
                  Icons.storefront_outlined,
                  size: 96,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeadline(bool isSmall) {
    final fontSize = isSmall ? 22.0 : 26.0;

    return Center(
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Browse your favorite ',
              style: GoogleFonts.plusJakartaSans(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: primaryDarkGreen,
                height: 1.25,
                letterSpacing: -0.4,
              ),
            ),
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsets.only(left: 3.0),
                child: CustomPaint(
                  size: Size(22, 22),
                  painter: _TwoLeavesPainter(color: freshGreenAccent),
                ),
              ),
            ),
            TextSpan(
              text: '\nwet market stalls anytime',
              style: GoogleFonts.plusJakartaSans(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: primaryDarkGreen,
                height: 1.25,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Logo widget that renders the existing PalengkeGo brand asset with text
class _OnboardingLogo extends StatelessWidget {
  const _OnboardingLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Existing logo asset
        Image.asset(
          'assets/images/market_basket.png',
          height: 44,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const CustomPaint(
            size: Size(44, 40),
            painter: _BasketLogoFallbackPainter(),
          ),
        ),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Palengke',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: OnboardingScreen.primaryDarkGreen,
                  letterSpacing: -0.3,
                ),
              ),
              TextSpan(
                text: 'Go',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: OnboardingScreen.freshGreenAccent,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Fallback basket icon painter matching the PalengkeGo basket branding
class _BasketLogoFallbackPainter extends CustomPainter {
  const _BasketLogoFallbackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final basketPaint = Paint()
      ..color = const Color(0xFF073B2C)
      ..style = PaintingStyle.fill;

    final leafPaint = Paint()
      ..color = const Color(0xFF58A83B)
      ..style = PaintingStyle.fill;

    // Basket body
    final basketRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, size.height * 0.42, size.width - 8, size.height * 0.52),
      const Radius.circular(8),
    );
    canvas.drawRRect(basketRect, basketPaint);

    // Basket handle
    final handlePaint = Paint()
      ..color = const Color(0xFF073B2C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawArc(
      Rect.fromLTWH(size.width * 0.25, size.height * 0.16, size.width * 0.5, size.height * 0.5),
      3.14,
      3.14,
      false,
      handlePaint,
    );

    // Leaf sprouting on top
    final leafPath = Path();
    leafPath.moveTo(size.width * 0.52, size.height * 0.28);
    leafPath.quadraticBezierTo(size.width * 0.75, size.height * 0.05, size.width * 0.85, size.height * 0.15);
    leafPath.quadraticBezierTo(size.width * 0.72, size.height * 0.38, size.width * 0.52, size.height * 0.28);
    leafPath.close();
    canvas.drawPath(leafPath, leafPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Three small progress indicators: active dark green capsule + two light gray dots
class _OnboardingProgressIndicators extends StatelessWidget {
  const _OnboardingProgressIndicators();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Onboarding step 1 of 3',
      child: Row(
        key: const Key('onboarding_progress_indicators'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Active capsule indicator
          Container(
            key: const Key('active_indicator'),
            width: 24,
            height: 7,
            decoration: BoxDecoration(
              color: OnboardingScreen.primaryDarkGreen,
              borderRadius: BorderRadius.circular(3.5),
            ),
          ),
          const SizedBox(width: 8),
          // Inactive circular indicator
          Container(
            key: const Key('inactive_indicator_1'),
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: OnboardingScreen.inactiveIndicator,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          // Inactive circular indicator
          Container(
            key: const Key('inactive_indicator_2'),
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: OnboardingScreen.inactiveIndicator,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

/// Redesigned primary Get Started button with right-arrow icon & tactile feedback
class _GetStartedButton extends StatefulWidget {
  const _GetStartedButton({required this.onPressed});

  final Future<void> Function() onPressed;

  @override
  State<_GetStartedButton> createState() => _GetStartedButtonState();
}

class _GetStartedButtonState extends State<_GetStartedButton> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _isPressed ? 0.98 : (_isHovered ? 1.01 : 1.0),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: OnboardingScreen.buttonGreen.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 7),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Material(
          color: _isHovered
              ? OnboardingScreen.buttonGreenHover
              : OnboardingScreen.buttonGreen,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            key: const Key('get_started_button'),
            onTap: () async {
              await widget.onPressed();
            },
            onHighlightChanged: (highlighted) {
              setState(() => _isPressed = highlighted);
            },
            onHover: (hovered) {
              setState(() => _isHovered = hovered);
            },
            borderRadius: BorderRadius.circular(28),
            splashColor: Colors.white.withValues(alpha: 0.15),
            highlightColor: Colors.white.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Get Started',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two small leafy brand marks drawn beside the headline
class _TwoLeavesPainter extends CustomPainter {
  const _TwoLeavesPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Upright leaf
    final leaf1 = Path();
    leaf1.moveTo(size.width * 0.15, size.height * 0.85);
    leaf1.quadraticBezierTo(size.width * 0.05, size.height * 0.35, size.width * 0.40, size.height * 0.15);
    leaf1.quadraticBezierTo(size.width * 0.65, size.height * 0.45, size.width * 0.15, size.height * 0.85);
    leaf1.close();
    canvas.drawPath(leaf1, paint);

    // Angled lateral leaf
    final leaf2 = Path();
    leaf2.moveTo(size.width * 0.30, size.height * 0.85);
    leaf2.quadraticBezierTo(size.width * 0.55, size.height * 0.50, size.width * 0.95, size.height * 0.45);
    leaf2.quadraticBezierTo(size.width * 0.85, size.height * 0.80, size.width * 0.30, size.height * 0.85);
    leaf2.close();
    canvas.drawPath(leaf2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Background painter rendering subtle light-green leaf decorations
class _OnboardingDecorPainter extends CustomPainter {
  const _OnboardingDecorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final decorPaint = Paint()
      ..color = const Color(0xFFEDF5EA)
      ..style = PaintingStyle.fill;

    // Top-left soft organic curve
    final topLeftPath = Path();
    topLeftPath.moveTo(0, 0);
    topLeftPath.lineTo(size.width * 0.18, 0);
    topLeftPath.cubicTo(
      size.width * 0.16, size.height * 0.07,
      size.width * 0.04, size.height * 0.14,
      0, size.height * 0.17,
    );
    topLeftPath.close();
    canvas.drawPath(topLeftPath, decorPaint);

    // Top-left leaf petal accent
    final petalPaint = Paint()
      ..color = const Color(0xFFE2EFE0)
      ..style = PaintingStyle.fill;
    final topPetal = Path();
    topPetal.moveTo(0, size.height * 0.08);
    topPetal.quadraticBezierTo(
      size.width * 0.14, size.height * 0.06,
      size.width * 0.12, size.height * 0.13,
    );
    topPetal.quadraticBezierTo(
      size.width * 0.03, size.height * 0.16,
      0, size.height * 0.15,
    );
    topPetal.close();
    canvas.drawPath(topPetal, petalPaint);

    // Top-left playful burst dashes (near top-left corner of the image)
    final burstPaint = Paint()
      ..color = const Color(0xFF58A83B).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;

    final burstX = size.width * 0.11;
    final burstY = size.height * 0.185;
    canvas.drawLine(
      Offset(burstX, burstY),
      Offset(burstX + 9, burstY - 11),
      burstPaint,
    );
    canvas.drawLine(
      Offset(burstX + 13, burstY + 2),
      Offset(burstX + 15, burstY - 12),
      burstPaint,
    );

    // Bottom-left botanical foliage silhouette
    final stemPaint = Paint()
      ..color = const Color(0xFFEDF5EA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0, size.height * 0.89),
      Offset(size.width * 0.14, size.height * 0.82),
      stemPaint,
    );

    // Bottom-left leaves
    _drawLeaf(canvas, Offset(size.width * 0.06, size.height * 0.86), 28, -0.6, decorPaint);
    _drawLeaf(canvas, Offset(size.width * 0.10, size.height * 0.83), 32, -1.1, decorPaint);
    _drawLeaf(canvas, Offset(size.width * 0.15, size.height * 0.81), 26, -0.2, decorPaint);

    // Bottom-right soft organic hill
    final bottomRightPath = Path();
    bottomRightPath.moveTo(size.width, size.height);
    bottomRightPath.lineTo(size.width * 0.62, size.height);
    bottomRightPath.cubicTo(
      size.width * 0.72, size.height * 0.94,
      size.width * 0.82, size.height * 0.85,
      size.width, size.height * 0.82,
    );
    bottomRightPath.close();
    canvas.drawPath(bottomRightPath, decorPaint);
  }

  void _drawLeaf(Canvas canvas, Offset origin, double length, double angle, Paint paint) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(angle);
    final leaf = Path();
    leaf.moveTo(0, 0);
    leaf.quadraticBezierTo(length * 0.35, -length * 0.32, length, 0);
    leaf.quadraticBezierTo(length * 0.35, length * 0.32, 0, 0);
    leaf.close();
    canvas.drawPath(leaf, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
