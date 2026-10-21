import 'package:flutter_dotenv/flutter_dotenv.dart';

// ignore: camel_case_types
class Config_URL {
  static String get baseUrl {
    final url = dotenv.env['BASE_URL'];
    if (url == null) {
      // ignore: avoid_print
      print("BASE_URL is not set in the .env file. Using default URL.");
      //đường dẫn API nếu không đọc được URL trong file .env
      return "http://10.0.2.2:5080";
    }
    return url;
  }
}
