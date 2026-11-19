import 'dart:convert';

/// One note in the offline Notes Vault.
///
/// The whole list is stored as a single JSON string in SharedPreferences,
/// so every field must round-trip through [toJson] / [NoteItem.fromJson].
class NoteItem {
  NoteItem({
    required this.id,
    required this.title,
    required this.dateText,
    this.isCompleted = false,
  });

  final String id;
  final String title;
  final String dateText;
  bool isCompleted;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'dateText': dateText,
    'isCompleted': isCompleted,
  };

  factory NoteItem.fromJson(Map<String, dynamic> json) => NoteItem(
    id: json['id'] as String,
    title: json['title'] as String,
    dateText: json['dateText'] as String? ?? '',
    isCompleted: json['isCompleted'] as bool? ?? false,
  );

  /// `List<NoteItem>` -> `List<Map>` -> one JSON string for disk.
  static String encodeList(List<NoteItem> notes) =>
      jsonEncode(notes.map((n) => n.toJson()).toList());

  /// JSON string from disk -> `List<dynamic>` -> typed `List<NoteItem>`.
  /// Returns an empty list if nothing was saved or the data is corrupt.
  static List<NoteItem> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => NoteItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on FormatException {
      return [];
    } on TypeError {
      return [];
    }
  }
}
