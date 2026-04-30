# Playbook DEFCON aplicado a la red

Modelo operativo de cinco niveles para alinear la postura de seguridad de un ISP, hosting o datacenter con su nivel real de amenaza. Adaptado del modelo militar DEFCON, aterrizado a comandos concretos del stack del repo.

> **El nivel se declara en el NOC y dispara playbooks ya escritos. La automatización ejecuta lo previsible; el ingeniero decide lo crítico.**

---

## Por qué DEFCON y no semáforos / colores

- Los semáforos (verde / amarillo / rojo) tienen 3 niveles. La operación real necesita 5: hay diferencia entre *"todo normal"* y *"vigilancia incrementada"*, y entre *"ataque inminente"* y *"red bajo ataque"*.
- DEFCON está culturalmente instalado. La gente entiende qué significa "DEFCON 1" sin explicación.
- Permite **automatizar la respuesta sin automatizar la decisión crítica**. El nivel lo declara un humano; las acciones que dispara cada nivel pueden ser automáticas.

---

## Resumen ejecutivo

| Nivel | Estado | Disparador típico | Quién decide |
|---|---|---|---|
| **DEFCON 5** | Operación normal | Higiene de borde sin alertas | Sistema |
| **DEFCON 4** | Vigilancia incrementada | Anomalías leves IPv4/IPv6 | NOC en turno |
| **DEFCON 3** | Alerta operativa | Phishing dirigido, CVE crítico, abuso de clientes | NOC + ingeniería |
| **DEFCON 2** | Ataque inminente | Recon confirmado, intentos de explotación, DDoS bajo | Ingeniería senior + CSIRT |
| **DEFCON 1** | Red bajo ataque | Incidente activo | Ingeniería senior + dirección |

Aplica por igual a IPv4 e IPv6.

---

## DEFCON 5 — Operación normal

### Lo que se observa

- RPKI: 100% de ROAs propios validados, 0 anuncios `Invalid` en BGP entrantes.
- BCP38 verificado en cada borde de cliente.
- CrowdSec: < 50 decisiones activas (ban natural por intentos automatizados).
- Suricata: < 10 alertas críticas/día.
- Wazuh: ningún alert level ≥ 12 en últimas 24h.
- fastnetmon: tráfico dentro del baseline esperado.
- Sin reportes externos (Shadowserver, abuse@) abiertos.

### Lo que se ejecuta (automático)

- Reportes semanales de salud del stack.
- Sync diario de feeds MISP / LACNIC CSIRT.
- Backup automático de configs.
- Validación periódica de ROAs con `oktorpki` en CI/CD.

### Lo que NO se hace

- No se hacen cambios significativos en producción los viernes.
- No se silencian alertas "porque están haciendo ruido".
- No se desactivan herramientas "porque no las miramos".

### Salida del nivel

A DEFCON 4 cuando aparece: anomalía leve sostenida >30 min, alerta de Wazuh level ≥10, reporte externo recibido, CVE crítico publicado en stack relevante.

---

## DEFCON 4 — Vigilancia incrementada

### Lo que se observa

- Anomalías leves en NetFlow/sFlow (puerto/protocolo no esperado).
- Aumento de intentos auth fallidos (+30% sobre baseline).
- Reporte externo (Shadowserver, abuse) con 1-3 hosts comprometidos.
- CVE crítico publicado afectando software del stack en uso.
- Phishing genérico detectado contra empleados.

### Lo que se ejecuta (semi-automático)

- **Suricata:** activación de reglas adicionales del set ET Open relevantes al CVE.
- **MISP:** enriquecimiento de IOCs relacionados al CVE.
- **CrowdSec:** revisión manual de decisiones activas, ajuste de scenarios si corresponde.
- **NOC:** verifica baseline de tráfico cada hora durante el turno.
- **Comunicación:** ticket interno abierto, equipo notificado por canal NOC.

### Comandos típicos

```bash
# Refrescar feeds y revisar IOCs nuevos
docker exec misp /var/www/MISP/app/Console/cake Server fetchFeeds all

# Listar decisiones recientes en CrowdSec
docker exec crowdsec cscli alerts list --since 1h

# Ver alertas de Wazuh nivel ≥10 últimas 6h
curl -k -u admin:$WAZUH_API_PASSWORD \
  "https://localhost:55000/security/user/authenticate" | jq -r .data.token

# Métricas de tráfico para chequear anomalías
curl http://localhost:9556/metrics | grep routinator_vrps
```

### Subida a DEFCON 3

Cuando se confirma intencionalidad: spear phishing dirigido (no genérico), intento de explotación detectado, abuso de cliente con repetición, anomalía sostenida >2h.

---

## DEFCON 3 — Alerta operativa

### Lo que se observa

