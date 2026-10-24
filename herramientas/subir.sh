#!/usr/bin/env bash
# Sube al release «ultima» solo los instaladores cuya versión/origen cambió (según versiones.txt).
set -euo pipefail
NUEVO="$1"; REPO="${GITHUB_REPOSITORY}"
if ! gh release view ultima -R "$REPO" >/dev/null 2>&1; then
  gh release create ultima -R "$REPO" --title "Última versión de cada app" \
    --notes "Instaladores de las apps de GC Digital. Se actualiza solo. Descárgalos desde https://gc-digital.mx" >/dev/null
fi
ANTES="$(mktemp)"
gh release download ultima -R "$REPO" -p versiones.txt -O "$ANTES" 2>/dev/null || : > "$ANTES"
cambios=0
while read -r fijo ver origen; do
  if grep -qxF "$fijo $ver $origen" "$ANTES"; then
    echo "Sin cambios: $fijo ($ver)"
  else
    echo "Subiendo $fijo ($ver)..."
    gh release upload ultima "$NUEVO/$fijo" -R "$REPO" --clobber
    cambios=$((cambios + 1))
  fi
done < "$NUEVO/versiones.txt"
# Lo que no se pudo juntar hoy se queda con su versión anterior en versiones.txt.
while read -r fijo resto; do
  grep -q "^$fijo " "$NUEVO/versiones.txt" || echo "$fijo $resto" >> "$NUEVO/versiones.txt"
done < "$ANTES"
gh release upload ultima "$NUEVO/versiones.txt" -R "$REPO" --clobber
{ echo "### Descargas"; echo; echo '```'; cat "$NUEVO/versiones.txt"; echo '```'; echo; echo "Cambios subidos: $cambios"; } >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
