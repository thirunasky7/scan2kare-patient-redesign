class DialysisCenterItem {
  final int id;
  final String centerName;
  final String? code;
  final String? address;
  final String? city;
  final String? state;
  final String? mobileNo;
  final String? profileImage;
  final double? latitude;
  final double? longitude;
  final double? distance;
  final bool isFeatured;

  DialysisCenterItem({
    required this.id,
    required this.centerName,
    this.code,
    this.address,
    this.city,
    this.state,
    this.mobileNo,
    this.profileImage,
    this.latitude,
    this.longitude,
    this.distance,
    this.isFeatured = false,
  });

  factory DialysisCenterItem.fromJson(Map<String, dynamic> json) {
    return DialysisCenterItem(
      id: int.tryParse('${json['id']}') ?? 0,
      centerName: (json['center_name'] ?? '').toString(),
      code: json['code']?.toString(),
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      mobileNo: json['mobile_no']?.toString(),
      profileImage: json['profile_image']?.toString(),
      latitude: double.tryParse('${json['latitude']}'),
      longitude: double.tryParse('${json['longitude']}'),
      distance: double.tryParse('${json['distance']}'),
      isFeatured: json['is_featured'] == true || json['is_featured'] == 1,
    );
  }

  String get locationLine {
    final parts = [city, state].where((e) => e != null && e.isNotEmpty);
    if (parts.isNotEmpty) return parts.join(', ');
    return address ?? '';
  }
}

class DialysisBookingItem {
  final int id;
  final String? bookingReference;
  final String status;
  final String? bookingDate;
  final String? slotTime;
  final String? shift;
  final String? patientName;
  final int? centerId;
  final String? centerName;
  final int? branchId;
  final String? branchName;
  final int? machineId;
  final String? machineName;

  DialysisBookingItem({
    required this.id,
    this.bookingReference,
    required this.status,
    this.bookingDate,
    this.slotTime,
    this.shift,
    this.patientName,
    this.centerId,
    this.centerName,
    this.branchId,
    this.branchName,
    this.machineId,
    this.machineName,
  });

  factory DialysisBookingItem.fromJson(Map<String, dynamic> json) {
    final center = json['center'] is Map ? json['center'] as Map : null;
    final branch = json['branch'] is Map ? json['branch'] as Map : null;
    final machine = json['machine'] is Map ? json['machine'] as Map : null;

    return DialysisBookingItem(
      id: int.tryParse('${json['id']}') ?? 0,
      bookingReference: json['booking_reference']?.toString(),
      status: (json['status'] ?? 'pending').toString(),
      bookingDate: json['booking_date']?.toString(),
      slotTime: json['slot_time']?.toString(),
      shift: json['shift']?.toString(),
      patientName: json['patient_name']?.toString(),
      centerId: int.tryParse('${center?['id'] ?? json['dialysis_center_id'] ?? ''}'),
      centerName: center?['center_name']?.toString(),
      branchId: int.tryParse('${branch?['id'] ?? json['dialysis_branch_id'] ?? ''}'),
      branchName: branch?['branch_name']?.toString(),
      machineId: int.tryParse('${machine?['id'] ?? json['dialysis_machine_id'] ?? ''}'),
      machineName: machine?['machine_name']?.toString(),
    );
  }

  bool get canReschedule =>
      status == 'pending' || status == 'accepted' || status == 'rescheduled';
}
