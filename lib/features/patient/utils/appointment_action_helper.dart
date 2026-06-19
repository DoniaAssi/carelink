import 'package:flutter/material.dart';

enum AppointmentActionType {
  changeAppointment,
  requestReschedule,
  requestPending,
  bookAgain,
  hidden,
}

class AppointmentActionState {
  final AppointmentActionType type;
  final bool isEnabled;
  final String? helperTextEn;
  final String? helperTextAr;

  const AppointmentActionState({
    required this.type,
    this.isEnabled = true,
    this.helperTextEn,
    this.helperTextAr,
  });
}

class AppointmentActionHelper {
  static AppointmentActionState getActionState({
    required String status,
    required String paymentStatus,
    DateTime? requestedRescheduleAt,
  }) {
    final s = status.toLowerCase().trim();
    final p = paymentStatus.toLowerCase().trim();

    if (s == 'unpaid' ||
        s == 'awaiting_payment' ||
        s == 'pending_payment' ||
        s == 'payment_pending' ||
        s == 'draft' ||
        p == 'unpaid' ||
        p == 'pending_payment' ||
        p == 'payment_pending' ||
        p == 'pending') {
      return const AppointmentActionState(
        type: AppointmentActionType.hidden,
      );
    }

    if (s == 'reschedule_requested') {
      return AppointmentActionState(
        type: AppointmentActionType.requestPending,
        isEnabled: false,
        helperTextEn: requestedRescheduleAt != null
            ? 'Reschedule request pending provider review'
            : 'Reschedule request pending provider review',
        helperTextAr: requestedRescheduleAt != null
            ? 'طلب تغيير الموعد قيد المراجعة'
            : 'طلب تغيير الموعد قيد المراجعة',
      );
    }

    if (s == 'pending_provider_approval' || s == 'pending') {
      return const AppointmentActionState(
        type: AppointmentActionType.changeAppointment,
      );
    }

    if (s == 'confirmed' || s == 'accepted' || s == 'scheduled' || s == 'approved') {
      return const AppointmentActionState(
        type: AppointmentActionType.requestReschedule,
      );
    }

    if (s == 'completed' || s == 'done' || s == 'cancelled' || s == 'canceled' || s == 'rejected') {
      return const AppointmentActionState(
        type: AppointmentActionType.bookAgain,
      );
    }

    return const AppointmentActionState(
      type: AppointmentActionType.hidden,
    );
  }

  static String getLabel(AppointmentActionType type, bool isAr) {
    switch (type) {
      case AppointmentActionType.changeAppointment:
        return isAr ? 'تغيير الموعد' : 'Change Appointment';
      case AppointmentActionType.requestReschedule:
        return isAr ? 'طلب تغيير الموعد' : 'Request Reschedule';
      case AppointmentActionType.requestPending:
        return isAr ? 'طلب قيد المراجعة' : 'Request Pending';
      case AppointmentActionType.bookAgain:
        return isAr ? 'احجز مرة أخرى' : 'Book Again';
      case AppointmentActionType.hidden:
        return '';
    }
  }

  static IconData getIcon(AppointmentActionType type) {
    switch (type) {
      case AppointmentActionType.changeAppointment:
        return Icons.edit_calendar_rounded;
      case AppointmentActionType.requestReschedule:
        return Icons.edit_calendar_rounded;
      case AppointmentActionType.requestPending:
        return Icons.hourglass_empty_rounded;
      case AppointmentActionType.bookAgain:
        return Icons.replay_rounded;
      case AppointmentActionType.hidden:
        return Icons.error;
    }
  }
}
