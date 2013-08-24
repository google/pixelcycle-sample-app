library ui;

import 'dart:async' show StreamSubscription;
import 'dart:html';

import 'package:pixelcycle2/src/movie.dart' show WIDTH, HEIGHT, LARGE, ALL, Movie, Frame, Size;
import 'package:pixelcycle2/src/player.dart' show Player;

void onLoad(Player player) {

  for (CanvasElement elt in queryAll('canvas[class="playerview"]')) {
    var size = new Size(elt.attributes["data-size"]);
    new PlayerView(player, elt, size);
  }

  for (CanvasElement elt in queryAll('canvas[class="stripview"]')) {
    var size = new Size(elt.attributes["data-size"]);
    new StripView(player, elt, size);
  }
}

class PlayerView {
  final Player player;
  final CanvasElement elt;
  final Size size;
  Frame _frame;
  StreamSubscription _frameSub;
  Rect _damage;
  int _animSub;
  int colorIndex = 1;

  StreamSubscription _moveSub;

  PlayerView(this.player, this.elt, this.size) {
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
    frame = player.currentFrame;
    if (_damage != null) {
      _frame.render(elt.context2D, size, _damage);
      _damage = null;
    }
    if (player.playing) {
      renderAsync(null);
    }
  }

  set frame(Frame newFrame) {
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
  int _animSub;

  StreamSubscription moveSub;

  var touchId = null;
  StreamSubscription touchMoveSub;

  num lastTime;
  num lastY;

  StripView(this.player, this.elt, this.size) {
    elt.width = WIDTH + SPACER * 2;
    elt.height = HEIGHT * LARGE.pixelsize;
    elt.style.backgroundColor = "#000000";

    player.onChange.listen((e) {
      renderAsync();
    });

    elt.onMouseDown.listen((e) {
      e.preventDefault();
      player.playing = false;
      player.speed = 0;
      if (moveSub == null) {
        startDrag(e.client.y);
        moveSub = elt.onMouseMove.listen((e) => onDrag(e.client.y));
      }
    });

    elt.onMouseUp.listen((e) => stopDragging());
    elt.onMouseOut.listen((e) => stopDragging());
    query("body").onMouseUp.listen((e) => stopDragging());

    elt.onTouchStart.listen((TouchEvent e) {
      print("onTouchStart");
      e.preventDefault();
      if (touchId != null) {
        return; // ignore touches after the first
      }
      Touch t = e.changedTouches[0];
      player.playing = false;
      player.speed = 0;
      if (touchMoveSub == null) {
        touchId = t.identifier;
        startDrag(t.page.y);
        touchMoveSub = elt.onTouchMove.listen((e) {
          for (Touch t in e.changedTouches) {
            if (t.identifier == touchId) {
              onDrag(t.page.y);
            }
          }
        });
      }
    });

    elt.onTouchEnd.listen((TouchEvent e) {
      if (e.touches.isEmpty) {
        stopDragging();
      }
    });
  }

  void startDrag(num y) {
    lastTime = window.performance.now() / 1000.0;
    lastY = y;
  }

  void onDrag(num y) {
    num now = window.performance.now() / 1000.0;
    num deltaY = y - lastY;
    num deltaPos = -deltaY / height;
    num deltaT = now - lastTime;
    player.drag(deltaPos, deltaT);
    lastY = y;
    lastTime = now;
  }

  void stopDragging() {
    num now = window.performance.now() / 1000.0;
    if (lastTime != null && now - lastTime > 0.2) {
      player.speed = 0;
    }
    player.playing = true;
    if (moveSub != null) {
      moveSub.cancel();
      moveSub = null;
    }
    if (touchMoveSub != null) {
      touchMoveSub.cancel();
      touchMoveSub = null;
    }
    touchId = null;
    lastY = null;
    lastTime = null;
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
  }
}

