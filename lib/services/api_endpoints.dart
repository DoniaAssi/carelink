// API Endpoints Documentation
// Base URL: http://127.0.0.1/carelink
//
// This file documents all required backend endpoints for the Nurse role.
// All endpoints follow RESTful conventions with JSON request/response format.

class ApiEndpoints {
  static const String baseUrl = 'http://127.0.0.1/carelink';

  // Authentication Endpoints
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String logout = '/api/auth/logout';
  static const String refreshToken = '/api/auth/refresh';

  // Service Requests Endpoints
  static const String getServiceRequests = '/api/service-requests';
  static const String getServiceRequestById = '/api/service-requests/:id';
  static const String updateServiceRequestStatus =
      '/api/service-requests/:id/status';
  static const String acceptServiceRequest = '/api/service-requests/:id/accept';
  static const String rejectServiceRequest = '/api/service-requests/:id/reject';
  static const String completeServiceRequest =
      '/api/service-requests/:id/complete';

  // Visit Reports Endpoints
  static const String getReports = '/api/visit-reports';
  static const String getReportById = '/api/visit-reports/:id';
  static const String createReport = '/api/visit-reports';
  static const String updateReport = '/api/visit-reports/:id';
  static const String deleteReport = '/api/visit-reports/:id';

  // Payment Endpoints
  static const String getPaymentMethods = '/api/payments/methods';
  static const String getPaymentHistory = '/api/payments/history';
  static const String getPaymentTransaction = '/api/payments/transactions/:id';
  static const String addPaymentMethod = '/api/payments/methods';
  static const String updatePaymentMethod = '/api/payments/methods/:id';
  static const String deletePaymentMethod = '/api/payments/methods/:id';
  static const String requestPayment = '/api/payments/request';

  // Provider Profile Endpoints
  static const String getProviderProfile = '/api/providers/profile';
  static const String updateProviderProfile = '/api/providers/profile';
  static const String uploadCertification =
      '/api/providers/certifications/upload';
  static const String getCertifications = '/api/providers/certifications';
  static const String deleteCertification = '/api/providers/certifications/:id';

  // Schedule/Availability Endpoints
  static const String getAvailability = '/api/providers/availability';
  static const String updateAvailability = '/api/providers/availability';
  static const String getScheduleConflicts =
      '/api/providers/schedule/conflicts';

  // Notification Endpoints
  static const String getNotifications = '/api/notifications';
  static const String markNotificationAsRead = '/api/notifications/:id/read';
  static const String updateNotificationPreferences =
      '/api/notifications/preferences';

  // Nurse Specific Dashboard Endpoints
  static const String getNurseDashboard = '/api/nurses/dashboard';
  static const String getNurseStats = '/api/nurses/stats';
  static const String getNurseRatings = '/api/nurses/ratings';

  // Doctor Specific Endpoints
  static const String doctorLogin = '/doctor/login';
  static const String doctorApprovalStatus = '/doctor/approval-status';
  static const String doctorProfile = '/doctor/profile';
  static const String doctorRequests = '/doctor/requests';
  static const String doctorPatients = '/doctor/patients';
  static const String doctorAvailability = '/doctor/availability';
  static const String doctorNotificationPreferences =
      '/doctor/notification-preferences';
  static const String doctorSchedule = '/doctor/schedule';
  static const String doctorRatings = '/doctor/ratings';
  static const String doctorPayments = '/doctor/payments';
  static const String doctorDashboard = '/doctor/dashboard';
  static const String doctorInitialDiagnosis = '/doctor/initial-diagnosis';
}

/// Expected Request/Response Formats

/// Login Request
/// POST /api/auth/login
/// {
///   "email": "nurse@example.com",
///   "password": "password123"
/// }
/// Response:
/// {
///   "success": true,
///   "token": "jwt_token",
///   "user": { "id", "email", "fullName", "role", ... }
/// }

/// Create Visit Report Request
/// POST /api/visit-reports
/// {
///   "provider_id": 1,
///   "patient_id": 1,
///   "patient_name": "John Doe",
///   "service_type": "Home Nursing Care",
///   "location": "123 Main St",
///   "scheduled_date": "2024-01-15",
///   "duration_hours": 2,
///   "visit_summary": "...",
///   "vital_signs": "...",
///   "medications": "...",
///   "observations": "...",
///   "recommendations": "..."
/// }
/// Response:
/// {
///   "success": true,
///   "report_id": 1,
///   "message": "Report created successfully"
/// }

