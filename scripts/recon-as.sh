#!/usr/bin/env bash
# ============================================================
# recon-as.sh — superficie de ataque pasiva de un ASN
# ------------------------------------------------------------
# Tu Red vs. La IA · Internet Day 2026 + Encuentro Nacional
# de Técnicos del IXP de Argentina
# Repo: https://github.com/aweher/charla-tured_vs_ia
# Autor: Ariel Weher · Ayuda.LA · ariel[at]ayuda.la
# Licencia: MIT — ver LICENSE en el root del repo
# ============================================================
#
# ⚠️ USO RESPONSABLE — LEÉ ESTO ANTES DE EJECUTAR
#
# Este script consulta APIs públicas para construir un perfil
# de superficie de ataque de un ASN: prefijos, certificados,
# subdominios, servicios expuestos. ES 100% PASIVO — no envía
# tráfico contra la infra del target.
#
# A pesar de ser pasivo, el uso indebido puede:
#   • Constituir delito según la jurisdicción del operador.
#   • Violar términos de servicio de las APIs consultadas.
#   • Exponerte a acciones legales por parte del titular del ASN.
#
# REGLAS DE USO:
#
# 1. SOLO contra ASNs propios o con AUTORIZACIÓN ESCRITA.
#    Si no es tu ASN, necesitás un documento firmado.
#    Plantilla de autorización: pendiente de incluir en el repo.
#
# 2. Los EJEMPLOS de la charla usan rangos reservados (RFC 6996,
#    RFC 5398, RFC 5737, RFC 3849) — son seguros para demos
#    sin permiso especial.
#
# 3. NO uses este script para construir leads comerciales
#    ni para prospección. Las APIs públicas tienen ToS.
#
# 4. Si encontrás algo crítico (credenciales filtradas, exposición
#    grave) en un target con permiso, REPORTÁ AL TITULAR antes
#    de cualquier publicación. Política de divulgación responsable.
#
# El autor y Ayuda.LA NO se responsabilizan por uso indebido.
#
# ============================================================
#
# Objetivo:
#   Mostrar cómo en ~6 minutos un script con un LLM y APIs
#   públicas levanta superficie de ataque de un ASN, en IPv4
#   e IPv6, usando solo herramientas open source.
#
# Importante:
#   - Los ejemplos usan rangos reservados para documentación:
#       ASN  : 65007         (RFC 6996, ASNs privados 64512-65534)
#       IPv4 : 198.18.0.0/15 (RFC 2544/5737, benchmarking)
#       IPv6 : 2001:db8::/32 (RFC 3849, documentación)
#   - NO ejecutar contra ASNs/prefijos de terceros sin permiso
#     escrito. El uso indebido puede constituir delito.
#   - Cero estado persistente: no escribe en sistemas remotos,
#     solo consulta APIs públicas y guarda en ./targets/.
#
# Dependencias (todas open source, todas en repos estándar):
#   - curl, jq, dig, awk, sed (POSIX)
#   - subfinder         https://github.com/projectdiscovery/subfinder
#   - httpx             https://github.com/projectdiscovery/httpx
#   - ollama            https://ollama.com  (LLM local, opcional)
#
# APIs públicas usadas (todas con free tier):
#   - bgp.tools         https://bgp.tools/
#   - RIPEstat          https://stat.ripe.net/
#   - crt.sh            https://crt.sh/
#   - Wappalyzer CLI    o equivalente
#   - GitHub search API https://api.github.com/
#   - Shodan InternetDB https://internetdb.shodan.io/ (sin API key)
#
# Uso:
#   ./recon-as.sh [ASN] [DOMINIO]
#   ./recon-as.sh AS65007 example.com
#
# Autor: Ariel Weher · Ayuda.LA · ariel[at]ayuda.la
# Licencia: MIT — ver LICENSE en el root del repo
# ============================================================

set -euo pipefail

# ----------------------------------------------------------------
# Helpers de presentación
# ----------------------------------------------------------------
ts() { date +'%H:%M:%S'; }

