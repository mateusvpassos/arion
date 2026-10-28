# 🎵 Arion

> Cifras, acordes e letras para tocar ao vivo — pensado para **tablet** (também roda em celular).

App feito em **Flutter** (Android, Windows e iOS), focado em ser **bonito, rápido e fácil de usar no palco**: marcar músicas, transpor na hora, montar repertórios e virar páginas com um pedal Bluetooth. Tem também a versão web: [arion-web](https://github.com/mateusvpassos/arion-web) — https://mateusvpassos.github.io/arion-web/.

![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?logo=flutter&logoColor=white)
![Android](https://img.shields.io/badge/Android-tablet%20%26%20phone-3DDC84?logo=android&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-PC-0078D4?logo=windows&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-iPad%20%26%20iPhone-000000?logo=apple&logoColor=white)
![Offline](https://img.shields.io/badge/Offline-first-success)
![Licença](https://img.shields.io/badge/uso-pessoal-lightgrey)

---

## ✨ Recursos

### No palco
- **Modo apresentação** com acorde sobre a letra, alinhamento exato (fonte monoespaçada embutida)
- **Transpor** o tom (+/–) e **capotraste** com um toque
- **Tela cheia** (immersive) — esconde tudo, só a cifra
- **Auto-scroll** com velocidade ajustável + **tela sempre ligada** (wakelock)
- **Pedal Bluetooth** (page-turner): avançar/voltar/rolar — teclas configuráveis
- **Trocar de música** arrastando para o lado (com animação) ou pelo pedal no fim da cifra
- **A– / A+** para ajustar a fonte na hora, sem abrir menus
- **Refrão destacado** e **diagramas de acorde** (toque no acorde para ver a pegada)

### Ao vivo (vários aparelhos)
- **Sessão pela rede Wi-Fi** (pode ser o roteador do celular): um aparelho cria, os outros acham na lista ou digitam o IP
- Quem **conduz** troca de música, muda o tom e rola a tela → quem **segue** acompanha na hora (a música vai junto, mesmo que o outro não tenha)
- **Um condutor por vez** — assumir rebaixa o anterior, com aviso
- Editar música/repertório em qualquer aparelho atualiza os outros; exclusão não se propaga
- Reconecta sozinho se o Wi-Fi cair; tela não apaga durante a sessão

### Organização
- **Biblioteca** com busca **sem acento** e **por trecho da letra**, **tags/categorias** e filtro
- **Repertórios** (setlists) reordenáveis, com **tom salvo por música**, **duplicar** e, ao adicionar músicas, filtro por tag e "tocada há X"
- Editor **simples**: toque num acorde da paleta e depois na letra (ou arraste p/ cima); a paleta segue o **tom** (campo harmônico primeiro)
- **Buscar letra** no [LRCLIB](https://lrclib.net) (base aberta): título, artista e letra já em estrofes e refrão
- **Copiar acordes** de uma estrofe p/ outra com a mesma melodia
- **Importar cifra** colada no formato "acorde acima da letra" (Cifra Club, inclusive o bug de copiar/colar do site), ChordPro (`{title}`, `{c:}`, `{soc}`) ou com `Tom:`/`Capo` no texto
- Entende `D7/9`, `Bø`, `B7(4/9)`, marcações `(2x)`, `|`, `N.C.` e seções por extenso (`Refrão:`, `1ª Parte`, `Intro: C G`)
- **Histórico** de tudo o que mudou (o quê, quando, de qual aparelho)
- **Desfazer** (undo) na edição

### Backup & exportar
- Tudo fica no aparelho (`arion_data.json`) e na nuvem (Firebase) — funciona sem internet e sobe quando voltar
- **Exportar / importar JSON** (backup completo)
- **PDF** (1 ou 2 colunas, encaixa na página), **Word (.docx)**, **imagem** e **TXT só letras** — da música ou do repertório inteiro no tom do repertório

### Grupos e acervo (nuvem — Firebase)
- **Acervo geral**: as músicas de todo mundo que usa o app (as suas entram sozinhas; continuam suas)
- **Grupos** (banda, coral, ministério...): lista, criar, renomear, apagar, pessoas e quais músicas estão no grupo; o grupo em uso aparece na tela inicial
- Login Google aberto, mas a nuvem só funciona p/ quem foi **convidado p/ um grupo** (protege a cota)
- **Quem cria é o dono**; os outros **sugerem** (o editor vira "Sugerir mudança") e o dono aceita ou recusa vendo a diferença linha a linha
- **Histórico de versões** de cada música (quem, quando, o que mudou) e **voltar a qualquer versão**
- Dono **libera** pessoas por música/repertório ou para tudo dele; repertório dos outros fica só leitura
- Regras de segurança no servidor: [`firebase/firestore.rules`](firebase/firestore.rules) (testes: `cd firebase && npm test`)
- Como está configurado e como mexer: [`docs/FIREBASE.md`](docs/FIREBASE.md)
- Teste local sem tocar no Google: `cd firebase && npm run emu` e `flutter run --dart-define=ARION_EMU=10.0.2.2`

### Aparência
- Tema claro/escuro, **8 cores** à escolha, tamanho de fonte ajustável

---

## 🚀 Build & instalação

Pré-requisitos: Flutter (canal stable). Android: Android Studio (JDK + SDK). Windows: Visual Studio Build Tools e o **Modo de Desenvolvedor** ligado. iOS: Mac com Xcode (não compila no Windows).

```bash
flutter pub get
flutter build apk --release          # Android
flutter build windows --release --dart-define-from-file=desktop_oauth.json   # PC (client OAuth desktop, fora do git)
flutter build ios --release --no-codesign   # iOS, no Mac
```

APK gerado em:
```
build/app/outputs/flutter-apk/app-release.apk
```

Instalar no tablet via USB (depuração ativada):
```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```
…ou copie o `.apk` para o aparelho e abra (permitir "fontes desconhecidas").

> O APK é assinado com a chave de debug deste PC (`%USERPROFILE%\.android\debug.keystore`, backup em `D:\backup\android\`).
> Gere sempre com a mesma chave: com outra, o Android não atualiza por cima e o login Google do Android para (o SHA-1 está cadastrado no Firebase).

PC: o build sai em `build\windows\x64\runner\Release\` (`arion.exe` + DLLs); a instalação atual copia essa pasta p/ `%LOCALAPPDATA%\Programs\Arion` e cria o atalho.

Rodar em modo dev (hot reload):
```bash
flutter run                 # Android
flutter run -d ios          # iPhone/iPad, no Mac
```

O alvo iOS usa o mesmo código do Android (`lib/`). Bundle: `com.mvini.arion`. No Mac, abra `ios/Runner.xcworkspace` no Xcode. A sessão ao vivo na rede local já está liberada no `Info.plist`. Login Google e a nuvem no iOS ficam desligados até registrar o app iOS no Firebase (`firebaseIos` em `lib/cloud/firebase_options.dart`) — sem isso o app abre e funciona offline.

Testes do motor de cifras:
```bash
flutter test
```

---

## ☁️ Nuvem

Firebase, login Google, clients OAuth e regras: [`docs/FIREBASE.md`](docs/FIREBASE.md).

---

## 🧱 Arquitetura

```
lib/
├── core/
│   ├── chord_engine.dart   # parser ChordPro + acorde-sobre-letra, transpose, modelo (Dart puro, testado)
│   ├── chord_shapes.dart   # geração de diagramas de acorde (formas móveis E/A)
│   ├── pedal.dart          # mapeamento de teclas do pedal
│   ├── chart_layout.dart   # encaixe em colunas/fonte (compartilhado PDF e DOCX)
│   ├── pdf_export.dart     # PDF / impressão
│   ├── docx_export.dart    # Word
│   ├── search.dart         # busca sem acento + trecho da letra
│   ├── letras.dart         # busca de letra no LRCLIB
│   └── liturgia.dart       # "tocada há X" (uso das músicas nos repertórios)
├── cloud/                  # Firebase: login, grupos, acervo, sugestões, versões, permissões
├── live/                   # sessão ao vivo: hub WebSocket + descoberta UDP + tela
├── data/store.dart         # estado global (ChangeNotifier) + persistência JSON
├── models/song.dart        # Song · Section · Line · Chord · Setlist · Settings
├── sync/                   # login Google no PC (desktop_auth)
└── ui/                     # biblioteca, apresentação, editor, repertórios, configurações
```

O **núcleo de cifras** (`core/`) é Dart puro, sem dependência de UI — fácil de testar e portar.

---

## 🗺️ Roadmap

- [ ] Chave própria de assinatura do Android (hoje é a de debug)
- [ ] Instalador do PC com atualização automática
- [ ] Opção de seguir sem pegar o tom de quem conduz (ex.: teclado sem capo)

---

<p align="center"><i>Feito com 🎶.</i></p>
