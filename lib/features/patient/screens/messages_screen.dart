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
      final data = await ApiService().getMessages(widget.userId);

      if (!mounted) return;

      setState(() {
        messages = data;
        filteredMessages = data;
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
                hintText: 'Search messages...',
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
                      child: Text(
                        'No messages found',
                        style: TextStyle(color: p.inkMuted, fontSize: 15),
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
                                const CircleAvatar(
                                  radius: 28,
                                  backgroundColor: AppColors.primary,
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: p.inkDark,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        message,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: p.inkMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  time,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: p.inkMuted,
                                  ),
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
}
