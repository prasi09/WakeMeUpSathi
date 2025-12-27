class AppSettings {
  double alertDistance; // in meters
  String alarmSound;
  bool vibration;

  AppSettings({
    required this.alertDistance,
    required this.alarmSound,
    required this.vibration,
  });

  factory AppSettings.defaultSettings() {
    return AppSettings(
      alertDistance: 500,
      alarmSound: 'alarm1',
      vibration: true,
    );
  }
}
