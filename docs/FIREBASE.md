# Nuvem (Firebase) — como está configurado

Tudo do Arion fica num projeto só: **Arion** (`arion-cifras`, nº 911820467893),
plano gratuito **Spark** (sem cartão: se a cota do dia acabar, para até o dia seguinte; nunca cobra).

Consoles:
- Firebase: https://console.firebase.google.com/project/arion-cifras
- Login Google (clients e tela de consentimento): https://console.cloud.google.com/auth/overview?project=arion-cifras

## O que tem lá

| Peça | Onde | Observação |
|---|---|---|
| **Firestore** | `southamerica-east1` (São Paulo), modo produção | Regras: [`firebase/firestore.rules`](../firebase/firestore.rules) |
| **Authentication** | provedor **Google** ativado | Domínios autorizados: `localhost`, `arion-cifras.firebaseapp.com`, `arion-cifras.web.app`, `mateusvpassos.github.io` |
| App **Android** | `com.mvini.arion` | SHA-1 do `debug.keystore` cadastrado (o APK é assinado com ele) |
| App **Web** | Arion Web | config em `arion-web/src/firebase.ts` |
| Client OAuth **Web** | criado pelo Firebase | usado como `serverClientId` no Android (`lib/cloud/cloud_config.dart`) |
| Client OAuth **Android** | criado pelo Firebase (pacote + SHA-1) | |
| Client OAuth **Arion PC** | tipo "App para computador" | id/secret em `desktop_oauth.json` (fora do git; backup em `D:\backup\`) |
| Tela de consentimento | **Em produção**, tipo Externo | Página inicial e política de privacidade no GitHub Pages (`arion-web/`) |

A config do Firebase (apiKey, appId...) **não é segredo**: o acesso é controlado pelas regras.
Só o `desktop_oauth.json` fica fora do git (o build do PC lê com
`--dart-define-from-file=desktop_oauth.json`).

## Quem pode usar (liberação)

O login Google é aberto a qualquer conta, mas **só lê e grava na nuvem quem está liberado**
(`liberados/{email}`), senão qualquer um gastaria a cota do projeto:

- O dono do app (`mviniciusdospassos@gmail.com`) já começa liberado (`admin()` nas regras).
- **Convidar alguém para um grupo libera a pessoa** na hora — não precisa mexer em console nenhum.
- Quem entra sem ter sido convidado vê "Acesso ainda não liberado" e um botão "Já me adicionaram".
- Tirar a liberação: só o dono do app, apagando o documento em `liberados/` no console do Firestore.

## Mudar as regras

1. Edite [`firebase/firestore.rules`](../firebase/firestore.rules) e rode os testes:
   ```bash
   cd firebase && npm test
   ```
   (precisa de Java; o do Android Studio serve: `JAVA_HOME="C:/Program Files/Android/Android Studio/jbr"`)
2. Firestore → aba **Regras** → cole o arquivo → **Publicar**
   (ou `npx firebase deploy --only firestore:rules --project arion-cifras` depois de `firebase login`).

## Testar sem tocar no projeto de verdade

Emulador local do Firebase (projeto `demo-arion`):
```bash
cd firebase && npm run emu
flutter run --dart-define=ARION_EMU=10.0.2.2   # app no emulador Android
cd ../../arion-web && npm run dev:emu          # web na porta 4174
```

## Se precisar refazer do zero

1. Criar projeto no Firebase (Analytics desligado), Firestore em São Paulo modo produção, Authentication → Google.
2. Registrar Android (`com.mvini.arion` + SHA-1: `keytool -J-Duser.language=en -list -v -keystore %USERPROFILE%\.android\debug.keystore -storepass android`) e Web.
3. Google Cloud → Google Auth Platform: criar client **App para computador**; branding com página inicial e
   política de privacidade; **Publicar app**.
4. Trocar as configs em `lib/cloud/firebase_options.dart`, `lib/cloud/cloud_config.dart` (webClientId),
   `arion-web/src/firebase.ts` e `desktop_oauth.json`; publicar as regras.
5. Dados: a migração de 21/10/2026 copiou tudo do projeto antigo com um script que lê com o login do dono e
   grava com os mesmos IDs, conferindo documento a documento. Backup daquela cópia: `D:\backup\arion-migracao\`.
