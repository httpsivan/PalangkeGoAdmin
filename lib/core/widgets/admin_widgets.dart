import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/app_models.dart';
import '../animations/animated_widgets.dart';
import '../animations/app_motion.dart';
import '../theme/category_colors.dart';
import '../theme/theme_extensions.dart';

export '../theme/category_colors.dart';

AppSemanticColors semanticColors(BuildContext context) =>
    Theme.of(context).extension<AppSemanticColors>()!;

/// Responsive breakpoints and layout helpers.
/// - Phone: width < 600
/// - Tablet: 600 <= width < 1024
/// - Laptop: 1024 <= width < 1440
/// - Computer: width >= 1440
class Responsive {
  static bool isPhone(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= 600 && w < 1024;
  }

  static bool isLaptop(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= 1024 && w < 1440;
  }

  static bool isComputer(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 1440;

  static EdgeInsets pagePadding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < 600) return const EdgeInsets.fromLTRB(16, 16, 16, 24);
    if (w < 1024) return const EdgeInsets.fromLTRB(24, 20, 24, 28);
    return const EdgeInsets.fromLTRB(36, 26, 36, 36);
  }

  static double horizontalPadding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < 600) return 16.0;
    if (w < 1024) return 24.0;
    return 36.0;
  }
}

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.compact = false,
    this.showTagline = true,
    this.showAdminBadge = false,
    this.dark = false,
  });

  final bool compact;
  final bool showTagline;
  final bool showAdminBadge;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    final primaryTextColor = dark
        ? Colors.white
        : (Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : const Color(0xFF1E293B));
    final accentColor = dark ? const Color(0xFF34D399) : colors.accent;

    final basketIcon = Image.asset(
      'assets/images/market_basket.png',
      width: compact ? 44 : 72,
      height: compact ? 44 : 72,
      fit: BoxFit.contain,
      semanticLabel: 'PalengkeGo Market Basket',
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.shopping_basket_rounded,
        size: compact ? 36 : 48,
        color: accentColor,
      ),
    );

    final titleText = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Palengke',
            style: GoogleFonts.plusJakartaSans(
              color: primaryTextColor,
              fontSize: compact ? 19 : 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          TextSpan(
            text: 'Go',
            style: GoogleFonts.plusJakartaSans(
              color: accentColor,
              fontSize: compact ? 19 : 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          if (showAdminBadge) ...[
            WidgetSpan(
              child: Container(
                margin: const EdgeInsets.only(left: 8, bottom: 2),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'ADMIN',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: compact ? 9 : 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    final taglineText = Text(
      'SKIP THE ROAM, ORDER FROM HOME',
      style: GoogleFonts.inter(
        color: dark
            ? Colors.white70
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        fontSize: compact ? 7.5 : 9.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      ),
    );

    return Semantics(
      label: 'PalengkeGo - Skip the Roam, Order from Home',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          basketIcon,
          SizedBox(width: compact ? 10 : 18),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleText,
                if (showTagline && !compact) ...[
                  const SizedBox(height: 2),
                  taglineText,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AvatarCircle extends StatelessWidget {
  const AvatarCircle({
    super.key,
    required this.name,
    this.size = 36,
    this.image,
    this.imageBytes,
  }) : assert(image == null || imageBytes == null);
  final String name;
  final double size;
  final ImageProvider<Object>? image;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((word) => word[0])
        .join()
        .toUpperCase();
    final resolvedImage =
        image ?? (imageBytes == null ? null : MemoryImage(imageBytes!));
    return CircleAvatar(
      radius: size / 2,
      backgroundColor:
          isDark ? colors.activeNavigation : colors.successContainer,
      backgroundImage: resolvedImage,
      child: resolvedImage == null
          ? Text(
              initials,
              style: TextStyle(
                color: isDark
                    ? colors.activeNavigationText
                    : colors.heroBackground,
                fontSize: size * .32,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.metrics = const [],
    this.tabs,
    this.trailing,
  });
  final String title;
  final String subtitle;
  final List<MetricCardData> metrics;
  final Widget? tabs;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    final isCompact = MediaQuery.sizeOf(context).width < 900;
    final horizontalPad = Responsive.horizontalPadding(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        horizontalPad,
        isCompact ? 18 : 24,
        horizontalPad,
        isCompact ? 16 : 20,
      ),
      decoration: BoxDecoration(
        color: colors.heroBackground,
        border: Border(
          bottom: BorderSide(color: colors.borderOnHero),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCompact) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: colors.heroForeground,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: colors.heroMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: trailing!,
                  ),
                ],
              ],
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          color: colors.heroForeground,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          color: colors.heroMuted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 16),
                  trailing!,
                ],
              ],
            ),
          ],
          if (tabs != null) ...[const SizedBox(height: 20), tabs!],
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: 20),
            PageHeaderMetricRibbon(metrics: metrics),
          ],
        ],
      ),
    );
  }
}

