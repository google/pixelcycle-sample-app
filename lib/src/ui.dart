library ui;

import 'dart:async' show StreamSubscription;
import 'dart:html';

import 'package:pixelcycle/src/editor.dart' show Editor;
import 'package:pixelcycle/src/movie.dart' show WIDTH, HEIGHT, LARGE, ALL, Movie, Frame;
import 'package:pixelcycle/src/palette.dart' show Palette, Brush;
import 'package:pixelcycle/src/player.dart' show Player, PlayDrag, FrameStack;
import 'package:pixelcycle/src/server.dart' as server;
import 'package:pixelcycle/src/util.dart' as util;

void updatePreviewStatus(util.Text status) {
  if (status.value != null) {
    List<HtmlElement> statusElts = querySelectorAll('.preview .status');
    for (HtmlElement elt in statusElts) {
      elt.text = status.value;
      elt.classes.remove("fade-hidden");
    }
  } else {
    List<HtmlElement> statusElts = querySelectorAll('.preview .status');
    for (HtmlElement elt in statusElts) {
      elt.classes.add("fade-hidden");
    }
  }
}

void hidePreview() {
  for (var elt in querySelectorAll(".preview")) {
    elt.classes.add("hidden");
  }
  for (var elt in querySelectorAll(".start-hidden")) {
    elt.classes.remove("start-hidden");
  }
}


void startEditor(Player player, Editor editor, Brush brush, util.Text status) {
  hidePreview();

  List<HtmlElement> statusElts = querySelectorAll('.status');
  status.onChange.listen((value) {
    for (HtmlElement elt in statusElts) {
      if (value == null) {
        elt.classes.add("fade-hidden");
      } else {
        elt.text = value;
        elt.classes.remove("fade-hidden");
        player.movie.onChange.first.then((e) => status.value = null);
      }
    }
  });

  player.movie.onChange.first.then((e) {
    for (ButtonElement elt in querySelectorAll('.save')) {
      elt.onClick.listen((e) => handleSave(player, editor, elt, status));
      elt.disabled = false;
    }
  });

  // speeds

  List<DivElement> speedElts = querySelectorAll(".speed-display");
  List<ButtonElement> reduceButtons = querySelectorAll(".reduce-speed");
  List<ButtonElement> increaseButtons = querySelectorAll(".increase-speed");
  player.onChange.listen((_) {
    String text;
    num speed = player.speed.abs();
    if (speed == 0) {
      text = "0 fps";
    } else if (speed < 10) {
      text = "${speed.toStringAsFixed(1)} fps";
    } else {
      text = "${speed.toStringAsPrecision(2)} fps";
    }
    for (DivElement elt in speedElts) {
      elt.text = text;
    }
    for (ButtonElement elt in reduceButtons) {
      elt.disabled = player.speed <= -60;
    }
    for (ButtonElement elt in increaseButtons) {
      elt.disabled = player.speed >= 60;
    }
  });

  for (ButtonElement elt in reduceButtons) {
    elt.onClick.listen((e) {
      e.preventDefault();
      player.reduceSpeed();
    });
  }

  for (ButtonElement elt in increaseButtons) {
    elt.onClick.listen((e) {
      e.preventDefault();
      player.increaseSpeed();
    });
  }

  var undoButtons = querySelectorAll('.undo');
  for (ButtonElement elt in undoButtons) {
    elt.onClick.listen((e) => editor.undo());
  }

  editor.canUndoChanged.listen((canUndo) {
    for (ButtonElement elt in undoButtons) {
      elt.disabled = !canUndo;
    }
  });

  window.onBeforeUnload.listen((BeforeUnloadEvent e) {
    if (!editor.saved) {
      e.returnValue = "You have unsaved edits.";
    }
  });

  for (CanvasElement elt in querySelectorAll('.strip')) {
    bool vertical = elt.attributes["data-vertical"] == "true";
    new StripView(player, elt, SMALL, vertical: vertical);
  }

  for (CanvasElement elt in querySelectorAll('.movie')) {
    new MovieView(player, editor, brush, elt);
  }

  for (TableElement elt in querySelectorAll('.palette')) {
    int width = brush.palette.length ~/ 4;
    if (elt.attributes.containsKey("data-width")) {
      width = int.parse(elt.attributes["data-width"]);
    }
    new PaletteView(brush, elt, width);
  }
}

