import 'dart:math';

enum Note {
  c,
  cSharp,
  d,
  dSharp,
  e,
  f,
  fSharp,
  g,
  gSharp,
  a,
  aSharp,
  b,
}

extension NoteExtension on Note {
  String get symbol {
    switch (this) {
      case Note.c:
        return 'C';
      case Note.cSharp:
        return 'C#';
      case Note.d:
        return 'D';
      case Note.dSharp:
        return 'D#';
      case Note.e:
        return 'E';
      case Note.f:
        return 'F';
      case Note.fSharp:
        return 'F#';
      case Note.g:
        return 'G';
      case Note.gSharp:
        return 'G#';
      case Note.a:
        return 'A';
      case Note.aSharp:
        return 'A#';
      case Note.b:
        return 'B';
    }
  }

  Note get previous {
    final idx = index - 1;
    if (idx < 0) return Note.b;
    return Note.values[idx];
  }

  Note get next {
    final idx = index + 1;
    if (idx >= Note.values.length) return Note.c;
    return Note.values[idx];
  }
}

class NoteInfo {
  String get noteName => note.symbol;
  final Note note;
  final double tuningFork;
  String get fullNoteWithOctave => noteName + octave.toString();
  final int octave;
  double get targetFrequency => _computeFrequency(note, octave);
  final double actualFrequency;
  double get centsOffset =>
      1200 * log(actualFrequency / targetFrequency) / ln2;

  NoteInfo(this.octave,
      {required this.actualFrequency,
      this.tuningFork = 440.0,
      required Note kNote})
      : note = kNote;

  double _computeFrequency(Note note, int octave) {
    final midi = (octave + 1) * 12 + note.index;

    return tuningFork * pow(2, (midi - 69) / 12);
  }

  NoteInfo get previousSemitone {
    final prevNote = note.previous;
    final prevOctave = note == Note.c ? octave - 1 : octave;
    return NoteInfo.fromFrequency(
      _computeFrequency(prevNote, prevOctave),
      tuningFork: tuningFork,
    )!;
  }

  NoteInfo get nextSemitone {
    final nextNote = note.next;
    final nextOctave = note == Note.b ? octave + 1 : octave;
    return NoteInfo.fromFrequency(
      _computeFrequency(nextNote, nextOctave),
      tuningFork: tuningFork,
    )!;
  }

  static NoteInfo? fromFrequency(
    double frequency, {
    double tuningFork = 440.0,
  }) {
    if (frequency <= 0 || frequency.isNaN || frequency.isInfinite) {
      return null;
    }

    final double semitonesFromA4 = 12 * (log(frequency / tuningFork) / ln2);

    final int midi = (69 + semitonesFromA4).round();

    final int noteIndex = midi % 12;

    final int octave = (midi ~/ 12) - 1;

    return NoteInfo(
      octave,
      actualFrequency: frequency,
      tuningFork: tuningFork,
      kNote: Note.values[noteIndex],
    );
  }

  static NoteInfo noteFromString(String noteString,
      {double tuningFork = 440.0}) {
    final noteName = noteString.substring(0, noteString.length - 1);
    final octave = int.parse(noteString.substring(noteString.length - 1));

    Note note;
    switch (noteName) {
      case 'C':
        note = Note.c;
        break;
      case 'C#':
        note = Note.cSharp;
        break;
      case 'D':
        note = Note.d;
        break;
      case 'D#':
        note = Note.dSharp;
        break;
      case 'E':
        note = Note.e;
        break;
      case 'F':
        note = Note.f;
        break;
      case 'F#':
        note = Note.fSharp;
        break;
      case 'G':
        note = Note.g;
        break;
      case 'G#':
        note = Note.gSharp;
        break;
      case 'A':
        note = Note.a;
        break;
      case 'A#':
        note = Note.aSharp;
        break;
      case 'B':
        note = Note.b;
        break;
      default:
        note = Note.c;
    }

    final tempNoteInfo = NoteInfo(octave,
        actualFrequency: 440.0, tuningFork: tuningFork, kNote: note);
    final frequency = tempNoteInfo.targetFrequency;

    return NoteInfo(
      octave,
      actualFrequency: frequency,
      tuningFork: tuningFork,
      kNote: note,
    );
  }

  static List<NoteInfo> parseNotes(List<String> noteStrings,
      {double tuningFork = 440.0}) {
    return noteStrings
        .map((s) => noteFromString(s, tuningFork: tuningFork))
        .toList();
  }
}

