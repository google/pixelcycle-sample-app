library ui;

import 'dart:html';
import 'package:pixelcycle2/src/movie.dart' show WIDTH, HEIGHT, ALL, Movie, Frame, Size;
import 'package:pixelcycle2/src/player.dart' show Player;

void onLoad(Player player) {
  for (CanvasElement elt in queryAll('canvas[class="frameview"]')) {
    Size size = new Size(elt.attributes["data-size"]);
    var f = new FrameView(elt, size);
    f.setFrame(player.movie.frames[player.frame]);
    player.onFrameChange.forEach((frameIndex) {
      f.setFrame(player.movie.frames[frameIndex]);      
    });
  }
}

class FrameView {
  final CanvasElement elt;
  final Size size;

  Frame frame;
  Rect _damage = null;

  FrameView(this.elt, this.size) {
    elt.width = WIDTH * size.pixelsize;
    elt.height = HEIGHT * size.pixelsize;
  }
 
  void setFrame(Frame newFrame) {
    if (this.frame == newFrame) {
      return;
    }
    this.frame = newFrame;
    renderAsync(ALL);
  }
  
  void renderAsync(Rect clip) {
    if (_damage != null) {
      _damage = _damage.union(clip);
      return;
    }
    _damage = clip;
    window.requestAnimationFrame((t) {
      frame.render(elt.context2D, size, clip);
      _damage = null;
    });
  }
}