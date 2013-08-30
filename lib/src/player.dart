library player;

import 'dart:html';
import 'dart:async' show Stream, StreamController, StreamSubscription;
import 'dart:json' as json;

import 'package:pixelcycle2/src/movie.dart' show WIDTH, HEIGHT, ALL, Movie, Frame, Size;

/// A Player contains the position and speed at which the movie is playing.
/// A position is represented as float between 0 up to (and not including) the number of frames in the movie.
/// The first frame is shown for positions 0 to 1, the second, from 1 to 2, and so on.
/// Time is in seconds since the zero time used by window.performance.now(), which is typically the page load.
/// Speeds are in frames per second.
class Player {
  final Movie movie;
  final StreamController<Player> _onChange = new StreamController<Player>.broadcast();

  // The time when the movie started playing, or null if it's not playing.
  num _startTime = null;

  // The position where the movie started playing, or will play if it's not playing.
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

  num get speed => _speed;

  set speed(num newValue) {
    if (playing) {
      num t = now();
      _startPosition = positionAt(t);
      _startTime = t;
    }
    _speed = newValue;
    if (_speed == 0) {
      playing = false;
    }
  }

  /// Stops playing and adds the given delta to the position.
  void drag(num deltaPos) {
    if (playing) {
      _stop();
    }
    _startPosition = (_startPosition + deltaPos) % movie.frames.length;
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
    num pos = (_startPosition + (time - _startTime) * _speed) % movie.frames.length;

    // If we're going too fast to animate transitions between frames, always use
    // the halfway point between frame changes.
    if (_speed.abs() >= 15) {
      return (pos ~/ 1) + 0.5;
    }

    return pos;
  }

  num get position => positionAt(now());

  /// Returns the frame to display at the given time.
  Frame frameAt(num time) => movie[(positionAt(time) ~/ 1)];

  Frame get currentFrame => frameAt(now());

  FrameStack get frameStack {
    num pos = positionAt(now());
    int current = pos ~/ 1;
    num fraction = pos - current;

    int other = (fraction < 0.5 ? (current - 1) : (current + 1)) % movie.length;
    num edgeDist = 0.5 - (fraction - 0.5).abs();
    num backBrightness = (0.9 - edgeDist * 2).clamp(0, 1);
    num frontAlpha = (0.7 + edgeDist).clamp(0, 1);
    return new FrameStack(movie[other], backBrightness, movie[current], frontAlpha);
  }

  /// Serializes the state of the player.
  String serialize() {
    return json.stringify({
      'Version': 1,
      'Speed': speed,
      'Width': WIDTH,
      'Height': HEIGHT,
      'Frames': movie.frames.map((f) => json.stringify(f.pixels)).toList(growable: false),
    });
  }
}

class FrameStack {
  final Frame back;
  final num backBrightness;
  final Frame front;
  final num frontAlpha;

  FrameStack(this.back, this.backBrightness, this.front, this.frontAlpha);

  bool operator==(FrameStack other) {
    return back==other.back && front==other.front && backBrightness == other.backBrightness && frontAlpha == other.frontAlpha;
  }

  int get hashCode {
    return front.hashCode ^ back.hashCode ^ backBrightness.hashCode;
  }
}

/// The state of an in-progress drag that will change how fast the movie plays.
/// The position is measured in frames and time in seconds.
class PlayDrag {
  final Player player;
  final StreamSubscription moveSub;
  final touchId;
  final List<num> times = new List<num>();
  final List<num> positions = new List<num>();
  num lastSpeed;

  PlayDrag.start(this.player, this.moveSub, num pos, {this.touchId}) {
    player.playing = false;
    player.speed = 0;
    times.add(now());
    positions.add(pos);
    lastSpeed = 0;
  }

  void update(num pos) {
    num time = now();

    // Update position (negative because dragging forward causes the movie to play backwards).
    player.drag(-(pos - positions.last));

    // try to find a sample about .1 seconds ago, for a better speed estimate
    num maxAge = .1;
    var lastTime = times.last;
    var lastPos = positions.last;
    for (int i = times.length - 2; i >= 0; i--) {
      if ((time - times[i]) < maxAge) {
        lastTime = times[i];
        lastPos = positions[i];
      }
    }

    num deltaT = time - lastTime;
    num deltaPos = -(pos - lastPos); // negate for dragging
    lastSpeed = _chooseSpeed(deltaPos, deltaT);

    positions.add(pos);
    times.add(time);
  }

  void finish() {
    num time = now();
    if (time - times.last > 0.2) {
      // No recent drag events; assume stopped.
      player.speed = 0;
    } else {
      player.speed = lastSpeed;
    }
    player.playing = true;
    moveSub.cancel();
  }

  num _chooseSpeed(num deltaPos, num deltaT) {
    if (deltaT == 0) {
      return lastSpeed;
    }

    num speed = deltaPos / deltaT;

    // Clamp to some common speeds for fast animation.
    num sign = speed.isNegative ? -1 : 1;
    num mag = speed.abs();
    if (mag > 40) {
      return sign * 60;
    } else if (mag > 21) {
      return sign * 30;
    } else if (mag >= 16) {
      return sign * 20;
    } else if (mag >= 13) {
      return sign * 15;
    }

    // Make it easier to stop.
    if (mag < 0.5) {
      return 0;
    }

    return speed;
  }
}

// The time in seconds since the window.performance.now() starting time.
num now() {
  return window.performance.now() / 1000;
}
