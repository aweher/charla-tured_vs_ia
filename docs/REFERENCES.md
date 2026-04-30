# Referencias técnicas

RFCs, lecturas, herramientas y links útiles para profundizar en lo que vimos en la charla.

## RFCs esenciales

### Routing security

- **RFC 7454** — BGP Operations and Security
- **RFC 8210** — RPKI to Router Protocol v1
- **RFC 6480** — Resource Public Key Infrastructure (RPKI) Architecture
- **RFC 6483** — Validation of Route Origination Using the Resource Certificate Public Key Infrastructure (RPKI) and Route Origin Authorizations (ROAs)
- **RFC 9582** — A Profile for ROAs (la versión moderna)

### Anti-spoofing

- **RFC 2827 / BCP38** — Network Ingress Filtering: Defeating Denial of Service Attacks which employ IP Source Address Spoofing
- **RFC 3704 / BCP84** — Ingress Filtering for Multihomed Networks
- **RFC 5635** — Remote Triggered Black Hole Filtering with Unicast Reverse Path Forwarding (uRPF)

### FlowSpec

- **RFC 5575 / 8955** — Dissemination of Flow Specification Rules (BGP FlowSpec)
- **RFC 8956** — FlowSpec for IPv6

### Otros

- **RFC 6996** — ASNs privados para uso interno (`64512-65534` y `4200000000-4294967294`)
- **RFC 5398** — IANA-Reserved IPv4 Prefix for Documentation
- **RFC 5737** — IPv4 Address Blocks Reserved for Documentation (`192.0.2.0/24`, `198.51.100.0/24`, `203.0.113.0/24`)
- **RFC 3849** — IPv6 Address Prefix Reserved for Documentation (`2001:db8::/32`)
- **RFC 2544** — Benchmarking Methodology (`198.18.0.0/15`)

## Reportes y datos abiertos

- **Cloudflare Radar** — <https://radar.cloudflare.com>
  Datos en tiempo real de tráfico, ataques, BGP, DNS.

- **Imperva Bad Bot Report** (anual) — <https://www.imperva.com/resources/resource-library/reports/bad-bot-report/>
  Tracking del tráfico bot global.

- **ENISA Threat Landscape** (anual) — <https://www.enisa.europa.eu/topics/threat-risk-management/threats-and-trends/enisa-threat-landscape>
  Panorama europeo, aplicable a la región.

- **Shadowserver Dashboard** — <https://dashboard.shadowserver.org>
  Reportes diarios de hosts comprometidos y vulnerables por ASN. **Gratis para operadores.**

- **LACNIC CSIRT** — <https://csirt.lacnic.net>
  Feeds y reportes regionales LATAM.

- **NIST RPKI Monitor** — <https://rpki-monitor.antd.nist.gov>
  Estado de adopción RPKI global.

- **MANRS Observatory** — <https://observatory.manrs.org>
  Compliance de operadores con MANRS.

## Herramientas (linkadas en el stack)

### Validadores RPKI

- **Routinator** (NLnet Labs) — <https://nlnetlabs.nl/projects/routing/routinator/>
- **FORT Validator** (NIC.MX/LACNIC) — <https://fortproject.net>
- **rpki-client** (OpenBSD) — <https://www.rpki-client.org>
- **oktorpki / cfrpki** (Cloudflare) — <https://github.com/cloudflare/cfrpki>

### IRR

- **bgpq4** — <https://github.com/bgp/bgpq4>
- **irrd4** — <https://irrd.readthedocs.io>

### Visibilidad de flujos

- **pmacct** — <http://www.pmacct.net>
- **Akvorado** — <https://akvorado.net>
- **NfSen / NFDUMP** — <https://github.com/phaag/nfdump>
- **Arkime** (PCAP a escala) — <https://arkime.com>
- **ElastiFlow** — <https://www.elastiflow.com>

### Detección

