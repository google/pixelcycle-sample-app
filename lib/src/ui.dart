library ui;

import 'dart:async' show StreamSubscription;
import 'dart:html';

import 'package:pixelcycle2/src/movie.dart' show WIDTH, HEIGHT, LARGE, ALL, Movie, Frame, Size;
import 'package:pixelcycle2/src/player.dart' show Player, PlayDrag;

void onLoad(Player player) {

  for (CanvasElement elt in queryAll('canvas[class="movie"]')) {
    var size = new Size(elt.attributes["data-size"]);
    new MovieView(player, elt, size);
  }

  for (CanvasElement elt in queryAll('canvas[class="strip"]')) {
    var size = new Size(elt.attributes["data-size"]);
    new StripView(player, elt, size);
  }
}

class MovieView {
  final Player player;
  final CanvasElement elt;
  final Size size;
  Frame _frame;
  StreamSubscription _frameSub;
  Rect _damage;
  int _animSub;
  int colorIndex = 1;

  StreamSubscription _moveSub;

  MovieView(this.player, this.elt, this.size) {
    print("moviesize: ${size.pixelsize}");
    elt.width = WIDTH * size.pixelsize;
    elt.height = HEIGHT * size.pixelsize;

    player.onChange.listen((e) {
      renderAsync(ALL);
    });

    elt.onMouseDown.listen((e) {
      e.preventDefault();
      if (_frame == null) {
        return;
      }
      _paint(e);
      colorIndex = (colorIndex + 1) % 50;
      _moveSub = elt.onMouseMove.listen(_paint);
    });

    query("body").onMouseUp.listen((MouseEvent e) {
      if (_moveSub != null) {
        _moveSub.cancel();
      }
    });

    elt.onMouseOut.listen((MouseEvent e) {
      if (_moveSub != null) {
        _moveSub.cancel();
      }
    });
  }

  void _paint(MouseEvent e) {
    int x = (e.offset.x / size.pixelsize).toInt();
    int y = (e.offset.y / size.pixelsize).toInt();
    _frame.set(x, y, colorIndex);
  }

  void renderAsync(Rect clip) {
    if (_damage == null) {
      _damage = clip;
    } else if (clip != null) {
      _damage = _damage.union(clip);
    }
    if (_animSub == null) {
      _animSub = window.requestAnimationFrame(_render);
    }
  }

  void _render(t) {
    _animSub = null;
    watch(player.currentFrame);
    if (_damage != null) {
      _frame.render(elt.context2D, size, _damage);
      _damage = null;
    }
    if (player.playing) {
      renderAsync(null);
    }
  }

  void watch(Frame newFrame) {
    if (_frame == newFrame) {
      return;
    }
    _frame = newFrame;
    if (_frameSub != null) {
      _frameSub.cancel();
    }
    _frameSub = _frame.onChange.listen(renderAsync);
    _frame.render(elt.context2D, size, ALL);
    _damage = null;
  }
}

const SPACER = 10;

class StripView {
  final Player player;
  final CanvasElement elt;
  final Size size;
  final int height = HEIGHT + SPACER;
  Frame _frame;
  StreamSubscription _frameSub;
  int _animSub;
  PlayDrag _drag;


  StripView(this.player, this.elt, this.size) {
    elt.width = WIDTH + SPACER * 2;
    elt.height = HEIGHT * LARGE.pixelsize;
    elt.style.backgroundColor = "#000000";

    player.onChange.listen((e) {
      renderAsync();
    });

    elt.onMouseDown.listen((e) {
      e.preventDefault();
      if (_drag == null) {
        var moveSub = elt.onMouseMove.listen((e) => _drag.update(e.client.y / height));
        _drag = new PlayDrag.start(player, moveSub, e.client.y / height);
      }
    });

    elt.onMouseUp.listen((e) => _finishDrag());
    elt.onMouseOut.listen((e) => _finishDrag());
    query("body").onMouseUp.listen((e) => _finishDrag());

    elt.onTouchStart.listen((TouchEvent e) {
      print("onTouchStart");
      e.preventDefault();
      if (_drag == null) {
        var moveSub = elt.onTouchMove.listen((e) {
          for (Touch t in e.changedTouches) {
            if (t.identifier == _drag.touchId) {
              _drag.update(t.page.y / height);
            }
          }
        });
        Touch t = e.changedTouches[0];
        _drag = new PlayDrag.start(player, moveSub, t.page.y / height, touchId: t.identifier);
      }
    });

    elt.onTouchEnd.listen((TouchEvent e) {
      if (e.touches.isEmpty) {
        _finishDrag();
      }
    });
  }

  void _finishDrag() {
    if (_drag != null) {
      _drag.finish();
      _drag = null;
    }
  }

  void renderAsync() {
    if (_animSub == null) {
      _animSub = window.requestAnimationFrame(_render);
    }
  }

  void _render(num millis) {
    _animSub = null;
    num moviePosition = player.positionAt(millis/1000);
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

    if (player.playing) {
      renderAsync();
    }
    _watch(player.currentFrame);
  }

  void _watch(Frame newFrame) {
    if (_frame == newFrame) {
      return;
    }
    _frame = newFrame;
    if (_frameSub != null) {
      _frameSub.cancel();
    }
    _frameSub = _frame.onChange.listen((Rect r) => renderAsync());
  }
}
