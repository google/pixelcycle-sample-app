library movie;

import 'dart:html' show CanvasElement, CanvasRenderingContext2D, Rect, Point;
import 'dart:async' show Stream, StreamController;
import 'package:pixelcycle/src/palette.dart' show Palette;

const int WIDTH = 60;
const int HEIGHT = 36;
const int PIXELSIZE = 2;
const Rect ALL = const Rect(0, 0, WIDTH, HEIGHT);

class Movie {
  final Palette palette;
  final List<Frame> _frames = new List<Frame>();
  final StreamController<Frame> _onChange = new StreamController<Frame>.broadcast();

  Movie(this.palette);

  factory Movie.blank(Palette palette, int frameCount) {
    Movie m = new Movie(palette);
    for (int i = 0; i < frameCount; i++) {
      m.add(new Frame(palette));
    }
    return m;
  }

  Stream<Frame> get onChange => _onChange.stream;

  void add(Frame frame) {
    _frames.add(frame);
    frame.onChange.listen((e) {
      if (_onChange.hasListener) {
        _onChange.add(frame);
      }
    });
  }

  int get length => _frames.length;

  Frame operator[](int i) => _frames[i];

  Iterable<Frame> get frames => _frames.toList(growable: false);
}

class Frame {
  final Palette palette;
  final CanvasElement elt = new CanvasElement();
  final List<int> pixels = new List<int>(WIDTH * HEIGHT);
  final StreamController<Rect> _onChange = new StreamController<Rect>.broadcast();

  Frame(this.palette) {
    elt.width = WIDTH * PIXELSIZE;
    elt.height = HEIGHT * PIXELSIZE;
    clear(0);
  }

  factory Frame.fromPixels(Palette palette, List<int> pixels) {
    Frame f = new Frame(palette);
    assert(pixels.length == WIDTH * HEIGHT);
    for (int y = 0; y < HEIGHT; y++) {
      for (int x = 0; x < WIDTH; x++) {
        int p = pixels[x + y * WIDTH];
        assert (p >= 0 && p < palette.length);
        f.set(x, y, p);
      }
    }
    return f;
  }

  get onChange => _onChange.stream;

  void clear(int colorIndex) {
    pixels.fillRange(0, pixels.length, colorIndex);
    var c = elt.context2D;
    c.fillStyle = palette[colorIndex];
    c.fillRect(0, 0, WIDTH * PIXELSIZE, HEIGHT * PIXELSIZE);
    if (_onChange.hasListener) {
      _onChange.add(ALL);
    }
  }

  PixelChange set(int x, int y, int colorIndex) {
    var change = new PixelChange(this, x, y, colorIndex);
    if (change.before == change.after) {
      return null;
    }
    change.apply();
    return change;
  }

  // Draws the pixels within clip to the given context.
  // (The clip is measured in grid coordinates.)
  void render(CanvasRenderingContext2D c, Rect clip, num pixelsize) {
    Rect expanded = new Rect(clip.left - 0.5, clip.top - 0.5, clip.width + 1, clip.height + 1).intersection(ALL);
    c.drawImageToRect(elt, scaleRect(expanded, pixelsize), sourceRect: scaleRect(expanded, PIXELSIZE));
  }

  void renderAt(CanvasRenderingContext2D c, int x, int y, num pixelsize) {
    c.drawImageToRect(elt, new Rect(x, y, WIDTH * pixelsize, HEIGHT * pixelsize), sourceRect: scaleRect(ALL, PIXELSIZE));
  }
}

class PixelChange {
  final Frame frame;
  final int x;
  final int y;
  final int index;
  final int before;
  final int after;

  PixelChange.raw(this.frame, this.x, this.y, this.index, this.before, this.after);

  factory PixelChange(Frame frame, int x, int y, int colorIndex) {
    assert(x >= 0 && x < WIDTH && y >= 0 && y < HEIGHT);
    int index = x + y * WIDTH;
    return new PixelChange.raw(frame, x, y, index, frame.pixels[index], colorIndex);
  }

  void apply() {
    _paint(after);
  }

  void undo() {
    _paint(before);
  }

  void _paint(int colorIndex) {
    frame.pixels[index] = colorIndex;
    var c = frame.elt.context2D;
    c.fillStyle = frame.palette[colorIndex];
    c.fillRect(x * PIXELSIZE, y * PIXELSIZE, PIXELSIZE, PIXELSIZE);
    if (frame._onChange.hasListener) {
      frame._onChange.add(new Rect(x, y, 1, 1));
    }
  }
}

Rect scaleRect(Rect r, num pixelsize) {
  return new Rect(r.left * pixelsize, r.top * pixelsize, r.width * pixelsize, r.height * pixelsize);
}