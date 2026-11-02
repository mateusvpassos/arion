// Importar de imagem: palavras + posições (de um OCR) -> cifra.
// As fixtures são saídas reais do Tesseract em prints de cifra.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:arion/core/chord_engine.dart';
import 'package:arion/core/ocr_cifra.dart';

List<PalavraOcr> fixture(String nome) =>
    (jsonDecode(File('test/fixtures/$nome').readAsStringSync()) as List)
        .map((j) => PalavraOcr(
              j['t'] as String,
              (j['x0'] as num).toDouble(),
              (j['y0'] as num).toDouble(),
              (j['x1'] as num).toDouble(),
              (j['y1'] as num).toDouble(),
            ))
        .toList();

/// "acorde@palavra" de cada acorde: em qual palavra da letra ele caiu.
List<String> ondeCaem(String cifra) {
  final out = <String>[];
  for (final s in ChordEngine.importText(cifra)) {
    for (final l in s.lines) {
      for (final c in l.chords) {
        final antes = l.lyric.substring(0, c.idx.clamp(0, l.lyric.length));
        final ini = antes.lastIndexOf(' ') + 1;
        var fim = l.lyric.indexOf(' ', c.idx.clamp(0, l.lyric.length));
        if (fim < 0) fim = l.lyric.length;
        out.add('${c.sym}@${l.lyric.substring(ini, fim)}');
      }
    }
  }
  return out;
}

void main() {
  test('corrige confusões típicas de OCR em acorde', () {
    expect(OcrCifra.corrigirAcorde('Fim'), 'F#m');
    expect(OcrCifra.corrigirAcorde('A/CH'), 'A/C#');
    expect(OcrCifra.corrigirAcorde('Bm7'), 'Bm7');
    expect(OcrCifra.corrigirAcorde('Bn/A'), 'Bm/A');
    expect(OcrCifra.corrigirAcorde('6'), 'G');
    expect(OcrCifra.corrigirAcorde('Senhor'), 'Senhor');
  });

  test('palavras sintéticas: acorde cai na sílaba de baixo', () {
    // "Que bom, Senhor" com D em cima de "bom" e A em cima de "Senhor"
    final ps = [
      const PalavraOcr('D', 52, 0, 60, 10),
      const PalavraOcr('A', 110, 0, 118, 10),
      const PalavraOcr('Que', 0, 16, 30, 26),
      const PalavraOcr('bom,', 50, 16, 90, 26),
      const PalavraOcr('Senhor', 110, 16, 170, 26),
    ];
    final cifra = OcrCifra.montar(ps);
    expect(ondeCaem(cifra), ['D@bom,', 'A@Senhor']);
  });

  test('foto torta: linha de acordes partida em duas vira uma', () {
    // "Em C" numa altura e "D D7" um pouco abaixo, à direita, sobre a mesma letra
    final ps = [
      const PalavraOcr('Em', 50, 0, 70, 10),
      const PalavraOcr('C', 200, 1, 210, 11),
      const PalavraOcr('D', 300, 9, 310, 19),
      const PalavraOcr('D7', 340, 10, 360, 20),
      const PalavraOcr('EABENÇOA', 0, 30, 90, 40),
      const PalavraOcr('A', 100, 30, 110, 40),
      const PalavraOcr('TODOS', 120, 30, 180, 40),
      const PalavraOcr('QUE', 190, 31, 230, 41),
      const PalavraOcr('ESPERAM', 240, 31, 320, 41),
      const PalavraOcr('EM', 330, 32, 350, 42),
      const PalavraOcr('VÓS.', 360, 32, 400, 42),
    ];
    final linhas = OcrCifra.montar(ps).split('\n');
    expect(linhas, hasLength(2));
    expect(ondeCaem(linhas.join('\n')).map((x) => x.split('@').first), ['Em', 'C', 'D', 'D7']);
  });

  test('print real (Como És Lindo): partes e acordes nas palavras certas', () {
    final cifra = OcrCifra.montar(fixture('ocr_como_es_lindo.json'));
    final secs = ChordEngine.importText(cifra);
    expect(secs.map((s) => s.name), containsAll(['Primeira Parte', 'Refrão']));
    final onde = ondeCaem(cifra);
    expect(onde, containsAll(['D@bom,', 'A@Ir', 'Bm@encontro', 'F#m@contigo', 'D@lindo']));
  });

  test('print real (Bem-aventurados): A7(4) e baixo invertido reconhecidos', () {
    final cifra = OcrCifra.montar(fixture('ocr_bem_aventurados.json'));
    final todos = ChordEngine.importText(cifra)
        .expand((s) => s.lines)
        .expand((l) => l.chords)
        .map((c) => c.sym)
        .toSet();
    expect(todos, containsAll(['D', 'A7', 'G', 'A7(4)', 'A/C#', 'Bm', 'Bm/A', 'F#7', 'Em7']));
  });
}
