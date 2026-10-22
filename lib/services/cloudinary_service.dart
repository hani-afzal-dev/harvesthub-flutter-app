import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class CloudinaryUploadException implements Exception {
  final String message;
  CloudinaryUploadException(this.message);

  @override
  String toString() => message;
}

class CloudinaryService {
  String get _cloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  String get _uploadPreset => dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';

  static String optimizedUrl(String url, {int width = 800}) {
    const marker = '/image/upload/';
    final index = url.indexOf(marker);
    if (index < 0 || !url.contains('res.cloudinary.com')) return url;
    final start = index + marker.length;
    return '${url.substring(0, start)}w_$width,q_auto,f_webp/${url.substring(start)}';
  }

  Future<String> uploadImage(File imageFile) async {
    if (_cloudName.isEmpty || _uploadPreset.isEmpty) {
      throw CloudinaryUploadException('Image upload is not configured yet.');
    }

    final uri =
        Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final streamedResponse = await request.send().timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw CloudinaryUploadException(
              'Upload timed out. Check your connection and try again.'),
        );
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw CloudinaryUploadException(
          'Could not upload image right now. Please try again.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final url = body['secure_url'] as String?;
    if (url == null || url.isEmpty) {
      throw CloudinaryUploadException(
          'Upload finished but no image link was returned.');
    }
    return url;
  }
}