class PageHeaderMetricRibbon extends StatelessWidget {
  const PageHeaderMetricRibbon({super.key, required this.metrics});
  final List<MetricCardData> metrics;

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.subtleBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canFitSingleRow =
              constraints.maxWidth >= (metrics.length * 170).clamp(750, 1100);

          if (!canFitSingleRow) {
            final int crossAxisCount;
            if (constraints.maxWidth >= 720) {
              crossAxisCount = metrics.length > 4 ? 3 : 2;
            } else if (constraints.maxWidth >= 440) {
              crossAxisCount = 2;
            } else {
              crossAxisCount = 1;
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(8),
              itemCount: metrics.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                mainAxisExtent: 68,
              ),
              itemBuilder: (context, i) =>
                  PageHeaderMetricTile(data: metrics[i]),
            );
          }
          return IntrinsicHeight(
            child: Row(
              children: [
                for (int i = 0; i < metrics.length; i++) ...[
                  Expanded(
                    child: PageHeaderMetricTile(data: metrics[i]),
                  ),
                  if (i < metrics.length - 1)
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: colors.subtleBorder,
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class PageHeaderMetricTile extends StatefulWidget {
  const PageHeaderMetricTile({super.key, required this.data});
  final MetricCardData data;

  @override
  State<PageHeaderMetricTile> createState() => _PageHeaderMetricTileState();
}

class _PageHeaderMetricTileState extends State<PageHeaderMetricTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    final data = widget.data;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: data.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Stack(
            children: [
              Row(
                children: [
                  Icon(
                    data.icon,
                    size: 18,
                    color: data.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          data.label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: colors.secondaryText,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.7,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: AnimatedCounter(
                            value: data.value,
                            style: data.valueStyle ??
                                GoogleFonts.plusJakartaSans(
                                  color: colors.primaryText,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (data.onTap != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    transform:
                        Matrix4.translationValues(_isHovered ? 2.0 : 0.0, 0, 0),
                    child: Icon(
                      Icons.arrow_outward_rounded,
                      size: 12,
                      color: _isHovered
                          ? data.accent
                          : colors.secondaryText.withValues(alpha: 0.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class MetricCardData {
  const MetricCardData({
    required this.value,
    required this.label,
    required this.icon,
    required this.accent,
    this.onTap,
    this.valueStyle,
  });
  final String value;
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
  final TextStyle? valueStyle;
}

class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.data, this.compact = false});
  final MetricCardData data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    final icon = Container(
      width: compact ? 33 : 34,
      height: compact ? 33 : 34,
      decoration: BoxDecoration(
        color: data.accent.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(data.icon, color: data.accent, size: 18),
    );
    final Widget? arrow = data.onTap == null
        ? null
        : compact
            ? IconButton(
                tooltip: 'Open',
                onPressed: data.onTap,
                icon: Icon(
                  Icons.arrow_outward_rounded,
                  size: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: .72),
                ),
              )
            : InkWell(
                onTap: data.onTap,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.subtleBorder),
                  ),
                  child: Icon(
                    Icons.arrow_outward_rounded,
                    size: 15,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: .72),
                  ),
                ),
              );
    final valueStyle = GoogleFonts.montserrat(
      color: Theme.of(context).colorScheme.onSurface,
      fontSize: compact ? 21 : 26,
      fontWeight: FontWeight.w800,
    ).merge(data.valueStyle);
    final value = AnimatedCounter(value: data.value, style: valueStyle);
    final label = Text(
      data.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .64),
        fontSize: compact ? 11 : 11.5,
      ),
    );
    return Semantics(
      button: data.onTap != null,
      label: '${data.label}: ${data.value}',
      child: AnimatedHoverContainer(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        child: Container(
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 14)
              : const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: BorderRadius.circular(compact ? 12 : 14),
            border: Border.all(color: colors.subtleBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: compact
              ? Row(
                  children: [
                    icon,
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: value,
                          ),
                          const SizedBox(height: 4),
                          Flexible(child: label),
                        ],
                      ),
                    ),
                    if (arrow != null) arrow,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        icon,
                        const Spacer(),
                        if (arrow != null) arrow,
                      ],
                    ),
                    const Spacer(),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: value,
                    ),
                    const SizedBox(height: 3),
                    Flexible(child: label),
                  ],
                ),
        ),
      ),
    );
  }
}