/// Get Provider Profile Request
/// GET /api/providers/profile?provider_id=1
/// Response:
/// {
///   "success": true,
///   "profile": {
///     "provider_id": 1,
///     "bio": "...",
///     "specialization": "...",
///     "experience_years": 5,
///     "hourly_rate": 50,
///     "phone": "...",
///     "is_available": true,
///     "certifications": ["RN", "BLS"],
///     "availability_schedule": {
///       "Monday": "9:00 AM - 5:00 PM",
///       ...
///     }
///   }
/// }

/// Update Provider Profile Request
/// PUT /api/providers/profile
/// {
///   "provider_id": 1,
///   "bio": "...",
///   "specialization": "...",
///   "experience_years": 5,
///   "hourly_rate": 50,
///   "phone": "...",
///   "is_available": true,
///   "certifications": ["RN", "BLS"],
///   "availability_schedule": { ... }
/// }
/// Response:
/// {
///   "success": true,
///   "message": "Profile updated successfully"
/// }

/// Get Payment Methods Request
/// GET /api/payments/methods?provider_id=1
/// Response:
/// {
///   "success": true,
///   "methods": [
///     {
///       "id": 1,
///       "provider_id": 1,
///       "type": "bank_transfer",
///       "account_holder": "John Doe",
///       "account_number": "****1234",
///       "is_primary": true
///     }
///   ]
/// }

/// Get Payment History Request
/// GET /api/payments/history?provider_id=1&page=1&limit=10
/// Response:
/// {
///   "success": true,
///   "transactions": [
///     {
///       "id": 1,
///       "provider_id": 1,
///       "amount": 150.00,
///       "status": "completed",
///       "date": "2024-01-10",
///       "service_request_id": 1
///     }
///   ],
///   "total": 50,
///   "page": 1,
///   "limit": 10
/// }

/// Request Payment Request
/// POST /api/payments/request
/// {
///   "provider_id": 1,
///   "service_request_ids": [1, 2, 3],
///   "total_amount": 450.00,
///   "payment_method_id": 1
/// }
/// Response:
/// {
///   "success": true,
///   "payment_request_id": 1,
///   "message": "Payment request submitted"
/// }

/// Get Service Requests Request
/// GET /api/service-requests?provider_id=1&status=pending&page=1
/// Response:
/// {
///   "success": true,
///   "requests": [
///     {
///       "id": 1,
///       "patient_id": 1,
///       "patient_name": "Jane Doe",
///       "service_type": "Home Nursing Care",
///       "location": "456 Oak Ave",
///       "date": "2024-01-20",
///       "start_time": "10:00",
///       "end_time": "12:00",
///       "status": "pending",
///       "description": "...",
///       "created_at": "2024-01-15"
///     }
///   ],
///   "total": 10
/// }

/// Accept Service Request Request
/// POST /api/service-requests/:id/accept
/// {
///   "provider_id": 1
/// }
/// Response:
/// {
///   "success": true,
///   "message": "Service request accepted"
/// }

/// Update Service Request Status Request
/// PUT /api/service-requests/:id/status
/// {
///   "status": "completed",
///   "notes": "Service completed successfully"
/// }
/// Response:
/// {
///   "success": true,
///   "message": "Status updated successfully"
/// }

/// Upload Certification Request
/// POST /api/providers/certifications/upload
/// FormData:
/// - provider_id: 1
/// - file: [binary file data]
/// Response:
/// {
///   "success": true,
///   "certification_id": 1,
///   "message": "Certification uploaded successfully"
/// }

/// Add Payment Method Request
/// POST /api/payments/methods
/// {
///   "provider_id": 1,
///   "type": "bank_transfer",
///   "account_holder": "John Doe",
///   "account_number": "1234567890",
///   "bank_name": "ABC Bank",
///   "is_primary": false
/// }
/// Response:
/// {
///   "success": true,
///   "method_id": 1,
///   "message": "Payment method added successfully"
/// }

/// Update Availability Schedule Request
/// PUT /api/providers/availability
/// {
///   "provider_id": 1,
///   "schedule": {
///     "Monday": "9:00 AM - 5:00 PM",
///     "Tuesday": "9:00 AM - 5:00 PM",
///     ...
///   }
/// }
/// Response:
/// {
///   "success": true,
///   "message": "Availability updated successfully"
/// }

/// Get Dashboard Stats Request
/// GET /api/nurses/dashboard?provider_id=1
/// Response:
/// {
///   "success": true,
///   "stats": {
///     "total_requests": 50,
///     "completed_requests": 45,
///     "pending_requests": 3,
///     "total_earnings": 2250.00,
///     "pending_payments": 150.00,
///     "average_rating": 4.8,
///     "total_patients": 25
///   }
/// }
