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
  });

  final String nurseName;
  final int upcomingVisitsCount;
  final int notificationCount;
  final List<VisitModel> upcomingVisits;
  final List<ServiceRequest> allRequests;
  final int completedVisitsCount;
  final int inProgressVisitsCount;
  final int pendingRequestsCount;
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
