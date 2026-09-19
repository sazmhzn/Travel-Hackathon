import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:go_router/go_router.dart';

class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    if (await FlutterBluePlus.isSupported == false) return;

    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        _scanResults = results;
      });
    });

    setState(() {
      _isScanning = true;
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

    setState(() {
      _isScanning = false;
    });
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proximity Radar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
            tooltip: 'Profile',
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _scanResults.length,
        itemBuilder: (context, index) {
          final result = _scanResults[index];
          // Determine distance based on RSSI (very roughly)
          final rssi = result.rssi;
          Color indicatorColor = Colors.grey;
          if (rssi > -60) {
            indicatorColor = Colors.red; // Hot
          } else if (rssi > -80) {
            indicatorColor = Colors.orange; // Warm
          } else {
            indicatorColor = Colors.blue; // Cold
          }

          return ListTile(
            leading: Icon(Icons.bluetooth, color: indicatorColor),
            title: Text(result.device.advName.isNotEmpty ? result.device.advName : "Unknown Device"),
            subtitle: Text('RSSI: $rssi'),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isScanning ? null : _startScan,
        child: Icon(_isScanning ? Icons.stop : Icons.refresh),
      ),
    );
  }
}
