import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../cloud/acervo.dart';
import '../cloud/cloud_state.dart';
import '../core/chord_engine.dart';
import '../core/letras.dart';
import '../data/store.dart';
import '../models/song.dart';
import 'package:provider/provider.dart';

class _ChordDrag {
  final String sym;
  final Chord? origin;
  final SongLine? originLine;
  _ChordDrag(this.sym, this.origin, this.originLine);
}

class SongEditPage extends StatefulWidget {
  final String songId;

  /// Música nova: só entra na biblioteca quando salvar (antes ficava uma
  /// "Nova música" vazia pra trás se a pessoa desistisse).
  final Song? novo;

  /// Versão do acervo geral (salvar grava lá, ou sugere ao dono).
  final Song? acervo;
  const SongEditPage({super.key, required this.songId, this.novo, this.acervo});
  @override
  State<SongEditPage> createState() => _SongEditPageState();

  /// Editor aberto: a sessão ao vivo não abre música por cima dele.
  static int openCount = 0;
}

class _SongEditPageState extends State<SongEditPage> {
  late Song _song;
  late TextEditingController _title;
  late TextEditingController _artist;
  late TextEditingController _key;
  late TextEditingController _text;
  late TextEditingController _notes;
  late TextEditingController _bpm;
  final List<DateTime> _taps = [];
  int _mode = 0; // 0 = Acordes (visual), 1 = Texto
  // música de outra pessoa sem permissão p/ editar: salvar vira sugestão
  late final bool _sugestao;
  late final String _donoNome;
  final List<String> _undo = [];
  String _current = '';

  final List<String> _palette = [
    'C',
    'D',
    'E',
    'F',
    'G',
    'A',
    'B',
    'Cm',
    'Dm',
    'Em',
    'Fm',
    'Gm',
    'Am',
    'Bm',
    'C7',
    'D7',
    'E7',
    'G7',
    'A7',
    'B7',
    'Cmaj7',
    'Dm7',
    'Em7',
    'Gsus4',
    'A/C#',
    'D/F#',
  ];
  // acordes que a pessoa digitou (+), na frente da paleta
  final List<String> _meus = [];

  /// Paleta: os digitados, os do tom (campo harmônico) e os comuns.
  List<String> get _paleta => {
    ..._meus,
    ...ChordEngine.campoHarmonico(_key.text),
    ..._palette,
  }.toList();

  /// Acorde escolhido na paleta p/ pôr com toques na letra (sem arrastar).
  String? _armado;

  @override
  void initState() {
    super.initState();
    SongEditPage.openCount++;
    final src =
        widget.acervo ??
        widget.novo ??
        context.read<AppState>().songById(widget.songId)!;
    final cloud = context.read<CloudState>();
    final acervo = context.read<AcervoState>();
    _sugestao = widget.acervo != null
        ? !acervo.podeEditar(src)
        : widget.novo == null && !cloud.podeEditarSong(src);
    _donoNome = widget.acervo != null
        ? acervo.nomeDe(src.dono)
        : cloud.nomeDe(src.dono);
    _song = src.copy();
    ChordEngine.trimSectionEnds(_song.sections);
    _title = TextEditingController(text: _song.title);
    _artist = TextEditingController(text: _song.artist);
    _key = TextEditingController(text: _song.key);
    _text = TextEditingController(
      text: ChordEngine.serializeSections(_song.sections),
    );
    _notes = TextEditingController(text: _song.notes);
    _bpm = TextEditingController(text: _song.bpm > 0 ? '${_song.bpm}' : '');
    _current = ChordEngine.serializeSections(_song.sections);
    _inicial = _assinatura();
  }

  // ---- alteração não salva ----

  late final String _inicial;

  String _assinatura() {
    final secs = _mode == 1
        ? ChordEngine.importText(_text.text)
        : _song.sections;
    return [
      _title.text.trim(),
      _artist.text.trim(),
      _key.text.trim(),
      _notes.text.trim(),
      _bpm.text.trim(),
      _song.tags.join(','),
      _song.tempos.join(','),
      _song.momentos.join(','),
      '${_song.capo}',
      ChordEngine.serializeSections(secs),
    ].join('');
  }

