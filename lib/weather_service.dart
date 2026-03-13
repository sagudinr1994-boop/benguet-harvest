import 'dart:convert';
import 'package:http/http.dart' as http;
import 'env.dart';

class WeatherService {
  static Future<Map<String, dynamic>?> fetchBaguio() async {
    if (Env.weatherKey == 'YOUR_OPENWEATHERMAP_API_KEY') return null;
    try {
      final uri = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather'
        '?q=Baguio+City,PH&appid=${Env.weatherKey}&units=metric',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return json.decode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  static String iconEmoji(String? main) {
    switch ((main ?? '').toLowerCase()) {
      case 'thunderstorm':
        return '⛈️';
      case 'drizzle':
        return '🌦️';
      case 'rain':
        return '🌧️';
      case 'snow':
        return '❄️';
      case 'clear':
        return '☀️';
      case 'clouds':
        return '☁️';
      case 'mist':
      case 'fog':
      case 'haze':
        return '🌫️';
      default:
        return '🌤️';
    }
  }
}
