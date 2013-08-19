library player;

import 'dart:html';
import 'dart:async' show Stream, EventSink, StreamController, Timer;
import 'package:pixelcycle2/src/movie.dart' show WIDTH, HEIGHT, ALL, Movie, Frame, Size;

/// The Player is in charge of playing the movie. It keeps the position and speed
/// that the movie plays and sends time change events to render the views while the
/// movie is playing.
class Player {
  final Movie movie;
  Stream<num> onTimeChange;
  EventSink<num> _onTimeChangeSink;

  num _position = 0;
  num velocity = 0;
  num _time = 0;

  bool _playing = false;
  int _animateRequestId = 0;

  Player(this.movie) {
    var controller = new StreamController<num>();
    onTimeChange = controller.stream.asBroadcastStream();
    _onTimeChangeSink = controller.sink;
  }

  /// Sets the movie's position and velocity based on a drag.
  /// This also pauses the movie and redraws it.
  void drag(num deltaPos, num deltaT) {
    if (deltaT == 0) {
      return;
    }
    _position = (_position + deltaPos) % movie.frames.length;
    velocity = deltaPos / deltaT;
    _time = window.performance.now() / 1000.0;
    _playing = false;
    renderAsync();
  }

  /// Sets the current simulation time in seconds since the start of window.performance.now()'s epoch.
  /// This updates the position in the movie (based on the current velocity) and renders the views
  /// at the new time. Normally the time is set from within requestAnimationFrame.
  set time (num newValue) {
    if (newValue == _time) {
      return;
    }
    _position = positionAt(newValue);
    _time = newValue;
    _onTimeChangeSink.add(newValue);
  }

  /// Returns what the movie's position will be at the given time, assuming it
  /// continues to play at the current velocity.
  num positionAt(num time) => (_position + (time - _time) * velocity) % movie.frames.length;

  /// Returns the current position within the movie.
  /// This is a floating point number from 0 (inclusive) to frames.length (exclusive).
  num get position => positionAt(_time);

  /// Returns the currently displayed movie frame.
  Frame get currentFrame => movie.frames[(position ~/ 1)];

  /// Set to true to play the movie the current velocity, or false to pause it.
  /// If velocity is zero, setting to play to true has no effect.
  set playing (bool newValue) {
    if (velocity == 0) {
      newValue = false;
    }
    if (_playing == newValue) {
      return;
    }
    if (!_playing) {
      _time = window.performance.now() / 1000;
    }
    _playing = newValue;
    if (_playing) {
      renderAsync();
    }
    if (!_playing && _animateRequestId != 0) {
      window.cancelAnimationFrame(_animateRequestId);
      _animateRequestId = 0;
    }
  }

  /// Requests the views to be redrawn.
  void renderAsync() {
    if (_animateRequestId == 0) {
      _animateRequestId = window.requestAnimationFrame(_animate);
    }
  }

  _animate(num tMillis) {
    time = tMillis / 1000;
    if (_playing) {
      _animateRequestId = window.requestAnimationFrame(_animate);
    } else {
      _animateRequestId = 0;
    }
  }
}
