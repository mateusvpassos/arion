import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../core/ocr_cifra.dart';

/// Importar cifra de foto/print: lê o texto com o ML Kit (no próprio aparelho,
/// sem internet) e monta "acorde acima da letra" pela posição das palavras.
/// Só Android/iOS (no PC, o Arion web faz isso no navegador).
class OcrImagem {
  static bool get disponivel => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Escolhe a imagem e devolve o texto da cifra (null = desistiu).
  static Future<String?> lerCifra(ImageSource fonte) async {
    final img = await ImagePicker().pickImage(source: fonte);
    if (img == null) return null;
    final rec = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final r = await rec.processImage(InputImage.fromFilePath(img.path));
      final palavras = <PalavraOcr>[
        for (final b in r.blocks)
          for (final l in b.lines)
            for (final e in l.elements)
              PalavraOcr(
                e.text,
                e.boundingBox.left,
                e.boundingBox.top,
                e.boundingBox.right,
                e.boundingBox.bottom,
              ),
      ];
      return OcrCifra.montar(palavras);
    } finally {
      await rec.close();
    }
  }
}
