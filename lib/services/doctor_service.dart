import 'package:carelink/services/api_service.dart';

import 'api_endpoints.dart';

class DoctorService {
  final ApiService _apiService = ApiService();

  // ============================================
  // DOCTOR LOGIN
  // ============================================
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _apiService.post(ApiEndpoints.doctorLogin, {
        'email': email,
        'password': password,
      });
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // CHECK APPROVAL STATUS
  // ============================================
  Future<Map<String, dynamic>> checkApprovalStatus(String userId) async {
    try {
      final response = await _apiService.get(
        '${ApiEndpoints.doctorApprovalStatus}/$userId',
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // GET DOCTOR PROFILE
  // ============================================
  Future<Map<String, dynamic>> getProfile(String userId) async {
    try {
      final response = await _apiService.get(
        '${ApiEndpoints.doctorProfile}/$userId',
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // UPDATE DOCTOR PROFILE
  // ============================================
  Future<Map<String, dynamic>> updateProfile(
    String userId, {
    String? fullName,
    String? phone,
    String? specialization,
    String? shortBio,
    int? experienceYears,
    double? consultationFee,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (fullName != null) body['fullName'] = fullName;
      if (phone != null) body['phone'] = phone;
      if (specialization != null) body['specialization'] = specialization;
      if (shortBio != null) body['shortBio'] = shortBio;
      if (experienceYears != null) body['experienceYears'] = experienceYears;
      if (consultationFee != null) body['consultationFee'] = consultationFee;

      final response = await _apiService.put(
        '${ApiEndpoints.doctorProfile}/$userId',
        body,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // GET PENDING REQUESTS
  // ============================================
  Future<List<dynamic>> getPendingRequests(String doctorId) async {
    try {
      final response = await _apiService.get(
        '${ApiEndpoints.doctorRequests}/pending?doctorId=$doctorId',
      );
      return response is List ? response : [];
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // GET AVAILABLE MATCHED REQUESTS
  // ============================================
  Future<List<dynamic>> getAvailableRequests(
    String doctorId, {
    double? maxDistanceKm,
  }) async {
    try {
      var endpoint =
          '${ApiEndpoints.doctorRequests}/available?doctorId=$doctorId';
      if (maxDistanceKm != null) {
        endpoint += '&maxDistanceKm=$maxDistanceKm';
      }
      final response = await _apiService.get(endpoint);
      return response is List ? response : [];
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // GET ALL REQUESTS
  // ============================================
  Future<List<dynamic>> getRequests(String doctorId, {String? status}) async {
    try {
      var endpoint = '${ApiEndpoints.doctorRequests}?doctorId=$doctorId';
      if (status != null) {
        endpoint += '&status=$status';
      }
      final response = await _apiService.get(endpoint);
      return response is List ? response : [];
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // GET REQUEST DETAILS
  // ============================================
  Future<Map<String, dynamic>> getRequestDetails(String requestId) async {
    try {
      final response = await _apiService.get(
        '${ApiEndpoints.doctorRequests}/$requestId',
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // ACCEPT REQUEST
  // ============================================
  Future<Map<String, dynamic>> acceptRequest(
    String requestId,
    String doctorId,
  ) async {
    try {
      final response = await _apiService.post(
        '${ApiEndpoints.doctorRequests}/$requestId/accept',
        {'doctorId': doctorId},
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // REJECT REQUEST
  // ============================================
  Future<Map<String, dynamic>> rejectRequest(
    String requestId,
    String doctorId, {
    String? reason,
  }) async {
    try {
      final response = await _apiService.post(
        '${ApiEndpoints.doctorRequests}/$requestId/reject',
        {'doctorId': doctorId, 'reason': reason},
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // COMPLETE REQUEST
  // ============================================
  Future<Map<String, dynamic>> completeRequest(
    String requestId,
    String doctorId,
  ) async {
    try {
      final response = await _apiService.post(
        '${ApiEndpoints.doctorRequests}/$requestId/complete',
        {'doctorId': doctorId},
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // GET DOCTOR PATIENTS
  // ============================================
  Future<List<dynamic>> getPatients(String doctorId) async {
    try {
      final response = await _apiService.get(
        '${ApiEndpoints.doctorPatients}?doctorId=$doctorId',
      );
      return response is List ? response : [];
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // GET PATIENT MEDICAL RECORD
  // ============================================
  Future<Map<String, dynamic>> getPatientMedicalRecord(
    String patientId, {
    required String doctorId,
  }) async {
    try {
      final response = await _apiService.get(
        '${ApiEndpoints.doctorPatients}/$patientId/medical-record?doctorId=$doctorId',
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // SUBMIT MEDICAL REPORT
  // ============================================
  Future<Map<String, dynamic>> submitMedicalReport(
    String requestId,
    String doctorId, {
    String? diagnosis,
    String? notes,
    String? prescription,
  }) async {
    try {
      final response = await _apiService
          .post('${ApiEndpoints.doctorRequests}/$requestId/report', {
            'doctorId': doctorId,
            'diagnosis': diagnosis,
            'notes': notes,
            'prescription': prescription,
          });
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // MANAGE AVAILABILITY
  // ============================================
  Future<Map<String, dynamic>> setAvailability(
    String doctorId,
    bool isAvailable,
  ) async {
    try {
      final response = await _apiService.put(
        '${ApiEndpoints.doctorAvailability}/$doctorId',
        {'isAvailable': isAvailable},
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // GET AVAILABILITY STATUS
  // ============================================
  Future<Map<String, dynamic>> getAvailabilityStatus(String doctorId) async {
    try {
      final response = await _apiService.get(
        '${ApiEndpoints.doctorAvailability}/$doctorId',
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // NOTIFICATION PREFERENCES
  // ============================================
  Future<Map<String, dynamic>> getNotificationPreferences(
    String doctorId,
  ) async {
    try {
      final response = await _apiService.get(
        '${ApiEndpoints.doctorNotificationPreferences}/$doctorId',
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateNotificationPreferences(
    String doctorId,
    Map<String, bool> preferences,
  ) async {
    try {
      final response = await _apiService.put(
        '${ApiEndpoints.doctorNotificationPreferences}/$doctorId',
        preferences,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // GET SCHEDULE
  // ============================================
  Future<List<dynamic>> getSchedule(String doctorId) async {
    try {
      final response = await _apiService.get(
        '${ApiEndpoints.doctorSchedule}/$doctorId',
      );
      return response is List ? response : [];
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // ADD SCHEDULE SLOT
  // ============================================
  Future<Map<String, dynamic>> addScheduleSlot(
    String doctorId, {
    required String day,
    required String startTime,
    required String endTime,
  }) async {
    try {
      final response = await _apiService.post(
        '${ApiEndpoints.doctorSchedule}/$doctorId',
        {'day': day, 'startTime': startTime, 'endTime': endTime},
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // DELETE SCHEDULE SLOT
  // ============================================
  Future<Map<String, dynamic>> deleteScheduleSlot(
    String doctorId,
    String slotId,
  ) async {
    try {
      final response = await _apiService.delete(
        '${ApiEndpoints.doctorSchedule}/$doctorId/$slotId',
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // GET RATINGS AND FEEDBACK
  // ============================================
  Future<Map<String, dynamic>> getRatings(String doctorId) async {
    try {
      final response = await _apiService.get(
        '/ratings/provider/$doctorId',
      );
      
      final items = response['items'] as List? ?? [];
      
      // Calculate distribution
      final Map<int, int> distMap = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      for (var item in items) {
        final stars = (item['stars'] as num?)?.round() ?? 0;
        if (distMap.containsKey(stars)) {
          distMap[stars] = (distMap[stars]! + 1);
        }
      }
      
      final distribution = distMap.entries.map((e) => {
        'rating': e.key,
        'count': e.value,
      }).toList();

      return {
        'summary': {
          'averageRating': response['averageRating'] ?? 0.0,
          'totalReviews': response['ratingsCount'] ?? 0,
          'distribution': distribution,
        },
        'reviews': items.map((item) => {
          'rating': item['stars'] ?? 0,
          'patientName': item['patientName'] ?? 'Anonymous',
          'reviewText': item['comment'] ?? '',
          'reasonForVisit': item['reasonForVisit'] ?? '',
          'createdAt': item['createdAt'],
        }).toList(),
      };
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // GET PAYMENT HISTORY
  // ============================================
  Future<Map<String, dynamic>> getPayments(String doctorId) async {
    try {
      final response = await _apiService.get(
        '${ApiEndpoints.doctorPayments}/$doctorId',
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // ============================================
  // GET DASHBOARD STATS
  // ============================================
  Future<Map<String, dynamic>> getDashboardStats(String doctorId) async {
    try {
      final response = await _apiService.get(
        '${ApiEndpoints.doctorDashboard}/$doctorId',
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }
}
