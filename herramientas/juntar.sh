#!/usr/bin/env bash
# Deja en $1 los instaladores con nombre fijo y versiones.txt («archivo versión origen»).
# Si una app no tiene versión lista, se avisa y se sigue con las demás.
set -uo pipefail
# Si algo truena, que GitHub muestre dónde (se ve en la corrida sin abrir el registro).
trap 'c=$?; [ $c -ne 0 ] && echo "::error title=Descargas::Terminó con $c en la línea $LINENO: $BASH_COMMAND"' EXIT
trap 'echo "::warning title=Descargas::Falló la línea $LINENO: $BASH_COMMAND"' ERR
SALIDA="$1"; mkdir -p "$SALIDA"; : > "$SALIDA/versiones.txt"
TMP="$(mktemp -d)"

apk() {  # repo carpeta_app nombre_fijo
  local repo="$1" sub="$2" fijo="$3"
  local dir="$TMP/$repo"
  # Solo la configuración de Expo, sin el código ni dependencias.
  if ! gh api "repos/Hgcruz91/$repo/contents/${sub}app.json" --jq .content | base64 -d > "$TMP/$repo.app.json"; then
    echo "::warning title=Descargas::No pude leer app.json de $repo"; return
  fi
  mkdir -p "$dir"
  # Solo lo que eas necesita para ubicar el proyecto: sin plugins (no hay node_modules aquí).
  node -e 'const a=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).expo;
    const e={name:a.name,slug:a.slug,owner:a.owner,version:a.version,extra:{eas:(a.extra||{}).eas}};
    require("fs").writeFileSync(process.argv[2],JSON.stringify({expo:e}))' "$TMP/$repo.app.json" "$dir/app.json"
  gh api "repos/Hgcruz91/$repo/contents/${sub}eas.json" --jq .content | base64 -d > "$dir/eas.json" 2>/dev/null || true
  echo '{"name":"descargas","private":true}' > "$dir/package.json"
  local lista
  listar() { (cd "$dir" && eas build:list --platform android --status finished --limit 10 --json --non-interactive 2>"$TMP/$repo.err" || (EAS_DEBUG=1 eas build:list --platform android --limit 1 --non-interactive >>"$TMP/$repo.err" 2>&1; false)); }
  if ! lista=$(listar); then
    # Si eas-cli pide el paquete expo para leer la configuración, se instala solo ese (sin el resto de la app).
    local ver_expo
    ver_expo=$(gh api "repos/Hgcruz91/$repo/contents/${sub}package.json" --jq .content | base64 -d \
      | node -p 'JSON.parse(require("fs").readFileSync(0,"utf8")).dependencies.expo' 2>/dev/null)
    (cd "$dir" && npm install --no-save --ignore-scripts --no-audit --no-fund "expo@${ver_expo:-latest}" >/dev/null 2>&1)
    if ! lista=$(listar); then
      echo "::warning title=Descargas::Expo no respondió para $repo: $(grep -v '^\s*$' "$TMP/$repo.err" | head -c 600 | tr '\n' ' ') | $(echo "$lista" | head -c 600 | tr '\n' ' ')"; return
    fi
  fi
  local info
  info=$(echo "${lista:$(expr index "$lista" '[')-1}" | node -e '
    let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
      const b=JSON.parse(s).find(x=>x.buildProfile==="preview"&&x.artifacts);
      if(!b){process.exit(2)}
      console.log((b.artifacts.applicationArchiveUrl||b.artifacts.buildUrl)+" "+(b.appVersion||"?")+"+"+(b.appBuildVersion||"?")+" "+b.id)})') || {
    echo "::warning title=Descargas::No hay APK terminado (perfil preview) de $repo"; return; }
  read -r url ver id <<<"$info"
  curl -sSfL "$url" -o "$SALIDA/$fijo" || { echo "::warning title=Descargas::No pude bajar el APK de $repo"; return; }
  echo "$fijo $ver expo:$id" >> "$SALIDA/versiones.txt"
}

ajolote() {  # workflow
  local wf="$1" dir="$TMP/$1"
  local run
  run=$(gh run list -R Hgcruz91/Ajolote-Fiscal --workflow "$wf" --branch main --status success -L 1 --json databaseId --jq '.[0].databaseId')
  [ -n "$run" ] || { echo "::warning title=Descargas::No hay corrida exitosa de $wf en main"; return; }
  gh run download "$run" -R Hgcruz91/Ajolote-Fiscal -D "$dir" || { echo "::warning title=Descargas::No pude bajar los archivos de $wf"; return; }
  while IFS= read -r f; do
    local base fijo ver
    base=$(basename "$f")
    case "$base" in
      *.exe) fijo="AjoloteFiscal-Windows.exe" ;;
      *Intel*.dmg) fijo="AjoloteFiscal-Mac-Intel.dmg" ;;
      *.dmg) fijo="AjoloteFiscal-Mac-Apple.dmg" ;;
      *) continue ;;
    esac
    ver=$(echo "$base" | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)
    cp "$f" "$SALIDA/$fijo"
    echo "$fijo ${ver:-?} run:$run" >> "$SALIDA/versiones.txt"
  done < <(find "$dir" -type f \( -name '*.exe' -o -name '*.dmg' \))
}

# El instalador de Windows que HG arma en su laptop (construir.bat) y sube a un release de
# Ajolote-Fiscal (por ejemplo «v0.7»). Si es igual o más nuevo que el de GitHub Actions, se usa ese.
ajolote_release() {
  local dir="$TMP/release" tag f base ver actual
  tag=$(gh api "repos/Hgcruz91/Ajolote-Fiscal/releases?per_page=10" \
        --jq '[.[] | select(.draft == false and .prerelease == false and any(.assets[]; .name | endswith(".exe")))][0].tag_name // empty')
  [ -n "$tag" ] || return 0
  gh release download "$tag" -R Hgcruz91/Ajolote-Fiscal -p '*.exe' -D "$dir" \
    || { echo "::warning title=Descargas::No pude bajar el .exe del release $tag"; return 0; }
  f=$(find "$dir" -name '*.exe' | head -1)
  [ -n "$f" ] || return 0
  base=$(basename "$f")
  ver=$(echo "$base" | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)
  ver=${ver:-${tag#v}}
  actual=$(awk '$1 == "AjoloteFiscal-Windows.exe" {print $2}' "$SALIDA/versiones.txt" 2>/dev/null || true)
  if [ -n "$actual" ] && [ "$(printf '%s\n%s\n' "$actual" "$ver" | sort -V | tail -1)" != "$ver" ]; then
    echo "El release $tag ($ver) es más viejo que el de Actions ($actual): se queda el de Actions."
    return 0
  fi
  grep -v '^AjoloteFiscal-Windows.exe ' "$SALIDA/versiones.txt" > "$TMP/v.txt" 2>/dev/null || true
  mv "$TMP/v.txt" "$SALIDA/versiones.txt"
  cp "$f" "$SALIDA/AjoloteFiscal-Windows.exe"
  echo "AjoloteFiscal-Windows.exe $ver release:$tag" >> "$SALIDA/versiones.txt"
}

apk Copal "" Copal.apk
apk costeo-artesanal "frontend/" CosteoArtesanal.apk
ajolote windows.yml
ajolote mac.yml
ajolote_release
echo "Esto se juntó:"; cat "$SALIDA/versiones.txt"
[ -s "$SALIDA/versiones.txt" ] || { echo "::error title=Descargas::No se juntó ningún instalador"; exit 1; }
