library player;

import 'dart:async' show Stream, EventSink, StreamController, Timer;
import 'package:pixelcycle2/src/movie.dart' show WIDTH, HEIGHT, ALL, Movie, Frame, Size;

class Player {
  final Movie movie;
  int frame = 0;
  Stream<int> onFrameChange;
  EventSink<int> _onFrameChangeSink;

  bool _playing = false;
  bool _reverse = false;
  int fps = 15;
  Stream<Player> onSettingChange;
  EventSink<Player> _onSettingChangeSink;
  Timer _ticker;
  
  Player(this.movie) {
    var controller = new StreamController<int>();
    onFrameChange = controller.stream.asBroadcastStream();
    _onFrameChangeSink = controller.sink;
    
    var controller2 = new StreamController<Player>();
    onSettingChange = controller2.stream.asBroadcastStream();
    _onSettingChangeSink = controller2.sink;    
  }
  
  void setFrame(int frameIndex) {
    this.frame = frameIndex;
    _onFrameChangeSink.add(frameIndex);
  }
  
  void setFramesPerSecond(int newValue) {
    if (fps == newValue) {
      return;
    }
    fps = newValue;
    _onSettingChangeSink.add(this);
  }
  
  bool get playing {
    return _playing;
  }
  
  void set playing(bool newValue) {
    if (_playing == newValue) {
      return;
    }
    _playing = newValue;
    _onSettingChangeSink.add(this);
    tick();
  }
  
  bool get reverse {
    return _reverse;
  }
  
  void set reverse(bool newValue) {
    if (_reverse == newValue) {
      return;
    }
    _reverse = newValue;
    _onSettingChangeSink.add(this);
  }
  
  void tick() {
    if (playing) {
      scheduleTick();
    }
    if (_reverse) {
      _step(-1);      
    } else {
      _step(1);
    }
  }
  
  void scheduleTick() {
    _cancelTick();
    int delay = (1000/fps).toInt();
    _ticker = new Timer(new Duration(milliseconds: delay), () {
      if (playing) {
        tick();  
      }
    });    
  }
  
  void _cancelTick() {
    if (_ticker != null) {
      _ticker.cancel();
      _ticker = null;
    }    
  }
  
  void step(int amount) {
    _step(amount);
    playing = false;
  }
  
  void _step(int amount) {
    int len = movie.frames.length;
    int next = (frame + amount + len) % len;
    setFrame(next);    
  }
}