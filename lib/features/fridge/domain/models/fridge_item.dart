class FridgeItem {
  final String id;
  final String name;
  final DateTime? expirationDate;
  final String? quantity;

  FridgeItem({
    required this.id,
    required this.name,
    this.expirationDate,
    this.quantity,
  });

  FridgeItem copyWith({
    String? id,
    String? name,
    DateTime? expirationDate,
    String? quantity,
  }) {
    return FridgeItem(
      id: id ?? this.id,
      name: name ?? this.name,
      expirationDate: expirationDate ?? this.expirationDate,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'expirationDate': expirationDate?.toIso8601String(),
      'quantity': quantity,
    };
  }

  factory FridgeItem.fromMap(Map<String, dynamic> map, String documentId) {
    return FridgeItem(
      id: documentId,
      name: map['name'] ?? '',
      expirationDate: map['expirationDate'] != null 
          ? DateTime.tryParse(map['expirationDate']) 
          : null,
      quantity: map['quantity'],
    );
  }
}