- Spear phishing con datos internos (caso del [slide 7](../README.md#-charla)).
- Intento de explotación de CVE en sistema productivo (block exitoso por WAF / IPS, pero confirmado).
- Cliente con CPE comprometido participando en botnet (reporte Shadowserver).
- DDoS volumétrico < 1 Gbps detectado y mitigado por upstream.
- Anomalía persistente sin causa identificada.

### Lo que se ejecuta

#### Automático

- **fastnetmon:** threshold bajado al 80% del normal.
- **CrowdSec:** todas las decisiones nuevas se replican a MISP como IOCs.
- **n8n:** workflow de notificación a Telegram/Slack al NOC.
- **Wazuh:** activación de "active response" para bloqueos automáticos en sshd, web.
- **Backup adicional:** snapshot de configs antes de cualquier cambio.

#### Manual

- **NOC en guardia activa** durante el incidente.
- **Cliente comprometido:** notificación formal vía email + teléfono (no solo email).
- **CVE crítico:** parcheo coordinado con ventana de mantenimiento o emergency patch si aplica.

### Comandos típicos

```bash
# Bajar threshold de fastnetmon temporariamente
docker exec fastnetmon \
  sed -i 's/^threshold_pps.*/threshold_pps = 30000/' /etc/fastnetmon/fastnetmon.conf
docker compose restart fastnetmon

# Forzar refresh de IOCs
docker exec misp /var/www/MISP/app/Console/cake Server pullAll all

# Revisar cliente comprometido en Shadowserver
curl -s "https://dashboard.shadowserver.org/asn/AS65007/" | grep compromised

# Activar reglas SIP estrictas (si telefonía)
docker exec suricata suricata-update enable-source ptresearch/attackdetection
docker compose restart suricata
```

### Comunicación

- Ticket público interno con timestamps de cada acción.
- Update cada 30 minutos al equipo, aunque sea "sin novedades".
- **Si el incidente afecta clientes finales: aviso público** (status page, redes sociales).

### Subida a DEFCON 2

Cuando: el atacante es claramente persistente, hay rotación de vectores, hay extorsión declarada, o se detectan IOCs de TTPs avanzadas.

---

## DEFCON 2 — Ataque inminente

### Lo que se observa

- Recon agresivo confirmado contra perímetro (escaneo masivo, intentos sistemáticos).
- Intentos de explotación múltiples desde IPs distribuidas.
- DDoS volumétrico bajo (< 5 Gbps) sostenido.
- Mensaje de extorsión RDDoS recibido (caso [slide 9](../README.md#-charla)).
- Compromiso confirmado de uno o más sistemas internos (sin lateral movement aún).

### Lo que se ejecuta

#### Pre-activación de mitigaciones

```bash
# 1. FlowSpec listo para disparar contra patrones conocidos
# (preparar la regla, no aplicar todavía)

# 2. RTBH preactivado en routers de borde (community lista)
# 3. Scrubbing pago contactado (si lo tenés en standby)
# 4. CDN con WAF activado para sitios críticos
# 5. SBC: rate limit + geofencing emergency
```

#### Equipo

- **Ingeniería senior en standby 24/7** durante la fase activa.
- **CSIRT regional notificado** (LACNIC CSIRT, NOG locales).
- **Dirección notificada** (no para decidir técnico, para comunicar legalmente / financieramente).

#### Comunicación

- **Status page actualizada** cada 15 minutos.
- **Clientes corporativos críticos avisados** individualmente (call lead).
- **Coordinación con upstreams** — abrir tickets formales con prioridad alta.

### Subida a DEFCON 1

Cuando el ataque empieza a impactar producción de manera medible: downtime, degradación de servicio, lateral movement detectado, exfiltración confirmada.

---

## DEFCON 1 — Red bajo ataque

### Lo que se observa

- Ataque activo en curso con impacto medible en producción.
- Múltiples superficies bajo presión simultánea (caso [slide 9](../README.md#-charla)).
- Posible extorsión activa.
- Posible compromiso interno con lateral movement.

### Lo que se ejecuta

#### Mitigación automática (lo que ya estaba pre-configurado)

- **fastnetmon → RTBH** en milisegundos para volumétrico.
- **FlowSpec** disparado contra patrones conocidos.
- **Scrubbing pago activado** si el caso lo justifica.
- **CDN WAF** en modo "Under Attack".

#### Decisión humana

- **Qué servicio sacrificar primero** (si hay que priorizar). Esta decisión la toma ingeniería senior con apoyo de dirección, **no la guardia de turno**.
- **Cuándo cortar comunicación con upstream específico** (si el upstream está siendo el problema).
- **Si se llama o no a fuerzas de seguridad** (decisión legal, no técnica).
- **Si se acepta o no la extorsión** (NO se debería, pero la decisión es del cliente).

#### Comunicación

- **Sala de crisis**: NOC + ingeniería + dirección + comunicaciones.
- **Status page con frecuencia de actualización < 5 min.**
- **Clientes corporativos críticos**: con el incidente comandante en línea.
- **Comunicación pública**: solo a través de canales oficiales del operador.
- **Postmortem prometido** públicamente, dentro de 7-14 días.

### Cierre del incidente (de DEFCON 1 → 4 → 5)

1. **Mitigación efectiva** sostenida >2h sin nueva escalada.
2. **Servicios restablecidos** verificados por NOC y por sondas externas.
3. **Sistemas comprometidos**: aislados, analizados forensemente, reinstalados desde backups limpios.
4. **Postmortem escrito** dentro de 7 días, publicado dentro de 14.
5. **Mejoras implementadas** documentadas en este playbook.

---

## Decisiones que dispara cada nivel

| Decisión | DEFCON 5 | DEFCON 4 | DEFCON 3 | DEFCON 2 | DEFCON 1 |
|---|---|---|---|---|---|
| Threshold fastnetmon | normal | normal | -20% | -40% | mínimo |
| Suricata reglas adicionales | — | sí, ET Open relevantes | sí | sí | todas |
| MISP refresh feeds | diario | cada 4h | cada hora | cada 30 min | continuo |
| NOC en guardia | turno normal | turno normal | activa | senior on-call | sala de crisis |
| Comunicación al equipo | semanal | ticket interno | canal NOC | dirección | dirección + legal |
| Comunicación a clientes | — | — | si afecta | sí, individual | status page +5min |
| Comunicación pública | — | — | — | si aplica | obligatorio |
| CSIRT regional | — | — | informativo | notificado | activo |
| Documentación postmortem | — | — | recomendado | obligatorio | obligatorio + público |

---

## Errores comunes

### "Vivimos en DEFCON 3"

Si todos los días estás en DEFCON 3, en realidad **estás en DEFCON 5 con malas alertas**. Recalibrá thresholds. La saturación de alertas es la mayor causa de incidentes no detectados.

### "Subir DEFCON sin bajar DEFCON"

Después de un incidente, hay que **bajar el nivel formalmente**. Si no, el equipo se acostumbra al estado de alerta y deja de prestar atención cuando vuelve a subir.

### "Declarar DEFCON sin tener el playbook escrito"

DEFCON sin playbook es teatro. Antes de adoptar este modelo, tiene que estar escrito **qué se hace en cada nivel** para tu operación específica. Este documento es un punto de partida.

### "DEFCON como herramienta de blame"

Los niveles no son para señalar a quién falló. Son para alinear acciones. Si el equipo siente que DEFCON es para repartir culpas, lo van a evitar declarar — y vas a perder la herramienta.

---

## Cómo personalizar para tu operación

1. **Definir tus baselines.** Tu DEFCON 5 es distinto al de otro ISP. Medí 4 semanas de operación normal y documentá los rangos.
2. **Listar tus disparadores específicos.** ¿Qué eventos en tu stack disparan cada subida? Documentalo.
3. **Asignar responsables.** ¿Quién declara DEFCON 4? ¿Quién DEFCON 2? Por nombre, no por rol.
4. **Probar en simulacro.** Una vez al trimestre, simular un incidente y declarar nivel. Ver si el playbook funciona.
5. **Iterar.** Después de cada incidente real, actualizar el playbook con lo aprendido.

---

## Referencias

- Charla **Tu Red vs. La IA** — Slide 12-bis: tabla resumen DEFCON.
- NIST SP 800-61 Rev. 2 — Computer Security Incident Handling Guide.
- LACNIC CSIRT — coordinación regional: <https://csirt.lacnic.net>
- FIRST.org — best practices de respuesta a incidentes: <https://www.first.org>

---

**Este es un documento vivo.** Si tu operación encontró un patrón mejor, abrí un PR.

> **Disclaimer:** este playbook forma parte de un **proyecto de prueba de concepto** con fines educativos y de divulgación técnica. Las acciones descritas pueden tener impacto operativo real en una red en producción. Ayuda.LA y sus colaboradores no ofrecen soporte técnico dedicado sin un contrato de soporte vigente. **No nos hacemos responsables por ningún mal uso o consecuencia derivada de la aplicación de este material.** El stack asociado requiere una alta cantidad de recursos de hardware; consultá los requisitos en [`stack/README.md`](../stack/README.md) y [`ARCHITECTURE.md`](./ARCHITECTURE.md) antes de implementar.
>
> **Autor:** Ariel S. Weher · Ayuda.LA · `ariel[at]ayuda.la`
