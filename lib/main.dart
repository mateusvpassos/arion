import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'cloud/acervo.dart';
import 'cloud/cloud_config.dart';
import 'cloud/cloud_state.dart';
import 'data/store.dart';
import 'live/live_follower.dart';
import 'live/live_session.dart';
import 'sync/drive_sync.dart';
import 'ui/library_page.dart';
import 'ui/tema.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final state = AppState();
  final sync = SyncState();
  final live = LiveSession(state);
  final cloud = CloudState(state);
  final acervo = AcervoState(cloud, state);
  // com o grupo da nuvem ligado é ele que sincroniza; o Drive vira só backup
  // (dois caminhos mesclando a mesma música davam versão misturada)
  // só Firebase: com ele configurado o Drive não sincroniza mais
  state.onPersist = () {
    if (!CloudConfig.ligado && !CloudConfig.emulador) sync.scheduleAuto(state);
  };
  runApp(
    MyApp(state: state, sync: sync, live: live, cloud: cloud, acervo: acervo),
  );
  // sync só depois do arquivo local carregado: antes os dois corriam juntos e,
  // se a leitura terminasse por último, apagava o que o sync tinha mesclado
  _boot(state, sync, cloud);
}

Future<void> _boot(AppState state, SyncState sync, CloudState cloud) async {
  await state.load();
  await CloudConfig.init();
  await cloud.init();
  // build de teste (emulador do Firebase) nunca encosta no Drive de verdade
  if (CloudConfig.ligado || CloudConfig.emulador) return;
  await sync.trySilent();
  if (sync.signedIn) await sync.sync(state);
}

class MyApp extends StatelessWidget {
  final AppState state;
  final SyncState sync;
  final LiveSession live;
  final CloudState cloud;
  final AcervoState acervo;
  const MyApp({
    required this.acervo,
    super.key,
    required this.state,
    required this.sync,
    required this.live,
    required this.cloud,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: state),
        ChangeNotifierProvider.value(value: sync),
        ChangeNotifierProvider.value(value: live),
        ChangeNotifierProvider.value(value: cloud),
        ChangeNotifierProvider.value(value: acervo),
      ],
      child: Consumer<AppState>(
        builder: (context, st, _) {
          return MaterialApp(
            title: 'MyMusic',
            debugShowCheckedModeBanner: false,
            theme: Tema.de(st.settings.seedColor, st.settings.dark),
            home: const LiveFollower(child: LibraryPage()),
          );
        },
      ),
    );
  }
}
