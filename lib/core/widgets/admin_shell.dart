import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/repositories/auth_repository.dart';
import '../animations/app_motion.dart';
import '../theme/theme_controller.dart';
import 'admin_widgets.dart';
import 'admin_profile_menu.dart';
import 'notification_panel.dart';

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child});
  final Widget child;
  static const navItems = [
    ('Overview', 'Overview', '/overview', Icons.home_outlined),
    ('Sales Reports', 'Sales Reports', '/sales-reports', Icons.bar_chart_rounded),
    ('Accounts', 'Accounts', '/accounts', Icons.people_outline_rounded),
    ('Stall Holder Application', 'Applications', '/applications', Icons.verified_user_outlined),
    ('Renewal', 'Renewal', '/renewal', Icons.autorenew_rounded),
    ('Complaint', 'Complaint', '/reports', Icons.report_problem_outlined),
    ('Announcements', 'Announcements', '/announcements', Icons.campaign_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = GoRouterState.of(context).uri.path;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: _MobileDrawer(current: current),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _TopNavigation(current: current),
            Expanded(
              child: RepaintBoundary(child: child),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopNavigation extends ConsumerStatefulWidget {
  const _TopNavigation({required this.current});
  final String current;

  @override
  ConsumerState<_TopNavigation> createState() => _TopNavigationState();
}

class _TopNavigationState extends ConsumerState<_TopNavigation> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 650;
    final horizontalPad =
        screenWidth < 1100 ? 12.0 : Responsive.horizontalPadding(context);

    return Container(
      height: 72,
      padding: EdgeInsets.symmetric(horizontal: horizontalPad),
      decoration: BoxDecoration(
        color: semanticColors(context).heroBackground,
        border: Border(
          bottom: BorderSide(color: semanticColors(context).borderOnHero),
        ),
      ),
      child: isMobile
          ? Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: const AppLogo(
                      dark: true,
                      compact: true,
                      showTagline: false,
                      showAdminBadge: false,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Builder(
                      builder: (context) => IconButton(
                        tooltip: 'Open navigation',
                        onPressed: () => Scaffold.of(context).openDrawer(),
                        icon:
                            const Icon(Icons.menu_rounded, color: Colors.white),
                      ),
                    ),
                    const _ThemeToggleButton(),
                    const SizedBox(width: 4),
                    const NotificationBell(),
                    const SizedBox(width: 6),
                    const AdminProfileMenu(compact: true),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                AppLogo(
                  dark: true,
                  compact: screenWidth < 1400,
                  showAdminBadge: screenWidth >= 1100,
                  showTagline: screenWidth >= 1600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Listener(
                    onPointerSignal: (pointerSignal) {
                      if (pointerSignal is PointerScrollEvent &&
                          _scrollController.hasClients) {
                        final target = (_scrollController.offset +
                                pointerSignal.scrollDelta.dy)
                            .clamp(
                                0.0,
                                _scrollController
                                    .position.maxScrollExtent);
                        _scrollController.jumpTo(target);
                      }
                    },
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(
                        dragDevices: {
                          ui.PointerDeviceKind.touch,
                          ui.PointerDeviceKind.mouse,
                          ui.PointerDeviceKind.trackpad,
                        },
                        scrollbars: false,
                      ),
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final item in AdminShell.navItems)
                              _NavItem(
                                label: item.$2,
                                tooltip: item.$1,
                                path: item.$3,
                                icon: item.$4,
                                active: widget.current == item.$3,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const _ThemeToggleButton(),
                    const SizedBox(width: 4),
                    const NotificationBell(),
                    const SizedBox(width: 8),
                    AdminProfileMenu(compact: screenWidth < 1400),
                  ],
                ),
              ],
            ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.path,
    required this.icon,
    required this.active,
    this.tooltip,
  });
  final String label;
  final String path;
  final IconData icon;
  final bool active;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    final activeColor =
        active ? colors.activeNavigationText : colors.heroMuted;

    final itemWidget = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          decoration: BoxDecoration(
            color: active ? colors.activeNavigation : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: InkWell(
            onTap: () {
              if (!active) {
                context.go(path);
              }
            },
            borderRadius: BorderRadius.circular(18),
            hoverColor: colors.navigationHover,
            splashColor: colors.activeNavigation.withValues(alpha: .16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: activeColor,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      color: activeColor,
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip != label) {
      return Tooltip(message: tooltip!, child: itemWidget);
    }
    return itemWidget;
  }
}

class _ThemeToggleButton extends ConsumerWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = semanticColors(context);
    return Tooltip(
      message: dark ? 'Switch to light mode' : 'Switch to dark mode',
      child: Material(
        color: colors.navigationControl,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: () => ref
              .read(themeModeProvider.notifier)
              .toggleResolved(Theme.of(context).brightness),
          hoverColor: colors.navigationHover,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 38,
            height: 38,
            child: AnimatedSwitcher(
              duration: AppMotion.duration(context, AppMotion.component),
              transitionBuilder: (child, animation) => RotationTransition(
                turns: Tween<double>(begin: -.12, end: 0).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(
                dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                key: ValueKey(dark),
                color: colors.heroForeground,
                size: 19,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showAccountSettingsDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (context) => const _AccountSettingsDialog(),
  );
}

class _AccountSettingsDialog extends ConsumerStatefulWidget {
  const _AccountSettingsDialog();

  @override
  ConsumerState<_AccountSettingsDialog> createState() =>
      _AccountSettingsDialogState();
}

class _AccountSettingsDialogState
    extends ConsumerState<_AccountSettingsDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(adminProfileProvider);
    _nameController = TextEditingController(text: profile.name);
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final password = _passwordController.text;
    if (name.isEmpty) {
      setState(() => _error = 'Enter your name.');
      return;
    }
    if (password.isNotEmpty && password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    if (password != _confirmPasswordController.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    await ref.read(adminProfileProvider.notifier).updateProfile(
          name: name,
          password: password.isEmpty ? null : password,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account settings updated.')),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Account settings'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Change password',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordController,
                obscureText: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'New password',
                  hintText: 'Leave blank to keep current password',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                onSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                  prefixIcon: Icon(Icons.lock_reset_outlined),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: semanticColors(context).danger,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save changes'),
          ),
        ],
      );
}

void showNotificationsDialog(BuildContext context) {
  showBlurredDialog<void>(
    context,
    (context) => const _NotificationsDialog(),
  );
}

class _NotificationsDialog extends StatelessWidget {
  const _NotificationsDialog();

  @override
  Widget build(BuildContext context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: semanticColors(context).successContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.campaign_outlined,
                        color: semanticColors(context).success,
                      ),
                      const SizedBox(width: 11),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'New Market Guidelines',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Updated safety protocols are available for the upcoming weekend market.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _MobileDrawer extends ConsumerWidget {
  const _MobileDrawer({required this.current});
  final String current;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Drawer(
        backgroundColor: semanticColors(context).elevatedSurface,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: AppLogo(compact: true, showAdminBadge: true),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close navigation',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(),
              for (final item in AdminShell.navItems)
                ListTile(
                  leading: Icon(item.$4),
                  title: Text(item.$1),
                  selected: current == item.$3,
                  selectedColor: semanticColors(context).heroBackground,
                  selectedTileColor: semanticColors(context).successContainer,
                  onTap: () {
                    Navigator.pop(context);
                    if (current != item.$3) {
                      context.go(item.$3);
                    }
                  },
                ),
              const Spacer(),
            ],
          ),
        ),
      );
}

void showThemeSelector(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Appearance',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          for (final mode in ThemeMode.values)
            // ignore: deprecated_member_use
            RadioListTile<ThemeMode>(
              value: mode,
              // ignore: deprecated_member_use
              groupValue: ref.read(themeModeProvider),
              title: Text(mode.name),
              // ignore: deprecated_member_use
              onChanged: (value) {
                if (value != null) {
                  ref.read(themeModeProvider.notifier).setMode(value);
                  Navigator.pop(context);
                }
              },
            ),
        ],
      ),
    ),
  );
}

Future<T?> showBlurredDialog<T>(
  BuildContext context,
  WidgetBuilder builder, {
  bool barrierDismissible = true,
}) =>
    showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Close dialog',
      barrierColor: semanticColors(context).overlayScrim,
      transitionDuration: AppMotion.duration(context, AppMotion.dialog),
      pageBuilder: (context, animation, secondaryAnimation) =>
          RepaintBoundary(child: builder(context)),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: AppMotion.easeOut,
        );
        if (AppMotion.reducedMotion(context)) {
          return FadeTransition(opacity: curved, child: child);
        }
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: .96, end: 1).animate(curved),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, .015),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );
