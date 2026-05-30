// import 'dart:async';
// import 'dart:convert';
// import 'dart:typed_data';

// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:http/http.dart' as http;
// import 'package:image_picker/image_picker.dart';
// import 'package:latlong2/latlong.dart';

// import '../../core/app_colors.dart';
// import '../../services/api_service.dart';

// class SignupScreen extends StatefulWidget {
//   const SignupScreen({super.key});

//   @override
//   State<SignupScreen> createState() => _SignupScreenState();
// }

// class _SignupScreenState extends State<SignupScreen> {
//   final _formKey = GlobalKey<FormState>();

//   final TextEditingController nameController = TextEditingController();
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController phoneController = TextEditingController();
//   final TextEditingController passwordController = TextEditingController();
//   final TextEditingController confirmPasswordController =
//       TextEditingController();

//   final TextEditingController specializationController =
//       TextEditingController();
//   final TextEditingController experienceYearsController =
//       TextEditingController();
//   final TextEditingController licenseNumberController = TextEditingController();
//   final TextEditingController serviceTypeController = TextEditingController();
//   final TextEditingController addressController = TextEditingController();
//   final TextEditingController profileImageUrlController =
//       TextEditingController();
//   final TextEditingController dateOfBirthController = TextEditingController();

//   String selectedRole = 'patient';
//   String? selectedGender;
//   bool isRegistering = false;
//   bool isGettingLocation = false;
//   bool obscurePassword = true;
//   bool obscureConfirmPassword = true;

//   double? gpsLat;
//   double? gpsLng;
//   String? selectedPlaceName;
//   Uint8List? profileImageBytes;
//   String? profileImageName;
//   bool showProfileImageUrlField = false;
//   final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

//   @override
//   void initState() {
//     super.initState();
//     selectedGender = 'prefer_not_to_say';
//   }

//   @override
//   void dispose() {
//     nameController.dispose();
//     emailController.dispose();
//     phoneController.dispose();
//     passwordController.dispose();
//     confirmPasswordController.dispose();
//     specializationController.dispose();
//     experienceYearsController.dispose();
//     licenseNumberController.dispose();
//     serviceTypeController.dispose();
//     addressController.dispose();
//     profileImageUrlController.dispose();
//     dateOfBirthController.dispose();
//     super.dispose();
//   }

//   void _showMessage(String text, {Color? color}) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).hideCurrentSnackBar();
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(text),
//         backgroundColor: color,
//         behavior: SnackBarBehavior.floating,
//       ),
//     );
//   }

//   Future<void> _pickDateOfBirth() async {
//     final now = DateTime.now();
//     final initial =
//         DateTime.tryParse(dateOfBirthController.text) ??
//         DateTime(now.year - 18, now.month, now.day);
//     final picked = await showDatePicker(
//       context: context,
//       initialDate: initial,
//       firstDate: DateTime(1900),
//       lastDate: now,
//     );
//     if (picked != null) {
//       dateOfBirthController.text = picked.toIso8601String().split('T').first;
//       setState(() {});
//     }
//   }

//   String _formatCoordinate(double value) => value.toStringAsFixed(6);

//   Future<void> getLocation() async {
//     FocusScope.of(context).unfocus();
//     setState(() => isGettingLocation = true);

//     try {
//       final result = await showModalBottomSheet<_PickedLocation>(
//         context: context,
//         isScrollControlled: true,
//         useSafeArea: true,
//         backgroundColor: Colors.transparent,
//         builder: (_) => _MapLocationPickerSheet(
//           initialLat: gpsLat,
//           initialLng: gpsLng,
//           initialAddress: addressController.text.trim(),
//           initialPlaceName: selectedPlaceName,
//         ),
//       );

//       if (result == null) return;

//       setState(() {
//         gpsLat = result.latitude;
//         gpsLng = result.longitude;
//         selectedPlaceName = result.placeName;
//       });
//       addressController.text = result.address;
//       _showMessage('Location selected from map', color: Colors.green);
//     } catch (e) {
//       _showMessage(
//         e.toString().replaceFirst('Exception: ', ''),
//         color: Colors.red,
//       );
//     } finally {
//       if (mounted) setState(() => isGettingLocation = false);
//     }
//   }

//   bool _isStrongPassword(String input) {
//     final regex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$');
//     return regex.hasMatch(input);
//   }

//   bool _isLikelyUrl(String input) {
//     final value = input.trim();
//     if (value.isEmpty) return true;
//     final uri = Uri.tryParse(value);
//     return uri != null && uri.hasScheme && uri.host.isNotEmpty;
//   }

//   Future<void> _pickProfileImage(ImageSource source) async {
//     try {
//       final picker = ImagePicker();
//       final file = await picker.pickImage(
//         source: source,
//         imageQuality: 80,
//         maxWidth: 1080,
//       );
//       if (file == null) return;
//       final bytes = await file.readAsBytes();
//       if (!mounted) return;
//       setState(() {
//         profileImageBytes = bytes;
//         profileImageName = file.name;
//         if (profileImageUrlController.text.trim().isNotEmpty) {
//           profileImageUrlController.clear();
//         }
//       });
//       _showMessage('Profile image selected', color: Colors.green);
//     } on MissingPluginException {
//       _showMessage(
//         'Image picker needs full app restart. Please stop and run again.',
//         color: Colors.red,
//       );
//     } catch (_) {
//       if (kIsWeb && source == ImageSource.camera) {
//         _showMessage(
//           'Camera not available on this browser/device. Try phone browser or Gallery.',
//           color: Colors.red,
//         );
//       } else {
//         _showMessage(
//           'Could not pick image. Please try again.',
//           color: Colors.red,
//         );
//       }
//     }
//   }

