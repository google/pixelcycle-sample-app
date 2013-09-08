library editor;

import 'dart:async' show Stream, StreamController;

import 'package:pixelcycle/src/movie.dart' show WIDTH, HEIGHT, LARGE, ALL, Movie, Frame, PixelChange;

/// An Editor performs edits and remembers undo history.
class Editor {
  final List<Stroke> strokes = new List<Stroke>();
  final StreamController<bool> _canUndoChanged = new StreamController<bool>();
  bool _canUndo;
  bool saved = true;
  Stroke current;

  Stream<bool> get canUndoChanged => _canUndoChanged.stream;

  void set(Frame frame, int x, int y, int colorIndex) {
    if (current == null) {
      current = new Stroke();
      strokes.add(current);
    }
    var change = frame.set(x, y, colorIndex);
    if (change == null) {
      return;
    }
    current.pixels.add(change);
    canUndo = true;
    saved = false;
  }

  void endStroke() {
    current = null;
  }

  void undo() {
    strokes.removeLast().undo();
    if (strokes.isEmpty) {
      canUndo = false;
      saved = true;
    }
  }

  bool get canUndo => _canUndo;

  void set canUndo(bool newValue) {
    if (_canUndo == newValue) {
      return;
    }
    _canUndo = newValue;
    if (_canUndoChanged.hasListener) {
      _canUndoChanged.add(newValue);
    }
  }
}

class Stroke {
  List<PixelChange> pixels = new List<PixelChange>();

  void undo() {
    for (var change in pixels.reversed) {
      change.undo();
    }
  }
}
