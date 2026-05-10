import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/features/auth/registration/getx/carelink_registration_models.dart';

/// Three-way role control — same chip idea as login social pills (border + fill).
class RoleSelector extends StatelessWidget {
  const RoleSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final CarelinkRegistrationRole value;
  final ValueChanged<CarelinkRegistrationRole> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('auth.iAmA'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: p.inkMuted,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final r in CarelinkRegistrationRole.values) ...[
              Expanded(
                child: _RoleChip(
                  role: r,
                  selected: value == r,
                  onTap: () => onChanged(r),
                ),
              ),
              if (r != CarelinkRegistrationRole.values.last) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          context.tr('auth.roleLicenseNote'),
          style: TextStyle(
            fontSize: 11.5,
            color: p.inkMuted,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final CarelinkRegistrationRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : p.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.border.withValues(alpha: 0.85),
              width: selected ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            role.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}