void handleSave(Player player, Editor editor, ButtonElement elt, util.Text status) {
  elt.disabled = true;
  status.value = "Saving...";
  server.save(player).then((String url) {
    status.value = "Reloading...";
    window.sessionStorage["loadMessage"] = "Saved. You can share or bookmark this page now.";
     editor.saved = true;
    window.location.assign(url);
  }).catchError((e) {
    print("error: ${e}");
    status.value = "Unable to save";
  }).whenComplete(() {
    elt.disabled = false;
  });
}

int SPACER = 10;

/// A StripView shows a strip of movie frames with the current frame near the center.
class StripView {
  final Player player;
  final CanvasElement elt;
  final Size size;
  final bool vertical;
  int pixelsPerFrame;
  Frame _frame;
  StreamSubscription _frameSub;
  DateTime _redrawWanted;
  PlayDrag _drag;

  StripView(this.player, this.elt, this.size, {this.vertical: false}) {
    elt.style.backgroundColor = "#000000";
    var mouseFramePos;
    var touchFramePos;
    if (vertical) {
      elt.width = size.width + SPACER * 2;
      elt.height = elt.clientHeight;
      pixelsPerFrame = size.height + SPACER;
      mouseFramePos = (MouseEvent e) => e.client.y / pixelsPerFrame;
      touchFramePos = (Touch t) => t.page.y / pixelsPerFrame;
    } else {
      elt.width = elt.clientWidth < 1000 ? elt.clientWidth : 1000;
      elt.height = size.height + SPACER * 2;
      pixelsPerFrame = size.width + SPACER;
      mouseFramePos = (MouseEvent e) => e.client.x / pixelsPerFrame;
      touchFramePos = (Touch t) => t.page.x / pixelsPerFrame;
    }

    player.onChange.listen((e) {
      renderAsync();
    });

    elt.onMouseDown.listen((e) {
      e.preventDefault();
      if (_drag == null) {
        var moveSub = elt.onMouseMove.listen((e) => _drag.update(mouseFramePos(e)));
        _drag = new PlayDrag.start(player, moveSub, mouseFramePos(e));
      }
    });

    elt.onMouseUp.listen((e) => _finishDrag());
    elt.onMouseOut.listen((e) => _finishDrag());
    querySelector("body").onMouseUp.listen((e) => _finishDrag());

    elt.onTouchStart.listen((TouchEvent e) {
      e.preventDefault();
      if (_drag == null) {
        var moveSub = elt.onTouchMove.listen((e) {
          for (Touch t in e.changedTouches) {
            if (t.identifier == _drag.touchId) {
              _drag.update(touchFramePos(t));
            }
          }
        });
        Touch t = e.changedTouches[0];
        _drag = new PlayDrag.start(player, moveSub, touchFramePos(t), touchId: t.identifier);
      }
    });

    elt.onTouchEnd.listen((TouchEvent e) {
      if (e.touches.isEmpty) {
        _finishDrag();
      }
    });

    window.onResize.listen((e) {
      renderAsync(); // visibility may have changed
    });
  }

  int get center {
    if (vertical) {
      return elt.height ~/ 2;
    } else {
      return elt.width ~/ 2;
    }
  }

  void _finishDrag() {
    if (_drag != null) {
      _drag.finish();
      _drag = null;
    }
  }

  void renderAsync() {
    if (_redrawWanted == null && elt.clientWidth > 0) {
      window.requestAnimationFrame(_render);
      _redrawWanted = new DateTime.now();
    }
  }

