class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.note,
    required this.outstandingAmount,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String? phone;
  final String? address;
  final String? note;
  final double outstandingAmount;
  final String createdAt;
  final String updatedAt;

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      note: map['note'] as String?,
      outstandingAmount: (map['outstanding_amount'] as num?)?.toDouble() ?? 0,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }
}
