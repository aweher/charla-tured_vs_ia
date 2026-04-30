# Arquitectura del stack

Cómo encaja cada pieza del stack y por dónde fluye la información.

```
                            ┌─────────────────────────┐
                            │   ROUTERS BGP           │
                            │   (Cisco / Juniper /    │
                            │    Mikrotik / BIRD)     │
                            └────────┬────────────────┘
                                     │
                ┌────────────────────┼────────────────────┐
                │                    │                    │
                │ RTR :3323          │ NetFlow            │ NetFlow/sFlow
                │ (validación        │ :2055              │ :6343
                │  RPKI)             │                    │
                ▼                    ▼                    ▼
         ┌────────────┐       ┌──────────────┐    ┌─────────────┐
         │ Routinator │       │   Akvorado   │    │  fastnetmon │
         │  (RPKI)    │       │  + ClickHouse│    │  Community  │
         └────────────┘       └──────┬───────┘    └──────┬──────┘
                                     │                   │
                                     ▼                   │ RTBH/FlowSpec
                              ┌──────────────┐           │ via ExaBGP
                              │   Grafana    │           ▼
                              │ (dashboards) │    ┌─────────────┐
                              └──────────────┘    │  ROUTERS    │
                                                  │  (mitigan)  │
                                                  └─────────────┘


   ┌───────────────────────────────────────────────────────────────┐
   │              SERVERS / CPEs / APPS DEL OPERADOR               │
   └────────────────────────┬──────────────────────────────────────┘
                            │
            ┌───────────────┼───────────────────┬─────────────┐
            │               │                   │             │
        agente            syslog              SPAN          logs
            │               │                   │             │
            ▼               ▼                   ▼             ▼
     ┌────────────┐  ┌────────────┐      ┌────────────┐  ┌──────────┐
     │   Wazuh    │  │ wazuh-mgr  │      │  Suricata  │  │ CrowdSec │
     │  agent →   │  │  ↔ indexer │      │  + Zeek    │  │  parsers │
     │  manager   │  │ ↔ dashboard │     └─────┬──────┘  └────┬─────┘
     └─────┬──────┘  └────────────┘            │              │
           │                                   │ EVE JSON     │ alerts
           │ alerts                            ▼              ▼
           ▼                              ┌──────────────────────┐
     ┌──────────────┐                     │   wazuh-manager      │
     │  WAZUH SIEM  │◄────────────────────┤   (correlación)      │
     │  Dashboard   │                     └──────────────────────┘
     └──────┬───────┘
            │
            │ webhook on alert
            ▼
     ┌──────────────┐         ┌──────────────┐         ┌──────────────┐
     │     n8n      │◄───────►│     MISP     │◄───────►│  LACNIC      │
     │ (SOAR)       │  IOCs   │  (threat     │  feeds  │  CSIRT,      │
     │              │         │   intel)     │         │  Spamhaus,   │
     └──────┬───────┘         └──────────────┘         │  Shadowserver│
            │                                          └──────────────┘
            │ analyze with LLM
            ▼
     ┌──────────────┐         ┌──────────────┐
     │    Ollama    │◄───────►│  Open WebUI  │
     │  (LLM API)   │         │  (UI humana) │
     └──────────────┘         └──────────────┘
```

## Por capa

### Capa 1 — Higiene de borde (Routinator)

- **Routinator** valida ROAs RPKI desde los repositorios de los RIRs.
- Expone RTR en `:3323` para que los routers BGP consulten la validez.
- Sin esta capa, todo lo demás es decoración.

### Capa 2 — Visibilidad (pmacct → Akvorado → Grafana)

- Los routers exportan **NetFlow / sFlow / IPFIX** a `:2055` y `:6343`.
- **Akvorado** los procesa y los guarda en **ClickHouse**.
- **Grafana** se conecta a ClickHouse para dashboards.
- Sin visibilidad, las capas 3 y 4 ven a ciegas.

### Capa 3 — Detección (CrowdSec + Suricata + Wazuh + Zeek)

- **CrowdSec** parsea logs (sshd, nginx, iptables) y bloquea automáticamente.
- **Suricata** corre en SPAN, exporta EVE JSON.
- **Wazuh** recibe agentes y EVE JSON, correlaciona y alerta.
- **Zeek** (no incluido por default, opcional) genera logs ricos por sesión.

### Capa 4 — Mitigación (fastnetmon)

- **fastnetmon** consume los flows.
- Cuando detecta un DDoS volumétrico contra una IP, dispara RTBH vía ExaBGP.
- Para FlowSpec, requiere upstream que lo soporte (Telxius, Cogent, Lumen).

### Capa 5 — Intel + automatización (MISP + n8n + Ollama)

- **MISP** federa IOCs con LACNIC CSIRT y otros feeds.
- **n8n** es el orquestador: recibe webhooks de Wazuh, consulta MISP, dispara acciones.
- **Ollama** es el LLM local para análisis. **Nada sale a APIs externas.**

## Decisiones arquitectónicas

