import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../utils/api_error.dart';
import '../utils/local_storage.dart';
import '../utils/token_storage.dart';

class CareFolderItem {
  final String name;
  final String role;
  final String description;
  final String? icon;
  final String? url;
  final String? hospitalSearch;
  final String? href;

  CareFolderItem({
    required this.name,
    this.role = '',
    this.description = '',
    this.icon,
    this.url,
    this.hospitalSearch,
    this.href,
  });

  factory CareFolderItem.fromJson(Map<String, dynamic> json) {
    return CareFolderItem(
      name: (json['name'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      icon: CareFolderService.normalizeAssetUrl(json['icon']?.toString()),
      url: json['url']?.toString(),
      hospitalSearch: json['hospital_search']?.toString(),
      href: json['href']?.toString(),
    );
  }
}

class CareScanFolder {
  final String slug;
  final String title;
  final String subtitle;
  final String? icon;

  CareScanFolder({
    required this.slug,
    required this.title,
    this.subtitle = '',
    this.icon,
  });

  factory CareScanFolder.fromJson(Map<String, dynamic> json) {
    return CareScanFolder(
      slug: (json['slug'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      icon: CareFolderService.normalizeAssetUrl(json['icon']?.toString()),
    );
  }
}

class CareChild {
  final String slug;
  final String folderSlug;
  final String title;
  final String subtitle;
  final String description;
  final String content;
  final String? icon;
  final String? url;
  final List<String> sliders;
  final List<CareFolderItem> items;
  final List<CareScanFolder> scanFolders;

  CareChild({
    required this.slug,
    required this.folderSlug,
    required this.title,
    this.subtitle = '',
    this.description = '',
    this.content = '',
    this.icon,
    this.url,
    this.sliders = const [],
    this.items = const [],
    this.scanFolders = const [],
  });

  factory CareChild.fromJson(Map<String, dynamic> json) {
    return CareChild(
      slug: (json['slug'] ?? '').toString(),
      folderSlug: (json['folder_slug'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      icon: CareFolderService.normalizeAssetUrl(json['icon']?.toString()),
      url: json['url']?.toString(),
      sliders: ((json['sliders'] as List?) ?? [])
          .map((e) => CareFolderService.normalizeAssetUrl(e.toString()) ?? '')
          .where((e) => e.isNotEmpty)
          .toList(),
      items: ((json['items'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => CareFolderItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      scanFolders: ((json['scan_folders'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => CareScanFolder.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class CareFolder {
  final String slug;
  final String title;
  final String subtitle;
  final String description;
  final String? icon;
  final List<CareChild> children;

  CareFolder({
    required this.slug,
    required this.title,
    this.subtitle = '',
    this.description = '',
    this.icon,
    this.children = const [],
  });

  factory CareFolder.fromJson(Map<String, dynamic> json) {
    return CareFolder(
      slug: (json['slug'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      icon: CareFolderService.normalizeAssetUrl(json['icon']?.toString()),
      children: ((json['children'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => CareChild.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class CareFolderService {
  static String get _assetBase => '${ApiConfig.host}/public/assets';

  static String _asset(String file) => '$_assetBase/homepage/$file';

  /// Care-folder images live on the API host (dev.scan2kare.com), not
  /// scan2kare.com/public/assets which 404s for these files.
  static String? normalizeAssetUrl(String? url) {
    if (url == null) return null;
    final raw = url.trim();
    if (raw.isEmpty || raw == 'null') return null;

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      final uri = Uri.tryParse(raw);
      if (uri == null) return raw;
      final path = uri.path;
      final idx = path.indexOf('/assets/');
      if (idx >= 0) {
        final after = path.substring(idx + '/assets/'.length);
        return '$_assetBase/$after';
      }
      return raw;
    }

    var rel = raw.replaceFirst(RegExp(r'^/+'), '');
    rel = rel.replaceFirst(RegExp(r'^public/'), '');
    rel = rel.replaceFirst(RegExp(r'^assets/'), '');
    return '$_assetBase/$rel';
  }

  static List<CareFolder> fallbackFolders() {
    return [
      CareFolder(
        slug: 'gynec',
        title: 'Gynecology',
        subtitle: 'Women’s health specialties',
        description:
            'Explore gynecology care options including oncology and infertility services.',
        icon: _asset('genocology.png'),
        children: [
          CareChild(
            slug: 'gynecologic-oncology',
            folderSlug: 'gynec',
            title: 'Gynecologic Oncology',
            subtitle: 'Cancer care for women’s reproductive health',
            description:
                'A specialized women’s healthcare centre focused on Gynaecology and Gynaecologic Oncology.',
            icon: _asset('genocology.png'),
            items: [
              CareFolderItem(
                name: 'Punar Bhava',
                role: 'Centre',
                description:
                    'Dr. Roopesh’s Clinic — gynaecology and gynaecologic oncology care.',
                icon: _asset('punarbhava.png'),
                url: 'https://punarbhava.org/#',
                href: 'https://punarbhava.org/#',
              ),
            ],
          ),
          CareChild(
            slug: 'infertility',
            folderSlug: 'gynec',
            title: 'Infertility',
            subtitle: 'Fertility & reproductive care',
            description: 'Infertility evaluation and treatment partners.',
            icon: _asset('infertility.png'),
          ),
        ],
      ),
      CareFolder(
        slug: 'telemedicine',
        title: 'Telemedicine',
        subtitle: 'Virtual care partners',
        description: 'Consult doctors online through our telemedicine partners.',
        icon: _asset('telemedicine.png'),
        children: [
          CareChild(
            slug: 'nuvacare',
            folderSlug: 'telemedicine',
            title: 'Nuvacure',
            subtitle: 'Telemedicine partner',
            description: 'Assisted telemedicine clinics on Scan2Kare.',
            content:
                'Nuvacure provides accessible, technology-enabled primary healthcare through assisted telemedicine clinics.',
            icon: _asset('nuvacare.png'),
            url: 'https://nuvacure.com/',
            sliders: [
              '$_assetBase/nuvacare/banner1.png',
              '$_assetBase/nuvacare/banner2.png',
            ],
            items: [
              CareFolderItem(
                name: 'Nuvacure',
                role: 'Partner',
                description: 'Digi Health Clinics.',
                icon: _asset('nuvacare.png'),
                hospitalSearch: 'Novacare',
                href: 'https://nuvacure.com/',
              ),
            ],
          ),
        ],
      ),
      CareFolder(
        slug: 'radiology',
        title: 'Radiology',
        subtitle: 'Imaging & radiology partners',
        description: 'Radiology and diagnostic imaging partners.',
        icon: _asset('radiology.png'),
        children: [
          CareChild(
            slug: 'aikensit',
            folderSlug: 'radiology',
            title: 'Aikensit',
            subtitle: 'Radiology partner',
            description: 'Aikensit radiology services on Scan2Kare.',
            icon: _asset('aikenist.png'),
            sliders: [
              '$_assetBase/aikensit/banner1.png',
              '$_assetBase/aikensit/banner2.png',
              '$_assetBase/aikensit/banner3.png',
            ],
            items: [
              CareFolderItem(
                name: 'Aikensit',
                role: 'Centre',
                description: 'Radiology and imaging partner.',
                icon: _asset('aikenist.png'),
              ),
            ],
            scanFolders: [
              CareScanFolder(
                slug: 'xray',
                title: 'X-Ray',
                subtitle: 'Upload an X-Ray image or report',
                icon: _asset('x-ray.png'),
              ),
              CareScanFolder(
                slug: 'ct',
                title: 'CT',
                subtitle: 'Upload a CT scan image or report',
                icon: _asset('ct-scan.png'),
              ),
              CareScanFolder(
                slug: 'mri',
                title: 'MRI',
                subtitle: 'Upload an MRI image or report',
                icon: _asset('mri-scan.png'),
              ),
            ],
          ),
        ],
      ),
    ];
  }

  static Future<List<CareFolder>> listFolders() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/care-folders'),
        headers: {'Accept': 'application/json'},
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['data'] is List) {
        return (data['data'] as List)
            .whereType<Map>()
            .map((e) => CareFolder.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return fallbackFolders();
  }

  static Future<CareFolder> getFolder(String slug) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/care-folders/$slug'),
        headers: {'Accept': 'application/json'},
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['data'] is Map) {
        return CareFolder.fromJson(Map<String, dynamic>.from(data['data'] as Map));
      }
    } catch (_) {}
    return fallbackFolders().firstWhere(
      (f) => f.slug == slug,
      orElse: () => CareFolder(slug: slug, title: slug),
    );
  }

  static Future<String> _token() async {
    return await TokenStorage.getToken() ??
        await LocalStorage.getToken() ??
        '';
  }

  static Future<Map<String, dynamic>> uploadScan({
    required String folder,
    required String subfolder,
    required String scan,
    required String filePath,
    String? fileName,
    int? patientId,
  }) async {
    final token = await _token();
    if (token.isEmpty) {
      throw Exception('Please log in to upload a scan.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        '${ApiConfig.baseUrl}/care-folders/$folder/$subfolder/$scan/upload',
      ),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';
    if (patientId != null) {
      request.fields['patient_id'] = patientId.toString();
    }
    request.files.add(
      await http.MultipartFile.fromPath(
        'scan_file',
        filePath,
        filename: fileName,
      ),
    );

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    Map<String, dynamic> data = {};
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map) data = Map<String, dynamic>.from(parsed);
    } catch (_) {}

    if ((streamed.statusCode == 200 || streamed.statusCode == 201) &&
        (data['success'] == true || data['status'] == true)) {
      return data;
    }
    throw Exception(
      friendlyApiError(
        data,
        fallback: 'Could not upload this scan. Please try again.',
      ),
    );
  }
}
