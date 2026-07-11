# Comprehensive Audit Results

## \payment\payment_screen.dart
- **Line 57** (Mock variables): `// 1. Simulate mock card payment success locally`
- **Line 78** (Mock variables): `paymentMethod: 'mock_card',`
- **Line 108** (Mock variables): `method: 'mock_card',`
- **Line 792** (Hardcoded Prices): `.padLeft(4, '0');`

## \screens\add_visit_report_screen.dart
- **Line 55** (DateTime.now()): `final now = DateTime.now();`
- **Line 57** (Hardcoded Prices): `'${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';`
- **Line 74** (DateTime.now()): `final now = DateTime.now();`
- **Line 84** (Hardcoded Prices): `'${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';`
- **Line 90** (DateTime.now()): `final now = DateTime.now();`
- **Line 99** (Hardcoded Prices): `'${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';`

## \screens\booking_details_screen.dart
- **Line 177** (DateTime.now()): `if (scheduledAt == null || !scheduledAt.isAfter(DateTime.now())) {`
- **Line 309** (DateTime.now()): `final d = DateTime.now().difference(t);`
- **Line 577** (DateTime.now()): `if (scheduledAt != null && scheduledAt.isBefore(DateTime.now())) {`
- **Line 922** (Hardcoded Available): `isAr ? 'متاح اليوم' : 'Available today',`
- **Line 1057** (Hardcoded Ready/Paid): `'paid' => isAr ? 'مدفوع' : 'Paid',`
- **Line 1467** (Hardcoded Prices): `(_paymentOverview?['providerAmount'] ?? '0').toString(),`
- **Line 1506** (Hardcoded Ready/Paid): `displayStatus = isAr ? 'مدفوع' : 'Paid';`
- **Line 1529** (Mock variables): `if (pm.toLowerCase() == 'mock_card' || pm.toLowerCase() == 'card') {`

## \screens\booking_screen.dart
- **Line 33** (DateTime.now()): `DateTime _selectedDate = DateTime.now();`
- **Line 34** (DateTime.now()): `DateTime _visibleStartDate = DateTime.now();`
- **Line 43** (DateTime.now()): `_selectedDate = DateTime.now();`
- **Line 120** (DateTime.now()): `final now = DateTime.now();`
- **Line 190** (Hardcoded Prices): `'${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')} $time24',`
- **Line 942** (DateTime.now()): `return slotDateTime.isBefore(DateTime.now());`
- **Line 1505** (Hardcoded Prices): `return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';`
- **Line 1517** (Hardcoded Prices): `return '${normalizedHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';`
- **Line 1520** (Hardcoded Prices): `return '${normalizedHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';`
- **Line 1534** (Hardcoded Prices): `return '${hour24.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';`
- **Line 1547** (Hardcoded Prices): `return '${hour24.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';`

## \screens\booking_success_screen.dart
- **Line 866** (Hardcoded Ratings): `fontSize: emphasized ? 14.5 : 13.5,`

## \screens\chat_screen.dart
- **Line 309** (DateTime.now()): `final localId = 'local-${DateTime.now().microsecondsSinceEpoch}';`
- **Line 316** (DateTime.now()): `createdAt: DateTime.now(),`
- **Line 343** (DateTime.now()): `DateTime.now(),`
- **Line 544** (DateTime.now()): `'${(await getTemporaryDirectory()).path}/carelink-${DateTime.now().millisecondsSinceEpoch}.m4a';`
- **Line 581** (DateTime.now()): `'voice-${DateTime.now().millisecondsSinceEpoch}.${kIsWeb ? 'webm' : 'm4a'}',`
- **Line 680** (DateTime.now()): `final difference = DateTime.now().difference(last);`
- **Line 685** (DateTime.now()): `final now = DateTime.now();`
- **Line 699** (DateTime.now()): `final now = DateTime.now();`
- **Line 1039** (Hardcoded Ratings): `height: 5.0 + (index % 4) * 2.5,`
- **Line 1062** (Hardcoded Ratings): `style: TextStyle(color: textColor, fontSize: 14.5, height: 1.38),`
- **Line 1189** (DateTime.now()): `key: ValueKey('typing-$index-${DateTime.now().second ~/ 2}'),`
- **Line 1355** (Hardcoded Ratings): `style: TextStyle(color: palette.inkDark, fontSize: 14.5),`
- **Line 1570** (Hardcoded Prices): `'${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';`

