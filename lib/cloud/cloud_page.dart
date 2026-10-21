import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'cloud_config.dart';
import 'cloud_state.dart';
import 'grupo_page.dart';

/// Grupos: quem você é e a lista dos seus grupos (tocar abre o grupo).
class CloudPage extends StatefulWidget {
  const CloudPage({super.key});
  @override
  State<CloudPage> createState() => _CloudPageState();
}

class _CloudPageState extends State<CloudPage> {
  final _emailTeste = TextEditingController();
  final _nomeTeste = TextEditingController();

  @override
  void dispose() {
    _emailTeste.dispose();
    _nomeTeste.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CloudState>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Grupos')),
      floatingActionButton: c.user == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _criarGrupo(context, c),
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('Novo grupo'),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          if (!c.disponivel)
            _card(
              context,
              icon: Icons.cloud_off,
              titulo: 'Nuvem ainda não configurada',
              children: const [Text('Falta configurar o Firebase.')],
            )
          else if (c.user == null)
            _entrar(context, c)
          else if (c.liberado == false) ...[
            _conta(context, c),
            _card(
              context,
              icon: Icons.lock_clock_outlined,
              titulo: 'Acesso ainda não liberado',
              children: [
                Text(
                  'Peça p/ alguém que já usa o Arion te adicionar num grupo '
                  '(pelo e-mail ${c.eu}). Ao ser adicionado, o seu acesso é liberado.',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: c.conferirLiberacao,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Já me adicionaram'),
                ),
              ],
            ),
          ] else ...[
            _conta(context, c),
            _grupos(context, c),
            _envio(context, c),
            _acervo(context),
          ],
          if (c.erro != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(c.erro!, style: TextStyle(color: scheme.error)),
            ),
        ],
      ),
    );
  }

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
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
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

  Widget _entrar(BuildContext context, CloudState c) {
    return _card(
      context,
      icon: Icons.login,
      titulo: 'Entrar',
      children: [
        const Text('Entre com a conta Google p/ ver o acervo e as suas músicas.'),
        const SizedBox(height: 12),
        if (CloudConfig.emulador) ...[
          TextField(
            controller: _emailTeste,
            decoration: const InputDecoration(hintText: 'E-mail (teste)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nomeTeste,
            decoration: const InputDecoration(hintText: 'Nome (teste)'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () =>
                c.entrarTeste(_emailTeste.text.trim(), _nomeTeste.text.trim()),
            child: const Text('Entrar (emulador)'),
          ),
        ] else
          FilledButton.icon(
            onPressed: c.entrar,
            icon: const Icon(Icons.account_circle),
            label: const Text('Entrar com Google'),
          ),
      ],
    );
  }

  Widget _conta(BuildContext context, CloudState c) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        leading: CircleAvatar(
          radius: 22,
          child: Text(c.nome.isEmpty ? '?' : c.nome[0].toUpperCase(),
              style: const TextStyle(fontSize: 20)),
        ),
        title: Text(c.nome, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(c.eu),
        trailing: TextButton(onPressed: c.sair, child: const Text('Sair')),
      ),
    );
  }

  /// Lista dos grupos; tocar abre o grupo p/ configurar.
  Widget _grupos(BuildContext context, CloudState c) {
    // a biblioteca pessoal é criada sozinha no 1º login
    if (c.grupos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Preparando a sua biblioteca...'),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return _card(
      context,
      icon: Icons.groups_outlined,
      titulo: 'Seus grupos',
      children: [
        Text(
          'Cada grupo tem as suas músicas, repertórios e pessoas. O que está em '
          'uso aparece na tela inicial.',
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        for (final g in c.grupos)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              g.pessoal && g.dono == c.eu ? Icons.person_outline : Icons.groups_outlined,
            ),
            title: Text(g.pessoal && g.dono == c.eu ? 'Minha biblioteca' : g.nome),
            subtitle: Text([
              '${g.membros.length} pessoa(s)',
              g.dono == c.eu ? 'você é o dono' : 'de ${c.nomeDe(g.dono)}',
            ].join('  •  ')),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (c.grupo?.id == g.id)
                  Chip(
                    label: const Text('em uso'),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(color: scheme.primary),
                  ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => GrupoPage(grupoId: g.id)),
            ),
          ),
      ],
    );
  }

  Future<void> _criarGrupo(BuildContext context, CloudState c) async {
    final ctrl = TextEditingController();
    final nome = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Novo grupo'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nome (ex.: Ministério de música)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    if (nome != null && nome.isNotEmpty) await c.criarGrupo(nome);
  }

  Widget _acervo(BuildContext context) {
    return _card(
      context,
      icon: Icons.public,
      titulo: 'Acervo geral',
      children: const [
        Text(
          'É a aba Músicas da tela inicial: todas as músicas de quem usa o app. '
          'As suas entram lá sozinhas (continuam suas; os outros só sugerem). '
          'Ao tocar ou pôr no repertório uma do acervo, ela vem p/ as suas '
          'músicas como cópia — dá p/ mudar o tom e as anotações sem mexer na original.',
        ),
      ],
    );
  }

  Widget _envio(BuildContext context, CloudState c) {
    if (!c.carregou) return const SizedBox.shrink();
    final ns = c.songsSoAqui, nr = c.setsSoAqui;
    if (ns == 0 && nr == 0) return const SizedBox.shrink();
    return _card(
      context,
      icon: Icons.cloud_upload_outlined,
      titulo: 'Só neste aparelho',
      children: [
        Text(
          '$ns música(s) e $nr repertório(s) ainda não estão na nuvem. '
          'Enviando, você vira o dono deles.',
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: c.enviarBiblioteca,
          icon: const Icon(Icons.upload),
          label: const Text('Enviar p/ a nuvem'),
        ),
      ],
    );
  }
}
