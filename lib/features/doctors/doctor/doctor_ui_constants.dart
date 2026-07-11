import 'package:flutter/material.dart';

import '../../../core/app_localizations.dart';

class DoctorUiConstants {
  const DoctorUiConstants._();

  static const Color doctorBackground = Color(0xFFEFF7EF);
  static const Color doctorPrimary = Color(0xFF0F8B8D);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color pageColor(BuildContext context) =>
      isDark(context) ? const Color(0xFF101716) : doctorBackground;

  static Color surfaceColor(BuildContext context) =>
      isDark(context) ? const Color(0xFF182321) : Colors.white;

  static Color surfaceSoftColor(BuildContext context) => isDark(context)
      ? const Color(0xFF20302D)
      : doctorPrimary.withValues(alpha: 0.08);

  static Color inkColor(BuildContext context) =>
      isDark(context) ? const Color(0xFFF4FAF8) : const Color(0xFF101828);

  static Color mutedColor(BuildContext context) =>
      isDark(context) ? const Color(0xFFB9C8C4) : const Color(0xFF667085);

  static Color borderColor(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.08)
      : const Color(0xFFE4E7EC);

  static Color shadowColor(BuildContext context, [double opacity = 0.06]) =>
      Colors.black.withValues(alpha: isDark(context) ? 0.24 : opacity);

  static Color onPrimaryColor(BuildContext context) =>
      Theme.of(context).colorScheme.onPrimary;

