# Tu Red vs. La IA

Material complementario de la charla **Tu Red vs. La IA — Segurizando nuestras redes en tiempos de IA: herramientas y mejores prácticas**, dictada por **Ariel Weher** (Ayuda.LA · Board de LACNOG) en el **Encuentro Nacional de Técnicos del IXP de Argentina + Internet Day 2026**.

> **La IA no viene a reemplazar al ingeniero de redes.
> Viene a reemplazar al ingeniero que no se actualiza.**

---

## ¿Qué hay acá?

Un toolkit defensivo completo, gratis y open source, diseñado para que un ISP, hosting, datacenter, operador de telefonía IP o IoT pueda armar su postura de seguridad sin licencias y sin firmas de proveedor. Lo que vas a encontrar:

| Carpeta | Qué contiene |
|---|---|
| [`stack/`](./stack/) | `docker-compose.yml` con el stack defensivo completo (Routinator + pmacct + Akvorado + CrowdSec + Suricata + Wazuh + fastnetmon + MISP + n8n + Ollama + Open WebUI). Listo para levantar en una VM con un comando. |
| [`docs/PLAYBOOK-DEFCON.md`](./docs/PLAYBOOK-DEFCON.md) | El playbook operativo: 5 niveles de DEFCON aplicados a la red, con qué se observa, qué se ejecuta y quién decide en cada nivel. |
| [`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md) | Cómo encaja cada pieza del stack y el flujo de datos entre ellas. |
| [`docs/REFERENCES.md`](./docs/REFERENCES.md) | RFCs, lecturas recomendadas y links de referencia. |
| [`scripts/recon-as.sh`](./scripts/recon-as.sh) | El script ilustrativo que se mostró en la charla. **Solo para uso contra ASNs propios o con autorización escrita.** Léase el [disclaimer](./scripts/README.md) antes de ejecutar. |

---

## Cómo arrancar en 5 minutos

```bash
# 1. Cloná el repo
git clone https://github.com/aweher/charla-tured_vs_ia.git
cd charla-tured_vs_ia/stack

# 2. Copiá la configuración base
cp .env.example .env
# Editá .env con tus valores (ASN, prefijos, contactos, tokens)

# 3. Levantá el stack
docker compose up -d

# 4. Verificá que arrancó
docker compose ps
```

Cada servicio expone su UI en un puerto distinto. Listado en [`stack/README.md`](./stack/README.md).

---

## Filosofía del proyecto

1. **Foco gratis / open source.** Si una pieza del stack requiere licencia para uso productivo, va en una sección separada con justificación y alternativa libre.
2. **IPv4 e IPv6 con la misma prioridad.** Cualquier herramienta que no soporte IPv6 nativo se descarta.
3. **Soberanía del dato.** Nada que envíe logs o configuración a APIs públicas de terceros sin tu consentimiento explícito. LLMs corren on-prem.
4. **Reproducibilidad.** Cada configuración funcional, no `# TODO`. Si algo no está, está marcado como `not_implemented_yet/` y explicado.
5. **Anti-marketing.** Sin promesas vacías. Si una herramienta tiene contras, están en su README.

---

## El stack en una sola pantalla

```
┌─────────────────────────────────────────────────────────────────────┐
│ CAPA 1 · HIGIENE DE BORDE                                           │
│   Routinator · rpki-client · uRPF · BCP38 · bgpq4 · oktorpki        │
├─────────────────────────────────────────────────────────────────────┤
│ CAPA 2 · VISIBILIDAD                                                │
│   pmacct → Akvorado → Grafana  (NetFlow / sFlow / IPFIX, v4 + v6)   │
├─────────────────────────────────────────────────────────────────────┤
│ CAPA 3 · DETECCIÓN                                                  │
│   CrowdSec (CPEs / servers) + Suricata (SPAN)                       │
│   Wazuh (SIEM con agentes) + Zeek (análisis de protocolo)           │
├─────────────────────────────────────────────────────────────────────┤
│ CAPA 4 · MITIGACIÓN                                                 │
│   fastnetmon → RTBH automático · FlowSpec con upstream              │
│   nftables/iptables · CrowdSec bouncers                             │
├─────────────────────────────────────────────────────────────────────┤
│ CAPA 5 · INTEL + AUTOMATIZACIÓN                                     │
│   MISP + feeds LACNIC CSIRT · n8n (SOAR) · Ollama (LLM on-prem)     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Cómo usar este repo en tu organización

| Si sos... | Empezá por |
|---|---|
| **WISP / ISP retail FTTH** | RPKI + uRPF + CrowdSec + fastnetmon + Wazuh |
| **ISP empresarial** | Lo anterior + Suricata + MISP + FlowSpec con upstream |
| **Hosting / Datacenter** | Lo anterior + Arkime + Security Onion + scrubbing por upstream |
| **Telefonía IP** | Suricata con reglas SIP + Fail2Ban + geofencing + Homer |
| **IoT / M2M** | Segmentación + Zeek + APN privada + Stamus Networks Community |
| **Servicios críticos / e-commerce** | Lo de hosting + WAF de CDN (vale la pena pago aquí) |

---

## ¿Querés contribuir?

Sí, por favor. Lee [`CONTRIBUTING.md`](./CONTRIBUTING.md). Las contribuciones más bienvenidas:

- Configuraciones probadas en producción (con redacción anonimizada).
- Casos de uso de la región LATAM.
- Traducciones y correcciones de docs.
- Reportes de bugs y sugerencias de mejora.

---

## Recursos comunitarios

- **LACNOG** — <https://nog.lat>
- **LACNIC CSIRT** — <https://csirt.lacnic.net>
- **MANRS** — <https://manrs.org/isps>
- **Ayuda.LA blog** — <https://ayuda.la/blog>
- **blog.capaocho.net** — notas técnicas del autor

---

## Licencia

[MIT](./LICENSE). Usalo, modificalo, compartilo. Atribución apreciada.

---

## Disclaimer

Este proyecto se ofrece como **prueba de concepto** con fines educativos y de divulgación técnica. Su objetivo es servir como punto de partida para la comunidad y se espera que evolucione como un **proyecto comunitario** con aportes de la región. Ayuda.LA y sus colaboradores **no ofrecen soporte técnico dedicado** sobre este material. Para asistencia profesional o implementación en entornos de producción, se requiere un **contrato de soporte vigente** con Ayuda.LA. Consultas: `ariel[at]ayuda.la`.

> **Recursos de hardware:** el stack completo requiere una cantidad significativa de recursos (CPU, RAM, disco). Antes de levantar todos los servicios, consultá la tabla de requisitos en [`stack/README.md`](./stack/README.md#recursos-esperados) y [`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md#recursos-esperados-production-ready).

Este material se distribuye **tal como está**, sin garantías de ningún tipo. Las herramientas open source incluidas tienen sus propias licencias y términos. **Los autores y Ayuda.LA no se hacen responsables por ningún mal uso que se le pueda dar a este proyecto ni a las herramientas que lo componen.** El script [`recon-as.sh`](./scripts/recon-as.sh) es ilustrativo y **solo debe ejecutarse contra ASNs propios o con autorización escrita**. El uso indebido puede constituir delito.

---

**Autor:** Ariel S. Weher · Socio Gerente, Ayuda.LA · `ariel[at]ayuda.la`
**Charla:** Internet Day 2026 + Encuentro Nacional de Técnicos del IXP de Argentina
**Repo corto:** <https://enrut.ar/turedvslaia>
