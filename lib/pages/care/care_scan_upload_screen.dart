import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/care_folder_service.dart';
import '../../utils/api_error.dart';
import '../../utils/auth_nav.dart';
import '../../utils/token_storage.dart';

class CareScanUploadScreen extends StatefulWidget {
  final String folderSlug;
  final String subfolderSlug;
  final CareScanFolder scan;

  const CareScanUploadScreen({
    super.key,
    required this.folderSlug,
    required this.subfolderSlug,
    required this.scan,
  });

  @override
  State<CareScanUploadScreen> createState() => _CareScanUploadScreenState();
}

class _CareScanUploadScreenState extends State<CareScanUploadScreen> {
  static const Color _brand = Color(0xFF2B6F71);
  static const _allowed = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'bmp',
    'heic',
    'heif',
    'pdf',
    'dcm',
    'dicom',
  };

  final ImagePicker _picker = ImagePicker();
  File? _file;
  Uint8List? _previewBytes;
  String? _fileName;
  bool _fromCamera = false;
  bool _loggedIn = false;
  bool _checkingAuth = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final ok = await TokenStorage.hasToken();
    if (!mounted) return;
    setState(() {
      _loggedIn = ok;
      _checkingAuth = false;
    });
  }

  bool _isImageName(String name) {
    final ext = name.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'heic', 'heif']
        .contains(ext);
  }

  String _extensionOf(String name) {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  Future<void> _setPicked({
    required String name,
    String? path,
    Uint8List? bytes,
    required bool fromCamera,
  }) async {
    final ext = _extensionOf(name);
    if (ext.isNotEmpty && !_allowed.contains(ext)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload an image, PDF, or DICOM file.'),
        ),
      );
      return;
    }

    Uint8List? data = bytes;
    if ((data == null || data.isEmpty) && path != null && path.isNotEmpty) {
      try {
        data = await File(path).readAsBytes();
      } catch (_) {}
    }

    File? file;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      file = File(path);
    }
    if (file == null && data != null && data.isNotEmpty) {
      final safeName = name.replaceAll(RegExp(r'[^\w.\-]+'), '_');
      file = File(
        '${Directory.systemTemp.path}/aikensit_${DateTime.now().millisecondsSinceEpoch}_$safeName',
      );
      await file.writeAsBytes(data, flush: true);
    }

    if (file == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read that file. Please try another.')),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _file = file;
      _previewBytes = data;
      _fileName = name;
      _fromCamera = fromCamera;
    });
  }

  Future<void> _pickFile() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        await _setPicked(
          name: image.name.isNotEmpty ? image.name : 'scan.jpg',
          path: image.path,
          bytes: await image.readAsBytes(),
          fromCamera: false,
        );
        return;
      }
    } catch (_) {}

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.single;
      final name = (picked.name.isNotEmpty)
          ? picked.name
          : (picked.path?.split(Platform.pathSeparator).last ?? 'scan-file');
      await _setPicked(
        name: name,
        path: picked.path,
        bytes: picked.bytes,
        fromCamera: false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open files. Please try again.'),
        ),
      );
    }
  }

  Future<void> _pickCamera() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (picked == null) return;
      await _setPicked(
        name: picked.name.isNotEmpty ? picked.name : 'camera.jpg',
        path: picked.path,
        bytes: await picked.readAsBytes(),
        fromCamera: true,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the camera. Please allow camera access and try again.'),
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (_file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose a file or take a photo before submitting.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await CareFolderService.uploadScan(
        folder: widget.folderSlug,
        subfolder: widget.subfolderSlug,
        scan: widget.scan.slug,
        filePath: _file!.path,
        fileName: _fileName,
      );
      if (!mounted) return;
      final message = (result['message'] ??
              '${widget.scan.title} uploaded successfully. Our team will review it shortly.')
          .toString();
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Upload successful'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyException(
            e,
            fallback: 'Could not upload this scan. Please try again.',
          )),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        title: Text(widget.scan.title),
      ),
      body: _checkingAuth
          ? const Center(child: CircularProgressIndicator(color: _brand))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  widget.scan.subtitle.isNotEmpty
                      ? widget.scan.subtitle
                      : 'Upload a file, preview it, then submit.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                ),
                const SizedBox(height: 20),
                if (!_loggedIn) _loginCard() else _uploadCard(),
              ],
            ),
    );
  }

  Widget _loginCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFE7F6F1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline, color: _brand, size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            'Login required to upload',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Please sign in with your patient account to upload ${widget.scan.title} for yourself or a family member.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, height: 1.4),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: goToLogin,
              child: const Text('Login to Upload'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _uploadCard() {
    final name = _fileName ??
        _file?.path.split(Platform.pathSeparator).last ??
        '';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _sourceButton(
                  icon: Icons.folder_open,
                  label: 'Upload from File',
                  active: _file != null && !_fromCamera,
                  onTap: _pickFile,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _sourceButton(
                  icon: Icons.photo_camera,
                  label: 'Upload from Camera',
                  active: _file != null && _fromCamera,
                  onTap: _pickCamera,
                ),
              ),
            ],
          ),
          if (_file != null) ...[
            const SizedBox(height: 20),
            if (_isImageName(name) &&
                _previewBytes != null &&
                _previewBytes!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  _previewBytes!,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => _fileFallback(name),
                ),
              )
            else
              _fileFallback(name),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _file == null || _submitting ? Colors.grey : _brand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: _file == null || _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Submit',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fileFallback(String name) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.insert_drive_file, size: 18, color: _brand),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sourceButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _submitting ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 140,
          decoration: BoxDecoration(
            color: active ? const Color(0xFFF5FBFD) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? const Color(0xFF00A7C4) : const Color(0xFF94A3B8),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF00A7C4), size: 32),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF003B5C),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
