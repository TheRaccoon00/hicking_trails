import 'package:flutter/material.dart';

class WeatherDay {
  final double avgTemp;
  final int weatherCode;
  final String date;

  WeatherDay(this.avgTemp, this.weatherCode, this.date);

  IconData get icon {
    if (weatherCode == 0 || weatherCode == 1) return Icons.wb_sunny;
    if (weatherCode == 2 || weatherCode == 3 || weatherCode == 45 || weatherCode == 48) return Icons.cloud;
    if (weatherCode >= 51 && weatherCode <= 67) return Icons.water_drop;
    if (weatherCode >= 71 && weatherCode <= 77) return Icons.ac_unit;
    if (weatherCode >= 80 && weatherCode <= 82) return Icons.water_drop;
    if (weatherCode >= 85 && weatherCode <= 86) return Icons.ac_unit;
    if (weatherCode >= 95) return Icons.flash_on;
    return Icons.cloud;
  }

  Color get color {
    if (weatherCode == 0 || weatherCode == 1) return Colors.orange;
    if (weatherCode == 2 || weatherCode == 3 || weatherCode == 45 || weatherCode == 48) return Colors.grey;
    if (weatherCode >= 51 && weatherCode <= 67) return Colors.blue;
    if (weatherCode >= 71 && weatherCode <= 77) return Colors.blue[200]!;
    if (weatherCode >= 80 && weatherCode <= 82) return Colors.blue;
    if (weatherCode >= 85 && weatherCode <= 86) return Colors.blue[200]!;
    if (weatherCode >= 95) return Colors.deepPurple;
    return Colors.grey;
  }
}
