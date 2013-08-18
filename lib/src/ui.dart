library ui;

import 'dart:html';
import 'package:pixelcycle2/src/movie.dart' show WIDTH, HEIGHT, ALL, Movie, Frame, Size;
import 'package:pixelcycle2/src/player.dart' show Player;

void onLoad(Player player) {
  Movie movie = player.movie;
  
  for (CanvasElement elt in queryAll('canvas[class="frameview"]')) {
    var size = new Size(elt.attributes["data-size"]);
    var f = new FrameView(elt, size, movie);
    player.onTimeChange.forEach((num time) {
      f.render(player.positionAt(time));      
    });
  }
  
  for (CanvasElement elt in queryAll('canvas[class="stripview"]')) {
    var size = new Size(elt.attributes["data-size"]);
    var strip = new StripView(elt, size, movie);    
    player.onTimeChange.forEach((num time) {
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
  final Movie movie;
  final int height = HEIGHT + SPACER;
  
  StripView(this.elt, this.size, this.movie) {
    var c = elt.context2D;
    c.fillStyle = "#000000";
    c.fillRect(0, 0, 2*SPACER + WIDTH, elt.height);    
  }
  
  void render(num moviePosition) {
    var c = elt.context2D;
    int frame = moviePosition ~/ 1;
    int frameY = ((frame - moviePosition) * height) ~/ 1;
    while (frameY < elt.height) {
      
      movie.frames[frame].renderAt(c, size, SPACER, frameY);
      c.fillStyle = "#000000";
      c.fillRect(0, frameY + HEIGHT, WIDTH + SPACER * 2, SPACER);
      
      frame = (frame + 1) % movie.frames.length;
      frameY += height;
    }
  }
}
