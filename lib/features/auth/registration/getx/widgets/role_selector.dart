import 'package:flutter/material.dart';
import '../carelink_registration_models.dart';

class RoleSelector extends StatelessWidget {
  const RoleSelector({super.key, required this.value, required this.onChanged});

  final CarelinkRegistrationRole value;
  final ValueChanged<CarelinkRegistrationRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ChoiceChip(
          label: const Text('Patient'),
          selected: value == CarelinkRegistrationRole.patient,
          onSelected: (_) => onChanged(CarelinkRegistrationRole.patient),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('Nurse'),
          selected: value == CarelinkRegistrationRole.nurse,
          onSelected: (_) => onChanged(CarelinkRegistrationRole.nurse),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('Doctor'),
          selected: value == CarelinkRegistrationRole.doctor,
          onSelected: (_) => onChanged(CarelinkRegistrationRole.doctor),
        ),
      ],
    );
  }
}
