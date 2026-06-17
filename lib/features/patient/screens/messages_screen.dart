import 'package:flutter/material.dart';
import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/shared/widgets/patient_app_bar.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  final String userId;

  const MessagesScreen({super.key, required this.userId});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> messages = [];
  List<dynamic> filteredMessages = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterMessages);
    _fetchMessages();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterMessages);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages() async {
    try {
      final messagesFuture = ApiService().getMessages(widget.userId);
      final appointmentsFuture = ApiService().getAppointments(widget.userId);
      final historyFuture = ApiService().getAppointmentHistory(widget.userId);

      final results = await Future.wait([messagesFuture, appointmentsFuture, historyFuture]);

      if (!mounted) return;

      final messagesData = results[0] as List<dynamic>;
      final activeAppointments = results[1] as List<dynamic>;
      final historyAppointments = results[2] as List<dynamic>;

      final List<dynamic> allAppointments = [
        ...activeAppointments,
        ...historyAppointments,
      ];

      final Map<String, Map<String, dynamic>> finalConversations = {};

      for (var msg in messagesData) {
        if (msg is! Map) continue;
        final providerId = (msg['doctorId'] ?? msg['providerId'] ?? '').toString();
        if (providerId.isNotEmpty) {
          finalConversations[providerId] = Map<String, dynamic>.from(msg);
        }
      }

      final Set<String> eligibleProviderIds = {};
      final Map<String, Map<String, dynamic>> providerDetailsFromAppt = {};
      final Map<String, String> latestAppointmentStatus = {};

      for (var appt in allAppointments) {
        if (appt is! Map) continue;
        final providerId = (appt['providerId'] ?? appt['providerUserId'] ?? appt['doctorId'] ?? '').toString();
        final status = (appt['status'] ?? '').toString();
        
        if (providerId.isEmpty) continue;

        if (!providerDetailsFromAppt.containsKey(providerId)) {
          providerDetailsFromAppt[providerId] = {
            'name': appt['providerName'] ?? appt['doctorName'] ?? '',
            'photo': appt['providerImage'] ?? appt['doctorImage'] ?? appt['providerPhoto'] ?? '',
          };
        }

        if (!latestAppointmentStatus.containsKey(providerId) || 
            (status != 'completed' && status != 'cancelled' && status != 'rejected')) {
          latestAppointmentStatus[providerId] = status;
        }

        final bool isActiveStatus = ['pending', 'pending_provider_approval', 'confirmed', 'accepted', 'completed'].contains(status.toLowerCase());
        final bool hasMessage = finalConversations.containsKey(providerId);

        if (isActiveStatus || hasMessage) {
          eligibleProviderIds.add(providerId);
        }
      }

      final List<Map<String, dynamic>> filteredData = [];
      final isAr = localeController.isArabic;
      
      for (var providerId in eligibleProviderIds) {
        if (finalConversations.containsKey(providerId)) {
          final item = finalConversations[providerId]!;
          item['appointmentStatus'] = latestAppointmentStatus[providerId] ?? '';
          if ((item['name'] ?? item['doctorName'] ?? '').toString().isEmpty) {
            item['name'] = providerDetailsFromAppt[providerId]?['name'];
          }
          if ((item['photo'] ?? item['doctorPhoto'] ?? item['profilePicture'] ?? '').toString().isEmpty) {
            item['photo'] = providerDetailsFromAppt[providerId]?['photo'];
          }
          filteredData.add(item);
        } else {
          filteredData.add({
            'doctorId': providerId,
            'providerId': providerId,
            'name': providerDetailsFromAppt[providerId]?['name'] ?? '',
            'photo': providerDetailsFromAppt[providerId]?['photo'] ?? '',
            'message': isAr ? 'ابدأ المحادثة' : 'Start conversation',
            'time': '',
            'unreadCount': 0,
            'appointmentStatus': latestAppointmentStatus[providerId] ?? '',
          });
        }
      }

      setState(() {
        messages = filteredData;
        filteredMessages = filteredData;
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _filterMessages() {
    final query = _searchController.text.toLowerCase().trim();

    if (query.isEmpty) {
      setState(() {
        filteredMessages = List.from(messages);
      });
      return;
    }

    setState(() {
      filteredMessages = messages.where((item) {
        final name = (item['name'] ?? item['doctorName'] ?? '')
            .toString()
            .toLowerCase();
        final message = (item['message'] ?? item['lastMessage'] ?? '')
            .toString()
            .toLowerCase();

        return name.contains(query) || message.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: PatientAppBar(
        title: localeController.isArabic ? 'الرسائل' : 'Messages',
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              cursorColor: AppColors.primary,
              style: TextStyle(color: p.inkDark, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: localeController.isArabic ? 'ابحث في الرسائل...' : 'Search messages...',
                hintStyle: TextStyle(color: p.inkMuted),
                prefixIcon: Icon(Icons.search, color: p.inkDark),
                filled: true,
                fillColor: p.filterSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: p.stroke),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: p.stroke),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : errorMessage != null
                  ? Center(
                      child: Text(
                        errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    )
                  : filteredMessages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 64, color: p.inkMuted.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            Text(
                              localeController.isArabic ? 'لا توجد محادثات بعد' : 'No conversations yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: p.inkDark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              localeController.isArabic 
                                  ? 'ستظهر هنا محادثاتك مع مقدمي الرعاية بعد إرسال طلب حجز.' 
                                  : 'Your conversations with care providers will appear here after sending a booking request.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: p.inkMuted, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredMessages.length,
                      itemBuilder: (context, index) {
                        final item = filteredMessages[index];

                        final String name =
                            (item['name'] ?? item['doctorName'] ?? 'Doctor')
                                .toString();

                        final String message =
                            (item['message'] ?? item['lastMessage'] ?? '')
                                .toString();

                        final String time =
                            (item['time'] ?? item['sentAt'] ?? '').toString();

                        final String doctorId =
                            (item['doctorId'] ?? item['providerId'] ?? '')
                                .toString();

                        final String status = 
                            (item['appointmentStatus'] ?? '').toString();
                            
                        final int unreadCount = 
                            int.tryParse((item['unreadCount'] ?? item['unread'] ?? '0').toString()) ?? 0;
                            
                        final String photo = 
                            (item['photo'] ?? item['doctorPhoto'] ?? item['profilePicture'] ?? '').toString();

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  name: name,
                                  userId: widget.userId,
                                  doctorId: doctorId,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: p.surface,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: p.stroke),
                              boxShadow: [_cardShadow(p)],
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: p.surface,
                                  backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                                  child: photo.isEmpty 
                                      ? const Icon(Icons.person, color: AppColors.primary)
                                      : null,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: p.inkDark,
                                                fontSize: 16,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (status.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(status).withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: _getStatusColor(status).withValues(alpha: 0.3)),
                                              ),
                                              child: Text(
                                                _getStatusText(status),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: _getStatusColor(status),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        message,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: unreadCount > 0 ? p.inkDark : p.inkMuted,
                                          fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      time,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: unreadCount > 0 ? AppColors.primary : p.inkMuted,
                                        fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                    if (unreadCount > 0) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          unreadCount.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  BoxShadow _cardShadow(CarelinkPalette p) {
    return BoxShadow(
      color: Colors.black.withValues(alpha: p.isDark ? 0.22 : 0.045),
      blurRadius: 16,
      offset: const Offset(0, 8),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
      case 'accepted':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    final isAr = localeController.isArabic;
    switch (status.toLowerCase()) {
      case 'pending':
        return isAr ? 'قيد الانتظار' : 'Pending';
      case 'confirmed':
      case 'accepted':
        return isAr ? 'مؤكد' : 'Confirmed';
      case 'completed':
        return isAr ? 'مكتمل' : 'Completed';
      case 'cancelled':
      case 'rejected':
        return isAr ? 'ملغي' : 'Cancelled';
      default:
        return status;
    }
  }
}