  void _render(num millis) {
    _redrawWanted = null;

    num moviePosition = player.positionAt(millis/1000);
    int currentFrame = moviePosition ~/ 1;
    var movie = player.movie;

    // resize the canvas to match the wanted side (and also clear it)
    if (vertical && elt.clientHeight >= 200 && elt.clientHeight <= 2000) {
      elt.height = elt.clientHeight;
    } else if (!vertical && elt.clientWidth >= 200 && elt.clientWidth <= 2000) {
      elt.width = elt.clientWidth;
    } else {
      elt.width = elt.width; // Just clear
    }
    var c = elt.context2D;

    // movie position corresponding to the first displayed frame
    num startPos = (moviePosition - center / pixelsPerFrame) % movie.frames.length;

    int frame = startPos ~/ 1;
    // frame position in pixels from left or top.
    int framePos = ((frame - startPos) * pixelsPerFrame) ~/ 1 + SPACER ~/ 2;
    int endPos = vertical ? elt.height : elt.width;
    c.fillStyle = "#444444";
    while (framePos < endPos) {

      // Set the alpha based on the distance from the center. (Proportional to total size.)
      var frameCenter = framePos + (vertical ? size.height / 2 : size.width / 2);
      var alphaDist = (frameCenter - center).abs() / (center * 2);
      c.globalAlpha = 0.8 - alphaDist * alphaDist * 2;
      if (vertical) {
        movie.frames[frame].renderAt(c, SPACER, framePos, size.pixelsize);
      } else {
        movie.frames[frame].renderAt(c, framePos, SPACER, size.pixelsize);
      }

      alphaDist = (framePos - center).abs() / (center * 2);
      c.globalAlpha = 0.8 - alphaDist * alphaDist * 2;
      if (vertical) {
        c.fillRect(SPACER, framePos - SPACER, size.width, SPACER);
      } else {
        c.fillRect(framePos - SPACER, SPACER, SPACER, size.height);
      }


      frame = (frame + 1) % movie.frames.length;
      framePos += pixelsPerFrame;
    }

    // Draw a line indicating the current frame
    c.strokeStyle = "#FFF";
    c.globalAlpha = 1.0;
    if (vertical) {
      c.moveTo(0, center);
      c.lineTo(elt.width, center);
      c.stroke();
    } else {
      c.moveTo(center, 0);
      c.lineTo(center, elt.height);
      c.stroke();
    }

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
    _frameSub = _frame.onChange.listen((Rectangle r) => renderAsync());
  }
}

/// A MovieView shows the current frame of a movie (according to the player).
/// It renders whenever the frame changes (due to drawing) or the player's
/// current frame changes. It uses requestAnimationFrame to avoid drawing too
/// often.
class MovieView {
  final Player player;
  final Editor editor;
  final Brush brush;
  final CanvasElement elt;
  Size size;
  FrameStack _frame; // The most recently rendered frame (being watched) and the one behind it.
  StreamSubscription _frameSub;
  Rectangle _damage; // Area of the watched frame that needs re-rendering.
  DateTime _redrawWanted; // Non-null if a render was requested.
  var _onFrameChange = () {};

  StreamSubscription _moveSub;

  MovieView(this.player, this.editor, this.brush, this.elt) {
    _setSize(LARGE);

    player.onChange.listen((e) {
      renderAsync(ALL);
    });

    elt.onMouseDown.listen((e) {
      e.preventDefault();
      if (_frame == null) {
        return;
      }
      _mousePaint(e);
      _moveSub = elt.onMouseMove.listen(_mousePaint);
    });

    querySelector("body").onMouseUp.listen((e) => _stopMousePaint());
    elt.onMouseOut.listen((e) => _stopMousePaint());

    elt.onTouchStart.listen(_fingerPaint);
    elt.onTouchMove.listen(_fingerPaint);

    elt.onTouchEnd.listen((TouchEvent e) {
      if (e.touches.isEmpty) {
        _onFrameChange = () {};
        editor.endStroke();
      } else {
        _onFrameChange = () => _fingerPaint(e);
      }
    });

    window.onResize.listen((e) {
      renderAsync(ALL); // visibility may have changed
    });
  }

  void _mousePaint(MouseEvent e) {
    int x = (e.offset.x / size.pixelsize).toInt();
    int y = (e.offset.y / size.pixelsize).toInt();
    editor.set(_frame.front, x, y, brush.selection);
    // Repeat on each frame if the user is holding down the mouse button
    _onFrameChange = () => _mousePaint(e);
  }

  void _stopMousePaint() {
    if (_moveSub != null) {
      _moveSub.cancel();
    }
    _moveSub = null;
    _onFrameChange = () {};
    editor.endStroke();
  }

  void _fingerPaint(TouchEvent e) {
    e.preventDefault();
    for (Touch t in e.targetTouches) {
      int canvasX = t.page.x - elt.documentOffset.x;
      int canvasY = t.page.y - elt.documentOffset.y;
      int x = canvasX ~/ size.pixelsize;
      int y = canvasY ~/ size.pixelsize;
      editor.set(_frame.front, x, y, brush.selection);
    }
    // Repeat on each frame if the user is pressing the canvas
    _onFrameChange = () => _fingerPaint(e);
  }

