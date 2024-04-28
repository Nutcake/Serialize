import "dart:io";
import "dart:ui" as ui;

import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:image/image.dart" as img;
import "package:just_audio/just_audio.dart";
import "package:serialize/color_selector_button.dart";
import "package:serialize/extensions.dart";
import "package:serialize/foohy_api.dart";
import "package:serialize/raw_audio_source.dart";
import "package:serialize/uppercase_input_formatter.dart";
import "package:sstv_encode/sstv_encode.dart";
import "package:usb_serial/usb_serial.dart";

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

class SendView extends StatefulWidget {
  const SendView({required this.port, super.key});

  final UsbPort port;

  @override
  State<SendView> createState() => _SendViewState();
}

class _SendViewState extends State<SendView> with WidgetsBindingObserver {
  final _encoder = Encoder();
  final _audioPlayer = AudioPlayer();
  final _callSignTextController = TextEditingController();
  final _listenerKey = GlobalKey();
  final _callsignTextKey = GlobalKey();
  img.Image? _currentImage;
  Future<ui.Image>? _uiImageFuture;
  Offset _lastPointerPos = Offset.zero;
  Offset _lastPointerPosNormalized = Offset.zero;
  FontSize _selectedFontSize = FontSize.twentyFour;
  Color _selectedColor = Colors.white;
  bool _foohyUpload = false;
  bool _foohyCallsign = false;
  ScrollPhysics _scrollPhysics = const AlwaysScrollableScrollPhysics();