  static ThemeData theme(BuildContext context) {
    final base = Theme.of(context);
    final page = pageColor(context);
    final surface = surfaceColor(context);
    final ink = inkColor(context);
    final muted = mutedColor(context);
    final border = borderColor(context);

    return base.copyWith(
      scaffoldBackgroundColor: page,
      cardColor: surface,
      canvasColor: surface,
      dividerColor: border,
      colorScheme: base.colorScheme.copyWith(
        primary: doctorPrimary,
        surface: surface,
        onSurface: ink,
        error: const Color(0xFFD92D20),
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: page,
        surfaceTintColor: page,
        foregroundColor: ink,
        elevation: 0,
        iconTheme: IconThemeData(color: ink),
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: ink,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: shadowColor(context),
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: ink,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(color: muted),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: muted),
        labelStyle: TextStyle(color: muted),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: doctorPrimary, width: 1.3),
        ),
      ),
      bottomNavigationBarTheme: base.bottomNavigationBarTheme.copyWith(
        backgroundColor: surface,
        selectedItemColor: doctorPrimary,
        unselectedItemColor: muted,
      ),
      popupMenuTheme: base.popupMenuTheme.copyWith(
        color: surface,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: ink),
      ),
    );
  }

  static const Map<String, String> phraseKeys = {
    'Home': 'doctor.nav.home',
    'Schedule': 'doctor.nav.schedule',
    'Patients': 'doctor.nav.patients',
    'Payment': 'doctor.nav.payment',
    'Reports': 'doctor.nav.reports',
    'Profile': 'doctor.nav.profile',
    'Cancel': 'doctor.common.cancel',
    'Not set': 'doctor.common.notSet',
    'Available': 'doctor.schedule.available',
    'Unavailable': 'doctor.schedule.unavailable',
    'Add': 'doctor.schedule.add',
    'Payment History': 'doctor.payments.history',
    'Total Paid': 'doctor.payments.totalPaid',
    'Pending': 'doctor.payments.pending',
    'Completed': 'doctor.dashboard.completed',
    'Cancelled': 'doctor.dashboard.canceled',
    'Confirmed': 'doctor.dashboard.statusConfirmed',
    'Medical Reports': 'doctor.dashboard.medicalReports',
    'New Report': 'doctor.dashboard.newReport',
    'Logout': 'doctor.profile.logout',
    'Professional Information': 'doctor.profile.professionalInfo',
    'Specialization': 'doctor.profile.specialization',
    'Experience': 'doctor.profile.experience',
    'Rating': 'doctor.profile.rating',
    'Phone': 'doctor.profile.phone',
    'Email': 'doctor.profile.email',
    'Diagnosis': 'doctor.visitReport.diagnosis',
    'Blood Type': 'doctor.initial.bloodType',
    'Allergies': 'doctor.initial.allergies',
    'Current Medications': 'doctor.initial.currentMedications',
    'Previous Surgeries': 'doctor.initial.previousSurgeries',
    'Chief Complaint': 'doctor.initial.chiefComplaint',
    'Symptoms': 'doctor.initial.symptoms',
    'Treatment Plan': 'doctor.initial.treatmentPlan',
    'Nursing Instructions': 'doctor.initial.nursingInstructions',
    'Visit Date': 'doctor.visitReport.visitDate',
    'Visit Time': 'doctor.visitReport.visitTime',
    'Accept': 'doctor.local.accept',
    'Accept Rate': 'doctor.local.accept_rate',
    'Actions': 'doctor.local.actions',
    'Add Availability Slot': 'doctor.local.add_availability_slot',
    'Add Note': 'doctor.local.add_note',
    'Add another period': 'doctor.local.add_another_period',
    'Address': 'doctor.local.address',
    'Agreed Rate': 'doctor.local.agreed_rate',
    'All Appointments': 'doctor.local.all_appointments',
    'All availability periods for this day will be removed.':
        'doctor.local.all_availability_periods_for_this_day_will_be_re',
    'Amount Earned': 'doctor.local.amount_earned',
    'Appointment Details': 'doctor.local.appointment_details',
    'Availability': 'doctor.local.availability',
    'Availability Slots': 'doctor.local.availability_slots',
    'Back to Role Selection': 'doctor.local.back_to_role_selection',
    'Booking Request': 'doctor.local.booking_request',
    'Check Again': 'doctor.local.check_again',
    'Contact Information': 'doctor.local.contact_information',
    'Date': 'doctor.local.date',
    'Day': 'doctor.local.day',
    'Delete': 'doctor.local.delete',
    'Delete Slot': 'doctor.local.delete_slot',
    'Are you sure you want to delete this availability slot?':
        'doctor.local.are_you_sure_you_want_to_delete_this_availabilit',
    'Details': 'doctor.local.details',
    'Disable': 'doctor.local.disable',
    'Edit Availability Slot': 'doctor.local.edit_availability_slot',
    'End Time': 'doctor.local.end_time',
    'End time must be after start time':
        'doctor.local.end_time_must_be_after_start_time',
    'Edit': 'doctor.local.edit',
    'Export PDF': 'doctor.local.export_pdf',
    'File Report': 'doctor.local.file_report',
    'Full Name': 'doctor.local.full_name',
    'Gender': 'doctor.local.gender',
    'Hourly Rate Approval': 'doctor.local.hourly_rate_approval',
    'In Progress': 'doctor.local.in_progress',
    'Language': 'doctor.local.language',
    'Location': 'doctor.local.location',
    'Medical Record': 'doctor.local.medical_record',
    'Message Patient': 'doctor.local.message_patient',
    'Name': 'doctor.local.name',
    'No completed visits ready for a report':
        'doctor.local.no_completed_visits_ready_for_a_report',
    'No earnings available.': 'doctor.local.no_earnings_available',
    'Notes': 'doctor.local.notes',
    'Notifications': 'doctor.local.notifications',
    'No appointments': 'doctor.local.no_appointments',
    'Appointments for {date} will appear here.':
        'doctor.local.appointments_for_date_will_appear_here',
    'On The Way': 'doctor.local.on_the_way',
    'Availability Status': 'doctor.local.availability_status',
    'Manage the time slots when you are available to accept appointments.':
        'doctor.local.manage_the_time_slots_when_you_are_available_to',
    'Patient': 'doctor.local.patient',
    'Patient Details': 'doctor.local.patient_details',
    'Patient Information': 'doctor.local.patient_information',
    'Patient Name': 'doctor.local.patient_name',
    'Patient Profile': 'doctor.local.patient_profile',
    'Payment Status': 'doctor.local.payment_status',
    'Please fill all fields': 'doctor.local.please_fill_all_fields',
    'Reason': 'doctor.local.reason',
    'Records': 'doctor.local.records',
    'Reject': 'doctor.local.reject',
    'Reject Request': 'doctor.local.reject_request',
    'Request Details': 'doctor.local.request_details',
    'Request Status': 'doctor.local.request_status',
    'Review options': 'doctor.local.review_options',
    'Save': 'doctor.local.save',
    'Save Changes': 'doctor.local.save_changes',
    'Scheduled': 'doctor.local.scheduled',
    'Select': 'doctor.local.select',
    'Service': 'doctor.local.service',
    'Filter': 'doctor.local.filter',
    'Clear': 'doctor.local.clear',
    'Service Type': 'doctor.local.service_type',
    'Slot added successfully': 'doctor.local.slot_added_successfully',
    'Slot deleted': 'doctor.local.slot_deleted',
    'Slot updated successfully': 'doctor.local.slot_updated_successfully',
    'Start Time': 'doctor.local.start_time',
    'Status': 'doctor.local.status',
    'Submit Medical Report': 'doctor.local.submit_medical_report',
    'Arrival verified successfully.':
        'doctor.local.arrival_verified_successfully',
    'Note saved successfully.': 'doctor.local.note_saved_successfully',
    'Profile updated successfully': 'doctor.local.profile_updated_successfully',
    'Request accepted successfully':
        'doctor.local.request_accepted_successfully',
    'Request rejected': 'doctor.local.request_rejected',
    'Visit marked completed': 'doctor.local.visit_marked_completed',
    'A report already exists for this completed visit.':
        'doctor.local.a_report_already_exists_for_this_completed_visit',
    'Unable to export earnings PDF':
        'doctor.local.unable_to_export_earnings_pdf',
    'View details': 'doctor.local.view_details',
    'Medication': 'doctor.local.medication',
    'Chronic Diseases': 'doctor.local.chronic_diseases',
    'Time': 'doctor.local.time',
    'Total Patients': 'doctor.local.total_patients',
    'Transaction History': 'doctor.local.transaction_history',
    'Treatment / Notes': 'doctor.local.treatment_notes',
    'Try Again': 'doctor.local.try_again',
    'Upcoming': 'doctor.local.upcoming',
    'View Medical Record': 'doctor.local.view_medical_record',
    'View Patient Profile': 'doctor.local.view_patient_profile',
    'Visit History': 'doctor.local.visit_history',
  };
}

