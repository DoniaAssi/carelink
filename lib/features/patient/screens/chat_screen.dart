import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/models/booking_request_model.dart';
import 'package:carelink/shared/models/chat_message_model.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/services/medical_record_service.dart';

import 'select_service_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.name,
    required this.userId,
    required this.doctorId,
    this.currentUserId,
    this.isDoctorView = false,
    this.peerImageUrl,
  });

  final String name;
  final String userId;
  final String doctorId;
  final String? currentUserId;
  final bool isDoctorView;
  final String? peerImageUrl;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiService _api = ApiService();
  final MedicalRecordService _recordService = MedicalRecordService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<ChatMessage> _messages = [];
  ProviderModel? _provider;
  Timer? _pollTimer;
  Timer? _heartbeatTimer;
  Timer? _typingStopTimer;
  Timer? _recordingTimer;
  StreamSubscription<List<int>>? _recordingStreamSubscription;
  final List<int> _recordedWebBytes = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isUploading = false;
  bool _isPolling = false;
  bool _providerIsTyping = false;
  bool _providerIsOnline = false;
  bool _typingSent = false;
  bool _isRecording = false;
  bool _cancelRecording = false;
  int _recordingSeconds = 0;
  String? _playingMessageId;
  DateTime? _providerLastActive;
  String? _loadError;

  bool get _isArabic => context.l10n.isArabic;
  String _text(String english, String arabic) => _isArabic ? arabic : english;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageChanged);
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingMessageId = null);
    });
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.wait([_loadConversation(), _loadProvider()]);
    if (!mounted) return;
    unawaited(_markRead());
    unawaited(_sendHeartbeat());
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollConversation(),
    );
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _sendHeartbeat(),
    );
  }

  @override
  void dispose() {
    if (_typingSent) {
      unawaited(
        _api.setChatTyping(
          senderId: widget.userId,
          receiverId: widget.doctorId,
          isTyping: false,
        ),
      );
    }
    _pollTimer?.cancel();
    _heartbeatTimer?.cancel();
    _typingStopTimer?.cancel();
    _recordingTimer?.cancel();
    unawaited(_recordingStreamSubscription?.cancel());
    _messageController
      ..removeListener(_onMessageChanged)
      ..dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    unawaited(_recorder.dispose());
    unawaited(_audioPlayer.dispose());
    super.dispose();
  }

  void _onMessageChanged() {
    if (mounted) setState(() {});
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText && !_typingSent) {
      _typingSent = true;
      unawaited(
        _api.setChatTyping(
          senderId: widget.userId,
          receiverId: widget.doctorId,
          isTyping: true,
        ),
      );
    }
    _typingStopTimer?.cancel();
    _typingStopTimer = Timer(const Duration(seconds: 2), () {
      if (!_typingSent) return;
      _typingSent = false;
      unawaited(
        _api.setChatTyping(
          senderId: widget.userId,
          receiverId: widget.doctorId,
          isTyping: false,
        ),
      );
    });
  }

  Future<void> _loadProvider() async {
    try {
      final data = await _api.getProviderById(widget.doctorId);
      if (mounted) setState(() => _provider = ProviderModel.fromJson(data));
    } catch (_) {
      // The route-provided name remains available if profile loading fails.
    }
  }

  Future<void> _loadConversation({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final rows = await _api.getChatMessages(
        widget.userId,
        widget.doctorId,
        viewerId: widget.userId,
      );
      final loaded =
          rows
              .whereType<Map>()
              .map(
                (row) => ChatMessage.fromJson(Map<String, dynamic>.from(row)),
              )
              .toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      if (!mounted) return;
      final wasNearBottom =
          !_scrollController.hasClients ||
          _scrollController.position.maxScrollExtent -
                  _scrollController.position.pixels <
              100;
      setState(() {
        _messages = loaded;
        _isLoading = false;
        _loadError = null;
      });
      if (showLoader || wasNearBottom) _scrollToBottom(animated: !showLoader);
    } catch (_) {
      if (!mounted || !showLoader) return;
      setState(() {
        _isLoading = false;
        _loadError = _text(
          'Messages could not be loaded.',
          'تعذر تحميل الرسائل.',
        );
      });
    }
  }

  Future<void> _pollConversation() async {
    if (_isPolling || !mounted) return;
    _isPolling = true;
    try {
      await Future.wait([
        _loadConversation(showLoader: false),
        _loadPresence(),
        _loadTyping(),
      ]);
    } finally {
      _isPolling = false;
    }
  }

  Future<void> _markRead() async {
    try {
      await _api.markChatRead(
        readerId: widget.userId,
        otherUserId: widget.doctorId,
      );
    } catch (_) {}
  }

  Future<void> _sendHeartbeat() async {
    try {
      await _api.updateChatPresence(widget.userId);
    } catch (_) {}
  }

  Future<void> _loadPresence() async {
    try {
      final data = await _api.getChatPresence(widget.doctorId);
      if (!mounted) return;
      setState(() {
        _providerIsOnline = data['isOnline'] == true;
        _providerLastActive = DateTime.tryParse(
          data['lastActive']?.toString() ?? '',
        )?.toLocal();
      });
    } catch (_) {}
  }

  Future<void> _loadTyping() async {
    try {
      final typing = await _api.getChatTyping(
        senderId: widget.doctorId,
        receiverId: widget.userId,
      );
      if (mounted && typing != _providerIsTyping) {
        setState(() => _providerIsTyping = typing);
        if (typing) _scrollToBottom();
      }
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;
    final localId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = ChatMessage(
      messageId: localId,
      senderId: widget.userId,
      receiverId: widget.doctorId,
      type: ChatMessageType.text,
      text: text,
      createdAt: DateTime.now(),
      isPending: true,
    );
    setState(() {
      _isSending = true;
      _messages.add(optimistic);
    });
    _scrollToBottom();

    try {
      final response = await _api.sendChatMessage({
        'senderId': widget.userId,
        'receiverId': widget.doctorId,
        'message': text,
        'messageType': 'text',
      });
      if (!mounted) return;
      setState(() {
        final index = _messages.indexWhere((m) => m.messageId == localId);
        if (index >= 0) {
          _messages[index] = optimistic.copyWith(
            messageId: response['messageId']?.toString(),
            sentAt:
                DateTime.tryParse(
                  response['sentAt']?.toString() ?? '',
                )?.toLocal() ??
                DateTime.now(),
            isPending: false,
          );
        }
        _isSending = false;
        if (_messageController.text.trim() == text) {
          _messageController.clear();
        }
      });
      unawaited(_loadConversation(showLoader: false));
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.messageId == localId);
        _isSending = false;
      });
      _showError(
        _text(
          'Message was not sent. Please try again.',
          'لم يتم إرسال الرسالة. حاول مرة أخرى.',
        ),
      );
    }
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: kIsWeb,
    );
    final file = result?.files.single;
    if (file == null) return;
    await _sendAttachment(
      fileName: file.name,
      filePath: file.path,
      fileBytes: file.bytes,
    );
  }

  Future<void> _sendAttachment({
    required String fileName,
    String? filePath,
    List<int>? fileBytes,
    int? voiceDurationSeconds,
  }) async {
    setState(() => _isUploading = true);
    try {
      await _api.sendChatAttachment(
        senderId: widget.userId,
        receiverId: widget.doctorId,
        fileName: fileName,
        filePath: filePath,
        fileBytes: fileBytes,
        voiceDurationSeconds: voiceDurationSeconds,
      );
      await _loadConversation(showLoader: false);
      _scrollToBottom();
    } catch (_) {
      _showError(
        _text('The attachment could not be sent.', 'تعذر إرسال المرفق.'),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _shareMedicalRecord() async {
    List<Map<String, dynamic>> records;
    try {
      records = await _recordService.listForPatient(
        widget.userId,
        requesterUserId: widget.userId,
        requesterRole: 'patient',
      );
    } catch (_) {
      _showError(_text('Records could not be loaded.', 'تعذر تحميل السجلات.'));
      return;
    }
    if (!mounted) return;
    final shareable = records.where((record) {
      final id = (record['id'] ?? record['recordId'] ?? '').toString();
      final url = (record['file_url'] ?? record['fileUrl'] ?? '').toString();
      return id.isNotEmpty && url.isNotEmpty;
    }).toList();

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.68,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    _text('Share Medical Record', 'مشاركة سجل طبي'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: shareable.isEmpty
                    ? Center(
                        child: Text(
                          _text(
                            'No uploaded records are available to share.',
                            'لا توجد سجلات مرفوعة متاحة للمشاركة.',
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                        itemCount: shareable.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final record = shareable[index];
                          final title =
                              (record['title'] ??
                                      record['file_name'] ??
                                      _text('Medical record', 'سجل طبي'))
                                  .toString();
                          return ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.description_outlined),
                            ),
                            title: Text(title, maxLines: 1),
                            subtitle: Text(
                              _text(
                                'Shared from CareLink Records',
                                'مشاركة من سجلات CareLink',
                              ),
                            ),
                            trailing: const Icon(Icons.send_outlined),
                            onTap: () => Navigator.pop(context, record),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;

    setState(() => _isUploading = true);
    try {
      await _api.sendChatMessage({
        'senderId': widget.userId,
        'receiverId': widget.doctorId,
        'message': _text(
          'Shared from CareLink Records',
          'مشاركة من سجلات CareLink',
        ),
        'messageType': 'medical_record',
        'medicalRecordId': (selected['id'] ?? selected['recordId']).toString(),
      });
      await _loadConversation(showLoader: false);
      _scrollToBottom();
    } catch (_) {
      _showError(
        _text('The medical record could not be shared.', 'تعذرت مشاركة السجل.'),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _startRecording() async {
    if (_isUploading || _isSending) return;
    if (!await _recorder.hasPermission()) {
      _showError(
        _text(
          'Microphone permission is required for voice messages.',
          'يلزم السماح باستخدام الميكروفون للرسائل الصوتية.',
        ),
      );
      return;
    }
    if (kIsWeb) {
      _recordedWebBytes.clear();
      final stream = await _recorder.startStream(
        const RecordConfig(encoder: AudioEncoder.opus),
      );
      _recordingStreamSubscription = stream.listen(_recordedWebBytes.addAll);
    } else {
      final path =
          '${(await getTemporaryDirectory()).path}/carelink-${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
    }
    if (!mounted) return;
    setState(() {
      _isRecording = true;
      _cancelRecording = false;
      _recordingSeconds = 0;
    });
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordingSeconds++);
    });
  }

  Future<void> _finishRecording() async {
    if (!_isRecording) return;
    _recordingTimer?.cancel();
    final path = await _recorder.stop();
    await _recordingStreamSubscription?.cancel();
    _recordingStreamSubscription = null;
    final shouldCancel = _cancelRecording || _recordingSeconds < 1;
    final duration = _recordingSeconds;
    final webBytes = List<int>.from(_recordedWebBytes);
    _recordedWebBytes.clear();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _cancelRecording = false;
        _recordingSeconds = 0;
      });
    }
    if (!shouldCancel && (path != null || webBytes.isNotEmpty)) {
      await _sendAttachment(
        fileName:
            'voice-${DateTime.now().millisecondsSinceEpoch}.${kIsWeb ? 'webm' : 'm4a'}',
        filePath: path,
        fileBytes: kIsWeb ? webBytes : null,
        voiceDurationSeconds: duration,
      );
    }
  }

  Future<void> _cancelVoiceRecording() async {
    if (!_isRecording) return;
    _cancelRecording = true;
    await _finishRecording();
  }

  Future<void> _playVoice(ChatMessage message) async {
    final url = _absoluteUrl(message.attachmentUrl);
    if (url == null) return;
    if (_playingMessageId == message.messageId) {
      await _audioPlayer.stop();
      setState(() => _playingMessageId = null);
      return;
    }
    await _audioPlayer.stop();
    await _audioPlayer.play(UrlSource(url));
    if (mounted) setState(() => _playingMessageId = message.messageId);
  }

  Future<void> _openAttachment(ChatMessage message) async {
    final url = _absoluteUrl(message.attachmentUrl);
    if (url == null) return;
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      _showError(_text('Unable to open this file.', 'تعذر فتح الملف.'));
    }
  }

  void _bookAppointment() {
    final provider = _provider;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SelectServiceScreen(
          request: BookingRequestModel(
            patientId: widget.userId,
            providerId: widget.doctorId,
            providerName: provider?.fullName ?? widget.name,
            providerRole: provider?.role ?? 'doctor',
            specialization: provider?.specialization ?? '',
            serviceType: '',
            appointmentDate: '',
            appointmentTime: '',
            visitLatitude: 0,
            visitLongitude: 0,
            visitAddress: '',
            locationNote: '',
            patientReason: '',
            symptoms: '',
            isUrgent: false,
            additionalNotes: '',
            price: provider?.consultationFee ?? 0,
            paymentMethod: '',
            paymentStatus: 'unpaid',
            bookingStatus: 'pending',
          ),
        ),
      ),
    );
  }

  void _prefill(String text) {
    _messageController.text = text;
    _messageController.selection = TextSelection.collapsed(offset: text.length);
    _messageFocusNode.requestFocus();
  }

  Future<void> _callProvider() async {
    final phone = _provider?.phone.trim() ?? '';
    if (phone.isEmpty) return;
    if (!await launchUrl(Uri(scheme: 'tel', path: phone)) && mounted) {
      _showError(_text('Unable to start the call.', 'تعذر بدء المكالمة.'));
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _absoluteUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return '${ApiService.baseUrl}${raw.startsWith('/') ? raw : '/$raw'}';
  }

  String _presenceLabel() {
    if (_providerIsTyping) return _text('Typing...', 'يكتب الآن...');
    if (_providerIsOnline) return _text('Online', 'متصل الآن');
    final last = _providerLastActive;
    if (last == null) return _text('Care provider', 'مقدم الرعاية');
    final difference = DateTime.now().difference(last);
    if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes.clamp(1, 59);
      return _text('Last seen $minutes min ago', 'آخر ظهور قبل $minutes دقيقة');
    }
    final now = DateTime.now();
    if (last.year == now.year &&
        last.month == now.month &&
        last.day == now.day) {
      final time = intl.DateFormat('h:mm a').format(last);
      return _text('Last seen today at $time', 'آخر ظهور اليوم $time');
    }
    return _text(
      'Last seen ${intl.DateFormat('MMM d, h:mm a').format(last)}',
      'آخر ظهور ${intl.DateFormat('d MMM، h:mm a').format(last)}',
    );
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final difference = today.difference(day).inDays;
    if (difference == 0) return _text('Today', 'اليوم');
    if (difference == 1) return _text('Yesterday', 'أمس');
    return intl.DateFormat('MMM d').format(date);
  }

  bool _differentDay(DateTime first, DateTime second) =>
      first.year != second.year ||
      first.month != second.month ||
      first.day != second.day;

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  String? _providerImageUrl() => _absoluteUrl(_provider?.profileImageUrl);

  @override
  Widget build(BuildContext context) {
    final palette = CarelinkPalette.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: palette.pageBg,
      appBar: _buildHeader(palette),
      body: Column(
        children: [
          Expanded(child: _buildConversation(palette)),
          _buildQuickActions(palette),
          _buildComposer(palette),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildHeader(CarelinkPalette palette) {
    final name = _provider?.fullName.trim().isNotEmpty == true
        ? _provider!.fullName
        : widget.name;
    final imageUrl = _providerImageUrl();
    final phone = _provider?.phone.trim() ?? '';
    return AppBar(
      toolbarHeight: 68,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: palette.surface,
      surfaceTintColor: palette.surface,
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: Icon(
          _isArabic ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
          color: palette.inkDark,
        ),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            foregroundImage: imageUrl == null ? null : NetworkImage(imageUrl),
            child: imageUrl == null
                ? const Icon(
                    Icons.medical_services_outlined,
                    color: AppColors.primary,
                    size: 21,
                  )
                : null,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.inkDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _providerIsOnline
                            ? AppColors.success
                            : palette.inkMuted,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          _presenceLabel(),
                          key: ValueKey(_presenceLabel()),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _providerIsTyping
                                ? AppColors.primary
                                : palette.inkMuted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
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
      actions: [
        if (phone.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: IconButton(
              tooltip: _text('Call provider', 'اتصل بمقدم الرعاية'),
              onPressed: _callProvider,
              style: IconButton.styleFrom(
                foregroundColor: AppColors.primary,
                backgroundColor: AppColors.primary.withValues(alpha: 0.09),
              ),
              icon: const Icon(Icons.call_outlined, size: 20),
            ),
          ),
      ],
    );
  }

  Widget _buildConversation(CarelinkPalette palette) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppColors.primary,
        ),
      );
    }
    if (_loadError != null) return _buildLoadError(palette);
    if (_messages.isEmpty && !_providerIsTyping) {
      return _buildEmptyState(palette);
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadConversation,
      child: ListView.builder(
        controller: _scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        itemCount: _messages.length + (_providerIsTyping ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _messages.length) return _typingBubble(palette);
          final message = _messages[index];
          final showDate =
              index == 0 ||
              _differentDay(message.createdAt, _messages[index - 1].createdAt);
          return Column(
            children: [
              if (showDate) _dateSeparator(message.createdAt, palette),
              _messageBubble(message, palette),
            ],
          );
        },
      ),
    );
  }

  Widget _dateSeparator(DateTime date, CarelinkPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.stroke),
        ),
        child: Text(
          _dateLabel(date),
          style: TextStyle(
            color: palette.inkMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _messageBubble(ChatMessage message, CarelinkPalette palette) {
    if (message.type == ChatMessageType.system) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          message.text,
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.inkMuted, fontSize: 12),
        ),
      );
    }
    final mine = message.senderId == widget.userId;
    return Align(
      alignment: mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.76,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsetsDirectional.fromSTEB(12, 9, 10, 7),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : palette.surface,
          borderRadius: BorderRadiusDirectional.only(
            topStart: const Radius.circular(18),
            topEnd: const Radius.circular(18),
            bottomStart: Radius.circular(mine ? 18 : 5),
            bottomEnd: Radius.circular(mine ? 5 : 18),
          ),
          border: mine ? null : Border.all(color: palette.stroke),
          boxShadow: mine
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.035),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _messageContent(message, mine, palette),
            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  intl.DateFormat('h:mm a').format(message.createdAt),
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    color: mine
                        ? Colors.white.withValues(alpha: 0.72)
                        : palette.inkMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (mine) ...[
                  const SizedBox(width: 5),
                  _messageStatus(message),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageContent(
    ChatMessage message,
    bool mine,
    CarelinkPalette palette,
  ) {
    final textColor = mine ? Colors.white : palette.inkDark;
    switch (message.type) {
      case ChatMessageType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GestureDetector(
                onTap: () => _openAttachment(message),
                child: Image.network(
                  _absoluteUrl(message.attachmentUrl) ?? '',
                  width: 220,
                  height: 150,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _fileCard(message, mine, palette),
                ),
              ),
            ),
            if (message.text.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(message.text, style: TextStyle(color: textColor)),
            ],
          ],
        );
      case ChatMessageType.pdf:
      case ChatMessageType.medicalRecord:
        return _fileCard(message, mine, palette);
      case ChatMessageType.voice:
        final playing = _playingMessageId == message.messageId;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => _playVoice(message),
              borderRadius: BorderRadius.circular(30),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Icon(
                  playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  color: textColor,
                  size: 27,
                ),
              ),
            ),
            const SizedBox(width: 7),
            SizedBox(
              width: 105,
              child: Row(
                children: List.generate(
                  15,
                  (index) => Expanded(
                    child: Container(
                      height: 5.0 + (index % 4) * 2.5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: textColor.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _duration(message.voiceDurationSeconds ?? 0),
              textDirection: TextDirection.ltr,
              style: TextStyle(color: textColor, fontSize: 12),
            ),
          ],
        );
      case ChatMessageType.text:
      case ChatMessageType.system:
        return Text(
          message.text,
          style: TextStyle(color: textColor, fontSize: 14.5, height: 1.38),
        );
    }
  }

  Widget _fileCard(ChatMessage message, bool mine, CarelinkPalette palette) {
    final foreground = mine ? Colors.white : palette.inkDark;
    final subtitle = message.type == ChatMessageType.medicalRecord
        ? _text('Shared from CareLink Records', 'مشاركة من سجلات CareLink')
        : _fileSize(message.attachmentSize);
    return InkWell(
      onTap: () => _openAttachment(message),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: mine
              ? Colors.white.withValues(alpha: 0.12)
              : palette.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: mine
                    ? Colors.white.withValues(alpha: 0.15)
                    : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                message.type == ChatMessageType.medicalRecord
                    ? Icons.medical_information_outlined
                    : Icons.picture_as_pdf_outlined,
                color: mine ? Colors.white : AppColors.primary,
                size: 21,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.attachmentName ?? _text('Attachment', 'مرفق'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground.withValues(alpha: 0.7),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.open_in_new_rounded, color: foreground, size: 17),
          ],
        ),
      ),
    );
  }

  Widget _messageStatus(ChatMessage message) {
    if (message.isPending) {
      return const Icon(
        Icons.schedule_rounded,
        size: 13,
        color: Colors.white70,
      );
    }
    final read = message.isRead || message.readAt != null;
    final delivered = message.deliveredAt != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          read || delivered ? Icons.done_all_rounded : Icons.done_rounded,
          size: 15,
          color: read
              ? const Color(0xFF9EF0C8)
              : Colors.white.withValues(alpha: 0.78),
        ),
        if (read) ...[
          const SizedBox(width: 2),
          Text(
            _text('Read', 'مقروءة'),
            style: const TextStyle(
              color: Color(0xFF9EF0C8),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  Widget _typingBubble(CarelinkPalette palette) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.stroke),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (index) => TweenAnimationBuilder<double>(
              key: ValueKey('typing-$index-${DateTime.now().second ~/ 2}'),
              tween: Tween(begin: 0.45, end: 1),
              duration: Duration(milliseconds: 450 + index * 120),
              builder: (_, value, child) =>
                  Opacity(opacity: value, child: child),
              child: Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(CarelinkPalette palette) {
    if (_isRecording) {
      return Material(
        color: palette.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
          child: Row(
            children: [
              const Icon(Icons.mic_rounded, color: Colors.redAccent, size: 19),
              const SizedBox(width: 7),
              Text(
                _duration(_recordingSeconds),
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  color: palette.inkDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _text('Release to send', 'اترك الزر للإرسال'),
                  style: TextStyle(color: palette.inkMuted, fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: _cancelVoiceRecording,
                child: Text(_text('Cancel', 'إلغاء')),
              ),
            ],
          ),
        ),
      );
    }
    final actions = [
      (
        Icons.calendar_month_outlined,
        _text('Book Appointment', 'حجز موعد'),
        _bookAppointment,
      ),
      (
        Icons.description_outlined,
        _text('Share Record', 'مشاركة سجل'),
        _shareMedicalRecord,
      ),
      (
        Icons.medication_outlined,
        _text('Medication Question', 'سؤال عن الدواء'),
        () => _prefill(
          _text(
            'I have a question about my medication.',
            'لدي سؤال بخصوص دوائي.',
          ),
        ),
      ),
      (
        Icons.follow_the_signs_outlined,
        _text('Follow-up', 'طلب متابعة'),
        () => _prefill(
          _text('I would like to request a follow-up.', 'أرغب في طلب متابعة.'),
        ),
      ),
    ];
    return Material(
      color: palette.surface,
      child: SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          itemCount: actions.length,
          separatorBuilder: (context, index) => const SizedBox(width: 7),
          itemBuilder: (context, index) {
            final action = actions[index];
            return ActionChip(
              avatar: Icon(action.$1, size: 16, color: AppColors.primary),
              label: Text(action.$2),
              onPressed: action.$3,
              visualDensity: VisualDensity.compact,
              side: BorderSide(color: palette.stroke),
              backgroundColor: palette.surface,
              labelStyle: TextStyle(
                color: palette.inkDark,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildComposer(CarelinkPalette palette) {
    final canSend =
        _messageController.text.trim().isNotEmpty &&
        !_isSending &&
        !_isUploading;
    return Material(
      color: palette.surface,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(10, 7, 10, 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: _text('Attach file', 'إرفاق ملف'),
              onPressed: _isUploading ? null : _pickAttachment,
              color: AppColors.primary,
              icon: _isUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Icon(Icons.attach_file_rounded),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 3, 5, 3),
                decoration: BoxDecoration(
                  color: palette.pageBg,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: palette.stroke),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _messageFocusNode,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.multiline,
                        style: TextStyle(
                          color: palette.inkDark,
                          fontSize: 14.5,
                        ),
                        decoration: InputDecoration(
                          hintText: _text('Type a message...', 'اكتب رسالة...'),
                          hintStyle: TextStyle(color: palette.inkMuted),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 11,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: canSend || _isSending
                          ? IconButton(
                              tooltip: _text('Send message', 'إرسال الرسالة'),
                              onPressed: canSend ? _sendMessage : null,
                              style: IconButton.styleFrom(
                                padding: EdgeInsets.zero,
                                foregroundColor: Colors.white,
                                backgroundColor: AppColors.primary,
                              ),
                              icon: _isSending
                                  ? const SizedBox(
                                      width: 17,
                                      height: 17,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Transform.flip(
                                      flipX: _isArabic,
                                      child: const Icon(
                                        Icons.send_rounded,
                                        size: 19,
                                      ),
                                    ),
                            )
                          : GestureDetector(
                              onLongPressStart: (_) => _startRecording(),
                              onLongPressEnd: (_) => _finishRecording(),
                              onLongPressMoveUpdate: (details) {
                                if (details.localOffsetFromOrigin.dx.abs() >
                                    85) {
                                  _cancelRecording = true;
                                }
                              },
                              onTap: () =>
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      duration: const Duration(seconds: 2),
                                      content: Text(
                                        _text(
                                          'Hold the microphone to record.',
                                          'اضغط مطولاً على الميكروفون للتسجيل.',
                                        ),
                                      ),
                                    ),
                                  ),
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary,
                                ),
                                child: const Icon(
                                  Icons.mic_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(CarelinkPalette palette) {
    final prompts = [
      (
        Icons.event_outlined,
        _text('Ask about your appointment', 'اسأل عن موعدك'),
        _text(
          'I have a question about my appointment.',
          'لدي سؤال بخصوص موعدي.',
        ),
      ),
      (
        Icons.description_outlined,
        _text('Share a medical report', 'شارك تقريراً طبياً'),
        '',
      ),
      (
        Icons.medication_outlined,
        _text('Request medication guidance', 'اطلب إرشادات دوائية'),
        _text(
          'I need guidance about my medication.',
          'أحتاج إلى إرشادات حول دوائي.',
        ),
      ),
      (
        Icons.follow_the_signs_outlined,
        _text('Schedule a follow-up', 'جدولة متابعة'),
        _text(
          'I would like to schedule a follow-up.',
          'أرغب في جدولة موعد متابعة.',
        ),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.forum_outlined,
                  color: AppColors.primary,
                  size: 30,
                ),
              ),
              const SizedBox(height: 17),
              Text(
                _text(
                  'Start a conversation with your provider',
                  'ابدأ محادثة مع مقدم الرعاية',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.inkDark,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _text(
                  'Ask a care question or securely share an existing medical record.',
                  'اطرح سؤالاً صحياً أو شارك سجلاً طبياً موجوداً بأمان.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.inkMuted,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              ...prompts.map(
                (prompt) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => prompt.$3.isEmpty
                        ? _shareMedicalRecord()
                        : _prefill(prompt.$3),
                    icon: Icon(prompt.$1, size: 18),
                    label: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(prompt.$2),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 45),
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: palette.stroke),
                      backgroundColor: palette.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadError(CarelinkPalette palette) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, color: palette.inkMuted, size: 42),
          const SizedBox(height: 12),
          Text(_loadError!, style: TextStyle(color: palette.inkMuted)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _loadConversation,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(_text('Try again', 'إعادة المحاولة')),
          ),
        ],
      ),
    );
  }

  String _duration(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  String _fileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return _text('Document', 'مستند');
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
