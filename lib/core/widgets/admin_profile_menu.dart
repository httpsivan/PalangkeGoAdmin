import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/auth_repository.dart';
import '../../features/admin_settings/admin_settings_page.dart';
import 'admin_widgets.dart';

class AdminProfileMenu extends ConsumerWidget {
  const AdminProfileMenu({super.key, required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(adminProfileProvider);
    final width = math.min(285.0, MediaQuery.sizeOf(context).width - 32);
    final colors = semanticColors(context);

    return MenuAnchor(
      useRootOverlay: true,
      crossAxisUnconstrained: false,
      reservedPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // The menu is aligned to the trigger's top-right by MenuStyle. Offset it
      // by the trigger height plus a small gap so it opens underneath the
      // profile button instead of covering it.
      alignmentOffset: const Offset(0, 56),
      style: MenuStyle(
        alignment: AlignmentDirectional.topEnd,
        backgroundColor: WidgetStatePropertyAll(colors.elevatedSurface),
        elevation: const WidgetStatePropertyAll(14),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        minimumSize: WidgetStatePropertyAll(Size(width, 0)),
        maximumSize: WidgetStatePropertyAll(Size(width, 520)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        side: WidgetStatePropertyAll(BorderSide(color: colors.subtleBorder)),
        shadowColor: WidgetStatePropertyAll(Colors.black.withValues(alpha: .14)),
      ),
      menuChildren: [
        SizedBox(
          width: width,
          child: _AdminProfileDropdown(
            profile: profile,
            onAccountSettings: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => const AdminSettingsDialog(),
            ),
            onLogout: () => _confirmLogout(context, ref),
          ),
        ),
      ],
      builder: (context, controller, child) => _AdminProfileTrigger(
        profile: profile,
        compact: compact,
        isOpen: controller.isOpen,
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'Are you sure you want to log out of the PalengkeGo Admin dashboard?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: semanticColors(dialogContext).danger,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authProvider.notifier).logout();
    if (context.mounted) context.go('/login');
  }
}

class _AdminProfileTrigger extends StatelessWidget {
  const _AdminProfileTrigger({
    required this.profile,
    required this.compact,
    required this.isOpen,
    required this.onTap,
  });

  final AdminProfile profile;
  final bool compact;
  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    return Tooltip(
      message: 'Admin profile menu',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Semantics(
          button: true,
          label: 'Admin profile menu',
          child: Material(
            color: isOpen ? colors.navigationHover : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              hoverColor: colors.navigationHover,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AvatarCircle(
                        name: profile.name,
                        size: 34,
                        imageBytes: profile.avatarBytes,
                      ),
                      if (!compact) ...[
                        const SizedBox(width: 9),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 158),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.heroForeground,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Administrator',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.heroMuted,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 7),
                      ],
                      AnimatedRotation(
                        turns: isOpen ? .5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: colors.heroMuted,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminProfileDropdown extends ConsumerWidget {
  const _AdminProfileDropdown({
    required this.profile,
    required this.onAccountSettings,
    required this.onLogout,
  });

  final AdminProfile profile;
  final VoidCallback onAccountSettings;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = semanticColors(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: colors.elevatedSurface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  AvatarCircle(
                    name: profile.name,
                    size: 38,
                    imageBytes: profile.avatarBytes,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          profile.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: .62),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor.withValues(alpha: .65)),
            _ProfileMenuItem(
              icon: Icons.history_rounded,
              label: 'Audit log',
              onTap: () {
                MenuController.maybeOf(context)?.close();
                context.go('/audit-log');
              },
            ),
            Divider(height: 1, color: theme.dividerColor.withValues(alpha: .65)),
            _ProfileMenuItem(
              icon: Icons.edit_outlined,
              label: 'Change profile',
              onTap: () {
                MenuController.maybeOf(context)?.close();
                onAccountSettings();
              },
            ),
            Divider(height: 1, color: theme.dividerColor.withValues(alpha: .65)),
            _ProfileMenuItem(
              icon: Icons.logout_rounded,
              label: 'Log out',
              foregroundColor: colors.danger,
              hoverColor: colors.dangerContainer.withValues(alpha: .55),
              onTap: () {
                MenuController.maybeOf(context)?.close();
                onLogout();
              },
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenuItem extends StatefulWidget {
  const _ProfileMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.foregroundColor,
    this.hoverColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? foregroundColor;
  final Color? hoverColor;

  @override
  State<_ProfileMenuItem> createState() => _ProfileMenuItemState();
}

class _ProfileMenuItemState extends State<_ProfileMenuItem> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = semanticColors(context);
    final foreground = widget.foregroundColor ?? theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovering = true),
        onExit: (_) => setState(() => hovering = false),
        child: Semantics(
          button: true,
          label: widget.label,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: hovering
                    ? widget.hoverColor ?? colors.hoverSurface
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(widget.icon, size: 18, color: foreground),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
