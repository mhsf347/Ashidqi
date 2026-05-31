import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final query = """
      [out:json];
      (
        node["amenity"="place_of_worship"]["religion"="muslim"](around:5000, -6.175392, 106.827153);
      );
      out center;
  """;

  try {
    final response = await http.post(
      Uri.parse('https://overpass-api.de/api/interpreter'),
      headers: {'User-Agent': 'AshidqiApp/1.0'},
      body: query,
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final elements = data['elements'] as List;
      print('Found \${elements.length} mosques.');
      if (elements.isNotEmpty) {
        print(elements[0]);
      }
    } else {
      print('Error: \${response.statusCode} - \${response.body}');
    }
  } catch (e) {
    print('Exception: \$e');
  }
}