## \screens\edit_profile_screen.dart
- **Line 100** (Hardcoded Prices): `final month = localDate.month.toString().padLeft(2, '0');`
- **Line 101** (Hardcoded Prices): `final day = localDate.day.toString().padLeft(2, '0');`
- **Line 589** (DateTime.now()): `'profile_${widget.userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';`

## \screens\medical_records_screen.dart
- **Line 1409** (Hardcoded Ready/Paid): `_t('Ready', 'جاهز'),`

## \screens\medical_record_details_screen.dart
- **Line 109** (Hardcoded Prices): `m['follow_up_required'] == '1';`

## \screens\messages_screen.dart
- **Line 181** (DateTime.now()): `final now = DateTime.now();`
- **Line 188** (Hardcoded Prices): `final minute = local.minute.toString().padLeft(2, '0');`
- **Line 617** (Hardcoded Ready/Paid): `'paid' => _t('Paid', 'مدفوع'),`

## \screens\patient_care_hub_screen.dart
- **Line 832** (Hardcoded Task Count): `_t('4 Tasks', '4 مهام'),`
- **Line 840** (Hardcoded Task Count): `_t('2 Meds', '2 أدوية'),`
- **Line 848** (Hardcoded Task Count): `_t('5 Inst.', '5 تعليمات'),`
- **Line 856** (Hardcoded Task Count): `_t('3 Goals', '3 أهداف'),`
- **Line 947** (Mock variables): `// Generate dummy activities based on latest records + bookings`
- **Line 991** (DateTime.now()): `final dt = DateTime.tryParse(dateStr) ?? DateTime.now();`
- **Line 1034** (Hardcoded Prices): `'${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',`

## \screens\patient_favorites_screen.dart
- **Line 207** (Hardcoded Ratings): `fontSize: 14.5,`
- **Line 265** (Hardcoded Prices): `final rating = double.tryParse(prov['rating']?.toString() ?? '0') ?? 0.0;`
- **Line 278** (Hardcoded Prices): `prov['isAvailable']?.toString() == '1') &&`
- **Line 389** (Hardcoded Prices): `double.tryParse(data['rating']?.toString() ?? '0') ?? 0.0;`

## \screens\patient_home_screen.dart
- **Line 260** (DateTime.now()): `final hour = DateTime.now().hour;`
- **Line 840** (DateTime.now()): `final now = DateTime.now();`
- **Line 937** (Hardcoded Prices): `return '${h.toString()}:${m.toString().padLeft(2, '0')} $period';`
- **Line 1560** (DateTime.now()): `final hour = DateTime.now().hour;`
- **Line 5073** (Hardcoded Ratings): `fontSize: 14.5,`
- **Line 5487** (DateTime.now()): `final diff = DateTime.now().difference(dt);`
- **Line 5788** (Hardcoded Prices): `final day = scheduled?.day.toString() ?? '24';`
- **Line 5804** (DateTime.now()): `scheduled.year == DateTime.now().year &&`
- **Line 5805** (DateTime.now()): `scheduled.month == DateTime.now().month &&`
- **Line 5806** (DateTime.now()): `scheduled.day == DateTime.now().day;`

## \screens\patient_payment_history_screen.dart
- **Line 86** (Hardcoded Ready/Paid): `return isAr ? 'مدفوع' : 'Paid';`

## \screens\profile_screen.dart
- **Line 209** (Hardcoded Prices): `final year = date.year.toString().padLeft(4, '0');`
- **Line 210** (Hardcoded Prices): `final month = date.month.toString().padLeft(2, '0');`
- **Line 211** (Hardcoded Prices): `final day = date.day.toString().padLeft(2, '0');`

## \screens\providers_screen.dart
- **Line 552** (Hardcoded Ratings): `children: [null, 2.0, 5.0, 10.0].map((km) {`
- **Line 552** (Hardcoded Arrays): `children: [null, 2.0, 5.0, 10.0].map((km) {`
- **Line 574** (Hardcoded Arrays): `children: [null, 50.0, 100.0, 150.0].map((price) {`

