import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/doctor_service.dart';
import '../../../core/app_colors.dart';

class DoctorScheduleScreen extends StatefulWidget {
  const DoctorScheduleScreen({super.key});

  @override
  State<DoctorScheduleScreen> createState() => _DoctorScheduleScreenState();
}

class _DoctorScheduleScreenState extends State<DoctorScheduleScreen> {
  final _doctorService = DoctorService();
  
  bool _isLoading = true;
  bool _isAvailable = true;
  List<dynamic> _slots = [];
  String _doctorId = '';

  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      _doctorId = prefs.getString('doctor_userId') ?? '';

      // Load availability status
      final availability = await _doctorService.getAvailabilityStatus(_doctorId);
      setState(() {
        _isAvailable = availability['isAvailable'] ?? true;
      });

      // Load schedule slots
      final slots = await _doctorService.getSchedule(_doctorId);
      setState(() {
        _slots = slots;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _toggleAvailability() async {
    try {
      final newStatus = !_isAvailable;
      await _doctorService.setAvailability(_doctorId, newStatus);
      setState(() {
        _isAvailable = newStatus;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You are now ${newStatus ? 'available' : 'unavailable'}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addSlot() async {
    String? selectedDay;
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Availability Slot'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Day Dropdown
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Day'),
                initialValue: selectedDay,
                items: _days.map((day) => DropdownMenuItem(
                  value: day,
                  child: Text(day),
                )).toList(),
                onChanged: (value) {
                  setDialogState(() => selectedDay = value);
                },
              ),
              const SizedBox(height: 16),
              // Start Time
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start Time'),
                trailing: TextButton(
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: startTime ?? const TimeOfDay(hour: 9, minute: 0),
                    );
                    if (time != null) {
                      setDialogState(() => startTime = time);
                    }
                  },
                  child: Text(
                    startTime != null ? startTime!.format(context) : 'Select',
                  ),
                ),
              ),
              // End Time
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('End Time'),
                trailing: TextButton(
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: endTime ?? const TimeOfDay(hour: 17, minute: 0),
                    );
                    if (time != null) {
                      setDialogState(() => endTime = time);
                    }
                  },
                  child: Text(
                    endTime != null ? endTime!.format(context) : 'Select',
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedDay == null || startTime == null || endTime == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                  return;
                }
                Navigator.pop(context, {
                  'day': selectedDay,
                  'startTime': startTime,
                  'endTime': endTime,
                });
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    ).then((result) async {
      if (result != null) {
        try {
          final startTimeStr = result['startTime'].format(context);
          final endTimeStr = result['endTime'].format(context);
          final timeRange = '$startTimeStr - $endTimeStr';
          print('Selected time: $timeRange');
          
          await _doctorService.addScheduleSlot(
            _doctorId,
            day: result['day'],
            startTime: _formatTimeForApi(result['startTime']),
            endTime: _formatTimeForApi(result['endTime']),
          );
          
          _loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Slot added successfully'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
            );
          }
        }
      }
    });
  }

  Future<void> _deleteSlot(String slotId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Slot'),
        content: const Text('Are you sure you want to delete this availability slot?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _doctorService.deleteScheduleSlot(_doctorId, slotId);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Slot deleted'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  String _formatTimeForApi(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule & Availability'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Availability Toggle
                Container(
                  padding: const EdgeInsets.all(16),
                  color: _isAvailable 
                      ? AppColors.success.withOpacity(0.1) 
                      : Colors.red.withOpacity(0.1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isAvailable ? Icons.check_circle : Icons.cancel,
                            color: _isAvailable ? AppColors.success : Colors.red,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isAvailable ? 'Available' : 'Unavailable',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: _isAvailable ? AppColors.success : Colors.red,
                                ),
                              ),
                              Text(
                                _isAvailable 
                                    ? 'You are accepting new patients' 
                                    : 'You are not accepting new patients',
                                style: TextStyle(
                                  color: _isAvailable ? AppColors.success : Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _isAvailable,
                        onChanged: (_) => _toggleAvailability(),
                        activeThumbColor: AppColors.success,
                      ),
                    ],
                  ),
                ),
                // Schedule Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Availability Slots',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _addSlot,
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                // Slots List
                Expanded(
                  child: _slots.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.calendar_today, size: 80, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No availability slots',
                                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add your available times',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _slots.length,
                          itemBuilder: (context, index) {
                            final slot = _slots[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.access_time, color: AppColors.primary),
                                ),
                                title: Text(
                                  slot['day'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  '${slot['startTime']} - ${slot['endTime']}',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteSlot(slot['slot_id']),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}