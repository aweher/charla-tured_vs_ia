# Wazuh — SIEM open source

[Wazuh](https://wazuh.com/) es la plataforma SIEM open source de referencia. El stack tiene tres componentes: Indexer (almacena), Manager (correlaciona), Dashboard (visualiza).

## Acceso primer login

URL: <https://localhost:5601>
Usuario: `admin`
Password: el de `WAZUH_INDEXER_PASSWORD` en tu `.env`

> ⚠️ El primer arranque tarda ~3-5 minutos. Si el dashboard no responde, esperá y volvé.

## Instalar agentes en tus servers

En cada server Linux que querés monitorear:

```bash
curl -so wazuh-agent.deb https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.7.5-1_amd64.deb
sudo WAZUH_MANAGER='IP_DEL_WAZUH_MANAGER' dpkg -i wazuh-agent.deb
sudo systemctl daemon-reload
sudo systemctl enable wazuh-agent
sudo systemctl start wazuh-agent
```

En tu Wazuh manager, registrá el agente (genera la key):

```bash
docker exec wazuh-manager /var/ossec/bin/manage_agents
```

## Lo que Wazuh detecta out-of-the-box

- Intentos de auth fallidos (sshd, sudo, web apps).
- Cambios en archivos críticos (FIM — File Integrity Monitoring).
- Vulnerabilidades en software instalado (vuln scanner integrado).
- Compliance: PCI-DSS, GDPR, HIPAA, NIST.

## Reglas custom

Agregá reglas en `./manager-data/etc/rules/local_rules.xml`. Ejemplo: alerta cuando alguien lee `/etc/shadow`:

```xml
<group name="local,syscheck,">
  <rule id="100200" level="12">
    <if_sid>550</if_sid>
    <field name="file">/etc/shadow</field>
    <description>Critical file accessed: /etc/shadow</description>
  </rule>
</group>
```

Reiniciá el manager:

```bash
docker compose restart wazuh-manager
```

## Integraciones útiles

- **MISP** — los agentes pueden enriquecer alertas con IOCs de tu MISP.
- **Suricata** — Wazuh ya parsea EVE JSON, montá el directorio de logs.
- **CrowdSec** — vía syslog, mandalas alertas de CrowdSec al puerto 1514.
- **n8n** — webhook desde Wazuh hacia n8n para automatizar respuestas.

## Recursos

> ⚠️ Wazuh es **caro en RAM**. El indexer pide 2-4GB, el manager 1-2GB, el dashboard 1GB. Total: 4-8GB solo para Wazuh. Si tu VM no llega, considerá poner Wazuh en una VM dedicada o usar `siem` profile separado.

## Referencias

- Documentación oficial: <https://documentation.wazuh.com>
- Reglas comunitarias: <https://github.com/wazuh/wazuh-ruleset>
