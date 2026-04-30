# Stack defensivo — guía de uso

Este directorio contiene el `docker-compose.yml` con todo el stack defensivo de la charla **Tu Red vs. La IA**, listo para levantar en una VM Linux con Docker.

## Requisitos

- Linux (probado en Ubuntu 22.04 / Debian 12).
- Docker 24+ con plugin compose v2.
- Mínimo recomendado: **4 vCPU · 16 GB RAM · 100 GB disco**. Para Wazuh + MISP + Ollama, **8 vCPU · 32 GB RAM** es más confortable.
- Si vas a correr Ollama con GPU: NVIDIA Container Toolkit instalado.

> **Atención:** el stack completo requiere una **alta cantidad de recursos de hardware**. Levantar todos los servicios simultáneamente puede consumir 32 GB de RAM o más. Si tu equipo es limitado, empezá con profiles individuales (`capa1`, `capa2`, etc.) e ir sumando capas. Consultá la tabla de [Recursos esperados](#recursos-esperados) más abajo antes de hacer `docker compose up -d` con todo.
>
> **Docker Desktop (macOS / Windows):** el stack está diseñado para un servidor Linux, pero puede correr en Docker Desktop para dev/demo. El Wazuh Indexer viene con heap reducido (`-Xms1g`) para funcionar en entornos con 8 GB de RAM. Si tenés 16 GB o más disponibles para Docker, podés subir a `-Xms2g -Xmx2g` editando `OPENSEARCH_JAVA_OPTS` en `docker-compose.yml`.

## Quickstart

```bash
# 1. Configurá las variables
cp .env.example .env
$EDITOR .env

# 2. Levantá todo
docker compose up -d

# 3. Verificá que arrancó
docker compose ps
docker compose logs --tail=50 -f
```

## Servicios y puertos

| Servicio | Puerto | Web UI | Función |
|---|---|---|---|
| **Routinator** | 9556 | http://localhost:9556 | Validador RPKI (HTTP + RTR :3323 para routers BGP) |
| **pmacct** | 2055 / 6343 | — | Colector NetFlow / sFlow |
| **Akvorado** | 8081 | http://localhost:8081 | Dashboards de tráfico inter-AS |
| **CrowdSec** | 8080 | (CLI) | Motor de detección + bouncers |
| **Suricata** | — (host net) | — | IDS/IPS en SPAN, exporta EVE JSON |
| **Wazuh Dashboard** | 5601 | https://localhost:5601 | SIEM principal |
| **fastnetmon** | 10007 | http://localhost:10007 | Detección y mitigación DDoS |
| **MISP** | 8083 | http://localhost:8083 | Threat intelligence federable |
| **n8n** | 5678 | http://localhost:5678 | SOAR / orquestación de respuestas |
| **Ollama** | 11434 | (API) | Runtime LLM local |
| **Open WebUI** | 3000 | http://localhost:3000 | Interfaz tipo ChatGPT para Ollama |
| **Grafana** | 3001 | http://localhost:3001 | Visualización general |

## Por dónde empezar (1ra vez)

1. **RPKI primero.** `docker compose up -d routinator` — verificá que valida ROAs en `http://localhost:9556`.
2. **Visibilidad después.** `docker compose up -d akvorado grafana` — empezá a recibir flows de tus routers.
3. **Detección.** `docker compose up -d crowdsec wazuh-indexer wazuh-manager wazuh-dashboard suricata`.
4. **Mitigación.** `docker compose up -d fastnetmon` — configurá threshold inicial alto y bajalo gradualmente.
5. **Intel y automatización.** `docker compose up -d misp n8n` — conectalos a feeds de LACNIC CSIRT.
6. **LLM local.** `docker compose up -d ollama open-webui` — descargá modelo: `docker exec ollama ollama pull llama3.1:8b`.

## Profiles de Docker Compose

Si no querés todo a la vez, usá profiles:

```bash
# Solo capa 1 (higiene de borde)
docker compose --profile capa1 up -d

# Solo capa 2 (visibilidad)
docker compose --profile capa2 up -d

# Solo LLM (para empezar a jugar con Ollama)
docker compose --profile llm up -d
```

Profiles disponibles: `capa1`, `capa2`, `capa3`, `capa4`, `capa5`, `llm`, `siem`.

## Configuración inicial

Cada servicio tiene su propio README en `./<servicio>/README.md` con configuración base y customizaciones recomendadas. Lectura sugerida en orden:

1. [`routinator/README.md`](./routinator/README.md)
2. [`crowdsec/README.md`](./crowdsec/README.md)
3. [`fastnetmon/README.md`](./fastnetmon/README.md)
4. [`wazuh/README.md`](./wazuh/README.md)
5. [`ollama/README.md`](./ollama/README.md)

## Recursos esperados

| Servicio | RAM en idle | RAM bajo carga | CPU idle | Disco |
|---|---|---|---|---|
| Routinator | 200 MB | 500 MB | bajo | 1 GB |
| pmacct + Akvorado + ClickHouse | 1.5 GB | 4 GB | medio | 20 GB+ |
| CrowdSec | 150 MB | 400 MB | bajo | 500 MB |
| Suricata | 500 MB | 4 GB | alto (1G+ tráfico) | 5 GB (logs) |
| Wazuh stack (heap 1g default) | 2 GB | 4 GB | medio | 40 GB+ |
| fastnetmon | 200 MB | 1 GB | medio | 1 GB |
| MISP | 1 GB | 2 GB | bajo | 10 GB |
| n8n | 200 MB | 500 MB | bajo | 1 GB |
| Ollama (8B model) | 6 GB | 8 GB | alto sin GPU | 5 GB por modelo |
| Open WebUI | 200 MB | 400 MB | bajo | 500 MB |
| Grafana | 200 MB | 500 MB | bajo | 500 MB |

## Backup y persistencia

Los datos persistentes de cada servicio están en bind mounts dentro de `stack/` (ej. `./clickhouse/data/`, `./wazuh/indexer-data/`, `./crowdsec/data/`). Nada de esto se commitea al repo — ver `.gitignore`. Para backup manual:

```bash
docker compose stop
tar czf backup-$(date +%Y%m%d).tar.gz \
  --exclude='*/cache' \
  --exclude='*/var-log/*.log' \
  stack/
docker compose up -d
```

## Updates

```bash
docker compose pull
docker compose up -d
```

## Troubleshooting

Si algo no arranca:

```bash
docker compose logs --tail=100 <servicio>
```

Issues conocidos: ver [`docs/TROUBLESHOOTING.md`](../docs/TROUBLESHOOTING.md).

---

**No es un producto.** Es un punto de partida. La operación 24/7 requiere un equipo. Tomalo como base y adaptalo a tu realidad.

Este stack se ofrece como **prueba de concepto** con fines educativos y de divulgación técnica. Se espera que evolucione como un proyecto comunitario. Ayuda.LA y sus colaboradores **no ofrecen soporte técnico dedicado** sobre este material sin un contrato de soporte vigente. **No nos hacemos responsables por ningún mal uso que se le pueda dar a estas herramientas.** Consultas comerciales: `ariel[at]ayuda.la`.

---

**Autor:** Ariel S. Weher · Ayuda.LA · `ariel[at]ayuda.la`
