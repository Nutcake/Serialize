import "package:http/http.dart";
import "package:image/image.dart" as img;
import "package:uuid/uuid.dart";

class FoohyApi {
  static const maxWidth = 160;
  static const maxHeight = 120;
  static const userId = "U-SerializeAndroid";
  static const header = "$maxWidth $maxHeight\n";

  static Future<void> uploadSstvImage(img.Image image) async {
    if (image.width != maxWidth || image.height != maxHeight) {
      final cmd = img.Command()
        ..image(image)
        ..copyResize(width: maxWidth, height: maxHeight);
      image = (await cmd.execute()).outputImage ?? (throw "Failed to resize image");
    }
    final sb = StringBuffer()..write(header);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final px = image.getPixel(x, y);
        final r = (px.rNormalized * 255).toInt();
        final g = (px.gNormalized * 255).toInt();
        final b = (px.bNormalized * 255).toInt();
        sb.write("${r.toRadixString(16).padLeft(2, "0")}${g.toRadixString(16).padLeft(2, "0")}${b.toRadixString(16).padLeft(2, "0")}");
      }
    }
    final body = sb.toString().toUpperCase().trim();
    final response =
        await post(Uri.parse("https://sstv.foohy.net/upload?algo=color&neos_mid=${const Uuid().v4().replaceAll("-", "")}&neos_id=$userId&utc_off=7200"), body: body, headers: {"Content-Type": "text/plain"});
    if (response.statusCode > 299) {
      throw "Request failed with status code ${response.statusCode}: ${response.body}";
    }
  }
}
