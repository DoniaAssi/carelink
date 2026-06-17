import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:carelink/shared/models/service_request.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/services/service_request_service.dart';

class NurseRepository {
  const NurseRepository();

  bool _isPendingProviderApproval(String status) {
    final value = status.toLowerCase().trim();
    return value == 'new' ||
        value == 'pending' ||
        value == 'pending_provider_approval' ||
        value == 'pending provider approval' ||
        value == 'pending_payment' ||
        value == 'payment_pending';
  }

  bool _isConfirmedOrActive(String status) {
    final value = status.toLowerCase().trim();
    return value == 'assigned' ||
        value == 'accepted' ||
        value == 'scheduled' ||
        value == 'confirmed' ||
        value == 'in_progress';
  }

  Future<List<ServiceRequest>> getTodayVisits(String nurseUserId) async {
    final today = DateTime.now();
    final all = await getAllRequests(nurseUserId);
    return all.where((request) {
      final sameDay =
          request.scheduledDate.year == today.year &&
          request.scheduledDate.month == today.month &&
          request.scheduledDate.day == today.day;
      if (!sameDay) return false;
      return _isPendingProviderApproval(request.status) ||
          _isConfirmedOrActive(request.status);
    }).toList()..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
  }

  Future<List<ServiceRequest>> getAllRequests(String nurseUserId) {
    return ServiceRequestService.getProviderRequests(nurseUserId);
  }

  Future<List<ServiceRequest>> getPendingRequests(String nurseUserId) async {
    final all = await getAllRequests(nurseUserId);
    return all.where((request) {
      return _isPendingProviderApproval(request.status);
    }).toList()..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
  }

  Future<List<ServiceRequest>> syncDashboard(String nurseUserId) {
    return getTodayVisits(nurseUserId);
  }

  Future<int> getNotificationCount(String nurseUserId) async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/notifications/$nurseUserId'),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return 0;
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return 0;
    return decoded.where((item) {
      if (item is! Map) return false;
      final value = item['isRead'];
      return value == false || value == 0 || value?.toString() == '0';
    }).length;
  }

  Future<bool> updateRequestStatus({
    required String requestId,
    required String status,
    required String nurseUserId,
    DateTime? scheduledAt,
    int? durationMinutes,
    String? nurseNote,
  }) {
    return ServiceRequestService.updateRequestStatus(
      requestId,
      status,
      providerUserId: nurseUserId,
      scheduledAt: scheduledAt,
      durationMinutes: durationMinutes,
      nurseNote: nurseNote,
    );
  }

  Future<bool> updateStatus({
    required String requestId,
    required String status,
    required String nurseUserId,
    DateTime? scheduledAt,
    int? durationMinutes,
    String? nurseNote,
  }) {
    return updateRequestStatus(
      requestId: requestId,
      status: status,
      nurseUserId: nurseUserId,
      scheduledAt: scheduledAt,
      durationMinutes: durationMinutes,
      nurseNote: nurseNote,
    );
  }

  Future<bool> createAppointment({
    required ServiceRequest request,
    required String nurseUserId,
    DateTime? scheduledAt,
    int? durationMinutes,
    String? nurseNote,
  }) {
    return updateRequestStatus(
      requestId: request.id,
      status: 'accepted',
      nurseUserId: nurseUserId,
      scheduledAt: scheduledAt,
      durationMinutes: durationMinutes,
      nurseNote: nurseNote,
    );
  }

  Future<List<ServiceRequest>> getSchedule(String nurseUserId) {
    return getAllRequests(nurseUserId);
  }
}
