import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/deep_link_service.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _handlingScan = false;
  bool _pickingImage = false;

  /// True only while the camera scanner sheet is on screen. The gallery flow has
  /// no sheet to close, and popping unconditionally would close ScannerScreen
  /// itself — unmounting this state before the confirm dialog can be shown.
  bool _scannerSheetOpen = false;

  /// Pick a QR code image from the gallery and decode it locally.
  Future<void> _pickQrFromGallery() async {
    if (_pickingImage) return;
    setState(() => _pickingImage = true);
    try {
      final XFile? file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      if (file == null) return;
      final controller = MobileScannerController();
      final BarcodeCapture? result;
      try {
        result = await controller.analyzeImage(file.path);
      } finally {
        await controller.dispose();
      }
      if (!mounted) return;
      if (result == null || result.barcodes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No QR code found in the selected image.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      final String? raw = result.barcodes.first.rawValue;
      if (raw == null || raw.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR code is empty or unreadable.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      _handleScannedCode(raw);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to read QR code: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  void _openScanner() {
    _scannerSheetOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                'Scan QR Code',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: MobileScanner(
                    fit: BoxFit.cover,
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        if (barcode.rawValue != null &&
                            barcode.rawValue!.isNotEmpty) {
                          _handleScannedCode(barcode.rawValue!);
                          break;
                        }
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Close Scanner'),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() => _scannerSheetOpen = false);
  }

  Map<String, String> _qrMeta(String code) {
    final lower = code.toLowerCase();
    if (lower.contains('view-hospital-details') ||
        lower.contains('hospital-detail')) {
      return {
        'badge': 'Hospital',
        'title': 'Hospital found',
        'subtitle':
            'Continue to view hospital details and available doctors.',
        'action': 'Continue',
      };
    }
    if (lower.contains('view-doctor-profile')) {
      return {
        'badge': 'Doctor Profile',
        'title': 'Doctor profile found',
        'subtitle': 'Continue to open this doctor\'s profile.',
        'action': 'Continue',
      };
    }
    if (lower.contains('view-doctor-details') ||
        lower.contains('doctor-detail')) {
      return {
        'badge': 'Doctor',
        'title': 'Doctor found',
        'subtitle': 'Continue to view doctor details and book an appointment.',
        'action': 'Continue',
      };
    }
    if (lower.contains('view-diagnostic-center') ||
        lower.contains('diagnostic')) {
      return {
        'badge': 'Diagnostic Center',
        'title': 'Diagnostic center found',
        'subtitle': 'Continue to view diagnostic center details.',
        'action': 'Continue',
      };
    }
    if (lower.contains('view-dialysis-center') || lower.contains('dialysis')) {
      return {
        'badge': 'Dialysis Centre',
        'title': 'Dialysis centre found',
        'subtitle': 'Continue to view machines and book a slot.',
        'action': 'Continue',
      };
    }
    if (lower.startsWith('http') || lower.startsWith('scan2kare://')) {
      return {
        'badge': 'Scan2Kare',
        'title': 'Link found',
        'subtitle': 'Continue to open this Scan2Kare link.',
        'action': 'Continue',
      };
    }
    return {
      'badge': 'QR Code',
      'title': 'QR code scanned',
      'subtitle': 'Continue to process this QR code.',
      'action': 'Continue',
    };
  }

  void _handleScannedCode(String code) {
    if (_handlingScan) return;
    _handlingScan = true;

    if (_scannerSheetOpen && Navigator.of(context).canPop()) {
      Navigator.pop(context); // Close scanner sheet
      _scannerSheetOpen = false;
    }

    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) {
        _handlingScan = false;
        return;
      }
      _showScanConfirmDialog(code);
    });
  }

  void _showScanConfirmDialog(String code) {
    final meta = _qrMeta(code);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF2B6F71).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 42,
                  color: Color(0xFF2B6F71),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B6F71).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  meta['badge']!,
                  style: const TextStyle(
                    color: Color(0xFF2B6F71),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                meta['title']!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                meta['subtitle']!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _handlingScan = false;
                    _processQRCode(code);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2B6F71),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    meta['action']!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handlingScan = false;
                },
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      _handlingScan = false;
    });
  }

  void _processQRCode(String code) {
    if (code.isEmpty) {
      _showScannedDataDialog('Empty QR code');
      return;
    }
    try {
      final uri = Uri.tryParse(code);
      if (uri != null) {
        final path = DeepLinkService.extractPathFromUri(uri);
        if (path != null && DeepLinkService.isSupportedPath(path)) {
          _goDeepLink(path);
          return;
        }
      }

      if (code.contains('/view-hospital-details/') ||
          code.contains('/api/hospital-detail/')) {
        final parsedUri = Uri.tryParse(code);
        if (parsedUri != null && parsedUri.pathSegments.isNotEmpty) {
          _goDeepLink('/view-hospital-details/${parsedUri.pathSegments.last}');
          return;
        }
      }

      if (code.contains('/view-doctor-profile/')) {
        final parsedUri = Uri.tryParse(code);
        if (parsedUri != null && parsedUri.pathSegments.isNotEmpty) {
          _goDeepLink('/view-doctor-profile/${parsedUri.pathSegments.last}');
          return;
        }
      }

      if (code.contains('/view-doctor-details/') ||
          code.contains('/api/doctor-detail/')) {
        final parsedUri = Uri.tryParse(code);
        if (parsedUri != null && parsedUri.pathSegments.isNotEmpty) {
          _goDeepLink('/view-doctor-details/${parsedUri.pathSegments.last}');
          return;
        }
      }

      if (code.contains('/view-diagnostic-center-detail/')) {
        final parsedUri = Uri.tryParse(code);
        if (parsedUri != null && parsedUri.pathSegments.isNotEmpty) {
          _goDeepLink(
            '/view-diagnostic-center-detail/${parsedUri.pathSegments.last}',
          );
          return;
        }
      }
      if (code.contains('/view-dialysis-center-detail/')) {
        final parsedUri = Uri.tryParse(code);
        if (parsedUri != null && parsedUri.pathSegments.isNotEmpty) {
          _goDeepLink(
            '/view-dialysis-center-detail/${parsedUri.pathSegments.last}',
          );
          return;
        }
      }

      _showScannedDataDialog(code);
    } catch (e) {
      _showScannedDataDialog('Error processing QR code: $code');
    }
  }

  /// Pop scanner screen, then open destination via go_router (back → Home).
  void _goDeepLink(String path) {
    final location = path.startsWith('/') ? path : '/$path';
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop(); // close ScannerScreen
    }
    DeepLinkService.handleUri(
      Uri.parse('https://scan2kare.com$location'),
    );
  }

  void _showScannedDataDialog(String data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scanned Data'),
        content: SingleChildScrollView(
          child: SelectableText(data),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
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
        title: const Text('Scanner'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
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
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner,
                          size: 80,
                          color: Color(0xFF2B6F71),
                        ),
                      ),
                      const SizedBox(height: 25),
                      const Text(
                        'QR Scanner',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Point your camera at a Scan2Kare QR code',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _openScanner,
                                icon: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Scan QR Code',
                                  style: TextStyle(fontSize: 16),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2B6F71),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed:
                                    _pickingImage ? null : _pickQrFromGallery,
                                icon: _pickingImage
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF2B6F71),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.photo_library_outlined,
                                        color: Color(0xFF2B6F71),
                                      ),
                                label: Text(
                                  _pickingImage
                                      ? 'Reading QR…'
                                      : 'Upload QR Code',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF2B6F71),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  side: const BorderSide(
                                    color: Color(0xFF2B6F71),
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text(
                          '← Back to Home',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF2B6F71),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
