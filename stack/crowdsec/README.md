# CrowdSec — Detección colaborativa

[CrowdSec](https://www.crowdsec.net/) es un motor de detección y respuesta open source con un componente comunitario que comparte IPs maliciosas entre todos los usuarios. En la práctica funciona como un Fail2Ban moderno con threat intel global.

## Cómo arrancarlo

```bash
docker compose up -d crowdsec
docker compose logs -f crowdsec
```

Las collections básicas (`linux`, `sshd`, `iptables`, `nginx`) ya están configuradas en el `docker-compose.yml` vía la variable `COLLECTIONS`.

## Bouncers (los que efectivamente bloquean)

CrowdSec **detecta** pero no bloquea solo — para eso necesitás un *bouncer*. Algunos comunes:

| Bouncer | Para qué | Instalación |
|---|---|---|
| `crowdsec-firewall-bouncer-iptables` | Bloqueo a nivel kernel | `apt install crowdsec-firewall-bouncer-iptables` (en el host, no en el contenedor) |
| `crowdsec-nginx-bouncer` | Bloqueo a nivel app web | `apt install crowdsec-nginx-bouncer` |
| `crowdsec-cloudflare-bouncer` | Bloqueo en CDN | `apt install crowdsec-cloudflare-bouncer` |

Los bouncers deben correr en el host con acceso a iptables/nftables, no dentro del contenedor de CrowdSec.

## Generar API key para un bouncer

```bash
docker exec crowdsec cscli bouncers add my-firewall-bouncer
```

Te devuelve una API key. Configurala en el bouncer del host.

## Ver qué está detectando

```bash
# Decisiones activas (IPs bloqueadas)
docker exec crowdsec cscli decisions list

# Alertas recientes
docker exec crowdsec cscli alerts list

# Métricas en tiempo real
docker exec crowdsec cscli metrics
```

## Comunidad: alimentarse del feed colaborativo

Por defecto, CrowdSec consulta el feed comunitario (gratis con cuota generosa). Para inscribirte y aumentar el quota, registrate en <https://app.crowdsec.net> y vinculá tu instancia:

```bash
docker exec crowdsec cscli console enroll <ENROLL_KEY>
```

## Reglas custom

Agregá parsers o scenarios propios en `./config/parsers.d/` y `./config/scenarios.d/`. Después:

```bash
docker exec crowdsec cscli hub list
docker exec crowdsec cscli scenarios install <tu-scenario>
```

## Integración con Wazuh

CrowdSec puede mandar sus alertas a Wazuh vía syslog. En `./config/profiles.yaml` agregá:

```yaml
- name: send_to_wazuh
  filters:
    - "Alert.Remediation == true"
  decisions:
    - type: ban
      duration: 4h
  notifications:
    - http_default
```

Y configurá un notification HTTP target apuntando al puerto 1514 del wazuh-manager.

## Referencias

- Hub de CrowdSec: <https://hub.crowdsec.net>
- Bouncers: <https://hub.crowdsec.net/author/crowdsecurity/bouncers>
- Comunidad regional: <https://discord.gg/crowdsec>
