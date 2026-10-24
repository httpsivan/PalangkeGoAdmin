class StallProduct {
  const StallProduct({
    required this.id,
    required this.vendorId,
    required this.name,
    required this.category,
    required this.price,
    this.unit = 'kg',
    required this.stockQuantity,
    this.initialStockQuantity = 0.0,
    this.isActive = true,
    this.imageUrl = '',
    this.emoji = '🥬',
    this.srpMin,
    this.srpMax,
    this.isFlagged = false,
    this.flagReason,
    this.description = '',
    this.addedAt,
  });

  final String id;
  final String vendorId;
  final String name;
  final String category;
  final double price;
  final String unit; // 'kg', '500g', '250g', 'tali', 'tumpok', 'pc'
  final double stockQuantity;
  final double initialStockQuantity;
  final bool isActive;
  final String imageUrl;
  final String emoji;
  final double? srpMin;
  final double? srpMax;
  final bool isFlagged;
  final String? flagReason;
  final String description;
  final DateTime? addedAt;

  DateTime get dateAdded {
    if (addedAt != null) return addedAt!;
    final hash = id.codeUnits.fold(0, (prev, elem) => prev + elem);
    final dayOffset = (hash % 12) + 1;
    final hour = 6 + (hash % 11);
    final minute = (hash * 7) % 60;
    return DateTime(2026, 10, 24, hour, minute).subtract(Duration(days: dayOffset));
  }

  bool get isLowStock {
    if (stockQuantity <= 0) return false;
    final u = unit.toLowerCase().trim();
    final isPiece = u == 'pc' || u == 'piece' || u == 'pieces' || u == 'tali' || u == 'tumpok';
    return isPiece ? stockQuantity <= 10 : stockQuantity <= 5.0;
  }

  bool get isOutOfStock => stockQuantity <= 0;

  bool get isAboveSrp {
    if (srpMax == null || srpMax! <= 0) return false;
    return price > srpMax!;
  }

  double get srpSurgePercent {
    if (srpMax == null || srpMax! <= 0 || price <= srpMax!) return 0.0;
    return ((price - srpMax!) / srpMax!) * 100.0;
  }

  StallProduct copyWith({
    String? id,
    String? vendorId,
    String? name,
    String? category,
    double? price,
    String? unit,
    double? stockQuantity,
    double? initialStockQuantity,
    bool? isActive,
    String? imageUrl,
    String? emoji,
    double? srpMin,
    double? srpMax,
    bool? isFlagged,
    String? flagReason,
    String? description,
    DateTime? addedAt,
  }) {
    return StallProduct(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      unit: unit ?? this.unit,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      initialStockQuantity: initialStockQuantity ?? this.initialStockQuantity,
      isActive: isActive ?? this.isActive,
      imageUrl: imageUrl ?? this.imageUrl,
      emoji: emoji ?? this.emoji,
      srpMin: srpMin ?? this.srpMin,
      srpMax: srpMax ?? this.srpMax,
      isFlagged: isFlagged ?? this.isFlagged,
      flagReason: flagReason ?? this.flagReason,
      description: description ?? this.description,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}
