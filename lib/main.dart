import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'cloud/acervo.dart';
import 'cloud/cloud_config.dart';
import 'cloud/cloud_state.dart';
import 'data/store.dart';
import 'live/live_follower.dart';
import 'live/live_session.dart';
import 'ui/library_page.dart';
import 'ui/tema.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final state = AppState();
  final live = LiveSession(state);
  final cloud = CloudState(state);
  final acervo = AcervoState(cloud, state);
  runApp(MyApp(state: state, live: live, cloud: cloud, acervo: acervo));
  // nuvem só depois do arquivo local carregado: antes os dois corriam juntos e,
  // se a leitura terminasse por último, apagava o que a nuvem tinha mesclado
  _boot(state, cloud);
}

Future<void> _boot(AppState state, CloudState cloud) async {
  await state.load();
  await CloudConfig.init();
  await cloud.init();
}

class MyApp extends StatelessWidget {
  final AppState state;
  final LiveSession live;
  final CloudState cloud;
  final AcervoState acervo;
  const MyApp({
    required this.acervo,
    super.key,
    required this.state,
    required this.live,
    required this.cloud,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: state),
        ChangeNotifierProvider.value(value: live),
        ChangeNotifierProvider.value(value: cloud),
        ChangeNotifierProvider.value(value: acervo),
      ],
      child: Consumer<AppState>(
        builder: (context, st, _) {
          return MaterialApp(
            title: 'Arion',
            debugShowCheckedModeBanner: false,
            theme: Tema.de(st.settings.seedColor, st.settings.dark),
            home: const LiveFollower(child: LibraryPage()),
          );
        },
      ),
    );
  }
}
