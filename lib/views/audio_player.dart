import "package:flutter/material.dart";
import "package:image/image.dart" as img;
import "package:just_audio/just_audio.dart";
import "package:serialize/extensions.dart";
import "package:serialize/raw_audio_source.dart";
import "package:sstv_encode/sstv_encode.dart";

class ImageAudioPlayer extends StatefulWidget {
  const ImageAudioPlayer({this.imageData, super.key});

  final img.Image? imageData;

  @override
  State<ImageAudioPlayer> createState() => _ImageAudioPlayerState();
}

class _ImageAudioPlayerState extends State<ImageAudioPlayer> with WidgetsBindingObserver {
  final _encoder = Encoder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  Future<bool>? _audioFileFuture;
  double _sliderValue = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _audioPlayer.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initFuture();
  }

  @override
  void didUpdateWidget(covariant ImageAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageData == widget.imageData) return;
    _initFuture();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose().onError((error, stackTrace) {});
    super.dispose();
  }

  void _initFuture() {
    final imgDat = widget.imageData;
    if (imgDat == null) {
      _audioFileFuture = null;
      return;
    }
    _audioFileFuture = Future(() async {
      final robotPcm = await _encoder.robot36(imgDat);
      final robotWav = await robotPcm.pcmToWav(11025 ~/ 2);
      await _audioPlayer.setAudioSource(RawAudioSource(robotWav)).timeout(const Duration(seconds: 2));
      return true;
    });
  }

  @override
  Widget build(BuildContext context) => Material(
        borderRadius: BorderRadius.circular(64),
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: StreamBuilder<PlayerState>(
            stream: _audioPlayer.playerStateStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                FlutterError.reportError(FlutterErrorDetails(exception: snapshot.error!, stack: snapshot.stackTrace));
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        "Failed to load audio clip",
                        textAlign: TextAlign.center,
                        softWrap: true,
                        maxLines: 3,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                  ),
                );
              }
              final playerState = snapshot.data;
              return Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FutureBuilder(
                    future: _audioFileFuture,
                    builder: (context, fileSnapshot) {
                      if (fileSnapshot.hasError) {
                        FlutterError.reportError(
                          FlutterErrorDetails(exception: fileSnapshot.error!, stack: fileSnapshot.stackTrace),
                        );
                        return const IconButton(
                          icon: Icon(Icons.warning),
                          tooltip: "Failed to load audio-message.",
                          onPressed: null,
                        );
                      }
                      return IconButton(
                        onPressed: fileSnapshot.hasData && snapshot.hasData && playerState != null && playerState.processingState != ProcessingState.loading
                            ? () async {
                                switch (playerState.processingState) {
                                  case ProcessingState.idle:
                                  case ProcessingState.loading:
                                  case ProcessingState.buffering:
                                    break;
                                  case ProcessingState.ready:
                                    if (playerState.playing) {
                                      await _audioPlayer.pause();
                                    } else {
                                      await _audioPlayer.play();
                                    }
                                    break;
                                  case ProcessingState.completed:
                                    await _audioPlayer.seek(Duration.zero);
                                    await _audioPlayer.play();
                                    break;
                                }
                              }
                            : null,
                        color: Theme.of(context).colorScheme.onBackground,
                        icon: Icon(
                          ((_audioPlayer.duration ?? const Duration(days: 9999)) - _audioPlayer.position).inMilliseconds < 10 ? Icons.replay : ((playerState?.playing ?? false) ? Icons.pause : Icons.play_arrow),
                        ),
                      );
                    },
                  ),
                  Expanded(
                    child: StreamBuilder(
                      stream: _audioPlayer.positionStream,
                      builder: (context, snapshot) {
                        _sliderValue = _audioPlayer.duration == null ? 0 : (_audioPlayer.position.inMilliseconds / (_audioPlayer.duration!.inMilliseconds)).clamp(0, 1);
                        return StatefulBuilder(
                          // Not sure if this makes sense here...
                          builder: (context, setState) => SliderTheme(
                            data: SliderThemeData(
                              inactiveTrackColor: Theme.of(context).colorScheme.onBackground.withAlpha(100),
                            ),
                            child: Slider(
                              thumbColor: Theme.of(context).colorScheme.onBackground,
                              value: _sliderValue,
                              min: 0.0,
                              max: 1.0,
                              onChanged: (value) async {
                                await _audioPlayer.pause();
                                setState(() {
                                  _sliderValue = value;
                                });
                                await _audioPlayer.seek(
                                  Duration(
                                    milliseconds: (value * (_audioPlayer.duration?.inMilliseconds ?? 0)).round(),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
}
