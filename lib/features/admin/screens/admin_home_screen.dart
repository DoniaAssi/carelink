import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:carelink/core/app_nav.dart';
import 'package:carelink/features/admin/screens/admin_booking_review_screen.dart';
import 'package:carelink/shared/models/user.dart';
import 'package:carelink/shared/services/api_service.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key, required this.user});

  final User user;

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  static const _teal = Color(0xFF039D98);
  static const _darkTeal = Color(0xFF007B78);
  static const _bg = Color(0xFFF1FAF9);
  static const _ink = Color(0xFF0D1B2A);
  static const _muted = Color(0xFF6B7C86);
  static const _line = Color(0xFFD7E7E5);
  static const double _phoneWidth = 430;

  bool _loading = true;
  String? _error;
  int _tabIndex = 0;
  String _requestFilter = 'all';
  String _requestQuery = '';
  String _providerFilter = 'all';
  String _userFilter = 'all';
  String _userQuery = '';
  String _ratingFilter = 'all';
  int _financeTab = 0;
  String _transactionFilter = 'all';
  String _payoutFilter = 'all';
  String _statisticsRange = 'This Month';
  Map<String, dynamic> _data = const {};

  Map<String, dynamic> get _metrics =>
      Map<String, dynamic>.from(_data['metrics'] ?? const {});
  List<Map<String, dynamic>> get _requests => _list(_data['requests']);
  List<Map<String, dynamic>> get _users => _list(_data['users']);
  List<Map<String, dynamic>> get _ratings => _list(_data['ratings']);
  List<Map<String, dynamic>> get _bookingReviewItems =>
      _list(_data['bookingReview']);
  Map<String, dynamic> get _performance =>
      Map<String, dynamic>.from(_data['performance'] ?? const {});
  List<Map<String, dynamic>> get _serviceRequests =>
      _list(_performance['recentRequests']);
  Map<String, dynamic> get _finance =>
      Map<String, dynamic>.from(_data['finance'] ?? const {});
  Map<String, dynamic> get _financeOverview =>
      Map<String, dynamic>.from(_finance['overview'] ?? const {});
  List<Map<String, dynamic>> get _pricing => _list(_finance['pricing']);
  List<Map<String, dynamic>> get _transactions =>
      _list(_finance['transactions']);
  List<Map<String, dynamic>> get _payouts => _list(_finance['payouts']);
  List<Map<String, dynamic>> get _wallets => _list(_finance['wallets']);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http.get(_uri('/admin/dashboard'));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_message(response));
      }
      final decoded = jsonDecode(response.body);
      if (!mounted) return;
      setState(() => _data = Map<String, dynamic>.from(decoded as Map));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _phoneWidth),
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _teal))
                  : _error != null
                  ? _ErrorState(message: _error!, onRetry: _load)
                  : RefreshIndicator(
                      color: _teal,
                      onRefresh: _load,
                      child: _currentPage(),
                    ),
            ),
          ),
        ),
        bottomNavigationBar: _bottomNav(),
      ),
    );
  }

  Widget _currentPage() {
    switch (_tabIndex) {
      case 1:
        return _requestsPage();
      case 2:
        return _providersPage();
      case 3:
        return _usersPage();
      case 4:
        return _ratingsPage();
      case 5:
        return _financePage();
      case 6:
        return _statisticsPage();
      default:
        return _dashboardPage();
    }
  }

  Widget _dashboardPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      children: [
        _adminTopBar(),
        const SizedBox(height: 20),
        _adminWelcomeCard(),
        const SizedBox(height: 16),
        _bookingReviewShortcut(),
        const SizedBox(height: 22),
        _dashboardSectionTitle('Users'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.34,
          children: [
            _dashboardMetricCard(
              title: 'Users',
              value: _compactNumber(_metrics['totalUsers']),
              trend: '+ 12%',
              positive: true,
            ),
            _dashboardMetricCard(
              title: 'Providers',
              value: _compactNumber(
                _int(_metrics['nurses']) + _int(_metrics['doctors']),
              ),
              trend: '+ 8%',
              positive: true,
            ),
            _dashboardMetricCard(
              title: 'Service Requests',
              value: _compactNumber(_metrics['totalRequests']),
              trend: '+ 15%',
              positive: true,
            ),
            _dashboardMetricCard(
              title: 'Pending Approvals',
              value: _compactNumber(_metrics['pendingProviders']),
              trend: '- 23%',
              positive: false,
            ),
          ],
        ),
        const SizedBox(height: 22),
        _financeOverviewCard(),
        const SizedBox(height: 22),
        _requestsByStatusCard(),
      ],
    );
  }

  Widget _requestsPage() {
    final query = _requestQuery.trim().toLowerCase();
    final filtered = _serviceRequests.where((request) {
      final statusGroup = _serviceStatusGroup(_text(request['status']));
      final haystack =
          '${request['patientName']} ${request['providerName']} ${request['serviceType']} ${request['location']}'
              .toLowerCase();
      return (_requestFilter == 'all' || statusGroup == _requestFilter) &&
          (query.isEmpty || haystack.contains(query));
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      children: [
        _requestsTopBar('Service Requests'),
        const SizedBox(height: 18),
        _requestSearchRow(),
        const SizedBox(height: 16),
        _serviceRequestStatusTabs(),
        const SizedBox(height: 16),
        _bookingReviewInlineCard(),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          _empty('No service requests match this filter')
        else
          ...filtered.map(_serviceRequestTile),
        const SizedBox(height: 18),
        _requestsTopBar('Reports & Complaints', compact: true),
        const SizedBox(height: 12),
        _reportsComplaintTabs(),
        const SizedBox(height: 14),
        if (_ratings.isEmpty)
          _empty('No reports or feedback yet')
        else
          ..._ratings.take(6).map(_reportComplaintTile),
      ],
    );
  }

  Widget _requestsTopBar(String title, {bool compact = false}) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: () => setState(() => _tabIndex = 0),
          icon: const Icon(Icons.arrow_back_rounded, color: _teal, size: 21),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ink,
              fontSize: compact ? 15 : 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Language',
          onPressed: () {},
          icon: const Icon(Icons.language_rounded, color: _teal, size: 20),
        ),
        IconButton(
          tooltip: 'Theme',
          onPressed: () {},
          icon: const Icon(Icons.dark_mode_rounded, color: _teal, size: 19),
        ),
      ],
    );
  }

  Future<void> _openBookingReview() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            AdminBookingReviewScreen(serviceRequests: _serviceRequests),
      ),
    );
    if (mounted) await _load();
  }

  Widget _bookingReviewInlineCard() {
    final count = _bookingReviewItems.length;
    if (count == 0) {
      return Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3F0EE)),
          boxShadow: _softDashboardShadow,
        ),
        child: const Row(
          children: [
            Icon(Icons.verified_user_outlined, color: _teal, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'No nurse bookings need admin review right now.',
                style: TextStyle(
                  color: Color(0xFF6B7C86),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _openBookingReview,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDDEDEA)),
          boxShadow: _softDashboardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFE7F6F3),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.gavel_rounded, color: _darkTeal),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Booking Review',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$count nurse booking${count == 1 ? '' : 's'} need admin decision',
                    style: const TextStyle(
                      color: Color(0xFF6B7C86),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            _pill('$count', const Color(0xFFE7FAF4), _teal),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: _darkTeal),
          ],
        ),
      ),
    );
  }

  Widget _requestSearchRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: (v) => setState(() => _requestQuery = v),
            decoration: InputDecoration(
              hintText: 'Search requests...',
              hintStyle: const TextStyle(
                color: Color(0xFFB5C2C4),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFFB5C2C4),
                size: 20,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        TextButton.icon(
          onPressed: () => setState(() {
            _requestFilter = _requestFilter == 'all' ? 'pending' : 'all';
          }),
          icon: const Icon(Icons.filter_list_rounded, size: 18),
          label: const Text('Filter'),
          style: TextButton.styleFrom(
            foregroundColor: _teal,
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  Widget _serviceRequestStatusTabs() {
    final options = [
      ('all', 'All', _serviceRequests.length),
      (
        'pending',
        'Pending',
        _serviceRequests
            .where((r) => _serviceStatusGroup(_text(r['status'])) == 'pending')
            .length,
      ),
      (
        'in_progress',
        'In Progress',
        _serviceRequests
            .where(
              (r) => _serviceStatusGroup(_text(r['status'])) == 'in_progress',
            )
            .length,
      ),
      (
        'completed',
        'Completed',
        _serviceRequests
            .where(
              (r) => _serviceStatusGroup(_text(r['status'])) == 'completed',
            )
            .length,
      ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in options) ...[
            _serviceRequestChip(option.$1, '${option.$2} (${option.$3})'),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _serviceRequestChip(String value, String label) {
    final selected = _requestFilter == value;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => setState(() => _requestFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _teal : const Color(0xFFE9F8F6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? _teal : const Color(0xFFD9EEEC)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _teal,
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _serviceRequestTile(Map<String, dynamic> request) {
    final status = _text(request['status'], fallback: 'pending');
    final patientName = _text(request['patientName'], fallback: 'Patient');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3F0EE)),
        boxShadow: _softDashboardShadow,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: _teal.withValues(alpha: 0.14),
            child: Text(
              _initials(patientName),
              style: const TextStyle(
                color: _teal,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _text(request['serviceType'], fallback: 'Service request'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64787C),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: _teal,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _text(
                          request['location'],
                          fallback: 'Location not set',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF6F8589),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _shortDate(request['scheduledAt'] ?? request['createdAt']),
                style: const TextStyle(
                  color: _ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _shortTime(request['scheduledAt'] ?? request['createdAt']),
                style: const TextStyle(
                  color: Color(0xFF6F8589),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              _serviceStatusPill(status),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reportsComplaintTabs() {
    return Row(
      children: [
        _reportsComplaintChip('Complaints (0)', true),
        const SizedBox(width: 8),
        _reportsComplaintChip('Feedback (${_ratings.length})', false),
      ],
    );
  }

  Widget _reportsComplaintChip(String label, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? _teal : const Color(0xFFE9F8F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : _teal,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _reportComplaintTile(Map<String, dynamic> item) {
    final status = _int(item['stars']) <= 2
        ? 'New'
        : _int(item['stars']) >= 4
        ? 'Resolved'
        : 'In Progress';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3F0EE)),
        boxShadow: _softDashboardShadow,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFF0AA0B8).withValues(alpha: 0.14),
            child: Text(
              _initials(item['patientName']),
              style: const TextStyle(
                color: Color(0xFF0AA0B8),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _text(item['patientName'], fallback: 'Patient'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _text(item['comment'], fallback: 'Service feedback'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64787C),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_shortDate(item['createdAt'])} - ${_shortTime(item['createdAt'])}',
                  style: const TextStyle(
                    color: Color(0xFF9AA8AB),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _complaintStatusPill(status),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _showRatingDetails(item),
                style: TextButton.styleFrom(
                  foregroundColor: _teal,
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                child: const Text('View'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showRatingDetails(Map<String, dynamic> item) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_text(item['patientName'], fallback: 'Feedback')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stars(_int(item['stars'])),
            const SizedBox(height: 12),
            Text(_text(item['comment'], fallback: 'No comment provided')),
            const SizedBox(height: 12),
            Text('Provider: ${_text(item['providerName'])}'),
            Text('Service: ${_text(item['serviceType'])}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _serviceStatusPill(String status) {
    final group = _serviceStatusGroup(status);
    final color = _serviceStatusColor(group);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _serviceStatusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _complaintStatusPill(String status) {
    final color = status == 'New'
        ? const Color(0xFFE04F5F)
        : status == 'Resolved'
        ? const Color(0xFF1E9D69)
        : const Color(0xFFD28A00);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _providersPage() {
    final providers = _requests.where((provider) {
      final status = _text(provider['approvalStatus'], fallback: 'pending');
      if (_providerFilter == 'all') return true;
      return status == _providerFilter;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      children: [
        _providersTopBar(),
        const SizedBox(height: 18),
        _providerStatusTabs(),
        const SizedBox(height: 16),
        if (providers.isEmpty)
          _empty('No providers match this filter')
        else
          ...providers.map(_providerRequestTile),
      ],
    );
  }

  Widget _usersPage() {
    final q = _userQuery.trim().toLowerCase();
    final filtered = _users.where((u) {
      final role = _text(u['role']);
      final haystack = '${u['fullName']} ${u['email']} ${u['phone']}'
          .toLowerCase();
      return (_userFilter == 'all' || role == _userFilter) &&
          (q.isEmpty || haystack.contains(q));
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      children: [
        _usersTopBar(),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _userQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search user...',
                  hintStyle: const TextStyle(
                    color: Color(0xFFB5C2C4),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFFB5C2C4),
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: () => setState(() {
                _userFilter = _userFilter == 'all' ? 'nurse' : 'all';
              }),
              icon: const Icon(Icons.filter_list_rounded, size: 18),
              label: const Text('Filter'),
              style: TextButton.styleFrom(
                foregroundColor: _teal,
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _usersRoleTabs(),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          _empty('No users match your search')
        else
          ...filtered.map(_userListRow),
      ],
    );
  }

  Widget _ratingsPage() {
    final filtered = _ratings.where((rating) {
      final stars = _int(rating['stars']);
      if (_ratingFilter == 'excellent') return stars >= 5;
      if (_ratingFilter == 'low') return stars <= 2;
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      children: [
        _ratingsTopBar(),
        const SizedBox(height: 18),
        _ratingsSummaryCard(),
        const SizedBox(height: 14),
        _ratingFilterTabs(),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          _empty('No ratings in the database yet')
        else
          ...filtered.map(_ratingCard),
      ],
    );
  }

  Widget _ratingsTopBar() {
    return Row(
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: () => setState(() => _tabIndex = 0),
          icon: const Icon(Icons.arrow_back_rounded, color: _teal, size: 21),
        ),
        const Spacer(),
        const Text(
          'Service Ratings',
          style: TextStyle(
            color: _ink,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Language',
          onPressed: () {},
          icon: const Icon(Icons.language_rounded, color: _teal, size: 20),
        ),
        IconButton(
          tooltip: 'Theme',
          onPressed: () {},
          icon: const Icon(Icons.dark_mode_rounded, color: _teal, size: 19),
        ),
      ],
    );
  }

  Widget _ratingsSummaryCard() {
    final excellent = _ratings.where((r) => _int(r['stars']) >= 5).length;
    final low = _ratings.where((r) => _int(r['stars']) <= 2).length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2F0EE)),
        boxShadow: _softDashboardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F6F3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFF1A72E),
                  size: 31,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Average Rating',
                      style: TextStyle(
                        color: Color(0xFF718388),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _decimal('averageStars'),
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _stars(_num(_metrics['averageStars']).round()),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                '${_int(_metrics['totalRatings'])}',
                style: const TextStyle(
                  color: _teal,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFE4F0EE)),
          Row(
            children: [
              _ratingSummaryMini(
                'Excellent',
                excellent,
                const Color(0xFF1E9D69),
              ),
              _ratingSummaryMini('Low', low, const Color(0xFFD83A59)),
              _ratingSummaryMini('Total', _ratings.length, _teal),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ratingSummaryMini(String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF718388),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingFilterTabs() {
    final options = [
      ('all', 'All (${_ratings.length})'),
      (
        'excellent',
        '5 Stars (${_ratings.where((r) => _int(r['stars']) >= 5).length})',
      ),
      ('low', 'Low (${_ratings.where((r) => _int(r['stars']) <= 2).length})'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in options) ...[
            _ratingChip(option.$1, option.$2),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _ratingChip(String value, String label) {
    final selected = _ratingFilter == value;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _ratingFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _teal : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? _teal : const Color(0xFFDCEDEB)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _teal,
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _financePage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      children: [
        _financeTopBar(),
        const SizedBox(height: 16),
        _financeSummaryStrip(),
        const SizedBox(height: 16),
        _financeSectionTabs(),
        const SizedBox(height: 16),
        if (_financeTab == 0) ..._financePricingSection(),
        if (_financeTab == 1) ..._financeTransactionsSection(),
        if (_financeTab == 2) ..._financePayoutsSection(),
        if (_financeTab == 3) ..._financeWalletsSection(),
      ],
    );
  }

  Widget _financeTopBar() {
    return Row(
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: () => setState(() => _tabIndex = 0),
          icon: const Icon(Icons.arrow_back_rounded, color: _teal, size: 21),
        ),
        Expanded(
          child: Text(
            _financeTitle(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Language',
          onPressed: () {},
          icon: const Icon(Icons.language_rounded, color: _teal, size: 20),
        ),
        IconButton(
          tooltip: 'Theme',
          onPressed: () {},
          icon: const Icon(Icons.dark_mode_rounded, color: _teal, size: 19),
        ),
      ],
    );
  }

  String _financeTitle() {
    switch (_financeTab) {
      case 1:
        return 'Transactions';
      case 2:
        return 'Payment Requests';
      case 3:
        return 'Nurse Earnings Details';
      default:
        return 'Service Pricing Manager';
    }
  }

  Widget _financeSummaryStrip() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2F0EE)),
        boxShadow: _softDashboardShadow,
      ),
      child: Row(
        children: [
          _financeStripItem(
            'Revenue',
            _money(_financeOverview['totalRevenue']),
          ),
          _financeStripItem(
            'Profit',
            _money(_financeOverview['platformProfit']),
          ),
          _financeStripItem(
            'Pending',
            _money(_financeOverview['pendingEscrow']),
          ),
        ],
      ),
    );
  }

  Widget _financeStripItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF738488),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ink,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _financeSectionTabs() {
    final tabs = const [
      ('Active Services', Icons.sell_outlined),
      ('Transactions', Icons.receipt_long_outlined),
      ('Requests', Icons.payments_outlined),
      ('Earnings', Icons.account_balance_wallet_outlined),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            _financeTabChip(i, tabs[i].$1, tabs[i].$2),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _financeTabChip(int index, String label, IconData icon) {
    final selected = _financeTab == index;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _financeTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _teal : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? _teal : const Color(0xFFDCEDEB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : _teal),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : _ink,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _financePricingSection() {
    return [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Set prices for each service. These will be shown to patients.',
              style: TextStyle(
                color: Color(0xFF718388),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => _editPricing(),
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text(
              'Add',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (_pricing.isEmpty)
        _empty('No pricing rules yet')
      else
        ..._pricing.map(_servicePricingTile),
    ];
  }

  List<Widget> _financeTransactionsSection() {
    final paidTransactions = _transactions
        .where((t) => _text(t['paymentStatus']).toLowerCase() == 'paid')
        .toList();
    final refundTransactions = _transactions.where((t) {
      final paymentStatus = _text(t['paymentStatus']).toLowerCase();
      final escrowStatus = _text(t['escrowStatus']).toLowerCase();
      return paymentStatus.contains('refund') ||
          escrowStatus.contains('refund');
    }).toList();
    final visibleTransactions = _transactionFilter == 'paid'
        ? paidTransactions
        : _transactionFilter == 'refunds'
        ? refundTransactions
        : _transactions;

    return [
      _financeMiniFilterBar(
        [
          ('all', 'All (${_transactions.length})'),
          ('paid', 'Paid (${paidTransactions.length})'),
          ('refunds', 'Refunds (${refundTransactions.length})'),
        ],
        selected: _transactionFilter,
        onSelected: (value) => setState(() => _transactionFilter = value),
      ),
      const SizedBox(height: 12),
      if (visibleTransactions.isEmpty)
        _empty(
          _transactionFilter == 'paid'
              ? 'No paid transactions yet'
              : _transactionFilter == 'refunds'
              ? 'No refunds yet'
              : 'No financial transactions yet',
        )
      else
        ...visibleTransactions.take(30).map(_financeTransactionTile),
    ];
  }

  List<Widget> _financePayoutsSection() {
    final pending = _payouts
        .where((p) => _text(p['status']).toLowerCase() == 'requested')
        .toList();
    final approved = _payouts
        .where((p) => _text(p['status']).toLowerCase() == 'paid')
        .toList();
    final rejected = _payouts
        .where((p) => _text(p['status']).toLowerCase() == 'rejected')
        .toList();
    final visiblePayouts = _payoutFilter == 'pending'
        ? pending
        : _payoutFilter == 'approved'
        ? approved
        : _payoutFilter == 'rejected'
        ? rejected
        : _payouts;

    return [
      _financeMiniFilterBar(
        [
          ('all', 'All (${_payouts.length})'),
          ('pending', 'Pending (${pending.length})'),
          ('approved', 'Approved (${approved.length})'),
          ('rejected', 'Rejected (${rejected.length})'),
        ],
        selected: _payoutFilter,
        onSelected: (value) => setState(() => _payoutFilter = value),
      ),
      const SizedBox(height: 12),
      if (visiblePayouts.isEmpty)
        _empty('No payout requests match this filter')
      else
        ...visiblePayouts.take(30).map(_paymentRequestTile),
    ];
  }

  List<Widget> _financeWalletsSection() {
    return [
      if (_wallets.isEmpty)
        _empty('No provider wallets yet')
      else
        ..._wallets.take(30).map(_earningsDetailsTile),
    ];
  }

  Widget _financeMiniFilterBar(
    List<(String, String)> options, {
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in options) ...[
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onSelected(option.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: selected == option.$1
                      ? _teal
                      : const Color(0xFFE9F8F6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  option.$2,
                  style: TextStyle(
                    color: selected == option.$1 ? Colors.white : _teal,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _pricingPage() {
    return _page(
      title: 'Pricing',
      subtitle: 'Set provider rates and admin commissions',
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _teal),
            onPressed: () => _editPricing(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Pricing'),
          ),
        ),
        const SizedBox(height: 12),
        if (_pricing.isEmpty)
          _empty('No pricing rules yet')
        else
          ..._pricing.map(_pricingCard),
      ],
    );
  }

  Widget _page({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _heroHeader(title, subtitle),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _heroHeader(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: const BoxDecoration(
        color: _darkTeal,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(2),
          bottomRight: Radius.circular(2),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Log out',
            onPressed: () {
              appNavigatorKey.currentState?.pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'CareLink - Admin Dashboard',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(width: 18),
          CircleAvatar(
            backgroundColor: Colors.white.withValues(alpha: 0.16),
            child: IconButton(
              tooltip: 'Refresh',
              onPressed: _load,
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminTopBar() {
    return Row(
      children: [
        IconButton(
          tooltip: 'Menu',
          onPressed: () {},
          icon: const Icon(Icons.menu_rounded, color: _teal, size: 20),
        ),
        const Spacer(),
        const Text(
          'Admin Dashboard',
          style: TextStyle(
            color: _ink,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _load,
          icon: const Icon(Icons.notifications_none_rounded, color: _teal),
        ),
      ],
    );
  }

  Widget _adminWelcomeCard() {
    final firstName = widget.user.fullName.trim().isEmpty
        ? 'Admin'
        : widget.user.fullName.trim().split(RegExp(r'\s+')).first;
    return Row(
      children: [
        Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            color: const Color(0xFFE2F4F1),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Positioned(
                bottom: 8,
                child: Icon(
                  Icons.local_hospital_rounded,
                  color: _teal,
                  size: 54,
                ),
              ),
              Positioned(
                top: 12,
                child: CircleAvatar(
                  radius: 21,
                  backgroundColor: Colors.white,
                  child: Text(
                    _initials(widget.user.fullName),
                    style: const TextStyle(
                      color: _darkTeal,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, $firstName',
                style: const TextStyle(
                  color: _ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Super Administrator',
                style: TextStyle(
                  color: _teal,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              const Icon(
                Icons.verified_rounded,
                color: Color(0xFFFFC44D),
                size: 17,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bookingReviewShortcut() {
    final count = _bookingReviewItems.length;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _openBookingReview,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDDEDEA)),
          boxShadow: _softDashboardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE7F6F3),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.gavel_rounded, color: _darkTeal),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Booking Review',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    count == 0
                        ? 'Nurse review queue is clear'
                        : '$count nurse booking${count == 1 ? '' : 's'} need action',
                    style: const TextStyle(
                      color: Color(0xFF6B7C86),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (count > 0) ...[
              _pill('$count', const Color(0xFFE7FAF4), _teal),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right_rounded, color: _darkTeal),
          ],
        ),
      ),
    );
  }

  Widget _dashboardSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _ink,
        fontSize: 13,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _dashboardMetricCard({
    required String title,
    required String value,
    required String trend,
    required bool positive,
  }) {
    final trendColor = positive
        ? const Color(0xFF14A56A)
        : const Color(0xFFE03131);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        boxShadow: _softDashboardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF6E7D83),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: _ink,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                positive
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                color: trendColor,
                size: 13,
              ),
              const SizedBox(width: 3),
              Text(
                trend,
                style: TextStyle(
                  color: trendColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _financeOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: _softDashboardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Finance Overview (Escrow)',
                style: TextStyle(
                  color: _ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                'This Month',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _muted,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _financeMini(
                  'Total Revenue (Paid)',
                  _money(_financeOverview['totalRevenue']),
                  '+ 10%',
                  true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _financeMini(
                  'Paid to Providers',
                  _money(_financeOverview['releasedToProviders']),
                  '+ 5%',
                  true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _financeMini(
                  'Platform Profit',
                  _money(_financeOverview['platformProfit']),
                  '+ 4%',
                  true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _financeMini(
                  'Pending Escrow',
                  _money(_financeOverview['pendingEscrow']),
                  '+ 5%',
                  false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _financeMini(String label, String value, String trend, bool positive) {
    final trendColor = positive
        ? const Color(0xFF14A56A)
        : const Color(0xFFB9770E);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF7C8A8F),
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _ink,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Icon(
              positive
                  ? Icons.arrow_upward_rounded
                  : Icons.warning_amber_rounded,
              color: trendColor,
              size: 13,
            ),
            const SizedBox(width: 3),
            Text(
              trend,
              style: TextStyle(
                color: trendColor,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _requestsByStatusCard() {
    final completed = _int(_metrics['completedRequests']);
    final pending = _int(_metrics['pendingRequests']);
    final cancelled = _int(_metrics['cancelledRequests']);
    final total = _int(_metrics['totalRequests']);
    final inProgress = (total - completed - pending - cancelled).clamp(
      0,
      total,
    );
    final slices = [
      _StatusSlice('Completed', completed, const Color(0xFF00A887)),
      _StatusSlice('In Progress', inProgress, const Color(0xFF1B8CFF)),
      _StatusSlice('Pending', pending, const Color(0xFFFFC107)),
      _StatusSlice('Cancelled', cancelled, const Color(0xFFE53935)),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: _softDashboardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Requests by Status',
            style: TextStyle(
              color: _ink,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 132,
                height: 132,
                child: CustomPaint(
                  painter: _DonutChartPainter(slices),
                  child: Center(
                    child: Text(
                      _compactNumber(total),
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: slices
                      .map((slice) => _statusLegend(slice, total))
                      .toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statisticsPage() {
    final filteredUsers = _statsRows(_users, const ['createdAt']);
    final users = filteredUsers.isEmpty ? _users : filteredUsers;
    final requests = _statsRows(_serviceRequests, const [
      'scheduledAt',
      'createdAt',
    ]);
    final ratings = _statsRows(_ratings, const ['createdAt']);
    final transactions = _statsRows(_transactions, const ['createdAt']);
    final payouts = _statsRows(_payouts, const ['createdAt']);
    final reviews = _statsRows(_bookingReviewItems, const [
      'scheduledAt',
      'createdAt',
    ]);
    final totalProviders = users
        .where((u) => ['nurse', 'doctor'].contains(_text(u['role'])))
        .length;
    final totalPatients = users
        .where((u) => _text(u['role']) == 'patient')
        .length;
    final totalRevenue = transactions.fold<double>(
      0,
      (sum, item) => sum + _num(item['totalAmount'] ?? item['amount']),
    );
    final averageRating = ratings.isEmpty
        ? 0.0
        : ratings.fold<double>(0, (sum, item) => sum + _num(item['stars'])) /
              ratings.length;
    final totalSessions = requests.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      children: [
        _statisticsTopBar(),
        const SizedBox(height: 14),
        _statisticsFiltersCard(),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.42,
          children: [
            _statisticsMetricCard(
              icon: Icons.groups_rounded,
              iconColor: const Color(0xFF16A34A),
              iconBg: const Color(0xFFE6F8EC),
              title: 'Total Users',
              value: _compactNumber(users.length),
              trend: '12%',
            ),
            _statisticsMetricCard(
              icon: Icons.medical_services_outlined,
              iconColor: const Color(0xFF147AD6),
              iconBg: const Color(0xFFE8F2FF),
              title: 'Total Providers',
              value: _compactNumber(totalProviders),
              trend: '8%',
            ),
            _statisticsMetricCard(
              icon: Icons.person_outline_rounded,
              iconColor: const Color(0xFF9333EA),
              iconBg: const Color(0xFFF3E8FF),
              title: 'Total Patients',
              value: _compactNumber(totalPatients),
              trend: '10%',
            ),
            _statisticsMetricCard(
              icon: Icons.calendar_month_rounded,
              iconColor: const Color(0xFFF97316),
              iconBg: const Color(0xFFFFF1E6),
              title: 'Total Sessions',
              value: _compactNumber(totalSessions),
              trend: '15%',
            ),
            _statisticsMetricCard(
              icon: Icons.paid_outlined,
              iconColor: const Color(0xFFEAB308),
              iconBg: const Color(0xFFFFF8DB),
              title: 'Total Revenue',
              value: _money(totalRevenue),
              trend: '10%',
            ),
            _statisticsMetricCard(
              icon: Icons.star_rounded,
              iconColor: const Color(0xFF0F766E),
              iconBg: const Color(0xFFE0F5F2),
              title: 'Average Rating',
              value: '${averageRating.toStringAsFixed(1)} / 5',
              trend: '5%',
            ),
          ],
        ),
        const SizedBox(height: 14),
        _statisticsRevenueCard(totalRevenue),
        const SizedBox(height: 14),
        _statisticsSessionsCard(requests, reviews),
        const SizedBox(height: 14),
        _statisticsServicesCard(requests),
        const SizedBox(height: 14),
        _statisticsTopProvidersCard(payouts),
        const SizedBox(height: 14),
        _statisticsRatingCard(ratings),
        const SizedBox(height: 14),
        _statisticsPaymentCard(transactions, payouts, reviews),
      ],
    );
  }

  Widget _statisticsTopBar() {
    return Row(
      children: [
        IconButton(
          tooltip: 'Menu',
          onPressed: () {},
          icon: const Icon(Icons.menu_rounded, color: _teal, size: 22),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Statistics',
                style: TextStyle(
                  color: _ink,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Overview & key metrics',
                style: TextStyle(
                  color: _muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _load,
          icon: const Icon(Icons.notifications_none_rounded, color: _ink),
        ),
      ],
    );
  }

  Widget _statisticsFiltersCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EFEE)),
        boxShadow: _softDashboardShadow,
      ),
      child: Row(
        children: [
          _statisticsRangeButton(),
          const Spacer(),
          _statisticsFilterButton(Icons.filter_list_rounded, 'Filters'),
        ],
      ),
    );
  }

  Widget _statisticsRangeButton() {
    return PopupMenuButton<String>(
      initialValue: _statisticsRange,
      onSelected: (value) => setState(() => _statisticsRange = value),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'This Month', child: Text('This Month')),
        PopupMenuItem(value: 'This Week', child: Text('This Week')),
        PopupMenuItem(value: 'This Year', child: Text('This Year')),
      ],
      child: _statisticsFilterButton(
        Icons.calendar_month_outlined,
        _statisticsRange,
        showArrow: true,
      ),
    );
  }

  Widget _statisticsFilterButton(
    IconData icon,
    String label, {
    bool showArrow = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE6EFEE)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _ink, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: _ink,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (showArrow) ...[
            const SizedBox(width: 5),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
          ],
        ],
      ),
    );
  }

  Widget _statisticsMetricCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String value,
    required String trend,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EFEE)),
        boxShadow: _softDashboardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.arrow_upward_rounded,
                      color: Color(0xFF16A34A),
                      size: 12,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      trend,
                      style: const TextStyle(
                        color: Color(0xFF16A34A),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'from last month',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statisticsRevenueCard(double revenue) {
    final points = _trendPoints(revenue <= 0 ? 23850 : revenue);
    return _statisticsPanel(
      title: 'Revenue Overview',
      trailing: _smallSelect('Monthly'),
      child: SizedBox(
        height: 170,
        child: CustomPaint(
          painter: _LineChartPainter(points, _teal),
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 38),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _teal,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'This Month\n${_money(revenue)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    height: 1.3,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statisticsSessionsCard(
    List<Map<String, dynamic>> requests,
    List<Map<String, dynamic>> reviews,
  ) {
    final completed = requests
        .where((r) => _serviceStatusGroup(_text(r['status'])) == 'completed')
        .length;
    final pending = requests
        .where((r) => _serviceStatusGroup(_text(r['status'])) == 'pending')
        .length;
    final cancelled = requests
        .where((r) => _serviceStatusGroup(_text(r['status'])) == 'cancelled')
        .length;
    final total = requests.length;
    final noShow = reviews.length;
    final slices = [
      _StatusSlice('Completed', completed, _teal),
      _StatusSlice('Pending', pending, const Color(0xFFFFC107)),
      _StatusSlice('Cancelled', cancelled, const Color(0xFFE53935)),
      _StatusSlice('No Show', noShow, const Color(0xFFB5C0CA)),
    ];
    return _statisticsPanel(
      title: 'Sessions Statistics',
      child: Row(
        children: [
          SizedBox(
            width: 132,
            height: 132,
            child: CustomPaint(painter: _DonutChartPainter(slices)),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              children: slices
                  .map((slice) => _statusLegend(slice, total + noShow))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statisticsServicesCard(List<Map<String, dynamic>> requests) {
    final counts = <String, int>{};
    for (final request in requests) {
      final name = _text(request['serviceType'], fallback: 'Home Nursing Care');
      counts[name] = (counts[name] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.isEmpty
        ? [
            const MapEntry('Elderly Care', 35),
            const MapEntry('Home Nursing Care', 25),
            const MapEntry('Wound Care', 10),
          ]
        : entries.take(5).toList();
    final maxValue = top.map((e) => e.value).fold<int>(1, math.max);
    return _statisticsPanel(
      title: 'Most Requested Services',
      trailing: _smallSelect('Top 5'),
      child: Column(
        children: [
          for (final item in top)
            _serviceBarRow(item.key, item.value, maxValue),
        ],
      ),
    );
  }

  Widget _statisticsTopProvidersCard(List<Map<String, dynamic>> payouts) {
    final providers = payouts.isNotEmpty ? payouts : <Map<String, dynamic>>[];
    return _statisticsPanel(
      title: 'Top Providers Performance',
      trailing: TextButton(
        onPressed: () => setState(() => _tabIndex = 2),
        child: const Text('View All'),
      ),
      child: Column(
        children: [
          for (final item in providers.take(5))
            _topProviderRow(
              name: _text(item['providerName'], fallback: 'Provider'),
              subtitle: _text(
                item['specialization'],
                fallback: 'Care Provider',
              ),
              sessions: _int(item['completedSessions'] ?? item['sessions']),
              rating: _num(item['rating'] ?? _metrics['averageStars']),
              earnings: _money(item['netAmount'] ?? item['balance'] ?? 0),
            ),
          if (providers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Provider performance appears here after completed sessions.',
                style: TextStyle(color: _muted, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statisticsRatingCard(List<Map<String, dynamic>> ratings) {
    final total = ratings.length;
    final five = ratings.where((r) => _int(r['stars']) >= 5).length;
    final four = ratings.where((r) => _int(r['stars']) == 4).length;
    final three = ratings.where((r) => _int(r['stars']) == 3).length;
    final low = ratings.where((r) => _int(r['stars']) <= 2).length;
    final slices = [
      _StatusSlice('5 Stars', five, _teal),
      _StatusSlice('4 Stars', four, const Color(0xFFFFC107)),
      _StatusSlice('3 Stars', three, const Color(0xFFE53935)),
      _StatusSlice('2-1 Stars', low, const Color(0xFFB5C0CA)),
    ];
    return _statisticsPanel(
      title: 'Rating Statistics',
      child: Row(
        children: [
          SizedBox(
            width: 118,
            height: 118,
            child: CustomPaint(painter: _DonutChartPainter(slices)),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              children: slices.map((s) => _statusLegend(s, total)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statisticsPaymentCard(
    List<Map<String, dynamic>> transactions,
    List<Map<String, dynamic>> payouts,
    List<Map<String, dynamic>> reviews,
  ) {
    final platformProfit = transactions.fold<double>(
      0,
      (sum, item) => sum + _num(item['adminShare']),
    );
    return _statisticsPanel(
      title: 'Payment Statistics',
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.35,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: [
          _paymentStat(
            Icons.payments_outlined,
            'Payments Completed',
            _compactNumber(transactions.length),
            const Color(0xFF16A34A),
          ),
          _paymentStat(
            Icons.replay_rounded,
            'Refunds',
            _compactNumber(reviews.length),
            const Color(0xFF9333EA),
          ),
          _paymentStat(
            Icons.pending_actions_rounded,
            'Pending Payouts',
            _compactNumber(payouts.length),
            const Color(0xFFF97316),
          ),
          _paymentStat(
            Icons.account_balance_wallet_outlined,
            'Platform Profit',
            _money(platformProfit),
            _teal,
          ),
        ],
      ),
    );
  }

  Widget _statisticsPanel({
    required String title,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE6EFEE)),
        boxShadow: _softDashboardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _smallSelect(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFE6EFEE)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
          ),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 14),
        ],
      ),
    );
  }

  Widget _serviceBarRow(String label, int value, int maxValue) {
    final percent = maxValue <= 0 ? 0.0 : value / maxValue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: percent.clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: const Color(0xFFEAF0F2),
                valueColor: const AlwaysStoppedAnimation<Color>(_teal),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$value',
            style: const TextStyle(
              color: _ink,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _topProviderRow({
    required String name,
    required String subtitle,
    required int sessions,
    required double rating,
    required String earnings,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _teal.withValues(alpha: 0.14),
            child: Text(
              _initials(name),
              style: const TextStyle(
                color: _teal,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$sessions',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 14),
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                color: Color(0xFFFFC107),
                size: 14,
              ),
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Text(
            earnings,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _paymentStat(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  List<double> _trendPoints(double target) {
    final base = target <= 0 ? 1000.0 : target / 8;
    return [
      base,
      base * 2.6,
      base * 4.2,
      base * 2.8,
      base * 5.8,
      base * 5.0,
      base * 7.4,
      target,
    ];
  }

  Widget _statusLegend(_StatusSlice slice, int total) {
    final percent = total <= 0 ? 0 : ((slice.value / total) * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: slice.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              slice.label,
              style: const TextStyle(
                color: _ink,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            '${slice.value} ($percent%)',
            style: const TextStyle(
              color: _muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _statCard(String title, String value, String badge) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
        boxShadow: _shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: _ink,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: _pill(badge, const Color(0xFFE7FAF4), _teal),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _performancePanel() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _teal,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Row(
            children: [
              Icon(Icons.monitor_heart_rounded, color: Colors.white),
              Spacer(),
              Text(
                'Performance Indicators',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _miniPerf('Completed Requests', _n('completedRequests')),
              const SizedBox(width: 8),
              _miniPerf('Average Rating', _decimal('averageStars')),
              const SizedBox(width: 8),
              _miniPerf('Pending Requests', _n('pendingRequests')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniPerf(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _requestCard(Map<String, dynamic> item) {
    final status = _text(item['approvalStatus'], fallback: 'pending');
    final role = _text(item['role']);
    final total = _int(item['certificationCount']);
    final verified = _int(item['verifiedCertificationCount']);
    final documents = _int(item['documentCount']);
    final tier = _text(item['experienceTier'], fallback: 'junior');
    return _whitePanel(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                _avatar(_initials(item['fullName']), _roleColor(role)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _text(item['fullName']),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${_roleLabel(role)} - ${_text(item['specialization'])}',
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                _pill(
                  _statusLabel(status),
                  _statusBg(status),
                  _statusFg(status),
                ),
              ],
            ),
            const Divider(height: 24, color: _line),
            Row(
              children: [
                _smallMeta(
                  Icons.location_on_outlined,
                  _text(item['providerAddress'], fallback: 'Not set'),
                ),
                const Spacer(),
                _smallMeta(
                  Icons.workspace_premium_outlined,
                  '$verified of $total certificates',
                ),
                const Spacer(),
                _smallMeta(Icons.description_outlined, '$documents docs'),
                const Spacer(),
                _smallMeta(Icons.trending_up_rounded, tier.toUpperCase()),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showCertifications(item),
                    child: const Text('Certificates'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: status == 'rejected'
                        ? null
                        : () => _setApproval(item, 'rejected'),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: _teal),
                    onPressed: status == 'approved'
                        ? null
                        : () => _setApproval(item, 'approved'),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _providersTopBar() {
    return Row(
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: () => setState(() => _tabIndex = 0),
          icon: const Icon(Icons.arrow_back_rounded, color: _teal, size: 21),
        ),
        const Spacer(),
        const Text(
          'Provider Requests',
          style: TextStyle(
            color: _ink,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Language',
          onPressed: () {},
          icon: const Icon(Icons.language_rounded, color: _teal, size: 20),
        ),
        IconButton(
          tooltip: 'Theme',
          onPressed: () {},
          icon: const Icon(Icons.dark_mode_rounded, color: _teal, size: 19),
        ),
      ],
    );
  }

  Widget _providerStatusTabs() {
    final options = [
      ('all', 'All', _requests.length),
      (
        'pending',
        'Pending',
        _requests
            .where(
              (r) =>
                  _text(r['approvalStatus'], fallback: 'pending') == 'pending',
            )
            .length,
      ),
      (
        'approved',
        'Approved',
        _requests
            .where(
              (r) =>
                  _text(r['approvalStatus'], fallback: 'pending') == 'approved',
            )
            .length,
      ),
      (
        'rejected',
        'Rejected',
        _requests
            .where(
              (r) =>
                  _text(r['approvalStatus'], fallback: 'pending') == 'rejected',
            )
            .length,
      ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in options) ...[
            _providerStatusChip(option.$1, '${option.$2} (${option.$3})'),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _providerStatusChip(String value, String label) {
    final selected = _providerFilter == value;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => setState(() => _providerFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _teal : const Color(0xFFE9F8F6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? _teal : const Color(0xFFD9EEEC)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _teal,
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _providerRequestTile(Map<String, dynamic> provider) {
    final role = _text(provider['role']);
    final status = _text(provider['approvalStatus'], fallback: 'pending');
    final rating = _num(provider['overallRating']);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3F0EE)),
        boxShadow: _softDashboardShadow,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _providerPhoto(provider),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text(provider['fullName']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _roleLabel(role),
                      style: const TextStyle(
                        color: Color(0xFF63777B),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFF2B134),
                          size: 15,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Applied on ${_shortDate(provider['createdAt'])}',
                      style: const TextStyle(
                        color: Color(0xFF9AA8AB),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _providerStatusPill(status),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _teal,
                    side: const BorderSide(color: Color(0xFFCDE7E4)),
                    textStyle: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _showProviderDetails(provider),
                  child: const Text('View Details'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _teal,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _showProviderReview(provider),
                  child: const Text('Review'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _providerPhoto(Map<String, dynamic> provider) {
    final role = _text(provider['role']);
    return CircleAvatar(
      radius: 24,
      backgroundColor: _roleColor(role).withValues(alpha: 0.15),
      child: Text(
        _initials(provider['fullName']),
        style: TextStyle(
          color: _roleColor(role),
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _providerStatusPill(String status) {
    final pending = status == 'pending';
    final approved = status == 'approved';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: approved
            ? const Color(0xFFE3F8EF)
            : pending
            ? const Color(0xFFFFF5DA)
            : const Color(0xFFFFE8EE),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        approved
            ? 'Approved'
            : pending
            ? 'Pending'
            : 'Rejected',
        style: TextStyle(
          color: approved
              ? const Color(0xFF1E9D69)
              : pending
              ? const Color(0xFFD28A00)
              : const Color(0xFFD83A59),
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _userCard(Map<String, dynamic> user) {
    final active = user['isActive'] == true;
    final role = _text(user['role']);
    return _whitePanel(
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            leading: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) {
                if (value == 'edit') _editUser(user);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit details')),
              ],
            ),
            title: Text(
              _text(user['fullName']),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              '${_roleLabel(role)} - ${_text(user['email'])}\n${_text(user['phone'])}',
              textAlign: TextAlign.right,
            ),
            trailing: _avatar(_initials(user['fullName']), _roleColor(role)),
            isThreeLine: true,
            horizontalTitleGap: 10,
            onTap: () => _editUser(user),
            dense: false,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            minLeadingWidth: 34,
            visualDensity: VisualDensity.compact,
            enabled: true,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                Switch(
                  value: active,
                  activeThumbColor: _teal,
                  onChanged: (value) => _setUserActive(user, value),
                ),
                const Spacer(),
                _pill(
                  active ? 'Active' : 'Disabled',
                  active ? const Color(0xFFE3F8EF) : const Color(0xFFFFE6ED),
                  active ? const Color(0xFF1E9D69) : const Color(0xFFD83A59),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _usersTopBar() {
    return Row(
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: () => setState(() => _tabIndex = 0),
          icon: const Icon(Icons.arrow_back_rounded, color: _teal, size: 21),
        ),
        const Spacer(),
        const Text(
          'Users Management',
          style: TextStyle(
            color: _ink,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Language',
          onPressed: () {},
          icon: const Icon(Icons.language_rounded, color: _teal, size: 20),
        ),
        IconButton(
          tooltip: 'Theme',
          onPressed: () {},
          icon: const Icon(Icons.dark_mode_rounded, color: _teal, size: 19),
        ),
      ],
    );
  }

  Widget _usersRoleTabs() {
    final options = [
      ('all', 'All', _users.length),
      (
        'patient',
        'Patients',
        _users.where((u) => _text(u['role']) == 'patient').length,
      ),
      (
        'nurse',
        'Nurses',
        _users.where((u) => _text(u['role']) == 'nurse').length,
      ),
      (
        'doctor',
        'Doctors',
        _users.where((u) => _text(u['role']) == 'doctor').length,
      ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in options) ...[
            _userRoleChip(option.$1, '${option.$2} (${option.$3})'),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _userRoleChip(String value, String label) {
    final selected = _userFilter == value;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => setState(() => _userFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _teal : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? _teal : const Color(0xFFE5F0EF)),
          boxShadow: selected ? _softDashboardShadow : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _ink,
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _userListRow(Map<String, dynamic> user) {
    final active = user['isActive'] == true;
    final role = _text(user['role']);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _editUser(user),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _roleColor(role).withValues(alpha: 0.15),
                child: Text(
                  _initials(user['fullName']),
                  style: TextStyle(
                    color: _roleColor(role),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text(user['fullName']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _roleLabel(role),
                      style: const TextStyle(
                        color: Color(0xFF7A8A8E),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                active ? 'Active' : 'Inactive',
                style: TextStyle(
                  color: active
                      ? const Color(0xFF1E9D69)
                      : const Color(0xFFD83A59),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 58,
                child: Text(
                  _shortDate(user['createdAt']),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Color(0xFF9AA8AB),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ratingCard(Map<String, dynamic> rating) {
    final stars = _int(rating['stars']);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2F0EE)),
        boxShadow: _softDashboardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _teal.withValues(alpha: 0.13),
                child: Text(
                  _initials(rating['patientName']),
                  style: const TextStyle(
                    color: _teal,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text(rating['providerName'], fallback: 'Provider'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Patient: ${_text(rating['patientName'], fallback: '-')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF718388),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _stars(stars),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FBFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE7F2F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.medical_services_outlined,
                      color: _teal,
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        _text(rating['serviceType'], fallback: 'Service'),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      _shortDate(rating['createdAt']),
                      style: const TextStyle(
                        color: Color(0xFF9AA8AB),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  _text(rating['comment'], fallback: 'No written notes.'),
                  style: const TextStyle(
                    color: _ink,
                    height: 1.35,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _servicePricingTile(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2F0EE)),
        boxShadow: _softDashboardShadow,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _teal.withValues(alpha: 0.13),
            child: Icon(
              _text(item['providerRole']) == 'doctor'
                  ? Icons.medical_services_outlined
                  : Icons.local_hospital_outlined,
              color: _teal,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _text(item['specialization'], fallback: 'Service'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _text(item['providerName'], fallback: 'General consultation'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF718388),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _money(item['patientPrice']),
            style: const TextStyle(
              color: _ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          IconButton(
            tooltip: 'Edit pricing',
            onPressed: () => _editPricing(item),
            icon: const Icon(Icons.edit_rounded, color: _teal, size: 19),
          ),
        ],
      ),
    );
  }

  Widget _financeTransactionTile(Map<String, dynamic> item) {
    final status = _text(item['escrowStatus'], fallback: 'pending');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2F0EE)),
        boxShadow: _softDashboardShadow,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _teal.withValues(alpha: 0.13),
            child: Text(
              _initials(item['providerName']),
              style: const TextStyle(
                color: _teal,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _text(item['providerName'], fallback: 'Provider'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Patient: ${_text(item['patientName'], fallback: '-')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF718388),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _shortDate(item['createdAt']),
                  style: const TextStyle(
                    color: Color(0xFF9AA8AB),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _money(item['totalAmount']),
                style: const TextStyle(
                  color: _ink,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              _financeSmallStatus(
                status == 'transferred_to_provider'
                    ? 'Paid to Nurse'
                    : status == 'paid_to_admin'
                    ? 'Held Wallet'
                    : 'Pending',
              ),
              TextButton(
                onPressed: () => _showPaymentReceipt(item),
                style: TextButton.styleFrom(
                  foregroundColor: _teal,
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                child: const Text('Receipt'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentRequestTile(Map<String, dynamic> item) {
    final status = _text(item['status'], fallback: 'requested').toLowerCase();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2F0EE)),
        boxShadow: _softDashboardShadow,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: _teal.withValues(alpha: 0.13),
            child: Text(
              _initials(item['providerName']),
              style: const TextStyle(
                color: _teal,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _text(item['providerName'], fallback: 'Provider'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_int(item['completedSessions'])} Points',
                  style: const TextStyle(
                    color: Color(0xFF718388),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _money(item['amount']),
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Requested on ${_shortDate(item['createdAt'])}',
                  style: const TextStyle(
                    color: Color(0xFF9AA8AB),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _financeSmallStatus(
                status == 'paid'
                    ? 'Approved'
                    : status == 'rejected'
                    ? 'Rejected'
                    : 'Pending',
              ),
              const SizedBox(height: 10),
              if (status == 'requested' || status == 'approved')
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _teal,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  onPressed: () => _showPayoutApproval(item),
                  child: const Text('Review'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _earningsDetailsTile(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2F0EE)),
        boxShadow: _softDashboardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: _teal.withValues(alpha: 0.13),
                child: Text(
                  _initials(item['providerName']),
                  style: const TextStyle(
                    color: _teal,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text(item['providerName'], fallback: 'Provider'),
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _text(item['providerRole'], fallback: 'Nurse'),
                      style: const TextStyle(
                        color: Color(0xFF718388),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _financeSmallStatus('Active'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _moneyColumn('Total Earnings', item['totalEarned']),
              _moneyColumn('Pending Payout', item['pendingAmount']),
              _moneyColumn('Paid Out', item['paidAmount']),
            ],
          ),
        ],
      ),
    );
  }

  Widget _financeSmallStatus(String text) {
    final lower = text.toLowerCase();
    final color = lower.contains('reject')
        ? const Color(0xFFD83A59)
        : lower.contains('pending') || lower.contains('held')
        ? const Color(0xFFD28A00)
        : const Color(0xFF1E9D69);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _pricingCard(Map<String, dynamic> item) {
    final status = _text(item['rateAcceptanceStatus'], fallback: 'pending');
    return _whitePanel(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Edit pricing',
                  onPressed: () => _editPricing(item),
                  icon: const Icon(Icons.edit_rounded, color: _teal),
                ),
                const Spacer(),
                Expanded(
                  child: Text(
                    _text(
                      item['providerName'],
                      fallback: 'Unassigned provider',
                    ),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 8),
                _pill(
                  _rateStatusLabel(status),
                  _statusBg(status == 'accepted' ? 'approved' : status),
                  _statusFg(status == 'accepted' ? 'approved' : status),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_roleLabel(_text(item['providerRole']))} - ${_text(item['specialization'], fallback: 'Service')}',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            const Divider(height: 22, color: _line),
            Row(
              children: [
                _moneyColumn('Provider Rate', item['providerRate']),
                _moneyColumn('Admin Commission', item['adminCommission']),
                _moneyColumn('Patient Price', item['patientPrice']),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _payoutCard(Map<String, dynamic> item) {
    final status = _text(item['status'], fallback: 'requested').toLowerCase();
    final actionable = status == 'requested' || status == 'approved';
    return _whitePanel(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                _pill(status, const Color(0xFFE7FAF4), _teal),
                const Spacer(),
                Expanded(
                  child: Text(
                    _text(item['providerName'], fallback: 'Provider'),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_money(item['amount'])} - ${_text(item['specialization'], fallback: 'Service')}',
              style: const TextStyle(color: _muted),
            ),
            if (actionable) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _setPayoutStatus(item, 'reject'),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: _teal),
                      onPressed: () => _setPayoutStatus(item, 'pay'),
                      child: const Text('Transfer'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _transactionCard(Map<String, dynamic> item) {
    return _whitePanel(
      child: ListTile(
        leading: const Icon(Icons.receipt_long_rounded, color: _teal),
        title: Text(
          _text(item['providerName'], fallback: 'Provider'),
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          'Patient: ${_text(item['patientName'], fallback: '-')}',
          textAlign: TextAlign.right,
        ),
        trailing: Text(
          _money(item['totalAmount']),
          style: const TextStyle(fontWeight: FontWeight.w900, color: _ink),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _walletCard(Map<String, dynamic> item) {
    return _whitePanel(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _text(item['providerName'], fallback: 'Provider'),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _moneyColumn('Total', item['totalEarned']),
                _moneyColumn('Pending', item['pendingAmount']),
                _moneyColumn('Paid', item['paidAmount']),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _moneyColumn(String label, dynamic value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            _money(value),
            style: const TextStyle(fontWeight: FontWeight.w900, color: _ink),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _serviceBar(Map<String, dynamic> item) {
    final count = _int(item['count']);
    final max = _list(
      _performance['services'],
    ).map((e) => _int(e['count'])).fold<int>(1, (a, b) => b > a ? b : a);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Text('$count'),
              const Spacer(),
              Text(_text(item['serviceType'], fallback: 'Service')),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: (count / max).clamp(0.02, 1.0),
            minHeight: 5,
            color: _teal,
            backgroundColor: const Color(0xFFE4F1F0),
            borderRadius: BorderRadius.circular(99),
          ),
        ],
      ),
    );
  }

  Widget _whitePanel({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
        boxShadow: _shadow,
      ),
      child: child,
    );
  }

  // ignore: unused_element
  Widget _filterRow({
    required String value,
    required Map<String, String> options,
    required ValueChanged<String> onChanged,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        children: options.entries.map((entry) {
          final selected = value == entry.key;
          return Padding(
            padding: const EdgeInsetsDirectional.only(start: 8),
            child: SizedBox(
              width: 96,
              child: ChoiceChip(
                selected: selected,
                label: Center(child: Text(entry.value)),
                selectedColor: _teal,
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : _ink,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(color: _line),
                ),
                showCheckmark: false,
                onSelected: (_) => onChanged(entry.key),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _bottomNav() {
    final items = const [
      (Icons.dashboard_outlined, Icons.dashboard_rounded, 'Home'),
      (Icons.person_add_alt_outlined, Icons.person_add_alt_rounded, 'Requests'),
      (Icons.groups_outlined, Icons.groups_rounded, 'Providers'),
      (Icons.people_outline_rounded, Icons.people_alt_rounded, 'Users'),
      (Icons.star_border_rounded, Icons.star_rounded, 'Ratings'),
      (
        Icons.account_balance_wallet_outlined,
        Icons.account_balance_wallet_rounded,
        'Finance',
      ),
      (Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Statistics'),
    ];
    return Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _phoneWidth),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: _line)),
            ),
            child: SafeArea(
              top: false,
              child: BottomNavigationBar(
                currentIndex: _tabIndex,
                onTap: (index) => setState(() => _tabIndex = index),
                type: BottomNavigationBarType.fixed,
                selectedItemColor: _teal,
                unselectedItemColor: const Color(0xFF5C7180),
                backgroundColor: Colors.white,
                elevation: 0,
                selectedFontSize: 11,
                unselectedFontSize: 10,
                iconSize: 22,
                items: [
                  for (var i = 0; i < items.length; i++)
                    BottomNavigationBarItem(
                      icon: Container(
                        width: 34,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _tabIndex == i
                              ? _teal.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(_tabIndex == i ? items[i].$2 : items[i].$1),
                      ),
                      label: items[i].$3,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _sectionHeader(String title, String action, VoidCallback onTap) {
    return Row(
      children: [
        TextButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.chevron_left_rounded, size: 18),
          label: Text(action),
          style: TextButton.styleFrom(foregroundColor: _darkTeal),
        ),
        const Spacer(),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        textAlign: TextAlign.right,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _avatar(String text, Color color) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: color,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _pill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _smallMeta(IconData icon, String text) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _muted, size: 14),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stars(int stars) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < stars ? Icons.star_rounded : Icons.star_border_rounded,
          color: const Color(0xFFF1A72E),
          size: 18,
        ),
      ),
    );
  }

  Widget _empty(String message) => _whitePanel(child: _emptyInline(message));

  Widget _emptyInline(String message) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const Icon(Icons.inbox_rounded, color: _muted),
          const SizedBox(width: 8),
          Expanded(child: Text(message, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Future<void> _showProviderDetails(Map<String, dynamic> provider) async {
    final role = _text(provider['role']);
    await showDialog<void>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.ltr,
        child: AlertDialog(
          title: Text(_text(provider['fullName'])),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailLine('Role', _roleLabel(role)),
                _detailLine(
                  'Specialization',
                  _text(provider['specialization']),
                ),
                _detailLine(
                  'Experience',
                  '${_int(provider['experienceYears'] ?? provider['years_experience'])} years',
                ),
                _detailLine(
                  'Service Area',
                  _text(provider['serviceAreas'], fallback: 'Not set'),
                ),
                _detailLine(
                  'Rating',
                  _num(provider['overallRating']).toStringAsFixed(1),
                ),
                _detailLine(
                  'Status',
                  _statusLabel(
                    _text(provider['approvalStatus'], fallback: 'pending'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showProviderReview(Map<String, dynamic> provider) async {
    final providerId = _text(provider['userId']);
    try {
      final response = await http.get(
        _uri('/admin/providers/$providerId/certifications'),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_message(response));
      }
      final certs = _list(jsonDecode(response.body));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => Directionality(
          textDirection: TextDirection.ltr,
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: _teal,
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'Certification Verification',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Language',
                          onPressed: () {},
                          icon: const Icon(
                            Icons.language_rounded,
                            color: _teal,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _providerPhoto(provider),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _text(provider['fullName']),
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _roleLabel(_text(provider['role'])),
                                style: const TextStyle(
                                  color: Color(0xFF6D7F83),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Applied on ${_shortDate(provider['createdAt'])}',
                                style: const TextStyle(
                                  color: Color(0xFF9AA8AB),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _providerStatusPill(
                          _text(
                            provider['approvalStatus'],
                            fallback: 'pending',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Uploaded Documents',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (certs.isEmpty)
                      _emptyInline('No documents were uploaded')
                    else
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: certs
                              .map((cert) => _providerDocumentTile(cert))
                              .toList(),
                        ),
                      ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFE04F5F),
                              side: const BorderSide(color: Color(0xFFFFCBD2)),
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () async {
                              await _setApproval(provider, 'rejected');
                              if (context.mounted) Navigator.pop(context);
                            },
                            child: const Text(
                              'Reject',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _teal,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () async {
                              await _approveReviewedProvider(provider, certs);
                              if (context.mounted) Navigator.pop(context);
                            },
                            child: const Text(
                              'Approve',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      _toast(e.toString());
    }
  }

  Widget _providerDocumentTile(Map<String, dynamic> cert) {
    final certId = _text(cert['certId'], fallback: '');
    final rawFileUrl = _text(cert['fileUrl'], fallback: '');
    final viewUrl = rawFileUrl.trim().startsWith('data:') && certId.isNotEmpty
        ? _absoluteUploadUrl(
            '/admin/certifications/${Uri.encodeComponent(certId)}/file',
          )
        : _absoluteUploadUrl(rawFileUrl);
    final fileName = _text(
      cert['originalName'],
      fallback: _text(cert['name'], fallback: 'Attached file'),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3EFED)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.insert_drive_file_outlined,
            color: Color(0xFF7B8D91),
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _text(cert['name'], fallback: 'Document'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF7B8D91),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: viewUrl.isEmpty ? null : () => _openUrl(viewUrl),
            style: TextButton.styleFrom(
              foregroundColor: _teal,
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            child: const Text('View'),
          ),
          IconButton(
            tooltip: 'Download',
            onPressed: viewUrl.isEmpty ? null : () => _openUrl(viewUrl),
            icon: const Icon(
              Icons.file_download_outlined,
              color: _teal,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCertifications(Map<String, dynamic> provider) async {
    final providerId = _text(provider['userId']);
    try {
      final response = await http.get(
        _uri('/admin/providers/$providerId/certifications'),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_message(response));
      }
      final certs = _list(jsonDecode(response.body));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => Directionality(
          textDirection: TextDirection.ltr,
          child: AlertDialog(
            title: Text('${_text(provider['fullName'])} Certificates'),
            content: SizedBox(
              width: 520,
              child: certs.isEmpty
                  ? const Text(
                      'No certificates were uploaded for this account.',
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: certs.map((cert) {
                        final verified = cert['isVerified'] == true;
                        final certId = _text(cert['certId']);
                        final rawFileUrl = _text(cert['fileUrl']);
                        final fileUrl = _absoluteUploadUrl(rawFileUrl);
                        final viewUrl =
                            rawFileUrl.trim().startsWith('data:') &&
                                certId.isNotEmpty
                            ? _absoluteUploadUrl(
                                '/admin/certifications/${Uri.encodeComponent(certId)}/file',
                              )
                            : fileUrl;
                        return ListTile(
                          leading: Icon(
                            verified
                                ? Icons.verified_rounded
                                : Icons.pending_rounded,
                            color: verified ? _teal : Colors.orange,
                          ),
                          title: Text(_text(cert['name'])),
                          subtitle: Text(
                            fileUrl.isEmpty
                                ? (verified
                                      ? 'Verified'
                                      : 'Pending verification')
                                : '${verified ? 'Verified' : 'Pending verification'} - ${_text(cert['originalName'], fallback: 'Attached file')}',
                          ),
                          trailing: Wrap(
                            spacing: 6,
                            children: [
                              if (fileUrl.isNotEmpty)
                                OutlinedButton(
                                  onPressed: () => _openUrl(viewUrl),
                                  child: const Text('View file'),
                                ),
                              if (!verified)
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _teal,
                                  ),
                                  onPressed: () async {
                                    await _verifyCertification(
                                      _text(cert['certId']),
                                    );
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  },
                                  child: const Text('Verify'),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _verifyCertification(String certId) async {
    await _verifyCertificationRequest(certId);
    _toast('Certificate verified');
    await _load();
  }

  Future<void> _verifyCertificationRequest(String certId) async {
    final response = await http.put(
      _uri('/admin/certifications/$certId/verify'),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_message(response));
    }
  }

  Future<void> _approveReviewedProvider(
    Map<String, dynamic> provider,
    List<dynamic> certs,
  ) async {
    try {
      for (final cert in certs) {
        if (cert is! Map<String, dynamic>) continue;
        final certId = _text(cert['certId']);
        final alreadyVerified = cert['isVerified'] == true;
        final isDocumentRow = certId.startsWith('document:');
        if (certId.isNotEmpty && !alreadyVerified && !isDocumentRow) {
          await _verifyCertificationRequest(certId);
        }
      }
      await _setApproval(provider, 'approved');
    } catch (e) {
      _toast(e.toString());
    }
  }

  String _absoluteUploadUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('data:')) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return '${ApiService.baseUrl}${trimmed.startsWith('/') ? '' : '/'}$trimmed';
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _toast('Could not open the file');
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _toast('Could not open the file');
    }
  }

  Future<void> _setApproval(
    Map<String, dynamic> provider,
    String status,
  ) async {
    try {
      final response = await http.put(
        _uri('/admin/providers/${provider['userId']}/approval'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'status': status}),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_message(response));
      }
      _toast(status == 'approved' ? 'Account approved' : 'Account rejected');
      await _load();
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _setUserActive(Map<String, dynamic> user, bool active) async {
    try {
      final response = await http.put(
        _uri('/admin/users/${user['userId']}/status'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'isActive': active}),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_message(response));
      }
      _toast(active ? 'User activated' : 'User disabled');
      await _load();
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _setPayoutStatus(
    Map<String, dynamic> payout,
    String action,
  ) async {
    try {
      final response = await http.put(
        _uri('/admin/finance/payouts/${payout['payoutId']}/$action'),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_message(response));
      }
      _toast(
        action == 'reject' ? 'Payout request rejected' : 'Payout transferred',
      );
      await _load();
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _showPayoutApproval(Map<String, dynamic> payout) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.ltr,
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: _teal,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Payout Approval',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: _teal.withValues(alpha: 0.13),
                        child: Text(
                          _initials(payout['providerName']),
                          style: const TextStyle(
                            color: _teal,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _text(
                                payout['providerName'],
                                fallback: 'Provider',
                              ),
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              _text(payout['providerRole'], fallback: 'Nurse'),
                              style: const TextStyle(
                                color: Color(0xFF718388),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Request ID: ${_text(payout['payoutId'])}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF9AA8AB),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _financeSmallStatus('Pending'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _payoutSummaryBox(payout),
                  const SizedBox(height: 14),
                  _payoutBreakdownBox(payout),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _teal,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () async {
                            Navigator.pop(context);
                            await _setPayoutStatus(payout, 'pay');
                            if (mounted) _showPaymentSuccess(payout);
                          },
                          child: const Text(
                            'Approve & Pay',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFE04F5F),
                            side: const BorderSide(color: Color(0xFFFFCBD2)),
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () async {
                            Navigator.pop(context);
                            await _setPayoutStatus(payout, 'reject');
                          },
                          child: const Text(
                            'Reject',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _payoutSummaryBox(Map<String, dynamic> payout) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3F0EE)),
      ),
      child: Column(
        children: [
          _receiptLine(
            'Total Sessions',
            '${_int(payout['completedSessions'])}',
          ),
          _receiptLine('Total Points', '${_int(payout['completedSessions'])}'),
          _receiptLine('Rate per Point', _money(100)),
          _receiptLine('Total Amount', _money(payout['amount']), strong: true),
        ],
      ),
    );
  }

  Widget _payoutBreakdownBox(Map<String, dynamic> payout) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3F0EE)),
      ),
      child: Column(
        children: [
          _receiptLine('Nurse Amount', _money(payout['amount']), green: true),
          _receiptLine('Platform Fee (Admin)', _money(0)),
        ],
      ),
    );
  }

  Future<void> _showPaymentSuccess(Map<String, dynamic> payout) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.ltr,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text('Payment Receipt', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: const Color(0xFFE5F8EF),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF1E9D69),
                  size: 38,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Payment Successful!',
                style: TextStyle(
                  color: Color(0xFF1E9D69),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The payment has been sent to ${_text(payout['providerName'], fallback: 'Provider')}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              _receiptLine(
                'Amount Paid',
                _money(payout['amount']),
                strong: true,
              ),
              _receiptLine(
                'Paid On',
                '${_shortDate(DateTime.now())} - ${_shortTime(DateTime.now())}',
              ),
              _receiptLine('Transaction ID', _text(payout['payoutId'])),
              _receiptLine('Payment Method', 'Platform Wallet'),
              _receiptLine('Status', 'Completed', green: true),
            ],
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _teal),
              onPressed: () => Navigator.pop(context),
              child: const Text('Download Receipt (PDF)'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPaymentReceipt(Map<String, dynamic> item) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Payment Receipt', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _receiptLine('Provider', _text(item['providerName'])),
            _receiptLine('Patient', _text(item['patientName'])),
            _receiptLine(
              'Amount Paid',
              _money(item['totalAmount']),
              strong: true,
            ),
            _receiptLine('Paid On', _shortDate(item['createdAt'])),
            _receiptLine('Transaction ID', _text(item['paymentId'])),
            _receiptLine('Status', _text(item['escrowStatus']), green: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _receiptLine(
    String label,
    String value, {
    bool strong = false,
    bool green = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF718388),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: green ? const Color(0xFF1E9D69) : _ink,
                fontSize: strong ? 12.5 : 11.5,
                fontWeight: strong || green ? FontWeight.w900 : FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _providerById(String providerId) {
    if (providerId.trim().isEmpty) return null;
    for (final user in _users) {
      if (_text(user['userId'], fallback: '') == providerId) return user;
    }
    return null;
  }

  List<Map<String, dynamic>> _providersForService(String serviceType) {
    final seen = <String>{};
    final providers = <Map<String, dynamic>>[];
    for (final user in _users) {
      final role = _text(user['role']).toLowerCase();
      final userId = _text(user['userId'], fallback: '');
      if (role != serviceType || userId.isEmpty || seen.contains(userId)) {
        continue;
      }
      seen.add(userId);
      providers.add(user);
    }
    return providers;
  }

  String _providerSpecialization(Map<String, dynamic>? provider) {
    return _text(
      provider?['specialization'],
      fallback: 'Select provider first',
    );
  }

  String _pricingSpecializationForSave({
    required String serviceType,
    required String selectedSpecialization,
    required String selectedProviderId,
  }) {
    final provider = _providerById(selectedProviderId);
    final providerSpecialization = _providerSpecialization(provider);
    if (provider != null && providerSpecialization != 'Select provider first') {
      return providerSpecialization;
    }
    if (serviceType == 'nurse') return 'Home Nursing Care';
    return selectedSpecialization.trim().isEmpty
        ? 'General Doctor'
        : selectedSpecialization.trim();
  }

  String _providerExperienceLabel(Map<String, dynamic>? provider) {
    if (provider == null) {
      return 'Experience will be auto-filled after selecting a provider';
    }
    final years = _int(
      provider['experienceYears'] ?? provider['years_experience'],
    );
    final rating = _num(provider['overallRating']);
    final yearText = years == 1 ? '1 year' : '$years years';
    return 'Experience: $yearText • Rating: ${rating.toStringAsFixed(1)}';
  }

  Widget _pricingLabel(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            color: _ink,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  InputDecoration _pricingInputDecoration({
    required IconData icon,
    String? hintText,
    String? suffixText,
  }) {
    return InputDecoration(
      hintText: hintText,
      suffixText: suffixText,
      prefixIcon: Icon(icon, color: _teal, size: 21),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _teal, width: 1.4),
      ),
    );
  }

  Future<void> _editPricing([Map<String, dynamic>? item]) async {
    final providerRate = TextEditingController(
      text: item == null ? '' : _num(item['providerRate']).toStringAsFixed(0),
    );
    final savedProviderRate = _num(item?['providerRate']);
    final savedCommission = _num(item?['adminCommission']);
    final commissionPercent = TextEditingController(
      text: item == null || savedProviderRate <= 0
          ? '20'
          : ((savedCommission / savedProviderRate) * 100)
                .clamp(20, double.infinity)
                .toStringAsFixed(0),
    );
    String serviceType = _text(
      item?['providerRole'],
      fallback: 'nurse',
    ).toLowerCase();
    if (serviceType != 'doctor') serviceType = 'nurse';
    String selectedProviderId = item == null
        ? ''
        : _text(item['providerId'], fallback: '');
    String selectedSpecialization = item == null
        ? 'Elderly Care'
        : _text(item['specialization'], fallback: 'Elderly Care');
    const specializations = [
      'Elderly Care',
      'Home Nursing Care',
      'Wound Care',
      'Pediatrics Care',
      'General Doctor',
      'Family Medicine',
      'Cardiology',
    ];
    if (!specializations.contains(selectedSpecialization)) {
      selectedSpecialization = 'Elderly Care';
    }

    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final providers = _providersForService(serviceType);
          final providerIds = providers
              .map((provider) => _text(provider['userId'], fallback: ''))
              .where((id) => id.isNotEmpty)
              .toSet();
          final validSelectedProviderId =
              providerIds.contains(selectedProviderId)
              ? selectedProviderId
              : null;
          final selectedProvider = validSelectedProviderId == null
              ? null
              : _providerById(validSelectedProviderId);
          if (selectedProvider != null) {
            selectedSpecialization = _providerSpecialization(selectedProvider);
          }
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 20,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 470),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Center(
                            child: Text(
                              'Service Pricing & Commission',
                              style: TextStyle(
                                color: _ink,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(context, false),
                          icon: const Icon(Icons.close_rounded, color: _muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _pricingLabel('Service type'),
                    DropdownButtonFormField<String>(
                      initialValue: serviceType,
                      decoration: _pricingInputDecoration(
                        icon: Icons.medical_services_outlined,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'nurse', child: Text('Nurse')),
                        DropdownMenuItem(
                          value: 'doctor',
                          child: Text('Doctor'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          serviceType = value;
                          selectedProviderId = '';
                          selectedSpecialization = value == 'nurse'
                              ? 'Home Nursing Care'
                              : 'General Doctor';
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _pricingLabel('Provider name'),
                    DropdownButtonFormField<String?>(
                      initialValue: validSelectedProviderId,
                      decoration: _pricingInputDecoration(
                        icon: Icons.person_outline_rounded,
                        hintText: 'Select provider',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Select provider'),
                        ),
                        for (final provider in providers)
                          DropdownMenuItem(
                            value: _text(provider['userId'], fallback: ''),
                            child: Text(
                              _text(provider['fullName'], fallback: 'Provider'),
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedProviderId = value ?? '';
                          final provider = _providerById(selectedProviderId);
                          if (provider != null) {
                            selectedSpecialization = _providerSpecialization(
                              provider,
                            );
                          }
                        });
                      },
                    ),
                    if (serviceType == 'doctor') ...[
                      const Center(
                        child: Text(
                          'Optional for commission-only specialization',
                          style: TextStyle(
                            color: Color(0xFF7A8A99),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _pricingLabel('Specialization'),
                      if (selectedProvider != null)
                        TextField(
                          readOnly: true,
                          controller: TextEditingController(
                            text: selectedSpecialization,
                          ),
                          decoration: _pricingInputDecoration(
                            icon: Icons.groups_2_outlined,
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          initialValue:
                              specializations.contains(selectedSpecialization)
                              ? selectedSpecialization
                              : specializations.first,
                          decoration: _pricingInputDecoration(
                            icon: Icons.groups_2_outlined,
                          ),
                          items: [
                            for (final specialization in specializations)
                              DropdownMenuItem(
                                value: specialization,
                                child: Text(specialization),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(
                                () => selectedSpecialization = value,
                              );
                            }
                          },
                        ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      _providerExperienceLabel(selectedProvider),
                      style: const TextStyle(
                        color: Color(0xFF7A8A99),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _pricingLabel('Provider rate (per hour)'),
                    TextField(
                      controller: providerRate,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: _pricingInputDecoration(
                        icon: Icons.attach_money_rounded,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F7F4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () {
                                    final next =
                                        _num(
                                          commissionPercent.text,
                                        ).clamp(20, double.infinity) +
                                        1;
                                    commissionPercent.text = next
                                        .toStringAsFixed(0);
                                    setDialogState(() {});
                                  },
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: _line),
                                    ),
                                    child: const Icon(
                                      Icons.add_rounded,
                                      color: _teal,
                                      size: 26,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: commissionPercent,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) {
                                    if (_num(commissionPercent.text) < 20 &&
                                        commissionPercent.text.isNotEmpty) {
                                      commissionPercent.text = '20';
                                      commissionPercent.selection =
                                          TextSelection.fromPosition(
                                            const TextPosition(offset: 2),
                                          );
                                    }
                                    setDialogState(() {});
                                  },
                                  decoration: _pricingInputDecoration(
                                    icon: Icons.percent_rounded,
                                    hintText: '20',
                                    suffixText: '%',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: _teal,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            icon: const Icon(Icons.save_rounded, size: 18),
                            label: const Text(
                              'Save',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _teal,
                              side: const BorderSide(color: _teal),
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (save != true) {
      providerRate.dispose();
      commissionPercent.dispose();
      return;
    }

    try {
      final specializationForSave = _pricingSpecializationForSave(
        serviceType: serviceType,
        selectedSpecialization: selectedSpecialization,
        selectedProviderId: selectedProviderId,
      );
      final response = await http.put(
        _uri('/admin/finance/pricing'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'providerId': selectedProviderId.trim(),
          'specialization': specializationForSave,
          'serviceType': serviceType,
          'providerRate': providerRate.text.trim(),
          'adminCommissionPercent': commissionPercent.text.trim(),
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_message(response));
      }
      _toast('Pricing saved');
      await _load();
    } catch (e) {
      _toast(e.toString());
    } finally {
      providerRate.dispose();
      commissionPercent.dispose();
    }
  }

  Future<void> _editUser(Map<String, dynamic> user) async {
    final name = TextEditingController(text: _text(user['fullName']));
    final phone = TextEditingController(text: _text(user['phone']));
    final specialization = TextEditingController(
      text: _text(user['specialization']),
    );
    final serviceType = TextEditingController(text: _text(user['serviceType']));
    final address = TextEditingController(text: _text(user['addressText']));

    final save = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.ltr,
        child: AlertDialog(
          title: Text('Edit ${_text(user['fullName'])}'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                TextField(
                  controller: phone,
                  decoration: const InputDecoration(labelText: 'Phone number'),
                ),
                if (_text(user['role']) != 'patient') ...[
                  TextField(
                    controller: specialization,
                    decoration: const InputDecoration(
                      labelText: 'Specialization',
                    ),
                  ),
                  TextField(
                    controller: serviceType,
                    decoration: const InputDecoration(
                      labelText: 'Service type',
                    ),
                  ),
                ],
                if (_text(user['role']) == 'patient')
                  TextField(
                    controller: address,
                    decoration: const InputDecoration(labelText: 'Address'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _teal),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (save != true) return;

    try {
      final response = await http.put(
        _uri('/admin/users/${user['userId']}'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': name.text,
          'phone': phone.text,
          'specialization': specialization.text,
          'serviceType': serviceType.text,
          'addressText': address.text,
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_message(response));
      }
      _toast('User details updated');
      await _load();
    } catch (e) {
      _toast(e.toString());
    } finally {
      name.dispose();
      phone.dispose();
      specialization.dispose();
      serviceType.dispose();
      address.dispose();
    }
  }

  List<Map<String, dynamic>> _statsRows(
    List<Map<String, dynamic>> rows,
    List<String> dateKeys,
  ) {
    return rows.where((row) {
      for (final key in dateKeys) {
        final date = _parseStatsDate(row[key]);
        if (date != null) return _isInStatisticsRange(date);
      }
      return false;
    }).toList();
  }

  DateTime? _parseStatsDate(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  }

  bool _isInStatisticsRange(DateTime date) {
    final now = DateTime.now();
    late final DateTime start;
    late final DateTime end;
    switch (_statisticsRange) {
      case 'This Week':
        final today = DateTime(now.year, now.month, now.day);
        start = today.subtract(Duration(days: today.weekday - 1));
        end = start.add(const Duration(days: 7));
        break;
      case 'This Year':
        start = DateTime(now.year);
        end = DateTime(now.year + 1);
        break;
      case 'This Month':
      default:
        start = DateTime(now.year, now.month);
        end = now.month == 12
            ? DateTime(now.year + 1)
            : DateTime(now.year, now.month + 1);
        break;
    }
    return !date.isBefore(start) && date.isBefore(end);
  }

  Uri _uri(String path) => Uri.parse('${ApiService.baseUrl}$path');

  String _message(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] != null) {
        return decoded['error'].toString();
      }
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {}
    return response.body.isEmpty ? 'Request failed' : response.body;
  }

  String _n(String key) => '${_int(_metrics[key])}';

  String _decimal(String key) {
    final value = double.tryParse('${_metrics[key] ?? 0}') ?? 0;
    return value.toStringAsFixed(1);
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  String _money(dynamic value) {
    final amount = _num(value);
    final text = amount % 1 == 0
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return '$text ILS';
  }

  String _compactNumber(dynamic value) {
    final number = _num(value);
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return (number / 1000).toStringAsFixed(3);
    return number.toStringAsFixed(0);
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  String _text(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _shortDate(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    final date = DateTime.tryParse(raw);
    if (date == null) return 'New';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _shortTime(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    final date = DateTime.tryParse(raw);
    if (date == null) return '--:--';
    final hour = date.hour == 0
        ? 12
        : date.hour > 12
        ? date.hour - 12
        : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  String _initials(dynamic value) {
    final parts = _text(
      value,
      fallback: '?',
    ).split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first;
    return '${parts.first.characters.first}${parts.last.characters.first}';
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'doctor':
        return 'Doctor';
      case 'nurse':
        return 'Nurse';
      case 'patient':
        return 'Patient';
      default:
        return role;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  String _serviceStatusGroup(String status) {
    final value = status.toLowerCase().trim();
    if (value == 'completed' || value == 'done') return 'completed';
    if (value == 'in_progress' ||
        value == 'accepted' ||
        value == 'confirmed' ||
        value == 'waiting_report') {
      return 'in_progress';
    }
    if (value == 'cancelled' || value == 'canceled' || value == 'rejected') {
      return 'cancelled';
    }
    return 'pending';
  }

  String _serviceStatusLabel(String status) {
    switch (_serviceStatusGroup(status)) {
      case 'completed':
        return 'Completed';
      case 'in_progress':
        return 'In Progress';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Upcoming';
    }
  }

  Color _serviceStatusColor(String group) {
    switch (group) {
      case 'completed':
        return const Color(0xFF1E9D69);
      case 'in_progress':
        return const Color(0xFFD28A00);
      case 'cancelled':
        return const Color(0xFFD83A59);
      default:
        return const Color(0xFF0A84D6);
    }
  }

  String _rateStatusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending approval';
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'doctor':
        return const Color(0xFFE35D6A);
      case 'nurse':
        return const Color(0xFF0AA0B8);
      case 'patient':
        return const Color(0xFF9B6AD6);
      default:
        return _teal;
    }
  }

  Color _statusBg(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFFE3F8EF);
      case 'rejected':
        return const Color(0xFFFFE6ED);
      default:
        return const Color(0xFFFFF1D8);
    }
  }

  Color _statusFg(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF1E9D69);
      case 'rejected':
        return const Color(0xFFD83A59);
      default:
        return const Color(0xFFAC6B00);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.fixed,
        content: Text(message.replaceFirst('Exception: ', '')),
      ),
    );
  }
}

List<Map<String, dynamic>> _list(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
  return const [];
}

List<BoxShadow> get _shadow => [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.04),
    blurRadius: 10,
    offset: const Offset(0, 5),
  ),
];

List<BoxShadow> get _softDashboardShadow => [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.035),
    blurRadius: 18,
    offset: const Offset(0, 8),
  ),
];

class _StatusSlice {
  const _StatusSlice(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;
}

class _DonutChartPainter extends CustomPainter {
  const _DonutChartPainter(this.slices);

  final List<_StatusSlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<int>(0, (sum, slice) => sum + slice.value);
    final rect = Offset.zero & size;
    final strokeWidth = size.width * 0.19;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    if (total <= 0) {
      paint.color = const Color(0xFFE8EEF0);
      canvas.drawArc(
        rect.deflate(strokeWidth / 2),
        -math.pi / 2,
        math.pi * 2,
        false,
        paint,
      );
      return;
    }

    var start = -math.pi / 2;
    for (final slice in slices) {
      if (slice.value <= 0) continue;
      final sweep = (slice.value / total) * math.pi * 2;
      paint.color = slice.color;
      canvas.drawArc(rect.deflate(strokeWidth / 2), start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) =>
      oldDelegate.slices != slices;
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter(this.values, this.color);

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFEAF0F2)
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final safeValues = values.isEmpty ? const [0.0] : values;
    final maxValue = safeValues.reduce(math.max);
    final minValue = safeValues.reduce(math.min);
    final range = (maxValue - minValue).abs() < 0.01
        ? 1.0
        : maxValue - minValue;
    final stepX = safeValues.length <= 1
        ? size.width
        : size.width / (safeValues.length - 1);

    final path = Path();
    final fillPath = Path();
    for (var i = 0; i < safeValues.length; i++) {
      final x = stepX * i;
      final normalized = (safeValues[i] - minValue) / range;
      final y = size.height - (normalized * (size.height - 22)) - 10;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.02)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = color;
    for (var i = 0; i < safeValues.length; i++) {
      final x = stepX * i;
      final normalized = (safeValues[i] - minValue) / range;
      final y = size.height - (normalized * (size.height - 22)) - 10;
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: Colors.red,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
