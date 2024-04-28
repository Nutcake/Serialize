import "dart:typed_data";
import "dart:ui" as ui;

import "package:image/image.dart" as img;

extension ImageX on img.Image {
  Future<ui.Image> convertImageToFlutterUi() async {
    var image = this;
    if (image.format != img.Format.uint8 || image.numChannels != 4) {
      final cmd = img.Command()
        ..image(image)
        ..convert(format: img.Format.uint8, numChannels: 4);
      final rgba8 = await cmd.getImageThread();
      if (rgba8 != null) {
        image = rgba8;
      }
    }

    final buffer = await ui.ImmutableBuffer.fromUint8List(image.toUint8List());

    final id = ui.ImageDescriptor.raw(buffer, height: image.height, width: image.width, pixelFormat: ui.PixelFormat.rgba8888);

    final codec = await id.instantiateCodec(targetHeight: image.height, targetWidth: image.width);

    final fi = await codec.getNextFrame();
    final uiImage = fi.image;

    return uiImage;
  }
}

extension Uint8ListX on Uint8List {
  Future<Uint8List> pcmToWav(int sampleRate) async {
    const channels = 1;
    final byteRate = ((16 * sampleRate * channels) / 8).round();
    final size = length;
    final fileSize = size + 36;
    final header = Uint8List.fromList([
      // "RIFF"
      82, 73, 70, 70,
      fileSize & 0xff,
      (fileSize >> 8) & 0xff,
      (fileSize >> 16) & 0xff,
      (fileSize >> 24) & 0xff,
      // WAVE
      87, 65, 86, 69,
      // fmt
      102, 109, 116, 32,
      // fmt chunk size 16
      16, 0, 0, 0,
      // Type of format
      1, 0,
      // One channel
      channels, 0,
      // Sample rate
      sampleRate & 0xff,
      (sampleRate >> 8) & 0xff,
      (sampleRate >> 16) & 0xff,
      (sampleRate >> 24) & 0xff,
      // Byte rate
      byteRate & 0xff,
      (byteRate >> 8) & 0xff,
      (byteRate >> 16) & 0xff,
      (byteRate >> 24) & 0xff,
      // Uhm
      ((16 * channels) / 8).round(), 0,
      // bitsize
      16, 0,
      // "data"
      100, 97, 116, 97,
      size & 0xff,
      (size >> 8) & 0xff,
      (size >> 16) & 0xff,
      (size >> 24) & 0xff,
      // incoming data
      ...this,
    ]);
    return header;
  }
}
