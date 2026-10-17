import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/location_service.dart';
import '../services/opinion_service.dart';
import '../utils/local_storage.dart';
import 'second_opinion_landing.dart';

/// Second-opinion request form.
///
/// [category] arrives from the medical-category cards on [SecondOptionScreen]
/// — those cards previously had no tap handler at all (POI-008), so selecting
/// a category did nothing. It's optional here so the form still works when
/// reached without one.
class SecondOpinionPage extends StatefulWidget {
  const SecondOpinionPage({super.key, this.category, this.network});

  final String? category;

  /// Which specialist network to route to (India / U.S.), from the two
  /// network cards on the landing page — those previously called print() on
  /// tap and did nothing else.
  final String? network;

  @override
  State<SecondOpinionPage> createState() => _SecondOpinionPageState();
}

class _SecondOpinionPageState extends State<SecondOpinionPage> {
  static const Color _brand = Color(0xFF2B6F71);
  static const Color _brandLight = Color(0xFF3E9799);
  static const Color _ink = Color(0xFF16211F);
  static const Color _muted = Color(0xFF6E7E7E);
  static const Color _danger = Color(0xFFD5443B);

  final _formKey = GlobalKey<FormState>();

  final firstName = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final address = TextEditingController();
  final notes = TextEditingController();

