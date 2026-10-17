import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/token_storage.dart';
import '../utils/local_storage.dart';
import '../utils/profile_completeness.dart';
import '../utils/app_date_format.dart';
import '../config/api_config.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  String? selectedGender;
  String? selectedRelation;

  List<Map<String, dynamic>> patients = [];
  bool isLoading = false;
  bool isSaving = false;

  int? editingFamilyId;
  bool isEditMode = false;
  bool editingSelf = false;

  final List<String> genders = ["male", "female", "other"];
  /// Backend rejects "self" for new family members (self is the account holder).
  final List<String> relations = [
    "Father",
    "Mother",
    "Spouse",
    "Child",
  ];

  bool _isSelf(Map<String, dynamic> p) {
    return (p["relationship"] ?? "").toString().toLowerCase().trim() == "self";
  }

  int? _ageForPatient(Map<String, dynamic> p) {
    final fromDob = AppDateFormat.ageFromDob(p["dob"]?.toString());
    if (fromDob != null) return fromDob;
    return int.tryParse(p["age"]?.toString() ?? '');
  }

  void _clearForm() {
    nameController.clear();
    dobController.clear();
    phoneController.clear();
    selectedGender = null;
    selectedRelation = null;
    editingFamilyId = null;
    isEditMode = false;
    editingSelf = false;
    _formKey.currentState?.reset();
  }

  bool _validateForm() {
    return _formKey.currentState?.validate() ?? false;
  }

  String? _validateName(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return "Name is required";
    if (v.length < 2) return "Enter a valid name";
    return null;
  }

  String? _validateDob(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return "Date of birth is required";
    if (AppDateFormat.tryParse(v) == null) {
      return "Enter a valid date (DD-MM-YYYY)";
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    if (!RegExp(r'^[0-9]{10}$').hasMatch(v)) {
      return "Enter a valid 10-digit phone number";
    }
    return null;
  }

  String? _validateGender(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Gender is required";
    }
    return null;
  }

  String? _validateRelation(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Relationship is required";
    }
    return null;
  }

  Future<void> _selectDob() async {
    final existing = AppDateFormat.tryParse(dobController.text);
    final picked = await showDatePicker(
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

  void editPatient(int index) {
    final p = patients[index];
    final isSelf = _isSelf(p);

    nameController.text = p["name"] == "-" ? "" : (p["name"] ?? "");
    phoneController.text = p["phone"] == "-" ? "" : (p["phone"] ?? "");

    final dobRaw = (p["dob"] ?? "").toString();
    if (dobRaw.isNotEmpty && dobRaw != "-") {
      dobController.text = AppDateFormat.toDisplay(dobRaw);
    } else {
      final age = int.tryParse(p["age"]?.toString() ?? '');
      if (age != null && age > 0) {
        dobController.text =
            AppDateFormat.toDisplay(ProfileCompleteness.dobFromAge(age));
      } else {
        dobController.clear();
      }
    }

    final gender = (p["gender"] ?? "").toString().toLowerCase().trim();
    selectedGender = genders.contains(gender) ? gender : null;

    if (isSelf) {
      selectedRelation = "Self";
      editingSelf = true;
    } else {
      editingSelf = false;
      final relation = (p["relationship"] ?? "").toString().trim().toLowerCase();
      final matchedRelation = relations.firstWhere(
        (e) => e.toLowerCase() == relation,
        orElse: () => "",
      );
      selectedRelation = matchedRelation.isEmpty ? null : matchedRelation;
    }

    editingFamilyId = p["id"] is int
        ? p["id"] as int
        : int.tryParse(p["id"]?.toString() ?? "");
    isEditMode = true;
    setState(() {});
  }

  String _apiErrorMessage(dynamic data, String fallback) {
    if (data is! Map) return fallback;
    if (data['message'] != null) return data['message'].toString();
    final errors = data['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
      return first.toString();
    }
    return fallback;
  }

  Future<void> fetchPatients() async {
    setState(() => isLoading = true);

    try {
      final token = await TokenStorage.getToken();

      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/patient/family-profiles"),
        headers: {
          "Accept": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['data'] != null) {
        final List list = data['data'];

        setState(() {
          patients = list
              .map<Map<String, dynamic>>((e) {
                return {
                  "id": e["id"],
                  "name": e["name"] ?? "-",
                  "relationship": e["relationship"] ?? "-",
                  "gender": e["gender"] ?? "-",
                  "age": e["age"]?.toString() ?? "",
                  "dob": e["dob"]?.toString() ?? "",
                  "phone": e["phone"] ?? "",
                };
              })
              .where((p) => !_isSelf(p))
              .toList();
        });
      } else {
        setState(() => patients = []);
      }
    } catch (e) {
      debugPrint("API Error: $e");
      if (mounted) {
        setState(() => patients = []);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to load family profiles")),
        );
      }
    }

    if (mounted) setState(() => isLoading = false);
  }

  Future<void> createFamilyMember() async {
    if (!_validateForm()) return;

    if (selectedRelation!.toLowerCase() == 'self') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Cannot add Self here. Self is your main account profile."),
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final token = await TokenStorage.getToken();

      final body = <String, dynamic>{
        "name": nameController.text.trim(),
        "gender": selectedGender,
        "relationship": selectedRelation!.toLowerCase(),
        "phone": phoneController.text.trim().isEmpty
            ? null
            : phoneController.text.trim(),
      };

      final dobApi = AppDateFormat.toApi(dobController.text.trim());
      final age = AppDateFormat.ageFromDob(dobController.text.trim());
      if (dobApi.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select a valid date of birth")),
        );
        return;
      }
      body["dob"] = dobApi;
      if (age != null) body["age"] = age;

      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/patient/family-profiles"),
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Family member added successfully")),
        );
        _clearForm();
        setState(() {});
        await fetchPatients();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_apiErrorMessage(data, "Creation failed")),
          ),
        );
      }
    } catch (e) {
      debugPrint("Create Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Something went wrong")),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> updateFamilyMember() async {
    if (editingFamilyId == null) return;
    if (!_validateForm()) return;

    // Allow "self" only when updating the existing Self record.
    if (selectedRelation!.toLowerCase() == 'self' && !editingSelf) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot change relationship to Self")),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final token = await TokenStorage.getToken();

      final body = <String, dynamic>{
        "name": nameController.text.trim(),
        "gender": selectedGender,
        "relationship": selectedRelation!.toLowerCase(),
        "phone": phoneController.text.trim().isEmpty
            ? null
            : phoneController.text.trim(),
      };

      final dobApi = AppDateFormat.toApi(dobController.text.trim());
      final age = AppDateFormat.ageFromDob(dobController.text.trim());
      if (dobApi.isEmpty) {
        if (!mounted) return;
        setState(() => isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select a valid date of birth")),
        );
        return;
      }
      body["dob"] = dobApi;
      if (age != null) body["age"] = age;

      final response = await http.put(
        Uri.parse(
          "${ApiConfig.baseUrl}/patient/family-profiles/$editingFamilyId",
        ),
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (editingSelf) {
          await _syncSelfToMainProfile();
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              editingSelf
                  ? "Self profile updated successfully"
                  : "Family member updated successfully",
            ),
          ),
        );
        _clearForm();
        setState(() {});
        await fetchPatients();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_apiErrorMessage(data, "Update failed")),
          ),
        );
      }
    } catch (e) {
      debugPrint("Update Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Something went wrong")),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  /// Keep main patient profile + Home/Drawer name in sync when Self is edited.
  Future<void> _syncSelfToMainProfile() async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null || token.isEmpty) return;

      final name = nameController.text.trim();
      final phone = phoneController.text.trim();
      final gender = selectedGender?.toLowerCase() ?? '';
      final dob = AppDateFormat.toApi(dobController.text.trim());
      final age = AppDateFormat.ageFromDob(dobController.text.trim());

      final request = http.MultipartRequest(
        'POST',
        Uri.parse("${ApiConfig.baseUrl}/update-profile"),
      );
      request.headers['Authorization'] = "Bearer $token";
      request.headers['Accept'] = "application/json";
      request.fields['name'] = name;
      if (phone.isNotEmpty) request.fields['phone'] = phone;
      if (gender.isNotEmpty) request.fields['gender'] = gender;
      if (dob.isNotEmpty) request.fields['dob'] = dob;
      if (age != null) request.fields['age'] = age.toString();

      // Preserve address/email from cached user if form doesn't have them.
      final existing = await LocalStorage.getUser() ?? <String, dynamic>{};
      final address = (existing['address'] ?? '').toString();
      final email = (existing['email'] ?? '').toString();
      if (address.isNotEmpty) request.fields['address'] = address;
      if (email.isNotEmpty) request.fields['email'] = email;

      await request.send();

      existing['name'] = name;
      if (phone.isNotEmpty) existing['phone'] = phone;
      if (gender.isNotEmpty) existing['gender'] = gender;
      if (age != null) existing['age'] = age;
      if (dob.isNotEmpty) existing['dob'] = dob;
      await LocalStorage.saveUser(existing);
    } catch (e) {
      debugPrint("Self → main profile sync error: $e");
      // Still update local display name so Home/Drawer reflect the change.
      await LocalStorage.syncDisplayPrefs({
        'name': nameController.text.trim(),
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchPatients();
  }

  @override
  void dispose() {
    nameController.dispose();
    dobController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Widget buildInputField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: validator,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            errorMaxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget buildDropdown(
    String label,
    String? value,
    List<String> items,
    Function(String?) onChanged, {
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          hint: const Text("Select"),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: enabled
              ? (val) {
                  onChanged(val);
                }
              : null,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: validator,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            errorMaxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget buildDobField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Date of Birth *",
            style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: dobController,
          readOnly: true,
          onTap: _selectDob,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: _validateDob,
          decoration: InputDecoration(
            hintText: "DD-MM-YYYY",
            suffixIcon: const Icon(Icons.calendar_today, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            errorMaxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget buildTableHeader() {
    return const Row(
      children: [
        Expanded(
          child: Text("Name", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: Text("Relation",
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: Text("Gender", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: Text("Age", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          width: 48,
          child: Text("Edit", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget buildTableRow(Map<String, dynamic> p, int index) {
    final age = _ageForPatient(p);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(p["name"] ?? "-")),
          Expanded(child: Text(p["relationship"] ?? "-")),
          Expanded(child: Text(p["gender"] ?? "-")),
          Expanded(
            child: Text(age != null ? age.toString() : "-"),
          ),
          SizedBox(
            width: 48,
            child: GestureDetector(
              onTap: () => editPatient(index),
              child: const Icon(Icons.edit, color: Colors.blue, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Patient Profiles"),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/gradient.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: fetchPatients,
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          const Text(
                            "Patient profiles under this account",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            "Add family members and book appointments from same account.",
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 20),
                          buildInputField(
                            "Name *",
                            nameController,
                            validator: _validateName,
                          ),
                          const SizedBox(height: 15),
                          buildDobField(),
                          const SizedBox(height: 15),
                          buildDropdown(
                            "Gender *",
                            selectedGender,
                            genders,
                            (val) => setState(() => selectedGender = val),
                            validator: _validateGender,
                          ),
                          const SizedBox(height: 15),
                          buildDropdown(
                            "Relationship *",
                            selectedRelation,
                            editingSelf ? const ["Self"] : relations,
                            (val) => setState(() => selectedRelation = val),
                            enabled: !editingSelf,
                            validator: _validateRelation,
                          ),
                          const SizedBox(height: 15),
                          buildInputField(
                            "Phone",
                            phoneController,
                            keyboardType: TextInputType.phone,
                            validator: _validatePhone,
                          ),
                          const SizedBox(height: 25),
                          Center(
                            child: SizedBox(
                              width: 240,
                              child: ElevatedButton(
                                onPressed: isSaving
                                    ? null
                                    : () {
                                        if (isEditMode) {
                                          updateFamilyMember();
                                        } else {
                                          createFamilyMember();
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2B6F71),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: isSaving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        isEditMode
                                            ? (editingSelf
                                                ? "Update self profile"
                                                : "Update family member")
                                            : "Add family member",
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                              ),
                            ),
                          ),
                          if (isEditMode) ...[
                            const SizedBox(height: 10),
                            Center(
                              child: TextButton(
                                onPressed: () {
                                  _clearForm();
                                  setState(() {});
                                },
                                child: const Text("Cancel edit"),
                              ),
                            ),
                          ],
                          const SizedBox(height: 25),
                          buildTableHeader(),
                          const Divider(),
                          if (patients.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  "No profiles yet. Add a family member above.",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          else
                            ...patients.asMap().entries.map((entry) {
                              return buildTableRow(entry.value, entry.key);
                            }),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
