import 'package:flutter/material.dart';

class TajweedRule {
  final Color color;
  final String label;

  const TajweedRule({required this.color, required this.label});
}

class TajweedParser {
  // Tajweed Metadata from AlQuran.cloud / GlobalQuran
  // Format: [h:1[text] or [n[text]

  // Tajweed Metadata from AlQuran.cloud / GlobalQuran
  // Mapping based on standard Tajweed rules visualization

  static final Map<String, TajweedRule> rules = {
    'h': TajweedRule(
      color: const Color(0xFFAAAAAA),
      label: 'Hamzah Wasal (Tidak Dibaca)',
    ),
    'sl': TajweedRule(
      color: const Color(0xFFAAAAAA),
      label: 'Huruf Diam / Tidak Dibaca',
    ),
    'n': TajweedRule(
      color: const Color(0xFF169278),
      label: 'Ghunnah (Dengung)',
    ),
    'm': TajweedRule(color: const Color(0xFF26BFFD), label: 'Iqlab (Membalik)'),
    'q': TajweedRule(
      color: const Color(0xFFFBB034),
      label: 'Qalqalah (Memantul)',
    ),
    'o': TajweedRule(
      color: const Color(0xFFFBB034),
      label: 'Qalqalah (Variasi)',
    ),
    'p': TajweedRule(
      color: const Color(0xFFFBB034),
      label: 'Qalqalah (Variasi)',
    ),
    'id': TajweedRule(
      color: const Color(0xFF169278),
      label: 'Idgham (Memasukkan)',
    ),
    'gh': TajweedRule(color: const Color(0xFF169278), label: 'Ghunnah'),
    'l': TajweedRule(
      color: const Color(0xFFAAAAAA),
      label: 'Lam Syamsiah/Qamariah',
    ),
  };

  static Map<String, Color> get _colors =>
      rules.map((k, v) => MapEntry(k, v.color));

  // Main parser for [tag[content] format
  static List<TextSpan> parseToSpans(
    String text, {
    required double fontSize,
    required bool isDark,
  }) {
    List<TextSpan> spans = [];
    RegExp exp = RegExp(r'\[([a-z]+)(?::\d+)?\[([^\]]+)\]');

    // Split text by matches
    int lastMatchEnd = 0;

    for (final match in exp.allMatches(text)) {
      // Add preceding plain text
      if (match.start > lastMatchEnd) {
        String plain = text.substring(lastMatchEnd, match.start);
        // Clean up any stray brackets if format allows
        // plain = plain.replaceAll('[', '').replaceAll(']', '');
        if (plain.isNotEmpty) {
          spans.add(
            TextSpan(text: plain, style: _getStyle(null, fontSize, isDark)),
          );
        }
      }

      String tag = match.group(1) ?? '';
      String content = match.group(2) ?? '';

      spans.add(
        TextSpan(text: content, style: _getStyle(tag, fontSize, isDark)),
      );

      lastMatchEnd = match.end;
    }

    // Remaining text
    if (lastMatchEnd < text.length) {
      String plain = text.substring(lastMatchEnd);
      if (plain.isNotEmpty) {
        spans.add(
          TextSpan(text: plain, style: _getStyle(null, fontSize, isDark)),
        );
      }
    }

    return spans;
  }

  static TextStyle _getStyle(String? tag, double fontSize, bool isDark) {
    Color baseColor = isDark ? Colors.white : Colors.black;
    if (tag == null) return TextStyle(fontSize: fontSize, color: baseColor);

    return TextStyle(fontSize: fontSize, color: _colors[tag] ?? baseColor);
  }
}