enum BadgeKind { success, warning, danger, info, purple, neutral }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.kind = BadgeKind.neutral,
    this.icon,
  });
  final String label;
  final BadgeKind kind;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    final pair = switch (kind) {
      BadgeKind.success => (colors.success, colors.successContainer),
      BadgeKind.warning => (colors.warning, colors.warningContainer),
      BadgeKind.danger => (colors.danger, colors.dangerContainer),
      BadgeKind.info => (colors.info, colors.infoContainer),
      BadgeKind.purple => Theme.of(context).brightness == Brightness.dark
          ? (const Color(0xFFC2A5FF), const Color(0xFF34265C))
          : (const Color(0xFF8B5CF6), const Color(0xFFEDE9FE)),
      BadgeKind.neutral => (colors.mutedText, colors.hoverSurface),
    };
    return Semantics(
      label: 'Status: $label',
      container: true,
      child: AnimatedSwitcher(
        duration: AppMotion.duration(context, AppMotion.component),
        switchInCurve: AppMotion.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: .95, end: 1).animate(animation),
            child: child,
          ),
        ),
        child: Container(
          key: ValueKey('$label-${kind.name}'),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: pair.$2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: pair.$1.withValues(alpha: .12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 11, color: pair.$1),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: pair.$1,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Toolbar extends StatelessWidget {
  const Toolbar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onClear,
    this.searchHint = 'Search by name, email, or application ID...',
    this.trailing = const [],
    this.emphasized = true,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final String searchHint;
  final List<Widget> trailing;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final search = SizedBox(
      height: 38,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(
          fontSize: 12,
          color: semanticColors(context).primaryText,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor:
              semanticColors(context).hoverSurface.withValues(alpha: 0.95),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 18,
            color: semanticColors(context).secondaryText,
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 36, minHeight: 36),
          hintText: searchHint,
          hintStyle: TextStyle(
            color: semanticColors(context).mutedText,
            fontSize: 12,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  splashRadius: 16,
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                    onClear?.call();
                  },
                  icon: const Icon(Icons.close_rounded, size: 16),
                ),
          enabledBorder: emphasized
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: BorderSide(
                      color: semanticColors(context)
                          .secondaryText
                          .withValues(alpha: 0.45)),
                )
              : null,
          focusedBorder: emphasized
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: BorderSide(color: semanticColors(context).accent),
                )
              : null,
        ),
      ),
    );
    final controls = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...trailing,
        if (onClear != null)
          AnimatedButtonFeedback(
            child: OutlinedButton.icon(
              onPressed: onClear,
              style: OutlinedButton.styleFrom(
                foregroundColor: emphasized
                    ? semanticColors(context).primaryText
                    : semanticColors(context).secondaryText,
                backgroundColor: semanticColors(context).hoverSurface,
                side: BorderSide(
                    color: emphasized
                        ? semanticColors(context)
                            .secondaryText
                            .withValues(alpha: 0.45)
                        : semanticColors(context).subtleBorder),
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              icon: const Icon(Icons.restart_alt_rounded, size: 14),
              label: const Text(
                'Clear Filters',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: semanticColors(context).subtleBorder),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 750;
          final searchWidget = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: search,
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchWidget,
                if (controls.children.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  controls,
                ],
              ],
            );
          }

          return Row(
            children: [
              searchWidget,
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: controls,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class FilterButton extends StatelessWidget {
  const FilterButton({
    super.key,
    required this.label,
    this.icon = Icons.keyboard_arrow_down_rounded,
    this.onTap,
    this.isActive = true,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    final isCategory = CategoryColors.isCategory(label);
    final categoryStyle = isCategory ? CategoryColors.get(label) : null;

    final effectiveBackground = categoryStyle?.background ??
        (isActive
            ? colors.hoverSurface.withValues(alpha: 0.95)
            : colors.hoverSurface);
    final effectiveBorder = categoryStyle?.border ??
        (isActive
            ? colors.secondaryText.withValues(alpha: 0.45)
            : colors.subtleBorder);

    return AnimatedButtonFeedback(
      enabled: onTap != null,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: categoryStyle?.text ??
              (isActive ? colors.primaryText : colors.secondaryText),
          side: BorderSide(color: effectiveBorder),
          backgroundColor: effectiveBackground,
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCategory) ...[
              CategoryDot(category: label, size: 7),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: (isCategory || isActive)
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: categoryStyle?.text ??
                    (isActive ? colors.primaryText : colors.secondaryText),
              ),
            ),
            const SizedBox(width: 5),
            Icon(
              icon,
              size: 15,
              color: categoryStyle?.text ??
                  (isActive ? colors.primaryText : colors.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}

class FilterMenuButton extends StatelessWidget {
  const FilterMenuButton({
    super.key,
    required this.label,
    required this.values,
    required this.onSelected,
    this.icon = Icons.keyboard_arrow_down_rounded,
    this.alwaysActive = true,
  });

  final String label;
  final List<String> values;
  final ValueChanged<String> onSelected;
  final IconData icon;
  final bool alwaysActive;

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    final isDefault = label.startsWith('All ') ||
        label == 'Newest First' ||
        label == 'Stall Category' ||
        label == 'Account Type';
    final isActive = alwaysActive || (!isDefault && values.contains(label));

    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.cardBackground),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: colors.subtleBorder),
          ),
        ),
        elevation: const WidgetStatePropertyAll(6),
        shadowColor:
            WidgetStatePropertyAll(Colors.black.withValues(alpha: 0.08)),
      ),
      menuChildren: [
        for (final value in values)
          MenuItemButton(
            onPressed: () => onSelected(value),
            style: MenuItemButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 160),
              child: Row(
                children: [
                  if (CategoryColors.isCategory(value)) ...[
                    CategoryDot(category: value, size: 7.5),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 12,
                        color: value == label
                            ? (CategoryColors.isCategory(value)
                                ? CategoryColors.get(value).text
                                : colors.accent)
                            : (CategoryColors.isCategory(value)
                                ? CategoryColors.get(value).text
                                : colors.primaryText),
                        fontWeight: value == label
                            ? FontWeight.w700
                            : (CategoryColors.isCategory(value)
                                ? FontWeight.w600
                                : FontWeight.normal),
                      ),
                    ),
                  ),
                  if (value == label) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: CategoryColors.isCategory(value)
                          ? CategoryColors.get(value).text
                          : colors.accent,
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
      builder: (context, controller, child) => FilterButton(
        label: label,
        icon: icon,
        isActive: isActive,
        onTap: () {
          if (controller.isOpen) {
            controller.close();
          } else {
            controller.open();
          }
        },
      ),
    );
  }
}