//   Future<void> registerUser() async {
//     if (!_formKey.currentState!.validate()) return;

//     if (selectedRole == 'patient') {
//       if (dateOfBirthController.text.trim().isEmpty) {
//         _showMessage('Please select date of birth', color: Colors.red);
//         return;
//       }
//       if (selectedGender == null || selectedGender!.trim().isEmpty) {
//         _showMessage('Please select gender', color: Colors.red);
//         return;
//       }
//     }

//     if (selectedRole == 'doctor' || selectedRole == 'nurse') {
//       final years = int.tryParse(experienceYearsController.text.trim());
//       if (years == null) {
//         _showMessage(
//           'Experience years must be a valid number',
//           color: Colors.red,
//         );
//         return;
//       }
//       if (selectedRole == 'doctor' &&
//           licenseNumberController.text.trim().isEmpty) {
//         _showMessage('Please enter doctor license number', color: Colors.red);
//         return;
//       }
//     }

//     setState(() => isRegistering = true);

//     try {
//       final response = await ApiService().register(
//         nameController.text.trim(),
//         emailController.text.trim(),
//         phoneController.text.trim(),
//         passwordController.text,
//         selectedRole,
//         confirmPassword: confirmPasswordController.text,
//         specialization: selectedRole == 'patient'
//             ? null
//             : specializationController.text.trim(),
//         addressText: addressController.text.trim(),
//         gpsLat: gpsLat,
//         gpsLng: gpsLng,
//         dateOfBirth: selectedRole == 'patient'
//             ? dateOfBirthController.text.trim()
//             : null,
//         gender: selectedRole == 'patient' ? selectedGender : null,
//         profileImageUrl: profileImageUrlController.text.trim(),
//         experienceYears: selectedRole == 'patient'
//             ? null
//             : int.tryParse(experienceYearsController.text.trim()),
//         licenseNumber: selectedRole == 'patient'
//             ? null
//             : licenseNumberController.text.trim(),
//         serviceType: selectedRole == 'patient'
//             ? null
//             : serviceTypeController.text.trim(),
//       );

//       _showMessage(
//         response['message']?.toString() ?? 'Account created successfully',
//         color: Colors.green,
//       );
//       if (mounted) Navigator.pop(context);
//     } catch (e) {
//       _showMessage(
//         e.toString().replaceFirst('Exception: ', ''),
//         color: Colors.red,
//       );
//     } finally {
//       if (mounted) setState(() => isRegistering = false);
//     }
//   }

