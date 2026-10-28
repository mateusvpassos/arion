import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/chord_engine.dart';
import '../cloud/acervo.dart';
import '../cloud/acervo_page.dart' show ObraPage;
import '../cloud/cloud_page.dart';
import '../cloud/cloud_state.dart';
import '../cloud/suggestions_page.dart';
import '../core/liturgia.dart';
import '../core/search.dart';
import '../data/store.dart';
import '../live/live_page.dart';
import '../live/live_session.dart';
import '../models/song.dart';
import 'minhas_page.dart';
import 'song_view_page.dart';
import 'widgets/song_tile.dart';
import 'song_edit_page.dart';
import 'setlist_page.dart';
import 'settings_page.dart';

/// Botão "pílula" com gradiente (usado como FAB).
class _GradientButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _GradientButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(12);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [scheme.primary, scheme.tertiary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: scheme.onPrimary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Atalho p/ a sessão ao vivo; acende e mostra quantos aparelhos há quando ativa.
class _LiveButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final live = context.watch<LiveSession>();
    final scheme = Theme.of(context).colorScheme;
    final icon = Icon(
      live.active ? Icons.wifi_tethering : Icons.wifi_tethering_off,
      color: live.active
          ? (live.reconnecting ? scheme.error : scheme.primary)
          : null,
    );
    return IconButton(
      tooltip: 'Ao vivo',
      icon: live.active
          ? Badge(label: Text('${live.peers.length}'), child: icon)
          : icon,
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LivePage()),
      ),
    );
  }
}