class ExportButton extends StatelessWidget {
  const ExportButton({
    super.key,
    this.label = 'Export',
    this.icon = Icons.download_rounded,
    this.onTap,
    this.onExportPdf,
    this.onExportExcel,
    this.tooltip = 'Export data',
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onExportPdf;
  final VoidCallback? onExportExcel;
  final String tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    final hasMenu = onExportPdf != null || onExportExcel != null;
    final isEnabled = hasMenu || onTap != null;

    final effectiveFg = foregroundColor ??
        (isEnabled ? colors.primaryText : colors.disabledText);
    final effectiveBg = backgroundColor ?? colors.hoverSurface;
    final effectiveBorder = borderColor ??
        (isEnabled
            ? colors.secondaryText.withValues(alpha: 0.45)
            : colors.subtleBorder);

    final buttonChild = OutlinedButton(
      onPressed: isEnabled ? (hasMenu ? null : onTap) : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: effectiveFg,
        backgroundColor: effectiveBg,
        disabledForegroundColor: effectiveFg,
        disabledBackgroundColor: effectiveBg,
        side: BorderSide(color: effectiveBorder),
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 11),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: effectiveFg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: effectiveFg,
            ),
          ),
          if (hasMenu) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 15,
              color: effectiveFg.withValues(alpha: 0.8),
            ),
          ],
        ],
      ),
    );

    if (hasMenu) {
      return Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: PopupMenuButton<String>(
          tooltip: tooltip,
          enabled: isEnabled,
          offset: const Offset(0, 42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: colors.subtleBorder),
          ),
          color: Colors.white,
          elevation: 6,
          onSelected: (action) {
            if (action == 'pdf') {
              onExportPdf?.call();
            } else if (action == 'excel') {
              onExportExcel?.call();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'pdf',
              height: 40,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 16,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Export PDF',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: colors.primaryText,
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(height: 1),
            PopupMenuItem(
              value: 'excel',
              height: 40,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.table_chart_outlined,
                      size: 16,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Export Excel',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: colors.primaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
          child: IgnorePointer(
            child: buttonChild,
          ),
        ),
      );
    }

    return Tooltip(
      message: tooltip,
      child: AnimatedButtonFeedback(
        enabled: isEnabled,
        child: buttonChild,
      ),
    );
  }
}

