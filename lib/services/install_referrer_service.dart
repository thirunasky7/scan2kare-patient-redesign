import 'package:flutter/services.dart';

class InstallReferrerService {
  static const _channel = MethodChannel('com.scan2kare.patient/install_referrer');

  static Future<String?> getInstallReferrer() async {
    try {
      final referrer = await _channel.invokeMethod<String>('getInstallReferrer');
      return referrer;
    } on PlatformException {
      return null;
    }
  }
}
