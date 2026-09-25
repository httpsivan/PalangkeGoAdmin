import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/animations/animated_widgets.dart';
import '../../core/animations/app_motion.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/admin_widgets.dart';
import '../../data/repositories/auth_repository.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  static const _loginSlides = <String>[
    'assets/images/naga_city_mall.jpg',
    'assets/images/fruit_stall.jpg',
    'assets/images/meat_stall.jpg',
    'assets/images/seafood_stall.jpg',
    'assets/images/sari_sari_stall.jpg',
    'assets/images/fish_market.jpg',
    'assets/images/dried_fish_stall.jpg',
    'assets/images/vegetable_stall.jpg',
    'assets/images/market_background.jpg',
  ];

  final formKey = GlobalKey<FormState>();
  final _mobileScrollController = ScrollController();
  final _desktopFormScrollController = ScrollController();
  // Demo credentials prefill only in demo mode — Firebase mode must never
  // pre-fill a real administrator's password.
  final email = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;
  bool keepSignedIn = false;
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    if (!ref.read(firebaseEnabledProvider)) {
      email.text = defaultAdminEmail;
      password.text = defaultAdminPassword;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final path in _loginSlides) {
      precacheImage(AssetImage(path), context).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _mobileScrollController.dispose();
    _desktopFormScrollController.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() => error = null);
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() => loading = true);
    final result = await ref
        .read(authProvider.notifier)
        .login(email.text, password.text, keepSignedIn);
    if (!mounted) return;
    setState(() {
      loading = false;
      error = result;
    });
    if (result == null) {
      context.go('/overview');
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result)));
    }
  }

  static final _loginThemeData = buildLightTheme();

  @override
  Widget build(BuildContext context) {
    return Theme(
      // The login screen intentionally stays light even when the dashboard
      // theme preference is dark.
      data: _loginThemeData,
      child: Builder(
        builder: (loginContext) {
          final narrow = MediaQuery.sizeOf(loginContext).width < 820;
          final body = narrow
              ? SingleChildScrollView(
                  controller: _mobileScrollController,
                  child: Column(
                    children: [
                      _market(loginContext, true),
                      _loginForm(loginContext),
                    ],
                  ),
                )
              : SizedBox.expand(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 52, child: _market(loginContext, false)),
                      Expanded(flex: 48, child: _loginForm(loginContext)),
                    ],
                  ),
                );
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            body: Form(
              key: formKey,
              child: Column(
                children: [
                  const _Header(dark: false),
                  Expanded(child: body),
                  const _Footer(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _market(BuildContext context, bool compact) {
    final width = MediaQuery.sizeOf(context).width;
    final headlineSize = compact
        ? (width < 400 ? 28.0 : 32.0)
        : (width < 1200 ? 42.0 : 50.0);
    final badgeSize = compact ? 11.5 : 14.0;

    return Container(
      height: compact ? 270 : double.infinity,
      constraints: BoxConstraints(minHeight: compact ? 270 : 360),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: semanticColors(context).heroBackground,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: const _LoginSlideshow(images: _loginSlides),
          ),
          // Subtle green overlay to maintain PalengkeGo identity while keeping market details crisp
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.38, 0.68, 1.0],
                  colors: [
                    const Color(0xFF0F4A3C).withValues(alpha: 0.18),
                    const Color(0xFF0B382D).withValues(alpha: 0.32),
                    const Color(0xFF07271F).withValues(alpha: 0.62),
                    const Color(0xFF041813).withValues(alpha: 0.88),
                  ],
                ),
              ),
            ),
          ),
          // Promotional text aligned at the bottom with high contrast and readable hierarchy
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 24 : 44,
                24,
                compact ? 24 : 44,
                compact ? 24 : 48,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 12 : 15,
                      vertical: compact ? 6 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.32),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Text(
                      'NAGA CITY PEOPLE’S MALL',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: badgeSize,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 12 : 18),
                  Text(
                    'Skip the Roam,\nOrder from Home.',
                    style: GoogleFonts.radley(
                      color: Colors.white,
                      fontSize: headlineSize,
                      height: 1.18,
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.65),
                          offset: const Offset(0, 2),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loginForm(BuildContext context) {
    final colors = semanticColors(context);
    final isDesktop = MediaQuery.sizeOf(context).width >= 820;

    final formContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Welcome Back, Admin!',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: colors.heroBackground,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Authorized personnel only',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: colors.secondaryText,
          ),
        ),
        const SizedBox(height: 16),
        Center(child: _ModeBadge(firebase: ref.read(firebaseEnabledProvider))),
        const SizedBox(height: 26),
        Text(
          'Email Address',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: colors.primaryText,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: email,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          style: GoogleFonts.inter(
            fontSize: 13.5,
            color: colors.primaryText,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'admin@nagacity.gov.ph',
            hintStyle: TextStyle(
              color: colors.disabledText,
              fontSize: 13,
            ),
            prefixIcon: Icon(
              Icons.mail_outline_rounded,
              size: 19,
              color: colors.secondaryText,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: colors.heroBackground,
                width: 1.8,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: colors.danger,
                width: 1.2,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: colors.danger,
                width: 1.8,
              ),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Enter your administrator email';
            }
            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                .hasMatch(value.trim())) {
              return 'Enter a valid email address';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        Text(
          'Password',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: colors.primaryText,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: password,
          obscureText: obscure,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onFieldSubmitted: (_) => submit(),
          style: GoogleFonts.inter(
            fontSize: 13.5,
            color: colors.primaryText,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: TextStyle(
              color: colors.disabledText,
              fontSize: 13,
            ),
            prefixIcon: Icon(
              Icons.lock_outline_rounded,
              size: 19,
              color: colors.secondaryText,
            ),
            suffixIcon: Tooltip(
              message: obscure ? 'Show password' : 'Hide password',
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: IconButton(
                  onPressed: () => setState(() => obscure = !obscure),
                  icon: Icon(
                    obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 19,
                    color: colors.secondaryText,
                  ),
                ),
              ),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: colors.heroBackground,
                width: 1.8,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: colors.danger,
                width: 1.2,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: colors.danger,
                width: 1.8,
              ),
            ),
          ),
          validator: (value) =>
              value == null || value.isEmpty ? 'Enter your password' : null,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (!ref.read(firebaseEnabledProvider))
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => keepSignedIn = !keepSignedIn),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: keepSignedIn,
                            activeColor: colors.heroBackground,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            side: const BorderSide(
                              color: Color(0xFF94A3B8),
                              width: 1.5,
                            ),
                            onChanged: (value) =>
                                setState(() => keepSignedIn = value ?? false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Keep me signed in',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: colors.secondaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: InkWell(
                onTap: () => _forgot(context),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  child: Text(
                    'Forgot password?',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.heroBackground,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.dangerContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colors.danger.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 16,
                  color: colors.danger,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error!,
                    style: GoogleFonts.inter(
                      color: colors.danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => error = null),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: colors.danger,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        SizedBox(
          height: 48,
          child: AnimatedButtonFeedback(
            enabled: !loading,
            child: FilledButton(
              onPressed: loading ? null : submit,
              style: FilledButton.styleFrom(
                backgroundColor: colors.heroBackground,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    colors.heroBackground.withValues(alpha: 0.6),
                disabledForegroundColor: Colors.white70,
                elevation: 1,
                shadowColor: colors.heroBackground.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: loading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Authenticating...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'Log In',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );

    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardPadding = screenWidth < 600
        ? const EdgeInsets.symmetric(horizontal: 18, vertical: 22)
        : (isDesktop
            ? const EdgeInsets.symmetric(horizontal: 36, vertical: 36)
            : const EdgeInsets.symmetric(horizontal: 24, vertical: 28));

    final card = Container(
      constraints: const BoxConstraints(maxWidth: 440),
      padding: cardPadding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: formContent,
    );

    final panel = Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: isDesktop
            ? SingleChildScrollView(
                controller: _desktopFormScrollController,
                child: card,
              )
            : card,
      ),
    );

    final animatedPanel = FadeSlideIn(
      begin: const Offset(0, .035),
      child: panel,
    );

    return isDesktop
        ? SizedBox.expand(child: animatedPanel)
        : animatedPanel;
  }

  Future<void> _forgot(BuildContext context) async {
    final controller = TextEditingController(text: email.text);
    final colors = semanticColors(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Reset Password',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: colors.heroBackground,
          ),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter your administrator email address to receive password reset instructions.',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: colors.secondaryText,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.inter(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Administrator Email',
                  hintText: 'admin@nagacity.gov.ph',
                  prefixIcon: const Icon(Icons.mail_outline_rounded, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.secondaryText),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'If the account exists, password reset instructions have been sent.',
                  ),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: colors.heroBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
    controller.dispose();
  }
}

