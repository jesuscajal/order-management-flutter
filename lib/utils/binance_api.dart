import 'dart:convert';
import 'package:http/http.dart' as http;

Future<double?> fetchBTCUSDT() async {
  final url = Uri.parse(
    'https://api.binance.com/api/v3/ticker/price?symbol=USDTARS',
  );
  final response = await http.get(url);
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return double.tryParse(data['price']);
  }
  return null;
}
