import 'package:pixelcycle2/src/palette.dart' show Palette;
import 'package:pixelcycle2/src/movie.dart' show Movie;
import 'package:pixelcycle2/src/player.dart' show Player;
import 'package:pixelcycle2/src/ui.dart' as ui;

void main() {
  var palette = new Palette.standard();
  var movie = new Movie.dazzle(palette);
  var player = new Player(movie);
  ui.onLoad(player);
  player.fps = 60;
  player.playing = true;
}
