class AppBannerTarget {
  final String type;
  final int? id;
  final String? code;
  final String? entityCode;
  final String? name;
  final String? path;
  final String? webUrl;
  final String? url;
  final bool requiresAuth;

  const AppBannerTarget({
    required this.type,
    this.id,
    this.code,
    this.entityCode,
    this.name,
    this.path,
    this.webUrl,
    this.url,
    this.requiresAuth = false,
  });

  factory AppBannerTarget.fromJson(Map<String, dynamic> json) {
    return AppBannerTarget(
      type: (json['type'] ?? '').toString(),
      id: int.tryParse(json['id']?.toString() ?? ''),
      code: json['code']?.toString(),
      entityCode: json['entity_code']?.toString(),
      name: json['name']?.toString(),
      path: json['path']?.toString(),
      webUrl: json['web_url']?.toString(),
      url: json['url']?.toString(),
      requiresAuth: json['requires_auth'] == true,
    );
  }

  bool get isFacility =>
      type == 'hospital' || type == 'diagnostic' || type == 'dialysis';

  bool get isExternal => type == 'external';
}

class AppBanner {
  final int id;
  final String? title;
  final String image;
  final String placement;
  final String linkType;
  final int? linkEntityId;
  final String? linkUrl;
  final AppBannerTarget? target;
  final int sortOrder;

  const AppBanner({
    required this.id,
    required this.image,
    required this.placement,
    this.title,
    this.linkType = 'none',
    this.linkEntityId,
    this.linkUrl,
    this.target,
    this.sortOrder = 0,
  });

  factory AppBanner.fromJson(Map<String, dynamic> json) {
    AppBannerTarget? target;
    final rawTarget = json['target'];
    if (rawTarget is Map<String, dynamic>) {
      target = AppBannerTarget.fromJson(rawTarget);
    } else if (rawTarget is Map) {
      target = AppBannerTarget.fromJson(Map<String, dynamic>.from(rawTarget));
    }

    return AppBanner(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: json['title']?.toString(),
      image: (json['image'] ?? '').toString(),
      placement: (json['placement'] ?? '').toString(),
      linkType: (json['link_type'] ?? 'none').toString(),
      linkEntityId: int.tryParse(json['link_entity_id']?.toString() ?? ''),
      linkUrl: json['link_url']?.toString(),
      target: target,
      sortOrder: int.tryParse(json['sort_order']?.toString() ?? '') ?? 0,
    );
  }
}
