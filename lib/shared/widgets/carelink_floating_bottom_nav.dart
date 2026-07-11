import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/locale_controller.dart';

class CarelinkFloatingNavItem {
  const CarelinkFloatingNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class CarelinkFloatingBottomNav extends StatelessWidget {
  const CarelinkFloatingBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<CarelinkFloatingNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final compact = MediaQuery.sizeOf(context).width < 360;
    final navHeight = compact ? 62.0 : 68.0;

    return SafeArea(
      top: false,
      child: Container(
        height: navHeight,
        margin: EdgeInsets.fromLTRB(compact ? 8 : 16, 0, compact ? 8 : 16, 12),
        decoration: BoxDecoration(
          color: p.isDark ? p.navBackground : Colors.white,
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final count = items.length;
            final itemWidth = constraints.maxWidth / count;
            final visualIndex = localeController.isArabic
                ? count - 1 - currentIndex
                : currentIndex;
            final pillWidth = itemWidth * 0.75;
            final pillHeight = compact ? 44.0 : 48.0;
            final leftOffset =
                (visualIndex * itemWidth) + ((itemWidth - pillWidth) / 2);

            return Stack(
              alignment: Alignment.center,
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  left: leftOffset,
                  top: (navHeight - pillHeight) / 2,
                  width: pillWidth,
                  height: pillHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFF0F766E,
                      ).withValues(alpha: p.isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
                Row(
                  children: List.generate(items.length, (index) {
                    return Expanded(
                      child: _CarelinkFloatingNavButton(
                        item: items[index],
                        selected: index == currentIndex,
                        palette: p,
                        onTap: () => onTap(index),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CarelinkFloatingNavButton extends StatefulWidget {
  const _CarelinkFloatingNavButton({
    required this.item,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final CarelinkFloatingNavItem item;
  final bool selected;
  final CarelinkPalette palette;
  final VoidCallback onTap;

  @override
  State<_CarelinkFloatingNavButton> createState() =>
      _CarelinkFloatingNavButtonState();
}

class _CarelinkFloatingNavButtonState
    extends State<_CarelinkFloatingNavButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.selected
        ? const Color(0xFF0F766E)
        : widget.palette.isDark
        ? widget.palette.navUnselected
        : const Color(0xFF94A3B8);

    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : (widget.selected ? 1.04 : 1),
        duration: const Duration(milliseconds: 190),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(22),
          splashColor: AppColors.primary.withValues(alpha: 0.10),
          highlightColor: AppColors.primary.withValues(alpha: 0.06),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: Icon(
                    widget.selected ? widget.item.activeIcon : widget.item.icon,
                    key: ValueKey('${widget.item.label}-${widget.selected}'),
                    size: widget.selected ? 25 : 22,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    color: color,
                    fontSize: widget.selected ? 11.5 : 10.5,
                    fontWeight: widget.selected
                        ? FontWeight.w900
                        : FontWeight.w600,
                  ),
                  child: Text(
                    widget.item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