  File? reportFile;
  bool acceptTerms = false;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _prefillFromLastKnown();
  }

  @override
  void dispose() {
    firstName.dispose();
    phone.dispose();
    email.dispose();
    address.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> _prefillFromLastKnown() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocation = await LocationService.loadLocation();

    if (!mounted) return;
    setState(() {
      final name = prefs.getString('user_name');
      if (name != null && name.isNotEmpty && name != 'Guest') {
        firstName.text = name;
      }
      final savedEmail = prefs.getString('user_email');
      if (savedEmail != null && savedEmail.isNotEmpty) {
        email.text = savedEmail;
      }
      if (savedLocation != null) {
        address.text = savedLocation['address'] ?? '';
      }
      final savedPhone = prefs.getString('user_phone');
      if (savedPhone != null && savedPhone.isNotEmpty) {
        phone.text = savedPhone;
      }
    });

    // Older sessions won't have 'user_phone' cached yet — fall back to the
    // full cached user JSON (already synced to prefs going forward).
    if (phone.text.isEmpty) {
      final user = await LocalStorage.getUser();
      final cachedPhone = (user?['phone'] ?? '').toString().trim();
      if (cachedPhone.isNotEmpty && mounted) {
        setState(() => phone.text = cachedPhone);
      }
    }
  }

  /// This was previously defined and never called from anywhere in the UI —
  /// the form had no way to attach the report it exists to review.
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.single.path == null) return;
    setState(() => reportFile = File(result.files.single.path!));
  }

  Future<void> _openTerms() async {
    final uri = Uri.parse('https://scan2kare.com/terms-and-conditions');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!acceptTerms) {
      _snack('Please accept the Terms & Conditions', isError: true);
      return;
    }

    setState(() => loading = true);

    try {
      await OpinionService.submitOpinion(
        firstName: firstName.text.trim(),
        phone: phone.text.trim(),
        email: email.text.trim(),
        address: address.text.trim(),
        category: widget.category,
        network: widget.network,
        notes: notes.text.trim(),
        report: reportFile,
      );

      if (!mounted) return;
      _snack('Request submitted — a specialist will review it shortly.');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SecondOptionScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      _snack('Could not submit your request. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _snack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _danger : _brand,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Second Opinion'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: _ink,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/gradient.png', fit: BoxFit.cover),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 90, 18, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.category != null || widget.network != null) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (widget.category != null)
                            _contextChip(
                              icon: Icons.medical_information_outlined,
                              label: widget.category!,
                            ),
                          if (widget.network != null)
                            _contextChip(
                              icon: Icons.public_rounded,
                              label: '${widget.network} Network',
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    const Text(
                      'Request a second opinion',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Share your details and, if you have one, a report — a specialist reviews it and gets back to you.',
                      style:
                          TextStyle(fontSize: 13.5, color: _muted, height: 1.4),
                    ),
                    const SizedBox(height: 22),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _sectionLabel('Your details'),
                          const SizedBox(height: 12),
                          _field(
                            controller: firstName,
                            label: 'Full name',
                            icon: Icons.person_outline_rounded,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Name is required';
                              }
                              if (v.trim().length < 3)
                                return 'Enter a valid name';
                              if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(v.trim())) {
                                return 'Only alphabets allowed';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _field(
                            controller: phone,
                            label: 'Phone number',
                            icon: Icons.call_outlined,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Phone is required';
                              }
                              if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v.trim())) {
                                return 'Enter a valid 10-digit mobile number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _field(
                            controller: email,
                            label: 'Email address',
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Email is required';
                              }
                              if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w]{2,4}$')
                                  .hasMatch(v.trim())) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _field(
                            controller: address,
                            label: 'Address',
                            icon: Icons.location_on_outlined,
                            maxLines: 3,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Address is required'
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _sectionLabel('Medical report (optional)'),
                          const SizedBox(height: 4),
                          const Text(
                            'PDF, JPG or PNG. Attaching a report helps the specialist give a more precise opinion.',
                            style: TextStyle(
                                fontSize: 12, color: _muted, height: 1.4),
                          ),
                          const SizedBox(height: 12),
                          _reportPicker(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _sectionLabel('Notes (optional)'),
                          const SizedBox(height: 12),
                          _field(
                            controller: notes,
                            label: 'Notes',
                            icon: Icons.edit_note_rounded,
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _termsRow(),
                    const SizedBox(height: 22),
                    _submitButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contextChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _brand.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _brand.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _brand),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: _brand,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _ink,
          letterSpacing: 0.2,
        ),
      );

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _brand.withOpacity(0.08),
            blurRadius: 24,
            spreadRadius: -6,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    // Flutter's InputDecorator sizes prefixIcon against the field's full
    // height, and for a multi-line field that means the icon (and the
    // floating label, which anchors relative to it) drift away from the text
    // instead of sitting beside its first line — attempts to override the
    // icon's alignment made this worse, not better. A composite layout with
    // the icon and label in their own header row sidesteps the geometry
    // fight entirely instead of continuing to patch it.
    if (maxLines > 1) {
      return _MultilineField(
        controller: controller,
        label: label,
        icon: icon,
        validator: validator,
        brand: _brand,
        danger: _danger,
        muted: _muted,
        ink: _ink,
      );
    }

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      validator: validator,
      cursorColor: _brand,
      style: const TextStyle(fontSize: 14.5, color: _ink),
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 4, right: 4),
          child: Icon(icon, size: 20, color: _muted),
        ),
        filled: true,
        fillColor: const Color(0xFFF3F7F7),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2EAEA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _brand, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _danger),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _reportPicker() {
    if (reportFile == null) {
      return InkWell(
        onTap: _pickFile,
        borderRadius: BorderRadius.circular(14),
        child: DottedBorderBox(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _brand.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.upload_file_rounded,
                      color: _brand, size: 22),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Tap to attach a file',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final name = reportFile!.path.split(Platform.pathSeparator).last;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2EAEA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_rounded, color: _brand, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => reportFile = null),
            icon: const Icon(Icons.close_rounded, size: 18, color: _muted),
            visualDensity: VisualDensity.compact,
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }

  Widget _termsRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: acceptTerms,
            activeColor: _brand,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            onChanged: (v) => setState(() => acceptTerms = v ?? false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: _openTerms,
            child: RichText(
              text: const TextSpan(
                style: TextStyle(color: _muted, fontSize: 13, height: 1.4),
                children: [
                  TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Terms & Conditions',
                    style: TextStyle(
                      color: _brand,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _submitButton() {
    return Opacity(
      opacity: loading ? 0.7 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [_brandLight, _brand],
          ),
          boxShadow: [
            BoxShadow(
              color: _brand.withOpacity(0.32),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: loading ? null : _submit,
            child: SizedBox(
              height: 54,
              child: Center(
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Submit request',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Simple dashed-border box for the upload tile — signals "drop zone" without
/// pulling in a dependency for one border style.
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB9C9C9)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(14),
    );

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Multi-line field (Address) as an icon+label header over a plain text area,
/// styled to match [_SecondOpinionPageState._field]'s single-line fields but
/// built without an [InputDecoration] prefixIcon — see the comment at its call
/// site for why.
class _MultilineField extends StatefulWidget {
  const _MultilineField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.brand,
    required this.danger,
    required this.muted,
    required this.ink,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color brand;
  final Color danger;
  final Color muted;
  final Color ink;
  final String? Function(String?)? validator;

  @override
  State<_MultilineField> createState() => _MultilineFieldState();
}

class _MultilineFieldState extends State<_MultilineField> {
  final FocusNode _focusNode = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _error != null;
    final borderColor = hasError
        ? widget.danger
        : _focusNode.hasFocus
            ? widget.brand
            : const Color(0xFFE2EAEA);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F7F7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: hasError || _focusNode.hasFocus ? 1.6 : 1,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(widget.icon, size: 17, color: widget.muted),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: widget.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: widget.controller,
                focusNode: _focusNode,
                maxLines: 3,
                minLines: 2,
                cursorColor: widget.brand,
                style: TextStyle(fontSize: 14.5, color: widget.ink),
                validator: (v) {
                  final result = widget.validator?.call(v);
                  // Runs outside the Form's own build pass (via onChanged),
                  // so the border color updates immediately rather than only
                  // after the next full-form validate() call.
                  if (result != _error) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _error = result);
                    });
                  }
                  return result;
                },
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                decoration: const InputDecoration(
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  errorStyle: TextStyle(height: 0, fontSize: 0),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 14, top: 6),
            child: Text(
              _error!,
              style: TextStyle(fontSize: 12, color: widget.danger),
            ),
          ),
      ],
    );
  }
}
