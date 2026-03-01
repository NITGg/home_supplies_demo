class CourierUser {
  final int id;
  final String fullName;
  final String phone;

  CourierUser({
    required this.id,
    required this.fullName,
    required this.phone,
  });

  factory CourierUser.fromJson(Map<String, dynamic> json) {
    return CourierUser(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String,
    );
  }
}

class CourierInfo {
  final int id;
  final CourierUser user;

  CourierInfo({
    required this.id,
    required this.user,
  });

  factory CourierInfo.fromJson(Map<String, dynamic> json) {
    return CourierInfo(
      id: json['id'] as int,
      user: CourierUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class Proposal {
  final int id;
  final int orderId;
  final int courierId;
  final String totalFee;
  final String status; // PENDING, ACCEPTED, REJECTED
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final CourierInfo courier;

  Proposal({
    required this.id,
    required this.orderId,
    required this.courierId,
    required this.totalFee,
    required this.status,
    required this.createdAt,
    this.confirmedAt,
    required this.courier,
  });

  factory Proposal.fromJson(Map<String, dynamic> json) {
    return Proposal(
      id: json['id'] as int,
      orderId: json['order_id'] as int,
      courierId: json['courier_id'] as int,
      totalFee: ((num.tryParse(json['total_fee']?.toString() ?? '0') ?? 0) / 100)
          .toStringAsFixed(0),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at']),
      confirmedAt: json['confirmed_at'] != null
          ? DateTime.parse(json['confirmed_at'])
          : null,
      courier: CourierInfo.fromJson(json['courier'] as Map<String, dynamic>),
    );
  }

  bool get isPending => status == 'PENDING';
  bool get isAccepted => status == 'ACCEPTED';
  bool get isRejected => status == 'REJECTED';
}

class ProposalsResponse {
  final List<Proposal> proposals;

  ProposalsResponse({required this.proposals});

  factory ProposalsResponse.fromJson(Map<String, dynamic> json) {
    return ProposalsResponse(
      proposals: (json['proposals'] as List<dynamic>)
          .map((e) => Proposal.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}