extension DoctorTextContext on BuildContext {
  String dx(String source, {Map<String, String>? args}) {
    final key = DoctorUiConstants.phraseKeys[source] ?? source;
    return CarelinkL10n.doctor(this).t(key, args: args);
  }

  String dxError(Object error, {String prefix = 'Error'}) {
    final message = CarelinkL10n.doctor(this).userMessage(error);
    return '${dx(prefix)}: $message';
  }
}

class DoctorTypographyScope extends StatelessWidget {
  const DoctorTypographyScope({super.key, required this.child});

  final Widget child;

  static const double _phoneScale = 0.88;

  @override
  Widget build(BuildContext context) {
    if (_DoctorTypographyMarker.maybeOf(context)) return child;

    final mediaQuery = MediaQuery.of(context);
    final preferredScale = mediaQuery.textScaler.scale(1);
    final effectiveScale = (preferredScale * _phoneScale).clamp(0.82, 1.08);

    return _DoctorTypographyMarker(
      child: Theme(
        data: DoctorUiConstants.theme(context),
        child: MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(effectiveScale),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _DoctorTypographyMarker extends InheritedWidget {
  const _DoctorTypographyMarker({required super.child});

  static bool maybeOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_DoctorTypographyMarker>() !=
        null;
  }

  @override
  bool updateShouldNotify(_DoctorTypographyMarker oldWidget) => false;
}