  void renderAsync(Rectangle clip) {
    if (_damage == null) {
      _damage = clip;
    } else if (clip != null) {
      _damage = _damage.boundingBox(clip);
    }
    if (_redrawWanted == null && elt.clientWidth > 0) {
      window.requestAnimationFrame(_render);
      _redrawWanted = new DateTime.now();
    }
  }

  /// Render the player's currently watched frame if needed.
  void _render(t) {
    _redrawWanted = null;
    _resize();
    _watch(player.frameStack);
    if (_damage != null) {
      _renderBlended(_damage);
      _damage = null;
    }
    if (player.playing) {
      renderAsync(null);
    }
  }

  /// Sets the canvas size to match the element's width.
  _resize() {
    if (elt.clientWidth < 200 || elt.clientWidth > 2000) {
      return; // probably not displayed
    }
    num pixelsize = elt.clientWidth / WIDTH;
    if (size != null && pixelsize == size.pixelsize) {
      return;
    }
    _setSize(new Size(elt.clientWidth / WIDTH));
  }

  _setSize(Size newVal) {
    size = newVal;
    elt.width = size.width.toInt();
    elt.height = size.height.toInt();
    _damage = ALL;
  }

  /// Change the currently watched frame, updating the frame subscription if needed.
  void _watch(FrameStack newFrame) {
    if (_frame == newFrame) {
      return;
    }
    bool frameChanged = _frame == null || _frame.front != newFrame.front;
    if (frameChanged && _frameSub != null) {
      _frameSub.cancel();
    }
    _frame = newFrame;
    if (frameChanged) {
      _onFrameChange(); // Paint again on the new frame.
      _frameSub = _frame.front.onChange.listen(renderAsync);
    }
    _renderBlended(ALL);
    _damage = null;
  }

  void _renderBlended(Rectangle clip) {
    var c = elt.context2D;
    if (_frame.frontAlpha != 1) {
      c.fillStyle = "#000";
      c.fillRect(clip.left * size.pixelsize, clip.top * size.pixelsize, clip.width * size.pixelsize, clip.height * size.pixelsize);
      c.globalAlpha = _frame.backBrightness;
      _frame.back.render(c, clip, size.pixelsize);
      c.globalAlpha = _frame.frontAlpha;
    }
    _frame.front.render(c, clip, size.pixelsize);
    if (_frame.frontAlpha != 1) {
      c.globalAlpha = 1;
    }
  }
}

class PaletteView {
  final Brush brush;
  final TableElement elt;
  List<TableCellElement> cells;
  PaletteView(this.brush, this.elt, int width) {
    cells = new List<TableCellElement>(palette.length);
    _initTable(width);

    elt.onClick.listen((MouseEvent e) {
      Element t = e.target;
      var id = t.dataset["id"];
      if (id != null) {
        brush.selection = int.parse(id);
      }
    });

    brush.onChange.listen((index) {
      render();
    });
  }

  _initTable(int width) {
    var row = new TableRowElement();
    for (int i = 0; i < palette.length; i++) {
      if (row.children.length == width) {
        elt.append(row);
        row = new TableRowElement();
      }
      var td = new TableCellElement();
      td.classes.add("paletteCell");
      td.dataset["id"] = i.toString();
      td.style.backgroundColor = palette[i];
      td.style.outlineColor = palette[i];
      cells[i] = td;
      row.append(td);
      renderCell(i);
    }
    elt.append(row);
  }

  Palette get palette => brush.palette;

  void render() {
    for (int i = 0; i < palette.length; i++) {
      renderCell(i);
    }
  }

  void renderCell(int i) {
    var td = cells[i];
    if (i == brush.selection) {
      td.classes.add("paletteCellSelected");
    } else {
      td.classes.remove("paletteCellSelected");
    }
  }
}

class Size {
  final num pixelsize;
  const Size(this.pixelsize);
  num get width => WIDTH * pixelsize;
  num get height => HEIGHT * pixelsize;
}

const SMALL = const Size(2);
const LARGE = const Size(15);
