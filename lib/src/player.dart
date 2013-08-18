library player;

import 'dart:html';
import 'dart:async' show Stream, EventSink, StreamController, Timer;
import 'package:pixelcycle2/src/movie.dart' show WIDTH, HEIGHT, ALL, Movie, Frame, Size;

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
    
  set time (num newValue) {
    if (newValue == _time) {
      return;
    }
    _position = positionAt(newValue);
    _time = newValue;
    _onTimeChangeSink.add(newValue);
  }
  
  num positionAt(num time) => (_position + (time - _time) * velocity) % movie.frames.length;
  
  num get position => positionAt(_time);

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
