// import 'package:flutter/material.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:sign_in_with_apple/sign_in_with_apple.dart';
// import '../../core/app_colors.dart';
// import '../../models/user.dart';
// import '../../services/api_service.dart';
// import '../../features/doctor/doctor/dashboard_screen.dart';
// import '../nurse/nurse_dashboard.dart';
// import 'signup_screen.dart';

// class LoginScreen extends StatefulWidget {
//   const LoginScreen({super.key});

//   @override
//   State<LoginScreen> createState() => _LoginScreenState();
// }

// class _LoginScreenState extends State<LoginScreen> {
//   static const String _googleClientIdFromDefine = String.fromEnvironment(
//     'GOOGLE_CLIENT_ID',
//     defaultValue: '',
//   );
//   static const String _googleServerClientIdFromDefine = String.fromEnvironment(
//     'GOOGLE_SERVER_CLIENT_ID',
//     defaultValue: '',
//   );
//   static const String _facebookAppIdFromDefine = String.fromEnvironment(
//     'FACEBOOK_APP_ID',
//     defaultValue: '',
//   );
//   static const String _appleClientIdFromDefine = String.fromEnvironment(
//     'APPLE_CLIENT_ID',
//     defaultValue: '',
//   );
//   static const String _appleRedirectUrlFromDefine = String.fromEnvironment(
//     'APPLE_REDIRECT_URL',
//     defaultValue: '',
//   );

//   String _googleClientId = _googleClientIdFromDefine;
//   String _googleServerClientId = _googleServerClientIdFromDefine;
//   String _facebookAppId = _facebookAppIdFromDefine;
//   String _appleClientId = _appleClientIdFromDefine;
//   String _appleRedirectUrl = _appleRedirectUrlFromDefine;

//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController passwordController = TextEditingController();

//   bool isLoading = false;
//   bool isSocialLoading = false;
//   bool _googleInitialized = false;
//   bool _facebookInitialized = false;
//   bool obscurePassword = true;

//   @override
//   void initState() {
//     super.initState();
//     _initializeSocialProviders();
//   }

//   @override
//   void dispose() {
//     emailController.dispose();
//     passwordController.dispose();
//     super.dispose();
//   }

//   bool _isValidEmail(String email) {
//     final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
//     return emailRegex.hasMatch(email);
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

//   Future<void> _initializeSocialProviders() async {
//     await _loadSocialAuthConfigFromBackend();
//     await _initializeGoogleSignIn();
//     await _initializeFacebookSignIn();
//   }

//   Future<void> _loadSocialAuthConfigFromBackend() async {
//     try {
//       final config = await ApiService().getSocialAuthConfig();
//       _googleClientId = (config['googleClientId'] ?? _googleClientId).toString();
//       _googleServerClientId =
//           (config['googleServerClientId'] ?? _googleServerClientId).toString();
//       _facebookAppId = (config['facebookAppId'] ?? _facebookAppId).toString();
//       _appleClientId = (config['appleClientId'] ?? _appleClientId).toString();
//       _appleRedirectUrl =
//           (config['appleRedirectUrl'] ?? _appleRedirectUrl).toString();
//     } catch (_) {
//       // Keep dart-define values if backend config is unavailable.
//     }
//   }

//   Future<void> _initializeGoogleSignIn() async {
//     if (_googleInitialized) return;

//     try {
//       await GoogleSignIn.instance.initialize(
//         clientId: _googleClientId.trim().isEmpty ? null : _googleClientId.trim(),
//         serverClientId: _googleServerClientId.trim().isEmpty
//             ? null
//             : _googleServerClientId.trim(),
//       );
//       _googleInitialized = true;
//     } catch (_) {
//       _googleInitialized = false;
//     }
//   }

//   Future<void> _initializeFacebookSignIn() async {
//     if (!kIsWeb || _facebookInitialized) return;
//     if (_facebookAppId.trim().isEmpty) return;

//     try {
//       await FacebookAuth.instance.webAndDesktopInitialize(
//         appId: _facebookAppId.trim(),
//         cookie: true,
//         xfbml: true,
//         version: 'v20.0',
//       );
//       _facebookInitialized = true;
//     } catch (_) {
//       _facebookInitialized = false;
//     }
//   }

//   String _friendlyError(Object error, {String fallback = 'Login failed.'}) {
//     final value = error.toString().replaceFirst('Exception: ', '');
//     if (value.trim().isEmpty) return fallback;
//     return value;
//   }

