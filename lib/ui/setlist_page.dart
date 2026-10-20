import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../cloud/acervo.dart';
import '../cloud/cloud_state.dart';
import '../cloud/permissions_sheet.dart';
import '../core/chord_engine.dart';
import '../core/docx_export.dart';
import '../core/image_export.dart';
import '../core/liturgia.dart';
import '../core/pdf_export.dart';
import '../core/search.dart';
import '../core/text_export.dart';
import '../data/store.dart';
import '../models/song.dart';
import 'song_view_page.dart';

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Cifras já no tom escolhido no repertório — é isso que tem que sair na
/// exportação, não o tom original da música.
List<Song> _noTomDoRepertorio(Setlist sl, List<Song> songs) => songs.map((s) {
  final steps = sl.transpose[s.id] ?? 0;
  return steps == 0 ? s.copy() : ChordEngine.transposeSong(s, steps);
}).toList();

Color _strong(int seed) {
  final hsl = HSLColor.fromColor(Color(seed));
  return hsl
      .withSaturation((hsl.saturation * 1.25).clamp(0.85, 1.0))
      .withLightness(0.42)
      .toColor();
}

class SetlistPage extends StatelessWidget {
  final String setlistId;
  const SetlistPage({super.key, required this.setlistId});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final sl = st.setlists.firstWhere(
      (s) => s.id == setlistId,
      orElse: () => Setlist(id: '', name: '—'),
    );
    final songs = sl.songIds
        .map((id) => st.songById(id))
        .whereType<Song>()
        .toList();
    final cloud = context.watch<CloudState>();
    // repertório de outra pessoa sem permissão: só ver/tocar/exportar
    final pode = cloud.podeEditarSetlist(sl);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(sl.name),
            if (sl.date != null)
              Text(
                _fmtDate(sl.date!),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
          ],
        ),
        actions: [
          if (cloud.ativa)
            IconButton(
              icon: const Icon(Icons.manage_accounts_outlined),
              tooltip: 'Dono e quem pode editar',
              onPressed: () => showPermissions(
                context,
                titulo: sl.name,
                dono: sl.dono,
                editores: sl.editores,
                salvar: (l) => cloud.setEditoresSetlist(sl, l),
              ),
            ),
          if (pode)
            IconButton(
              icon: const Icon(Icons.event),
              tooltip: 'Data do evento',
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: sl.date ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (d != null) {
                  sl.date = d;
                  st.upsertSetlist(sl);
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.play_circle_fill),
            tooltip: 'Iniciar',
            onPressed: songs.isEmpty
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SongViewPage(
                        songId: songs.first.id,
                        setlistId: sl.id,
                        setlistSongIds: List.of(sl.songIds),
                      ),
                    ),
                  ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Exportar',
            enabled: songs.isNotEmpty,
            onSelected: (v) {
              final cor = _strong(st.settings.seedColor);
              final cifras = _noTomDoRepertorio(sl, songs);
              if (v == 'img') {
                ImageExport.shareSetlist(
                  sl.name,
                  cifras.map((s) => s.title).toList(),
                  chordColor: cor,
                );
              } else if (v == 'txt') {
                TextExport.shareSetlistLyrics(sl.name, cifras);
              } else if (v == 'pdf') {
                PdfExport.printSetlist(
                  sl.name,
                  cifras,
                  colorArgb: cor.toARGB32(),
                );
              } else if (v == 'docx') {
                DocxExport.shareSetlist(sl.name, cifras, chordColor: cor);
              }
              st.logEvent(
                'exportou',
                'repertorio',
                sl.name,
                details: [
                  'Formato: ${v.toUpperCase()}',
                  '${songs.length} música(s)',
                ],
              );
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pdf', child: Text('PDF (todas as cifras)')),
              PopupMenuItem(value: 'docx', child: Text('Word (.docx)')),
              PopupMenuItem(value: 'img', child: Text('Imagem da lista')),
              PopupMenuItem(
                value: 'txt',
                child: Text('Letras (TXT) — cantores'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (!pode)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.tertiaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Repertório de ${cloud.nomeDe(sl.dono)} — só leitura. '
                'Para montar o seu, use Duplicar na lista de repertórios.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          Expanded(child: _corpo(context, st, sl, songs, pode)),
        ],
      ),
      floatingActionButton: !pode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _addSongs(context, st, sl),
              icon: const Icon(Icons.add),
              label: const Text('Músicas'),
            ),
    );
  }

  Widget _corpo(
    BuildContext context,
    AppState st,
    Setlist sl,
    List<Song> songs,
    bool pode,
  ) {
    return songs.isEmpty
        ? Center(
            child: Text(
              'Vazio — adicione músicas',
              style: TextStyle(color: Theme.of(context).disabledColor),
            ),
          )
        : ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
            buildDefaultDragHandles: pode,
            itemCount: songs.length,
            // índices são da lista VISÍVEL; songIds pode ter música que não
            // existe mais aqui (excluída em outro aparelho) — por isso
            // reordena os visíveis e deixa os órfãos no fim
            onReorderItem: (a, b) {
              final ids = songs.map((s) => s.id).toList();
              ids.insert(b, ids.removeAt(a));
              sl.songIds = [
                ...ids,
                ...sl.songIds.where((x) => !ids.contains(x)),
              ];
              st.upsertSetlist(sl);
            },
            itemBuilder: (_, i) {
              final s = songs[i];
              return Card(
                key: ValueKey(s.id),
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: ListTile(
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text(
                    s.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${s.key}${s.artist.isNotEmpty ? '  •  ${s.artist}' : ''}',
                  ),
                  trailing: !pode
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () {
                                sl.songIds.remove(s.id);
                                st.upsertSetlist(sl);
                              },
                            ),
                            const Icon(Icons.drag_handle),
                          ],
                        ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SongViewPage(
                        songId: s.id,
                        setlistId: sl.id,
                        setlistSongIds: List.of(sl.songIds),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
  }

  void _addSongs(BuildContext context, AppState st, Setlist sl) {
    final data = sl.date ?? DateTime.now();
    // uso ANTES da data do repertório, sem contar ele mesmo
    final uso = UsoMusicas.calcula(st.setlists, ate: data, exceto: sl.id);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        var busca = '';
        String? tag; // filtro
        return StatefulBuilder(
          builder: (context, setSheet) {
            final scheme = Theme.of(context).colorScheme;
            // minhas músicas + as do acervo que ainda não tenho (marcar puxa a cópia)
            final ac = context.read<AcervoState>();
            final doAcervo = [
              for (final e in ac.obras.entries)
                if (ac.copiaDaObra(e.key) == null) e.value.first,
            ];
            bool daBiblioteca(Song s) => st.songById(s.id) != null;
            final todas = [...st.songs, ...doAcervo];
            final tags = {for (final s in todas) ...s.tags}.toList()..sort();
            var achadas = SongSearch.run(todas, busca);
            if (tag != null) {
              achadas = achadas.where((h) => h.song.tags.contains(tag)).toList();
            }
            if (busca.trim().isEmpty) {
              // primeiro as que faz mais tempo que não toca
              DateTime quando(Song s) =>
                  uso[s.id]?.ultima ?? DateTime.utc(1900);
              achadas.sort((a, b) => quando(a.song).compareTo(quando(b.song)));
            }
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              builder: (_, controller) => ListView(
                controller: controller,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Buscar por nome ou trecho da letra...',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                      onChanged: (v) => setSheet(() => busca = v),
                    ),
                  ),
                  if (tags.isNotEmpty)
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          for (final t in tags) ...[
                            ChoiceChip(
                              label: Text(t),
                              selected: tag == t,
                              onSelected: (v) => setSheet(() => tag = v ? t : null),
                            ),
                            const SizedBox(width: 4),
                          ],
                        ],
                      ),
                    ),
                  if (achadas.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        tag != null
                            ? 'Nenhuma música com a tag "$tag".'
                            : 'Nenhuma música encontrada.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  for (final h in achadas)
                    CheckboxListTile(
                      value: sl.songIds.contains(h.song.id),
                      title: Text(h.song.title),
                      subtitle: Text(
                        [
                          h.song.key,
                          if (uso[h.song.id] case final u?)
                            'tocada ${UsoMusicas.quando(u.ultima, hoje: data)} (${u.vezes}x)'
                          else
                            'nunca tocada',
                          if (h.snippet != null) '“${h.snippet}”',
                        ].join('  •  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      secondary: !daBiblioteca(h.song)
                          ? Tooltip(
                              message: 'Do acervo geral — entra nas suas músicas ao marcar',
                              child: Icon(Icons.public, size: 18, color: scheme.outline),
                            )
                          : const SizedBox(width: 18), // alinha os títulos
                      onChanged: (v) {
                        final id = daBiblioteca(h.song) || v != true
                            ? h.song.id
                            : ac.puxar(h.song).id;
                        if (v == true) {
                          if (!sl.songIds.contains(id)) sl.songIds.add(id);
                        } else {
                          sl.songIds.remove(id);
                          sl.moments.remove(id);
                        }
                        st.upsertSetlist(sl);
                        setSheet(() {});
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
