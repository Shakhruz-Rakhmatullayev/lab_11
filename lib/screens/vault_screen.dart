import 'package:flutter/material.dart';

import '../models/note_item.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';

/// LW11 "Offline-First Notes & Settings Vault".
///
/// Everything on this screen is stored in SharedPreferences by [AppState]:
/// the dark-mode bool, the display name and the notes list (as JSON).
class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  late final AppState _state = AppScope.of(context);
  late final _name = TextEditingController(
    text: _state.displayName == kGuestName ? '' : _state.displayName,
  );
  final _note = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  void _saveName() {
    FocusScope.of(context).unfocus();
    _state.setDisplayName(_name.text);
    showToast(context, 'Saved name: ${_state.displayName}');
  }

  void _addNote() {
    if (_note.text.trim().isEmpty) return;
    _state.addNote(_note.text);
    _note.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Scaffold(
      backgroundColor: Palette.of(context).bgBottom,
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground()),
          SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                ScreenHeader(
                  title: 'Vault',
                  onBack: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 22),
                _Header(name: state.displayName, noteCount: state.notes.length),
                const SizedBox(height: 22),
                _Tile(
                  icon: state.isDarkMode
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  title: 'Dark mode',
                  trailing: Switch(
                    key: const Key('darkModeSwitch'),
                    value: state.isDarkMode,
                    onChanged: state.setDarkMode,
                    thumbColor: const WidgetStatePropertyAll(AppColors.ink),
                    trackColor: WidgetStateProperty.resolveWith(
                      (s) => s.contains(WidgetState.selected)
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.3),
                    ),
                    trackOutlineColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                const Text('Profile', style: AppText.section),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GlassTextField(
                        key: const Key('nameField'),
                        controller: _name,
                        hint: 'Your username',
                        onSubmitted: (_) => _saveName(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _PillButton(label: 'Save', onTap: _saveName),
                  ],
                ),
                const SizedBox(height: 26),
                const Text('Notes', style: AppText.section),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GlassTextField(
                        key: const Key('noteField'),
                        controller: _note,
                        hint: 'New note…',
                        onSubmitted: (_) => _addNote(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GlassCircleButton(
                      key: const Key('addNote'),
                      icon: Icons.add_rounded,
                      onTap: _addNote,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (state.notes.isEmpty)
                  const _EmptyNotes()
                else
                  for (final note in state.notes)
                    Padding(
                      key: ValueKey(note.id),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _NoteRow(
                        note: note,
                        onToggle: () => state.toggleNote(note),
                        onDelete: () => state.deleteNote(note),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.noteCount});

  final String name;
  final int noteCount;

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 32,
      opacity: 0.2,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Avatar(name: name, size: 60),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$noteCount ${noteCount == 1 ? 'note' : 'notes'} saved offline',
                  style: AppText.caption.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 24,
      opacity: 0.2,
      padding: const EdgeInsets.fromLTRB(10, 4, 12, 4),
      child: Row(
        children: [
          _IconCircle(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _IconCircle extends StatelessWidget {
  const _IconCircle({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.1),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({
    required this.note,
    required this.onToggle,
    required this.onDelete,
  });

  final NoteItem note;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final done = note.isCompleted;
    return Glass(
      radius: 22,
      opacity: done ? 0.1 : 0.2,
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      child: Row(
        children: [
          Checkbox(
            value: done,
            onChanged: (_) => onToggle(),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            side: const BorderSide(color: Colors.white, width: 1.5),
            fillColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected)
                  ? Colors.white
                  : Colors.transparent,
            ),
            checkColor: AppColors.ink,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.white,
                    color: Colors.white.withValues(alpha: done ? 0.6 : 1),
                  ),
                ),
                const SizedBox(height: 2),
                Text(note.dateText, style: AppText.caption),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete note',
            onPressed: onDelete,
            icon: Icon(
              Icons.delete_outline_rounded,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNotes extends StatelessWidget {
  const _EmptyNotes();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(
            Icons.sticky_note_2_outlined,
            size: 40,
            color: Colors.white.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 8),
          Text(
            'No notes yet. They stay here even after the app is closed.',
            textAlign: TextAlign.center,
            style: AppText.caption.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}
