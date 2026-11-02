// ocr_cifra.dart — monta a cifra ("acorde acima da letra") a partir das
// palavras que um OCR leu numa imagem, usando a posição de cada uma: é a
// posição na tela que diz em qual sílaba cada acorde cai.
//
// Espelhado em arion-web/src/ocrCifra.ts.
import 'chord_engine.dart';

/// Uma palavra lida pelo OCR, com a caixa onde ela está na imagem (pixels).
class PalavraOcr {
  final String texto;
  final double esq, topo, dir, base;
  const PalavraOcr(this.texto, this.esq, this.topo, this.dir, this.base);
  double get altura => base - topo;
  double get centroY => (topo + base) / 2;
}

class OcrCifra {
  /// Erros típicos de OCR em acorde ("F#m" lido "Fim", "A/C#" lido "A/CH"):
  /// troca e só aceita se virar acorde de verdade.
  static String corrigirAcorde(String t) {
    if (ChordEngine.isChordSymbol(t)) return t;
    // raiz lida errada (O/0 -> D, 8 -> B, 6 -> G)
    const raiz = {'O': 'D', '0': 'D', '8': 'B', '6': 'G'};
    var r = t;
    if (r.isNotEmpty && raiz.containsKey(r[0])) r = raiz[r[0]]! + r.substring(1);
    if (ChordEngine.isChordSymbol(r)) return r;
    // depois da raiz: sustenido lido como letra ("Fim" -> "F#m") ou "m" lido
    // "n"/"rn" ("Bn/A" -> "Bm/A")
    for (final tr in const [['H', '#'], ['i', '#'], ['l', '#'], ['f', '#'], ['t', '#'], ['rn', 'm'], ['n', 'm']]) {
      if (r.length < 2) break;
      final c = r[0] + r.substring(1).replaceAll(tr[0], tr[1]);
      if (ChordEngine.isChordSymbol(c)) return c;
    }
    return t;
  }

  static double _mediana(List<double> v) {
    if (v.isEmpty) return 0;
    final s = [...v]..sort();
    return s[s.length ~/ 2];
  }

  /// Agrupa as palavras em linhas (pela altura na imagem), cada linha da
  /// esquerda p/ a direita.
  static List<List<PalavraOcr>> _linhas(List<PalavraOcr> ps) {
    final h = _mediana(ps.map((p) => p.altura).toList());
    final ordem = [...ps]..sort((a, b) => a.centroY.compareTo(b.centroY));
    final linhas = <List<PalavraOcr>>[];
    for (final p in ordem) {
      final atual = linhas.isEmpty ? null : linhas.last;
      if (atual != null) {
        final cy = atual.map((x) => x.centroY).reduce((a, b) => a + b) / atual.length;
        if ((p.centroY - cy).abs() < h * 0.5) {
          atual.add(p);
          continue;
        }
      }
      linhas.add([p]);
    }
    for (final l in linhas) {
      l.sort((a, b) => a.esq.compareTo(b.esq));
    }
    return linhas;
  }

  static bool _ehAcorde(PalavraOcr p) => ChordEngine.isChordSymbol(corrigirAcorde(p.texto));

  /// Linha de acordes: a maioria dos tokens é acorde (o OCR às vezes junta
  /// um borrão ou lê um traço solto); 1 token só precisa ser acorde.
  static bool _ehLinhaDeAcorde(List<PalavraOcr> l) {
    final n = l.where(_ehAcorde).length;
    return n > 0 && (n == l.length || (l.length >= 2 && n / l.length >= 0.6));
  }

  /// Texto da cifra, pronto p/ a tela de importar (que entende partes,
  /// "Tom:", etc.).
  static String montar(List<PalavraOcr> palavras) {
    final ps = palavras.where((p) => p.texto.trim().isNotEmpty).toList();
    if (ps.isEmpty) return '';
    final linhas = _linhas(ps);
    final acorde = [for (final l in linhas) _ehLinhaDeAcorde(l)];

    // largura média de um caractere (das linhas de letra)
    final larguras = <double>[
      for (var i = 0; i < linhas.length; i++)
        if (!acorde[i])
          for (final p in linhas[i])
            if (p.texto.length > 1) (p.dir - p.esq) / p.texto.length,
    ];
    final cw = larguras.isEmpty ? 10.0 : _mediana(larguras);
    final margem = ps.map((p) => p.esq).reduce((a, b) => a < b ? a : b);

    // linha em branco onde o espaço entre linhas é bem maior que o normal
    final vaos = <double>[
      for (var i = 1; i < linhas.length; i++)
        linhas[i].first.topo - linhas[i - 1].map((p) => p.base).reduce((a, b) => a > b ? a : b),
    ];
    final vaoNormal = _mediana(vaos);

    final out = <String>[];
    for (var i = 0; i < linhas.length; i++) {
      if (i > 0 && vaos[i - 1] > vaoNormal * 2.2 && vaos[i - 1] > cw) out.add('');
      final l = linhas[i];
      if (!acorde[i]) {
        out.add(l.map((p) => p.texto).join(' '));
        continue;
      }
      final abaixo = i + 1 < linhas.length && !acorde[i + 1] ? linhas[i + 1] : null;
      out.add(_linhaDeAcordes(l, abaixo, cw, margem));
    }
    return out.join('\n');
  }

  /// Acordes posicionados em colunas que caem na sílaba certa da letra de
  /// baixo (que é montada com um espaço entre palavras).
  static String _linhaDeAcordes(
    List<PalavraOcr> acordes,
    List<PalavraOcr>? letra,
    double cw,
    double margem,
  ) {
    // início (em caracteres) de cada palavra da letra montada
    final inicios = <int>[];
    var pos = 0;
    for (final p in letra ?? const <PalavraOcr>[]) {
      inicios.add(pos);
      pos += p.texto.length + 1;
    }
    int coluna(double x) {
      if (letra == null || letra.isEmpty) return ((x - margem) / cw).round().clamp(0, 400);
      if (x < letra.first.esq) return 0;
      for (var k = letra.length - 1; k >= 0; k--) {
        final w = letra[k];
        if (x >= w.esq - cw / 2) {
          final larg = w.dir - w.esq;
          if (x <= w.dir) {
            final frac = larg <= 0 ? 0.0 : (x - w.esq) / larg;
            return inicios[k] + (frac * w.texto.length).round().clamp(0, w.texto.length);
          }
          // no vão depois da palavra (ou além do fim da letra)
          final fim = inicios[k] + w.texto.length;
          return fim + 1 + ((x - w.dir) / cw).floor().clamp(0, 400);
        }
      }
      return 0;
    }

    final buf = StringBuffer();
    // o que não é acorde numa linha de acordes é lixo do OCR
    for (final a in acordes.where(_ehAcorde)) {
      final sym = corrigirAcorde(a.texto);
      var col = coluna(a.esq);
      // não encosta no acorde anterior
      if (buf.length > 0 && col <= buf.length) col = buf.length + 1;
      while (buf.length < col) {
        buf.write(' ');
      }
      buf.write(sym);
    }
    return buf.toString();
  }
}