//   Widget _customField({
//     String? label,
//     required String hint,
//     required IconData icon,
//     required TextEditingController controller,
//     bool obscure = false,
//     TextInputType keyboardType = TextInputType.text,
//     Widget? suffixIcon,
//     String? Function(String?)? validator,
//     bool readOnly = false,
//     VoidCallback? onTap,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 14),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           if (label != null) ...[
//             Text(
//               label,
//               style: const TextStyle(
//                 fontSize: 13,
//                 fontWeight: FontWeight.w600,
//                 color: Color(0xFF51606F),
//               ),
//             ),
//             const SizedBox(height: 7),
//           ],
//           Container(
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(16),
//               border: Border.all(color: const Color(0xFFDDE4EC)),
//               boxShadow: const [
//                 BoxShadow(
//                   color: Color(0x0D0E1726),
//                   blurRadius: 10,
//                   offset: Offset(0, 4),
//                 ),
//               ],
//             ),
//             child: TextFormField(
//               controller: controller,
//               obscureText: obscure,
//               keyboardType: keyboardType,
//               validator: validator,
//               readOnly: readOnly,
//               onTap: onTap,
//               decoration: InputDecoration(
//                 hintText: hint,
//                 hintStyle: const TextStyle(
//                   color: Color(0xFF9AA3AF),
//                   fontWeight: FontWeight.w500,
//                 ),
//                 prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
//                 suffixIcon: suffixIcon,
//                 border: InputBorder.none,
//                 contentPadding: const EdgeInsets.symmetric(
//                   vertical: 16,
//                   horizontal: 16,
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildRoleTabs() {
//     const roles = [
//       ('patient', 'Patient', Icons.favorite_outline),
//       ('doctor', 'Doctor', Icons.medical_services_outlined),
//       ('nurse', 'Nurse', Icons.local_hospital_outlined),
//     ];

//     return Row(
//       children: roles.map((entry) {
//         final isSelected = selectedRole == entry.$1;
//         return Expanded(
//           child: GestureDetector(
//             onTap: () {
//               setState(() {
//                 selectedRole = entry.$1;
//               });
//             },
//             child: AnimatedContainer(
//               duration: const Duration(milliseconds: 140),
//               margin: const EdgeInsets.symmetric(horizontal: 3),
//               padding: const EdgeInsets.symmetric(vertical: 10),
//               decoration: BoxDecoration(
//                 color: isSelected
//                     ? AppColors.primary.withValues(alpha: 0.14)
//                     : Colors.white,
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(
//                   color: isSelected ? AppColors.primary : AppColors.border,
//                 ),
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Icon(
//                     entry.$3,
//                     size: 17,
//                     color: isSelected ? AppColors.primaryDark : Colors.grey,
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     entry.$2,
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       color: isSelected
//                           ? AppColors.primaryDark
//                           : AppColors.textLight,
//                       fontWeight: FontWeight.w700,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         );
//       }).toList(),
//     );
//   }

//   Widget _buildGenderDropdown() {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 14),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: const Color(0xFFDDE4EC)),
//         boxShadow: const [
//           BoxShadow(
//             color: Color(0x0D0E1726),
//             blurRadius: 10,
//             offset: Offset(0, 4),
//           ),
//         ],
//       ),
//       child: DropdownButtonFormField<String>(
//         initialValue: selectedGender,
//         decoration: const InputDecoration(
//           border: InputBorder.none,
//           prefixIcon: Icon(Icons.wc_outlined, color: AppColors.primary),
//           contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
//         ),
//         items: const [
//           DropdownMenuItem(value: 'male', child: Text('Male')),
//           DropdownMenuItem(value: 'female', child: Text('Female')),
//           DropdownMenuItem(value: 'other', child: Text('Other')),
//           DropdownMenuItem(
//             value: 'prefer_not_to_say',
//             child: Text('Prefer not to say'),
//           ),
//         ],
//         onChanged: (v) => setState(() => selectedGender = v),
//       ),
//     );
//   }

//   Widget _buildLocationCard() {
//     final hasLocation = gpsLat != null && gpsLng != null;
//     final placeLabel = (selectedPlaceName ?? '').trim();
//     final addressLabel = addressController.text.trim();

//     return Container(
//       margin: const EdgeInsets.only(top: 2, bottom: 12),
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: const Color(0xFFF4FAFD),
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: const Color(0xFFD9EAF5)),
//       ),
//       child: Row(
//         children: [
//           Icon(
//             Icons.my_location,
//             color: hasLocation ? Colors.green : Colors.orange,
//           ),
//           const SizedBox(width: 8),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   hasLocation
//                       ? 'Location selected from map'
//                       : 'Open map and pick your location',
//                   style: const TextStyle(
//                     fontSize: 13,
//                     color: Color(0xFF4A5A69),
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//                 if (hasLocation) ...[
//                   const SizedBox(height: 3),
//                   Text(
//                     placeLabel.isNotEmpty
//                         ? placeLabel
//                         : (addressLabel.isNotEmpty
//                               ? addressLabel
//                               : 'Unnamed location'),
//                     maxLines: 2,
//                     overflow: TextOverflow.ellipsis,
//                     style: const TextStyle(
//                       fontSize: 12.5,
//                       color: Color(0xFF2D3A46),
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                   const SizedBox(height: 2),
//                   Text(
//                     'Lat: ${_formatCoordinate(gpsLat!)}  |  Lng: ${_formatCoordinate(gpsLng!)}',
//                     style: const TextStyle(
//                       fontSize: 12,
//                       color: Color(0xFF667585),
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ],
//               ],
//             ),
//           ),
//           const SizedBox(width: 6),
//           if (isGettingLocation)
//             const SizedBox(
//               width: 18,
//               height: 18,
//               child: CircularProgressIndicator(strokeWidth: 2),
//             )
//           else
//             TextButton.icon(
//               onPressed: getLocation,
//               icon: const Icon(Icons.map_outlined, size: 18),
//               label: Text(
//                 hasLocation ? 'Change' : 'Open Map',
//                 style: const TextStyle(fontWeight: FontWeight.w700),
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSectionCard({
//     required String title,
//     required String subtitle,
//     required List<Widget> children,
//   }) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 14),
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: const Color(0xFFDDE4EC)),
//         boxShadow: const [
//           BoxShadow(
//             color: Color(0x080E1726),
//             blurRadius: 12,
//             offset: Offset(0, 5),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title,
//             style: const TextStyle(
//               fontSize: 16,
//               fontWeight: FontWeight.w800,
//               color: AppColors.textDark,
//             ),
//           ),
//           const SizedBox(height: 2),
//           Text(
//             subtitle,
//             style: const TextStyle(
//               fontSize: 12.5,
//               color: Color(0xFF8B97A3),
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           const SizedBox(height: 12),
//           ...children,
//         ],
//       ),
//     );
//   }

//   Widget _buildProfileImagePicker() {
//     final hasImage = profileImageBytes != null;
//     return Container(
//       margin: const EdgeInsets.only(bottom: 14),
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: const Color(0xFFF7FAFC),
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: const Color(0xFFDCE5ED)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'Profile Image (Optional)',
//             style: TextStyle(
//               fontSize: 13,
//               fontWeight: FontWeight.w700,
//               color: Color(0xFF4A5A69),
//             ),
//           ),
//           const SizedBox(height: 9),
//           Row(
//             children: [
//               CircleAvatar(
//                 radius: 27,
//                 backgroundColor: const Color(0xFFE7EEF5),
//                 backgroundImage: hasImage
//                     ? MemoryImage(profileImageBytes!)
//                     : null,
//                 child: hasImage
//                     ? null
//                     : const Icon(
//                         Icons.person_outline,
//                         color: Color(0xFF6B7A88),
//                       ),
//               ),
//               const SizedBox(width: 10),
//               Expanded(
//                 child: Text(
//                   hasImage
//                       ? (profileImageName ?? 'Image selected')
//                       : 'Choose image from camera or gallery',
//                   maxLines: 2,
//                   overflow: TextOverflow.ellipsis,
//                   style: const TextStyle(
//                     fontSize: 12.5,
//                     color: Color(0xFF607080),
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               Expanded(
//                 child: OutlinedButton.icon(
//                   onPressed: () => _pickProfileImage(ImageSource.camera),
//                   icon: const Icon(Icons.photo_camera_outlined, size: 18),
//                   label: const Text('Camera'),
//                 ),
//               ),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: OutlinedButton.icon(
//                   onPressed: () => _pickProfileImage(ImageSource.gallery),
//                   icon: const Icon(Icons.photo_library_outlined, size: 18),
//                   label: const Text('Gallery'),
//                 ),
//               ),
//             ],
//           ),
//           Align(
//             alignment: Alignment.centerRight,
//             child: TextButton(
//               onPressed: () {
//                 setState(() {
//                   showProfileImageUrlField = !showProfileImageUrlField;
//                 });
//               },
//               child: Text(
//                 showProfileImageUrlField
//                     ? 'Hide URL option'
//                     : 'Use image URL instead',
//               ),
//             ),
//           ),
//           if (showProfileImageUrlField)
//             _customField(
//               label: null,
//               hint: 'https://example.com/image.jpg',
//               icon: Icons.link_rounded,
//               controller: profileImageUrlController,
//               validator: (v) {
//                 final value = (v ?? '').trim();
//                 if (value.isEmpty) return null;
//                 if (!_isLikelyUrl(value)) return 'Please enter a valid URL';
//                 return null;
//               },
//             ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSubmitButton() {
//     return SizedBox(
//       width: double.infinity,
//       height: 56,
//       child: ElevatedButton(
//         onPressed: isRegistering ? null : registerUser,
//         style: ElevatedButton.styleFrom(
//           backgroundColor: AppColors.primary,
//           foregroundColor: Colors.white,
//           disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.55),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(16),
//           ),
//           elevation: 1,
//         ),
//         child: isRegistering
//             ? const SizedBox(
//                 width: 22,
//                 height: 22,
//                 child: CircularProgressIndicator(
//                   color: Colors.white,
//                   strokeWidth: 2.4,
//                 ),
//               )
//             : const Text(
//                 'Create Account',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 17,
//                   fontWeight: FontWeight.w700,
//                 ),
//               ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFEFF4F8),
//       body: SafeArea(
//         child: Column(
//           children: [
//             Container(
//               width: double.infinity,
//               padding: const EdgeInsets.fromLTRB(24, 24, 24, 26),
//               decoration: const BoxDecoration(
//                 gradient: LinearGradient(
//                   begin: Alignment.topCenter,
//                   end: Alignment.bottomCenter,
//                   colors: [Color(0xFF0E7E77), AppColors.primary],
//                 ),
//               ),
//               child: const Column(
//                 children: [
//                   CircleAvatar(
//                     radius: 34,
//                     backgroundColor: Color(0x24FFFFFF),
//                     child: Icon(
//                       Icons.person_add_alt_1_rounded,
//                       size: 34,
//                       color: Colors.white,
//                     ),
//                   ),
//                   SizedBox(height: 12),
//                   Text(
//                     'Create Your Account',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 26,
//                       fontWeight: FontWeight.w800,
//                     ),
//                   ),
//                   SizedBox(height: 6),
//                   Text(
//                     'Register as Patient, Doctor, or Nurse',
//                     style: TextStyle(
//                       color: Color(0xD9FFFFFF),
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             Expanded(
//               child: Container(
//                 width: double.infinity,
//                 decoration: const BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.only(
//                     topLeft: Radius.circular(30),
//                     topRight: Radius.circular(30),
//                   ),
//                 ),
//                 child: SingleChildScrollView(
//                   padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
//                   child: Center(
//                     child: ConstrainedBox(
//                       constraints: const BoxConstraints(maxWidth: 760),
//                       child: Form(
//                         key: _formKey,
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             _buildSectionCard(
//                               title: 'Choose Account Type',
//                               subtitle:
//                                   'Select your role to show the right form fields.',
//                               children: [_buildRoleTabs()],
//                             ),
//                             _buildSectionCard(
//                               title: 'Basic Information',
//                               subtitle:
//                                   'Please enter your personal and contact details.',
//                               children: [
//                                 _customField(
//                                   label: 'Full Name',
//                                   hint: 'Enter your full name',
//                                   icon: Icons.person_outline,
//                                   controller: nameController,
//                                   validator: (v) {
//                                     final value = (v ?? '').trim();
//                                     if (value.isEmpty)
//                                       return 'Please enter your full name';
//                                     if (value.length < 2)
//                                       return 'Name is too short';
//                                     if (RegExp(r'^\d+$').hasMatch(value)) {
//                                       return 'Name cannot be numbers only';
//                                     }
//                                     return null;
//                                   },
//                                 ),
//                                 _customField(
//                                   label: 'Email Address',
//                                   hint: 'example@domain.com',
//                                   icon: Icons.email_outlined,
//                                   controller: emailController,
//                                   keyboardType: TextInputType.emailAddress,
//                                   validator: (v) {
//                                     final value = (v ?? '').trim();
//                                     if (value.isEmpty)
//                                       return 'Please enter your email';
//                                     if (!_emailRegex.hasMatch(value)) {
//                                       return 'Invalid email format';
//                                     }
//                                     return null;
//                                   },
//                                 ),
//                                 _customField(
//                                   label: 'Phone Number',
//                                   hint: 'Enter your phone number',
//                                   icon: Icons.phone_outlined,
//                                   controller: phoneController,
//                                   keyboardType: TextInputType.phone,
//                                   validator: (v) {
//                                     final value = (v ?? '').trim();
//                                     if (value.isEmpty)
//                                       return 'Please enter your phone number';
//                                     if (!RegExp(
//                                       r'^\d{8,15}$',
//                                     ).hasMatch(value)) {
//                                       return 'Phone must be 8-15 digits';
//                                     }
//                                     return null;
//                                   },
//                                 ),
//                               ],
//                             ),
//                             _buildSectionCard(
//                               title: 'Security',
//                               subtitle:
//                                   'Use a strong password to protect your account.',
//                               children: [
//                                 _customField(
//                                   label: 'Password',
//                                   hint: 'Enter a strong password',
//                                   icon: Icons.lock_outline,
//                                   controller: passwordController,
//                                   obscure: obscurePassword,
//                                   suffixIcon: IconButton(
//                                     icon: Icon(
//                                       obscurePassword
//                                           ? Icons.visibility_off
//                                           : Icons.visibility,
//                                     ),
//                                     onPressed: () {
//                                       setState(
//                                         () =>
//                                             obscurePassword = !obscurePassword,
//                                       );
//                                     },
//                                   ),
//                                   validator: (v) {
//                                     final value = v ?? '';
//                                     if (value.isEmpty)
//                                       return 'Please enter a password';
//                                     if (!_isStrongPassword(value)) {
//                                       return 'Use 8+ chars with upper/lower/number';
//                                     }
//                                     return null;
//                                   },
//                                 ),
//                                 _customField(
//                                   label: 'Confirm Password',
//                                   hint: 'Re-enter your password',
//                                   icon: Icons.lock_reset_outlined,
//                                   controller: confirmPasswordController,
//                                   obscure: obscureConfirmPassword,
//                                   suffixIcon: IconButton(
//                                     icon: Icon(
//                                       obscureConfirmPassword
//                                           ? Icons.visibility_off
//                                           : Icons.visibility,
//                                     ),
//                                     onPressed: () {
//                                       setState(
//                                         () => obscureConfirmPassword =
//                                             !obscureConfirmPassword,
//                                       );
//                                     },
//                                   ),
//                                   validator: (v) {
//                                     if ((v ?? '').isEmpty) {
//                                       return 'Please confirm your password';
//                                     }
//                                     if (v != passwordController.text) {
//                                       return 'Passwords do not match';
//                                     }
//                                     return null;
//                                   },
//                                 ),
//                                 const Padding(
//                                   padding: EdgeInsets.only(bottom: 4),
//                                   child: Text(
//                                     'Password must contain uppercase, lowercase, number, and at least 8 characters.',
//                                     style: TextStyle(
//                                       fontSize: 12,
//                                       color: Color(0xFF8B97A3),
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                             _buildSectionCard(
//                               title: selectedRole == 'patient'
//                                   ? 'Patient Details'
//                                   : 'Professional Details',
//                               subtitle: selectedRole == 'patient'
//                                   ? 'Complete your profile to personalize your care.'
//                                   : 'Provide credentials and service information.',
//                               children: [
//                                 _buildProfileImagePicker(),
//                                 _customField(
//                                   label: selectedRole == 'patient'
//                                       ? 'Address'
//                                       : 'Address / Location (Optional)',
//                                   hint: selectedRole == 'patient'
//                                       ? 'Enter your full address'
//                                       : 'Enter your clinic or office address',
//                                   icon: Icons.location_on_outlined,
//                                   controller: addressController,
//                                   validator: (v) {
//                                     if (selectedRole == 'patient' &&
//                                         (v == null || v.trim().isEmpty)) {
//                                       return 'Address is required for patient';
//                                     }
//                                     return null;
//                                   },
//                                 ),
//                                 _buildLocationCard(),
//                                 if (selectedRole == 'patient') ...[
//                                   _customField(
//                                     label: 'Date of Birth',
//                                     hint: 'Select your date of birth',
//                                     icon: Icons.cake_outlined,
//                                     controller: dateOfBirthController,
//                                     readOnly: true,
//                                     onTap: _pickDateOfBirth,
//                                     validator: (v) {
//                                       if (selectedRole == 'patient' &&
//                                           (v == null || v.trim().isEmpty)) {
//                                         return 'Date of birth is required';
//                                       }
//                                       return null;
//                                     },
//                                   ),
//                                   _buildGenderDropdown(),
//                                 ] else ...[
//                                   _customField(
//                                     label: 'Specialization',
//                                     hint: 'e.g. Cardiology, Pediatrics',
//                                     icon: Icons.medical_services_outlined,
//                                     controller: specializationController,
//                                     validator: (v) {
//                                       if ((v ?? '').trim().isEmpty) {
//                                         return 'Please enter specialization';
//                                       }
//                                       return null;
//                                     },
//                                   ),
//                                   _customField(
//                                     label: 'Service Type (Optional)',
//                                     hint: 'Clinic, Home Visit, Telehealth',
//                                     icon: Icons.local_hospital_outlined,
//                                     controller: serviceTypeController,
//                                   ),
//                                   _customField(
//                                     label: 'Experience Years',
//                                     hint: 'Enter number of years',
//                                     icon: Icons.workspace_premium_outlined,
//                                     controller: experienceYearsController,
//                                     keyboardType: TextInputType.number,
//                                     validator: (v) {
//                                       final value = (v ?? '').trim();
//                                       final years = int.tryParse(value);
//                                       if (value.isEmpty)
//                                         return 'Please enter experience years';
//                                       if (years == null ||
//                                           years < 0 ||
//                                           years > 80) {
//                                         return 'Invalid years';
//                                       }
//                                       return null;
//                                     },
//                                   ),
//                                   _customField(
//                                     label: selectedRole == 'doctor'
//                                         ? 'License Number'
//                                         : 'License Number (Optional)',
//                                     hint: 'Enter professional license number',
//                                     icon: Icons.verified_user_outlined,
//                                     controller: licenseNumberController,
//                                     validator: (v) {
//                                       if (selectedRole == 'doctor' &&
//                                           (v == null || v.trim().isEmpty)) {
//                                         return 'License number is required for doctor';
//                                       }
//                                       return null;
//                                     },
//                                   ),
//                                 ],
//                               ],
//                             ),
//                             const SizedBox(height: 6),
//                             _buildSubmitButton(),
//                             const SizedBox(height: 14),
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: [
//                                 const Text(
//                                   'Already have an account? ',
//                                   style: TextStyle(color: Color(0xFF7D8A91)),
//                                 ),
//                                 GestureDetector(
//                                   onTap: () => Navigator.pop(context),
//                                   child: const Text(
//                                     'Sign In',
//                                     style: TextStyle(
//                                       color: AppColors.primary,
//                                       fontWeight: FontWeight.w700,
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _PickedLocation {
//   const _PickedLocation({
//     required this.latitude,
//     required this.longitude,
//     required this.address,
//     required this.placeName,
//   });

//   final double latitude;
//   final double longitude;
//   final String address;
//   final String placeName;
// }

// class _PlaceSearchResult {
//   const _PlaceSearchResult({
//     required this.title,
//     required this.subtitle,
//     required this.latitude,
//     required this.longitude,
//   });

//   factory _PlaceSearchResult.fromNominatim(Map<String, dynamic> json) {
//     final lat = double.tryParse((json['lat'] ?? '').toString()) ?? 0;
//     final lng = double.tryParse((json['lon'] ?? '').toString()) ?? 0;
//     final displayName = (json['display_name'] ?? '').toString();
//     final name = (json['name'] ?? '').toString().trim();
//     final address = json['address'];
//     String title = name.isNotEmpty ? name : displayName;
//     String subtitle = displayName;

//     if (address is Map<String, dynamic>) {
//       final city =
//           (address['city'] ??
//                   address['town'] ??
//                   address['village'] ??
//                   address['state'] ??
//                   '')
//               .toString();
//       final country = (address['country'] ?? '').toString();
//       final compact = [
//         city,
//         country,
//       ].where((e) => e.trim().isNotEmpty).join(', ');
//       if (compact.isNotEmpty) {
//         subtitle = compact;
//       }
//     }

//     if (title.trim().isEmpty) {
//       title = subtitle;
//     }

//     return _PlaceSearchResult(
//       title: title,
//       subtitle: subtitle,
//       latitude: lat,
//       longitude: lng,
//     );
//   }

//   final String title;
//   final String subtitle;
//   final double latitude;
//   final double longitude;
// }

// class _MapLocationPickerSheet extends StatefulWidget {
//   const _MapLocationPickerSheet({
//     required this.initialLat,
//     required this.initialLng,
//     required this.initialAddress,
//     required this.initialPlaceName,
//   });

//   final double? initialLat;
//   final double? initialLng;
//   final String initialAddress;
//   final String? initialPlaceName;

//   @override
//   State<_MapLocationPickerSheet> createState() =>
//       _MapLocationPickerSheetState();
// }

// class _MapLocationPickerSheetState extends State<_MapLocationPickerSheet> {
//   static const LatLng _defaultCenter = LatLng(31.9539, 35.9106);

//   final MapController _mapController = MapController();
//   final TextEditingController _searchController = TextEditingController();

//   late LatLng _pickedPoint;
//   late String _address;
//   late String _placeName;
//   final List<String> _recentSearches = [];
//   final List<_PlaceSearchResult> _searchResults = [];
//   Timer? _searchDebounce;
//   bool _resolvingAddress = false;
//   bool _locatingCurrent = false;
//   bool _searchingPlace = false;

//   @override
//   void initState() {
//     super.initState();
//     _pickedPoint = (widget.initialLat != null && widget.initialLng != null)
//         ? LatLng(widget.initialLat!, widget.initialLng!)
//         : _defaultCenter;
//     _address = widget.initialAddress;
//     _placeName = widget.initialPlaceName?.trim() ?? '';
//     _searchController.text = _placeName.isNotEmpty ? _placeName : _address;

//     if (_address.isEmpty) {
//       _resolveAddressForPoint(_pickedPoint);
//     }
//   }

//   @override
//   void dispose() {
//     _searchDebounce?.cancel();
//     _searchController.dispose();
//     super.dispose();
//   }

//   void _onSearchChanged(String value) {
//     _searchDebounce?.cancel();
//     _searchDebounce = Timer(const Duration(milliseconds: 450), () {
//       _runPlacesSearch(value);
//     });
//   }

//   Future<List<_PlaceSearchResult>> _fetchPlacesFromNominatim(
//     String query,
//   ) async {
//     final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
//       'q': query,
//       'format': 'jsonv2',
//       'addressdetails': '1',
//       'limit': '6',
//       'accept-language': 'ar,en',
//     });

//     final response = await http.get(
//       uri,
//       headers: const {
//         'Accept': 'application/json',
//         'User-Agent': 'carelink.app',
//       },
//     );
//     if (response.statusCode < 200 || response.statusCode >= 300) {
//       throw Exception('Search service unavailable');
//     }

//     final decoded = jsonDecode(response.body);
//     if (decoded is! List) return [];

//     return decoded
//         .whereType<Map<String, dynamic>>()
//         .map(_PlaceSearchResult.fromNominatim)
//         .where((e) => e.latitude != 0 || e.longitude != 0)
//         .toList();
//   }

//   Future<void> _runPlacesSearch(String value) async {
//     final query = value.trim();
//     if (query.length < 2) {
//       if (!mounted) return;
//       setState(() {
//         _searchingPlace = false;
//         _searchResults.clear();
//       });
//       return;
//     }

//     setState(() => _searchingPlace = true);
//     try {
//       final nominatimResults = await _fetchPlacesFromNominatim(query);
//       if (!mounted) return;
//       setState(() {
//         _searchResults
//           ..clear()
//           ..addAll(nominatimResults);
//       });
//     } catch (_) {
//       if (!mounted) return;
//       setState(() => _searchResults.clear());
//     } finally {
//       if (mounted) {
//         setState(() => _searchingPlace = false);
//       }
//     }
//   }

//   Future<void> _applySearchResult(_PlaceSearchResult result) async {
//     FocusScope.of(context).unfocus();
//     final point = LatLng(result.latitude, result.longitude);
//     setState(() {
//       _pickedPoint = point;
//       _searchController.text = result.title;
//       _recentSearches.removeWhere(
//         (entry) => entry.toLowerCase() == result.title.toLowerCase(),
//       );
//       _recentSearches.insert(0, result.title);
//       if (_recentSearches.length > 6) {
//         _recentSearches.removeRange(6, _recentSearches.length);
//       }
//       _searchResults.clear();
//     });
//     _mapController.move(point, 16.5);
//     await _resolveAddressForPoint(point);
//   }

//   Future<void> _searchPlaceByName([String? customQuery]) async {
//     final query = (customQuery ?? _searchController.text).trim();
//     if (query.isEmpty) return;

//     if (_searchResults.isEmpty) {
//       await _runPlacesSearch(query);
//     }

//     if (_searchResults.isNotEmpty) {
//       await _applySearchResult(_searchResults.first);
//       return;
//     }

//     // Fallback to platform geocoding if remote search returns nothing.
//     try {
//       final fallback = await locationFromAddress(query);
//       if (fallback.isNotEmpty) {
//         final first = fallback.first;
//         await _applySearchResult(
//           _PlaceSearchResult(
//             title: query,
//             subtitle: 'Location from device geocoder',
//             latitude: first.latitude,
//             longitude: first.longitude,
//           ),
//         );
//         return;
//       }
//     } catch (_) {}

//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(
//         content: Text('Could not find this place name'),
//         behavior: SnackBarBehavior.floating,
//       ),
//     );
//   }

//   Widget _buildSearchSuggestions() {
//     final query = _searchController.text.trim();
//     if (query.length < 2 && _recentSearches.isEmpty) {
//       return const SizedBox.shrink();
//     }

//     if (_searchingPlace && _searchResults.isEmpty) {
//       return const Padding(
//         padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
//         child: LinearProgressIndicator(minHeight: 2),
//       );
//     }

//     final showRecentOnly = query.length < 2 || _searchResults.isEmpty;
//     if (showRecentOnly && _recentSearches.isEmpty) {
//       return const SizedBox.shrink();
//     }

//     return Container(
//       margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: const Color(0xFFE1E8EF)),
//         boxShadow: const [
//           BoxShadow(
//             color: Color(0x080E1726),
//             blurRadius: 12,
//             offset: Offset(0, 5),
//           ),
//         ],
//       ),
//       child: ConstrainedBox(
//         constraints: const BoxConstraints(maxHeight: 180),
//         child: ListView(
//           padding: EdgeInsets.zero,
//           shrinkWrap: true,
//           children: showRecentOnly
//               ? _recentSearches
//                     .map(
//                       (entry) => ListTile(
//                         dense: true,
//                         leading: const Icon(Icons.history, size: 18),
//                         title: Text(
//                           entry,
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                         onTap: () {
//                           _searchController.text = entry;
//                           _searchPlaceByName(entry);
//                         },
//                       ),
//                     )
//                     .toList()
//               : _searchResults
//                     .map(
//                       (result) => ListTile(
//                         dense: true,
//                         leading: const Icon(Icons.place_outlined, size: 18),
//                         title: Text(
//                           result.title,
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                         subtitle: Text(
//                           result.subtitle,
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                         onTap: () => _applySearchResult(result),
//                       ),
//                     )
//                     .toList(),
//         ),
//       ),
//     );
//   }

//   Future<void> _moveToCurrentLocation() async {
//     setState(() => _locatingCurrent = true);
//     try {
//       final enabled = await Geolocator.isLocationServiceEnabled();
//       if (!enabled) {
//         throw Exception('Location services are disabled');
//       }

//       var permission = await Geolocator.checkPermission();
//       if (permission == LocationPermission.denied) {
//         permission = await Geolocator.requestPermission();
//       }
//       if (permission == LocationPermission.denied ||
//           permission == LocationPermission.deniedForever) {
//         throw Exception('Location permission is not granted');
//       }

//       final pos = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );
//       final point = LatLng(pos.latitude, pos.longitude);
//       if (!mounted) return;
//       setState(() => _pickedPoint = point);
//       _mapController.move(point, 16);
//       await _resolveAddressForPoint(point);
//     } catch (_) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Could not get current location'),
//           behavior: SnackBarBehavior.floating,
//         ),
//       );
//     } finally {
//       if (mounted) {
//         setState(() => _locatingCurrent = false);
//       }
//     }
//   }

//   Future<void> _resolveAddressForPoint(LatLng point) async {
//     setState(() => _resolvingAddress = true);
//     try {
//       final placemarks = await placemarkFromCoordinates(
//         point.latitude,
//         point.longitude,
//       );
//       final first = placemarks.isNotEmpty ? placemarks.first : null;

//       final place = [
//         first?.name,
//         first?.subLocality,
//         first?.locality,
//       ].where((e) => e != null && e.trim().isNotEmpty).join(', ');

//       final fullAddress = [
//         first?.street,
//         first?.subLocality,
//         first?.locality,
//         first?.administrativeArea,
//         first?.country,
//       ].where((e) => e != null && e.trim().isNotEmpty).join(', ');

//       if (!mounted) return;
//       setState(() {
//         _placeName = place;
//         _address = fullAddress;
//       });
//     } catch (_) {
//       if (!mounted) return;
//       setState(() {
//         _placeName = '';
//         _address = '';
//       });
//     } finally {
//       if (mounted) setState(() => _resolvingAddress = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final latText = _pickedPoint.latitude.toStringAsFixed(6);
//     final lngText = _pickedPoint.longitude.toStringAsFixed(6);
//     final title = _placeName.isNotEmpty ? _placeName : 'Selected location';
//     final address = _address.isNotEmpty
//         ? _address
//         : 'Address could not be resolved';

//     return Container(
//       decoration: const BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
//       ),
//       child: SizedBox(
//         height: MediaQuery.of(context).size.height * 0.88,
//         child: Column(
//           children: [
//             const SizedBox(height: 10),
//             Container(
//               width: 44,
//               height: 4.5,
//               decoration: BoxDecoration(
//                 color: const Color(0xFFD4DCE5),
//                 borderRadius: BorderRadius.circular(6),
//               ),
//             ),
//             Padding(
//               padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
//               child: Row(
//                 children: [
//                   const Expanded(
//                     child: Text(
//                       'Choose Location from Map',
//                       style: TextStyle(
//                         fontSize: 16.5,
//                         fontWeight: FontWeight.w800,
//                         color: AppColors.textDark,
//                       ),
//                     ),
//                   ),
//                   TextButton.icon(
//                     onPressed: _locatingCurrent ? null : _moveToCurrentLocation,
//                     icon: _locatingCurrent
//                         ? const SizedBox(
//                             width: 16,
//                             height: 16,
//                             child: CircularProgressIndicator(strokeWidth: 2),
//                           )
//                         : const Icon(Icons.my_location_outlined, size: 18),
//                     label: const Text('My Location'),
//                   ),
//                 ],
//               ),
//             ),
//             Padding(
//               padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
//               child: TextField(
//                 controller: _searchController,
//                 onChanged: _onSearchChanged,
//                 onSubmitted: (_) => _searchPlaceByName(),
//                 textInputAction: TextInputAction.search,
//                 decoration: InputDecoration(
//                   hintText: 'Search city, street, or area',
//                   prefixIcon: const Icon(Icons.search),
//                   suffixIcon: _searchingPlace
//                       ? const Padding(
//                           padding: EdgeInsets.all(12),
//                           child: SizedBox(
//                             width: 16,
//                             height: 16,
//                             child: CircularProgressIndicator(strokeWidth: 2),
//                           ),
//                         )
//                       : IconButton(
//                           icon: const Icon(Icons.arrow_forward_rounded),
//                           onPressed: _searchPlaceByName,
//                         ),
//                   isDense: true,
//                   filled: true,
//                   fillColor: const Color(0xFFF5F8FB),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: const BorderSide(color: Color(0xFFDCE4EC)),
//                   ),
//                   enabledBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: const BorderSide(color: Color(0xFFDCE4EC)),
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                     borderSide: const BorderSide(color: AppColors.primary),
//                   ),
//                 ),
//               ),
//             ),
//             _buildSearchSuggestions(),
//             Expanded(
//               child: FlutterMap(
//                 mapController: _mapController,
//                 options: MapOptions(
//                   initialCenter: _pickedPoint,
//                   initialZoom: 15,
//                   onTap: (_, point) {
//                     setState(() => _pickedPoint = point);
//                     _resolveAddressForPoint(point);
//                   },
//                 ),
//                 children: [
//                   TileLayer(
//                     urlTemplate:
//                         'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
//                     userAgentPackageName: 'carelink.app',
//                   ),
//                   MarkerLayer(
//                     markers: [
//                       Marker(
//                         point: _pickedPoint,
//                         width: 52,
//                         height: 52,
//                         child: const Icon(
//                           Icons.location_pin,
//                           size: 42,
//                           color: AppColors.primary,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//             Container(
//               width: double.infinity,
//               padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
//               decoration: const BoxDecoration(
//                 border: Border(top: BorderSide(color: Color(0xFFE6ECF2))),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   if (_resolvingAddress)
//                     const Padding(
//                       padding: EdgeInsets.only(bottom: 6),
//                       child: LinearProgressIndicator(minHeight: 2),
//                     ),
//                   Text(
//                     title,
//                     style: const TextStyle(
//                       fontSize: 14.5,
//                       fontWeight: FontWeight.w700,
//                       color: AppColors.textDark,
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     address,
//                     maxLines: 2,
//                     overflow: TextOverflow.ellipsis,
//                     style: const TextStyle(
//                       fontSize: 12.5,
//                       color: Color(0xFF657384),
//                     ),
//                   ),
//                   const SizedBox(height: 7),
//                   Text(
//                     'Lat: $latText  |  Lng: $lngText',
//                     style: const TextStyle(
//                       fontSize: 12.5,
//                       fontWeight: FontWeight.w600,
//                       color: Color(0xFF3A4B5C),
//                     ),
//                   ),
//                   const SizedBox(height: 12),
//                   SizedBox(
//                     width: double.infinity,
//                     child: ElevatedButton(
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: AppColors.primary,
//                         foregroundColor: Colors.white,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                       ),
//                       onPressed: () {
//                         final locationAddress = _address.isNotEmpty
//                             ? _address
//                             : '$latText, $lngText';
//                         Navigator.pop(
//                           context,
//                           _PickedLocation(
//                             latitude: _pickedPoint.latitude,
//                             longitude: _pickedPoint.longitude,
//                             address: locationAddress,
//                             placeName: _placeName,
//                           ),
//                         );
//                       },
//                       child: const Text(
//                         'Use This Location',
//                         style: TextStyle(fontWeight: FontWeight.w700),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
