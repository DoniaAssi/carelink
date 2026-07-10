import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:carelink/shared/models/user.dart';
import 'package:carelink/shared/services/api_service.dart';

import 'nurse_ui.dart';

class NurseEarningsScreen extends StatefulWidget {
  const NurseEarningsScreen({super.key, required this.user});

  final User user;

  @override
  State<NurseEarningsScreen> createState() => _NurseEarningsScreenState();
}

enum _EarningsView {
  overview,
  sessions,
  summary,
  requestPayout,
  submitted,
  requests,
  paymentReceived,
}

class _NurseEarningsScreenState extends State<NurseEarningsScreen> {
  static const _primary = Color(0xFF0F766E);
  static Color get _bg => NurseUi.background;
  static Color get _surface => NurseUi.surface;
  static Color get _text => NurseUi.text;
  static Color get _muted => NurseUi.muted;

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic> _data = const {};
  _EarningsView _view = _EarningsView.overview;
  String _sessionFilter = 'All';
  String _payoutFilter = 'All';
  Map<String, dynamic>? _lastSubmittedRequest;

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
      final uri = Uri.parse(
        '${ApiService.baseUrl}/nurse/earnings/${widget.user.userId}',
      );
      final response = await http.get(uri);
      final body = jsonDecode(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = body is Map<String, dynamic>
            ? body['error']?.toString()
            : null;
        throw Exception(message ?? 'Failed to load earnings');
      }

      setState(() => _data = body as Map<String, dynamic>);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestPayout() async {
    if (_submitting) return;
    if (!_canWork) {
      _showLockedMessage();
      return;
    }
    setState(() => _submitting = true);
    try {
      final response = await http.post(
        Uri.parse(
          '${ApiService.baseUrl}/nurse/earnings/${widget.user.userId}/payout',
        ),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      final body = jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = body is Map<String, dynamic>
            ? body['error']?.toString()
            : null;
        throw Exception(message ?? 'Failed to submit payout request');
      }
      await _load();
      setState(() {
        _lastSubmittedRequest = body as Map<String, dynamic>;
        _view = _EarningsView.submitted;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool get _canWork => _map('eligibility')['canWork'] == true;

  void _showLockedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Accept your admin-set hourly rate before requesting payouts.',
        ),
      ),
    );
  }

