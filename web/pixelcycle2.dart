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

  var palette = new Palette.standard();
  loadPlayer(palette).then((Player player) {
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

    var brush = new Brush(palette);
    brush.selection = 26;

    ui.startEditor(player, new Editor(), brush, status);

    if (!skipPreview) {
      status.value = null;
    }

    player.playing = true;

    print("started");
  });
}

Future<Player> loadPlayer(Palette palette) {

  var match = savedMoviePath.firstMatch(window.location.pathname);
  var player;
  if (match != null) {
    var c = new Completer();
    server.load(match.group(1)).then((String data) {
      print("got data");
      c.complete(deserializePlayer(palette, data));
    });
    return c.future;
  }

  var movie = new Movie.blank(palette, 8);
  player = new Player(movie);
  player.speed = 10;
  return new Future.value(player);
}

Player deserializePlayer(Palette palette, String dataString) {
  Map data = json.parse(dataString);
  assert (data["Version" == 1]);
  assert (data["Width"] == WIDTH && data["Height"] == HEIGHT);

  var movie = new Movie(palette);
  for (String frameString in data["Frames"]) {
    List<int> pixels = json.parse(frameString);
    Frame f = new Frame.fromPixels(palette, pixels);
    movie.add(f);
  }
  var player = new Player(movie);
  player.speed = data["Speed"];
  return player;
}
