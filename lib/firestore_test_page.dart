import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreTestPage extends StatefulWidget {
  const FirestoreTestPage({super.key});

  @override
  State<FirestoreTestPage> createState() => _FirestoreTestPageState();
}

class _FirestoreTestPageState extends State<FirestoreTestPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> _addUser() async {
    await _db.collection("users").add({
      "name": "Ismot Ara",
      "email": "ismotaraprova@gmail.com",
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> _addSensor() async {
    await _db.collection("sensors").add({
      "type": "Flood",
      "location": "Dhaka",
      "status": "Active",
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> _addAlert() async {
    await _db.collection("alerts").add({
      "disaster": "Flood",
      "level": "High",
      "location": "Dhaka",
      "time": FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Firestore DB Test")),
      body: Column(
        children: [
          // Buttons to add test data
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _addUser,
                child: const Text("Add User"),
              ),
              ElevatedButton(
                onPressed: _addSensor,
                child: const Text("Add Sensor"),
              ),
              ElevatedButton(
                onPressed: _addAlert,
                child: const Text("Add Alert"),
              ),
            ],
          ),

          const Divider(),

          // Live alerts list
          const Text("Recent Alerts:", style: TextStyle(fontSize: 18)),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection("alerts")
                  .orderBy("time", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text("No alerts yet"));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final alert = docs[index].data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text("${alert["disaster"]} - ${alert["level"]}"),
                      subtitle: Text("Location: ${alert["location"]}"),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