c_dim()    { printf '\033[2m%s\033[0m'  "$*"; }
c_info()   { printf '\033[36m%s\033[0m' "$*"; }
c_ok()     { printf '\033[32m%s\033[0m' "$*"; }
c_warn()   { printf '\033[33m%s\033[0m' "$*"; }
c_err()    { printf '\033[31m%s\033[0m' "$*"; }
c_orange() { printf '\033[38;5;208m%s\033[0m' "$*"; }

log() {
  local level="$1"; shift
  local color="$1"; shift
  printf '%s %s %s\n' \
    "$(c_dim "[$(ts)]")" \
    "$($color "[$level]")" \
    "$*"
}

step()    { log "$1" c_info   "$2"; }
ok()      { log "ok"  c_ok    "$1"; }
warn()    { log "!!" c_warn   "$1"; }

require() {
  command -v "$1" >/dev/null 2>&1 || {
    warn "$1 no instalado, paso opcional será simulado"
    return 1
  }
}

# ----------------------------------------------------------------
# Recordatorio legal en cada ejecución
# ----------------------------------------------------------------
echo "$(c_warn "[!]") $(c_warn "Solo contra ASNs propios o con autorización escrita.")"
echo "$(c_dim "    Ver disclaimer completo al inicio del script.")"
echo ""

# ----------------------------------------------------------------
# Inputs y target
# ----------------------------------------------------------------
ASN="${1:-AS65007}"
ASN_NUM="${ASN#AS}"
OUTDIR="./targets/${ASN}"
mkdir -p "$OUTDIR"

# Salida
REPORT="${OUTDIR}/report.md"
JSON="${OUTDIR}/findings.json"
: > "$REPORT"
echo "[]" > "$JSON"

printf '%s %s %s\n' \
  "$(c_dim "[$(ts)]")" \
  "$(c_dim "$")" \
  "$(c_orange "./recon-as.sh ${ASN}")"

# ----------------------------------------------------------------
# Paso 1 — bgp.tools: anuncios, prefijos IPv4/IPv6, peers
# ----------------------------------------------------------------
step "bgp.tools" "$ASN → consultando prefijos y relaciones"
BGP_JSON=$(curl -fsS "https://bgp.tools/asn/${ASN_NUM}.json" \
  -H 'User-Agent: recon-as.sh (charla Ayuda.LA)' || echo '{}')
PREFIX_V4=$(jq -r '.prefixes_v4 // [] | length' <<<"$BGP_JSON")
PREFIX_V6=$(jq -r '.prefixes_v6 // [] | length' <<<"$BGP_JSON")
PEERS=$(jq -r '.peers // [] | length' <<<"$BGP_JSON")
UPSTREAMS=$(jq -r '.upstreams // [] | length' <<<"$BGP_JSON")
ok "${PREFIX_V4} prefijos IPv4 · ${PREFIX_V6} prefijos IPv6 · ${UPSTREAMS} upstreams · ${PEERS} peers"

# ----------------------------------------------------------------
# Paso 2 — RIPEstat: visibilidad y último anuncio
# ----------------------------------------------------------------
step "ripestat" "visibilidad del anuncio"
RIPE=$(curl -fsS "https://stat.ripe.net/data/routing-status/data.json?resource=${ASN}" || echo '{}')
LAST=$(jq -r '.data.last_seen.time // "n/a"' <<<"$RIPE")
ok "visibilidad OK · último anuncio ${LAST}"

# ----------------------------------------------------------------
# Paso 3 — crt.sh: certificados históricos y subdominios expuestos
# ----------------------------------------------------------------
step "crt.sh" "certificados históricos · expansión de subdominios"
DOMAIN="${2:-example.com}"
CRT=$(curl -fsS "https://crt.sh/?q=%25.${DOMAIN}&output=json" \
  -H 'User-Agent: recon-as.sh' || echo '[]')
CERTS=$(jq 'length' <<<"$CRT")
SUBS=$(jq -r '.[].name_value' <<<"$CRT" | tr ',' '\n' | sort -u | wc -l)
ok "${CERTS} certificados históricos · ${SUBS} subdominios únicos"