  Future<void> _decideRate(String decision) async {
    try {
      final response = await http.post(
        Uri.parse(
          '${ApiService.baseUrl}/nurse/rate-status/${widget.user.userId}/decision',
        ),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'decision': decision}),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = body is Map<String, dynamic>
            ? body['error']?.toString()
            : null;
        throw Exception(message ?? 'Failed to update hourly rate decision');
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == 'accepted'
                ? 'Hourly rate accepted. You can start working now.'
                : 'Hourly rate rejected. Your account remains inactive for work.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive(
      (context) {
        if (_loading) {
          return Scaffold(
            backgroundColor: NurseUi.background,
            body: const Center(child: CircularProgressIndicator(color: _primary)),
          );
        }

        if (_error != null) {
          return Scaffold(
            backgroundColor: NurseUi.background,
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFEF4444),
                        size: 44,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: NurseUi.text),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _load,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(NurseUi.t('Retry')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: NurseUi.background,
          body: SafeArea(
            child: RefreshIndicator(
              color: _primary,
              onRefresh: _load,
              child: _buildCurrentView(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentView() {
    if (!_canWork && _view != _EarningsView.overview) {
      _view = _EarningsView.overview;
    }
    switch (_view) {
      case _EarningsView.sessions:
        return _sessionsView();
      case _EarningsView.summary:
        return _summaryView();
      case _EarningsView.requestPayout:
        return _requestPayoutView();
      case _EarningsView.submitted:
        return _submittedView();
      case _EarningsView.requests:
        return _requestsView();
      case _EarningsView.paymentReceived:
        return _paymentReceivedView();
      case _EarningsView.overview:
        return _overviewView();
    }
  }

  Widget _overviewView() {
    final provider = _map('provider');
    final wallet = _map('wallet');
    final summary = _map('summary');
    final eligibility = _map('eligibility');
    final canWork = eligibility['canWork'] == true;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
      children: [
        _topBar(
          NurseUi.t('Earnings & Payments'),
          leading: Icons.menu_rounded,
          onLeading: () {},
        ),
        const SizedBox(height: 24),
        _providerHeader(provider),
        const SizedBox(height: 18),
        _rateApprovalCard(eligibility),
        if (!canWork) ...[
          const SizedBox(height: 24),
          _infoBox(
            'Accept your admin-set hourly rate to unlock earnings, sessions, payouts, and nurse services.',
          ),
          const SizedBox(height: 90),
        ] else ...[
          const SizedBox(height: 22),
          _balanceCard(
            title: 'Available Balance (Pending)',
            amount: _num(wallet['availableBalance']),
            subtitle: '${_int(summary['totalPoints'])} Points',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  'Total Sessions',
                  _int(summary['totalSessions']).toString(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricCard(
                  'Total Points',
                  _int(summary['totalPoints']).toString(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricCard(
                  'Total Earnings',
                  _money(_num(summary['totalEarnings'])),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(NurseUi.t('Quick Actions'), style: _sectionTitle),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _actionTile(
                  Icons.account_balance_wallet_outlined,
                  NurseUi.isArabic.value ? 'Ø·Ù„Ø¨ Ø¯ÙØ¹Ø©' : 'Request Payout',
                  () => setState(() => _view = _EarningsView.requestPayout),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _actionTile(
                  Icons.receipt_long_outlined,
                  NurseUi.isArabic.value ? 'Ø³Ø¬Ù„ Ø§Ù„Ø£Ø±Ø¨Ø§Ø­' : 'Earnings History',
                  () => setState(() => _view = _EarningsView.requests),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _wideAction(
            Icons.medical_services_outlined,
            NurseUi.isArabic.value ? 'Ø®Ø¯Ù…Ø§ØªÙŠ (Ø§Ù„Ø¬Ù„Ø³Ø§Øª)' : 'My Services (Sessions)',
            NurseUi.isArabic.value
                ? 'Ø±Ø§Ø¬Ø¹ÙŠ Ø§Ù„Ø¬Ù„Ø³Ø§Øª Ø§Ù„Ù…ÙƒØªÙ…Ù„Ø© ÙˆØ§Ù„Ù…Ø¹Ù„Ù‚Ø©'
                : 'Review completed and pending sessions',
            () => setState(() => _view = _EarningsView.sessions),
          ),
          const SizedBox(height: 12),
          _wideAction(
            Icons.bar_chart_rounded,
            NurseUi.t('Overall Summary'),
            NurseUi.isArabic.value
                ? 'Ù…Ø¬Ù…Ø¹Ø© Ø­Ø³Ø¨ Ø§Ù„Ø®Ø¯Ù…Ø© ÙˆØªØ³Ø¹ÙŠØ± Ø§Ù„Ø£Ø¯Ù…Ù†'
                : 'Grouped by service and admin pricing rules',
            () => setState(() => _view = _EarningsView.summary),
          ),
        ],
      ],
    );
  }

  Widget _sessionsView() {
    final sessions = _list('sessions');
    final filtered = sessions.where((item) {
      final status = _status(item['status']);
      if (_sessionFilter == 'All') return true;
      return status.toLowerCase() == _sessionFilter.toLowerCase();
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
      children: [
        _topBar(
          NurseUi.isArabic.value ? 'Ø®Ø¯Ù…Ø§ØªÙŠ (Ø§Ù„Ø¬Ù„Ø³Ø§Øª)' : 'My Services (Sessions)',
          leading: Icons.arrow_back_rounded,
          trailing: Icons.filter_list_rounded,
          onLeading: () => setState(() => _view = _EarningsView.overview),
        ),
        const SizedBox(height: 20),
        _chips(['All', 'Completed', 'Pending'], _sessionFilter, (value) {
          setState(() => _sessionFilter = value);
        }),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          _emptyCard(NurseUi.isArabic.value ? 'Ù„Ø§ ØªÙˆØ¬Ø¯ Ø¬Ù„Ø³Ø§Øª' : 'No sessions found')
        else
          for (final session in filtered) ...[
            _sessionCard(session),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  Widget _summaryView() {
    final services = _list('serviceSummary');
    final summary = _map('summary');
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
      children: [
        _topBar(
          NurseUi.t('Overall Summary'),
          leading: Icons.arrow_back_rounded,
          onLeading: () => setState(() => _view = _EarningsView.overview),
        ),
        const SizedBox(height: 24),
        Text(NurseUi.t('Summary by Service'), style: _sectionTitle),
        const SizedBox(height: 12),
        if (services.isEmpty)
          _emptyCard(NurseUi.isArabic.value ? 'Ù„Ø§ ÙŠÙˆØ¬Ø¯ Ù…Ù„Ø®Øµ Ø£Ø±Ø¨Ø§Ø­ Ø¨Ø¹Ø¯' : 'No earnings summary yet')
        else
          for (final service in services) ...[
            _serviceSummaryCard(service),
            const SizedBox(height: 12),
          ],
        const SizedBox(height: 18),
        Text(NurseUi.t('Overall Summary'), style: _sectionTitle),
        const SizedBox(height: 12),
        _detailsCard([
          ('Total Sessions', _int(summary['totalSessions']).toString()),
          ('Total Points', _int(summary['totalPoints']).toString()),
          ('Total Earnings', _money(_num(summary['totalEarnings']))),
        ]),
        const SizedBox(height: 18),
        _primaryButton(
          NurseUi.isArabic.value ? 'Ø·Ù„Ø¨ Ø¯ÙØ¹Ø©' : 'Request Payout',
          Icons.account_balance_wallet_outlined,
          () => setState(() => _view = _EarningsView.requestPayout),
        ),
      ],
    );
  }

  Widget _requestPayoutView() {
    final wallet = _map('wallet');
    final summary = _map('summary');
    final method = _map('paymentMethod');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
      children: [
        _topBar(
          NurseUi.isArabic.value ? 'Ø·Ù„Ø¨ Ø¯ÙØ¹Ø©' : 'Request Payout',
          leading: Icons.arrow_back_rounded,
          trailing: Icons.more_horiz_rounded,
          onLeading: () => setState(() => _view = _EarningsView.overview),
        ),
        const SizedBox(height: 24),
        _softBalanceCard(
          _num(wallet['availableBalance']),
          _int(summary['totalPoints']),
        ),
        const SizedBox(height: 18),
        Text(NurseUi.t('Request Details'), style: _sectionTitle),
        const SizedBox(height: 12),
        _detailsCard([
          ('Total Sessions', _int(summary['totalSessions']).toString()),
          ('Total Points', _int(summary['totalPoints']).toString()),
          (
            'Total Earnings (To Withdraw)',
            _money(_num(wallet['availableBalance'])),
          ),
        ]),
        const SizedBox(height: 18),
        Text(NurseUi.t('Payment Method'), style: _sectionTitle),
        const SizedBox(height: 12),
        _paymentMethodCard(method),
        const SizedBox(height: 18),
        _infoBox(
          'Your request will be reviewed by admin. You will be notified once the payment is approved.',
        ),
        const SizedBox(height: 22),
        _primaryButton(
          _submitting ? 'Submitting...' : 'Submit Request',
          Icons.send_rounded,
          _submitting ? null : _requestPayout,
        ),
      ],
    );
  }

  Widget _submittedView() {
    final amount = _num(_lastSubmittedRequest?['amount']) == 0
        ? _num(_map('wallet')['availableBalance'])
        : _num(_lastSubmittedRequest?['amount']);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 110),
      children: [
        _successIcon(),
        const SizedBox(height: 24),
        const Text(
          'Request Submitted!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _primary,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Your payout request of\n${_money(amount)}\nhas been submitted successfully.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _text,
            height: 1.6,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7E6),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Column(
            children: [
              Text(
                'Request Status',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 8),
              Text(
                'Pending Approval',
                style: TextStyle(
                  color: Color(0xFFF59E0B),
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 120),
        _outlineButton(
          'View My Requests',
          Icons.list_alt_rounded,
          () => setState(() => _view = _EarningsView.requests),
        ),
      ],
    );
  }

  Widget _requestsView() {
    final payouts = _list('payoutRequests');
    final filtered = payouts.where((item) {
      if (_payoutFilter == 'All') return true;
      return _status(item['statusLabel']).toLowerCase() ==
          _payoutFilter.toLowerCase();
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
      children: [
        _topBar(
          'My Payout Requests',
          leading: Icons.arrow_back_rounded,
          trailing: Icons.more_horiz_rounded,
          onLeading: () => setState(() => _view = _EarningsView.overview),
        ),
        const SizedBox(height: 20),
        _chips(['All', 'Pending', 'Approved', 'Paid'], _payoutFilter, (value) {
          setState(() => _payoutFilter = value);
        }),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          _emptyCard('No payout requests yet')
        else
          for (final payout in filtered) ...[
            _payoutCard(payout),
            const SizedBox(height: 12),
          ],
        const SizedBox(height: 22),
        _outlineButton(
          'View Payment Received',
          Icons.payments_outlined,
          _list('transactions').isEmpty
              ? null
              : () => setState(() => _view = _EarningsView.paymentReceived),
        ),
      ],
    );
  }

  Widget _paymentReceivedView() {
    final transactions = _list('transactions');
    final transaction = transactions.isEmpty
        ? const <String, dynamic>{}
        : transactions.first;
    final method = _map('paymentMethod');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 110),
      children: [
        _topBar(
          'Payment Received',
          leading: Icons.arrow_back_rounded,
          onLeading: () => setState(() => _view = _EarningsView.requests),
        ),
        const SizedBox(height: 26),
        _successIcon(),
        const SizedBox(height: 22),
        const Text(
          'Payment Received!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _primary,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${_money(_num(transaction['amount']))}\nhas been transferred to you.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            height: 1.6,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 28),
        _detailsCard([
          ('Transaction ID', transaction['transactionId']?.toString() ?? '-'),
          ('Date & Time', _date(transaction['createdAt'])),
          ('Amount', _money(_num(transaction['amount']))),
          (
            'Payment Method',
            _status(method['type']).isEmpty
                ? 'Not configured'
                : _status(method['type']),
          ),
          (
            'Status',
            _status(transaction['status']).isEmpty
                ? 'Completed'
                : _status(transaction['status']),
          ),
        ]),
        const SizedBox(height: 22),
        _outlineButton('Download Receipt', Icons.download_rounded, () {}),
      ],
    );
  }

  Widget _topBar(
    String title, {
    IconData? leading,
    IconData? trailing,
    VoidCallback? onLeading,
  }) {
    return Row(
      children: [
        IconButton(
          onPressed: onLeading,
          icon: Icon(leading ?? Icons.arrow_back_rounded),
          color: _primary,
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _text,
            ),
          ),
        ),
        IconButton(
          onPressed: trailing == null ? null : () {},
          icon: Icon(trailing ?? Icons.notifications_none_rounded),
          color: _primary,
        ),
      ],
    );
  }

  Widget _providerHeader(Map<String, dynamic> provider) {
    return Row(
      children: [
        CircleAvatar(
          radius: 42,
          backgroundColor: const Color(0xFFDDF2EF),
          child: Text(
            _initial(provider['name']),
            style: TextStyle(
              color: _primary,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _status(provider['name']).isEmpty
                    ? widget.user.fullName
                    : _status(provider['name']),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_title(_status(provider['role']).isEmpty ? 'Nurse' : _status(provider['role']))}'
                '${_status(provider['specialty']).isEmpty ? '' : ' â€¢ ${_status(provider['specialty'])}'}',
                style: TextStyle(
                  color: _primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFFBBF24),
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_num(provider['rating']).toStringAsFixed(1)} (${_int(provider['reviews'])} reviews)',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rateApprovalCard(Map<String, dynamic> eligibility) {
    final status = _status(eligibility['rateAcceptanceStatus']).toLowerCase();
    final approval = _status(eligibility['approvalStatus']).toLowerCase();
    final rate = _num(eligibility['providerRate']);
    final canWork = eligibility['canWork'] == true;
    final reason = _status(eligibility['reason']);
    final color = canWork
        ? const Color(0xFF16A34A)
        : status == 'rejected'
        ? const Color(0xFFEF4444)
        : const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(borderColor: color.withValues(alpha: 0.35)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(Icons.price_check_rounded, color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Admin Hourly Rate',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rate > 0
                          ? '${_money(rate)} per hour'
                          : 'Waiting for admin rate',
                      style: TextStyle(
                        color: _muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              _pill(
                canWork
                    ? 'Ready'
                    : status.isEmpty
                    ? 'Pending'
                    : _title(status),
                color.withValues(alpha: 0.12),
                color,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            approval == 'approved'
                ? (reason.isEmpty
                      ? 'Your account is approved. Accept the hourly rate before accepting requests or starting sessions.'
                      : reason)
                : 'Admin approval is required before accepting requests or starting sessions.',
            style: TextStyle(
              color: _text,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          if (approval == 'approved' && rate > 0 && status != 'accepted') ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _decideRate('rejected'),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject Rate'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _decideRate('accepted'),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Accept Rate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _balanceCard({
    required String title,
    required num amount,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF0A5C54)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: _shadow,
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _money(amount),
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _softBalanceCard(num amount, int points) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7F5),
        borderRadius: BorderRadius.circular(18),
        boxShadow: _shadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available Balance (Pending)',
                  style: TextStyle(color: _muted, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  _money(amount),
                  style: TextStyle(
                    color: _primary,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$points Points',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.account_balance_wallet_rounded,
            size: 58,
            color: Color(0xFF60A5FA),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: _text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: _cardDecoration(),
        child: Column(
          children: [
            Icon(icon, color: _primary, size: 28),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wideAction(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            _iconBox(icon, _primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: _primary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionCard(Map<String, dynamic> session) {
    final status = _status(session['status']);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          _iconBox(
            _serviceIcon(session['specialization']),
            _serviceColor(session['specialization']),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _status(session['specialization']),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _date(session['dateTime']),
                  style: TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_duration(session['duration'])} â€¢ ${_title(status)}',
                  style: TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _pill(
                  '${_int(session['points'])} ${_int(session['points']) == 1 ? 'Point' : 'Points'}',
                  const Color(0xFFE5F7EF),
                  const Color(0xFF16A34A),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _money(_num(session['ratePerSession'])),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Per Hour',
                style: TextStyle(
                  color: _muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _serviceSummaryCard(Map<String, dynamic> service) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              _iconBox(
                _serviceIcon(service['specialization']),
                _serviceColor(service['specialization']),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _status(service['specialization']),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _miniStat(
                  'Total',
                  _int(service['totalSessions']).toString(),
                ),
              ),
              Expanded(
                child: _miniStat(
                  'Total Points',
                  _int(service['totalPoints']).toString(),
                ),
              ),
              Expanded(
                child: _miniStat(
                  'Total Earnings',
                  _money(_num(service['totalEarnings'])),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Rate / Hour: ${_money(_num(service['ratePerSession']))}',
              style: TextStyle(
                color: _muted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _muted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          child: Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
        ),
      ],
    );
  }

  Widget _paymentMethodCard(Map<String, dynamic> method) {
    final type = _status(method['type']).isEmpty
        ? 'Payment method not configured'
        : _status(method['type']);
    final details = _status(method['details']);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          _iconBox(Icons.account_balance_outlined, _primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type, style: TextStyle(fontWeight: FontWeight.w900)),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    details,
                    style: TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, color: _muted, size: 16),
        ],
      ),
    );
  }

  Widget _payoutCard(Map<String, dynamic> payout) {
    final label = _status(payout['statusLabel']);
    final color = _payoutColor(label);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: label == 'Paid'
          ? () => setState(() => _view = _EarningsView.paymentReceived)
          : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(
          borderColor: label == 'Pending' ? const Color(0xFFFDE68A) : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Request #${_shortId(payout['payoutId'])}',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _date(payout['createdAt']),
                    style: TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _money(_num(payout['amount'])),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            _pill(
              label.isEmpty ? 'Pending' : label,
              color.withValues(alpha: 0.12),
              color,
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailsCard(List<(String, String)> rows) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    rows[i].$1,
                    style: TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    rows[i].$2,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: _text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            if (i != rows.length - 1) const Divider(height: 26),
          ],
        ],
      ),
    );
  }

  Widget _chips(
    List<String> values,
    String selected,
    ValueChanged<String> onChanged,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final value in values) ...[
            ChoiceChip(
              label: Text(value),
              selected: selected == value,
              onSelected: (_) => onChanged(value),
              selectedColor: _primary,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: selected == value ? Colors.white : _text,
                fontWeight: FontWeight.w900,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: selected == value ? _primary : const Color(0xFFE5E7EB),
                ),
              ),
              showCheckmark: false,
            ),
            const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }

  Widget _primaryButton(String label, IconData icon, VoidCallback? onPressed) {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          disabledBackgroundColor: const Color(0xFF9CA3AF),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
      ),
    );
  }

  Widget _outlineButton(String label, IconData icon, VoidCallback? onPressed) {
    return SizedBox(
      height: 54,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: _primary,
          side: BorderSide(
            color: onPressed == null ? const Color(0xFFCBD5E1) : _primary,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _infoBox(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F4FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_rounded, color: Color(0xFF0284C7)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontWeight: FontWeight.w800, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: _cardDecoration(),
      child: Center(
        child: Text(
          text,
          style: TextStyle(color: _muted, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _successIcon() {
    return Center(
      child: Container(
        width: 100,
        height: 100,
        decoration: const BoxDecoration(
          color: Color(0xFFDDF2EF),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: CircleAvatar(
            radius: 34,
            backgroundColor: Color(0xFF10B981),
            child: Icon(Icons.check_rounded, color: Colors.white, size: 44),
          ),
        ),
      ),
    );
  }

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color),
    );
  }

  Widget _pill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }

  BoxDecoration _cardDecoration({Color? borderColor}) {
    return NurseUi.cardDecoration(borderColor: borderColor);
  }

  List<BoxShadow> get _shadow => NurseUi.softShadow;

  Map<String, dynamic> _map(String key) {
    final value = _data[key];
    return value is Map<String, dynamic> ? value : const {};
  }

  List<Map<String, dynamic>> _list(String key) {
    final value = _data[key];
    if (value is! List) return const [];
    return value.whereType<Map<String, dynamic>>().toList();
  }

  num _num(Object? value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _int(Object? value) => _num(value).round();

  String _status(Object? value) => value?.toString().trim() ?? '';

  String _money(num value) {
    final fixed = value % 1 == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return '$fixed ILS';
  }

  String _date(Object? value) {
    final raw = _status(value);
    if (raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final months = [
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
    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final suffix = parsed.hour >= 12 ? 'PM' : 'AM';
    return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year} â€¢ $hour:$minute $suffix';
  }

  String _duration(Object? minutesValue) {
    final minutes = _int(minutesValue);
    if (minutes <= 0) return 'Duration not set';
    if (minutes < 60) return '$minutes min';
    final hours = minutes / 60;
    return hours % 1 == 0
        ? '${hours.toStringAsFixed(0)} Hours'
        : '${hours.toStringAsFixed(1)} Hours';
  }

  String _initial(Object? name) {
    final clean = _status(name);
    return clean.isEmpty ? 'N' : clean[0].toUpperCase();
  }

  String _title(String value) {
    if (value.isEmpty) return value;
    return value
        .split(RegExp(r'[_\s-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
        .join(' ');
  }

  String _shortId(Object? value) {
    final raw = _status(value);
    if (raw.length <= 12) return raw;
    return raw.substring(raw.length - 12).toUpperCase();
  }

  IconData _serviceIcon(Object? specialization) {
    final text = _status(specialization).toLowerCase();
    if (text.contains('pediatric') || text.contains('child')) {
      return Icons.child_care_rounded;
    }
    if (text.contains('wound')) return Icons.healing_rounded;
    if (text.contains('injection')) return Icons.vaccines_rounded;
    return Icons.elderly_rounded;
  }

  Color _serviceColor(Object? specialization) {
    final text = _status(specialization).toLowerCase();
    if (text.contains('pediatric') || text.contains('child')) {
      return const Color(0xFF6D5DF6);
    }
    if (text.contains('wound')) return const Color(0xFFEF4444);
    if (text.contains('injection')) return const Color(0xFF0284C7);
    return const Color(0xFF16A34A);
  }

  Color _payoutColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF16A34A);
      case 'paid':
        return const Color(0xFF10B981);
      case 'rejected':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  TextStyle get _sectionTitle => TextStyle(
    color: _text,
    fontSize: 18,
    fontWeight: FontWeight.w900,
  );
}

