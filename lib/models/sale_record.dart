class SaleRecord {
  const SaleRecord({
    required this.id,
    required this.invoiceNo,
    this.customerName,
    required this.total,
    required this.paidAmount,
    required this.dueAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.createdAt,
  });

  final int id;
  final String invoiceNo;
  final String? customerName;
  final double total;
  final double paidAmount;
  final double dueAmount;
  final String paymentMethod;
  final String paymentStatus;
  final String createdAt;

  factory SaleRecord.fromMap(Map<String, dynamic> map) {
    return SaleRecord(
      id: map['id'] as int,
      invoiceNo: map['invoice_no'] as String,
      customerName: map['customer_name'] as String?,
      total: (map['total'] as num).toDouble(),
      paidAmount: (map['paid_amount'] as num).toDouble(),
      dueAmount: (map['due_amount'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String,
      paymentStatus: map['payment_status'] as String,
      createdAt: map['created_at'] as String,
    );
  }
}
