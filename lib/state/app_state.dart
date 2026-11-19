import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/note_item.dart';
import '../utils/format.dart';

/// SharedPreferences keys for the LW11 Notes & Settings Vault.
const kDarkModeKey = 'app_theme_dark_mode';
const kDisplayNameKey = 'user_display_name';
const kNotesKey = 'notes_vault_items';
const kGuestName = 'Guest User';

class Habit {
  Habit({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    this.time = 'Morning',
    this.streak = 0,
    this.done = false,
  });

  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final String time;
  int streak;
  bool done;
}

class AppState extends ChangeNotifier {
  AppState({this._prefs}) {
    _loadSettings();
  }

  /// Persists settings across launches. Null in tests, where nothing is saved.
  final SharedPreferences? _prefs;

  String userName = 'Shakhruz Rakhmatullayev';
  String location = 'Almaty, Kazakhstan';
  int age = 20;
  int height = 173;
  int weight = 75;

  ThemeMode themeMode = ThemeMode.system;
  bool sound = true;
  bool notifications = true;
  String experience = 'Intermediate';
  TimeOfDay reminder = const TimeOfDay(hour: 8, minute: 0);
  final Set<String> cautionAreas = {'Lower back'};

  /// Name shown in the Vault header; [kGuestName] until the user saves one.
  String displayName = kGuestName;

  /// Notes Vault, newest first. Saved to disk as one JSON string.
  final List<NoteItem> notes = [];

  final List<Habit> habits = [
    Habit(
      id: 'water',
      title: 'Drink 2L water',
      icon: Icons.water_drop_rounded,
      color: const Color(0xFF5B7DB1),
      time: 'Anytime',
      streak: 12,
      done: true,
    ),
    Habit(
      id: 'meditate',
      title: 'Meditate 10 min',
      icon: Icons.self_improvement_rounded,
      color: const Color(0xFF3C8D7E),
      streak: 21,
      done: true,
    ),
    Habit(
      id: 'read',
      title: 'Read 20 pages',
      icon: Icons.menu_book_rounded,
      color: const Color(0xFF8A7A4E),
      time: 'Evening',
      streak: 6,
    ),
    Habit(
      id: 'run',
      title: 'Morning run',
      icon: Icons.directions_run_rounded,
      color: const Color(0xFFF0782A),
      streak: 9,
      done: true,
    ),
    Habit(
      id: 'journal',
      title: 'Journal',
      icon: Icons.edit_note_rounded,
      color: const Color(0xFFB4637A),
      time: 'Evening',
      streak: 3,
    ),
    Habit(
      id: 'sleep',
      title: 'Sleep by 11 pm',
      icon: Icons.bedtime_rounded,
      color: const Color(0xFF5E6A9E),
      time: 'Evening',
      streak: 4,
    ),
  ];

  void _loadSettings() {
    final p = _prefs;
    if (p == null) return;
    // The dark-mode bool wins; the older 'themeMode' string is only used
    // when the user picked "System" (which clears the bool).
    final dark = p.getBool(kDarkModeKey);
    if (dark != null) {
      themeMode = dark ? ThemeMode.dark : ThemeMode.light;
    } else {
      final mode = p.getString('themeMode');
      themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == mode,
        orElse: () => themeMode,
      );
    }
    displayName = p.getString(kDisplayNameKey) ?? kGuestName;
    notes
      ..clear()
      ..addAll(NoteItem.decodeList(p.getString(kNotesKey)));
    sound = p.getBool('sound') ?? sound;
    notifications = p.getBool('notifications') ?? notifications;
    experience = p.getString('experience') ?? experience;
    final minutes = p.getInt('reminder');
    if (minutes != null) {
      reminder = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    }
    final areas = p.getStringList('cautionAreas');
    if (areas != null) {
      cautionAreas
        ..clear()
        ..addAll(areas);
    }
  }

  String get firstName => userName.trim().split(' ').first;
  int get doneCount => habits.where((h) => h.done).length;
  int get bestStreak =>
      habits.fold(0, (best, h) => h.streak > best ? h.streak : best);

  void toggleHabit(Habit h) {
    h.done = !h.done;
    h.streak = (h.streak + (h.done ? 1 : -1)).clamp(0, 99999);
    notifyListeners();
  }

  void addHabit({
    required String title,
    required IconData icon,
    required Color color,
    required String time,
  }) {
    habits.add(
      Habit(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        icon: icon,
        color: color,
        time: time,
      ),
    );
    notifyListeners();
  }

  void removeHabit(Habit h) {
    habits.remove(h);
    notifyListeners();
  }

  void updateProfile({
    required String name,
    required String location,
    required int age,
    required int height,
    required int weight,
  }) {
    userName = name;
    this.location = location;
    this.age = age;
    this.height = height;
    this.weight = weight;
    notifyListeners();
  }

  bool get isDarkMode => themeMode == ThemeMode.dark;

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    _prefs?.setString('themeMode', mode.name);
    if (mode == ThemeMode.system) {
      _prefs?.remove(kDarkModeKey);
    } else {
      _prefs?.setBool(kDarkModeKey, mode == ThemeMode.dark);
    }
    notifyListeners();
  }

  void setDarkMode(bool dark) =>
      setThemeMode(dark ? ThemeMode.dark : ThemeMode.light);

  void setDisplayName(String name) {
    final trimmed = name.trim();
    displayName = trimmed.isEmpty ? kGuestName : trimmed;
    if (trimmed.isEmpty) {
      _prefs?.remove(kDisplayNameKey);
    } else {
      _prefs?.setString(kDisplayNameKey, trimmed);
    }
    notifyListeners();
  }

  // ---- Notes Vault: every change re-encodes the list and writes it. ----

  void _saveNotes() {
    _prefs?.setString(kNotesKey, NoteItem.encodeList(notes));
    notifyListeners();
  }

  void addNote(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
    notes.insert(
      0,
      NoteItem(
        id: now.microsecondsSinceEpoch.toString(),
        title: trimmed,
        dateText: '${formatLongDate(now)} · $time',
      ),
    );
    _saveNotes();
  }

  void toggleNote(NoteItem note) {
    note.isCompleted = !note.isCompleted;
    _saveNotes();
  }

  void deleteNote(NoteItem note) {
    notes.removeWhere((n) => n.id == note.id);
    _saveNotes();
  }

  void setSound(bool v) {
    sound = v;
    _prefs?.setBool('sound', v);
    notifyListeners();
  }

  void setNotifications(bool v) {
    notifications = v;
    _prefs?.setBool('notifications', v);
    notifyListeners();
  }

  void setExperience(String v) {
    experience = v;
    _prefs?.setString('experience', v);
    notifyListeners();
  }

  void setReminder(TimeOfDay t) {
    reminder = t;
    _prefs?.setInt('reminder', t.hour * 60 + t.minute);
    notifyListeners();
  }

  void toggleCaution(String area) {
    if (!cautionAreas.remove(area)) cautionAreas.add(area);
    _prefs?.setStringList('cautionAreas', cautionAreas.toList());
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    super.key,
    required AppState super.notifier,
    required super.child,
  });

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
