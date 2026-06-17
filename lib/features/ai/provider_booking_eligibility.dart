import 'package:carelink/shared/models/provider_model.dart';

class ProviderBookingEligibility {
  const ProviderBookingEligibility._();

  static bool canBook(ProviderModel provider) {
    final role = provider.role.trim().toLowerCase();
    return provider.userId.trim().isNotEmpty &&
        const {'doctor', 'nurse'}.contains(role) &&
        provider.isActive &&
        provider.isProfileComplete &&
        _hasUsefulValue(provider.fullName) &&
        _hasUsefulValue(provider.specialization) &&
        _hasUsefulValue(provider.serviceType) &&
        provider.consultationFee != null &&
        provider.consultationFee!.isFinite &&
        provider.consultationFee! > 0 &&
        provider.isAvailable &&
        provider.availableSlots.any(_isValidSlot);
  }

  static bool _isValidSlot(AvailabilitySlot slot) {
    final start = _clockMinutes(slot.startTime);
    final end = _clockMinutes(slot.endTime);
    return _hasUsefulValue(slot.day) &&
        start != null &&
        end != null &&
        end > start;
  }

  static int? _clockMinutes(String value) {
    final parts = value.trim().split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return hour * 60 + minute;
  }

  static bool _hasUsefulValue(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isNotEmpty &&
        !const {'null', 'unknown', 'n/a', '-'}.contains(normalized);
  }
}