class _LoginSlideshow extends StatefulWidget {
  const _LoginSlideshow({required this.images});

  final List<String> images;

  @override
  State<_LoginSlideshow> createState() => _LoginSlideshowState();
}

class _LoginSlideshowState extends State<_LoginSlideshow> {
  static const _slideInterval = Duration(seconds: 5);
  static const _fadeDuration = Duration(milliseconds: 1000);

  Timer? _timer;
  int _currentIndex = 0;
  bool _preloadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_preloadStarted) return;
    _preloadStarted = true;
    unawaited(_preloadImagesAndStart());
  }

  Future<void> _preloadImagesAndStart() async {
    await Future.wait(
      widget.images.map(
        (imagePath) => precacheImage(AssetImage(imagePath), context),
      ),
    );
    if (!mounted || widget.images.length < 2) return;
    _timer = Timer.periodic(_slideInterval, (_) {
      if (!mounted) return;
      setState(() {
        _currentIndex = (_currentIndex + 1) % widget.images.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = AppMotion.reducedMotion(context);
    return AnimatedSwitcher(
      duration: reducedMotion ? AppMotion.instant : _fadeDuration,
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      layoutBuilder: (currentChild, previousChildren) => Stack(
        fit: StackFit.expand,
        children: [
          ...previousChildren,
          if (currentChild != null) currentChild,
        ],
      ),
      child: Image.asset(
        widget.images[_currentIndex],
        key: ValueKey<int>(_currentIndex),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => Container(
          color: const Color(0xFF0F4A3C),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.dark});
  final bool dark;

  void _showInfoDialog(BuildContext context, String title, String content) {
    final colors = semanticColors(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: colors.heroBackground,
          ),
        ),
        content: SizedBox(
          width: 460,
          child: Text(
            content,
            style: GoogleFonts.inter(fontSize: 13.5, height: 1.55),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: FilledButton.styleFrom(
              backgroundColor: colors.heroBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showInstallDialog(BuildContext context) {
    final colors = semanticColors(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.heroBackground.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.download_rounded,
                color: colors.heroBackground,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Install PalengkeGo',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: colors.heroBackground,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Access PalengkeGo quickly directly from your desktop or mobile device.',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: colors.secondaryText,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.hoverSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.subtleBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.desktop_windows_outlined,
                      size: 20,
                      color: colors.heroBackground,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Desktop Web App (PWA)',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: colors.primaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Click the install icon in your browser address bar (Chrome, Edge) to install the PalengkeGo Admin portal as a standalone desktop app.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              height: 1.4,
                              color: colors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.hoverSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.subtleBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.phone_android_outlined,
                      size: 20,
                      color: colors.heroBackground,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mobile Application',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: colors.primaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Stallholder and customer Android APK builds are distributed through the MEPO Operations Office.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              height: 1.4,
                              color: colors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: FilledButton.styleFrom(
              backgroundColor: colors.heroBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  Widget _navItem({
    required BuildContext context,
    required String label,
    required VoidCallback onTap,
    required AppSemanticColors colors,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: colors.accent.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: dark ? Colors.white : const Color(0xFF1E293B),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    final bg = dark ? colors.heroBackground : Colors.white;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPad = screenWidth < 400
        ? 10.0
        : (screenWidth < 768 ? 16.0 : 36.0);
    final isCompact = screenWidth < 850;

    return Container(
      height: 72,
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: horizontalPad),
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          bottom: BorderSide(
            color: dark ? colors.borderOnHero : colors.subtleBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          AppLogo(
            dark: dark,
            compact: screenWidth < 768,
            showTagline: screenWidth >= 900,
            showAdminBadge: screenWidth >= 440,
          ),
          const Spacer(),
          if (!isCompact)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _navItem(
                    context: context,
                    label: 'Home',
                    colors: colors,
                    onTap: () {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('You are on the PalengkeGo Admin Portal.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  _navItem(
                    context: context,
                    label: 'About',
                    colors: colors,
                    onTap: () => _showInfoDialog(
                      context,
                      'About PalengkeGo',
                      'PalengkeGo is the official digital market management platform for Naga City People’s Mall, developed in partnership with the Market Enterprise and Promotions Office (MEPO).\n\nIt streamlines stall holder operations, digital payments, market space management, and customer deliveries to bring the vibrant culture of the public market into the modern digital age.',
                    ),
                  ),
                  const SizedBox(width: 4),
                  _navItem(
                    context: context,
                    label: 'Contact',
                    colors: colors,
                    onTap: () => _showInfoDialog(
                      context,
                      'Contact MEPO Office',
                      'Market Enterprise and Promotions Office (MEPO)\nCity Government of Naga\n\n📍 Location: 2nd Floor, Naga City People’s Mall, Gen. Luna St., Naga City, Camarines Sur\n📞 Phone: (054) 881-2500 / local 1204\n📧 Email: mepo@nagacity.gov.ph\n🌐 Website: naga.gov.ph',
                    ),
                  ),
                  const SizedBox(width: 14),
                  FilledButton.icon(
                    onPressed: () => _showInstallDialog(context),
                    icon: const Icon(
                      Icons.download_rounded,
                      size: 17,
                      color: Colors.white,
                    ),
                    label: Text(
                      'Install App',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F4A3C),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            IconButton(
              tooltip: 'Install PalengkeGo',
              onPressed: () => _showInstallDialog(context),
              icon: const Icon(Icons.download_rounded),
              color: const Color(0xFF0F4A3C),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              tooltip: 'Portal Menu',
              onSelected: (value) {
                if (value == 'home') {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('You are on the PalengkeGo Admin Portal.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                } else if (value == 'about') {
                  _showInfoDialog(
                    context,
                    'About PalengkeGo',
                    'PalengkeGo is the official digital market management platform for Naga City People’s Mall, developed in partnership with the Market Enterprise and Promotions Office (MEPO).\n\nIt streamlines stall holder operations, digital payments, market space management, and customer deliveries to bring the vibrant culture of the public market into the modern digital age.',
                  );
                } else if (value == 'contact') {
                  _showInfoDialog(
                    context,
                    'Contact MEPO Office',
                    'Market Enterprise and Promotions Office (MEPO)\nCity Government of Naga\n\n📍 Location: 2nd Floor, Naga City People’s Mall, Gen. Luna St., Naga City, Camarines Sur\n📞 Phone: (054) 881-2500 / local 1204\n📧 Email: mepo@nagacity.gov.ph\n🌐 Website: naga.gov.ph',
                  );
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'home', child: Text('Home')),
                PopupMenuItem(value: 'about', child: Text('About')),
                PopupMenuItem(value: 'contact', child: Text('Contact')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  void _showInfo(BuildContext context, String title, String content) {
    final colors = semanticColors(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: colors.heroBackground,
          ),
        ),
        content: SizedBox(
          width: 440,
          child: Text(
            content,
            style: GoogleFonts.inter(fontSize: 13, height: 1.5),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: FilledButton.styleFrom(
              backgroundColor: colors.heroBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPad = screenWidth < 768 ? 16.0 : 36.0;

    return Container(
      height: 52,
      padding: EdgeInsets.symmetric(horizontal: horizontalPad),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: colors.subtleBorder),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/images/naga_city_seal.png',
                    width: 22,
                    height: 22,
                    fit: BoxFit.cover,
                    semanticLabel: 'City of Naga official seal',
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.verified_rounded,
                      size: 22,
                      color: colors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Naga City People’s Mall — Market Enterprise and Promotions Office (MEPO)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: colors.secondaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (MediaQuery.sizeOf(context).width > 680) ...[
            _footerLink(
              context,
              'Privacy Policy',
              () => _showInfo(
                context,
                'Privacy Policy',
                'PalengkeGo and the Market Enterprise and Promotions Office (MEPO) of Naga City are committed to protecting administrator and constituent privacy. Access to this portal is logged and monitored for security and compliance with the Data Privacy Act of 2012.',
              ),
            ),
            _footerLink(
              context,
              'Terms of Service',
              () => _showInfo(
                context,
                'Terms of Service',
                'This portal is strictly for authorized personnel of the Market Enterprise and Promotions Office (MEPO), City Government of Naga. Unauthorized access or misuse is subject to administrative sanctions and applicable Philippine laws.',
              ),
            ),
            _footerLink(
              context,
              'Support',
              () => _showInfo(
                context,
                'MEPO Administrator Support',
                'For account issues, credential resets, or technical support, please contact the MEPO IT Operations Desk at admin-support@nagacity.gov.ph or local trunkline 1204.',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _footerLink(BuildContext context, String label, VoidCallback onTap) {
    final colors = semanticColors(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        hoverColor: colors.selectedSurface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.secondaryText,
            ),
          ),
        ),
      ),
    );
  }
}

/// Honest mode indicator — demo (seeded data) vs live Firebase. Civic
/// clarity over decoration: a quiet pill, no glass, no gradients.
class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.firebase});

  final bool firebase;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppSemanticColors>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: firebase ? colors.successContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: firebase ? colors.success : Theme.of(context).dividerColor,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            firebase ? Icons.verified_outlined : Icons.science_outlined,
            size: 12,
            color: firebase ? colors.success : colors.mutedText,
          ),
          const SizedBox(width: 6),
          Text(
            firebase ? 'Live · City of Naga market data' : 'Demo · seeded data',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.02,
              color: firebase ? colors.success : colors.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}
