import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:arion/core/chord_engine.dart';
import 'package:arion/models/song.dart';

String ida(String inline) => ChordEngine.cifraEmCima(ChordEngine.parseSections(inline));
String volta(List<Section> s) =>
    ChordEngine.serializeSections(ChordEngine.importText(ChordEngine.cifraEmCima(s)));

void main() {
  test('acorde em cima da letra', () {
    expect(ida('#Refrão\nO [G]esplendor de um [D]Rei\nsem acorde'),
        '#Refrão\n  G               D\nO esplendor de um Rei\nsem acorde');
  });

  test('acordes grudados ganham espaço', () {
    expect(ida('[G][D/F#]Vem'), 'G D/F#\nVem');
  });

  test('linha só de acordes antes de letra sem acorde vai inline', () {
    final t = ida('#Intro\n[G]  [D]\nletra solta');
    expect(t, '#Intro\n[G]  [D]\nletra solta');
    expect(ChordEngine.importText(t).first.lines.length, 2);
  });

  test('ida e volta mantém a cifra', () {
    const inline = '#Verso\nO [G]esplendor de um [D]Rei\n[Em]Vestido de [C]majestade\n\n'
        '#Refrão\n[C]  [G]  [D]\n[C]Quão gran[G]de é o meu [D]Deus';
    final secs = ChordEngine.importText(inline);
    expect(volta(secs), ChordEngine.serializeSections(secs));
  });

  // biblioteca real (não versionada): ARION_DATA=...json. Só informa.
  test('ida e volta na biblioteca real', () {
    final path = Platform.environment['ARION_DATA'];
    if (path == null) return;
    final j = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final songs = (j['songs'] as List).map((e) => Song.fromJson(e as Map<String, dynamic>));
    var ruins = 0, total = 0;
    for (final s in songs) {
      total++;
      // espaço no fim da linha não conta
      String limpa(String x) => x.split('\n').map((l) => l.trimRight()).join('\n');
      final a = limpa(ChordEngine.serializeSections(s.sections));
      final b = limpa(volta(s.sections));
      if (a == b) continue;
      ruins++;
      final la = a.split('\n'), lb = b.split('\n');
      for (var i = 0; i < la.length; i++) {
        if (i >= lb.length || la[i] != lb[i]) {
          // ignore: avoid_print
          print('${s.title}:\n  antes: ${la[i]}\n  depois: ${i < lb.length ? lb[i] : '(fim)'}');
          break;
        }
      }
    }
    // ignore: avoid_print
    print('DIFERENTES: $ruins de $total');
  });
}
