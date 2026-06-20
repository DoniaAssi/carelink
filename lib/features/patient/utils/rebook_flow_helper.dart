import 'package:flutter/material.dart';

import 'package:carelink/features/patient/screens/provider_details_screen.dart';
import 'package:carelink/shared/models/appointment_model.dart';
import 'package:carelink/shared/models/booking_request_model.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/api_service.dart';

class RebookFlowHelper {
  const RebookFlowHelper._();

  static Future<void> startFromAppointment({
    required BuildContext context,
    required AppointmentModel appointment,
    required String patientUserId,
    double? priceHint,
  }) async {
    final providerId = appointment.providerUserId.trim();
    if (providerId.isEmpty) {
      _showSnack(context, 'This provider is currently unavailable.');
      return;
    }

    try {
      final provider = ProviderModel.fromJson(
        await ApiService().getProviderById(providerId, realAvailability: true),
      );
      final profile = await ApiService().getPatientProfile(patientUserId);
      if (!context.mounted) return;
      if (profile['isNewPatient'] == true && provider.role.toLowerCase() != 'doctor') {
        _showSnack(context, 'For your first appointment, you must book with a doctor for an initial assessment.');
        return;
      }
      final request = _requestFromAppointment(
        appointment: appointment,
        patientUserId: patientUserId,
        provider: provider,
        priceHint: priceHint,
      );
      _openProviderDetails(
        context: context,
        provider: provider,
        patientUserId: patientUserId,
        request: request,
        existingBooking: _appointmentToMap(appointment),
      );
    } catch (error) {
      if (context.mounted) {
        _showSnack(context, error.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  static Future<void> startFromRow({
    required BuildContext context,
    required Map<String, dynamic> row,
    required String patientUserId,
  }) async {
    final providerId = (row['providerUserId'] ?? row['doctorUserId'] ?? '')
        .toString()
        .trim();
    if (providerId.isEmpty) {
      _showSnack(context, 'This provider is currently unavailable.');
      return;
    }

    try {
      final provider = ProviderModel.fromJson(
        await ApiService().getProviderById(providerId, realAvailability: true),
      );
      final profile = await ApiService().getPatientProfile(patientUserId);
      if (!context.mounted) return;
      if (profile['isNewPatient'] == true && provider.role.toLowerCase() != 'doctor') {
        _showSnack(context, 'For your first appointment, you must book with a doctor for an initial assessment.');
        return;
      }
      final request = _requestFromRow(
        row: row,
        patientUserId: patientUserId,
        provider: provider,
      );
      _openProviderDetails(
        context: context,
        provider: provider,
        patientUserId: patientUserId,
        request: request,
        existingBooking: row,
      );
    } catch (error) {
      if (context.mounted) {
        _showSnack(context, error.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  static void _openProviderDetails({
    required BuildContext context,
    required ProviderModel provider,
    required String patientUserId,
    required BookingRequestModel request,
    required Map<String, dynamic> existingBooking,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderDetailsScreen(
          provider: provider,
          patientUserId: patientUserId,
          isRebook: true,
          existingBooking: existingBooking,
          draftBookingRequest: request,
        ),
      ),
    );
  }

  static BookingRequestModel _requestFromAppointment({
    required AppointmentModel appointment,
    required String patientUserId,
    required ProviderModel provider,
    double? priceHint,
  }) {
    final parsed = _parseNotes(appointment.notes);
    final service = _firstNonEmpty([
      parsed['service'],
      provider.serviceType,
      appointment.providerRole,
      'Care Service',
    ]);
    final reason = _firstNonEmpty([
      parsed['reason'],
      parsed['currentcase'],
      appointment.notes.contains('|') ? '' : appointment.notes,
      appointment.symptoms,
    ]);
    final dateTime = appointment.scheduledAt;

    return BookingRequestModel(
      patientId: patientUserId,
      providerId: provider.userId,
      providerName: _firstNonEmpty([
        provider.fullName,
        appointment.providerName,
      ]),
      providerRole: _firstNonEmpty([provider.role, appointment.providerRole]),
      providerImageUrl:
          provider.profileImageUrl ?? appointment.providerImageUrl,
      specialization: provider.specialization,
      serviceType: service,
      appointmentType: _firstNonEmpty([parsed['appointmenttype'], 'home']),
      appointmentDate: _dateOnly(dateTime),
      appointmentTime: _timeOnly(dateTime),
      visitLatitude: appointment.visitLatitude ?? provider.gpsLat ?? 0,
      visitLongitude: appointment.visitLongitude ?? provider.gpsLng ?? 0,
      visitAddress: _firstNonEmpty([
        appointment.visitAddress,
        appointment.location,
      ]),
      locationNote: appointment.locationNote,
      patientReason: reason,
      symptoms: appointment.symptoms,
      isUrgent: appointment.isUrgent,
      additionalNotes: appointment.additionalNotes,
      price: provider.consultationFee ?? priceHint ?? 0,
      paymentMethod: '',
      paymentStatus: 'unpaid',
      bookingStatus: 'pending_provider_approval',
      isRebook: true,
      previousAppointmentId: appointment.appointmentId,
    );
  }

  static BookingRequestModel _requestFromRow({
    required Map<String, dynamic> row,
    required String patientUserId,
    required ProviderModel provider,
  }) {
    final notes = (row['notes'] ?? '').toString();
    final parsed = _parseNotes(notes);
    final scheduled = DateTime.tryParse(
      (row['scheduledAt'] ?? '').toString().replaceFirst(' ', 'T'),
    );
    final service = _firstNonEmpty([
      row['serviceType'],
      parsed['service'],
      provider.serviceType,
      'Care Service',
    ]);
    final reason = _firstNonEmpty([
      row['reasonForVisit'],
      parsed['reason'],
      parsed['currentcase'],
      notes.contains('|') ? '' : notes,
      row['symptoms'],
    ]);

    return BookingRequestModel(
      patientId: patientUserId,
      providerId: provider.userId,
      providerName: _firstNonEmpty([provider.fullName, row['providerName']]),
      providerRole: _firstNonEmpty([provider.role, row['providerRole']]),
      providerImageUrl: provider.profileImageUrl ?? '',
      specialization: provider.specialization,
      serviceType: service,
      appointmentType: _firstNonEmpty([parsed['appointmenttype'], 'home']),
      appointmentDate: _dateOnly(scheduled),
      appointmentTime: _timeOnly(scheduled),
      visitLatitude: _doubleFrom(row['visitLatitude']) ?? provider.gpsLat ?? 0,
      visitLongitude:
          _doubleFrom(row['visitLongitude']) ?? provider.gpsLng ?? 0,
      visitAddress: _firstNonEmpty([row['visitAddress'], row['location']]),
      locationNote: (row['locationNote'] ?? '').toString(),
      patientReason: reason,
      symptoms: (row['symptoms'] ?? '').toString(),
      isUrgent:
          row['isUrgent'] == true ||
          row['isUrgent'] == 1 ||
          (row['isUrgent'] ?? '').toString() == '1',
      additionalNotes: (row['additionalNotes'] ?? '').toString(),
      price: provider.consultationFee ?? 0,
      paymentMethod: '',
      paymentStatus: 'unpaid',
      bookingStatus: 'pending_provider_approval',
      isRebook: true,
      previousAppointmentId: (row['appointmentId'] ?? row['requestId'] ?? '')
          .toString(),
    );
  }

  static Map<String, dynamic> _appointmentToMap(AppointmentModel appointment) {
    return {
      'appointmentId': appointment.appointmentId,
      'requestId': appointment.appointmentId,
      'patientUserId': appointment.patientUserId,
      'providerUserId': appointment.providerUserId,
      'providerName': appointment.providerName,
      'providerRole': appointment.providerRole,
      'serviceType': '',
      'status': appointment.status,
      'scheduledAt': appointment.scheduledAt?.toIso8601String(),
      'location': appointment.location,
      'visitAddress': appointment.visitAddress,
      'locationNote': appointment.locationNote,
      'symptoms': appointment.symptoms,
      'isUrgent': appointment.isUrgent,
      'additionalNotes': appointment.additionalNotes,
      'notes': appointment.notes,
      'visitLatitude': appointment.visitLatitude,
      'visitLongitude': appointment.visitLongitude,
    };
  }

  static Map<String, String> _parseNotes(String rawNotes) {
    final result = <String, String>{};
    if (rawNotes.trim().isEmpty) return result;
    final parts = rawNotes.contains('|')
        ? rawNotes.split('|')
        : rawNotes.split(RegExp(r'[\n\r]'));
    for (final raw in parts) {
      final part = raw.trim();
      final colon = part.indexOf(':');
      if (colon < 0) continue;
      final key = part.substring(0, colon).trim().toLowerCase();
      final value = part.substring(colon + 1).trim();
      if (value.isEmpty) continue;
      final normalized = switch (key) {
        'appointment type' => 'appointmenttype',
        'current case' => 'currentcase',
        'reason for visit' => 'reason',
        _ => key.replaceAll(' ', ''),
      };
      result[normalized] = value;
    }
    return result;
  }

  static String _firstNonEmpty(List<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return '';
  }

  static String _dateOnly(DateTime? value) {
    if (value == null) return '';
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  static String _timeOnly(DateTime? value) {
    if (value == null) return '';
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  static double? _doubleFrom(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static void _showSnack(BuildContext context, String message) {
    if (!context.mounted || message.trim().isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
