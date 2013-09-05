import 'dart:html';
import 'dart:async' show Future, Completer;

import 'package:pixelcycle2/src/editor.dart' show Editor;
import 'package:pixelcycle2/src/palette.dart' show Palette, Brush;
import 'package:pixelcycle2/src/movie.dart' show Movie, Frame, WIDTH, HEIGHT;
import 'package:pixelcycle2/src/player.dart' show Player;
import 'package:pixelcycle2/src/server.dart' as server;
import 'package:pixelcycle2/src/ui.dart' as ui;
import 'package:pixelcycle2/src/util.dart' as util;


RegExp gifPath = new RegExp(r"^/gif/(\d+)$");

void main() {
  print("main entered");

  String gif = query("#gif").attributes["src"];
  var match = gifPath.firstMatch(gif);
  if (match == null) {
    ui.hidePreview();
    startEditor(new Player.blank(), new util.Text());
    return;
  }
  var movieId = match.group(1);

  var status = new util.Text();
  if (window.sessionStorage["loadMessage"] != null) {
    status.value = window.sessionStorage["loadMessage"];
    window.sessionStorage.remove("loadMessage");
  }

  ui.updatePreviewStatus(status);

  server.load(movieId).then((Player thisPicture) {
    print("movie loaded");
    enableButtons(thisPicture, status);
  }).catchError((e) {
    print("can't load movie");
    enableButtons(new Player.blank(), status);
  });
}

void enableButtons(Player thisPicture, util.Text status) {
  ButtonElement edit = query("#edit");
  edit.onClick.first.then((e) {
    status.value = null;
    startEditor(thisPicture, status);
  });
  edit.disabled = false;

  ButtonElement start = query("#start-anew");
  start.onClick.first.then((e) {
    status.value = null;
    startEditor(new Player.blank(), status);
  });
  start.disabled = false;
}

void startEditor(Player player, util.Text status) {
  print("starting editor");

  var brush = new Brush(player.movie.palette);
  brush.selection = 26;

  ui.startEditor(player, new Editor(), brush, status);
  player.playing = true;

  print("ready to edit");
}
