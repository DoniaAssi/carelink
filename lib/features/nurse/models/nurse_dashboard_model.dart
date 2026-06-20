import 'package:carelink/shared/models/service_request.dart';

class NurseDashboardModel {
  const NurseDashboardModel({
    required this.nurseName,
    required this.upcomingVisitsCount,
    required this.notificationCount,
    required this.upcomingVisits,
    required this.allRequests,
    required this.completedVisitsCount,
    required this.inProgressVisitsCount,
    required this.pendingRequestsCount,
    required this.canWork,
    required this.rateApprovalStatus,
    required this.approvedHourlyRate,
    required this.specialization,
    required this.rateGateMessage,
  });

  final String nurseName;
  final int upcomingVisitsCount;
  final int notificationCount;
  final List<VisitModel> upcomingVisits;
  final List<ServiceRequest> allRequests;
  final int completedVisitsCount;
  final int inProgressVisitsCount;
  final int pendingRequestsCount;
  final bool canWork;
  final String rateApprovalStatus;
  final double approvedHourlyRate;
  final String specialization;
  final String rateGateMessage;
}

class VisitModel {
  const VisitModel({
    required this.id,
    required this.patientName,
    required this.patientInitial,
    required this.serviceType,
    required this.location,
    required this.time,
    required this.status,
    required this.request,
  });

  final String id;
  final String patientName;
  final String patientInitial;
  final String serviceType;
  final String location;
  final String time;
  final String status;
  final ServiceRequest request;
}
