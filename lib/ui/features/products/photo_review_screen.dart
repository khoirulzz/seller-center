import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Runs away from the UI isolate. Crop is deliberately centered and never
/// changes the original until the seller explicitly applies the preview.
Uint8List transformProductPhoto(
  ({Uint8List bytes, int turns, double? ratio}) input,
) {
  if (input.turns % 4 == 0 && input.ratio == null) return input.bytes;
  final decoded = img.decodeImage(input.bytes);
  if (decoded == null) throw const FormatException('Foto tidak dapat dibuka.');
  var image = img.bakeOrientation(decoded);
  if (input.turns % 4 != 0)
    image = img.copyRotate(image, angle: input.turns * 90);
  if (input.ratio != null) {
    var width = image.width, height = image.height;
    if (width / height > input.ratio!) {
      width = (height * input.ratio!).round().clamp(1, image.width);
    } else {
      height = (width / input.ratio!).round().clamp(1, image.height);
    }
    image = img.copyCrop(
      image,
      x: (image.width - width) ~/ 2,
      y: (image.height - height) ~/ 2,
      width: width,
      height: height,
    );
  }
  // PNG preserves transparent merchant artwork; JPEG keeps fabric photos small.
  return image.hasAlpha
      ? img.encodePng(image)
      : img.encodeJpg(image, quality: 90);
}

class PhotoReviewScreen extends StatefulWidget {
  const PhotoReviewScreen({super.key, required this.bytes});
  final Uint8List bytes;
  @override
  State<PhotoReviewScreen> createState() => _PhotoReviewScreenState();
}

class _PhotoReviewScreenState extends State<PhotoReviewScreen> {
  int turns = 0;
  double? ratio;
  bool busy = false;
  Uint8List? preview;
  String? error;
  Future<void> update() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final bytes = await compute(transformProductPhoto, (
        bytes: widget.bytes,
        turns: turns,
        ratio: ratio,
      ));
      if (mounted) setState(() => preview = bytes);
    } catch (_) {
      if (mounted)
        setState(() => error = 'Foto belum dapat diproses. Coba foto lain.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Atur foto')),
    body: Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Image.memory(preview ?? widget.bytes, fit: BoxFit.contain),
            ),
          ),
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const Text(
                'Pemotongan mengambil bagian tengah foto. Periksa hasil sebelum menerapkan.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final option in <({String label, double? ratio})>[
                    (label: 'Asli', ratio: null),
                    (label: '1:1', ratio: 1),
                    (label: '4:5', ratio: 0.8),
                  ])
                    ChoiceChip(
                      label: Text(option.label),
                      selected: ratio == option.ratio,
                      onSelected: busy
                          ? null
                          : (_) {
                              ratio = option.ratio;
                              update();
                            },
                    ),
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () {
                            turns = (turns + 1) % 4;
                            update();
                          },
                    icon: const Icon(Icons.rotate_right),
                    label: const Text('Putar 90°'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.all(16),
      child: FilledButton(
        onPressed: busy || error != null
            ? null
            : () => Navigator.pop(context, preview ?? widget.bytes),
        child: const Text('Terapkan foto'),
      ),
    ),
  );
}
