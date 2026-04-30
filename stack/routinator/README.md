# Routinator — Validador RPKI

[Routinator](https://nlnetlabs.nl/projects/routing/routinator/) es el validador RPKI de referencia, mantenido por NLnet Labs. Sincroniza ROAs desde los repositorios de los RIRs y expone una interfaz RTR para que tus routers BGP consulten la validez de orígenes en tiempo real.

## Por qué empezar por acá

> **Si todavía no firmaste tus ROAs, lo demás no te va a salvar.**

Es la capa 1 de defensa. Sin RPKI validado en el borde, cualquier secuestro de prefijos pasa sin protesta. Todos los Tier-1 ya descartan rutas inválidas; si tu ASN anuncia un prefijo con ROA inválido, vas a tener problemas de alcance.

## Configuración inicial

Routinator viene listo con los TALs (Trust Anchor Locators) de los 5 RIRs.

```bash
docker compose up -d routinator
docker compose logs -f routinator
```

Esperá ~5 minutos al primer `rsync` completo. Verificá que valida:

```bash
curl http://localhost:9556/api/v1/status | jq
```

## Conectar tu router BGP

Routinator expone RTR en `tcp/3323`. Configurá tu router así:

### Cisco IOS-XR

```
router bgp 65007
  rpki server 198.51.100.10
    transport tcp port 3323
    refresh-time 600
```

### Juniper Junos

```
routing-options {
    validation {
        group rpki-routinator {
            session 198.51.100.10 {
                port 3323;
                refresh-time 600;
            }
        }
    }
}
```

### Mikrotik RouterOS 7

```
/routing rpki add address=198.51.100.10 port=3323 group=routinator
```

### BIRD 2

```
roa4 table r4;
roa6 table r6;

protocol rpki {
    roa4 { table r4; };
    roa6 { table r6; };
    remote "198.51.100.10" port 3323;
    refresh keep 60;
    retry keep 90;
}
```

## Verificar que está funcionando

Desde un router BGP que ya recibe el feed:

```
show rpki server detail
show ip bgp validation
```

Deberías ver tres estados: **Valid**, **Invalid**, **NotFound**. Configurá tu policy para descartar `Invalid` y preferir `Valid` sobre `NotFound`.

## Métricas

Routinator expone Prometheus-compatible metrics:

```bash
curl http://localhost:9556/metrics
```

Conectá a tu Grafana del stack para visualizar.

## Siguientes pasos

1. **Firmá tus ROAs** en LACNIC: <https://rpki.lacnic.net>
2. **Validá emisión** con [oktorpki](https://github.com/cloudflare/cfrpki) en CI/CD.
3. **Adherí a MANRS**: <https://manrs.org/isps>

## Referencias

- RFC 6480 — Resource Public Key Infrastructure (RPKI) Architecture
- RFC 8210 — RPKI to Router Protocol v1
- LACNIC RPKI portal: <https://rpki.lacnic.net>
- Validador FORT (alternativa regional): <https://fortproject.net>
