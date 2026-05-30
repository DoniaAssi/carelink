import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/shared/models/user.dart';
import 'package:carelink/shared/services/provider_profile_service.dart';
import 'nurse_ui.dart';

class NurseAvailability extends StatefulWidget {
  const NurseAvailability({Key? key, required this.user}) : super(key: key);

  final User user;

  @override
  State<NurseAvailability> createState() => _NurseAvailabilityState();
}

class _NurseAvailabilityState extends State<NurseAvailability> {
  final days = const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  bool isLoading = true;
  List<Map<String, dynamic>> slots = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await ProviderProfileService.getAvailability(widget.user.userId);
    if (!mounted) return;
    setState(() {
      slots = data
          .map(
            (slot) => {
              'day': slot['day']?.toString() ?? '',
              'startTime': _cleanTime(slot['startTime']),
              'endTime': _cleanTime(slot['endTime']),
            },
          )
          .where((slot) => slot['day'].toString().isNotEmpty)
          .toList();
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: NurseUi.background,
        appBar: AppBar(
          title: Text(NurseUi.label('Availability', 'Availability')),
          backgroundColor: NurseUi.background,
          foregroundColor: NurseUi.text,
          elevation: 0,
          actions: [NurseModeControls(providerUserId: widget.user.userId)],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          onPressed: () => _showSlotSheet(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Time'),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                children: [
                  Text(
                    'Available Times',
                    style: TextStyle(
                      color: NurseUi.text,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (slots.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Center(
                        child: Text(
                          'No availability times yet',
                          style: TextStyle(color: NurseUi.muted, fontSize: 16),
                        ),
                      ),
                    )
                  else
                    ...slots.map((slot) => _slotCard(slot)),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _save,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text(
                        'Save Availability',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _slotCard(Map<String, dynamic> slot) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: NurseUi.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NurseUi.border.withOpacity(0.8)),
      ),
      child: ListTile(
        leading: const Icon(Icons.schedule_rounded, color: AppColors.primaryDark),
        title: Text(
          slot['day'].toString(),
          style: TextStyle(color: NurseUi.text, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${slot['startTime']} - ${slot['endTime']}',
          style: TextStyle(color: NurseUi.muted),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: () => setState(() => slots.remove(slot)),
        ),
      ),
    );
  }

  Future<void> _showSlotSheet() async {
    String day = days.first;
    TimeOfDay start = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 17, minute: 0);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Availability Time',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: day,
                decoration: const InputDecoration(labelText: 'Day'),
                items: days
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setSheetState(() => day = value);
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start Time'),
                subtitle: Text(_formatTime(start)),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: start,
                  );
                  if (picked != null) setSheetState(() => start = picked);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('End Time'),
                subtitle: Text(_formatTime(end)),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: end,
                  );
                  if (picked != null) setSheetState(() => end = picked);
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      slots.add({
                        'day': day,
                        'startTime': _formatTime(start),
                        'endTime': _formatTime(end),
                      });
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Add Time'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final success = await ProviderProfileService.saveAvailability(
      widget.user.userId,
      slots,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Availability saved successfully' : 'Failed to save availability',
        ),
      ),
    );
    if (success) Navigator.pop(context);
  }

  String _cleanTime(dynamic value) {
    final text = value?.toString() ?? '';
    final parts = text.split(':');
    if (parts.length >= 2) return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    return text;
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
