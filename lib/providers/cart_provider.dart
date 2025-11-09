import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class CartItem {
  final String id;       
  final String name;
  final double price;
  int quantity;       

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 1,
  });
   Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'],
      name: json['name'],
      price: json['price'],
      quantity: json['quantity'],
    );
  }
}

class CartProvider with ChangeNotifier {

  List<CartItem> _items = [];

  String? _userId;
  StreamSubscription<User?>? _authSubscription;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;


  List<CartItem> get items => _items;

  // Lightweight constructor: do not start async listeners here to avoid
  // initialization ordering/deadlocks. Call initializeAuthListener()
  // from main.dart (before runApp) after Firebase.initializeApp().
  CartProvider() {
    print('CartProvider initialized (listener not started)');
  }

  /// Call this once after Firebase.initializeApp() and before runApp()
  /// to attach the auth listener. This prevents a deadlock on startup
  /// when the provider is created before Firebase is fully ready.
  Future<void> initializeAuthListener() async {
    // Cancel existing if any
    await _authSubscription?.cancel();

    _authSubscription = _auth.authStateChanges().listen((User? user) {
      if (user == null) {
        print('User logged out, clearing cart.');
        _userId = null;
        _items = [];
      } else {
        print('User logged in: ${user.uid}. Fetching cart...');
        _userId = user.uid;
        _fetchCart();
      }
      notifyListeners();
    });
  }
    Future<void> _fetchCart() async {
    if (_userId == null) return;

    try {
      final doc = await _firestore.collection('userCarts').doc(_userId).get();
      
      if (doc.exists && doc.data()!['cartItems'] != null) {
        final List<dynamic> cartData = doc.data()!['cartItems'];
        
        _items = cartData.map((item) => CartItem.fromJson(item)).toList();
        print('Cart fetched successfully: ${_items.length} items');
      } else {
        _items = [];
      }
    } catch (e) {
      print('Error fetching cart: $e');
      _items = [];
    }
    notifyListeners(); 
  }

  Future<void> _saveCart() async {
    if (_userId == null) return; 

    try {
      final List<Map<String, dynamic>> cartData = 
          _items.map((item) => item.toJson()).toList();
      
      await _firestore.collection('userCarts').doc(_userId).set({
        'cartItems': cartData,
      });
      print('Cart saved to Firestore');
    } catch (e) {
      print('Error saving cart: $e');
    }
  }

  int get itemCount => _items.fold(0, (total, item) => total + item.quantity);

  // Returns the total before VAT
  double get subtotal => _items.fold(
        0.0,
        (total, item) => total + (item.price * item.quantity),
      );

  // Calculates 12% VAT from subtotal
  double get vat => subtotal * 0.12;

  // Returns final total including VAT
  double get totalPriceWithVat => subtotal + vat;

  void addItem(String id, String name, double price, {int quantity = 1}) {
    var index = _items.indexWhere((item) => item.id == id);

    if (index != -1) {
      _items[index].quantity += quantity;
    } else {
      _items.add(CartItem(id: id, name: name, price: price, quantity: quantity));
    }
    _saveCart();
    notifyListeners();
  }

  void removeItem(String id) {
    _items.removeWhere((item) => item.id == id);
    _saveCart();
    notifyListeners();
  }
  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

   Future<void> placeOrder() async {
    if (_userId == null || _items.isEmpty) {
      throw Exception('Cart is empty or user is not logged in.');
    }

    try {
      final List<Map<String, dynamic>> cartData = 
          _items.map((item) => item.toJson()).toList();
      
      final double subtotalAmount = subtotal;
      final double vatAmount = vat;
      final double totalAmount = totalPriceWithVat;
      final int count = itemCount;

      await _firestore.collection('orders').add({
        'userId': _userId,
        'items': cartData,
        'subtotal': subtotalAmount,
        'vat': vatAmount,
        'totalPrice': totalAmount,
        'itemCount': count,
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
    } catch (e) {
      print('Error placing order: $e');
      throw e; 
    }
  }
  Future<void> clearCart() async {
    _items = [];
    
    if (_userId != null) {
      try {
        await _firestore.collection('userCarts').doc(_userId).set({
          'cartItems': [],
        });
        print('Firestore cart cleared.');
      } catch (e) {
        print('Error clearing Firestore cart: $e');
      }
    }

    notifyListeners();
  }
}