class TableActionIconButton extends StatelessWidget {
  const TableActionIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.size = 32,
    this.iconSize = 15,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: colors.hoverSurface,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          hoverColor: colors.selectedSurface,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.subtleBorder),
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: color ?? colors.secondaryText,
            ),
          ),
        ),
      ),
    );
  }
}

class TableActionReviewButton extends StatelessWidget {
  const TableActionReviewButton({
    super.key,
    required this.onPressed,
    this.label = 'Review',
    this.tooltip = 'Review application',
  });

  final VoidCallback? onPressed;
  final String label;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    return Tooltip(
      message: tooltip,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.accent,
          backgroundColor: colors.hoverSurface,
          side: BorderSide(color: colors.subtleBorder),
          minimumSize: const Size(0, 30),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class DataPanel extends StatelessWidget {
  const DataPanel({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.headerAction,
    this.titleStyle,
  });
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? headerAction;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.elevatedSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.subtleBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow =
                    constraints.maxWidth < 520 && headerAction != null;
                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: titleStyle ??
                            TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: .58),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: headerAction!,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: titleStyle ??
                                TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              subtitle!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: .58),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (headerAction != null) headerAction!,
                  ],
                );
              },
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class ApplicationStatusBadge extends StatelessWidget {
  const ApplicationStatusBadge({super.key, required this.status});
  final ApplicationStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    final label = switch (status) {
      ApplicationStatus.verified => 'Verified',
      ApplicationStatus.reviewing => 'Pending',
      ApplicationStatus.invalidDocs => 'Re-Upload Requested',
      ApplicationStatus.rejected => 'Rejected',
    };
    final kind = switch (status) {
      ApplicationStatus.verified => BadgeKind.success,
      ApplicationStatus.reviewing => BadgeKind.info,
      ApplicationStatus.invalidDocs => BadgeKind.warning,
      ApplicationStatus.rejected => BadgeKind.danger,
    };
    final icon = switch (status) {
      ApplicationStatus.verified => Icons.verified_rounded,
      ApplicationStatus.reviewing => Icons.pie_chart_outline_rounded,
      ApplicationStatus.invalidDocs => Icons.document_scanner_outlined,
      ApplicationStatus.rejected => Icons.cancel_outlined,
    };
    final color = switch (kind) {
      BadgeKind.success => colors.success,
      BadgeKind.info => colors.info,
      BadgeKind.danger => colors.danger,
      _ => colors.mutedText,
    };
    return AnimatedSwitcher(
      duration: AppMotion.duration(context, AppMotion.component),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: .95, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: Row(
        key: ValueKey(status),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScrollableDataTable extends StatelessWidget {
  const ScrollableDataTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.verticalController,
    this.columnSpacing = 18,
    this.rowHeight = 68,
    this.minWidth = 0,
    this.emptyState = const EmptyState(),
    this.horizontalScroll = true,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final ScrollController verticalController;
  final double columnSpacing;
  final double rowHeight;
  final double minWidth;
  final Widget emptyState;
  final bool horizontalScroll;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final colors = semanticColors(context);
            final tableWidth = constraints.maxWidth > minWidth
                ? constraints.maxWidth
                : minWidth;

            Widget table({
              required List<DataRow> tableRows,
              required double headingHeight,
            }) =>
                ConstrainedBox(
                  constraints: BoxConstraints(minWidth: tableWidth),
                  child: DataTable(
                    showCheckboxColumn: false,
                    headingRowColor: WidgetStatePropertyAll(
                      colors.tableHeader,
                    ),
                    headingTextStyle: GoogleFonts.inter(
                      color: colors.secondaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                    dataTextStyle: GoogleFonts.inter(
                      color: colors.primaryText,
                      fontSize: 13,
                    ),
                    headingRowHeight: headingHeight,
                    dataRowMinHeight: rowHeight,
                    dataRowMaxHeight: rowHeight,
                    columnSpacing: columnSpacing,
                    columns: columns,
                    rows: tableRows,
                    dataRowColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.hovered)) {
                        return colors.hoverSurface;
                      }
                      return colors.cardBackground;
                    }),
                  ),
                );

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: tableWidth),
                child: AnimatedSwitcher(
                  duration: AppMotion.duration(context, AppMotion.component),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                  child: rows.isEmpty
                      ? KeyedSubtree(
                          key: const ValueKey('empty'),
                          child: emptyState,
                        )
                      : KeyedSubtree(
                          key: const ValueKey('rows'),
                          child: table(tableRows: rows, headingHeight: 48),
                        ),
                ),
              ),
            );
          },
        ),
      );
}

