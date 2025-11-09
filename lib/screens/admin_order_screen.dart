import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminOrderScreen extends StatefulWidget {
  const AdminOrderScreen({super.key});

  @override
  State<AdminOrderScreen> createState() => _AdminOrderScreenState();
}

class _AdminOrderScreenState extends State<AdminOrderScreen> {
  // 1. Get an instance of Firestore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 2. This is the function that updates the status in Firestore
  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      // Get the order document first to get the userId
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      final orderData = orderDoc.data() as Map<String, dynamic>;
      final userId = orderData['userId'] as String;

      // Update the order status
      await _firestore.collection('orders').doc(orderId).update({
        'status': newStatus,
      });

      // Create a notification
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': 'Order Status Updated',
        'body': 'Your order ($orderId) has been updated to "$newStatus"',
        'orderId': orderId,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order status updated!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }
  
  // 4. This function shows the update dialog
  void _showStatusDialog(String orderId, String currentStatus) {
    showDialog(
          context: context,
          builder: (dialogContext) {
        // 5. A list of all possible statuses
        const statuses = ['Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled'];
        
        return AlertDialog(
          title: const Text('Update Order Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min, // Make the dialog small
            children: statuses.map((status) {
              // 6. Create a button for each status
              return ListTile(
                title: Text(status),
                // 7. Show a checkmark next to the current status
                trailing: currentStatus == status ? const Icon(Icons.check) : null,
                onTap: () {
                  // 8. When tapped:
                  _updateOrderStatus(orderId, status); // Call update
                      Navigator.of(dialogContext).pop(); // Close the dialog using dialog's context
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            )
          ],
        );
      },
    );
  }
   @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Orders'),
      ),
      // 1. Use a StreamBuilder to get all orders
      body: StreamBuilder<QuerySnapshot>(
        // 2. This is our query
        stream: _firestore
            .collection('orders')
            .orderBy('createdAt', descending: true) // Newest first
            .snapshots(),
            
        builder: (context, snapshot) {
          // 3. Handle all states: loading, error, empty
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No orders found.'));
          }

          // 4. We have the orders!
          final orders = snapshot.data!.docs;

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final orderData = order.data() as Map<String, dynamic>;
              
              // 5. Format the date (same as OrderCard)
                  final Timestamp? timestamp = orderData['createdAt'] is Timestamp
                      ? (orderData['createdAt'] as Timestamp)
                      : null;
                  final String formattedDate = timestamp != null
                      ? DateFormat('MM/dd/yyyy hh:mm a').format(timestamp.toDate())
                      : 'Unknown date';
              
              // 6. Get the current status
                  final String status = (orderData['status'] as String?) ?? 'Unknown';

              // 7. Build a Card for each order
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text(
                    'Order ID: ${order.id}', // Show the doc ID
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  subtitle: Text(
                        'User: ${(orderData['userId'] as String?) ?? 'Unknown'}\n'
                        'Total: ₱${(((orderData['totalPrice'] as num?) ?? 0).toDouble()).toStringAsFixed(2)} | Date: $formattedDate'
                  ),
                  isThreeLine: true,
                  
                  // 8. Show the status with a colored chip
                  trailing: Chip(
                    label: Text(
                      status,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: 
                      status == 'Pending' ? Colors.orange : 
                      status == 'Processing' ? Colors.blue :
                      status == 'Shipped' ? Colors.deepPurple : 
                      status == 'Delivered' ? Colors.green : Colors.red,
                  ),
                  
                  // 9. On tap, show our update dialog
                  onTap: () {
                    _showStatusDialog(order.id, status);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}