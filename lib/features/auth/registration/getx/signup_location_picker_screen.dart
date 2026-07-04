import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/shared/widgets/carelink_responsive.dart';

class SignupLocationResult {
  const SignupLocationResult({
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String address;
  final double latitude;
  final double longitude;
}

class SignupLocationPickerScreen extends StatefulWidget {
  const SignupLocationPickerScreen({
    super.key,
    this.initialAddress,
    this.initialLatitude,
    this.initialLongitude,
  });

  final String? initialAddress;
  final double? initialLatitude;
  final double? initialLongitude;

  @override
  State<SignupLocationPickerScreen> createState() =>
      _SignupLocationPickerScreenState();
}

class _SignupLocationPickerScreenState
    extends State<SignupLocationPickerScreen> {
  final _mapController = MapController();
  final _addressController = TextEditingController();

  late LatLng _marker;
  double _zoom = 15;
  bool _isResolving = false;

  bool get _canConfirm => _addressController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _marker = LatLng(
      widget.initialLatitude ?? 31.9038,
      widget.initialLongitude ?? 35.2034,
    );
    _addressController.text = widget.initialAddress ?? '';
    if (_addressController.text.trim().isEmpty) {
      _resolveAddress(_marker);
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) throw Exception('Please enable location services.');

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required.');
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
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
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

        final address = _joinNonEmptyParts([
          streetClean,
          subLocalityClean,
          localityClean,
          subAdminAreaClean,
          adminAreaClean,
          countryClean,
        ]);

        if (address.trim().isNotEmpty) {
          _addressController.text = _cleanAddressString(address);
          return;
        }
      }
      final fallback = await _reverseGeocodeFromNominatim(point);
      if (fallback.isNotEmpty) {
        _addressController.text = _cleanAddressString(fallback);
      }
    } catch (_) {
      final fallback = await _reverseGeocodeFromNominatim(point);
      if (fallback.isNotEmpty) {
        _addressController.text = _cleanAddressString(fallback);
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
        headers: const {'User-Agent': 'carelink.app/1.0 (signup-location)'},
      );
      if (response.statusCode != 200) return '';
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return '';
      return (data['display_name'] ?? '').toString().trim();
    } catch (_) {
      return '';
    }
  }

  void _confirm() {
    Navigator.pop(
      context,
      SignupLocationResult(
        address: _addressController.text.trim(),
        latitude: _marker.latitude,
        longitude: _marker.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CarelinkResponsiveScope(
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(
            context.tr('booking.location.chooseAddress'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: IconThemeData(color: colorScheme.onSurface),
          backgroundColor: colorScheme.surface,
          elevation: 0,
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: FilledButton(
              onPressed: _canConfirm ? _confirm : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  context.tr('booking.location.useThisAddress'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
        body: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            CarelinkResponsiveScope.horizontalPadding(context),
            8,
            CarelinkResponsiveScope.horizontalPadding(context),
            18,
          ),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 380,
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
                                size: 42,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: _MapButton(
                        icon: Icons.my_location_rounded,
                        onTap: _useCurrentLocation,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _addressController,
              minLines: 2,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: context.tr('booking.location.address'),
                labelStyle: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                ),
                prefixIcon: Icon(
                  Icons.location_on_outlined,
                  color: colorScheme.primary,
                ),
                suffixIcon: _isResolving
                    ? Padding(
                        padding: const EdgeInsets.all(14),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: colorScheme.surface,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: 1.5,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: colorScheme.primary),
        ),
      ),
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