class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.total,
    required this.start,
    required this.end,
    required this.page,
    required this.pageCount,
    required this.onPageChanged,
    this.showSummary = false,
  });
  final int total;
  final int start;
  final int end;
  final int page;
  final int pageCount;
  final ValueChanged<int> onPageChanged;
  final bool showSummary;
  @override
  Widget build(BuildContext context) {
    if (total <= 0 || pageCount <= 0) {
      return const SizedBox.shrink();
    }

    final int safePage = page.clamp(0, pageCount - 1);
    final pagination = Wrap(
      spacing: 5,
      children: [
        _button(
          context,
          Icons.chevron_left_rounded,
          safePage > 0 ? () => onPageChanged(safePage - 1) : null,
        ),
        if (pageCount <= 5)
          for (var i = 0; i < pageCount; i++)
            _button(
              context,
              i + 1,
              () => onPageChanged(i),
              active: i == safePage,
            )
        else ...[
          for (var i = 0; i < 3; i++)
            _button(
              context,
              i + 1,
              () => onPageChanged(i),
              active: i == safePage,
            ),
          _button(context, '...', null),
          _button(
            context,
            pageCount,
            () => onPageChanged(pageCount - 1),
            active: safePage == pageCount - 1,
          ),
        ],
        _button(
          context,
          Icons.chevron_right_rounded,
          safePage < pageCount - 1 ? () => onPageChanged(safePage + 1) : null,
        ),
      ],
    );

    final summary = Text(
      'Showing $start to $end of $total results',
      style: TextStyle(
        fontSize: 10.5,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .62),
      ),
    );

    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (!showSummary) {
            return Align(
              alignment: Alignment.centerRight,
              child: pagination,
            );
          }

          if (constraints.maxWidth < 700) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                summary,
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: pagination,
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: summary),
              pagination,
            ],
          );
        },
      ),
    );
  }

  Widget _button(
    BuildContext context,
    Object label,
    VoidCallback? onTap, {
    bool active = false,
  }) {
    final colors = semanticColors(context);
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = active
        ? colorScheme.onPrimary
        : onTap == null
            ? colors.disabledText
            : colors.primaryText;

    return Material(
      color: active ? colorScheme.primary : colors.cardBackground,
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        hoverColor: active ? Colors.transparent : colors.hoverSurface,
        splashColor: active ? Colors.transparent : null,
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: active ? null : Border.all(color: colors.subtleBorder),
          ),
          child: label is IconData
              ? Icon(
                  label,
                  size: 16,
                  color: foreground,
                )
              : Text(
                  '$label',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: foreground,
                  ),
                ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.message = 'No results found',
    this.description,
    this.icon,
    this.action,
  });

  final String message;
  final String? description;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = semanticColors(context);
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeSlideIn(
              child: Icon(
                icon ?? Icons.search_off_rounded,
                size: 32,
                color: colors.mutedText,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                color: colors.secondaryText,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description ?? 'Try changing your search or filter selection.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.mutedText,
                fontSize: 11.5,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                letterSpacing: .6,
                fontWeight: FontWeight.w800,
                color: semanticColors(context).secondaryText,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      );
}

void copyToClipboard(BuildContext context, String value) {
  Clipboard.setData(ClipboardData(text: value));
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
}
