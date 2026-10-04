class SalesSummary {
  const SalesSummary({
    required this.totalSales,
    required this.totalPaid,
    required this.totalDue,
    required this.totalProfit,
    required this.totalDiscount,
    required this.transactionCount,
    required this.itemsSold,
    required this.outstandingCredit,
  });

  final double totalSales;
  final double totalPaid;
  final double totalDue;
  final double totalProfit;
  final double totalDiscount;
  final int transactionCount;
  final double itemsSold;
  final double outstandingCredit;
}
