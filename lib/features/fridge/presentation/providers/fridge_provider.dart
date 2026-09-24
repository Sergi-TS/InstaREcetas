import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import '../../domain/models/fridge_item.dart';
import 'package:recipecatcher/core/services/notification_service.dart';
import '../../data/fridge_repository.dart';

class FridgeNotifier extends Notifier<List<FridgeItem>> {
  final _uuid = const Uuid();
  StreamSubscription? _subscription;

  @override
  List<FridgeItem> build() {
    _initSync();
    return [];
  }
  
  void _initSync() {
    final repository = ref.read(fridgeRepositoryProvider);
    _subscription = repository.watchItems().listen((items) {
      state = items;
      
      // Sincronizar notificaciones para los nuevos items cargados
      for (final item in items) {
        if (item.expirationDate != null) {
          NotificationService().scheduleExpirationNotification(
            id: item.id.hashCode,
            itemName: item.name,
            expirationDate: item.expirationDate!,
          );
        }
      }
    });
    
    ref.onDispose(() {
      _subscription?.cancel();
    });
  }

  Future<void> addItem({required String name, DateTime? expirationDate, String? quantity}) async {
    final newItem = FridgeItem(
      id: _uuid.v4(),
      name: name,
      expirationDate: expirationDate,
      quantity: quantity,
    );
    
    // Lo guardamos en Firestore. El Stream se encargará de actualizar el 'state'.
    try {
      final repository = ref.read(fridgeRepositoryProvider);
      await repository.saveItem(newItem);
    } catch (e) {
      // Si falla, al menos lo metemos local
      state = [...state, newItem];
    }
  }

  Future<void> removeItem(String id) async {
    try {
      final repository = ref.read(fridgeRepositoryProvider);
      await repository.deleteItem(id);
    } catch (e) {
      // Fallback local
      state = state.where((item) => item.id != id).toList();
    }
    NotificationService().cancelNotification(id.hashCode);
  }

  Future<void> updateItem(FridgeItem updatedItem) async {
    try {
      final repository = ref.read(fridgeRepositoryProvider);
      await repository.updateItem(updatedItem);
    } catch (e) {
      state = [
        for (final item in state)
          if (item.id == updatedItem.id) updatedItem else item
      ];
    }
    
    NotificationService().cancelNotification(updatedItem.id.hashCode);
  }
}

final fridgeProvider = NotifierProvider<FridgeNotifier, List<FridgeItem>>(() {
  return FridgeNotifier();
});
