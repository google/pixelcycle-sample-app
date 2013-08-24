library movie;

import 'dart:html' show CanvasElement, CanvasRenderingContext2D, Rect;
import 'dart:async' show Stream, StreamController;
import 'package:pixelcycle2/src/palette.dart' show Palette;

const int WIDTH = 60;
const int HEIGHT = 36;
const Rect ALL = const Rect(0, 0, WIDTH, HEIGHT);

class Size {
  static final List<Size> all = [SMALL, LARGE];

  final String name;
  final int index;
  final int pixelsize;
  const Size._internal(this.name, this.index, this.pixelsize);

  factory Size(String name) => all.firstWhere((s) => s.name == name);

  Rect gridToViewCoords(Rect r) {
    return new Rect(r.left * pixelsize, r.top * pixelsize, r.width * pixelsize, r.height * pixelsize);
  }
}

const SMALL = const Size._internal("small", 0, 1);
const LARGE = const Size._internal("large", 1, 14);

class Movie {
  final Palette palette;
  final List<Frame> frames = new List<Frame>();

  Movie(this.palette);

  factory Movie.blank(Palette palette, int frameCount) {
    Movie m = new Movie(palette);
    for (int i = 0; i < frameCount; i++) {
      m.frames.add(new Frame(palette));
    }
    return m;
  }

  factory Movie.dazzle(Palette palette) {
    Movie m = new Movie(palette);
    for (int findex = 0; findex < palette.colors.length; findex++) {
      var f = new Frame(palette);
      for (int y = 0; y < HEIGHT; y++) {
        for (int x = 0; x < WIDTH; x++) {
          f.set(x, y, (x + y + findex) % palette.colors.length);
        }
      }
      m.frames.add(f);
    }
    return m;
  }

  factory Movie.wiper(Palette palette) {
    Movie m = new Movie(palette);
    var frameCount = 16;
    for (int findex = 0; findex < frameCount; findex++) {
      var f = new Frame(palette);
      for (int y = 0; y < HEIGHT; y++) {
        for (int x = findex; x < WIDTH; x += frameCount) {
          f.set(x, y, 5);
        }
      }
      m.frames.add(f);
    }
    return m;
  }
}

class Frame {
  final Palette palette;
  final List<CanvasElement> bufs = Size.all.map((s) => new CanvasElement()).toList();
  final StreamController<Rect> _onChange = new StreamController<Rect>.broadcast();

  Frame(this.palette) {
    for (var s in Size.all) {
      var elt = bufs[s.index];
      elt.width = WIDTH * s.pixelsize;
      elt.height = HEIGHT * s.pixelsize;
    }
    clear(0);
  }

  get onChange => _onChange.stream;

  void clear(int colorIndex) {
    for (var s in Size.all) {
      var c = bufs[s.index].context2D;
      c.fillStyle = palette[colorIndex];
      c.fillRect(0, 0, WIDTH * s.pixelsize, HEIGHT * s.pixelsize);
    }
    if (_onChange.hasListener) {
      _onChange.add(ALL);
    }
  }

  void set(int x, int y, int colorIndex) {
    for (var s in Size.all) {
      var c = bufs[s.index].context2D;
      c.fillStyle = palette[colorIndex];
      c.fillRect(x * s.pixelsize, y * s.pixelsize, s.pixelsize, s.pixelsize);
    }
    if (_onChange.hasListener) {
      _onChange.add(new Rect(x, y, 1, 1));
    }
  }

  // Draws the pixels within clip to the given context.
  // (The clip is measured in grid coordinates.)
  void render(CanvasRenderingContext2D c, Size size, Rect clip) {
    Rect viewRect = size.gridToViewCoords(clip);
    c.drawImageToRect(bufs[size.index], viewRect, sourceRect: viewRect);
  }

  void renderAt(CanvasRenderingContext2D c, Size size, int x, int y) {
    c.drawImage(bufs[size.index], x, y);
  }
}
