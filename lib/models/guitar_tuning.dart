import '../backend/note_helper.dart';

class GuitarTuning {
  final String name;
  final List<NoteInfo> strings;

  const GuitarTuning(this.name, this.strings);

  List<String> get notes => strings.map((n) => n.fullNoteWithOctave).toList();

  GuitarTuning withTuningFork(double tuningFork) {
    return GuitarTuning(
      name,
      strings
          .map((n) => NoteInfo.noteFromString(
        n.fullNoteWithOctave,
        tuningFork: tuningFork,
      ))
          .toList(),
    );
  }

  static GuitarTuning _build(String name, List<String> noteStrings) {
    return GuitarTuning(name, NoteInfo.parseNotes(noteStrings));
  }

  static final standard =
  _build('Standard (E)', ['E2', 'A2', 'D3', 'G3', 'B3', 'E4']);
  static final dropD = _build('Drop D', ['D2', 'A2', 'D3', 'G3', 'B3', 'E4']);
  static final dStandard =
  _build('D Standard', ['D2', 'G2', 'C3', 'F3', 'A3', 'D4']);
  static final dropC = _build('Drop C', ['C2', 'G2', 'C3', 'F3', 'A3', 'D4']);
  static final openG = _build('Open G', ['D2', 'G2', 'D3', 'G3', 'B3', 'D4']);
  static final openD =
  _build('Open D', ['D2', 'A2', 'D3', 'F#3', 'A3', 'D4']);
  static final halfStepDown = _build(
    'Half Step Down',
    ['E#2', 'A#2', 'D#3', 'G#3', 'B#3', 'E#4'],
  );
}

final List<GuitarTuning> kGuitarTunings = [
  GuitarTuning.standard,
  GuitarTuning.dropD,
  GuitarTuning.dStandard,
  GuitarTuning.dropC,
  GuitarTuning.openG,
  GuitarTuning.openD,
  GuitarTuning.halfStepDown,
];