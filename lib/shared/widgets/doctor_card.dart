import 'package:flutter/material.dart';

import 'package:carelink/shared/models/provider_model.dart';

class ProviderCard extends StatelessWidget {
  final ProviderModel provider;

  const ProviderCard({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.teal.withOpacity(0.1),
          child: Icon(
            provider.role.toLowerCase() == 'doctor'
                ? Icons.medical_services
                : Icons.local_hospital,
            color: Colors.teal,
          ),
        ),

        title: Text(
          provider.fullName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),

        subtitle: Text(
          '${provider.specialization} • ⭐ ${provider.overallRating}',
        ),

        trailing: Icon(
          provider.isAvailable ? Icons.check_circle : Icons.cancel,
          color: provider.isAvailable ? Colors.green : Colors.red,
        ),
      ),
    );
  }
}