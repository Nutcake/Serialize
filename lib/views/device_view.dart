import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:serialize/models/baud_rate.dart';
import 'package:serialize/models/parity.dart';
import 'package:usb_serial/usb_serial.dart';

class DeviceView extends StatefulWidget {
  const DeviceView({required this.deviceName, required this.port, super.key});

  final String deviceName;
  final UsbPort port;

  @override
  State<DeviceView> createState() => _DeviceViewState();
}

class _DeviceViewState extends State<DeviceView> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  late UsbPort _port;
  Stream<Uint8List>? _inputStream;
  String _inputData = "";
  bool _autoScroll = true;
  StreamSubscription? _inputStreamListener;

  @override
  void initState() {
    super.initState();
    _reloadPort();
  }

  @override
  void didUpdateWidget(covariant DeviceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.port != widget.port) {
      _reloadPort();
    }
  }

  void _reloadPort() {
    _port = widget.port;
    _inputStream = _port.inputStream;
    _inputStreamListener = _inputStream?.listen((event) {
      _inputData += String.fromCharCodes(event);
      if (_autoScroll) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    _inputStreamListener?.cancel();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.deviceName),
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.black54,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      DropdownMenu<BaudRate>(
                        initialSelection: BaudRate.fromValue(_port.baudRate) ?? BaudRate.baud9600,
                        label: const Text("Baud"),
                        onSelected: (value) {
                          if (value != null) {
                            _port.setPortParameters(value.rate, _port.dataBits, _port.stopBits, _port.parity);
                          }
                        },
                        dropdownMenuEntries: BaudRate.values
                            .map(
                              (e) => DropdownMenuEntry(
                                value: e,
                                label: e.rate.toString(),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(
                        width: 16,
                      ),
                      DropdownMenu<Parity>(
                        initialSelection: Parity.fromValue(_port.parity) ?? Parity.none,
                        label: const Text("Parity}"),
                        onSelected: (value) {
                          if (value != null) {
                            _port.setPortParameters(_port.baudRate, _port.dataBits, _port.stopBits, value.index);
                          }
                        },
                        dropdownMenuEntries: Parity.values
                            .map(
                              (e) => DropdownMenuEntry(
                                value: e,
                                label: toBeginningOfSentenceCase(e.name),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder(
                stream: _inputStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    FlutterError.reportError(
                      FlutterErrorDetails(
                        exception: snapshot.error!,
                        stack: snapshot.stackTrace,
                      ),
                    );
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.warning_amber,
                          size: 36,
                        ),
                        Text(
                          "Something went wrong",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(snapshot.error.toString()),
                        TextButton.icon(
                          onPressed: () => setState(_reloadPort),
                          icon: const Icon(Icons.refresh),
                          label: const Text("Retry"),
                        ),
                      ],
                    );
                  }
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _inputData,
                          ),
                        ),
                      ),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Align(
                          alignment: Alignment.topCenter,
                          child: LinearProgressIndicator(),
                        ),
                    ],
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.only(
                left: 16,
                right: 8,
                top: 8,
                bottom: 8,
              ),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.black54,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        filled: true,
                        isDense: true,
                        fillColor: Colors.black12,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(64),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 4,
                  ),
                  IconButton(
                    iconSize: 28,
                    onPressed: () async {
                      try {
                        await _port.write(Uint8List.fromList(_inputController.text.codeUnits));
                        _inputController.clear();
                      } catch (e, s) {
                        FlutterError.reportError(
                          FlutterErrorDetails(
                            exception: e,
                            stack: s,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
