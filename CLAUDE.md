# Arion

App Flutter de cifras para tocar ao vivo (tablet, celular, Windows). Firebase `arion-cifras`. Antigo MyMusic.

## Comandos
```bash
flutter run -d windows --dart-define-from-file=desktop_oauth.json
flutter test
bash scripts/publicar-apk.sh "notas"   # sobe o +build, gera APKs e cria Release no GitHub
```

## Regras
- Publicar Release só com pedido explícito do usuário. Depois do script, dar push do commit do build.
- PC instalado em `%LOCALAPPDATA%\Programs\Arion\arion.exe`.
- Projeto Firebase antigo `cifras-779b6` é backup: nunca apagar.
- Versão web no repo `arion-web` (mesma nuvem e visual).
