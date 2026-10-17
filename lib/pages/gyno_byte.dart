import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'unblock_dna_type_screen.dart';
import '../config/api_config.dart';

class GenoByteScreen extends StatefulWidget {
  final String title;

  const GenoByteScreen({
    super.key,
    this.title = "Geno Byte",
  });

  @override
  State<GenoByteScreen> createState() => _GenoByteScreenState();
}

class _GenoByteScreenState extends State<GenoByteScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final addressController = TextEditingController();

  DateTime? selectedDob;
  String? selectedGender;

  List<String> selectedPanels = [];

  final List<String> panelOptions = [
    "Men's Health",
    "Women's Health",
    "Whole Body Metabolic Pathway",
    "Autism (ASD)",
    "Fitness",
    "Nephrology",
    "Auto-Immune",
    "Fertility Male",
    "Neurodegenerative",
    "Allergies",
    "Fertility Female",
    "Nutrition",
    "Cardiovascular",
    "Diabetes",
    "Mental Health",
    "Sleep Disorder",
    "Microbiome (Gut)",
    "Others",
  ];

  bool isAcceptedTerms = false;
  bool showTermsError = false;

  /// 🔗 Open Terms URL
  Future<void> openUrl(String url) async {
    final Uri uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// 📅 DOB Picker
  Widget _buildDobField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Date of Birth *"),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            DateTime now = DateTime.now();
            DateTime? picked = await showDatePicker(
              context: context,
              initialDate: DateTime(2000),
              firstDate: DateTime(1950),
              lastDate: now,
            );
            if (picked != null) {
              setState(() {
                selectedDob = picked;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              selectedDob == null
                  ? "Select DOB"
                  : "${selectedDob!.toLocal()}".split(' ')[0],
            ),
          ),
        ),
      ],
    );
  }

  /// 👤 Gender Dropdown
  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      value: selectedGender,
      hint: const Text("Select Gender"),
      items: ["Male", "Female", "Other"]
          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
          .toList(),
      onChanged: (value) {
        setState(() {
          selectedGender = value;
        });
      },
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      ),
      validator: (value) => value == null ? "Please select gender" : null,
    );
  }

  Widget _buildPanelChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Select Panel *",
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: panelOptions.map((panel) {
            final isSelected = selectedPanels.contains(panel);

            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    selectedPanels.remove(panel);
                  } else {
                    selectedPanels.add(panel);
                  }
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF2B6F71)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF2B6F71)
                        : Colors.grey.shade400,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: isSelected ? Colors.white : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      panel,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 📝 Common Input Field
  Widget _buildField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ],
    );
  }

  /// 🚀 Submit API
  Future<void> submitForm() async {
    setState(() {
      showTermsError = !isAcceptedTerms;
    });

    if (!_formKey.currentState!.validate()) return;

    if (selectedDob == null) {
      _showMsg("Select DOB");
      return;
    }

    if (selectedPanels.isEmpty) {
      _showMsg("Select at least one panel");
      return;
    }

    if (!isAcceptedTerms) return;

    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/genobyte-store"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "name": nameController.text,
          "email": emailController.text,
          "address": addressController.text,
          "dob": selectedDob!.toIso8601String().split('T')[0],
          "gender": selectedGender,
          "panel": selectedPanels,
          "terms_accepted": isAcceptedTerms
        }),
      );

      if (response.statusCode == 201) {
        _showMsg("Submitted Successfully");

        // ✅ Clear form (optional)
        nameController.clear();
        emailController.clear();
        addressController.clear();
        selectedDob = null;
        selectedGender = null;
        selectedPanels.clear();
        isAcceptedTerms = false;

        setState(() {});

        // ✅ Navigate to Unlock DNA screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const UnlockDnaScreen(),
          ),
        );
      } else {
        _showMsg("Error: ${response.body}");
      }
    } catch (e) {
      _showMsg("Network error");
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/gradient.png',
              fit: BoxFit.cover,
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildField(
                    label: "Name *",
                    controller: nameController,
                    validator: (v) => v!.isEmpty ? "Enter name" : null,
                  ),

                  const SizedBox(height: 16),

                  _buildField(
                    label: "Email *",
                    controller: emailController,
                    validator: (v) => v!.contains('@') ? null : "Invalid email",
                  ),
                  const SizedBox(height: 16),

                  _buildField(
                    label: "Address *",
                    controller: addressController,
                    maxLines: 3,
                    validator: (v) => v!.isEmpty ? "Enter address" : null,
                  ),
                  const SizedBox(height: 16),

                  _buildDobField(),
                  const SizedBox(height: 16),

                  _buildGenderDropdown(),
                  const SizedBox(height: 16),

                  _buildPanelChips(),
                  const SizedBox(height: 16),

                  /// Terms
                  Row(
                    children: [
                      Checkbox(
                        value: isAcceptedTerms,
                        onChanged: (v) {
                          setState(() {
                            isAcceptedTerms = v!;
                          });
                        },
                      ),
                      GestureDetector(
                        onTap: () {
                          openUrl("https://scan2kare.com/terms");
                        },
                        child: const Text(
                          "Accept Terms & Conditions",
                          style: TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline),
                        ),
                      )
                    ],
                  ),

                  if (showTermsError)
                    const Text("Accept Terms",
                        style: TextStyle(color: Colors.red)),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2B6F71),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: submitForm,
                      child: const Text("Submit"),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