  @override
  void initState() {
    super.initState();
    widget.port.setRTS(false);
    _audioPlayer.playerStateStream.listen((event) async {
      if (event.processingState == ProcessingState.completed) {
        await widget.port.setRTS(false);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _audioPlayer.stop();
      widget.port.setRTS(false);
    }
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    widget.port.setRTS(false);
    super.dispose();
  }

  void _setImage(img.Image? image) {
    setState(() {
      _currentImage = image;
      _uiImageFuture = image?.convertImageToFlutterUi();
      if (image == null) {
        return;
      }
    });
  }

  bool get _sendable => _currentImage != null && _callSignTextController.text.isNotEmpty;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: const Text("Send image"),
            ),
            resizeToAvoidBottomInset: true,
            body: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              physics: _scrollPhysics,
              children: [
                Card.outlined(
                  child: SizedBox(
                    width: double.infinity,
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Listener(
                        key: _listenerKey,
                        onPointerMove: (event) {
                          final canvasRb = _listenerKey.currentContext?.findRenderObject() as RenderBox?;
                          final textRb = _callsignTextKey.currentContext?.findRenderObject() as RenderBox?;
                          if (canvasRb == null || textRb == null) return;
                          setState(() {
                            _lastPointerPos = ui.Offset(
                              (event.localPosition.dx - (textRb.size.width / 2)).clamp(0, canvasRb.size.width).toDouble(),
                              event.localPosition.dy.clamp(0, canvasRb.size.height).toDouble(),
                            );
                            _lastPointerPosNormalized = ui.Offset(_lastPointerPos.dx / canvasRb.size.width, _lastPointerPos.dy / canvasRb.size.height);
                          });
                        },
                        onPointerDown: (event) {
                          setState(() {
                            _scrollPhysics = const NeverScrollableScrollPhysics();
                          });
                        },
                        onPointerUp: (event) {
                          setState(() {
                            _scrollPhysics = const AlwaysScrollableScrollPhysics();
                          });
                        },
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: FutureBuilder(
                                  future: _uiImageFuture,
                                  builder: (context, snapshot) {
                                    if (snapshot.hasError) {
                                      return Center(
                                        child: Text("error: ${snapshot.error}"),
                                      );
                                    }
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }
                                    return snapshot.data != null
                                        ? RawImage(
                                            image: snapshot.data!,
                                            fit: BoxFit.fitWidth,
                                            width: double.infinity,
                                          )
                                        : const SizedBox.shrink();
                                  },
                                ),
                              ),
                            ),
                            AnimatedAlign(
                              duration: const Duration(milliseconds: 400),
                              alignment: _uiImageFuture == null ? Alignment.center : Alignment.topRight,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(64),
                                  color: Theme.of(context).colorScheme.onBackground.withOpacity(0.3),
                                ),
                                margin: const EdgeInsets.all(8),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  splashRadius: 20,
                                  iconSize: 20,
                                  color: Theme.of(context).colorScheme.background,
                                  onPressed: () async {
                                    final result = await FilePicker.platform.pickFiles(type: FileType.image);
                                    if (result != null) {
                                      final file = File(result.files.single.path!);
                                      final cmd = img.Command()
                                        ..decodeImage(file.readAsBytesSync())
                                        ..copyResize(width: Encoder.imgWidth, height: Encoder.imgHeight)
                                        ..encodePng();
                                      _setImage((await cmd.execute()).outputImage);
                                    } else {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("File selection cancelled")));
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.edit),
                                ),
                              ),
                            ),
                            Positioned(
                              left: _lastPointerPos.dx,
                              top: _lastPointerPos.dy,
                              child: Text(
                                _callSignTextController.text,
                                key: _callsignTextKey,
                                textAlign: ui.TextAlign.center,
                                style: TextStyle(
                                  fontSize: _selectedFontSize.value,
                                  color: _selectedColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 16,
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _callSignTextController,
                        onChanged: (value) => setState(() {}),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          labelText: "Callsign",
                          isDense: true,
                        ),
                        inputFormatters: [
                          UppercaseInputFormatter(),
                        ],
                      ),
                    ),
                    const SizedBox(
                      width: 16,
                    ),
                    SegmentedButton(
                      style: SegmentedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      emptySelectionAllowed: false,
                      multiSelectionEnabled: false,
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(value: FontSize.fourteen, label: Text("${FontSize.fourteen.value.toInt()} px")),
                        ButtonSegment(value: FontSize.twentyFour, label: Text("${FontSize.twentyFour.value.toInt()} px")),
                        ButtonSegment(value: FontSize.fortyEight, label: Text("${FontSize.fortyEight.value.toInt()} px")),
                      ],
                      selected: {_selectedFontSize},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _selectedFontSize = selection.firstOrNull ?? _selectedFontSize;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(
                  height: 16,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Colors.white,
                    Colors.black,
                    Colors.red,
                    Colors.green,
                    Colors.blue,
                    Colors.yellow,
                    Colors.orange,
                  ]
                      .map(
                        (e) => ColorSelectorButton(
                          color: e,
                          selected: e == _selectedColor,
                          checkColor: e == Colors.black ? Colors.white : null,
                          onTap: () => setState(() {
                            _selectedColor = e;
                          }),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(
                  height: 16,
                ),
                Row(
                  children: [
                    Text(
                      "Also upload to sstv.foohy.net",
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const Spacer(),
                    Switch(
                      value: _foohyUpload,
                      onChanged: (value) => setState(() {
                        _foohyUpload = value;
                      }),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      "Enable callsign for web upload",
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const Spacer(),
                    Switch(
                      value: _foohyCallsign,
                      onChanged: (value) => setState(() {
                        _foohyCallsign = value;
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _sendable
                ? AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: animation,
                        child: child,
                      ),
                    ),
                    child: StreamBuilder(
                      stream: _audioPlayer.playerStateStream,
                      builder: (context, snapshot) {
                        final state = snapshot.data;
                        final sending = state != null && state.playing && state.processingState != ProcessingState.completed;
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(64),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: SizedBox.expand(
                                    child: StreamBuilder<Duration>(
                                      stream: _audioPlayer.positionStream,
                                      builder: (context, snapshot) {
                                        final value = (_audioPlayer.duration == null ? 0 : (_audioPlayer.position.inMilliseconds / (_audioPlayer.duration!.inMilliseconds)).clamp(0, 1)) * 100;
                                        return Row(
                                          children: [
                                            Expanded(
                                              flex: value.toInt(),
                                              child: Container(
                                                height: double.infinity,
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context).colorScheme.primary,
                                                  border: Border.all(
                                                    width: 0,
                                                    color: Theme.of(context).colorScheme.primary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 100 - value.toInt(),
                                              child: Container(
                                                height: double.infinity,
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context).colorScheme.secondary,
                                                  border: Border.all(
                                                    width: 0,
                                                    color: Theme.of(context).colorScheme.secondary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: sending
                                        ? () async {
                                            await _audioPlayer.stop();
                                            await _audioPlayer.seek(const Duration(days: 1));
                                            await widget.port.setRTS(false);
                                          }
                                        : () async {

                                            final color = img.ColorInt8(4)
                                              ..rNormalized = _selectedColor.red / 255
                                              ..gNormalized = _selectedColor.green / 255
                                              ..bNormalized = _selectedColor.blue / 255
                                              ..aNormalized = _selectedColor.alpha / 255;
                                            final cmd = img.Command()
                                              ..image(_currentImage!)
                                              ..copy()
                                              ..drawString(
                                                _callSignTextController.text,
                                                font: _selectedFontSize.font,
                                                color: color,
                                                x: (_lastPointerPosNormalized.dx * Encoder.imgWidth).toInt(),
                                                y: (_lastPointerPosNormalized.dy * Encoder.imgHeight).toInt(),
                                              );
                                            final image = (await cmd.execute()).outputImage;
                                            if (image == null) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to embed callsign")));
                                              }
                                              return;
                                            }
                                            if (_foohyUpload) {
                                              try {
                                                if (_foohyCallsign) {
                                                  await FoohyApi.uploadSstvImage(image);
                                                } else {
                                                  await FoohyApi.uploadSstvImage(_currentImage!);
                                                }
                                              } catch (e, s) {
                                                FlutterError.reportError(FlutterErrorDetails(exception: e, stack: s));
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to send image to foohy.net:\n$e")));
                                                }
                                              }
                                            }
                                            await widget.port.setRTS(true);
                                            final robotPcm = await _encoder.robot36(image);
                                            final robotWav = await robotPcm.pcmToWav(11025 ~/ 2);
                                            await _audioPlayer.setAudioSource(RawAudioSource(robotWav)).timeout(const Duration(seconds: 2));
                                            await _audioPlayer.seek(Duration.zero);
                                            await _audioPlayer.play();
                                          },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            sending ? "Abort" : "Send it!",
                                            style: Theme.of(context).textTheme.headlineSmall?.apply(
                                                  color: Theme.of(context).colorScheme.onPrimary,
                                                ),
                                          ),
                                          const SizedBox(
                                            width: 16,
                                          ),
                                          Icon(
                                            sending ? Icons.cancel_outlined : Icons.send,
                                            color: Theme.of(context).colorScheme.onPrimary,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      );
}