- **CrowdSec** — <https://www.crowdsec.net>
- **Suricata** — <https://suricata.io>
- **Zeek** (ex Bro) — <https://zeek.org>
- **Wazuh** — <https://wazuh.com>
- **Security Onion** — <https://securityonionsolutions.com>
- **Stamus Networks Community** — <https://www.stamus-networks.com>
- **Homer** (VoIP/SIP) — <https://sipcapture.org>
- **Fail2Ban** — <https://www.fail2ban.org>

### Mitigación

- **fastnetmon** — <https://fastnetmon.com>
- **netfilter** — <https://www.netfilter.org>

### Threat intel

- **MISP** — <https://www.misp-project.org>
- **OpenCTI** — <https://www.opencti.io>
- **TheHive + Cortex** — <https://strangebee.com>
- **AbuseIPDB** — <https://www.abuseipdb.com>
- **Spamhaus** — <https://www.spamhaus.org>
- **Team Cymru** — <https://www.team-cymru.com>

### Automatización

- **n8n** — <https://n8n.io>
- **Node-RED** — <https://nodered.org>

### LLMs locales

- **Ollama** — <https://ollama.com>
- **vLLM** — <https://docs.vllm.ai>
- **llama.cpp** — <https://github.com/ggml-org/llama.cpp>
- **Open WebUI** — <https://github.com/open-webui/open-webui>
- **LM Studio** — <https://lmstudio.ai>

## Sitios de referencia operativa

- **bgp.tools** — <https://bgp.tools>
  Explorer BGP global con datos crudos.

- **RIPEstat** — <https://stat.ripe.net>
  Plataforma de información de Internet del RIPE NCC.

- **crt.sh** — <https://crt.sh>
  Buscador de certificados públicos (Certificate Transparency).

- **Shodan InternetDB** — <https://internetdb.shodan.io>
  Servicios expuestos por IP, sin API key.

- **PeeringDB** — <https://www.peeringdb.com>
  Información de peering y IXPs.

## Comunidades

### Regionales

- **LACNOG** — <https://nog.lat>
- **LACNIC** — <https://www.lacnic.net>
- **CABASE** (Argentina) — <https://cabase.org.ar>
- **ARNOG** (Argentina) — <https://arnog.org>
- **MX-NOG** (México) — <https://mxnog.org>
- **PE-NOG** (Perú) — <https://www.penog.pe>
- **CR-NOG** (Costa Rica) — <https://www.cr-nog.org>

### Globales

- **NANOG** — <https://www.nanog.org>
- **RIPE NCC** — <https://www.ripe.net>
- **APNIC** — <https://www.apnic.net>
- **AFRINIC** — <https://www.afrinic.net>
- **MANRS** — <https://www.manrs.org>
- **FIRST** — <https://www.first.org>

## Newsletters y blogs

- **Ayuda.LA** — <https://ayuda.la/blog>
- **blog.capaocho.net** — notas técnicas del autor de la charla
- **APNIC Blog** — <https://blog.apnic.net>
- **RIPE Labs** — <https://labs.ripe.net>
- **The Cloudflare Blog** — <https://blog.cloudflare.com>

## Charlas y videos relacionados

Por curar — abrí PR con tus recomendaciones.

## Glosario

- **RPKI** — Resource Public Key Infrastructure
- **ROA** — Route Origin Authorization
- **BCP38** — Best Current Practice 38, anti-spoofing en borde
- **MANRS** — Mutually Agreed Norms for Routing Security
- **RTBH** — Remotely Triggered Black Hole
- **FlowSpec** — Filtros L3/L4 distribuidos por BGP
- **MTTR** — Mean Time To Repair / Recover
- **MTTD** — Mean Time To Detect
- **IOC** — Indicator of Compromise
- **SOAR** — Security Orchestration, Automation and Response
- **SIEM** — Security Information and Event Management
- **NDR** — Network Detection and Response
- **EDR** — Endpoint Detection and Response
- **XDR** — Extended Detection and Response
- **CSIRT** — Computer Security Incident Response Team
- **NOG** — Network Operators Group
- **IXP** — Internet Exchange Point
