import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class DatabaseTestPage extends StatefulWidget {
  const DatabaseTestPage({super.key});

  @override
  State<DatabaseTestPage> createState() => _DatabaseTestPageState();
}

class _DatabaseTestPageState extends State<DatabaseTestPage> {
  final FirestoreService _fs = FirestoreService();

  // controllers for user
  final TextEditingController _userNameCtrl = TextEditingController();
  final TextEditingController _userEmailCtrl = TextEditingController();
  final TextEditingController _userLocationCtrl = TextEditingController();

  // controllers for sensor
  final TextEditingController _sensorTypeCtrl = TextEditingController();
  final TextEditingController _sensorLocationCtrl = TextEditingController();
  final TextEditingController _sensorReadingCtrl = TextEditingController();

  // controllers for alert
  final TextEditingController _alertTypeCtrl = TextEditingController(
    text: "Flood",
  );
  final TextEditingController _alertLevelCtrl = TextEditingController(
    text: "High",
  );
  final TextEditingController _alertLocationCtrl = TextEditingController();
  final TextEditingController _alertMessageCtrl = TextEditingController();

  bool _sending = false;

  @override
  void dispose() {
    _userNameCtrl.dispose();
    _userEmailCtrl.dispose();
    _userLocationCtrl.dispose();
    _sensorTypeCtrl.dispose();
    _sensorLocationCtrl.dispose();
    _sensorReadingCtrl.dispose();
    _alertTypeCtrl.dispose();
    _alertLevelCtrl.dispose();
    _alertLocationCtrl.dispose();
    _alertMessageCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String text, [Color? color]) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text), backgroundColor: color));
  }

  Future<void> _addUser() async {
    final name = _userNameCtrl.text.trim();
    final email = _userEmailCtrl.text.trim();
    final loc = _userLocationCtrl.text.trim();
    if (name.isEmpty || email.isEmpty) {
      _showSnack('Enter name and email', Colors.orange);
      return;
    }
    setState(() => _sending = true);
    try {
      await _fs.addUser(name: name, email: email, location: loc);
      _showSnack('User added ✅');
      _userNameCtrl.clear();
      _userEmailCtrl.clear();
      _userLocationCtrl.clear();
    } catch (e) {
      _showSnack('Failed: $e', Colors.red);
    } finally {
      setState(() => _sending = false);
    }
  }

  Future<void> _addSensor() async {
    final type = _sensorTypeCtrl.text.trim();
    final loc = _sensorLocationCtrl.text.trim();
    final readingText = _sensorReadingCtrl.text.trim();
    if (type.isEmpty || loc.isEmpty || readingText.isEmpty) {
      _showSnack('Please fill sensor fields', Colors.orange);
      return;
    }
    final reading = double.tryParse(readingText);
    if (reading == null) {
      _showSnack('Reading must be a number', Colors.orange);
      return;
    }
    setState(() => _sending = true);
    try {
      await _fs.addSensor(type: type, location: loc, lastReading: reading);
      _showSnack('Sensor added ✅');
      _sensorTypeCtrl.clear();
      _sensorLocationCtrl.clear();
      _sensorReadingCtrl.clear();
    } catch (e) {
      _showSnack('Failed: $e', Colors.red);
    } finally {
      setState(() => _sending = false);
    }
  }

  Future<void> _addAlert() async {
    final type = _alertTypeCtrl.text.trim();
    final level = _alertLevelCtrl.text.trim();
    final loc = _alertLocationCtrl.text.trim();
    final msg = _alertMessageCtrl.text.trim();
    if (type.isEmpty || level.isEmpty || loc.isEmpty || msg.isEmpty) {
      _showSnack('Fill alert fields', Colors.orange);
      return;
    }
    setState(() => _sending = true);
    try {
      await _fs.addAlert(type: type, level: level, location: loc, message: msg);
      _showSnack('Alert added ✅');
      _alertLocationCtrl.clear();
      _alertMessageCtrl.clear();
    } catch (e) {
      _showSnack('Failed: $e', Colors.red);
    } finally {
      setState(() => _sending = false);
    }
  }

  Widget _buildAddUserCard() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add User',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _userNameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _userEmailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _userLocationCtrl,
              decoration: const InputDecoration(labelText: 'Location (city)'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _sending ? null : _addUser,
              child: const Text('Add User'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddSensorCard() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add Sensor (simulated)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _sensorTypeCtrl,
              decoration: const InputDecoration(
                labelText: 'Sensor type (e.g., WaterLevel)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _sensorLocationCtrl,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _sensorReadingCtrl,
              decoration: const InputDecoration(labelText: 'Reading (number)'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _sending ? null : _addSensor,
              child: const Text('Add Sensor'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddAlertCard() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add Alert (manual)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _alertTypeCtrl,
              decoration: const InputDecoration(
                labelText: 'Type (Flood/Earthquake/etc)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _alertLevelCtrl,
              decoration: const InputDecoration(
                labelText: 'Level (Low/Medium/High/Critical)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _alertLocationCtrl,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _alertMessageCtrl,
              decoration: const InputDecoration(labelText: 'Message'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _sending ? null : _addAlert,
              child: const Text('Add Alert'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _fs.alertsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Stream error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No alerts yet.'));
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            final d = docs[i].data();
            final ts = docs[i].data()['timestamp'];
            String timeText = '';
            if (ts is Timestamp) {
              final dt = ts.toDate();
              timeText =
                  '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
            }
            return ListTile(
              leading: CircleAvatar(
                child: Text(d['level']?.toString().substring(0, 1) ?? '?'),
              ),
              title: Text(d['message'] ?? d['type'] ?? 'Alert'),
              subtitle: Text(
                '${d['type'] ?? ''} • ${d['location'] ?? ''}\n$timeText',
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firestore DB Test'),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildAddUserCard(),
            _buildAddSensorCard(),
            _buildAddAlertCard(),
            const SizedBox(height: 12),
            Card(
              margin: const EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recent Alerts',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _buildAlertsList(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
