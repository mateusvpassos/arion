#!/usr/bin/env bash
# Publica o APK mais recente numa release do GitHub. O site (arion-web) baixa
# sempre de releases/latest/download/arion.apk, então é só rodar isto a cada
# versão nova:
#   bash scripts/publicar-apk.sh "o que mudou"
# Sobe o número do build no pubspec (o Android só atualiza por cima com número
# maior), gera os APKs por arquitetura e cria a release.
set -euo pipefail
cd "$(dirname "$0")/.."

notas="${1:-Versão nova do Arion.}"

linha=$(grep -E '^version:' pubspec.yaml)
nome=$(echo "$linha" | sed -E 's/version: *([^+]+)\+.*/\1/')
build=$(echo "$linha" | sed -E 's/.*\+([0-9]+).*/\1/')
build=$((build + 1))
sed -i -E "s/^version:.*/version: $nome+$build/" pubspec.yaml
tag="v$nome-$build"
echo "== $tag"

flutter build apk --release --split-per-abi

out=build/app/outputs/flutter-apk
dist=build/publicar
rm -rf "$dist" && mkdir -p "$dist"
cp "$out/app-arm64-v8a-release.apk" "$dist/arion.apk"
cp "$out/app-armeabi-v7a-release.apk" "$dist/arion-32bits.apk"

git add pubspec.yaml
git commit -qm "build: $tag"

gh release create "$tag" "$dist/arion.apk" "$dist/arion-32bits.apk" \
  --title "Arion $nome (build $build)" --latest \
  --notes "$notas

- **arion.apk**: quase todo celular/tablet.
- **arion-32bits.apk**: celular antigo, se o outro der \"app não instalado\"."

echo "== publicado. Falta: git push (o commit do número do build)"