  // voltar sem salvar perdia tudo calado; agora pergunta
  Future<void> _tentarSair() async {
    if (_assinatura() == _inicial) {
      Navigator.pop(context);
      return;
    }
    final r = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sair sem salvar?'),
        content: const Text('Você mudou esta música e ainda não salvou.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'descartar'),
            child: const Text('Descartar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continuar editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'salvar'),
            child: Text(_sugestao ? 'Enviar sugestão' : 'Salvar'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (r == 'salvar') {
      _save();
    } else if (r == 'descartar') {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _tentarSair();
    },
    child: _page(context),
  );

  // registra mudança p/ undo (snapshot anterior já está em _current)
  void _recordChange() {
    _undo.add(_current);
    if (_undo.length > 40) _undo.removeAt(0);
    _current = ChordEngine.serializeSections(_song.sections);
    setState(() {});
  }

  void _undoLast() {
    if (_undo.isEmpty) return;
    _current = _undo.removeLast();
    setState(() {
      _song.sections = ChordEngine.importText(_current);
    });
  }

  @override
  void dispose() {
    SongEditPage.openCount--;
    _title.dispose();
    _artist.dispose();
    _key.dispose();
    _text.dispose();
    _notes.dispose();
    _bpm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_mode == 1) _applyText();
    _song.title = _title.text.trim().isEmpty
        ? 'Sem título'
        : _title.text.trim();
    _song.artist = _artist.text.trim();
    _song.key = _key.text.trim().isEmpty ? 'C' : _key.text.trim();
    _song.notes = _notes.text.trim();
    _song.bpm = int.tryParse(_bpm.text.trim()) ?? 0;
    if (_sugestao) {
      final nota = await _pedirNota();
      if (nota == null || !mounted) return;
      if (widget.acervo != null) {
        await context.read<AcervoState>().sugerir(_song, nota: nota);
      } else {
        await context.read<CloudState>().sugerir(_song, nota: nota);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sugestão enviada — $_donoNome decide se aceita'),
        ),
      );
      Navigator.pop(context);
      return;
    }
    if (widget.acervo != null) {
      context.read<AcervoState>().salvar(_song);
    } else {
      context.read<AppState>().upsertSong(_song);
    }
    Navigator.pop(context);
  }

  /// Recado opcional junto da sugestão. null = desistiu.
  Future<String?> _pedirNota() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enviar sugestão'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText:
                'Recado p/ o dono (opcional) — ex.: acorde errado no refrão',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  void _applyText() {
    _song.sections = ChordEngine.importText(_text.text);
  }

  void _maybeSuggestKey() {
    if (_key.text.trim().isNotEmpty && _key.text.trim() != 'C') return;
    final k = ChordEngine.suggestKey(_song.sections);
    if (k != null) _key.text = k;
  }

  Future<void> _importDialog() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            const Expanded(child: Text('Importar cifra')),
            TextButton.icon(
              icon: const Icon(Icons.content_paste, size: 18),
              label: const Text('Colar'),
              onPressed: () async {
                final d = await Clipboard.getData(Clipboard.kTextPlain);
                if (d?.text != null) ctrl.text = d!.text!;
              },
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            maxLines: 14,
            style: const TextStyle(fontFamily: 'ChordMono', fontSize: 13),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText:
                  'Cole a cifra aqui (acordes acima da letra ou [G]letra)...',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Importar'),
          ),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      _song.sections = ChordEngine.importText(ctrl.text);
      _text.text = ChordEngine.serializeSections(_song.sections);
      // "Tom: G", "Capo 2", {title: ...} no texto colado preenchem os campos
      final meta = ChordEngine.detectMeta(ctrl.text);
      final t = _title.text.trim();
      if (meta.title != null && (t.isEmpty || t == 'Nova música')) {
        _title.text = meta.title!;
      }
      if (meta.artist != null && _artist.text.trim().isEmpty) {
        _artist.text = meta.artist!;
      }
      if (meta.key != null) _key.text = meta.key!;
      if (meta.capo != null) _song.capo = meta.capo!;
      _maybeSuggestKey();
      _mode = 0;
      _recordChange();
    }
  }

  void _exportText() {
    final t = ChordEngine.serializeSections(
      _mode == 1 ? ChordEngine.importText(_text.text) : _song.sections,
    );
    Clipboard.setData(ClipboardData(text: t));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Cifra copiada (texto)')));
  }

  void _syncTextFromModel() {
    _text.text = ChordEngine.serializeSections(_song.sections);
  }

  Widget _page(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${_sugestao ? 'Sugerir mudança' : 'Editar'}'
          '${widget.acervo != null ? ' — acervo (${AcervoState.rotulo(widget.acervo!)})' : ''}',
        ),
        actions: [
          IconButton(
            tooltip: 'Desfazer',
            icon: const Icon(Icons.undo),
            onPressed: _undo.isEmpty ? null : _undoLast,
          ),
          IconButton(
            tooltip: 'Buscar letra',
            icon: const Icon(Icons.lyrics_outlined),
            onPressed: _buscarLetra,
          ),
          IconButton(
            tooltip: 'Importar cifra',
            icon: const Icon(Icons.paste),
            onPressed: _importDialog,
          ),
          IconButton(
            tooltip: 'Copiar como texto',
            icon: const Icon(Icons.copy),
            onPressed: _exportText,
          ),
          TextButton.icon(
            onPressed: _save,
            icon: Icon(_sugestao ? Icons.outgoing_mail : Icons.check),
            label: Text(_sugestao ? 'Enviar sugestão' : 'Salvar'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_sugestao)
            Container(
              width: double.infinity,
              color: scheme.tertiaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Esta música é de $_donoNome. O que você mudar vai como '
                'sugestão — $_donoNome aceita ou não.',
                style: TextStyle(color: scheme.onTertiaryContainer),
              ),
            ),
          // com o teclado aberto (ou tablet deitado) os campos encolhem e
          // rolam, em vez de estourar a tela
          Flexible(child: SingleChildScrollView(child: _meta(scheme))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('Acordes'),
                  icon: Icon(Icons.touch_app),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('Texto'),
                  icon: Icon(Icons.notes),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) {
                setState(() {
                  if (_mode == 1 && s.first == 0) _applyText();
                  if (_mode == 0 && s.first == 1) _syncTextFromModel();
                  _mode = s.first;
                });
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _mode == 0 ? _visual(scheme) : _textEditor()),
        ],
      ),
    );
  }

  void _tapTempo() {
    final now = DateTime.now();
    if (_taps.isNotEmpty && now.difference(_taps.last).inMilliseconds > 2000) {
      _taps.clear();
    }
    _taps.add(now);
    if (_taps.length >= 2) {
      final intervals = <int>[];
      for (var i = 1; i < _taps.length; i++) {
        intervals.add(_taps[i].difference(_taps[i - 1]).inMilliseconds);
      }
      final avg = intervals.reduce((a, b) => a + b) / intervals.length;
      final bpm = (60000 / avg).round();
      setState(() => _bpm.text = '$bpm');
    }
    if (_taps.length > 6) _taps.removeAt(0);
  }

  void _addTag() async {
    final ctrl = TextEditingController();
    final t = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tag / categoria'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ex.: adoração, ceia, natal',
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    final v = t?.trim().toLowerCase();
    if (v != null && v.isNotEmpty && !_song.tags.contains(v)) {
      setState(() => _song.tags.add(v));
    }
  }

  Widget _meta(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              hintText: 'Título',
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _artist,
                  decoration: const InputDecoration(
                    hintText: 'Artista',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _key,
                  // a paleta de acordes segue o tom
                  onChanged: (_) => setState(() {}),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: 'Tom',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final t in _song.tags)
                Chip(
                  label: Text(t),
                  visualDensity: VisualDensity.compact,
                  onDeleted: () => setState(() => _song.tags.remove(t)),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('tag'),
                visualDensity: VisualDensity.compact,
                onPressed: _addTag,
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _notes,
            maxLines: 2,
            minLines: 1,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Anotações (ex.: entra suave, repete 2x)',
              isDense: true,
              prefixIcon: Icon(Icons.sticky_note_2_outlined, size: 18),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _bpm,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'BPM',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _tapTempo,
                icon: const Icon(Icons.touch_app, size: 18),
                label: const Text('Tap tempo'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- modo TEXTO ----------
  Widget _textEditor() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Use [Acorde] antes da sílaba. Linha com # = seção. Ex.:  O [G]esplendor de um [D]Rei',
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _text,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                fontFamily: 'ChordMono',
                fontSize: 15,
                height: 1.4,
              ),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- modo VISUAL (drag) ----------
  Widget _visual(ColorScheme scheme) {
    return Column(
      children: [
        Expanded(
          child: ReorderableListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            buildDefaultDragHandles: false,
            onReorderItem: (a, b) {
              setState(
                () => _song.sections.insert(b, _song.sections.removeAt(a)),
              );
              _recordChange();
            },
            footer: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton.icon(
                onPressed: _addSection,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar seção'),
              ),
            ),
            children: [
              for (int si = 0; si < _song.sections.length; si++)
                _sectionCard(si, scheme),
            ],
          ),
        ),
        _paletteBar(scheme),
      ],
    );
  }

  Widget _sectionCard(int si, ColorScheme scheme) {
    final sec = _song.sections[si];
    return Card(
      key: ObjectKey(sec),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: si,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.drag_indicator, size: 20),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _renameSection(sec),
                    child: Text(
                      sec.name.isEmpty ? '(sem nome)' : sec.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (v) {
                    if (v == 'rename') _renameSection(sec);
                    if (v == 'copiar') _copiarAcordesDe(sec);
                    if (v == 'dup') {
                      setState(() => _song.sections.insert(si + 1, sec.copy()));
                      _recordChange();
                    }
                    if (v == 'del') {
                      setState(() => _song.sections.removeAt(si));
                      _recordChange();
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'rename',
                      child: Text('Renomear'),
                    ),
                    if (_song.sections.any(
                      (s) =>
                          s != sec && s.lines.any((l) => l.chords.isNotEmpty),
                    ))
                      const PopupMenuItem(
                        value: 'copiar',
                        child: Text('Copiar acordes de outra parte'),
                      ),
                    const PopupMenuItem(value: 'dup', child: Text('Duplicar')),
                    const PopupMenuItem(value: 'del', child: Text('Excluir')),
                  ],
                ),
              ],
            ),
            for (final line in sec.lines)
              _EditableLine(
                line: line,
                chordColor: scheme.primary,
                onChanged: _recordChange,
                onEditChord: (c) => _editChord(line, c),
                armado: _armado,
                onPlace: (idx) => _porArmado(line, idx),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  setState(() => sec.lines.add(SongLine('', [])));
                  _recordChange();
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('linha'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paletteBar(ColorScheme scheme) {
    final paleta = _paleta;
    final doTom = ChordEngine.campoHarmonico(_key.text).toSet();
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Text(
              _armado == null
                  ? 'Toque num acorde e depois na letra onde ele entra — ou arraste p/ cima.'
                  : 'Toque na letra onde entra o $_armado. Toque nele de novo p/ parar.',
              style: TextStyle(
                fontSize: 12,
                color: _armado == null
                    ? scheme.onSurfaceVariant
                    : scheme.primary,
                fontWeight: _armado == null ? null : FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  // no PC também rola arrastando com o mouse (não só a roda)
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: paleta.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (_, i) {
                        if (i == paleta.length) {
                          return ActionChip(
                            label: const Icon(Icons.add, size: 18),
                            onPressed: _addCustomChord,
                          );
                        }
                        final s = paleta[i];
                        return _PaletteChip(
                          sym: s,
                          color: scheme.primary,
                          doTom: doTom.contains(s),
                          selecionado: _armado == s,
                          onTap: () =>
                              setState(() => _armado = _armado == s ? null : s),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Toque na letra com um acorde escolhido: põe ele ali (troca o que já
  /// estava na mesma letra).
  void _porArmado(SongLine line, int idx) {
    final s = _armado;
    if (s == null) return;
    line.chords
      ..removeWhere((c) => c.idx == idx)
      ..add(Chord(s, idx));
    _recordChange();
  }

  /// Estrofe com a mesma melodia: traz os acordes de outra seção.
  Future<void> _copiarAcordesDe(Section dst) async {
    final fontes = _song.sections
        .where((s) => s != dst && s.lines.any((l) => l.chords.isNotEmpty))
        .toList();
    final src = await showDialog<Section>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Copiar acordes de qual parte?'),
        children: [
          for (final s in fontes)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, s),
              child: Text(
                '${s.name.isEmpty ? '(sem nome)' : s.name} — '
                '${s.lines.firstWhere((l) => l.lyric.trim().isNotEmpty, orElse: () => s.lines.first).lyric.trim()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
    if (src == null || !mounted) return;
    final temAcordes = dst.lines.any((l) => l.chords.isNotEmpty);
    if (temAcordes) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Trocar os acordes desta parte?'),
          content: const Text('Os acordes que já estão aqui saem.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Trocar'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    // linha a linha, pulando as vazias dos dois lados
    final de = src.lines
        .where((l) => l.lyric.trim().isNotEmpty || l.chords.isNotEmpty)
        .toList();
    final para = dst.lines.where((l) => l.lyric.trim().isNotEmpty).toList();
    for (var i = 0; i < para.length && i < de.length; i++) {
      para[i].chords = ChordEngine.copiarAcordes(de[i], para[i]);
    }
    _recordChange();
  }

  Future<void> _buscarLetra() async {
    final t = _title.text.trim();
    final termo = [
      if (t.isNotEmpty && t != 'Nova música') t,
      _artist.text.trim(),
    ].where((x) => x.isNotEmpty).join(' ');
    final achada = await showDialog<LetraAchada>(
      context: context,
      builder: (_) => _BuscarLetraDialog(termo: termo),
    );
    if (achada == null || !mounted) return;
    final temLetra = _song.sections.any(
      (s) => s.lines.any((l) => l.lyric.trim().isNotEmpty),
    );
    if (temLetra) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Trocar a letra?'),
          content: const Text('A letra e os acordes que já estão aqui saem.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Trocar'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    _song.sections = Letras.paraSecoes(achada.letra);
    if (t.isEmpty || t == 'Nova música') _title.text = achada.titulo;
    if (_artist.text.trim().isEmpty) _artist.text = achada.artista;
    _mode = 0;
    _syncTextFromModel();
    _recordChange();
  }

  void _addCustomChord() async {
    final ctrl = TextEditingController();
    final sym = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Acorde'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ex.: F#m7'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Usar'),
          ),
        ],
      ),
    );
    final t = sym?.trim() ?? '';
    if (t.isNotEmpty) {
      setState(() {
        if (!_meus.contains(t)) _meus.insert(0, t);
        // já deixa escolhido p/ pôr na letra
        _armado = t;
      });
    }
  }

  void _editChord(SongLine line, Chord c) async {
    final ctrl = TextEditingController(text: c.sym);
    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar acorde'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, '__del__'),
            child: const Text('Excluir'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (res == null) return;
    if (res == '__del__') {
      line.chords.remove(c);
    } else if (res.trim().isNotEmpty) {
      c.sym = res.trim();
    }
    _recordChange();
  }

  void _addSection() {
    setState(
      () => _song.sections.add(Section('Nova seção', [SongLine('', [])])),
    );
    _recordChange();
  }

  void _renameSection(Section sec) async {
    final ctrl = TextEditingController(text: sec.name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nome da seção'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, '__del__'),
            child: const Text('Excluir seção'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (name == null) return;
    setState(() {
      if (name == '__del__') {
        _song.sections.remove(sec);
      } else {
        sec.name = name.trim();
      }
    });
    _recordChange();
  }
}

/// Chip da paleta: tocar escolhe (p/ pôr com toques na letra); arrastar p/
/// cima leva até a letra. Arrastar de lado rola a paleta.
class _PaletteChip extends StatelessWidget {
  final String sym;
  final Color color;
  final bool doTom, selecionado;
  final VoidCallback onTap;
  const _PaletteChip({
    required this.sym,
    required this.color,
    required this.doTom,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chip = GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(
          sym,
          style: TextStyle(
            color: selecionado ? Colors.white : color,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: selecionado ? color : null,
        // os do tom com borda na cor do destaque
        side: doTom && !selecionado
            ? BorderSide(color: color.withValues(alpha: 0.6))
            : null,
        visualDensity: VisualDensity.compact,
      ),
    );
    return Draggable<_ChordDrag>(
      // só o arrasto vertical pega o acorde; o lateral fica p/ a rolagem
      affinity: Axis.vertical,
      data: _ChordDrag(sym, null, null),
      feedback: Material(color: Colors.transparent, child: _ghost(sym, color)),
      child: chip,
    );
  }

  Widget _ghost(String s, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8)),
    child: Text(
      s,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
    ),
  );
}

/// Uma linha editável: letra (monospace) + acordes posicionados/arrastáveis,
/// com DragTarget que calcula a coluna pelo offset do drop.
class _EditableLine extends StatefulWidget {
  final SongLine line;
  final Color chordColor;
  final VoidCallback onChanged;
  final void Function(Chord) onEditChord;

  /// acorde escolhido na paleta: tocar na linha põe ele ali
  final String? armado;
  final void Function(int idx) onPlace;
  const _EditableLine({
    required this.line,
    required this.chordColor,
    required this.onChanged,
    required this.onEditChord,
    required this.armado,
    required this.onPlace,
  });

  @override
  State<_EditableLine> createState() => _EditableLineState();
}

class _EditableLineState extends State<_EditableLine> {
  final _lyricKey = GlobalKey();

  static const _lyricStyle = TextStyle(
    fontFamily: 'ChordMono',
    fontSize: 16,
    height: 1.25,
  );

  double get _charW {
    final tp = TextPainter(
      text: const TextSpan(text: 'M', style: _lyricStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp.size.width;
  }

  // posições x sem overlap (empurra acorde largo p/ direita), por objeto Chord
  Map<Chord, double> _placeX(
    SongLine line,
    TextStyle chordStyle,
    double charW,
  ) {
    final sorted = [...line.chords]..sort((a, b) => a.idx.compareTo(b.idx));
    const gap = 8.0;
    final map = <Chord, double>{};
    double prevRight = -1e9;
    for (final c in sorted) {
      final tp = TextPainter(
        text: TextSpan(text: '${c.sym} ', style: chordStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      var x = c.idx.clamp(0, line.lyric.length) * charW;
      if (x < prevRight + gap) x = prevRight + gap;
      map[c] = x;
      prevRight = x + tp.size.width;
    }
    return map;
  }

  int _idxFromGlobal(Offset global) {
    final box = _lyricKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return 0;
    final local = box.globalToLocal(global);
    final i = (local.dx / _charW).round();
    return i.clamp(0, widget.line.lyric.length);
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    final charW = _charW;
    final chordStyle = TextStyle(
      fontFamily: 'ChordMono',
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: widget.chordColor,
    );
    final xOf = _placeX(line, chordStyle, charW);
    final chordRow = SizedBox(
      height: line.chords.isEmpty ? 20 : 22,
      child: Stack(
        children: [
          for (final c in line.chords)
            Positioned(
              left: xOf[c]!,
              child: Draggable<_ChordDrag>(
                data: _ChordDrag(c.sym, c, line),
                feedback: Material(
                  color: Colors.transparent,
                  child: Text(c.sym, style: chordStyle.copyWith(fontSize: 17)),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: Text(c.sym, style: chordStyle),
                ),
                child: GestureDetector(
                  onTap: () => widget.onEditChord(c),
                  child: Text(c.sym, style: chordStyle),
                ),
              ),
            ),
        ],
      ),
    );

    return DragTarget<_ChordDrag>(
      onAcceptWithDetails: (d) {
        final idx = _idxFromGlobal(d.offset);
        setState(() {
          if (d.data.origin != null && d.data.originLine != null) {
            d.data.originLine!.chords.remove(d.data.origin);
          }
          line.chords.add(Chord(d.data.sym, idx));
        });
        widget.onChanged();
      },
      builder: (context, cand, rej) {
        final box = Container(
          color: cand.isNotEmpty
              ? widget.chordColor.withValues(alpha: 0.08)
              : Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              chordRow,
              Text(
                line.lyric.isEmpty ? ' ' : line.lyric,
                key: _lyricKey,
                style: _lyricStyle,
                maxLines: 1,
                softWrap: false,
                textScaler: TextScaler.noScaling,
              ),
            ],
          ),
        );
        if (widget.armado == null || line.lyric.isEmpty) return box;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => widget.onPlace(_idxFromGlobal(d.globalPosition)),
          child: box,
        );
      },
    );
  }
}

/// Busca a letra no LRCLIB; tocar num resultado mostra a letra p/ conferir.
class _BuscarLetraDialog extends StatefulWidget {
  final String termo;
  const _BuscarLetraDialog({required this.termo});
  @override
  State<_BuscarLetraDialog> createState() => _BuscarLetraDialogState();
}

class _BuscarLetraDialogState extends State<_BuscarLetraDialog> {
  late final _q = TextEditingController(text: widget.termo);
  List<LetraAchada>? _res;
  LetraAchada? _vendo;
  bool _buscando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    if (widget.termo.isNotEmpty) _buscar();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    setState(() {
      _buscando = true;
      _erro = null;
      _vendo = null;
    });
    try {
      final r = await Letras.buscar(_q.text);
      if (mounted) setState(() => _res = r);
    } catch (e) {
      if (mounted)
        setState(() => _erro = 'Não deu p/ buscar (precisa de internet): $e');
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _vendo;
    final cinza = TextStyle(
      fontSize: 12,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return AlertDialog(
      title: Text(v == null ? 'Buscar letra' : v.titulo),
      content: SizedBox(
        width: 560,
        height: 460,
        child: v != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [v.artista, v.album].where((x) => x.isNotEmpty).join(' · '),
                    style: cinza,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: SelectableText(
                        v.letra,
                        style: const TextStyle(height: 1.4),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  TextField(
                    controller: _q,
                    autofocus: widget.termo.isEmpty,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _buscar(),
                    decoration: InputDecoration(
                      hintText: 'Nome da música (e o artista, se souber)',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _buscar,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_buscando) const LinearProgressIndicator(),
                  if (_erro != null)
                    Text(
                      _erro!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  Expanded(
                    child: _res == null
                        ? Center(
                            child: Text(
                              'As letras vêm do LRCLIB (lrclib.net), uma base aberta. '
                              'Os acordes você põe depois.',
                              textAlign: TextAlign.center,
                              style: cinza,
                            ),
                          )
                        : _res!.isEmpty
                        ? Center(
                            child: Text(
                              'Nada encontrado. Tente com o nome do artista.',
                              style: cinza,
                            ),
                          )
                        : ListView.builder(
                            itemCount: _res!.length,
                            itemBuilder: (_, i) {
                              final r = _res![i];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(r.titulo),
                                subtitle: Text(
                                  [
                                    r.artista,
                                    r.letra.split('\n').first,
                                  ].where((x) => x.isNotEmpty).join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => setState(() => _vendo = r),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
      actions: v == null
          ? [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
            ]
          : [
              TextButton(
                onPressed: () => setState(() => _vendo = null),
                child: const Text('Voltar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, v),
                child: const Text('Usar esta letra'),
              ),
            ],
    );
  }
}
