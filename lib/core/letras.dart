// letras.dart — busca de letra no LRCLIB (lrclib.net): base aberta, sem
// chave. Só a letra; os acordes a pessoa põe no editor.
//
// Espelhado em mymusic-web/src/letras.ts.
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';

class LetraAchada {
  final String titulo, artista, album, letra;
  const LetraAchada(this.titulo, this.artista, this.album, this.letra);
}

class Letras {
  static final _uri = Uri.parse('https://lrclib.net/api/search');

  /// Resultados com letra, sem repetir a mesma música (o LRCLIB tem várias
  /// cópias da mesma faixa, de álbuns diferentes).
  static Future<List<LetraAchada>> buscar(String termo, {http.Client? client}) async {
    final q = termo.trim();
    if (q.isEmpty) return const [];
    final c = client ?? http.Client();
    try {
      final r = await c
          .get(
            _uri.replace(queryParameters: {'q': q}),
            // o LRCLIB pede p/ identificar o app
            headers: {'User-Agent': 'MyMusic (cifras e repertorios)'},
          )
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) throw 'O site de letras respondeu ${r.statusCode}';
      final vistos = <String>{};
      final out = <LetraAchada>[];
      for (final j in (jsonDecode(utf8.decode(r.bodyBytes)) as List).cast<Map>()) {
        final letra = ((j['plainLyrics'] ?? '') as String).trim();
        if (letra.isEmpty) continue;
        final t = ((j['trackName'] ?? '') as String).trim();
        final a = ((j['artistName'] ?? '') as String).trim();
        if (!vistos.add('${t.toLowerCase()}|${a.toLowerCase()}')) continue;
        out.add(LetraAchada(_limpaTitulo(t), a, ((j['albumName'] ?? '') as String).trim(), letra));
      }
      return out;
    } finally {
      if (client == null) c.close();
    }
  }

  /// Letra -> partes, separadas por linha em branco. Bloco que se repete é
  /// o refrão; os outros, estrofes (p/ copiar acordes de uma p/ outra).
  static List<Section> paraSecoes(String letra) {
    final blocos = letra
        .replaceAll('\r', '')
        .split(RegExp(r'\n\s*\n'))
        .map((b) => b.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList())
        .where((b) => b.isNotEmpty)
        .toList();
    String chave(List<String> b) => b.join('\n').toLowerCase();
    final vezes = <String, int>{};
    for (final b in blocos) {
      vezes[chave(b)] = (vezes[chave(b)] ?? 0) + 1;
    }
    var estrofe = 0;
    return [
      for (final b in blocos)
        Section(
          vezes[chave(b)]! > 1 ? 'Refrão' : 'Estrofe ${++estrofe}',
          [for (final l in b) SongLine(l, [])],
        ),
    ];
  }

  // "11 - A Barca" / "01. Ressuscita-me" -> sem o número da faixa
  static String _limpaTitulo(String t) =>
      t.replaceFirst(RegExp(r'^\d{1,3}\s*[-.)]\s*'), '');
}