### Por qué ClickHouse y no Elastic

- Akvorado fue diseñado para ClickHouse, mejor performance para flows.
- Wazuh ya trae su propio indexer (basado en OpenSearch/Elastic), separado.
- Mantener stacks separados evita acoplamientos.

### Por qué CrowdSec y Wazuh juntos

- **CrowdSec** es excelente bloqueando rápido en bordes (CPEs, servers).
- **Wazuh** es excelente correlacionando y dando vista global SIEM.
- Se complementan: CrowdSec actúa, Wazuh investiga.

### Por qué Ollama y no API externa

- **Soberanía del dato.** Logs de tu red no salen.
- **Determinismo en prep.** Podés probar el mismo prompt 10 veces.
- **Costo cero variable.** Pagaste el hardware, no pagás por token.
- **Latencia controlada.** No depende de la red al exterior.

### Por qué profiles en docker-compose

- Permite levantar capas selectivamente.
- Permite probar el stack sin tener que correr todo.
- Permite a operadores chicos arrancar con `capa1 + capa2` y crecer.

## Lo que NO está en el stack (deliberadamente)

| Pieza | Por qué no está |
|---|---|
| **OpenCTI** | Excelente, pero MISP cubre el caso de uso para un ISP. Si tu org tiene SOC dedicado, sumalo. |
| **TheHive + Cortex** | Caso de uso similar a n8n + workflow custom. Si manejás muchos casos paralelos, valoralo. |
| **Stamus Networks** | Comunidad gratis, pero capa de Suricata. Si Suricata sin frontend te alcanza, no lo necesitás. |
| **ExaBGP** | Necesario para fastnetmon → BGP, pero requiere config con tu setup BGP real. Documentado en [`fastnetmon/README.md`](../stack/fastnetmon/README.md). |
| **Arkime** | Captura full PCAP. Excelente para forensia, pero requiere mucho disco. Sumar si tu caso lo justifica. |
| **CDN / WAF** | Es paga (aunque Cloudflare tiene tier free). No incluida porque es servicio, no software. |

## Dependencias entre servicios

| Servicio | Depende de | Notas |
|---|---|---|
| Akvorado | clickhouse | Storage de flows |
| Grafana | clickhouse, akvorado | Solo datasource |
| wazuh-manager | wazuh-indexer | Storage de eventos |
| wazuh-dashboard | wazuh-indexer, wazuh-manager | UI |
| misp | misp-db, misp-redis | DB y cache |
| open-webui | ollama | API del LLM |
| n8n | (cualquiera con API) | Orquesta |

## Recursos esperados (production-ready)

> **Atención:** el stack completo requiere una **alta cantidad de recursos de hardware**. Los valores de la tabla siguiente son orientativos para entornos de producción. Evaluá tu capacidad disponible antes de desplegar.

| Setup | RAM | CPU | Disco | Uso típico |
|---|---|---|---|---|
| **Mínimo (capa 1+2)** | 4 GB | 2 vCPU | 50 GB | WISP arrancando |
| **Estándar (capa 1-4)** | 8 GB | 4 vCPU | 100 GB | ISP retail consolidado |
| **Completo (capa 1-5 + LLM)** | 32 GB | 8 vCPU | 200 GB | ISP empresarial / hosting |
| **Completo + GPU NVIDIA** | 32 GB + RTX 3060 | 8 vCPU + GPU | 200 GB | Equipo sec con LLM intensivo |
| **Completo + Apple Silicon** | Mac Mini M2 Pro 32 GB | 10+16 CPU + 19 GPU | 200 GB | Equipo sec con LLM, Ollama nativo vía Metal |

## Backup y disaster recovery

- **ClickHouse, Wazuh indexer, MISP DB**: backup diario con `mysqldump` / snapshots.
- **Configuraciones**: en git, no en disco.
- **Data efímera (logs, alerts)**: definir política de retención (30/90/365 días según costo de storage).

## Observabilidad del stack

Todos los servicios exponen métricas Prometheus o equivalentes. Sumá un **Prometheus** + **Alertmanager** apuntando a:

- `routinator:9556/metrics`
- `clickhouse:9363/metrics`
- `wazuh-indexer:9200/_prometheus/metrics`
- `n8n:5678/healthz`
- `crowdsec:8080/metrics` (si lo habilitás)

## Referencias cruzadas

- [Playbook DEFCON](./PLAYBOOK-DEFCON.md) — qué se ejecuta en cada nivel.
- [REFERENCES.md](./REFERENCES.md) — RFCs y links.
- [stack/README.md](../stack/README.md) — quickstart operativo.

---

Este documento forma parte de un **proyecto de prueba de concepto** con fines educativos. Se espera que evolucione como un proyecto comunitario. Ayuda.LA y sus colaboradores no ofrecen soporte técnico dedicado sin un contrato de soporte vigente. **No nos hacemos responsables por ningún mal uso** que se le pueda dar a este material.

**Autor:** Ariel S. Weher · Ayuda.LA · `ariel[at]ayuda.la`
