import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mymusic/core/chord_engine.dart';
import 'package:mymusic/core/letras.dart';
import 'package:mymusic/models/song.dart';

void main() {
  group('campoHarmonico', () {
    test('tom maior: I ii iii IV V vi vii° primeiro', () {
      expect(ChordEngine.campoHarmonico('G').take(7), ['G', 'Am', 'Bm', 'C', 'D', 'Em', 'F#°']);
      expect(ChordEngine.campoHarmonico('G'), containsAll(['D7', 'D/F#', 'G/B']));
    });

    test('tom com bemol escreve com bemol', () {
      expect(ChordEngine.campoHarmonico('F').take(7), ['F', 'Gm', 'Am', 'Bb', 'C', 'Dm', 'E°']);
    });

    test('tom menor: i ii° III iv v VI VII + V7', () {
      expect(ChordEngine.campoHarmonico('Em').take(7), ['Em', 'F#°', 'G', 'Am', 'Bm', 'C', 'D']);
      expect(ChordEngine.campoHarmonico('Em'), contains('B7'));
    });

    test('todos são acordes que o app entende', () {
      for (final k in ['C', 'D', 'Bb', 'F#', 'Am', 'C#m', 'Gm']) {
        for (final c in ChordEngine.campoHarmonico(k)) {
          expect(ChordEngine.isChordSymbol(c), isTrue, reason: '$k -> $c');
        }
      }
    });

    test('tom vazio ou inválido: nada', () {
      expect(ChordEngine.campoHarmonico(''), isEmpty);
      expect(ChordEngine.campoHarmonico('xyz'), isEmpty);
    });
  });

  group('copiarAcordes', () {
    test('mesma proporção, encostando no começo da palavra', () {
      final src = SongLine('Segura na mão de Deus', [Chord('G', 0), Chord('C', 11), Chord('D', 17)]);
      final dst = SongLine('Pois ela, ela te sustentará', []);
      final r = ChordEngine.copiarAcordes(src, dst);
      expect(r.map((c) => c.sym), ['G', 'C', 'D']);
      for (final c in r) {
        expect(c.idx == 0 || dst.lyric[c.idx - 1] == ' ', isTrue, reason: '${c.sym}@${c.idx}');
      }
      expect(r.first.idx, 0);
    });

    test('linha igual: acordes no mesmo lugar', () {
      final src = SongLine('O Senhor é meu pastor', [Chord('C', 2), Chord('G', 11)]);
      final dst = SongLine('O Senhor é meu pastor', []);
      expect(ChordEngine.copiarAcordes(src, dst).map((c) => c.idx), [2, 11]);
    });

    test('dois acordes não caem na mesma letra', () {
      final src = SongLine('abcdefghij', [Chord('C', 0), Chord('G', 1)]);
      final dst = SongLine('xy', []);
      final idx = ChordEngine.copiarAcordes(src, dst).map((c) => c.idx).toList();
      expect(idx.toSet().length, idx.length);
    });
  });

  test('letra sem acordes vira seções', () {
    final secs = ChordEngine.importText('Primeira linha\nSegunda linha\n\nRefrão linha\nOutra');
    final linhas = secs.expand((s) => s.lines).where((l) => l.lyric.isNotEmpty).toList();
    expect(linhas.map((l) => l.lyric), ['Primeira linha', 'Segunda linha', 'Refrão linha', 'Outra']);
    expect(linhas.every((l) => l.chords.isEmpty), isTrue);
  });

  test('letra buscada vira estrofes e refrão', () {
    final s = Letras.paraSecoes(
      'Se as águas do mar\nSegura na mão\n\nSegura na mão de Deus\ne vai\n\n'
      'Se a jornada é pesada\nSegura\n\r\n  Segura na mão de Deus\ne vai\n',
    );
    expect(s.map((x) => x.name), ['Estrofe 1', 'Refrão', 'Estrofe 2', 'Refrão']);
    expect(s[1].lines.map((l) => l.lyric), ['Segura na mão de Deus', 'e vai']);
  });

  group('Letras.buscar (LRCLIB)', () {
    test('tira repetidas, sem letra e o número da faixa', () async {
      final client = MockClient((req) async {
        expect(req.url.queryParameters['q'], 'segura na mao');
        expect(req.headers['User-Agent'], isNotEmpty);
        return http.Response.bytes(
          utf8.encode(jsonEncode([
            {'trackName': 'Segura na Mão de Deus', 'artistName': 'Padre Marcelo Rossi', 'albumName': 'A', 'plainLyrics': 'Se as águas\ndo mar'},
            {'trackName': 'segura na mão de deus', 'artistName': 'padre marcelo rossi', 'albumName': 'B', 'plainLyrics': 'repetida'},
            {'trackName': 'Instrumental', 'artistName': 'X', 'plainLyrics': null},
            {'trackName': '03 - Segura na Mão', 'artistName': 'Coral', 'albumName': '', 'plainLyrics': 'outra'},
          ])),
          200,
        );
      });
      final r = await Letras.buscar('segura na mao', client: client);
      expect(r.map((x) => x.titulo), ['Segura na Mão de Deus', 'Segura na Mão']);
      expect(r.first.letra, startsWith('Se as águas'));
    });

    test('termo vazio não busca', () async {
      final client = MockClient((_) async => fail('não devia buscar'));
      expect(await Letras.buscar('  ', client: client), isEmpty);
    });
  });
}
