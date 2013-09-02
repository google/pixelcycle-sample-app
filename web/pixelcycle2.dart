import 'dart:html';
import 'dart:async' show Future, Completer;
import 'dart:json' as json;

import 'package:pixelcycle2/src/editor.dart' show Editor;
import 'package:pixelcycle2/src/palette.dart' show Palette, Brush;
import 'package:pixelcycle2/src/movie.dart' show Movie, Frame, WIDTH, HEIGHT;
import 'package:pixelcycle2/src/player.dart' show Player;
import 'package:pixelcycle2/src/server.dart' as server;
import 'package:pixelcycle2/src/ui.dart' as ui;
import 'package:pixelcycle2/src/util.dart' as util;

RegExp savedMoviePath = new RegExp(r"^/m(\d+)$");

void main() {
  print("main entered");

  String gif = query("#gif").attributes["src"];
  print("gif: ${gif}");
  bool skipPreview = (gif == null) || (gif == "") || gif.startsWith("{{");
  if (skipPreview) {
    ui.hidePreview();
  }

  var status = new util.Text();
  if (window.sessionStorage["loadMessage"] != null) {
    status.value = window.sessionStorage["loadMessage"];
    window.sessionStorage.remove("loadMessage");
  }
  ui.previewStatus(status);

  loadPlayer().then((Player player) {
    print("player loaded");

    if (skipPreview) {
      return new Future.value(player);
    }

    print("showing preview");
    ButtonElement edit = query("#edit");

    var c = new Completer();
    edit.onClick.first.then((e) {
      c.complete(player);
    });

    edit.disabled = false;

    return c.future;
  }).then((Player player) {
    print("starting editor");

    var brush = new Brush(player.movie.palette);
    brush.selection = 26;

    ui.startEditor(player, new Editor(), brush, status);

    if (!skipPreview) {
      status.value = null;
    }

    player.playing = true;

    print("started");
  });
}

Future<Player> loadPlayer() {

  var match = savedMoviePath.firstMatch(window.location.pathname);
  if (match != null) {
    return server.load(match.group(1));
  }

  var movie = new Movie.blank(new Palette.standard(), 8);
  var player = new Player(movie);
  player.speed = 10;
  return new Future.value(player);
}