/// "Arion" + o grupo em uso (tocar abre a lista de grupos).
class _TituloComGrupo extends StatelessWidget {
  const _TituloComGrupo();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CloudState>();
    final g = c.grupo;
    if (g == null) return const Text('Arion');
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CloudPage()),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Arion'),
          Text(
            g.pessoal && g.dono == c.eu ? 'Minha biblioteca ▾' : '${g.nome} ▾',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  String _query = '';

  @override
  void initState() {
    super.initState();
    // se a leitura do acervo tinha sido negada, tenta de novo ao abrir
    final a = context.read<AcervoState>();
    if (a.erro != null || !a.carregou) a.religar();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    if (!st.loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset('assets/icon/icon.png', width: 32, height: 32),
            ),
            const SizedBox(width: 10),
            const Flexible(child: _TituloComGrupo()),
          ],
        ),
        // abas numa cápsula com borda (como no web e no Kino)
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Container(
            height: 44,
            margin: const EdgeInsets.fromLTRB(12, 2, 12, 12),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: TabBar(
              controller: _tab,
              tabs: const [
                Tab(height: 34, text: 'Acervo'),
                Tab(height: 34, text: 'Repertórios'),
              ],
            ),
          ),
        ),
        // celular: Grupos e Configurações vão p/ o menu (senão some o nome do grupo)
        actions: MediaQuery.sizeOf(context).width < 480
            ? [
                const _CloudButtons(comGrupos: false),
                _LiveButton(),
                PopupMenuButton<Widget>(
                  tooltip: 'Mais',
                  onSelected: (p) => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => p),
                  ),
                  itemBuilder: (_) => [
                    if (context.read<CloudState>().disponivel)
                      const PopupMenuItem(
                        value: CloudPage(),
                        child: ListTile(leading: Icon(Icons.group_outlined), title: Text('Grupos')),
                      ),
                    const PopupMenuItem(
                      value: SettingsPage(),
                      child: ListTile(leading: Icon(Icons.tune), title: Text('Configurações')),
                    ),
                  ],
                ),
              ]
            : [
                const _CloudButtons(),
                _LiveButton(),
                IconButton(
                  icon: const Icon(Icons.tune),
                  tooltip: 'Configurações',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  ),
                ),
              ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Buscar no acervo ou nos repertórios...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [_acervoTab(st), _setlistsTab(st)],
            ),
          ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tab,
        builder: (_, _) => _GradientButton(
          icon: Icons.add,
          label: _tab.index == 0 ? 'Música' : 'Repertório',
          onTap: () => _tab.index == 0 ? _newSong(st) : _newSetlist(st),
        ),
      ),
    );
  }

  /// Aba Músicas = acervo geral: uma linha por obra (a versão principal).
  /// Tocar abre a MINHA cópia (tom, anotações, repertórios); sem cópia, a do acervo.
  Widget _acervoTab(AppState st) {
    final a = context.watch<AcervoState>();
    final cloud = context.watch<CloudState>();
    final scheme = Theme.of(context).colorScheme;
    if (a.esperandoLiberacao) {
      return _empty(
        'Acesso ainda não liberado: peça p/ alguém que usa o app te adicionar num grupo',
        Icons.lock_clock_outlined,
      );
    }
    if (!a.ligado) {
      return _empty('Entre com o Google (ícone de pessoas lá em cima)', Icons.public);
    }
    final obras = a.obras;
    final obraDaPrincipal = {for (final e in obras.entries) e.value.first.id: e.key};
    final hits = SongSearch.run(obras.values.map((l) => l.first), _query);
    if (_query.trim().isEmpty) {
      hits.sort((x, y) => SongSearch.fold(x.song.title).compareTo(SongSearch.fold(y.song.title)));
    }
    final uso = UsoMusicas.calcula(st.setlists);
    return Column(
      children: [
        if (!a.carregou) const LinearProgressIndicator(),
        if (a.erro != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(child: Text(a.erro!, style: TextStyle(color: scheme.error))),
                TextButton(onPressed: a.religar, child: const Text('Tentar de novo')),
              ],
            ),
          ),
        Expanded(
          child: hits.isEmpty
              ? (a.carregou && _query.isEmpty
                  ? _empty(
                      'O acervo ainda está vazio',
                      Icons.library_music,
                      dica: 'Cole uma cifra (do Cifra Club, por exemplo) ou digite a sua. '
                          'Ela fica nas suas músicas e no acervo, para o seu grupo tocar junto.',
                      acao: 'Criar a primeira música',
                      onAcao: () => _newSong(st),
                    )
                  : _empty(a.carregou ? 'Nada encontrado' : 'Carregando...', Icons.library_music))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                  itemCount: hits.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final v = hits[i].song;
                    final obra = obraDaPrincipal[v.id]!;
                    final n = obras[obra]!.length;
                    final copia = a.copiaDaObra(obra);
                    final u = copia == null ? null : uso[copia.id];
                    return SongTile(
                      title: v.title,
                      keyLabel: v.key,
                      trecho: hits[i].snippet,
                      tags: v.tags,
                      meta: [
                        if (v.artist.isNotEmpty) v.artist,
                        if (v.dono.isNotEmpty && v.dono != cloud.eu) 'de ${a.nomeDe(v.dono)}',
                        if (n > 1) '$n versões',
                        if (u != null) 'tocada ${UsoMusicas.quando(u.ultima)} (${u.vezes}x)',
                      ].join('  •  '),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SongViewPage(songId: copia?.id ?? v.id)),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (copia != null)
                            Tooltip(
                              message: 'Está nas suas músicas',
                              child: Icon(Icons.library_add_check, color: scheme.primary),
                            ),
                          PopupMenuButton<String>(
                            onSelected: (op) {
                              if (op == 'add') {
                                final c = a.puxar(v);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('"${c.title}" está nas suas músicas')),
                                );
                              } else if (op == 'versoes') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ObraPage(obra: obra)),
                                );
                              } else if (op == 'edit') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SongEditPage(songId: v.id, acervo: v),
                                  ),
                                );
                              }
                            },
                            itemBuilder: (_) => [
                              if (copia == null)
                                const PopupMenuItem(value: 'add', child: Text('Adicionar às minhas músicas')),
                              PopupMenuItem(
                                value: 'versoes',
                                child: Text(n > 1 ? 'Ver versões' : 'Versões e detalhes'),
                              ),
                              PopupMenuItem(
                                value: 'edit',
                                child: Text(a.podeEditar(v)
                                    ? 'Editar (${AcervoState.rotulo(v)})'
                                    : 'Sugerir mudança'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Widget _setlistsTab(AppState st) {
    if (st.setlists.isEmpty) {
      return _empty(
        'Nenhum repertório ainda',
        Icons.queue_music,
        dica: 'Monte a lista de um culto, show ou ensaio: as músicas na ordem, cada uma no tom do dia.',
        acao: 'Criar repertório',
        onAcao: () => _newSetlist(st),
      );
    }
    final q = SongSearch.fold(_query.trim());
    // com data primeiro (mais recente no topo), depois sem data
    final list =
        [
          ...st.setlists.where(
            (x) => q.isEmpty || SongSearch.fold(x.name).contains(q),
          ),
        ]..sort((a, b) {
          if (a.date != null && b.date != null) {
            return b.date!.compareTo(a.date!);
          }
          if (a.date != null) return -1;
          if (b.date != null) return 1;
          return b.updatedAt.compareTo(a.updatedAt);
        });
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final sl = list[i];
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            leading: const Icon(Icons.queue_music),
            title: Text(
              sl.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
            ),
            subtitle: Builder(
              builder: (context) {
                final c = context.watch<CloudState>();
                return Text(
                  [
                    if (sl.date != null) _fmtDate(sl.date!),
                    '${sl.songIds.length} músicas',
                    if (c.ativa && sl.dono.isNotEmpty && sl.dono != c.eu)
                      'de ${c.nomeDe(sl.dono)}',
                  ].join('  •  '),
                );
              },
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'dup') st.duplicateSetlist(sl);
                if (v == 'del') {
                  _confirmDelete(
                    'Excluir "${sl.name}"?',
                    () => st.deleteSetlist(sl.id),
                  );
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'dup', child: Text('Duplicar')),
                // no grupo só o dono apaga
                if (context.read<CloudState>().souDono(sl.dono))
                  const PopupMenuItem(value: 'del', child: Text('Excluir')),
              ],
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SetlistPage(setlistId: sl.id)),
            ),
          ),
        );
      },
    );
  }

  /// Lista vazia; com [acao], explica o que fazer e já oferece o botão.
  Widget _empty(String msg, IconData icon, {String? dica, String? acao, VoidCallback? onAcao}) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: acao == null ? Theme.of(context).disabledColor : scheme.primary),
            const SizedBox(height: 12),
            Text(
              msg,
              style: acao == null
                  ? TextStyle(color: Theme.of(context).disabledColor)
                  : const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            if (dica != null) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(dica, textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14)),
              ),
            ],
            if (acao != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: onAcao, icon: const Icon(Icons.add), label: Text(acao)),
            ],
          ],
        ),
      ),
    );
  }

  void _newSong(AppState st) {
    final s = Song(id: ChordEngine.uid(), title: '');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SongEditPage(songId: s.id, novo: s),
      ),
    );
  }

  void _newSetlist(AppState st) async {
    final ctrl = TextEditingController();
    // data do evento: é o que dá o histórico de "tocada há X semanas"
    final hoje = DateTime.now();
    var data = DateTime(hoje.year, hoje.month, hoje.day);
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final name = await showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDlg) => AlertDialog(
          title: const Text('Novo repertório'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Nome'),
                onSubmitted: (v) => Navigator.pop(context, v),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: Text(fmt(data)),
                subtitle: const Text('Data do evento'),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: data,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setDlg(() => data = d);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: const Text('Criar'),
            ),
          ],
        ),
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      st.upsertSetlist(
        Setlist(id: ChordEngine.uid(), name: name.trim(), date: data),
      );
    }
  }

  void _confirmDelete(String msg, VoidCallback onYes) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onYes();
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}

/// Nuvem: sugestões esperando (com contador) e o grupo.
class _CloudButtons extends StatelessWidget {
  const _CloudButtons({this.comGrupos = true});
  final bool comGrupos;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CloudState>();
    final a = context.watch<AcervoState>();
    if (!c.disponivel) return const SizedBox.shrink();
    final n = c.paraDecidir.length + a.paraDecidir.length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (c.ativa)
          IconButton(
            tooltip: 'Minhas músicas',
            icon: const Icon(Icons.library_music_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MinhasMusicasPage()),
            ),
          ),
        if (c.user != null)
          IconButton(
            tooltip: 'Sugestões',
            icon: Badge(
              isLabelVisible: n > 0,
              label: Text('$n'),
              child: const Icon(Icons.inbox_outlined),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SuggestionsPage()),
            ),
          ),
        if (comGrupos) IconButton(
          tooltip: 'Grupos',
          icon: Icon(c.ativa ? Icons.group_outlined : Icons.cloud_off_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CloudPage()),
          ),
        ),
      ],
    );
  }
}
