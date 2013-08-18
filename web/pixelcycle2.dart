import 'package:pixelcycle2/src/palette.dart' show Palette;
import 'package:pixelcycle2/src/movie.dart' show Movie;
import 'package:pixelcycle2/src/player.dart' show Player;
import 'package:pixelcycle2/src/ui.dart' as ui;

void main() {
  print("got to main");
  var palette = new Palette.standard();
  var movie = new Movie.dazzle(palette);
  var player = new Player(movie);
  print("got to ui");
  ui.onLoad(player);
  print("done with ui");
  player.velocity = 5;
  player.playing = true;
}
