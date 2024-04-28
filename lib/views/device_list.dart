import "package:flutter/material.dart";
import "package:serialize/views/send_view.dart";
import "package:usb_serial/usb_serial.dart";

class DeviceList extends StatefulWidget {
  const DeviceList({super.key});

  @override
  State<DeviceList> createState() => _DeviceListState();
}

class _DeviceListState extends State<DeviceList> {
  Future<List<UsbDevice>>? _devicesFuture;

  @override
  void initState() {
    super.initState();
    _refreshDevices();
  }

  void _refreshDevices() {
    _devicesFuture = UsbSerial.listDevices();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text("Serial Devices"),
        ),
        body: FutureBuilder(
          future: _devicesFuture,
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
                    onPressed: () => setState(_refreshDevices),
                    icon: const Icon(Icons.refresh),
                    label: const Text("Retry"),
                  ),
                ],
              );
            }
            if (snapshot.hasData) {
              final devices = snapshot.data!;
              return RefreshIndicator(
                onRefresh: () async {
                  setState(_refreshDevices);
                  await _devicesFuture;
                },
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 16),
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return StatefulBuilder(
                      builder: (context, iSetState) => Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                        child: Card.filled(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              UsbPort port;
                              try {
                                port = await device.create() ?? (throw "Unknown error");
                                final result = await port.open();
                                if (!result) throw "Unknown error";
                                await port.setRTS(false);
                                if (context.mounted) {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => SendView(port: port),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to open USB port\n$e")));
                                }
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    device.deviceName,
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(
                                    height: 16,
                                  ),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.start,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Manufacturer",
                                              style: Theme.of(context).textTheme.labelLarge,
                                            ),
                                            Text(
                                              device.manufacturerName.toString(),
                                              style: Theme.of(context).textTheme.labelMedium,
                                            ),
                                            Text(
                                              "Model",
                                              style: Theme.of(context).textTheme.labelLarge,
                                            ),
                                            Text(
                                              device.productName.toString(),
                                              style: Theme.of(context).textTheme.labelMedium,
                                            ),
                                            Text(
                                              "Device ID",
                                              style: Theme.of(context).textTheme.labelLarge,
                                            ),
                                            Text(
                                              device.deviceId.toString(),
                                              style: Theme.of(context).textTheme.labelMedium,
                                            ),
                                            Text(
                                              "Interface count",
                                              style: Theme.of(context).textTheme.labelLarge,
                                            ),
                                            Text(
                                              device.interfaceCount.toString(),
                                              style: Theme.of(context).textTheme.labelMedium,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.start,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "PID",
                                              style: Theme.of(context).textTheme.labelLarge,
                                            ),
                                            Text(
                                              device.pid.toString(),
                                              style: Theme.of(context).textTheme.labelMedium,
                                            ),
                                            Text(
                                              "Serial",
                                              style: Theme.of(context).textTheme.labelLarge,
                                            ),
                                            Text(
                                              device.serial.toString(),
                                              style: Theme.of(context).textTheme.labelMedium,
                                            ),
                                            Text(
                                              "Serial",
                                              style: Theme.of(context).textTheme.labelLarge,
                                            ),
                                            Text(
                                              device.vid.toString(),
                                              style: Theme.of(context).textTheme.labelMedium,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            }
            return const Center(
              child: CircularProgressIndicator(),
            );
          },
        ),
      );
}
