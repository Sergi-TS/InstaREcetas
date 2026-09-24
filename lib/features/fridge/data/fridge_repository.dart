import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/fridge_item.dart';

final fridgeRepositoryProvider = Provider((ref) => FridgeRepository());

class FridgeRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _fridgeCollection {
    final uid = _userId;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('fridge');
  }

  Future<void> saveItem(FridgeItem item) async {
    final collection = _fridgeCollection;
    if (collection == null) throw Exception('Usuario no autenticado');
    
    await collection.doc(item.id).set(item.toMap());
  }

  Future<void> updateItem(FridgeItem item) async {
    final collection = _fridgeCollection;
    if (collection == null) throw Exception('Usuario no autenticado');
    
    await collection.doc(item.id).update(item.toMap());
  }

  Future<void> deleteItem(String id) async {
    final collection = _fridgeCollection;
    if (collection == null) throw Exception('Usuario no autenticado');
    
    await collection.doc(id).delete();
  }

  Stream<List<FridgeItem>> watchItems() {
    final collection = _fridgeCollection;
    if (collection == null) return Stream.value([]);
    
    return collection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => FridgeItem.fromMap(doc.data(), doc.id)).toList();
    });
  }
}
