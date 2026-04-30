# fastnetmon Community — Detección y mitigación de DDoS

[fastnetmon](https://fastnetmon.com/) es la herramienta open source para detectar y mitigar DDoS volumétricos en ISPs. La versión Community es GPL-2.0; existe una Advanced paga que suma FlowSpec avanzado, soporte y multi-tenant.

## Cómo funciona

1. Recibe sFlow/NetFlow de tus routers de borde.
2. Calcula thresholds de tráfico por IP.
3. Cuando una IP supera el threshold (víctima de DDoS volumétrico), dispara una acción configurable: anuncio BGP RTBH, llamada a un script, notificación.

## Configuración mínima

Editá `./etc/fastnetmon.conf` con tus datos:

```ini
# Interfaces de captura (si usás mirror/SPAN local)
interfaces = eth0

# O bien si recibís sFlow/NetFlow de routers externos
mirror_netflow = on
mirror_sflow = on
netflow_port = 2056      # OJO: distinto del 2055 que usa Akvorado
sflow_port = 6344        # OJO: distinto del 6343 que usa Akvorado

# Tus prefijos a monitorear
networks_list_path = /etc/fastnetmon/networks_list

# Threshold inicial (bajo = más sensible)
threshold_pps = 50000
threshold_mbps = 1000
threshold_flows = 3500

# Acción al detectar DDoS
notify_script_path = /etc/fastnetmon/notify.sh
exabgp = on
exabgp_command_pipe = /var/run/exabgp.cmd
exabgp_community = 65007:666
```

Y en `./etc/networks_list`:

```
198.18.0.0/15
2001:db8::/32
```

## Integración con BGP RTBH

fastnetmon puede anunciar la IP víctima a tu router BGP vía community RTBH. Necesitás:

1. **ExaBGP** corriendo (lo configurás aparte, no está en el compose por defecto porque depende de tu setup BGP real).
2. **Community RTBH acordada** con tu upstream. Telxius, Cogent y Lumen ya tienen comunidades RTBH públicas.

```bash
# notify.sh ejemplo
#!/bin/bash
ip=$1
action=$2  # "ban" o "unban"
if [ "$action" = "ban" ]; then
  echo "announce route $ip/32 next-hop 192.0.2.1 community 65007:666" \
    > /var/run/exabgp.cmd
fi
```

## Threshold: empezar alto e ir bajando

**Error común:** poner threshold bajo el primer día y blackholear clientes legítimos.

**Recomendado:**

```ini
threshold_pps = 200000      # primer día
threshold_mbps = 5000       # primer día
threshold_flows = 10000     # primer día
```

Después de 2 semanas observando tu baseline, ajustá. Lo típico para un ISP regional:

```ini
threshold_pps = 50000
threshold_mbps = 1000
threshold_flows = 3500
```

## Verificar que está funcionando

```bash
# Stats en tiempo real
docker exec fastnetmon fastnetmon_client

# Ver si está detectando flujos
docker exec fastnetmon tail -f /var/log/fastnetmon/fastnetmon.log
```

## Tests sintéticos (en lab, no en prod)

Generá un flood controlado contra un host de pruebas:

```bash
# En el atacante (otra VM)
hping3 --flood --rand-source -p 80 198.51.100.10
```

fastnetmon debería detectarlo en segundos.

## Cuándo conviene la Advanced (paga)

- Si necesitás **FlowSpec automático** (no solo RTBH).
- Si tenés multi-tenancy real (varios clientes que cada uno vea solo lo suyo).
- Si SLA de soporte 24/7 te justifica el costo.

Para un ISP chico/mediano, Community alcanza. Avanzá a Advanced solo cuando tengas el caso de uso medido.

## Referencias

- Repo: <https://github.com/pavel-odintsov/fastnetmon>
- Documentación oficial: <https://fastnetmon.com/docs-fnm-advanced/>
- Telxius RTBH: pedí specs a tu account manager
- Cogent BGP communities: <https://www.cogentco.com/files/docs/network/network_overview/cogent_global_network_routing_policy.pdf>
