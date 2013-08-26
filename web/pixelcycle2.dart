import 'package:pixelcycle2/src/palette.dart' show Palette, Brush;
import 'package:pixelcycle2/src/movie.dart' show Movie;
import 'package:pixelcycle2/src/player.dart' show Player;
import 'package:pixelcycle2/src/ui.dart' as ui;

void main() {
  var palette = new Palette.standard();
  var brush = new Brush(palette);
  brush.selection = 26;
  var movie = new Movie.blank(palette, 8);
  var player = new Player(movie);

  ui.onLoad(player, brush);

  player.speed = 10;
  player.playing = true;
}
