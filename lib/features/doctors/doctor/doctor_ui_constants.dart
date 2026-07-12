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
    'Requests': 'doctor.dashboard.actionRequests',
    'Cancel': 'doctor.common.cancel',
    'Not set': 'doctor.common.notSet',
    'Available': 'doctor.schedule.available',
    'Unavailable': 'doctor.schedule.unavailable',
    'Add': 'doctor.schedule.add',
    'Payment History': 'doctor.payments.history',
    'Total Paid': 'doctor.payments.totalPaid',
    'Pending': 'doctor.payments.pending',
    'Refunded': 'doctor.payments.refunded',
    'Completed': 'doctor.dashboard.completed',
    'Cancelled': 'doctor.dashboard.canceled',
    'Confirmed': 'doctor.dashboard.statusConfirmed',
    'Medical Reports': 'doctor.dashboard.medicalReports',
    'Medical Records': 'doctor.local.medical_records',
    'View medical history and documents':
        'doctor.local.view_medical_history_documents',
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
    'Accepted': 'doctor.dashboard.statusConfirmed',
    'Account Approved!': 'doctor.local.account_approved',
    'Pending Approval': 'doctor.local.pending_approval',
    'Approved': 'doctor.local.approved',
    'Check Status': 'doctor.local.check_status',
    'Checking...': 'doctor.local.checking',
    'Your doctor account has been approved. You can now access the system.':
        'doctor.local.account_approved_message',
    'Your doctor account is pending approval from the administrator. Please check back later.':
        'doctor.local.account_pending_message',
    'Actions': 'doctor.local.actions',
    'Add Availability Slot': 'doctor.local.add_availability_slot',
    'Add Note': 'doctor.local.add_note',
    'Add another period': 'doctor.local.add_another_period',
    'Address': 'doctor.local.address',
    'Agreed Rate': 'doctor.local.agreed_rate',
    'All': 'doctor.local.all',
    'All Appointments': 'doctor.local.all_appointments',
    'All availability periods for this day will be removed.':
        'doctor.local.all_availability_periods_for_this_day_will_be_re',
    'Amount Earned': 'doctor.local.amount_earned',
    'Appointment Details': 'doctor.local.appointment_details',
    'Appointment': 'doctor.local.appointment',
    'Appointments': 'doctor.local.appointments',
    'View & manage appointments': 'doctor.local.view_manage_appointments',
    'Approved by Admin': 'doctor.local.approved_by_admin',
    'Accept your assigned service rate before using Earnings.':
        'doctor.local.assigned_rate_required',
    'Assignment updates': 'doctor.local.assignment_updates',
    'Availability': 'doctor.local.availability',
    'Availability Slots': 'doctor.local.availability_slots',
    'Back to Role Selection': 'doctor.local.back_to_role_selection',
    'Booking Request': 'doctor.local.booking_request',
    'Check Again': 'doctor.local.check_again',
    'Change profile photo': 'doctor.local.change_profile_photo',
    'Choose from gallery': 'doctor.local.choose_from_gallery',
    'Clinical Notes': 'doctor.local.clinical_notes',
    'Contact Information': 'doctor.local.contact_information',
    'Create and manage reports': 'doctor.local.create_and_manage_reports',
    'Current Approved Rate': 'doctor.local.current_approved_rate',
    'Date': 'doctor.local.date',
    'Date of Birth': 'doctor.local.date_of_birth',
    'Age': 'doctor.local.age',
    'Phone Number': 'doctor.local.phone_number',
    'Day': 'doctor.local.day',
    'Delete': 'doctor.local.delete',
    'Delete Slot': 'doctor.local.delete_slot',
    'Are you sure you want to delete this availability slot?':
        'doctor.local.are_you_sure_you_want_to_delete_this_availabilit',
    'Details': 'doctor.local.details',
    'Distance': 'doctor.local.distance',
    'Disable': 'doctor.local.disable',
    'Doctor ID is missing': 'doctor.local.doctor_id_missing',
    'Edit Availability Slot': 'doctor.local.edit_availability_slot',
    'Edit Profile': 'doctor.local.edit_profile',
    'End Time': 'doctor.local.end_time',
    'End time must be after start time':
        'doctor.local.end_time_must_be_after_start_time',
    'Edit': 'doctor.local.edit',
    'Earning Details': 'doctor.local.earning_details',
    'Earnings': 'doctor.local.earnings',
    'Earnings History': 'doctor.local.earnings_history',
    'Earnings Locked': 'doctor.local.earnings_locked',
    'Earnings are calculated based on completed visits and the approved rate.':
        'doctor.local.earnings_calculated_note',
    'Export PDF': 'doctor.local.export_pdf',
    'Failed': 'doctor.local.failed',
    'Could not pick image. Please try again.':
        'doctor.local.could_not_pick_image',
    'File Report': 'doctor.local.file_report',
    'Full Name': 'doctor.local.full_name',
    'Gender': 'doctor.local.gender',
    'Hourly Rate Approval': 'doctor.local.hourly_rate_approval',
    'Image picker needs a full app restart':
        'doctor.local.image_picker_restart_required',
    'Image size must be less than 5MB': 'doctor.local.image_size_less_than_5mb',
    'In Progress': 'doctor.local.in_progress',
    'Last Month': 'doctor.local.last_month',
    'Language': 'doctor.local.language',
    'Location': 'doctor.local.location',
    'Medical Record': 'doctor.local.medical_record',
    'Medical cases': 'doctor.local.medical_cases',
    'Message Patient': 'doctor.local.message_patient',
    'Name': 'doctor.local.name',
    'New appointments': 'doctor.local.new_appointments',
    'No completed visits ready for a report':
        'doctor.local.no_completed_visits_ready_for_a_report',
    'No completed visits available for reporting.':
        'doctor.local.no_completed_visits_available_for_reporting',
    'No medical record found': 'doctor.local.no_medical_record_found',
    'No earnings available.': 'doctor.local.no_earnings_available',
    'No earnings found for this filter.':
        'doctor.local.no_earnings_found_for_this_filter',
    'Notes': 'doctor.local.notes',
    'Visits History': 'doctor.local.visits_history',
    'View all past visits': 'doctor.local.view_all_past_visits',
    'View patient notes': 'doctor.local.view_patient_notes',
    'Next Visit': 'doctor.local.next_visit',
    'Last Visit': 'doctor.local.last_visit',
    'Notifications': 'doctor.local.notifications',
    'No appointments': 'doctor.local.no_appointments',
    'No notes yet': 'doctor.local.no_notes_yet',
    'Appointments for {date} will appear here.':
        'doctor.local.appointments_for_date_will_appear_here',
    'On The Way': 'doctor.local.on_the_way',
    'Availability Status': 'doctor.local.availability_status',
    'Manage the time slots when you are available to accept appointments.':
        'doctor.local.manage_the_time_slots_when_you_are_available_to',
    'Patient': 'doctor.local.patient',
    'Patient updates': 'doctor.local.patient_updates',
    'Patient Details': 'doctor.local.patient_details',
    'Patient Information': 'doctor.local.patient_information',
    'Patient Name': 'doctor.local.patient_name',
    'Patient Profile': 'doctor.local.patient_profile',
    'Payment Status': 'doctor.local.payment_status',
    'Profile photo updated successfully':
        'doctor.local.profile_photo_updated_successfully',
    'Paid': 'doctor.local.paid',
    'Paid Out': 'doctor.local.paid_out',
    'Payout Pending': 'doctor.local.payout_pending',
    'Pending Payout': 'doctor.local.pending_payout',
    'Please fill all fields': 'doctor.local.please_fill_all_fields',
    'Reason': 'doctor.local.reason',
    'Records': 'doctor.local.records',
    'Reject': 'doctor.local.reject',
    'Reject Request': 'doctor.local.reject_request',
    'Report': 'doctor.local.report',
    'Report Type: Initial Diagnosis':
        'doctor.local.report_type_initial_diagnosis',
    'Result': 'doctor.local.result',
    'Reference': 'doctor.local.reference',
    'Done': 'doctor.local.done',
    'Request Payout': 'doctor.local.request_payout',
    'Request Details': 'doctor.local.request_details',
    'Request Status': 'doctor.local.request_status',
    'Review options': 'doctor.local.review_options',
    'Save': 'doctor.local.save',
    'Save Changes': 'doctor.local.save_changes',
    'Scheduled': 'doctor.local.scheduled',
    'Select': 'doctor.local.select',
    'Service': 'doctor.local.service',
    'Send medical summaries after completed visits':
        'doctor.local.send_medical_summaries_after_completed_visits',
    'Filter': 'doctor.local.filter',
    'Clear': 'doctor.local.clear',
    'Service Type': 'doctor.local.service_type',
    'Service Rate Approval': 'doctor.local.service_rate_approval',
    'The administrator has assigned your service rate. Please review and accept it before continuing.':
        'doctor.local.service_rate_review_message',
    'Assigned Rate': 'doctor.local.assigned_rate',
    'Service rate accepted. Payment is now available.':
        'doctor.local.service_rate_accepted',
    'Service rate rejected. Please wait for administrator review.':
        'doctor.local.service_rate_rejected',
    'Slot added successfully': 'doctor.local.slot_added_successfully',
    'Slot deleted': 'doctor.local.slot_deleted',
    'Slot updated successfully': 'doctor.local.slot_updated_successfully',
    'Start Time': 'doctor.local.start_time',
    'Status': 'doctor.local.status',
    'Stars': 'doctor.local.stars',
    'Submit Medical Report': 'doctor.local.submit_medical_report',
    'Arrival verified successfully.':
        'doctor.local.arrival_verified_successfully',
    'Arrival Time': 'doctor.local.arrival_time',
    'Arrived': 'doctor.local.arrived',
    'Arrived Successfully': 'doctor.local.arrived_successfully',
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
    'This Month': 'doctor.local.this_month',
    'Total Earnings': 'doctor.local.total_earnings',
    'Total Patients': 'doctor.local.total_patients',
    'Transaction History': 'doctor.local.transaction_history',
    'Treatment / Notes': 'doctor.local.treatment_notes',
    'Try Again': 'doctor.local.try_again',
    'Upcoming': 'doctor.local.upcoming',
    'View Medical Record': 'doctor.local.view_medical_record',
    'View Patient Profile': 'doctor.local.view_patient_profile',
    'Visit History': 'doctor.local.visit_history',
    'Visit': 'doctor.local.visit',
    'Visits': 'doctor.local.visits',
    'Estimated time': 'doctor.local.estimated_time',
    'Visit Duration': 'doctor.local.visit_duration',
    'Visit In Progress': 'doctor.local.visit_in_progress',
    'Visit Tracking': 'doctor.local.visit_tracking',
    'Consultation in progress': 'doctor.local.consultation_in_progress',
    'Patient Location': 'doctor.local.patient_location',
    'Please drive safely and follow traffic rules.':
        'doctor.local.please_drive_safely',
    'Start Navigation': 'doctor.local.start_navigation',
    'Start Visit': 'doctor.local.start_visit',
    'Take a photo': 'doctor.local.take_a_photo',
    'You are on your way to the patient':
        'doctor.local.you_are_on_your_way_to_the_patient',
    'Visit report': 'doctor.local.visit_report',
    'Lab Results': 'doctor.local.lab_results',
    'Initial Diagnosis': 'doctor.local.initial_diagnosis',
    'Completed Visits': 'doctor.local.completed_visits',
    'Complete Visit': 'doctor.local.complete_visit',
    'Short Bio': 'doctor.local.short_bio',
    'Experience (Years)': 'doctor.local.experience_years',
    'Rate Review Pending': 'doctor.local.rate_review_pending',
    'A list of completed visit earnings and payment statuses.':
        'doctor.local.earnings_history_subtitle',
    'A new report can be created only after a completed visit without an existing report.':
        'doctor.local.report_empty_subtitle',
    'Not yet paid out': 'doctor.local.not_yet_paid_out',
    'Successfully paid': 'doctor.local.successfully_paid',
    'All visit earnings': 'doctor.local.all_visit_earnings',
    'Cancellations': 'doctor.local.cancellations',
    'Error': 'doctor.local.error',
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
