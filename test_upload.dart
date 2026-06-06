import 'package:http/http.dart' as http;
void main() async {
  final uri = Uri.parse('http://localhost:3000/medical-records/upload');
  final request = http.MultipartRequest('POST', uri);
  request.headers['x-user-id'] = 'patient123';
  request.headers['x-user-role'] = 'patient';
  request.fields['patient_id'] = 'patient123';
  request.fields['title'] = 'Test';
  request.fields['notes'] = 'ملاحظات باللغة العربية';
  request.files.add(http.MultipartFile.fromBytes('file', [1, 2, 3], filename: 'test.pdf'));
  try {
    final response = await request.send();
    print('Status: ${response.statusCode}');
    print(await response.stream.bytesToString());
  } catch (e) {
    print('Error: $e');
  }
}
