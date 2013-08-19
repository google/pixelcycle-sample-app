library ui;

import 'dart:async' show StreamSubscription;
import 'dart:html';
import 'dart:math';

import 'package:pixelcycle2/src/movie.dart' show WIDTH, HEIGHT, LARGE, ALL, Movie, Frame, Size;
import 'package:pixelcycle2/src/player.dart' show Player;

void onLoad(Player player) {
  Movie movie = player.movie;
  
  for (CanvasElement elt in queryAll('canvas[class="frameview"]')) {
    var size = new Size(elt.attributes["data-size"]);
    var f = new FrameView(elt, size, movie);
    player.onTimeChange.listen((num time) {
      f.render(player.positionAt(time));      
    });
  }
  
  for (CanvasElement elt in queryAll('canvas[class="stripview"]')) {
    var size = new Size(elt.attributes["data-size"]);
    var strip = new StripView(elt, size, player);    
    player.onTimeChange.listen((num time) {
      strip.render(player.positionAt(time));
    });
  }
}

class FrameView {
  final CanvasElement elt;
  final Size size;
  final Movie movie;

  FrameView(this.elt, this.size, this.movie) {
    elt.width = WIDTH * size.pixelsize;
    elt.height = HEIGHT * size.pixelsize;
  }
  
  void render(num moviePosition) { 
    var frame = movie.frames[moviePosition ~/ 1];      
    frame.render(elt.context2D, size, ALL);
  }
}

const SPACER = 10;

class StripView {
  final CanvasElement elt;
  final Size size;
  final Player player;
  final int height = HEIGHT + SPACER;
  
  StreamSubscription moveSub;
  num lastTime;
  num lastY;
  
  StripView(this.elt, this.size, this.player) {
    elt.width = WIDTH + SPACER * 2;
    elt.height = HEIGHT * LARGE.pixelsize;
    elt.style.backgroundColor = "#000000";
    
    elt.onMouseDown.listen((e) {
      e.preventDefault();
      player.playing = false;
      player.velocity = 0;
      if (moveSub == null) {
        lastTime = window.performance.now() / 1000.0;
        lastY = e.client.y;
        moveSub = elt.onMouseMove.listen(drag);
      }
    });
    
    elt.onMouseUp.listen((e) => stopDragging());   
    elt.onMouseOut.listen((e) => stopDragging());      
    query("body").onMouseUp.listen((e) => stopDragging());
  }

  void drag(MouseEvent e) {
    num now = window.performance.now() / 1000.0;
    num deltaY = e.client.y - lastY;
    num deltaPos = -deltaY / height;
    num deltaT = now - lastTime;
    player.drag(deltaPos, deltaT);
    lastTime = now;
    lastY = e.client.y;
  }
  
  void stopDragging() {
    player.playing = true;
    if (moveSub != null) {
      moveSub.cancel();
      moveSub = null;
    }    
  }
  
  void render(num moviePosition) {
    var movie = player.movie;
    elt.width = elt.width;
    var c = elt.context2D;

    int currentFrame = moviePosition ~/ 1;
    int currentFrameY = elt.height ~/ 2;
    
    num startPos = (moviePosition - currentFrameY / height) % movie.frames.length;
    int frame = startPos ~/ 1;
    int frameY = ((frame - startPos) * height) ~/ 1 + SPACER ~/ 2;
    while (frameY < elt.height) {
      var peakDist = (frameY - currentFrameY).abs() / elt.height;
      c.globalAlpha = 0.6 - peakDist / 2;
      movie.frames[frame].renderAt(c, size, SPACER, frameY);
      
      frame = (frame + 1) % movie.frames.length;
      frameY += height;
    }

    c.strokeStyle = "#FFF";
    c.globalAlpha = 1.0;
    c.moveTo(0, currentFrameY);
    c.lineTo(elt.width, currentFrameY);
    c.stroke();
  }
}
