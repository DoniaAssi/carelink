import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:carelink/features/nurse/models/nurse_dashboard_model.dart';
import 'package:carelink/shared/models/service_request.dart';
import 'package:carelink/shared/models/user.dart';
import 'package:carelink/shared/services/api_service.dart';

import 'nurse_repository.dart';

class NurseDashboardRepository {
  const NurseDashboardRepository({
    this.client,
    this.nurseRepository = const NurseRepository(),
  });

  final http.Client? client;
  final NurseRepository nurseRepository;

  Future<NurseDashboardModel> load(User user) async {
    final httpClient = client ?? http.Client();
    final statsFuture = httpClient.get(
      Uri.parse('${ApiService.baseUrl}/nurse/dashboard/${user.userId}'),
    );
    final notificationsFuture = nurseRepository.getNotificationCount(
      user.userId,
    );
    final requestsFuture = nurseRepository.getAllRequests(user.userId);
    final todayVisitsFuture = nurseRepository.syncDashboard(user.userId);

    final responses = await Future.wait([
      statsFuture,
      notificationsFuture,
      requestsFuture,
      todayVisitsFuture,
    ]);

    final statsResponse = responses[0] as http.Response;
    final notificationCount = responses[1] as int;
    final requests = responses[2] as List<ServiceRequest>;
    final todayVisits = responses[3] as List<ServiceRequest>;

    if (statsResponse.statusCode < 200 || statsResponse.statusCode >= 300) {
      throw Exception('Failed to load dashboard data');
    }

    final stats = jsonDecode(statsResponse.body) as Map<String, dynamic>;
    final visits = todayVisits.map(_visitFromRequest).toList();

    return NurseDashboardModel(
      nurseName: user.fullName.trim().isEmpty ? user.email : user.fullName,
      upcomingVisitsCount: visits.length,
      notificationCount: notificationCount,
      upcomingVisits: visits,
      allRequests: requests,
      completedVisitsCount: _parseInt(stats['completedVisits']),
      inProgressVisitsCount: requests
          .where((request) => request.status.toLowerCase() == 'in_progress')
          .length,
      pendingRequestsCount: _parseInt(stats['pendingRequests']),
    );
  }

  VisitModel _visitFromRequest(ServiceRequest request) {
    final patientName = request.patientName.trim().isEmpty
        ? 'Patient'
        : request.patientName.trim();
    final location = request.location.trim().isNotEmpty
        ? request.location.trim()
        : request.patientAddress.trim();
    return VisitModel(
      id: request.id,
      patientName: patientName,
      patientInitial: patientName[0].toUpperCase(),
      serviceType: request.serviceType.trim().isEmpty
          ? 'Care visit'
          : request.serviceType.trim(),
      location: location.isEmpty ? 'Location not set' : location,
      time: _formatTime(request.scheduledDate),
      status: _dashboardStatus(request.status),
      request: request,
    );
  }

  String _dashboardStatus(String status) {
    final normalized = status.toLowerCase().trim();
    if (normalized == 'pending' ||
        normalized == 'new' ||
        normalized == 'pending_provider_approval' ||
        normalized == 'pending provider approval' ||
        normalized == 'pending_payment' ||
        normalized == 'payment_pending') {
      return 'pending';
    }
    return 'confirmed';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class NurseDashboardController extends ChangeNotifier {
  NurseDashboardController({
    required this.user,
    this.repository = const NurseDashboardRepository(),
  });

  final User user;
  final NurseDashboardRepository repository;

  NurseDashboardModel? model;
  bool isLoading = true;
  String? error;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      model = await repository.load(user);
    } catch (_) {
      error = 'Failed to load dashboard data';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    try {
      model = await repository.load(user);
      error = null;
    } catch (_) {
      error = 'Failed to load dashboard data';
    }
    notifyListeners();
  }
}