//   Future<void> _handleAuthSuccess(
//     Map<String, dynamic> response, {
//     String successMessage = 'Login successful',
//   }) async {
//     if (!mounted) return;

//     final user = response['user'] as Map<String, dynamic>?;
//     if (user == null) {
//       _showMessage('Invalid server response: user data not found');
//       return;
//     }

//     final role = (user['role'] ?? user['userRole'] ?? '').toString().toLowerCase();
//     final userId = (user['userId'] ?? user['id'] ?? '').toString();
//     final userName = (user['fullName'] ?? user['name'] ?? 'User').toString();
//     final userMap = Map<String, dynamic>.from(user);

//     if (userMap['id'] == null && userMap['userId'] != null) {
//       userMap['id'] = userMap['userId'];
//     }
//     if (userMap['fullName'] == null && userMap['name'] != null) {
//       userMap['fullName'] = userMap['name'];
//     }
//     if (userMap['role'] == null && userMap['userRole'] != null) {
//       userMap['role'] = userMap['userRole'];
//     }

//     final currentUser = User.fromJson(userMap);
//     _showMessage(successMessage, color: Colors.green);

//     switch (role) {
//       case 'patient':
//         Navigator.pushReplacementNamed(
//           context,
//           '/patient-home',
//           arguments: {
//             'userId': userId,
//             'displayName': userName,
//           },
//         );
//         break;
//       case 'nurse':
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(
//             builder: (_) => NurseDashboard(user: currentUser),
//           ),
//         );
//         break;
//       case 'doctor':
//         final prefs = await SharedPreferences.getInstance();
//         final token = response['token']?.toString();
//         if (token != null && token.isNotEmpty) {
//           await prefs.setString('doctor_token', token);
//         }
//         await prefs.setString('doctor_userId', userId);
//         await prefs.setString('doctor_fullName', userName);
//         await prefs.setString('doctor_email', (userMap['email'] ?? '').toString());
//         await prefs.setString('doctor_role', role);

//         if (!mounted) return;
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(
//             builder: (_) => const DoctorDashboardScreen(),
//           ),
//         );
//         break;
//       case 'admin':
//         _showMessage('Admin dashboard is not connected yet');
//         break;
//       default:
//         _showMessage('Unknown user role: $role');
//     }
//   }

//   Widget _field(
//     String hint,
//     IconData icon,
//     TextEditingController controller, {
//     bool obscure = false,
//     TextInputType keyboardType = TextInputType.text,
//     Widget? suffixIcon,
//   }) {
//     return Container(
//       height: 60,
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(18),
//         border: Border.all(
//           color: const Color(0xFFDDE4EC),
//         ),
//         boxShadow: const [
//           BoxShadow(
//             color: Color(0x0D0E1726),
//             blurRadius: 10,
//             offset: Offset(0, 4),
//           ),
//         ],
//       ),
//       child: TextField(
//         controller: controller,
//         obscureText: obscure,
//         keyboardType: keyboardType,
//         autocorrect: false,
//         enableSuggestions: !obscure,
//         textInputAction: obscure ? TextInputAction.done : TextInputAction.next,
//         onSubmitted: (_) {
//           if (obscure && !isLoading) {
//             loginUser();
//           }
//         },
//         decoration: InputDecoration(
//           hintText: hint,
//           hintStyle: const TextStyle(
//             color: Color(0xFF9AA3AF),
//             fontSize: 15,
//             fontWeight: FontWeight.w500,
//           ),
//           prefixIcon: Icon(
//             icon,
//             color: AppColors.primary,
//             size: 23,
//           ),
//           suffixIcon: suffixIcon,
//           border: InputBorder.none,
//           contentPadding: const EdgeInsets.symmetric(
//             horizontal: 18,
//             vertical: 19,
//           ),
//         ),
//         style: const TextStyle(
//           fontSize: 15,
//           fontWeight: FontWeight.w600,
//           color: AppColors.textDark,
//         ),
//       ),
//     );
//   }

//   Future<void> loginUser() async {
//     final email = emailController.text.trim();
//     final password = passwordController.text.trim();

//     if (email.isEmpty || password.isEmpty) {
//       _showMessage('Please enter email and password');
//       return;
//     }

//     if (!_isValidEmail(email)) {
//       _showMessage('Please enter a valid email address');
//       return;
//     }

//     FocusScope.of(context).unfocus();

//     setState(() {
//       isLoading = true;
//     });

//     try {
//       final response = await ApiService().login(email, password);
//       await _handleAuthSuccess(response);
//     } catch (e) {
//       final errorString = e.toString().toLowerCase();
//       String errorMsg = 'Login failed. Please try again.';

//       if (errorString.contains('invalid credentials') ||
//           errorString.contains('unauthorized') ||
//           errorString.contains('401')) {
//         errorMsg = 'Invalid email or password.';
//       } else if (errorString.contains('network request failed') ||
//           errorString.contains('failed to fetch') ||
//           errorString.contains('connection refused') ||
//           errorString.contains('failed host lookup') ||
//           errorString.contains('network error')) {
//         errorMsg =
//             'Cannot connect to backend at ${ApiService.baseUrl}. Make sure the backend is running and the base URL is correct.';
//       } else if (errorString.contains('timeout')) {
//         errorMsg =
//             'The request timed out. Check if the backend server is running.';
//       } else if (errorString.contains('cors')) {
//         errorMsg =
//             'CORS error. If you are running on Chrome, enable CORS in your backend.';
//       } else {
//         errorMsg = e.toString().replaceFirst('Exception: ', '');
//       }

//       _showMessage(errorMsg, color: Colors.red);
//     } finally {
//       if (mounted) {
//         setState(() {
//           isLoading = false;
//         });
//       }
//     }
//   }

//   Future<void> _showForgotPasswordDialog() async {
//     final TextEditingController forgotEmailController =
//         TextEditingController();

//     await showDialog(
//       context: context,
//       builder: (context) {
//         bool isSending = false;

//         return StatefulBuilder(
//           builder: (context, setDialogState) {
//             return AlertDialog(
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               title: const Text(
//                 'Forgot Password',
//                 style: TextStyle(
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               content: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   const Text(
//                     'Enter your email address and we will send you password reset instructions.',
//                     style: TextStyle(
//                       fontSize: 14,
//                       color: Colors.black87,
//                     ),
//                   ),
//                   const SizedBox(height: 18),
//                   TextField(
//                     controller: forgotEmailController,
//                     keyboardType: TextInputType.emailAddress,
//                     decoration: InputDecoration(
//                       hintText: 'Email Address',
//                       prefixIcon: const Icon(
//                         Icons.email_outlined,
//                         color: AppColors.primary,
//                       ),
//                       filled: true,
//                       fillColor: const Color(0xFFF7F9FC),
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(14),
//                         borderSide: BorderSide(
//                           color: Colors.grey.withValues(alpha: 0.2),
//                         ),
//                       ),
//                       enabledBorder: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(14),
//                         borderSide: BorderSide(
//                           color: Colors.grey.withValues(alpha: 0.2),
//                         ),
//                       ),
//                       focusedBorder: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(14),
//                         borderSide: const BorderSide(
//                           color: AppColors.primary,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//               actions: [
//                 TextButton(
//                   onPressed: isSending
//                       ? null
//                       : () {
//                           Navigator.pop(context);
//                         },
//                   child: const Text(
//                     'Cancel',
//                     style: TextStyle(color: Colors.grey),
//                   ),
//                 ),
//                 ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: AppColors.primary,
//                     foregroundColor: Colors.white,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                   ),
//                   onPressed: isSending
//                       ? null
//                       : () async {
//                           final email = forgotEmailController.text.trim();

//                           if (email.isEmpty) {
//                             _showMessage('Please enter your email');
//                             return;
//                           }

//                           if (!_isValidEmail(email)) {
//                             _showMessage('Please enter a valid email address');
//                             return;
//                           }

//                           setDialogState(() {
//                             isSending = true;
//                           });

//                           try {
//                             final response =
//                                 await ApiService().forgotPassword(email);
//                             if (!context.mounted) return;
//                             Navigator.pop(context);
//                             _showMessage(
//                               response['message']?.toString() ??
//                                   'If this email exists, reset instructions have been sent.',
//                               color: Colors.green,
//                             );
//                           } catch (e) {
//                             if (!context.mounted) return;
//                             Navigator.pop(context);
//                             _showMessage(
//                               e.toString().replaceFirst('Exception: ', ''),
//                               color: Colors.red,
//                             );
//                           }
//                         },
//                   child: isSending
//                       ? const SizedBox(
//                           width: 18,
//                           height: 18,
//                           child: CircularProgressIndicator(
//                             color: Colors.white,
//                             strokeWidth: 2.2,
//                           ),
//                         )
//                       : const Text('Send'),
//                 ),
//               ],
//             );
//           },
//         );
//       },
//     );

//     forgotEmailController.dispose();
//   }

//   Future<void> _handleSocialSignIn(String provider) async {
//     if (isSocialLoading || isLoading) return;

//     switch (provider.toLowerCase()) {
//       case 'google':
//         await _signInWithGoogle();
//         break;
//       case 'facebook':
//         await _signInWithFacebook();
//         break;
//       case 'apple':
//         await _signInWithApple();
//         break;
//       default:
//         _showMessage('Unsupported provider: $provider');
//     }
//   }

//   Future<void> _signInWithGoogle() async {
//     setState(() => isSocialLoading = true);

//     try {
//       await _initializeGoogleSignIn();
//       if (!_googleInitialized) {
//         throw Exception(
//           'Google sign-in is not configured. Add GOOGLE_CLIENT_ID in backend/.env then restart backend.',
//         );
//       }

//       final account = await GoogleSignIn.instance.authenticate();
//       final idToken = account.authentication.idToken;
//       if (idToken == null || idToken.isEmpty) {
//         throw Exception('Google did not return an idToken.');
//       }

//       final response = await ApiService().socialLoginWithGoogle(idToken: idToken);
//       await _handleAuthSuccess(response, successMessage: 'Google login successful');
//     } on GoogleSignInException catch (e) {
//       if (e.code == GoogleSignInExceptionCode.canceled ||
//           e.code == GoogleSignInExceptionCode.interrupted) {
//         _showMessage('Google sign-in was cancelled');
//       } else {
//         _showMessage(
//           _friendlyError(e, fallback: 'Google sign-in failed'),
//           color: Colors.red,
//         );
//       }
//     } catch (e) {
//       _showMessage(
//         _friendlyError(e, fallback: 'Google sign-in failed'),
//         color: Colors.red,
//       );
//     } finally {
//       if (mounted) {
//         setState(() => isSocialLoading = false);
//       }
//     }
//   }

//   Future<void> _signInWithFacebook() async {
//     setState(() => isSocialLoading = true);

//     try {
//       await _initializeFacebookSignIn();
//       if (kIsWeb && _facebookAppId.trim().isEmpty) {
//         throw Exception(
//           'Facebook sign-in needs FACEBOOK_APP_ID in backend/.env.',
//         );
//       }

//       final result = await FacebookAuth.instance.login(
//         permissions: const ['email', 'public_profile'],
//       );

//       switch (result.status) {
//         case LoginStatus.success:
//           final token = result.accessToken?.tokenString;
//           if (token == null || token.isEmpty) {
//             throw Exception('Facebook did not return an access token.');
//           }
//           final response =
//               await ApiService().socialLoginWithFacebook(accessToken: token);
//           await _handleAuthSuccess(
//             response,
//             successMessage: 'Facebook login successful',
//           );
//           break;
//         case LoginStatus.cancelled:
//           _showMessage('Facebook sign-in was cancelled');
//           break;
//         case LoginStatus.operationInProgress:
//           _showMessage('Facebook sign-in already in progress');
//           break;
//         case LoginStatus.failed:
//           throw Exception(result.message ?? 'Facebook sign-in failed');
//       }
//     } catch (e) {
//       _showMessage(
//         _friendlyError(e, fallback: 'Facebook sign-in failed'),
//         color: Colors.red,
//       );
//     } finally {
//       if (mounted) {
//         setState(() => isSocialLoading = false);
//       }
//     }
//   }

//   Future<void> _signInWithApple() async {
//     setState(() => isSocialLoading = true);

//     try {
//       final available = await SignInWithApple.isAvailable();
//       if (!available) {
//         throw Exception('Apple sign-in is not available on this device.');
//       }

//       final bool requiresWebOptions = kIsWeb;
//       if (requiresWebOptions &&
//           (_appleClientId.trim().isEmpty || _appleRedirectUrl.trim().isEmpty)) {
//         throw Exception(
//           'Apple sign-in on web needs APPLE_CLIENT_ID and APPLE_REDIRECT_URL in backend/.env.',
//         );
//       }

//       final credential = await SignInWithApple.getAppleIDCredential(
//         scopes: const [
//           AppleIDAuthorizationScopes.email,
//           AppleIDAuthorizationScopes.fullName,
//         ],
//         webAuthenticationOptions: requiresWebOptions
//             ? WebAuthenticationOptions(
//                 clientId: _appleClientId.trim(),
//                 // backend/.env value, same as Service ID on Apple developer console
//                 redirectUri: Uri.parse(_appleRedirectUrl.trim()),
//               )
//             : null,
//       );

//       final identityToken = credential.identityToken;
//       if (identityToken == null || identityToken.isEmpty) {
//         throw Exception('Apple did not return an identity token.');
//       }

//       final response = await ApiService().socialLoginWithApple(
//         identityToken: identityToken,
//         email: credential.email,
//         fullName: {
//           'givenName': credential.givenName,
//           'familyName': credential.familyName,
//         },
//       );
//       await _handleAuthSuccess(response, successMessage: 'Apple login successful');
//     } catch (e) {
//       _showMessage(
//         _friendlyError(e, fallback: 'Apple sign-in failed'),
//         color: Colors.red,
//       );
//     } finally {
//       if (mounted) {
//         setState(() => isSocialLoading = false);
//       }
//     }
//   }

//   Widget _socialButton({
//     required Widget iconWidget,
//     required String label,
//     required VoidCallback? onTap,
//   }) {
//     return InkWell(
//       onTap: isSocialLoading ? null : onTap,
//       borderRadius: BorderRadius.circular(16),
//       child: Container(
//         width: 96,
//         height: 74,
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(16),
//           border: Border.all(
//             color: const Color(0xFFDFE5EC),
//           ),
//           boxShadow: const [
//             BoxShadow(
//               color: Color(0x0D0E1726),
//               blurRadius: 12,
//               offset: Offset(0, 5),
//             ),
//           ],
//         ),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             iconWidget,
//             const SizedBox(height: 6),
//             Text(
//               label,
//               style: const TextStyle(
//                 fontSize: 14,
//                 color: AppColors.textDark,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _socialIconGoogle() {
//     return const Text(
//       'G',
//       style: TextStyle(
//         fontSize: 28,
//         fontWeight: FontWeight.w700,
//         color: Color(0xFFDB4437),
//       ),
//     );
//   }

//   Widget _socialIconFacebook() {
//     return const Icon(
//       Icons.facebook_rounded,
//       color: Color(0xFF1877F2),
//       size: 30,
//     );
//   }

//   Widget _socialIconApple() {
//     return const Icon(
//       Icons.apple,
//       color: Colors.black,
//       size: 29,
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
//               padding: const EdgeInsets.only(
//                 top: 34,
//                 bottom: 34,
//                 left: 24,
//                 right: 24,
//               ),
//               decoration: const BoxDecoration(
//                 gradient: LinearGradient(
//                   begin: Alignment.topCenter,
//                   end: Alignment.bottomCenter,
//                   colors: [
//                     Color(0xFF0E7E77),
//                     AppColors.primary,
//                   ],
//                 ),
//               ),
//               child: Column(
//                 children: [
//                   Container(
//                     width: 94,
//                     height: 94,
//                     decoration: BoxDecoration(
//                       color: Colors.white.withValues(alpha: 0.14),
//                       shape: BoxShape.circle,
//                       border: Border.all(
//                         color: Colors.white.withValues(alpha: 0.18),
//                       ),
//                     ),
//                     child: const Icon(
//                       Icons.favorite,
//                       color: Colors.white,
//                       size: 42,
//                     ),
//                   ),
//                   const SizedBox(height: 20),
//                   const Text(
//                     "Welcome Back",
//                     style: TextStyle(
//                       fontSize: 50 / 1.55,
//                       fontWeight: FontWeight.w800,
//                       color: Colors.white,
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   Text(
//                     "Sign in to your CareLink account",
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       color: Colors.white.withValues(alpha: 0.88),
//                       fontSize: 14.8,
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
//                     topLeft: Radius.circular(34),
//                     topRight: Radius.circular(34),
//                   ),
//                 ),
//                 child: SingleChildScrollView(
//                   padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       const Text(
//                         "Login to your account",
//                         style: TextStyle(
//                           fontSize: 39 / 2,
//                           fontWeight: FontWeight.w800,
//                           color: AppColors.textDark,
//                         ),
//                       ),
//                       const SizedBox(height: 6),
//                       const Text(
//                         "Use your email and password to continue",
//                         style: TextStyle(
//                           color: Color(0xFF97A1AE),
//                           fontSize: 13.5,
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                       const SizedBox(height: 20),
//                       _field(
//                         "Email Address",
//                         Icons.email_outlined,
//                         emailController,
//                         keyboardType: TextInputType.emailAddress,
//                       ),
//                       const SizedBox(height: 14),
//                       _field(
//                         "Password",
//                         Icons.lock_outline,
//                         passwordController,
//                         obscure: obscurePassword,
//                         suffixIcon: IconButton(
//                           onPressed: () {
//                             setState(() {
//                               obscurePassword = !obscurePassword;
//                             });
//                           },
//                           icon: Icon(
//                             obscurePassword
//                                 ? Icons.visibility_off_outlined
//                                 : Icons.visibility_outlined,
//                             color: Colors.grey,
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 6),
//                       Align(
//                         alignment: Alignment.centerRight,
//                         child: TextButton(
//                           onPressed: _showForgotPasswordDialog,
//                           child: const Text(
//                             "Forgot Password?",
//                             style: TextStyle(
//                               color: AppColors.primary,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 12),
//                       SizedBox(
//                         width: double.infinity,
//                         height: 58,
//                         child: ElevatedButton(
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: AppColors.primary,
//                             foregroundColor: Colors.white,
//                             disabledBackgroundColor:
//                                 AppColors.primary.withValues(alpha: 0.6),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(18),
//                             ),
//                             elevation: 1.5,
//                           ),
//                           onPressed: isLoading ? null : loginUser,
//                           child: isLoading
//                               ? const SizedBox(
//                                   width: 24,
//                                   height: 24,
//                                   child: CircularProgressIndicator(
//                                     color: Colors.white,
//                                     strokeWidth: 2.5,
//                                   ),
//                                 )
//                               : const Text(
//                                   "Sign In",
//                                   style: TextStyle(
//                                     fontSize: 18,
//                                     fontWeight: FontWeight.w700,
//                                     color: Colors.white,
//                                   ),
//                                 ),
//                         ),
//                       ),
//                       const SizedBox(height: 26),
//                       const Row(
//                         children: [
//                           Expanded(child: Divider(color: Color(0xFFE4E8EE))),
//                           Padding(
//                             padding: EdgeInsets.symmetric(horizontal: 10),
//                             child: Text(
//                               "Or continue with",
//                               style: TextStyle(
//                                 color: Color(0xFF9AA3AF),
//                                 fontSize: 13.5,
//                                 fontWeight: FontWeight.w500,
//                               ),
//                             ),
//                           ),
//                           Expanded(child: Divider(color: Color(0xFFE4E8EE))),
//                         ],
//                       ),
//                       const SizedBox(height: 18),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           _socialButton(
//                             iconWidget: _socialIconFacebook(),
//                             label: 'Facebook',
//                             onTap: () => _handleSocialSignIn('Facebook'),
//                           ),
//                           _socialButton(
//                             iconWidget: _socialIconGoogle(),
//                             label: 'Google',
//                             onTap: () => _handleSocialSignIn('Google'),
//                           ),
//                           _socialButton(
//                             iconWidget: _socialIconApple(),
//                             label: 'Apple',
//                             onTap: () => _handleSocialSignIn('Apple'),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 12),
//                       if (isSocialLoading)
//                         const Center(
//                           child: SizedBox(
//                             width: 18,
//                             height: 18,
//                             child: CircularProgressIndicator(strokeWidth: 2),
//                           ),
//                         )
//                       else
//                         const Center(
//                           child: Text(
//                             'Google, Facebook and Apple login',
//                             style: TextStyle(
//                               color: Color(0xFF9AA3AF),
//                               fontSize: 12,
//                               fontWeight: FontWeight.w500,
//                             ),
//                           ),
//                         ),
//                       const SizedBox(height: 28),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           const Text(
//                             "Don't have an account? ",
//                             style: TextStyle(
//                               color: Colors.grey,
//                               fontSize: 14,
//                             ),
//                           ),
//                           GestureDetector(
//                             onTap: () {
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => const SignupScreen(),
//                                 ),
//                               );
//                             },
//                             child: const Text(
//                               "Create Account",
//                               style: TextStyle(
//                                 color: AppColors.primary,
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 14,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
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
