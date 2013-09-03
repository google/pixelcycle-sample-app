library share;

import 'dart:async' show Future, Completer;
import 'dart:html' show HttpRequest, HttpRequestProgressEvent;
import 'dart:json' as json;

import 'package:pixelcycle2/src/movie.dart' show WIDTH, HEIGHT, Movie, Frame;
import 'package:pixelcycle2/src/palette.dart' show Palette;
import 'package:pixelcycle2/src/player.dart' show Player;

/// Saves the current state and returns a new URL that can be used to load it.
Future<String> save(Player player) {
  return post("/save", stringify(player));
}

/// Serializes the state of the player.
String stringify(Player player) {
  var palette = player.movie.palette.toInts();
  bool isStandard = equalLists(palette, standardPalette);
  var data = {
              'Version': 2,
              'Speed': player.speed,
              'Width': WIDTH,
              'Height': HEIGHT,
              'Frames': player.movie.frames.map((f) => stringifyFrame(f)).toList(growable: false),
  };
  if (!isStandard) {
    print("nonstandard palette: ${palette}");
    print("   standard palette: ${standardPalette}");
    data['Palette'] = palette;
  }
  return json.stringify(data);
}

bool equalLists(List a, List b) {
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

const baseColorChar = 33;

/// Encodes frame using one character per pixel, starting from ascii 33.
String stringifyFrame(Frame f) {
  return new String.fromCharCodes(f.pixels.map((p) => p + baseColorChar));
}

Frame parseFrame(Palette palette, String frameString) {
  List<int> pixels = frameString.codeUnits.map((c) => c - baseColorChar).toList(growable: false);
  return new Frame.fromPixels(palette, pixels);
}

List<int> standardPalette = [
  0, 0, 0, 51, 51, 51, 102, 102, 102, 204, 102, 102,
  204, 127, 102, 204, 153, 102, 204, 178, 102, 204, 204, 102,
  171, 204, 102, 102, 204, 102, 102, 204, 169, 102, 204, 204,
  102, 170, 204, 102, 136, 204, 102, 102, 204, 135, 102, 204,
  170, 102, 204, 204, 102, 204, 204, 102, 153, 153, 153, 153,
  204, 204, 204, 255, 255, 255, 255, 0, 0, 255, 63, 0,
  255, 127, 0, 255, 191, 0, 255, 255, 0, 171, 255, 0,
  0, 255, 0, 0, 255, 169, 0, 255, 255, 0, 170, 255,
  0, 85, 255, 0, 0, 255, 84, 0, 255, 170, 0, 255,
  255, 0, 255, 255, 0, 128, 51, 0, 0, 51, 51, 0,
  0, 51, 0, 191, 0, 0, 191, 47, 0, 191, 95, 0,
  191, 143, 0, 191, 191, 0, 128, 191, 0, 0, 191, 0,
  0, 191, 127, 0, 191, 191, 0, 128, 191, 0, 64, 191,
  0, 0, 191, 63, 0, 191, 127, 0, 191, 191, 0, 191,
  191, 0, 96, 0, 51, 51, 0, 0, 51, 51, 0, 51,
  127, 0, 0, 127, 31, 0, 127, 63, 0, 127, 95, 0,
  127, 127, 0, 85, 127, 0, 0, 127, 0, 0, 127, 84,
  0, 127, 127, 0, 85, 127, 0, 42, 127, 0, 0, 127,
  42, 0, 127, 85, 0, 127, 127, 0, 127, 127, 0, 64,
];

/// Loads the player state with the given id.
Future<Player> load(String id) {
  var c = new Completer<Player>();
  HttpRequest.getString("/json/${id}")
      .then((data) => c.complete(parse(data)));
  return c.future;
}

Player parse(String dataString) {
  var palette = new Palette.standard();

  Map data = json.parse(dataString);
  if (data["Version"] != 2) {
    throw "unexpected version: ${data["Version"]}";
  }
  if (data["Width"] != WIDTH || data["Height"] != HEIGHT) {
    throw "unexpected bounds: (${data["Width"]}, ${data["Height"]})";
  }

  var movie = new Movie(palette);
  for (String frameString in data["Frames"]) {
    movie.add(parseFrame(palette, frameString));
  }
  var player = new Player(movie);
  player.speed = data["Speed"];
  return player;
}

/// Posts a string to the server and returns the response body as a string.
Future<String> post(String url, String data) {
  Completer done = new Completer();

  var r = new HttpRequest();

  r.onReadyStateChange.listen((e) {
    if (r.readyState == 4) {
      if (r.status == 200) {
        done.complete(r.responseText);
      } else {
        done.completeError("request failed with ${r.status}");
      }
    }
  });

  r.open("POST", url, async: true);
  r.send(data);

  return done.future;
}