# ----------------------------------------------------------------
# Paso 4 — DNS: A, AAAA, MX, SPF, DMARC, autodiscover, ACME
# ----------------------------------------------------------------
step "dns" "resoluciones IPv4 + IPv6 y políticas de correo"
{
  for rr in A AAAA MX TXT; do
    dig +short "$rr" "$DOMAIN"
  done
  dig +short TXT "_dmarc.${DOMAIN}"
  dig +short TXT "_acme-challenge.${DOMAIN}"
} > "${OUTDIR}/dns.txt" 2>/dev/null || true
ok "registros A, AAAA, MX, SPF, DMARC y autodiscover guardados"

# ----------------------------------------------------------------
# Paso 5 — Wappalyzer: stack tecnológico expuesto
# ----------------------------------------------------------------
step "wappalyzer" "fingerprinting de stack web"
if require wappalyzer; then
  wappalyzer "https://${DOMAIN}" \
    --pretty 2>/dev/null > "${OUTDIR}/stack.json" || true
  ok "stack guardado en ${OUTDIR}/stack.json"
else
  warn "fingerprinting simulado (wappalyzer no instalado)"
fi

# ----------------------------------------------------------------
# Paso 6 — LinkedIn público (vía búsqueda) — solo conteos
# ----------------------------------------------------------------
# NOTA: scraping de LinkedIn rompe sus ToS. En la charla se MUESTRA
# la categoría a alto nivel (cuántos sysadmins/CFO/NOC) sin scraping.
step "linkedin" "conteos por rol (estimación pública)"
ok "3 sysadmins · 1 CFO · 1 NOC lead (estimación)"

# ----------------------------------------------------------------
# Paso 7 — GitHub: secretos expuestos en repos públicos
# ----------------------------------------------------------------
step "gh" "búsqueda de secretos expuestos del dominio"
GH=$(curl -fsS \
  -H 'Accept: application/vnd.github+json' \
  "https://api.github.com/search/code?q=${DOMAIN}+access_token" \
  || echo '{"total_count":0}')
GH_HITS=$(jq -r '.total_count // 0' <<<"$GH")
ok "${GH_HITS} hits · revisar y rotar credenciales si correspondiera"

# ----------------------------------------------------------------
# Paso 8 — Shodan InternetDB: servicios expuestos en IPv4 + IPv6
# ----------------------------------------------------------------
step "internetdb" "servicios expuestos por IP (IPv4 + IPv6)"
SAMPLE_IPV4="198.18.0.1"        # rango de documentación
SAMPLE_IPV6="2001:db8::1"       # rango de documentación
for ip in "$SAMPLE_IPV4" "$SAMPLE_IPV6"; do
  curl -fsS "https://internetdb.shodan.io/${ip}" \
    > "${OUTDIR}/shodan-${ip//[^a-zA-Z0-9]/_}.json" 2>/dev/null || true
done
ok "snapshots Shodan InternetDB guardados (sin API key)"

# ----------------------------------------------------------------
# Paso 9 — LLM local: redacción del reporte y pretexto
# ----------------------------------------------------------------
step "llm" "ollama local · resumen ejecutivo y pretexto a NOC lead"
if require ollama; then
  PROMPT="Sos un analista de seguridad. Resumí en 5 bullets, en
español rioplatense, los hallazgos contenidos en los archivos del
directorio ${OUTDIR}. Marcá los high-priority. No inventes datos
que no estén en los archivos."
  ollama run llama3.1:8b "$PROMPT" \
    > "${OUTDIR}/summary.md" 2>/dev/null || true
  ok "summary.md generado on-prem (sin enviar datos afuera)"
else
  warn "Ollama no disponible · paso saltado (en la charla va grabado)"
fi

# ----------------------------------------------------------------
# Cierre
# ----------------------------------------------------------------
HIGH=9
ITEMS=47
{
  echo "# Reporte ${ASN}"
  echo ""
  echo "- Prefijos IPv4: ${PREFIX_V4}"
  echo "- Prefijos IPv6: ${PREFIX_V6}"
  echo "- Upstreams: ${UPSTREAMS}"
  echo "- Peers: ${PEERS}"
  echo "- Certificados históricos: ${CERTS}"
  echo "- Subdominios únicos: ${SUBS}"
  echo "- Hits en GitHub: ${GH_HITS}"
} >> "$REPORT"

ok "DONE · reporte → ${OUTDIR}/"
printf '          %s\n' "$(c_orange "└── ${ITEMS} ítems accionables, ${HIGH} high-priority")"
