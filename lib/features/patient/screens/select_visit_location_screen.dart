import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:carelink/shared/widgets/carelink_background.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/models/booking_request_model.dart';
import 'package:carelink/features/patient/utils/booking_flow_exit_helper.dart';
import 'booking_review_screen.dart';
import 'package:carelink/features/patient/widgets/booking_step_indicator.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';

class SelectVisitLocationScreen extends StatefulWidget {
  final BookingRequestModel request;
  const SelectVisitLocationScreen({super.key, required this.request});

  @override
  State<SelectVisitLocationScreen> createState() =>
      _SelectVisitLocationScreenState();
}

class _SelectVisitLocationScreenState extends State<SelectVisitLocationScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  LatLng _marker = const LatLng(31.9539, 35.9106);
  bool _isResolving = false;
  bool _isSearching = false;
  double _zoom = 15;
  Timer? _searchDebounce;
  final List<_PlaceSearchResult> _searchResults = [];

  bool get _canContinue => _addressController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _marker = LatLng(
      widget.request.visitLatitude,
      widget.request.visitLongitude,
    );
    _addressController.text = widget.request.visitAddress;
    _noteController.text = widget.request.locationNote;
    _addressController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<List<_PlaceSearchResult>> _fetchPlacesFromNominatim(
    String query,
  ) async {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search?format=jsonv2&addressdetails=1&limit=6&q=${Uri.encodeQueryComponent(query)}',
    );
    final response = await http.get(
      uri,
      headers: const <String, String>{
        'User-Agent': 'carelink.app/1.0 (location-search)',
      },
    );
    if (response.statusCode != 200) return const [];
    final data = jsonDecode(response.body);
    if (data is! List) return const [];
    return data
        .map(_PlaceSearchResult.fromJson)
        .whereType<_PlaceSearchResult>()
        .toList();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _searchResults.clear();
        _isSearching = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);
      try {
        final results = await _fetchPlacesFromNominatim(query);
        if (!mounted) return;
        setState(() {
          _searchResults
            ..clear()
            ..addAll(results);
        });
      } finally {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  Future<void> _applySearchResult(_PlaceSearchResult result) async {
    final point = LatLng(result.latitude, result.longitude);
    setState(() {
      _marker = point;
      _addressController.text = result.displayName;
      _searchResults.clear();
      _zoom = 15.5;
    });
    _mapController.move(point, _zoom);
    await _resolveAddress(point);
  }

  Future<void> _useCurrentLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) throw Exception('Please enable location services.');

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        throw Exception(
          'Location permission is required to use current location.',
        );
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final point = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _marker = point;
        _zoom = 16;
      });
      _mapController.move(point, _zoom);
      await _resolveAddress(point);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.userMessage(e))),
      );
    }
  }

  String _cleanAddressString(String raw) {
    String formatted = raw
        .replaceAll(
          RegExp(r'Palestinian Territories', caseSensitive: false),
          'Palestine',
        )
        .replaceAll(
          RegExp(r'Palestinian Territory', caseSensitive: false),
          'Palestine',
        );
    formatted = formatted.replaceAll(
      RegExp(r'\bArea\s+[A-Z]\b', caseSensitive: false),
      '',
    );
    return formatted
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .fold<List<String>>([], (list, e) {
          if (!list.contains(e)) list.add(e);
          return list;
        })
        .join(', ');
  }

  Future<void> _resolveAddress(LatLng point) async {
    setState(() => _isResolving = true);
    try {
      final placemarks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;

        final streetClean = (p.street ?? '').toLowerCase().contains('area ')
            ? null
            : p.street;
        final subLocalityClean =
            (p.subLocality ?? '').toLowerCase().contains('area ')
            ? null
            : p.subLocality;
        final localityClean = p.locality;
        final subAdminAreaClean =
            (p.subAdministrativeArea ?? '').toLowerCase().contains('area ')
            ? null
            : p.subAdministrativeArea;
        final adminAreaClean =
            (p.administrativeArea ?? '').toLowerCase().contains('area ')
            ? null
            : p.administrativeArea;

        var countryClean = p.country ?? '';
        if (countryClean.toLowerCase() == 'palestinian territories' ||
            countryClean.toLowerCase().contains('palestinian')) {
          countryClean = 'Palestine';
        }

        final fromDeviceGeocoder = _joinNonEmptyParts([
          streetClean,
          subLocalityClean,
          localityClean,
          subAdminAreaClean,
          adminAreaClean,
          countryClean,
        ]);

        if (fromDeviceGeocoder.trim().isNotEmpty) {
          _addressController.text = _cleanAddressString(fromDeviceGeocoder);
          return;
        }
      }
      final fromNominatim = await _reverseGeocodeFromNominatim(point);
      if (fromNominatim.trim().isNotEmpty) {
        _addressController.text = _cleanAddressString(fromNominatim);
      }
    } catch (_) {
      final fromNominatim = await _reverseGeocodeFromNominatim(point);
      if (fromNominatim.trim().isNotEmpty) {
        _addressController.text = _cleanAddressString(fromNominatim);
      }
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  Future<String> _reverseGeocodeFromNominatim(LatLng point) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${point.latitude}&lon=${point.longitude}&zoom=18&addressdetails=1',
      );
      final response = await http.get(
        uri,
        headers: const <String, String>{
          'User-Agent': 'carelink.app/1.0 (reverse-geocoding)',
        },
      );
      if (response.statusCode != 200) return '';
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return '';
      return (data['display_name'] ?? '').toString().trim();
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return PatientScaffold(
      backgroundColor: p.pageBg,
      appBar: PatientAppBar(
        title: context.l10n.isArabic
            ? 'اختر الموقع'
            : context.tr('booking.location.title'),
        actions: [
          BookingFlowExitHelper.action(
            context: context,
            patientUserId: widget.request.patientId,
            hasProgress: true,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: BoxDecoration(
            color: p.pageBg,
            border: Border(top: BorderSide(color: p.stroke)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: p.isDark ? 0.28 : 0.08),
                blurRadius: 18,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: PatientPrimaryButton(
            height: 54,
            icon: Icons.check_rounded,
            onPressed: _canContinue
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookingReviewScreen(
                          request: widget.request.copyWith(
                            visitLatitude: _marker.latitude,
                            visitLongitude: _marker.longitude,
                            visitAddress: _addressController.text.trim(),
                            locationNote: _noteController.text.trim(),
                          ),
                        ),
                      ),
                    );
                  }
                : null,
            label: context.tr('booking.location.confirm'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        children: [
          const BookingStepIndicator(currentStep: BookingFlowStep.location),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.stroke),
              boxShadow: [_cardShadow(p)],
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 320,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _marker,
                            initialZoom: _zoom,
                            onTap: (_, point) {
                              setState(() => _marker = point);
                              _resolveAddress(point);
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'carelink.app',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _marker,
                                  width: 42,
                                  height: 42,
                                  child: const Icon(
                                    Icons.location_pin,
                                    color: AppColors.primary,
                                    size: 40,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Positioned(
                          right: 12,
                          top: 12,
                          child: _mapControlButton(
                            icon: Icons.my_location_rounded,
                            onTap: _useCurrentLocation,
                          ),
                        ),
                        Positioned(
                          right: 12,
                          top: 64,
                          child: Column(
                            children: [
                              _mapControlButton(
                                icon: Icons.add_rounded,
                                onTap: () {
                                  setState(() => _zoom += 0.6);
                                  _mapController.move(_marker, _zoom);
                                },
                              ),
                              const SizedBox(height: 8),
                              _mapControlButton(
                                icon: Icons.remove_rounded,
                                onTap: () {
                                  setState(() => _zoom -= 0.6);
                                  _mapController.move(_marker, _zoom);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _useCurrentLocation,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    side: const BorderSide(color: AppColors.primary),
                    foregroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.my_location_rounded),
                  label: Text(context.tr('booking.location.useCurrent')),
                ),
                const SizedBox(height: 16),
                _fieldLabel(context.tr('booking.location.address')),
                const SizedBox(height: 6),
                TextField(
                  controller: _addressController,
                  onChanged: _onSearchChanged,
                  cursorColor: AppColors.primary,
                  style: TextStyle(
                    color: p.inkDark,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: context.l10n.isArabic
                        ? 'اختر موقع الزيارة أو ابحث عن عنوان'
                        : 'Select a location or search address',
                    hintStyle: TextStyle(color: p.inkMuted),
                    filled: true,
                    fillColor: p.filterSurface,
                    suffixIcon: (_isResolving || _isSearching)
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _addressController.text.trim().isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _addressController.clear();
                              setState(() => _searchResults.clear());
                            },
                            icon: const Icon(Icons.close_rounded),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: p.stroke),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                if (_searchResults.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: p.stroke),
                    ),
                    child: ListView.separated(
                      itemCount: _searchResults.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: p.stroke),
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.location_on_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          title: Text(
                            result.primaryText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            result.secondaryText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _applySearchResult(result),
                        );
                      },
                    ),
                  ),
                ],
                _fieldLabel(context.tr('booking.location.note')),
                const SizedBox(height: 6),
                TextField(
                  controller: _noteController,
                  cursorColor: AppColors.primary,
                  style: TextStyle(
                    color: p.inkDark,
                    fontWeight: FontWeight.w600,
                  ),
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 120,
                  decoration: InputDecoration(
                    hintText: context.tr('booking.location.noteHint'),
                    hintStyle: TextStyle(color: p.inkMuted),
                    filled: true,
                    fillColor: p.filterSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: p.stroke),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, color: p.inkMuted, size: 14),
              const SizedBox(width: 6),
              Text(
                context.l10n.isArabic
                    ? 'يتم استخدام موقعك لهذا الحجز فقط'
                    : 'Your location is used for this booking only',
                style: TextStyle(color: p.inkMuted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    final p = CarelinkPalette.of(context);
    return Text(
      text,
      style: TextStyle(
        color: p.inkDark,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
    );
  }

  Widget _mapControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final p = CarelinkPalette.of(context);
    return PatientPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary),
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

String _joinNonEmptyParts(List<Object?> values) {
  final parts = <String>[];
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty && !parts.contains(text)) parts.add(text);
  }
  return parts.join(', ');
}

class _PlaceSearchResult {
  final String displayName;
  final double latitude;
  final double longitude;

  const _PlaceSearchResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });

  String get primaryText {
    final parts = displayName.split(',');
    for (final part in parts) {
      final text = part.trim();
      if (text.isNotEmpty) return text;
    }
    return displayName.trim().isEmpty
        ? 'Location unavailable'
        : displayName.trim();
  }

  String get secondaryText {
    final parts = <String>[];
    for (final raw in displayName.split(',')) {
      final text = raw.trim();
      if (text.isNotEmpty) parts.add(text);
    }
    if (parts.length <= 1) return 'Tap to select location';
    return parts.skip(1).join(', ');
  }

  static _PlaceSearchResult? fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    final lat = double.tryParse((json['lat'] ?? '').toString());
    final lon = double.tryParse((json['lon'] ?? '').toString());
    final name = (json['display_name'] ?? '').toString().trim();
    if (lat == null || lon == null || name.isEmpty) return null;
    return _PlaceSearchResult(displayName: name, latitude: lat, longitude: lon);
  }
}
