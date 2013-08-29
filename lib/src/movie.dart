library movie;

import 'dart:html' show CanvasElement, CanvasRenderingContext2D, Rect, Point;
import 'dart:async' show Stream, StreamController;
import 'package:pixelcycle2/src/palette.dart' show Palette;

const int WIDTH = 60;
const int HEIGHT = 36;
const int PIXELSIZE = 2;
const Rect ALL = const Rect(0, 0, WIDTH, HEIGHT);

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

  void set(int x, int y, int colorIndex) {
    assert(x >= 0 && x < WIDTH && y >= 0 && y < HEIGHT);
    int index = x + y * WIDTH;
    if (pixels[index] == colorIndex) {
      return;
    }
    pixels[index] = colorIndex;
    var c = elt.context2D;
    c.fillStyle = palette[colorIndex];
    c.fillRect(x * PIXELSIZE, y * PIXELSIZE, PIXELSIZE, PIXELSIZE);
    if (_onChange.hasListener) {
      _onChange.add(new Rect(x, y, 1, 1));
    }
  }

  // Draws the pixels within clip to the given context.
  // (The clip is measured in grid coordinates.)
  void render(CanvasRenderingContext2D c, Rect clip, num pixelsize) {
    //Rect expanded = new Rect(clip.left - 0.5, clip.top - 0.5, clip.width + 1, clip.height + 1).intersection(ALL);
    c.drawImageToRect(elt, scaleRect(clip, pixelsize), sourceRect: scaleRect(clip, PIXELSIZE));
  }

  void renderAt(CanvasRenderingContext2D c, int x, int y, num pixelsize) {
    c.drawImageToRect(elt, new Rect(x, y, WIDTH * pixelsize, HEIGHT * pixelsize), sourceRect: scaleRect(ALL, PIXELSIZE));
  }
}

Rect scaleRect(Rect r, num pixelsize) {
  return new Rect(r.left * pixelsize, r.top * pixelsize, r.width * pixelsize, r.height * pixelsize);
}