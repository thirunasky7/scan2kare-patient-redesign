import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../utils/token_storage.dart';
import '../utils/auth_nav.dart';
import '../utils/local_storage.dart';
import '../utils/app_date_format.dart';
import '../services/deep_link_service.dart';
import '../services/auth_service.dart';
import '../config/api_config.dart';

/// ================= PROFILE SCREEN =================
class ProfileUpdateScreen extends StatefulWidget {
  /// When true (first login after OTP), name/gender/dob/address are required
  /// and user continues to Home / pending deep link after save.
  final bool isFirstLoginSetup;

  const ProfileUpdateScreen({
    super.key,
    this.isFirstLoginSetup = false,
  });

  @override
  State<ProfileUpdateScreen> createState() => _ProfileUpdateScreenState();
}

class _ProfileUpdateScreenState extends State<ProfileUpdateScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final dobController = TextEditingController();
  final addressController = TextEditingController();

  String? gender;
  File? _profileImage;
  String profileImageUrl = "";

  bool _isLoading = true;
  bool _isUpdating = false;
  bool _isDeleting = false;

  final ImagePicker _picker = ImagePicker();

  final String profileUrl = "${ApiConfig.baseUrl}/patient/profile";
  final String updateUrl = "${ApiConfig.baseUrl}/update-profile";

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    dobController.dispose();
    addressController.dispose();
    super.dispose();
  }

  /// ================= FETCH PROFILE =================
  Future<void> fetchProfile() async {
    try {
      String? token = await TokenStorage.getToken();
      if (token == null || token.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final response = await http.get(
        Uri.parse(profileUrl),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (_isApiSuccess(jsonData) && jsonData['data'] != null) {
          final user = jsonData['data'];

          if (!mounted) return;
          setState(() {
            nameController.text = user['name']?.toString() ?? '';
            emailController.text = user['email']?.toString() ?? '';
            phoneController.text = user['phone']?.toString() ?? '';
            gender = _normalizeGender(user['gender']?.toString());
            dobController.text =
                AppDateFormat.toDisplay(user['dob']?.toString());
            addressController.text = user['address']?.toString() ?? '';
            profileImageUrl = user['profile_image']?.toString() ?? '';
            _isLoading = false;
          });

          if (user is Map) {
            await LocalStorage.saveUser(Map<String, dynamic>.from(user));
          }
          return;
        }
      }
    } catch (e) {
      //debugPrint("fetchProfile error: $e");
    }

    // Fallback: seed from locally saved OTP user data.
    final local = await LocalStorage.getUser();
    if (!mounted) return;
    if (local != null) {
      setState(() {
        nameController.text = local['name']?.toString() ?? '';
        emailController.text = local['email']?.toString() ?? '';
        phoneController.text = local['phone']?.toString() ?? '';
        addressController.text = local['address']?.toString() ?? '';
        gender = _normalizeGender(local['gender']?.toString());
        dobController.text = AppDateFormat.toDisplay(local['dob']?.toString());
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAccount() async {
    if (_isDeleting) return;
    setState(() => _isDeleting = true);

    try {
      final result = await AuthService.deleteAccount();
      if (!mounted) return;

      if (result['success'] == true) {
        LocalStorage.displayNameNotifier.value = 'Guest';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message']?.toString() ?? "Account deleted successfully",
            ),
            backgroundColor: Colors.green,
          ),
        );
        goToLogin();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message']?.toString() ?? "Delete failed",
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Something went wrong. Please try again."),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  void _confirmDelete() {
    if (_isDeleting) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text(
            "Are you sure you want to delete your account? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteAccount();
            },
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  String? _normalizeGender(String? g) {
    final value = (g ?? '').toString().trim().toLowerCase();
    if (value == 'female') return 'Female';
    if (value == 'other') return 'Other';
    if (value == 'male') return 'Male';
    return null;
  }

  bool _isApiSuccess(dynamic jsonData) {
    if (jsonData is! Map) return true;
    final status = jsonData['status'];
    if (status == null) return true;
    return status == true ||
        status == 1 ||
        status == '1' ||
        status == 'true' ||
        status == 'success';
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
      });
    }
  }

  Future<void> _selectDate() async {
    final existing = AppDateFormat.tryParse(dobController.text);
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: existing ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        dobController.text = AppDateFormat.formatDisplay(picked);
      });
    }
  }

  String? _validateName(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return "Enter your name";
    if (value.length < 2) return "Name must be at least 2 characters";
    if (!RegExp(r"^[a-zA-Z\s.'.-]+$").hasMatch(value)) {
      return "Enter a valid name";
    }
    return null;
  }

  String? _validateGender(String? v) {
    if (v == null || v.trim().isEmpty) return "Select gender";
    return null;
  }

  String? _validateDob(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return "Select date of birth";
    if (AppDateFormat.tryParse(value) == null) {
      return "Enter a valid date (DD-MM-YYYY)";
    }
    return null;
  }

  String? _validateAddress(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return "Enter your address";
    if (value.length < 3) return "Address must be at least 3 characters";
    return null;
  }

  String? _validateEmail(String? v) {
    final value = (v ?? '').trim();
    if (widget.isFirstLoginSetup && value.isEmpty) return null;
    if (value.isEmpty) return "Enter your email";
    final emailOk = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
    if (!emailOk) return "Enter a valid email";
    return null;
  }

  String? _validatePhone(String? v) {
    final value = (v ?? '').trim();
    if (widget.isFirstLoginSetup && value.isEmpty) return null;
    if (value.isEmpty) return "Enter your phone number";
    if (value.length < 10) return "Enter a valid 10-digit phone number";
    return null;
  }

  /// ================= UPDATE PROFILE =================
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isUpdating) return;

    setState(() => _isUpdating = true);

    try {
      String? token = await TokenStorage.getToken();
      if (token == null || token.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Session expired. Please login again."),
              backgroundColor: Colors.red,
            ),
          );
          goToLogin();
        }
        return;
      }

      final dobApi = AppDateFormat.toApi(dobController.text.trim());
      if (dobApi.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Please select a valid date of birth (DD-MM-YYYY)"),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      final age = AppDateFormat.ageFromDob(dobController.text.trim());

      var request = http.MultipartRequest('POST', Uri.parse(updateUrl));

      request.headers['Authorization'] = "Bearer $token";
      request.headers['Accept'] = "application/json";

      request.fields['name'] = nameController.text.trim();
      request.fields['address'] = addressController.text.trim();
      request.fields['dob'] = dobApi;
      request.fields['gender'] = (gender ?? '').toLowerCase();
      if (age != null) {
        request.fields['age'] = age.toString();
      }

      final email = emailController.text.trim();
      final phone = phoneController.text.trim();
      if (email.isNotEmpty) request.fields['email'] = email;
      if (phone.isNotEmpty) request.fields['phone'] = phone;

      if (_profileImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'profile_image',
            _profileImage!.path,
          ),
        );
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      Map<String, dynamic>? jsonData;
      try {
        final decoded = json.decode(responseBody);
        if (decoded is Map<String, dynamic>) {
          jsonData = decoded;
        } else if (decoded is Map) {
          jsonData = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        jsonData = null;
      }

      final ok = (response.statusCode == 200 || response.statusCode == 201) &&
          _isApiSuccess(jsonData);

      if (ok) {
        _profileImage = null;

        final name = nameController.text.trim();
        final address = addressController.text.trim();

        final existing = await LocalStorage.getUser() ?? <String, dynamic>{};
        existing['name'] = name;
        existing['address'] = address;
        existing['age'] = age?.toString() ?? '';
        existing['dob'] = dobApi;
        existing['email'] = email;
        existing['phone'] = phone;
        existing['gender'] = (gender ?? '').toLowerCase();
        existing['profile_completed'] = true;
        existing['is_new_user'] = false;
        if (jsonData != null && jsonData['data'] is Map) {
          final serverUser = Map<String, dynamic>.from(jsonData['data'] as Map);
          existing.addAll(serverUser);
          existing['name'] = name.isNotEmpty ? name : existing['name'];
          existing['address'] =
              address.isNotEmpty ? address : existing['address'];
          existing['age'] = age != null ? age.toString() : existing['age'];
          existing['dob'] = dobApi;
          if (email.isNotEmpty) existing['email'] = email;
          if (phone.isNotEmpty) existing['phone'] = phone;
          existing['gender'] = (gender ?? '').toLowerCase();
        }
        await LocalStorage.saveUser(existing);

        await fetchProfile();

        if (!mounted) return;

        if (name.isNotEmpty) nameController.text = name;
        if (address.isNotEmpty) addressController.text = address;
        dobController.text = AppDateFormat.toDisplay(dobApi);
        if (email.isNotEmpty) emailController.text = email;
        if (phone.isNotEmpty) phoneController.text = phone;
        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isFirstLoginSetup
                ? "Profile saved successfully"
                : "Profile updated successfully"),
            backgroundColor: Colors.green,
          ),
        );

        if (widget.isFirstLoginSetup) {
          await DeepLinkService.navigateAfterProfileSetup();
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_profileUpdateErrorMessage(jsonData)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint("update profile error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Something went wrong. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  String _profileUpdateErrorMessage(Map<String, dynamic>? jsonData) {
    if (jsonData == null) return "Update failed";
    final message = (jsonData['message'] ?? '').toString().trim();
    if (message.isNotEmpty) return message;

    final errors = jsonData['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) {
        return first.first.toString();
      }
      return first.toString();
    }
    return "Update failed";
  }

  /// ================= UI =================
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isFirstLoginSetup,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: !widget.isFirstLoginSetup,
          title: Text(
            widget.isFirstLoginSetup ? "Complete Profile" : "Edit Profile",
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/gradient.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: _formKey,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.isFirstLoginSetup) ...[
                                const Text(
                                  "Please add your basic details to continue.",
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],

                              if (!widget.isFirstLoginSetup) ...[
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 55,
                                      backgroundImage: _profileImage != null
                                          ? FileImage(_profileImage!)
                                          : profileImageUrl.isNotEmpty
                                              ? NetworkImage(profileImageUrl)
                                              : const AssetImage(
                                                      'assets/doc1.png')
                                                  as ImageProvider,
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: IconButton(
                                        icon: const Icon(Icons.camera_alt),
                                        onPressed: _pickImage,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 25),
                              ],

                              _inputField(
                                hint: "Enter your name",
                                controller: nameController,
                                icon: Icons.person,
                                validator: _validateName,
                                textInputAction: TextInputAction.next,
                              ),
                              DropdownButtonFormField<String>(
                                value: ["Male", "Female", "Other"]
                                        .contains(gender)
                                    ? gender
                                    : null,
                                items: const [
                                  DropdownMenuItem(
                                      value: "Male", child: Text("Male")),
                                  DropdownMenuItem(
                                      value: "Female", child: Text("Female")),
                                  DropdownMenuItem(
                                      value: "Other", child: Text("Other")),
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => gender = v);
                                  }
                                },
                                validator: _validateGender,
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                decoration: _decoration(
                                  Icons.wc,
                                  hint: "Select gender",
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: dobController,
                                readOnly: true,
                                onTap: _selectDate,
                                validator: _validateDob,
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                decoration: _decoration(
                                  Icons.calendar_today,
                                  hint: "Date of birth (DD-MM-YYYY)",
                                ),
                              ),
                              const SizedBox(height: 12),
                              _inputField(
                                hint: "Enter your address",
                                controller: addressController,
                                icon: Icons.location_on_outlined,
                                validator: _validateAddress,
                                maxLines: 2,
                                textInputAction: TextInputAction.next,
                              ),

                              if (!widget.isFirstLoginSetup) ...[
                                _inputField(
                                  hint: "Enter your email",
                                  controller: emailController,
                                  icon: Icons.email,
                                  validator: _validateEmail,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                ),
                                _inputField(
                                  hint: "Enter your phone number",
                                  controller: phoneController,
                                  icon: Icons.phone,
                                  validator: _validatePhone,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(10),
                                  ],
                                ),
                              ],

                              const SizedBox(height: 25),

                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed:
                                      _isUpdating ? null : _updateProfile,
                                  style: ButtonStyle(
                                    backgroundColor:
                                        WidgetStateProperty.resolveWith<Color>(
                                      (Set<WidgetState> states) {
                                        return const Color(0xFF2B6F71);
                                      },
                                    ),
                                    foregroundColor:
                                        WidgetStateProperty.all<Color>(
                                            Colors.white),
                                    textStyle:
                                        WidgetStateProperty.all<TextStyle>(
                                      const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  child: _isUpdating
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          widget.isFirstLoginSetup
                                              ? "Continue"
                                              : "Update Profile",
                                        ),
                                ),
                              ),

                              if (!widget.isFirstLoginSetup) ...[
                                const SizedBox(height: 15),
                                Center(
                                  child: GestureDetector(
                                    onTap: _isDeleting ? null : _confirmDelete,
                                    child: _isDeleting
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.red,
                                            ),
                                          )
                                        : const Text(
                                            "Delete Account",
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _inputField({
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    void Function(String)? onChanged,
    TextInputAction? textInputAction,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        textInputAction: textInputAction,
        maxLines: maxLines,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: _decoration(icon, hint: hint),
      ),
    );
  }

  InputDecoration _decoration(IconData icon, {String? hint}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2B6F71)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }
}
