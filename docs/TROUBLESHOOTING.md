# Troubleshooting

Guía de resolución de problemas del stack defensivo **Tu Red vs. La IA**. Organizada por capa y por servicio, con los issues más comunes primero.

---

## Índice

- [Problemas generales del stack](#problemas-generales-del-stack)
- [Capa 1 — Routinator (RPKI)](#capa-1--routinator-rpki)
- [Capa 2 — Akvorado + ClickHouse + Grafana](#capa-2--akvorado--clickhouse--grafana)
- [Capa 3 — CrowdSec + Suricata + Wazuh](#capa-3--crowdsec--suricata--wazuh)
- [Capa 4 — fastnetmon](#capa-4--fastnetmon)
- [Capa 5 — MISP + n8n](#capa-5--misp--n8n)
- [LLM — Ollama + Open WebUI](#llm--ollama--open-webui)
- [Script recon-as.sh](#script-recon-assh)
- [Red y conectividad entre servicios](#red-y-conectividad-entre-servicios)
- [Rendimiento y recursos](#rendimiento-y-recursos)
- [Backups y persistencia](#backups-y-persistencia)

---

## Problemas generales del stack

### `docker compose up -d` no levanta nada

**Síntoma:** ejecutás `docker compose up -d` y no se crean contenedores.

**Causa:** los servicios tienen `profiles` definidos. Sin la variable `COMPOSE_PROFILES` no se levanta ninguno.

**Solución:**

```bash
# Verificá que existe el .env
ls -la stack/.env

# Si no existe, crealo desde el template
cp stack/.env.example stack/.env

# Verificá que COMPOSE_PROFILES tiene al menos un valor
grep COMPOSE_PROFILES stack/.env
```

También podés forzar un profile puntual:

```bash
docker compose --profile capa1 up -d
```

### `.env` no existe o tiene variables vacías

**Síntoma:** errores de variables no definidas al hacer `docker compose up`.

**Solución:**

```bash
cd stack/
cp .env.example .env
$EDITOR .env
```

Revisá que **no haya líneas con `=` vacío** salvo que sea intencional. Las variables más críticas:

- `COMPOSE_PROFILES` — define qué capas se levantan.
- `SURICATA_INTERFACE` — si ponés una interfaz que no existe, Suricata crashea.
- `WAZUH_INDEXER_PASSWORD` — passwords por defecto funcionan para dev; **cambiá en producción**.

### `docker compose` vs `docker-compose`

**Síntoma:** `docker-compose` no reconoce el archivo o da error de versión.

**Causa:** el stack requiere Docker Compose V2, que se invoca como `docker compose` (sin guión).

**Solución:**

```bash
# Verificar versión
docker compose version
# Debe ser >= 2.x

# Si solo tenés docker-compose (v1), actualizá Docker
# Ubuntu/Debian:
sudo apt update && sudo apt install docker-compose-plugin
```

### Contenedor en restart loop

**Síntoma:** `docker compose ps` muestra `Restarting` constantemente.

**Diagnóstico:**

```bash
# Ver los logs del contenedor que reinicia
docker compose logs --tail=100 <servicio>

# Ver el exit code
docker inspect <contenedor> --format='{{.State.ExitCode}}'
```

**Causas comunes:**

| Exit code | Significado | Solución típica |
|---|---|---|
| 0 | Salida limpia inesperada | Verificar `command:` en compose |
| 1 | Error genérico | Leer logs — generalmente config inválida |
| 137 | OOM Killed | Aumentar RAM o reducir servicios activos |
| 126 | Permiso denegado | Verificar permisos de volúmenes montados |
| 127 | Comando no encontrado | Imagen incorrecta o corrupta — `docker compose pull` |

### Permisos en volúmenes montados

**Síntoma:** errores tipo `Permission denied` en logs del contenedor.

**Causa:** los bind mounts (`./servicio/data`) se crean con el UID del host, pero el contenedor corre con otro UID.

**Solución:**

```bash
# Crear directorio con permisos amplios (ajustar después)
mkdir -p stack/<servicio>/data
chmod 777 stack/<servicio>/data

# Alternativa más segura: usar el UID del contenedor
# Ejemplo para ClickHouse (UID 101):
sudo chown -R 101:101 stack/clickhouse/data
```

### Puertos en conflicto

**Síntoma:** `Bind for 0.0.0.0:<puerto> failed: port is already allocated`.

**Diagnóstico:**

```bash
# Quién usa el puerto
sudo ss -tlnp | grep <puerto>
# o
sudo lsof -i :<puerto>
```

**Solución:** cambiar el puerto en `.env`:

```bash
# Ejemplo: CrowdSec y Akvorado compiten por 8080/8081
CROWDSEC_API_PORT=8180
AKVORADO_HTTP_PORT=8181
```

### Docker no tiene suficientes recursos

**Síntoma:** contenedores que no arrancan, errores de `cgroup memory` o simplemente se matan.

**Diagnóstico:**

```bash
# Ver uso de recursos de todos los contenedores
docker stats --no-stream

# Ver memoria disponible en el host
free -h

# Ver disco
df -h /var/lib/docker
```

**Requerimientos mínimos por setup:**

| Setup | RAM | Disco |
|---|---|---|
| Capa 1+2 | 4 GB | 50 GB |
| Capa 1-4 | 8 GB | 100 GB |
| Completo + LLM | 32 GB | 200 GB |

---

## Capa 1 — Routinator (RPKI)

### Routinator tarda mucho en el primer sync

**Síntoma:** después de `docker compose up -d routinator`, no responde en `:9556`.

**Causa normal:** el primer sync contra los repositorios de los 5 RIRs usa rsync y RRDP. Puede tardar **5-15 minutos** dependiendo del ancho de banda.

**Verificación:**

```bash
docker compose logs -f routinator
# Buscá líneas como "RRDP update" y "rsync update"
# Cuando termine, verás "server listening on 0.0.0.0:9556"
```

**Si pasa más de 20 minutos:** puede haber un bloqueo de rsync en tu firewall.

```bash
# Verificá que rsync (TCP/873) no esté bloqueado
docker exec routinator rsync rsync://rpki.ripe.net/ta/ --list-only
```

### `curl http://localhost:9556` devuelve connection refused

**Causa 1:** Routinator aún está sincronizando (ver arriba).

**Causa 2:** el puerto está mapeado a otro valor.

```bash
grep ROUTINATOR_HTTP_PORT stack/.env
docker compose ps routinator
```

**Causa 3:** Routinator no arrancó.

```bash
docker compose logs routinator | tail -20
```

### Los routers no conectan vía RTR

**Síntoma:** `show rpki server` en el router muestra `Inactive` o `Down`.

**Verificaciones:**

```bash
# Desde el host, verificá que RTR responde
nc -zv localhost 3323

# Desde otro host en la red:
nc -zv <ip-del-server> 3323
```

**Causas comunes:**

- Firewall del host bloqueando TCP/3323.
- El router usa la IP interna del contenedor en vez de la IP del host.
- El router tiene configurado un port incorrecto.

### Routinator muestra 0 VRPs

**Síntoma:** `curl http://localhost:9556/api/v1/status | jq` muestra `"vrps": 0`.

**Causa:** los TAL files no se cargaron correctamente o el repositorio no se sincronizó.

```bash
# Verificar TALs
docker exec routinator ls /home/routinator/.rpki-cache/tals/

# Forzar re-sync
docker compose restart routinator
```

---

## Capa 2 — Akvorado + ClickHouse + Grafana

### ClickHouse no arranca por ulimits

**Síntoma:** ClickHouse se cierra inmediatamente con error de `nofile` o `too many open files`.

**Causa:** el kernel del host no permite los ulimits configurados.

**Solución:**

```bash
# En el host, verificá los límites del sistema
ulimit -n
# Debe ser >= 262144

# Si no, editá /etc/security/limits.conf
# * soft nofile 262144
# * hard nofile 262144

# Y en /etc/sysctl.conf
# fs.file-max = 500000
sudo sysctl -p
```

### Akvorado no recibe flows

**Síntoma:** Akvorado arranca pero no muestra datos en la UI (`:8081`).

**Diagnóstico:**

```bash
# Verificar que el puerto UDP está escuchando
sudo ss -ulnp | grep -E '2055|6343'

# Verificar logs de Akvorado
docker compose logs --tail=50 akvorado
```

**Causas comunes:**

1. **Routers no exportan hacia la IP correcta.** Los flows deben apuntar a `<ip-del-host>:2055` (NetFlow) o `:6343` (sFlow).
2. **Firewall bloqueando UDP.** NetFlow y sFlow son UDP — si el firewall del host los bloquea, no hay error visible.
3. **Falta el archivo de configuración.** Akvorado requiere `./akvorado/config.yaml` montado.

```bash
# Verificar que existe
ls -la stack/akvorado/config.yaml

# Si no existe, crear uno mínimo
mkdir -p stack/akvorado
cat > stack/akvorado/config.yaml << 'EOF'
---
http:
  listen: :8080
inlet:
  flow:
    inputs:
      - type: netflow
        listen: :2055
      - type: sflow
        listen: :6343
  core:
    exporter-class-ifiers:
      - default
orchestrator:
  clickhouse:
    servers:
      - http://clickhouse:8123
    database: akvorado
EOF
```

4. **Versión de NetFlow incorrecta.** Akvorado soporta NetFlow v5, v9 e IPFIX. Verificá la versión que exporta tu router.

### Grafana no muestra dashboards

**Síntoma:** Grafana carga pero no tiene dashboards ni datasources.

**Causa:** falta el directorio de provisioning.

```bash
# Crear estructura mínima
mkdir -p stack/grafana/provisioning/datasources
mkdir -p stack/grafana/provisioning/dashboards
```

Ejemplo de datasource ClickHouse (`stack/grafana/provisioning/datasources/clickhouse.yaml`):

```yaml
apiVersion: 1
datasources:
  - name: ClickHouse
    type: grafana-clickhouse-datasource
    access: proxy
    url: http://clickhouse:8123
    jsonData:
      defaultDatabase: akvorado
```

**Otro problema:** credenciales. El password por defecto es `admin` / el valor de `GRAFANA_ADMIN_PASSWORD` en `.env`.

### ClickHouse consume mucho disco

**Síntoma:** `/var/lib/docker` se llena.

**Solución:**

```bash
# Ver cuánto ocupa ClickHouse
du -sh stack/clickhouse/data/

# Limpiar datos viejos (conectarse a ClickHouse)
docker exec -it clickhouse clickhouse-client
# > SELECT table, formatReadableSize(sum(bytes)) FROM system.parts GROUP BY table;
# > ALTER TABLE <tabla> DELETE WHERE date < today() - 30;
```

Considerá configurar TTL en las tablas de Akvorado para retención automática.

---

## Capa 3 — CrowdSec + Suricata + Wazuh

### CrowdSec: no detecta nada

**Síntoma:** `docker exec crowdsec cscli decisions list` siempre vacío.

**Diagnóstico:**

```bash
# Ver qué parsers y scenarios están instalados
docker exec crowdsec cscli hub list

# Ver si está leyendo logs
docker exec crowdsec cscli metrics
```

**Causas comunes:**

1. **No montaste los logs del host.** El compose monta `/var/log:/var/log:ro`. Si tus logs están en otro path, ajustá el volumen.
2. **Los parsers no matchean tus logs.** CrowdSec viene con parsers para formatos estándar. Si tu sshd o nginx usan formato custom, necesitás parsers adicionales.
3. **Nadie está atacando (buena señal).** Generá un intento fallido para probar:

```bash
# Desde otra máquina, intentá login SSH con password incorrecto 5 veces
ssh fakeuser@<ip-del-host>
```

### CrowdSec: `COLLECTIONS` no se instalan

**Síntoma:** logs muestran error al descargar collections.

**Causa:** el contenedor no tiene acceso a internet para descargar del Hub.

```bash
# Verificar conectividad desde el contenedor
docker exec crowdsec curl -sI https://hub.crowdsec.net
```

**Solución:** si estás detrás de proxy, configurá `HTTP_PROXY` y `HTTPS_PROXY` en el servicio de compose.

### Suricata: no captura tráfico

**Síntoma:** no se generan alertas ni EVE JSON.

**Verificación:**

```bash
# Ver si está corriendo
docker compose ps suricata

# Ver logs
docker compose logs --tail=50 suricata

# Verificar la interfaz
docker exec suricata suricata --list-app-layer-protos
```

**Causa más común:** la variable `SURICATA_INTERFACE` apunta a una interfaz que no existe.

```bash
# Ver interfaces del host
ip link show

# Corregir en .env
SURICATA_INTERFACE=ens18   # o la que corresponda
```

**Nota:** Suricata corre con `network_mode: host` y necesita `CAP_NET_ADMIN` + `CAP_NET_RAW`. En hosts con AppArmor/SELinux restrictivo, puede fallar silenciosamente.

### Suricata: reglas desactualizadas

```bash
# Actualizar reglas
docker exec suricata suricata-update
docker compose restart suricata

# Verificar que se cargaron
docker exec suricata suricata-update list-sources
```

### Suricata: alto uso de CPU

**Causa normal:** en interfaces de 1 Gbps+, Suricata consume CPU significativo. Es esperado.

**Mitigación:**

```bash
# Verificar el threading
docker exec suricata cat /etc/suricata/suricata.yaml | grep -A5 threading

# Limitar workers si es necesario — editar suricata.yaml:
# threading:
#   set-cpu-affinity: yes
#   cpu-affinity:
#     - management-cpu-set:
#         cpu: [ 0 ]
#     - worker-cpu-set:
#         cpu: [ 1, 2 ]
```

### Wazuh: el dashboard no carga (timeout o 502)

**Síntoma:** `https://localhost:5601` devuelve timeout o error.

**Causa 1:** el stack de Wazuh necesita **3-5 minutos** en el primer arranque para inicializar índices.

```bash
# Ver el progreso
docker compose logs -f wazuh-indexer
docker compose logs -f wazuh-dashboard
```

**Causa 2:** falta RAM. El indexer usa `-Xms1g -Xmx1g` por defecto (configurable en `OPENSEARCH_JAVA_OPTS` del compose). Con overhead de JVM necesita ~1.5-2 GB libres. Si corrés muchos containers simultáneamente (ej. Docker Desktop con 8 GB), el indexer puede entrar en crash loop sin mostrar errores claros en los logs — solo warnings de Java al intentar arrancar.

```bash
# Verificar que el indexer está vivo
curl -sf http://localhost:9200/_cluster/health | jq

# Ver cuánta RAM consumen los containers
docker stats --no-stream
```

Si el indexer reinicia en loop, verificá que Docker tiene suficiente RAM disponible. Podés reducir otros servicios o subir la RAM de Docker Desktop.

**Causa 3:** certificados SSL internos.

```bash
# Si los certs no se generaron, el indexer no arranca
docker compose logs wazuh-indexer | grep -i cert
# Si es el caso, borrá los datos y dejá que se regeneren:
sudo rm -rf stack/wazuh/indexer-certs/*
docker compose restart wazuh-indexer wazuh-manager wazuh-dashboard
```

### Wazuh: agentes no se registran

**Síntoma:** los agentes en tus servers no aparecen en el dashboard.

**Verificación:**

```bash
# Desde el server con el agente
sudo systemctl status wazuh-agent

# Verificar conectividad al manager
nc -zv <ip-wazuh-manager> 1514
nc -zv <ip-wazuh-manager> 1515
```

**Causas comunes:**

1. **Firewall bloqueando TCP/1514 y TCP/1515.** Abrir ambos puertos.
2. **El agente apunta a la IP incorrecta del manager.**
3. **Versión del agente incompatible.** Usar la misma major version (4.x) que el manager.

### Wazuh indexer: error `max virtual memory areas`

**Síntoma:** el indexer no arranca con error `max virtual memory areas vm.max_map_count [65530] is too low`.

**Solución:**

```bash
# En el host
sudo sysctl -w vm.max_map_count=262144

# Para hacerlo persistente
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### Wazuh: passwords por defecto

En producción, **cambiá todas las passwords** del `.env`:

- `WAZUH_INDEXER_PASSWORD`
- `WAZUH_API_PASSWORD`

Si cambiás los passwords después del primer arranque, necesitás actualizar las contraseñas internas:

```bash
# Detener todo
docker compose down

# Borrar datos del indexer (CUIDADO: pierde datos)
sudo rm -rf stack/wazuh/indexer-data/*

# Re-levantar con nuevos passwords
docker compose up -d
```

---

## Capa 4 — fastnetmon

### fastnetmon no arranca

**Síntoma:** el contenedor reinicia constantemente.

**Verificación:**

```bash
docker compose logs --tail=50 fastnetmon
```

**Causa más común:** falta el directorio de configuración.

```bash
mkdir -p stack/fastnetmon/etc
mkdir -p stack/fastnetmon/var-log
```

Si el archivo `fastnetmon.conf` no existe, creá uno mínimo (ver [`stack/fastnetmon/README.md`](../stack/fastnetmon/README.md)).

### fastnetmon blackholea clientes legítimos

**Causa:** threshold demasiado bajo para tu red.

**Solución inmediata:**

```bash
# Desbanear una IP
docker exec fastnetmon fastnetmon_client -u <ip>

# Subir threshold
docker exec fastnetmon \
  sed -i 's/^threshold_pps.*/threshold_pps = 200000/' /etc/fastnetmon/fastnetmon.conf
docker compose restart fastnetmon
```

**Regla:** empezar con threshold **alto** (200k pps, 5 Gbps, 10k flows) y bajar gradualmente después de 2 semanas de observar tu baseline.

### fastnetmon no recibe flows

**Verificación:**

```bash
docker exec fastnetmon fastnetmon_client
# Debe mostrar tráfico por IP

# Si muestra 0 en todo:
docker exec fastnetmon tail -f /var/log/fastnetmon/fastnetmon.log
```

**Causas:**

1. **Puertos NetFlow/sFlow duplicados con Akvorado.** fastnetmon y Akvorado **no pueden escuchar en el mismo puerto UDP**. Usá puertos distintos: 2055/6343 para Akvorado, 2056/6344 para fastnetmon. Configurá los routers para exportar a ambos destinos.
2. **`network_mode: host` tiene implicancias de binding.** Verificá con `ss -ulnp` que fastnetmon efectivamente escucha en los puertos configurados.

### ExaBGP no conecta al router

**Nota:** ExaBGP no está incluido en el compose porque depende de tu setup BGP real.

**Si lo configuraste por fuera:**

```bash
# Verificar que el pipe existe
ls -la /var/run/exabgp.cmd

# Verificar que ExaBGP estableció sesión BGP
exabgpcli show neighbor summary
```

---

## Capa 5 — MISP + n8n

### MISP: primer login falla

**URL:** `http://localhost:8083` (o el valor de `MISP_HTTP_PORT`).

**Credenciales por defecto:** el email de `MISP_ADMIN_EMAIL` y password de `MISP_ADMIN_PASSWORD` del `.env`.

**Si no funciona:**

```bash
# Ver logs de MISP
docker compose logs --tail=100 misp

# Verificar que MariaDB está arriba
docker compose logs misp-db | tail -20

# Verificar que Redis está arriba
docker compose logs misp-redis
```

**Causa frecuente:** la variable en `.env` debe llamarse `MISP_ADMIN_PASSWORD` (es lo que lee el `docker-compose.yml`). Si tu `.env` viene de una versión vieja del `.env.example`, puede tener el nombre incorrecto `MISP_ADMIN_PASSPHRASE` — renombrala.

### MISP: MariaDB no arranca

**Síntoma:** `misp-db` en restart loop.

```bash
docker compose logs misp-db | tail -30
```

**Causas:**

1. **Disco lleno.** MariaDB necesita poder escribir.
2. **Permisos en `./misp/db/`.** El contenedor de MariaDB corre como UID 999.

```bash
sudo chown -R 999:999 stack/misp/db/
```

3. **Datos corruptos.** Si la DB se corrompió (por ej. crash del host):

```bash
# CUIDADO: esto borra todos los datos de MISP
sudo rm -rf stack/misp/db/*
docker compose up -d misp-db
```

### MISP: los feeds no se sincronizan

```bash
# Forzar sync de todos los feeds
docker exec misp /var/www/MISP/app/Console/cake Server fetchFeeds all

# Verificar conectividad a feeds externos
docker exec misp curl -sI https://www.circl.lu
```

**Si estás detrás de proxy:** configurá las variables de proxy en el servicio MISP del compose.

### n8n: no conecta a otros servicios del stack

**Síntoma:** workflows de n8n no pueden alcanzar MISP, Wazuh, etc.

**Causa:** n8n está en la red `defensa` y los servicios se alcanzan por nombre de contenedor.

**Verificación:**

```bash
# Desde n8n, verificar que alcanza MISP
docker exec n8n wget -qO- http://misp:80 || echo "no alcanza"

# Verificar red
docker network inspect tu-red-vs-la-ia_defensa
```

**Importante:** usá los **nombres de contenedor** como hostname en n8n, no `localhost`:

| Servicio | URL desde n8n |
|---|---|
| MISP | `http://misp:80` |
| Wazuh API | `https://wazuh-manager:55000` |
| Ollama | `http://ollama:11434` |
| CrowdSec | `http://crowdsec:8080` |

### n8n: error de autenticación

**Credenciales:** `N8N_BASIC_AUTH_USER` / `N8N_BASIC_AUTH_PASSWORD` del `.env`.

Si cambiaste las credenciales y no podés entrar:

```bash
docker compose down n8n
sudo rm -rf stack/n8n/data/.n8n/config
docker compose up -d n8n
```

---

## LLM — Ollama + Open WebUI

### Ollama: no descarga modelos (timeout)

**Síntoma:** `docker exec ollama ollama pull llama3.1:8b` se cuelga o da timeout.

**Causa:** los modelos pesan entre 4 y 40 GB. Requiere buena conexión a internet.

```bash
# Verificar conectividad
docker exec ollama curl -sI https://registry.ollama.ai

# Si estás detrás de proxy
# Agregar al servicio ollama en docker-compose.yml:
# environment:
#   HTTP_PROXY: http://tu-proxy:3128
#   HTTPS_PROXY: http://tu-proxy:3128
```

### Ollama: inferencia extremadamente lenta (< 1 token/s)

**Causa 1:** sin GPU, los modelos 8B corren a ~3-5 tokens/s. Esto es **normal** en CPU. Si ves < 1 token/s:

```bash
# Ver cuánta RAM tiene el host
free -h

# Si queda poco libre, Ollama está swapeando — desastroso para performance
# Solución: bajar servicios o usar un modelo más chico
docker exec ollama ollama pull qwen2.5:3b
```

**Causa 2 (NVIDIA):** el bloque `deploy:` está comentado en el compose.

```bash
# Verificar que el runtime NVIDIA funciona
docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi

# Si funciona, descomentar el bloque deploy en docker-compose.yml
# y reiniciar
docker compose down ollama
docker compose --profile llm up -d
```

**Causa 3 (Apple Silicon):** Docker Desktop no expone Metal a contenedores. Usá Ollama nativo.

```bash
# Instalar nativo
brew install ollama
ollama serve &
ollama pull llama3.1:8b

# Verificar que Metal está activo
ollama ps
# Debe mostrar "metal" en la columna de procesador

# Cambiar Open WebUI para apuntar al host
# En docker-compose.yml, cambiar OLLAMA_BASE_URL:
#   OLLAMA_BASE_URL: http://host.docker.internal:11434
```

### Ollama: error `not enough memory`

**Síntoma:** `ollama run` falla con error de memoria.

**Solución:**

```bash
# Ver modelos cargados (cada modelo consume RAM mientras está cargado)
docker exec ollama ollama ps

# Descargar modelos que no estés usando
docker exec ollama ollama rm <modelo-que-no-necesitas>

# Usar un modelo más chico
docker exec ollama ollama pull qwen2.5:3b    # ~2 GB
docker exec ollama ollama pull phi3:mini      # ~2 GB
```

| RAM disponible | Modelo máximo recomendado |
|---|---|
| 8 GB | qwen2.5:3b, phi3:mini |
| 16 GB | llama3.1:8b, qwen2.5:7b |
| 32 GB | llama3.1:8b, mixtral:8x7b |
| 64 GB+ | llama3.1:70b |

### Ollama: Metal no funciona en Apple Silicon

```bash
# Verificar soporte Metal
system_profiler SPDisplaysDataType | grep Metal

# Limpiar cache de shaders
rm -rf ~/Library/Caches/com.apple.metal

# Forzar CPU para debug
OLLAMA_METAL=0 ollama serve

# Ver uso de GPU
sudo powermetrics --samplers gpu_power -i1000 -n1
```

> **macOS 26 (Tahoe) + M5:** hay un bug conocido con shaders Metal de Ollama. Alternativa: usar [MLX](https://github.com/ml-explore/mlx) de Apple hasta que se resuelva.

### Open WebUI: no encuentra Ollama

**Síntoma:** Open WebUI carga pero dice "No models available" o "Connection refused".

**Verificación:**

```bash
# Verificar que Ollama responde
docker exec open-webui wget -qO- http://ollama:11434/api/tags

# Si no responde, verificar que ambos están en la misma red
docker network inspect tu-red-vs-la-ia_defensa | grep -A2 ollama
docker network inspect tu-red-vs-la-ia_defensa | grep -A2 open-webui
```

**Causa con Ollama nativo (Apple Silicon):**

```bash
# Cambiar OLLAMA_BASE_URL en docker-compose.yml:
OLLAMA_BASE_URL: http://host.docker.internal:11434

# Reiniciar Open WebUI
docker compose restart open-webui
```

### Open WebUI: primer usuario no se crea

**Síntoma:** la pantalla de registro no aparece o falla.

```bash
# Ver logs
docker compose logs --tail=50 open-webui

# Si la DB interna se corrompió, resetear:
sudo rm -rf stack/open-webui/data/*
docker compose restart open-webui
```

El primer usuario registrado queda como administrador.

---

## Script recon-as.sh

### Errores de dependencias

**Síntoma:** el script falla con `command not found`.

**Dependencias obligatorias:**

```bash
# Verificar
which curl jq dig awk sed

# Instalar (Ubuntu/Debian)
sudo apt install curl jq dnsutils gawk
```

**Dependencias opcionales (el script funciona sin ellas):**

```bash
# subfinder — enumeración de subdominios
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest

# httpx — probe HTTP
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest

# ollama — resumen con LLM (el script lo saltea si no está)
```

### APIs públicas no responden

**Síntoma:** errores de `curl` contra bgp.tools, crt.sh, RIPEstat, etc.

**Causas:**

1. **Rate limiting.** Las APIs tienen cuotas. No ejecutes el script más de 2-3 veces por hora contra el mismo ASN.
2. **Firewall corporativo.** Verificá que podés alcanzar las APIs desde tu red.
3. **API caída.** Chequea status en los sitios de cada servicio.

```bash
# Test rápido de conectividad
curl -sI https://bgp.tools
curl -sI https://stat.ripe.net
curl -sI https://crt.sh
```

### El directorio `targets/` no se crea

**Verificación:**

```bash
# El script crea ./targets/<ASN>/
# Verificá que tenés permisos de escritura
ls -la scripts/
```

Si ejecutás desde otro directorio, el script crea `targets/` relativo al `cwd`.

---

## Red y conectividad entre servicios

### Los contenedores no se ven entre sí

**Síntoma:** un servicio no puede conectar a otro por nombre (ej: `akvorado` no conecta a `clickhouse`).

**Verificación:**

```bash
# Listar la red
docker network inspect tu-red-vs-la-ia_defensa

# Verificar que ambos contenedores están en la red
docker inspect <contenedor> --format='{{json .NetworkSettings.Networks}}' | jq
```

**Excepción:** `suricata` y `fastnetmon` usan `network_mode: host` y **no están en la red `defensa`**. No pueden resolver otros contenedores por nombre.

Si necesitás que fastnetmon hable con otros servicios del stack, usá la IP del host:

```bash
# Desde fastnetmon, usar IP del host en vez de nombre
curl http://172.17.0.1:8080   # en vez de http://crowdsec:8080
```

### DNS interno de Docker no resuelve

**Síntoma:** `Could not resolve host: <servicio>`.

```bash
# Verificar el DNS interno de Docker
docker exec <contenedor> cat /etc/resolv.conf

# Debe apuntar a 127.0.0.11 (el DNS embedido de Docker)
```

**Solución:** si usás un DNS custom en el host que interfiere con Docker:

```bash
# En /etc/docker/daemon.json
{
  "dns": ["8.8.8.8", "1.1.1.1"]
}
sudo systemctl restart docker
```

### Servicios con `network_mode: host` vs red `defensa`

| Servicio | Red | Acceso a otros contenedores |
|---|---|---|
| routinator | defensa | Por nombre de contenedor |
| clickhouse | defensa | Por nombre de contenedor |
| akvorado | defensa | Por nombre de contenedor |
| grafana | defensa | Por nombre de contenedor |
| crowdsec | defensa | Por nombre de contenedor |
| **suricata** | **host** | **Solo por IP del host** |
| wazuh-* | defensa | Por nombre de contenedor |
| **fastnetmon** | **host** | **Solo por IP del host** |
| misp, misp-db, misp-redis | defensa | Por nombre de contenedor |
| n8n | defensa | Por nombre de contenedor |
| ollama | defensa | Por nombre de contenedor |
| open-webui | defensa | Por nombre de contenedor |

---

## Rendimiento y recursos

### Identificar el contenedor que consume más

```bash
# Snapshot de recursos
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

# Top consumers de disco
du -sh stack/*/data stack/*/var-log 2>/dev/null | sort -rh | head -20
```

### El host se queda sin RAM

**Orden de prioridad para bajar servicios:**

1. Ollama (6-8 GB) — si no lo estás usando activamente.
2. Wazuh stack (4-8 GB) — mover a VM dedicada si es posible.
3. MISP (1-2 GB) — puede correr por separado.
4. Suricata (0.5-4 GB) — depende del tráfico.

```bash
# Bajar un profile entero
docker compose --profile llm down
docker compose --profile siem down

# O un servicio puntual
docker compose stop ollama
```

### El host se queda sin disco

```bash
# Ver uso de Docker
docker system df

# Limpiar imágenes y volúmenes no usados
docker system prune -a --volumes
# CUIDADO: esto borra imágenes no usadas y volúmenes anónimos

# Limpiar solo imágenes colgadas (más seguro)
docker image prune

# Revisar logs de Docker (pueden crecer mucho)
sudo du -sh /var/lib/docker/containers/*/*.log | sort -rh | head -5

# Limitar tamaño de logs en /etc/docker/daemon.json
# {
#   "log-driver": "json-file",
#   "log-opts": {
#     "max-size": "50m",
#     "max-file": "3"
#   }
# }
```

### ClickHouse consume mucho disco

ClickHouse almacena flows que crecen con el tiempo.

```bash
# Ver tamaño de tablas
docker exec -it clickhouse clickhouse-client -q \
  "SELECT table, formatReadableSize(sum(bytes_on_disk)) as size
   FROM system.parts
   WHERE active
   GROUP BY table
   ORDER BY sum(bytes_on_disk) DESC"

# Configurar retención (ejemplo: 90 días)
docker exec -it clickhouse clickhouse-client -q \
  "ALTER TABLE akvorado.flows MODIFY TTL toDateTime(TimeReceived) + INTERVAL 90 DAY"
```

---

## Backups y persistencia

### Dónde están los datos

Todos los datos persistentes están en bind mounts bajo `stack/`:

| Servicio | Path | Criticidad |
|---|---|---|
| Routinator | `./routinator/data/` | Baja (se re-sincroniza solo) |
| ClickHouse | `./clickhouse/data/` | Media (flows históricos) |
| Akvorado | `./akvorado/config.yaml` | Alta (configuración) |
| CrowdSec | `./crowdsec/data/`, `./crowdsec/config/` | Media |
| Suricata | `./suricata/etc/`, `./suricata/var-log/` | Media (reglas + logs) |
| Wazuh indexer | `./wazuh/indexer-data/` | Alta (todos los eventos SIEM) |
| Wazuh manager | `./wazuh/manager-data/`, `./wazuh/manager-logs/` | Alta |
| fastnetmon | `./fastnetmon/etc/` | Alta (configuración) |
| MISP DB | `./misp/db/` | Alta (toda la threat intel) |
| MISP Redis | `./misp/redis/` | Media (cache) |
| MISP configs/files | Docker named volumes (`misp_config`, `misp_files`) | Alta |
| n8n | `./n8n/data/` | Alta (workflows) |
| Ollama models | `./ollama/models/` | Baja (se re-descargan) |
| Open WebUI | `./open-webui/data/` | Media (historial de chats) |
| Grafana | `./grafana/data/` | Media (dashboards custom) |

### Backup manual rápido

```bash
# Parar servicios para consistencia (opcional pero recomendado para DBs)
docker compose stop

# Backup de todo
tar czf backup-$(date +%Y%m%d).tar.gz \
  --exclude='*/data/cache' \
  --exclude='*/var-log/*.log' \
  stack/

# Levantar de nuevo
docker compose up -d
```

### Restaurar desde backup

```bash
# Parar todo
docker compose down

# Restaurar
tar xzf backup-YYYYMMDD.tar.gz

# Levantar
docker compose up -d
```

---

## Comandos de diagnóstico rápido

Referencia rápida para cuando algo falla:

```bash
# Estado general
docker compose ps
docker compose logs --tail=20

# Logs de un servicio específico
docker compose logs --tail=100 -f <servicio>

# Recursos en tiempo real
docker stats

# Red
docker network ls
docker network inspect tu-red-vs-la-ia_defensa

# Verificar puertos
sudo ss -tlnp    # TCP
sudo ss -ulnp    # UDP

# Reiniciar un servicio
docker compose restart <servicio>

# Reconstruir sin cache (si la imagen está corrupta)
docker compose pull <servicio>
docker compose up -d <servicio>

# Nuclear option: bajar todo, limpiar, y volver a empezar
docker compose down
docker system prune -a
docker compose up -d
```

---

## Problemas conocidos

| Problema | Afecta a | Estado | Workaround |
|---|---|---|---|
| Docker Desktop para Mac no expone Metal a contenedores | Ollama en macOS | Limitación de Docker | Usar Ollama nativo (`brew install ollama`) |
| macOS 26 (Tahoe) + M5: bug en shaders Metal | Ollama en M5 | [Issue #14432](https://github.com/ollama/ollama/issues/14432) | Usar [MLX](https://github.com/ml-explore/mlx) como alternativa |
| `MISP_ADMIN_PASSPHRASE` vs `MISP_ADMIN_PASSWORD` | MISP | Corregido en `.env.example` | Usar `MISP_ADMIN_PASSWORD` en `.env` (es lo que consume el compose) |
| Wazuh Indexer crash loop sin errores visibles | Wazuh Indexer | Corregido (heap default 1g) | Reducir `OPENSEARCH_JAVA_OPTS` a `-Xms1g -Xmx1g` o aumentar RAM de Docker. El indexer con 2g de heap necesita ~3.5 GB libres con overhead de JVM. |
| Wazuh Dashboard `wazuh.yml` se corrompe (duplicated mapping key) | Wazuh Dashboard | Corregido (mount `:ro`) | El archivo `wazuh.yml` se monta como `:ro` para evitar que el init script del container lo sobreescriba. Si necesitás cambiar la config, editá el archivo local y reiniciá el dashboard. El warning `Read-only file system` en los logs es cosmético. |
| MISP workers FATAL en primer arranque | MISP | Normal | Los workers de supervisord (`default_*`, `cache_*`, `email_*`, `prio_*`) fallan durante la primera inicialización mientras se corren migraciones de DB. MISP se recupera solo después de 5-10 min. Si sigue en FATAL después de 15 min, investigar con `docker compose logs misp`. |
| CrowdSec `No matching files` para `auth.log`/`syslog` | CrowdSec en macOS | Normal en macOS | Los paths `/var/log/auth.log` y `/var/log/syslog` en `acquis.yaml` son para Linux. En macOS (Docker Desktop) esos archivos no existen en el host. En un servidor Linux real, matchean sin problema. |
| Grafana xychart plugin `already registered` | Grafana 11.2.0 | Bug cosmético | Error interno de Grafana donde el panel xychart bundleado colisiona con una versión anterior. No afecta funcionalidad. |
| n8n `Database connection timed out` | n8n | Transitorio | Ocurre cuando el sistema está bajo presión de RAM/IO. n8n se recupera automáticamente (`Database connection recovered`). Si es persistente, reducir containers activos. |

---

## Dónde pedir ayuda

1. **Issues del repo:** <https://github.com/aweher/charla-tured_vs_ia/issues>
2. **Documentación del stack:** cada servicio tiene su propio `README.md` en `stack/<servicio>/`.
3. **Documentación upstream:** ver [REFERENCES.md](./REFERENCES.md) para links a la documentación oficial de cada herramienta.
4. **Comunidades regionales:**
   - LACNIC CSIRT: <https://csirt.lacnic.net>
   - NOG Argentina
   - CrowdSec Discord: <https://discord.gg/crowdsec>

---

**Este documento se actualiza con cada incidente resuelto. Si resolviste algo que no está acá, abrí un PR.**
