library player;

import 'dart:html';
import 'dart:async' show Stream, EventSink, StreamController, Timer;
import 'package:pixelcycle2/src/movie.dart' show WIDTH, HEIGHT, ALL, Movie, Frame, Size;

class Player {
  final Movie movie;
  Stream<num> onTimeChange;
  EventSink<num> _onTimeChangeSink;
  num velocity = 0;
  num _position = 0;
  num _time = 0;
  bool _playing = false;
  int animateRequestId = 0;
  
  Player(this.movie) {
    var controller = new StreamController<num>();
    onTimeChange = controller.stream.asBroadcastStream();
    _onTimeChangeSink = controller.sink;
  }

  num get time => _time;
  
  set time (num newValue) {
    if (newValue == _time) {
      return;
    }
    _position = positionAt(newValue);
    _time = newValue;
    _onTimeChangeSink.add(newValue);
  }
  
  num positionAt(num time) => (_position + (time - _time) * velocity) % movie.frames.length;
  
  set playing (bool newValue) {
    if (_playing == newValue) {
      return;
    }
    if (!_playing) {
      _time = window.performance.now() / 1000;
    }
    _playing = newValue;
    if (_playing && animateRequestId == 0) {
      animateRequestId = window.requestAnimationFrame(_animate);
    }
    if (!_playing && animateRequestId != 0) {
      print("cancelling");
      window.cancelAnimationFrame(animateRequestId);
    }
  }
  
  _animate(num tMillis) {
    time = tMillis / 1000;
    if (_playing) {
      animateRequestId = window.requestAnimationFrame(_animate);
    } else {
      animateRequestId = 0;
    }
  }
}
