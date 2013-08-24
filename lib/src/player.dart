library player;

import 'dart:html';
import 'dart:async' show Stream, EventSink, StreamController, Timer;
import 'package:pixelcycle2/src/movie.dart' show WIDTH, HEIGHT, ALL, Movie, Frame, Size;

// The time in seconds since the window.performance.now() Epoch.
num now() {
  return window.performance.now() / 1000;
}

/// The Player controls the position and speed at which the movie is playing.
class Player {
  final Movie movie;
  final StreamController<Player> _onChange = new StreamController<Player>.broadcast();

  // The time in seconds since the window.performance.now() epoch when the movie started playing, or null if not playing.
  num _startTime = null;

  // The position in the movie where it started playing, or will play.
  // This is a number between 0 (the first frame) and the length of the movie in frames.
  num _startPosition = 0;

  // The speed at which the movie is playing, or will play. May be negative to play backwards.
  num _speed = 0;

  Player(this.movie);

  Stream<Player> get onChange => _onChange.stream;

  bool get playing => _startTime != null;

  /// Set to true to play the movie the current velocity, or false to pause it.
  /// If the speed is 0 then the movie will remain stopped.
  set playing (bool newValue) {
    if (playing == newValue) {
      return;
    }
    if (newValue && _speed != 0) {
      _start();
    } else {
      _stop();
    }
    if (_onChange.hasListener) {
      _onChange.add(this);
    }
  }

  void _start() {
    _startTime = now();
  }

  void _stop() {
    _startPosition = positionAt(now());
    _startTime = null;
  }

  set speed(num newValue) {
    num t = now();
    _startPosition = positionAt(t);
    _speed = newValue;
    _startTime = playing ? t : null;
    if (_speed == 0) {
      playing = false;
    }
  }

  /// Modifies movie's starting position and speed based on a drag. Also pauses the player.
  /// The position will have deltaPos added to it and the speed will be set to deltaPos / deltaT.
  void drag(num deltaPos, num deltaT) {
    if (deltaT == 0) {
      return;
    }
    if (playing) {
      _stop();
    }
    _startPosition = (_startPosition + deltaPos) % movie.frames.length;
    _speed = deltaPos / deltaT;
    if (_onChange.hasListener) {
      _onChange.add(this);
    }
  }

  /// Returns the movie's position at the given time, assuming it
  /// continues to play at the current speed.
  /// The time is in seconds since the window.performance.now() epoch.
  num positionAt(num time) {
    if (!playing) {
      return _startPosition;
    }
    return (_startPosition + (time - _startTime) * _speed) % movie.frames.length;
  }

  num get position => positionAt(now());

  /// Returns the frame to display at the given time.
  Frame frameAt(num time) => movie.frames[(positionAt(time) ~/ 1)];

  Frame get currentFrame => frameAt(now());
}