## \screens\provider_details_screen.dart
- **Line 221** (DateTime.now()): `var date = DateTime.now();`
- **Line 1752** (DateTime.now()): `if (slotDateTime.isBefore(DateTime.now())) return false;`
- **Line 1814** (Hardcoded Prices): `return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';`
- **Line 1831** (Hardcoded Prices): `final time = '$hour12:${minute.toString().padLeft(2, '0')} $suffix';`
- **Line 1912** (Hardcoded Prices): `return '$hour12:${minute.toString().padLeft(2, '0')} $suffix';`
- **Line 2634** (Hardcoded Available): `return _availableDayLabel == _t('Available today', 'متاح اليوم')`
- **Line 2672** (DateTime.now()): `final today = names[DateTime.now().weekday];`
- **Line 2685** (Hardcoded Available): `return isToday ? _t('Available today', 'متاح اليوم') : slots.first.day;`
- **Line 2834** (Hardcoded Ratings): `fontSize: primary ? 14.5 : 14,`
- **Line 3211** (Hardcoded Ratings): `fontSize: 14.5,`

## \screens\schedule_screen.dart
- **Line 58** (DateTime.now()): `DateTime _focusedDay = DateTime.now();`
- **Line 108** (DateTime.now()): `final firstPast = first.isBefore(DateTime.now());`
- **Line 109** (DateTime.now()): `final secondPast = second.isBefore(DateTime.now());`
- **Line 134** (DateTime.now()): `final hasPassed = _dateOf(row)?.isBefore(DateTime.now()) ?? false;`
- **Line 284** (Mock variables): `paymentMethod: 'mock_card',`
- **Line 378** (Hardcoded Prices): `(row['isUrgent'] ?? '').toString() == '1',`
- **Line 504** (DateTime.now()): `final now = DateTime.now();`
- **Line 675** (DateTime.now()): `final now = DateTime.now();`
- **Line 872** (DateTime.now()): `final today = DateTime.now();`
- **Line 1378** (Hardcoded Ready/Paid): `'paid' => _t('Paid', 'مدفوع'),`

## \utils\rebook_flow_helper.dart
- **Line 223** (Hardcoded Prices): `(row['isUrgent'] ?? '').toString() == '1',`
- **Line 292** (Hardcoded Prices): `return '${value.year.toString().padLeft(4, '0')}-'`
- **Line 293** (Hardcoded Prices): `'${value.month.toString().padLeft(2, '0')}-'`
- **Line 294** (Hardcoded Prices): `'${value.day.toString().padLeft(2, '0')}';`
- **Line 299** (Hardcoded Prices): `return '${value.hour.toString().padLeft(2, '0')}:'`
- **Line 300** (Hardcoded Prices): `'${value.minute.toString().padLeft(2, '0')}';`

## \widgets\change_provider_modal.dart
- **Line 420** (Mock variables): `// Fake availability logic (or use real if availableTimeSlots exist)`

## \widgets\reschedule_modal.dart
- **Line 41** (DateTime.now()): `DateTime _weekStart = _startOfWeek(DateTime.now());`
- **Line 42** (DateTime.now()): `DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);`
- **Line 144** (DateTime.now()): `if (!available || _slotDateTime(date, time24).isBefore(DateTime.now())) {`
- **Line 1356** (Hardcoded Ratings): `fontSize: 14.5,`
- **Line 1524** (DateTime.now()): `if (_slotDateTime(date, time24).isBefore(DateTime.now())) continue;`
- **Line 1681** (Hardcoded Prices): `return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';`
- **Line 1688** (Hardcoded Prices): `final min = parts[1].padLeft(2, '0');`
- **Line 1701** (Hardcoded Prices): `final minute = match.group(2)!.padLeft(2, '0');`
- **Line 1705** (Hardcoded Prices): `return '${hour.toString().padLeft(2, '0')}:$minute';`
- **Line 1709** (Hardcoded Prices): `return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';`
- **Line 1723** (DateTime.now()): `final now = DateTime.now();`

## \widgets\smart_rebook_modal.dart
- **Line 60** (DateTime.now()): `final now = DateTime.now();`
- **Line 92** (Hardcoded Prices): `if (blocked.contains('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} $time')) continue;`
- **Line 167** (Hardcoded Prices): `if (!stillAvailable || blocked.contains('${_nearestDate!.year}-${_nearestDate!.month.toString().padLeft(2, '0')}-${_nearestDate!.day.toString().padLeft(2, '0')} $_nearestTime')) {`
- **Line 185** (Hardcoded Prices): `final dateStr = '${_nearestDate!.year}-${_nearestDate!.month.toString().padLeft(2, '0')}-${_nearestDate!.day.toString().padLeft(2, '0')}';`

