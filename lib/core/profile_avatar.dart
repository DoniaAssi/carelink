import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// رابط صورة الملف من استجابة الـ API (يدعم اختلاف تسمية المفتاح).
String? profileImageUrlFromMap(Map<String, dynamic>? map) {
  if (map == null) return null;
  final v = map['profileImageUrl'] ?? map['profileimageurl'];
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// يزيل مسافات/أسطر قد تكسر فك base64 بعد التخزين في MySQL.
String _normalizeBase64Payload(String raw) {
  return raw.replaceAll(RegExp(r'\s'), '');
}

/// يعيد بايتات الصورة من `data:image/...;base64,...` أو null إذا الترميز غير صالح.
Uint8List? decodeDataUriImageBytes(String dataUri) {
  final u = dataUri.trim();
  if (!u.startsWith('data:image')) return null;
  final comma = u.indexOf(',');
  if (comma <= 0 || comma >= u.length - 1) return null;
  final payload = _normalizeBase64Payload(u.substring(comma + 1));
  if (payload.isEmpty) return null;
  try {
    final bytes = base64Decode(payload);
    if (bytes.isEmpty) return null;
    return bytes;
  } catch (_) {
    return null;
  }
}

ImageProvider? profileImageProvider(
  String? url, {
  Uint8List? localBytes,
}) {
  if (localBytes != null && localBytes.isNotEmpty) {
    return MemoryImage(localBytes);
  }
  final u = (url ?? '').trim();
  if (u.isEmpty) return null;
  if (u.startsWith('data:image')) {
    final bytes = decodeDataUriImageBytes(u);
    if (bytes == null) return null;
    return MemoryImage(bytes);
  }
  if (u.startsWith('http://') || u.startsWith('https://')) {
    return NetworkImage(u);
  }
  return null;
}

Widget _placeholderIcon({
  required IconData placeholderIcon,
  required Color placeholderColor,
  required double iconSize,
}) {
  return Icon(placeholderIcon, size: iconSize, color: placeholderColor);
}

/// Use inside [ClipOval] / [CircleAvatar].
Widget profileAvatarOrPlaceholder({
  required String? imageUrl,
  Uint8List? localBytes,
  required double size,
  required Color placeholderColor,
  required IconData placeholderIcon,
  double iconSize = 28,
}) {
  if (localBytes != null && localBytes.isNotEmpty) {
    return Image.memory(
      localBytes,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _placeholderIcon(
        placeholderIcon: placeholderIcon,
        placeholderColor: placeholderColor,
        iconSize: iconSize,
      ),
    );
  }
  final u = (imageUrl ?? '').trim();
  if (u.startsWith('data:image')) {
    final bytes = decodeDataUriImageBytes(u);
    if (bytes == null) {
      return _placeholderIcon(
        placeholderIcon: placeholderIcon,
        placeholderColor: placeholderColor,
        iconSize: iconSize,
      );
    }
    return Image.memory(
      bytes,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _placeholderIcon(
        placeholderIcon: placeholderIcon,
        placeholderColor: placeholderColor,
        iconSize: iconSize,
      ),
    );
  }
  if (u.startsWith('http://') || u.startsWith('https://')) {
    return Image.network(
      u,
      width: size,
      height: size,
      fit: BoxFit.cover,
      headers: const {'Accept': 'image/*'},
      errorBuilder: (context, error, stackTrace) => _placeholderIcon(
        placeholderIcon: placeholderIcon,
        placeholderColor: placeholderColor,
        iconSize: iconSize,
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Center(
          child: SizedBox(
            width: size * 0.35,
            height: size * 0.35,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: placeholderColor,
            ),
          ),
        );
      },
    );
  }
  return _placeholderIcon(
    placeholderIcon: placeholderIcon,
    placeholderColor: placeholderColor,
    iconSize: iconSize,
  );
}
