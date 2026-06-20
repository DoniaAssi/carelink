import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:carelink/core/app_nav.dart';
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
  String _userFilter = 'all';
  String _userQuery = '';
  Map<String, dynamic> _data = const {};

  Map<String, dynamic> get _metrics =>
      Map<String, dynamic>.from(_data['metrics'] ?? const {});
  List<Map<String, dynamic>> get _requests => _list(_data['requests']);
  List<Map<String, dynamic>> get _users => _list(_data['users']);
  List<Map<String, dynamic>> get _ratings => _list(_data['ratings']);
  Map<String, dynamic> get _performance =>
      Map<String, dynamic>.from(_data['performance'] ?? const {});
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
        return _usersPage();
      case 3:
        return _ratingsPage();
      case 4:
        return _financePage();
      case 5:
        return _pricingPage();
      default:
        return _dashboardPage();
    }
  }

  Widget _dashboardPage() {
    final pending = _requests
        .where((r) => _text(r['approvalStatus']) == 'pending')
        .take(3)
        .toList();
    final services = _list(_performance['services']).take(4).toList();
    return _page(
      title: 'Welcome, ${widget.user.fullName}',
      subtitle: 'Here is your system overview today',
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.42,
          children: [
            _statCard('Patients', _n('patients'), '${_n('totalUsers')} users'),
            _statCard('Nurses', _n('nurses'), '${_n('doctors')} doctors'),
            _statCard('Pending Reviews', _n('pendingProviders'), 'New'),
            _statCard(
              'Service Requests',
              _n('totalRequests'),
              '${_n('completedRequests')} completed',
            ),
          ],
        ),
        const SizedBox(height: 18),
        _performancePanel(),
        const SizedBox(height: 18),
        _sectionHeader(
          'Registration Requests Pending Review',
          'View all',
          () => setState(() => _tabIndex = 1),
        ),
        if (pending.isEmpty)
          _empty('No pending registration requests right now')
        else
          ...pending.map(_requestCard),
        const SizedBox(height: 12),
        _sectionTitle('Top Requested Services'),
        _whitePanel(
          child: services.isEmpty
              ? _emptyInline('No requested services yet')
              : Column(children: services.map(_serviceBar).toList()),
        ),
      ],
    );
  }

  Widget _requestsPage() {
    final filtered = _requests.where((r) {
      final role = _text(r['role']);
      final status = _text(r['approvalStatus']);
      if (_requestFilter == 'all') return true;
      if (_requestFilter == 'rejected') return status == 'rejected';
      return role == _requestFilter;
    }).toList();

    return _page(
      title: 'Registration Requests',
      subtitle: 'Review new nurses and doctors',
      children: [
        _filterRow(
          value: _requestFilter,
          options: const {
            'all': 'All',
            'nurse': 'Nurses',
            'doctor': 'Doctors',
            'rejected': 'Rejected',
          },
          onChanged: (v) => setState(() => _requestFilter = v),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          _empty('No requests match this filter')
        else
          ...filtered.map(_requestCard),
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

    return _page(
      title: 'Users',
      subtitle: 'Manage patients and providers',
      children: [
        TextField(
          onChanged: (v) => setState(() => _userQuery = v),
          decoration: InputDecoration(
            hintText: 'Search users...',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: const BorderSide(color: _line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: const BorderSide(color: _line),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _filterRow(
          value: _userFilter,
          options: const {
            'all': 'All',
            'patient': 'Patients',
            'nurse': 'Nurses',
            'doctor': 'Doctors',
          },
          onChanged: (v) => setState(() => _userFilter = v),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          _empty('No users match your search')
        else
          ...filtered.map(_userCard),
      ],
    );
  }

  Widget _ratingsPage() {
    return _page(
      title: 'Service Ratings',
      subtitle: 'Patient feedback for providers',
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _teal,
            borderRadius: BorderRadius.circular(22),
            boxShadow: _shadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Average Rating',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _decimal('averageStars'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'from ${_n('totalRatings')} ratings',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_ratings.isEmpty)
          _empty('No ratings in the database yet')
        else
          ..._ratings.map(_ratingCard),
      ],
    );
  }

  Widget _financePage() {
    return _page(
      title: 'Finance',
      subtitle: 'Platform revenue, wallets, and payouts',
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.32,
          children: [
            _statCard(
              'Total Revenue',
              _money(_financeOverview['totalRevenue']),
              '${_int(_financeOverview['paymentCount'])} payments',
            ),
            _statCard(
              'Platform Profit',
              _money(_financeOverview['platformProfit']),
              'Admin commission',
            ),
            _statCard(
              'Pending Escrow',
              _money(_financeOverview['pendingEscrow']),
              'Awaiting transfer',
            ),
            _statCard(
              'Released to Providers',
              _money(_financeOverview['releasedToProviders']),
              'Paid',
            ),
          ],
        ),
        const SizedBox(height: 18),
        _sectionTitle('Payout Requests'),
        if (_payouts.isEmpty)
          _empty('No payout requests right now')
        else
          ..._payouts.take(8).map(_payoutCard),
        const SizedBox(height: 8),
        _sectionTitle('Recent Transactions'),
        if (_transactions.isEmpty)
          _empty('No financial transactions yet')
        else
          ..._transactions.take(8).map(_transactionCard),
        const SizedBox(height: 8),
        _sectionTitle('Provider Wallets'),
        if (_wallets.isEmpty)
          _empty('No provider wallets yet')
        else
          ..._wallets.take(8).map(_walletCard),
      ],
    );
  }

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

  Widget _ratingCard(Map<String, dynamic> rating) {
    final stars = _int(rating['stars']);
    return _whitePanel(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                _stars(stars),
                const Spacer(),
                Text(
                  '${_text(rating['providerName'], fallback: 'Provider')}.',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'For ${_text(rating['serviceType'], fallback: 'service')}',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            Text(
              _text(rating['comment'], fallback: 'No written notes.'),
              textAlign: TextAlign.right,
              style: const TextStyle(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

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
      (Icons.people_outline_rounded, Icons.people_alt_rounded, 'Users'),
      (Icons.star_border_rounded, Icons.star_rounded, 'Ratings'),
      (
        Icons.account_balance_wallet_outlined,
        Icons.account_balance_wallet_rounded,
        'Finance',
      ),
      (Icons.sell_outlined, Icons.sell_rounded, 'Pricing'),
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
                        final fileUrl = _absoluteUploadUrl(
                          _text(cert['fileUrl']),
                        );
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
                                  onPressed: () => _openUrl(fileUrl),
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
    final response = await http.put(
      _uri('/admin/certifications/$certId/verify'),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_message(response));
    }
    _toast('Certificate verified');
    await _load();
  }

  String _absoluteUploadUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '${ApiService.baseUrl}${url.startsWith('/') ? '' : '/'}$url';
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
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

  ({String label, int points}) _tierForProvider(
    Map<String, dynamic>? provider,
  ) {
    final years = _int(
      provider?['experienceYears'] ?? provider?['years_experience'],
    );
    final rating = _num(provider?['overallRating']);
    final points = ((years.clamp(0, 10) * 10) + (rating.clamp(0, 5) * 12))
        .round();
    if (points >= 140) return (label: 'Expert', points: points);
    if (points >= 90) return (label: 'Senior', points: points);
    return (label: 'Junior', points: points == 0 ? 60 : points);
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
  }) {
    return InputDecoration(
      hintText: hintText,
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

  Widget _pricingTierCard(Map<String, dynamic>? provider) {
    final tier = _tierForProvider(provider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F7F4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.stars_rounded, color: _teal, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Experience / Performance Tier (Auto-filled)',
                  style: TextStyle(
                    color: _teal,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${tier.label} (${tier.points} points)',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editPricing([Map<String, dynamic>? item]) async {
    final providerRate = TextEditingController(
      text: item == null ? '' : _num(item['providerRate']).toStringAsFixed(0),
    );
    final commission = TextEditingController(
      text: item == null
          ? ''
          : _num(item['adminCommission']).toStringAsFixed(0),
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
                    const SizedBox(height: 16),
                    _pricingTierCard(selectedProvider),
                    const SizedBox(height: 16),
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
                      decoration: _pricingInputDecoration(
                        icon: Icons.attach_money_rounded,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _pricingLabel('Admin commission (per hour)'),
                    TextField(
                      controller: commission,
                      keyboardType: TextInputType.number,
                      decoration: _pricingInputDecoration(
                        icon: Icons.attach_money_rounded,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'This amount is not visible to the provider or the patient',
                        style: TextStyle(
                          color: Color(0xFF7A8A99),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
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
      commission.dispose();
      return;
    }

    try {
      final response = await http.put(
        _uri('/admin/finance/pricing'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'providerId': selectedProviderId.trim(),
          'specialization': selectedSpecialization.trim(),
          'serviceType': serviceType,
          'providerRate': providerRate.text.trim(),
          'adminCommission': commission.text.trim(),
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
      commission.dispose();
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

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  String _text(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
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
