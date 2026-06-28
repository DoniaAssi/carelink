import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_colors.dart';
import '../../../core/locale_controller.dart';
import '../../../services/doctor_service.dart';
import 'doctor_ui_constants.dart';

class DoctorPaymentsScreen extends StatefulWidget {
  const DoctorPaymentsScreen({super.key});

  @override
  State<DoctorPaymentsScreen> createState() => _DoctorPaymentsScreenState();
}

class _DoctorPaymentsScreenState extends State<DoctorPaymentsScreen> {
  final _doctorService = DoctorService();

  bool _isLoading = true;
  bool _isExporting = false;
  Map<String, dynamic> _paymentsData = {};
  Map<String, dynamic> _rateStatus = {};
  String _doctorId = '';
  String _doctorName = 'Doctor';
  _EarningsFilter _selectedFilter = _EarningsFilter.all;

  List<dynamic> get _payments => _paymentsData['payments'] as List? ?? [];

  Map<String, dynamic> get _summary {
    final value = _paymentsData['summary'];
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  double get _approvedRate => _toMoney(_rateStatus['providerRate']);
  double get _paidOut => _toMoney(_summary['totalPaid']);
  double get _pendingPayout => _toMoney(_summary['totalUnpaid']);
  double get _totalEarnings => _paidOut + _pendingPayout;

  int get _completedVisits => _payments.where((payment) {
    final item = _asMap(payment);
    final status = (item['requestStatus'] ?? '').toString().toLowerCase();
    return status == 'completed' || status == 'complete';
  }).length;

  List<dynamic> get _filteredPayments => _payments.where((payment) {
    final item = _asMap(payment);
    final paymentStatus = _normalizedPaymentStatus(item);
    final date = _paymentDate(item);
    final now = DateTime.now();

    switch (_selectedFilter) {
      case _EarningsFilter.all:
        return true;
      case _EarningsFilter.paid:
        return paymentStatus == 'paid';
      case _EarningsFilter.pending:
        return paymentStatus == 'pending';
      case _EarningsFilter.thisMonth:
        return date != null && date.year == now.year && date.month == now.month;
      case _EarningsFilter.lastMonth:
        final lastMonth = DateTime(now.year, now.month - 1);
        return date != null &&
            date.year == lastMonth.year &&
            date.month == lastMonth.month;
    }
  }).toList();

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      _doctorId = prefs.getString('doctor_userId') ?? '';
      _doctorName =
          prefs.getString('doctor_fullName')?.trim().isNotEmpty == true
          ? prefs.getString('doctor_fullName')!.trim()
          : 'Doctor';

      final rateStatus = await _doctorService.getRateStatus(_doctorId);
      final data = rateStatus['canWork'] == true
          ? await _doctorService.getPayments(_doctorId)
          : <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _rateStatus = rateStatus;
        _paymentsData = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading payments: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: localeController,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: DoctorUiConstants.doctorBackground,
          appBar: AppBar(
            title: const Text(
              'Earnings',
              style: TextStyle(color: Colors.black),
            ),
            centerTitle: true,
            backgroundColor: DoctorUiConstants.doctorBackground,
            foregroundColor: Colors.black,
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _rateStatus['canWork'] != true
              ? _buildRateBlockedState()
              : RefreshIndicator(
                  onRefresh: _loadPayments,
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1180),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildApprovedRateCard(),
                              const SizedBox(height: 16),
                              _buildStatisticsGrid(constraints.maxWidth),
                              const SizedBox(height: 20),
                              _buildEarningsHistory(),
                              const SizedBox(height: 14),
                              _buildEarningsNote(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildApprovedRateCard() {
    return _surfaceCard(
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.monetization_on_outlined,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Approved Rate',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_money(_approvedRate)} ILS / Visit',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                const Row(
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      color: AppColors.success,
                      size: 17,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Approved by Admin',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.shield_outlined,
            color: AppColors.primary.withValues(alpha: 0.1),
            size: 72,
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsGrid(double width) {
    final columns = width >= 900 ? 4 : (width >= 520 ? 2 : 1);
    final cards = [
      _EarningsStat(
        title: 'Total Earnings',
        value: '${_money(_totalEarnings)} ILS',
        icon: Icons.account_balance_wallet_outlined,
        color: AppColors.success,
        subtitle: 'All visit earnings',
      ),
      _EarningsStat(
        title: 'Pending Payout',
        value: '${_money(_pendingPayout)} ILS',
        icon: Icons.schedule_rounded,
        color: AppColors.warning,
        subtitle: 'Not yet paid out',
      ),
      _EarningsStat(
        title: 'Paid Out',
        value: '${_money(_paidOut)} ILS',
        icon: Icons.payments_outlined,
        color: AppColors.info,
        subtitle: 'Successfully paid',
      ),
      _EarningsStat(
        title: 'Completed Visits',
        value: '$_completedVisits',
        icon: Icons.bar_chart_rounded,
        color: const Color(0xFF7C3AED),
        subtitle: 'Completed visits',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 132,
      ),
      itemBuilder: (context, index) => _buildStatCard(cards[index]),
    );
  }

  Widget _buildStatCard(_EarningsStat stat) {
    return _surfaceCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: stat.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(stat.icon, color: stat.color, size: 25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    stat.value,
                    style: TextStyle(
                      color: stat.color,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stat.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsHistory() {
    return _surfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Earnings History',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'A list of completed visit earnings and payment statuses.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              );
              final exportButton = OutlinedButton.icon(
                onPressed: _isExporting ? null : _exportPdf,
                icon: _isExporting
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Export PDF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );

              if (constraints.maxWidth < 600) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [title, const SizedBox(height: 14), exportButton],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  exportButton,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _EarningsFilter.values.map((filter) {
                final selected = filter == _selectedFilter;
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedFilter = filter),
                    label: Text(filter.label),
                    avatar: filter == _EarningsFilter.all
                        ? const Icon(Icons.filter_list_rounded, size: 17)
                        : null,
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: selected
                          ? AppColors.primary
                          : const Color(0xFFD8E1DF),
                    ),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF344054),
                      fontWeight: FontWeight.w700,
                    ),
                    checkmarkColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          if (_filteredPayments.isEmpty)
            _buildEmptyHistory()
          else
            _buildEarningsTable(),
        ],
      ),
    );
  }

  Widget _buildEarningsTable() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE1E8E6)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1040),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                AppColors.primary.withValues(alpha: 0.06),
              ),
              headingTextStyle: const TextStyle(
                color: Color(0xFF475467),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
              dataTextStyle: const TextStyle(
                color: Color(0xFF1D2939),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              columns: const [
                DataColumn(label: Text('Patient Name')),
                DataColumn(label: Text('Service')),
                DataColumn(label: Text('Visit Date')),
                DataColumn(label: Text('Agreed Rate')),
                DataColumn(label: Text('Amount Earned')),
                DataColumn(label: Text('Payment Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: _filteredPayments.map((payment) {
                final item = _asMap(payment);
                final status = _normalizedPaymentStatus(item);
                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.primary.withValues(
                              alpha: 0.1,
                            ),
                            child: Text(
                              _initial(_text(item['patientName'], 'Patient')),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(_text(item['patientName'], 'Patient')),
                        ],
                      ),
                    ),
                    DataCell(Text(_serviceName(item['serviceType']))),
                    DataCell(Text(_formatPaymentDate(item))),
                    DataCell(Text('${_money(_agreedRate(item))} ILS / Visit')),
                    DataCell(
                      Text(
                        '${_money(_toMoney(item['amount']))} ILS',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    DataCell(_statusBadge(status)),
                    DataCell(
                      IconButton(
                        tooltip: 'View details',
                        onPressed: () => _showEarningDetails(item),
                        icon: const Icon(Icons.more_vert_rounded, size: 20),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                color: AppColors.primary,
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'No earnings found for this filter.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsNote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 19),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Earnings are calculated based on completed visits and the approved rate.',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = switch (status) {
      'paid' => AppColors.success,
      'refunded' => AppColors.info,
      'failed' => Colors.red,
      _ => AppColors.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Future<void> _showEarningDetails(Map<String, dynamic> item) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Earning Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 18),
              _detailRow('Patient', _text(item['patientName'], 'Patient')),
              _detailRow('Service', _serviceName(item['serviceType'])),
              _detailRow('Visit Date', _formatPaymentDate(item)),
              _detailRow(
                'Agreed Rate',
                '${_money(_agreedRate(item))} ILS / Visit',
              ),
              _detailRow(
                'Amount Earned',
                '${_money(_toMoney(item['amount']))} ILS',
              ),
              _detailRow(
                'Payment Status',
                _statusLabel(_normalizedPaymentStatus(item)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPdf() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final document = pw.Document(
        title: 'CareLink Earnings Report',
        author: 'CareLink',
      );
      final generatedAt = DateTime.now();
      final teal = PdfColor.fromHex('#0F8B8D');
      final lightTeal = PdfColor.fromHex('#EAF7F5');
      final grey = PdfColor.fromHex('#667085');

      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(28),
          header: (context) => pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 10),
            decoration: pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: teal, width: 1.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'CareLink - Earnings Report',
                  style: pw.TextStyle(
                    color: teal,
                    fontSize: 19,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Generated: ${_formatDateTime(generatedAt)}',
                  style: pw.TextStyle(color: grey, fontSize: 9),
                ),
              ],
            ),
          ),
          footer: (context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(color: grey, fontSize: 9),
            ),
          ),
          build: (context) => [
            pw.SizedBox(height: 18),
            pw.Text(
              'Doctor: $_doctorName',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: lightTeal,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Current Approved Rate',
                    style: pw.TextStyle(
                      color: grey,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '${_money(_approvedRate)} ILS / Visit',
                    style: pw.TextStyle(
                      color: teal,
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Row(
              children: [
                _pdfStat('Total Earnings', '${_money(_totalEarnings)} ILS'),
                pw.SizedBox(width: 8),
                _pdfStat('Pending Payout', '${_money(_pendingPayout)} ILS'),
                pw.SizedBox(width: 8),
                _pdfStat('Paid Out', '${_money(_paidOut)} ILS'),
                pw.SizedBox(width: 8),
                _pdfStat('Completed Visits', '$_completedVisits'),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Earnings History',
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            if (_payments.isEmpty)
              pw.Text('No earnings available.')
            else
              pw.TableHelper.fromTextArray(
                headers: const [
                  'Patient Name',
                  'Service',
                  'Visit Date',
                  'Agreed Rate',
                  'Amount Earned',
                  'Payment Status',
                ],
                data: _payments.map((payment) {
                  final item = _asMap(payment);
                  return [
                    _text(item['patientName'], 'Patient'),
                    _serviceName(item['serviceType']),
                    _formatPaymentDate(item),
                    '${_money(_agreedRate(item))} ILS / Visit',
                    '${_money(_toMoney(item['amount']))} ILS',
                    _statusLabel(_normalizedPaymentStatus(item)),
                  ];
                }).toList(),
                headerDecoration: pw.BoxDecoration(color: teal),
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 6,
                ),
                border: pw.TableBorder.all(
                  color: PdfColor.fromHex('#DDE5E3'),
                  width: 0.5,
                ),
                oddRowDecoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F7FAF9'),
                ),
              ),
            pw.SizedBox(height: 16),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              color: lightTeal,
              child: pw.Text(
                'Earnings are calculated based on completed visits and the approved rate.',
                style: pw.TextStyle(color: teal, fontSize: 9),
              ),
            ),
          ],
        ),
      );

      final bytes = await document.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'carelink_earnings_${_fileDate(generatedAt)}.pdf',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to export earnings PDF: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  pw.Widget _pdfStat(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColor.fromHex('#DDE5E3')),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                color: PdfColor.fromHex('#667085'),
                fontSize: 8,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                color: PdfColor.fromHex('#0F8B8D'),
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRateBlockedState() {
    final status = (_rateStatus['rateAcceptanceStatus'] ?? 'pending')
        .toString()
        .toLowerCase();
    final rate = _toMoney(_rateStatus['providerRate']);
    final message =
        (_rateStatus['reason'] ??
                'Accept your assigned service rate before using Earnings.')
            .toString();

    return RefreshIndicator(
      onRefresh: _loadPayments,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 72),
          Icon(
            status == 'rejected'
                ? Icons.hourglass_top_rounded
                : Icons.lock_clock_rounded,
            color: status == 'rejected'
                ? Colors.orange.shade700
                : AppColors.primary,
            size: 62,
          ),
          const SizedBox(height: 20),
          Text(
            status == 'rejected' ? 'Rate Review Pending' : 'Earnings Locked',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          if (rate > 0) ...[
            const SizedBox(height: 10),
            Text(
              '${_money(rate)} ILS / Visit',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _surfaceCard({required Widget child, required EdgeInsets padding}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1E8E6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  String _normalizedPaymentStatus(Map<String, dynamic> item) {
    final raw = (item['paymentStatus'] ?? item['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (raw.isEmpty || raw == 'unpaid') return 'pending';
    return raw;
  }

  String _statusLabel(String status) {
    if (status.isEmpty) return 'Pending';
    return status[0].toUpperCase() + status.substring(1).replaceAll('_', ' ');
  }

  DateTime? _paymentDate(Map<String, dynamic> item) {
    final raw = item['scheduledAt'] ?? item['visitDate'] ?? item['createdAt'];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString().replaceFirst(' ', 'T'))?.toLocal();
  }

  String _formatPaymentDate(Map<String, dynamic> item) {
    final date = _paymentDate(item);
    if (date == null) return 'N/A';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  double _agreedRate(Map<String, dynamic> item) {
    for (final value in [
      item['agreedRate'],
      item['providerRate'],
      item['visitRate'],
    ]) {
      final rate = _toMoney(value);
      if (rate > 0) return rate;
    }
    return _approvedRate;
  }

  String _serviceName(dynamic value) {
    final text = _text(value, 'General Consultation').replaceAll('_', ' ');
    return text
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  String _text(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
  }

  String _initial(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? 'P' : trimmed[0].toUpperCase();
  }

  double _toMoney(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(double value) => value.toStringAsFixed(2);

  String _formatDateTime(DateTime value) {
    final date =
        '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/${value.year}';
    final time =
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  String _fileDate(DateTime value) {
    return '${value.year}${value.month.toString().padLeft(2, '0')}'
        '${value.day.toString().padLeft(2, '0')}';
  }
}

enum _EarningsFilter { all, paid, pending, thisMonth, lastMonth }

extension on _EarningsFilter {
  String get label {
    switch (this) {
      case _EarningsFilter.all:
        return 'All';
      case _EarningsFilter.paid:
        return 'Paid';
      case _EarningsFilter.pending:
        return 'Pending';
      case _EarningsFilter.thisMonth:
        return 'This Month';
      case _EarningsFilter.lastMonth:
        return 'Last Month';
    }
  }
}

class _EarningsStat {
  const _EarningsStat({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;
}
