import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/search.dart';
import '../models/song.dart';
import 'acervo.dart';
import 'cloud_state.dart';

/// Um grupo: nome, se está em uso no app, quem participa, quais músicas e
/// repertórios ele tem. Quem é dono do grupo configura tudo; os outros veem.
class GrupoPage extends StatefulWidget {
  final String grupoId;
  const GrupoPage({super.key, required this.grupoId});
  @override
  State<GrupoPage> createState() => _GrupoPageState();
}

class _GrupoPageState extends State<GrupoPage> {
  final _convite = TextEditingController();
  Stream<List<Song>>? _musicas;
  Stream<List<Setlist>>? _repertorios;
  Stream<List<String>>? _confianca;

  @override
  void dispose() {
    _convite.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CloudState>();
    final g = c.grupos.where((x) => x.id == widget.grupoId).firstOrNull;
    if (g == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Grupo não encontrado (foi apagado ou você saiu).')),
      );
    }
    _musicas ??= c.musicasDe(g);
    _repertorios ??= c.repertoriosDe(g);
    _confianca ??= c.confiancaEm(g);
    final dono = g.dono == c.eu;
    final emUso = c.grupo?.id == g.id;
    return Scaffold(
      appBar: AppBar(
        title: Text(_titulo(c, g)),
        actions: [
          if (dono)
            IconButton(
              tooltip: 'Renomear',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _renomear(context, c, g),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _uso(context, c, g, emUso),
          _pessoas(context, c, g, dono),
          _listaMusicas(context, c, g),
          _listaRepertorios(context, g, emUso),
          if (g.membros.length > 1) _editarDireto(context, c, g),
          if (dono && !g.pessoal)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => _apagar(context, c, g),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Apagar grupo'),
              ),
            ),
          if (c.erro != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(c.erro!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
    );
  }

  static String _titulo(CloudState c, Grupo g) =>
      g.pessoal && g.dono == c.eu ? 'Minha biblioteca' : g.nome;

  Widget _card(
    BuildContext context, {
    required IconData icon,
    required String titulo,
    required List<Widget> children,
    Widget? trailing,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  TextStyle _cinza(BuildContext context) => TextStyle(
    fontSize: 13,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );

  Widget _uso(BuildContext context, CloudState c, Grupo g, bool emUso) {
    return _card(
      context,
      icon: emUso ? Icons.check_circle : Icons.radio_button_unchecked,
      titulo: emUso ? 'Em uso no app' : 'Não está em uso',
      children: [
        Text(
          emUso
              ? 'As músicas e os repertórios da tela inicial são deste grupo.'
              : 'Abra p/ ver as músicas e os repertórios deste grupo na tela inicial '
                    'e tocar com eles.',
        ),
        if (!emUso) ...[
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () {
              c.escolherGrupo(g);
              Navigator.popUntil(context, (r) => r.isFirst);
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Usar este grupo'),
          ),
        ],
      ],
    );
  }

  Widget _pessoas(BuildContext context, CloudState c, Grupo g, bool dono) {
    return _card(
      context,
      icon: Icons.people_outline,
      titulo: 'Pessoas (${g.membros.length})',
      children: [
        for (final m in g.membros)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 16,
              child: Text(c.nomeDe(m).isEmpty ? '?' : c.nomeDe(m)[0].toUpperCase()),
            ),
            title: Text('${c.nomeDe(m)}${m == c.eu ? ' (você)' : ''}'),
            subtitle: Text(m == g.dono ? '$m · dono do grupo' : m),
            trailing: dono && m != g.dono
                ? IconButton(
                    icon: const Icon(Icons.person_remove_outlined),
                    tooltip: 'Tirar do grupo',
                    onPressed: () => _tirarPessoa(context, c, g, m),
                  )
                : null,
          ),
        if (dono) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _convite,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'E-mail Google da pessoa'),
                  onSubmitted: (_) => _convidar(c, g),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: () => _convidar(c, g), child: const Text('Adicionar')),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'A pessoa entra no app com esse e-mail e o grupo aparece na lista dela.',
            style: _cinza(context),
          ),
        ],
      ],
    );
  }

  void _convidar(CloudState c, Grupo g) {
    final e = _convite.text.trim().toLowerCase();
    if (e.isNotEmpty) c.convidar(e, g);
    _convite.clear();
  }

  Future<void> _tirarPessoa(BuildContext context, CloudState c, Grupo g, String m) async {
    final ok = await _confirmar(
      context,
      'Tirar ${c.nomeDe(m)} do grupo?',
      'A pessoa deixa de ver as músicas e os repertórios do grupo.',
      'Tirar',
    );
    if (ok) c.remover(m, g);
  }

  Widget _listaMusicas(BuildContext context, CloudState c, Grupo g) {
    return StreamBuilder<List<Song>>(
      stream: _musicas,
      builder: (context, snap) {
        final lista = snap.data ?? const <Song>[];
        return _card(
          context,
          icon: Icons.library_music_outlined,
          titulo: snap.hasData ? 'Músicas (${lista.length})' : 'Músicas',
          trailing: TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _EscolherDoAcervo(
                  grupo: g,
                  ja: {for (final s in lista) if (s.baseId.isNotEmpty) s.baseId},
                ),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Adicionar'),
          ),
          children: [
            if (!snap.hasData)
              const LinearProgressIndicator()
            else if (lista.isEmpty)
              Text('Nenhuma música ainda. Toque em Adicionar p/ trazer do acervo.',
                  style: _cinza(context))
            else
              for (final s in lista)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.title),
                  subtitle: Text(
                    [
                      if (s.key.isNotEmpty) s.key,
                      if (s.artist.isNotEmpty) s.artist,
                      if (s.dono.isNotEmpty) s.dono == c.eu ? 'sua' : 'de ${c.nomeDe(s.dono)}',
                    ].join('  •  '),
                  ),
                  trailing: s.dono == c.eu
                      ? IconButton(
                          tooltip: 'Tirar do grupo',
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () async {
                            final ok = await _confirmar(
                              context,
                              'Tirar "${s.title}" do grupo?',
                              'Sai do grupo e dos repertórios dele. No acervo continua.',
                              'Tirar',
                            );
                            if (ok) c.tirarDoGrupo(g, s);
                          },
                        )
                      : null,
                ),
          ],
        );
      },
    );
  }

  Widget _listaRepertorios(BuildContext context, Grupo g, bool emUso) {
    return StreamBuilder<List<Setlist>>(
      stream: _repertorios,
      builder: (context, snap) {
        final lista = snap.data ?? const <Setlist>[];
        return _card(
          context,
          icon: Icons.queue_music,
          titulo: snap.hasData ? 'Repertórios (${lista.length})' : 'Repertórios',
          children: [
            if (!snap.hasData)
              const LinearProgressIndicator()
            else if (lista.isEmpty)
              Text('Nenhum repertório ainda.', style: _cinza(context))
            else
              for (final sl in lista)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(sl.name),
                  subtitle: Text('${sl.songIds.length} música(s)'),
                ),
            const SizedBox(height: 4),
            Text(
              emUso
                  ? 'Crie e edite os repertórios na aba Repertórios da tela inicial.'
                  : 'P/ criar e editar repertórios, use este grupo (botão lá em cima).',
              style: _cinza(context),
            ),
          ],
        );
      },
    );
  }

  Widget _editarDireto(BuildContext context, CloudState c, Grupo g) {
    final outros = g.membros.where((m) => m != c.eu).toList();
    return StreamBuilder<List<String>>(
      stream: _confianca,
      builder: (context, snap) {
        final atuais = snap.data ?? const <String>[];
        return _card(
          context,
          icon: Icons.edit_note,
          titulo: 'Quem mexe nas suas músicas',
          children: [
            const Text(
              'Normalmente os outros só sugerem mudanças nas suas músicas e você '
              'aceita ou não. Marque quem pode mudar direto, sem pedir:',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in outros)
                  FilterChip(
                    label: Text(c.nomeDe(m)),
                    selected: atuais.contains(m),
                    onSelected: (v) => c.setConfianca(
                      v ? [...atuais, m] : atuais.where((x) => x != m).toList(),
                      g,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _renomear(BuildContext context, CloudState c, Grupo g) async {
    final ctrl = TextEditingController(text: _titulo(c, g));
    final nome = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nome do grupo'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (nome != null && nome.isNotEmpty) c.renomearGrupo(g, nome);
  }

  Future<void> _apagar(BuildContext context, CloudState c, Grupo g) async {
    final ok = await _confirmar(
      context,
      'Apagar "${g.nome}"?',
      'Ninguém mais vê este grupo nem os repertórios dele. As músicas continuam no acervo.',
      'Apagar',
    );
    if (!ok) return;
    await c.apagarGrupo(g);
    if (context.mounted) Navigator.pop(context);
  }

  static Future<bool> _confirmar(
    BuildContext context,
    String titulo,
    String texto,
    String acao,
  ) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(titulo),
          content: Text(texto),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(acao)),
          ],
        ),
      ) ==
      true;
}

/// Escolhe músicas do acervo p/ pôr no grupo (marca várias de uma vez).
class _EscolherDoAcervo extends StatefulWidget {
  final Grupo grupo;
  final Set<String> ja;
  const _EscolherDoAcervo({required this.grupo, required this.ja});
  @override
  State<_EscolherDoAcervo> createState() => _EscolherDoAcervoState();
}

class _EscolherDoAcervoState extends State<_EscolherDoAcervo> {
  String _query = '';
  final Map<String, Song> _marcadas = {};

  @override
  Widget build(BuildContext context) {
    final a = context.watch<AcervoState>();
    final c = context.read<CloudState>();
    final hits = SongSearch.run(a.obras.values.expand((l) => l), _query);
    if (_query.trim().isEmpty) {
      hits.sort((x, y) => SongSearch.fold(x.song.title).compareTo(SongSearch.fold(y.song.title)));
    }
    return Scaffold(
      appBar: AppBar(title: Text('Adicionar a ${widget.grupo.nome}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Buscar no acervo (título, artista ou trecho)...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          if (!a.carregou) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: hits.length,
              itemBuilder: (_, i) {
                final s = hits[i].song;
                final ja = widget.ja.contains(s.id);
                return CheckboxListTile(
                  value: ja || _marcadas.containsKey(s.id),
                  onChanged: ja
                      ? null
                      : (v) => setState(() => v == true ? _marcadas[s.id] = s : _marcadas.remove(s.id)),
                  title: Text(s.title),
                  subtitle: Text(
                    [
                      if (s.key.isNotEmpty) s.key,
                      if (s.artist.isNotEmpty) s.artist,
                      if (s.nomeVersao.isNotEmpty) AcervoState.rotulo(s),
                      if (ja) 'já está no grupo',
                    ].join('  •  '),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _marcadas.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                await c.adicionarAoGrupo(widget.grupo, _marcadas.values.toList(), widget.ja);
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.check),
              label: Text('Adicionar ${_marcadas.length}'),
            ),
    );
  }
}
