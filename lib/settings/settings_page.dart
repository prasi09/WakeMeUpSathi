import 'package:flutter/material.dart';
import 'settings_model.dart';
import 'settings_storage.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {

  late AppSettings settings;
  bool loading = true;

  final List<double> distances = [300, 500, 1000];
  final List<String> sounds = ['alarm1', 'alarm2', 'alarm3'];

  @override
  void initState() {
    super.initState();
    load();
  }

  void load() async {
    settings = await SettingsStorage.loadSettings();
    setState(() => loading = false);
  }

  void save() async {
    await SettingsStorage.saveSettings(settings);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: save,
          ),
        ],
      ),
      body: ListView(
        children: [

          // 🔔 ALERT DISTANCE
          ListTile(
            title: const Text('Alert Distance'),
            subtitle: Text('${settings.alertDistance.toInt()} meters'),
            trailing: DropdownButton<double>(
              value: settings.alertDistance,
              items: distances.map((d) {
                return DropdownMenuItem(
                  value: d,
                  child: Text('${d.toInt()} m'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  settings.alertDistance = value!;
                });
              },
            ),
          ),

          const Divider(),

          // 🔊 ALARM SOUND
          ListTile(
            title: const Text('Alarm Sound'),
            trailing: DropdownButton<String>(
              value: settings.alarmSound,
              items: sounds.map((s) {
                return DropdownMenuItem(
                  value: s,
                  child: Text(s.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  settings.alarmSound = value!;
                });
              },
            ),
          ),

          const Divider(),

          // 📳 VIBRATION
          SwitchListTile(
            title: const Text('Vibration'),
            value: settings.vibration,
            onChanged: (value) {
              setState(() {
                settings.vibration = value;
              });
            },
          ),
        ],
      ),
    );
  }
}
