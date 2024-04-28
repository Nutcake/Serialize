import "package:image/image.dart" as img;

enum FontSize {
  fourteen,
  twentyFour,
  fortyEight;

  double get value => {
        fourteen: 14.0,
        twentyFour: 24.0,
        fortyEight: 48.0,
      }[this]!;

  img.BitmapFont get font => {
        fourteen: img.arial14,
        twentyFour: img.arial24,
        fortyEight: img.arial48,
      }[this]!;
}
