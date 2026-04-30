# scripts/

Herramientas de la charla. **Léase los disclaimers antes de ejecutar.**

## ⚠️ Aviso legal previo

Los scripts de este directorio acceden a APIs públicas para recopilar información sobre infraestructura de red. **Aunque sean 100% pasivos**, su uso fuera del alcance autorizado puede:

- Constituir delito según la jurisdicción (Argentina: Ley 26.388 de Delitos Informáticos).
- Violar términos de servicio de las APIs consultadas (bgp.tools, GitHub, etc.).
- Exponerte a acciones legales del titular del ASN/dominio.

**El autor y Ayuda.LA no se responsabilizan por uso indebido.**

## Reglas de uso

| Caso | ¿Permitido? | Requiere |
|---|---|---|
| Tu propio ASN | ✅ Sí | Nada |
| ASN de doc (RFC 6996, 5398, 5737, 3849) | ✅ Sí | Nada — usado en demos |
| ASN de cliente, con autorización escrita | ✅ Sí | [Plantilla de autorización](./AUTORIZACION-RECON.md) firmada |
| ASN de tercero sin autorización | ❌ No | Aunque las APIs sean públicas |
| Construcción de leads comerciales | ❌ No | Viola ToS de las APIs |
| Pentesting sin autorización | ❌ No | Delito |

## Política de divulgación responsable

Si en una ejecución autorizada encontrás un hallazgo crítico (credenciales filtradas, vuln severa, exposición indebida) en un target con permiso, **debés**:

1. **Notificar al titular** del ASN/dominio en privado, antes de cualquier publicación.
2. Otorgar **mínimo 30 días** para que remedien antes de mencionarlo públicamente.
3. **Excluir de cualquier presentación pública** los hallazgos que el titular pida mantener confidenciales.

## Scripts

### `recon-as.sh`

Reconnaissance pasivo de un ASN: prefijos BGP, certificados históricos, subdominios, servicios expuestos en Shodan InternetDB, secretos en GitHub público.

**Uso:**

```bash
./recon-as.sh [ASN] [DOMINIO]
./recon-as.sh AS65007 example.com   # ejemplos de doc
./recon-as.sh AS<TU_ASN> tu-dominio.com   # tu propia infra
```

**Dependencias:**

- `curl`, `jq`, `dig` (presentes en cualquier Linux)
- Opcionales: `wappalyzer`, `ollama` (corre el LLM local)

**Salida:**

- `./targets/<ASN>/report.md` — reporte resumen
- `./targets/<ASN>/findings.json` — datos crudos
- `./targets/<ASN>/dns.txt` — resoluciones DNS
- `./targets/<ASN>/shodan-*.json` — snapshots InternetDB
- `./targets/<ASN>/summary.md` — resumen del LLM (si Ollama está disponible)

**Tiempo de ejecución:** ~30-60 segundos contra un ASN típico.

**Lo que NO hace:**

- No envía tráfico contra la infraestructura del target.
- No intenta explotación de ningún tipo.
- No accede a sistemas privados.
- No envía datos a terceros — todo queda local.

## Solicitar autorización a un cliente

Si querés usar este script contra el ASN de un cliente o partner, **siempre con autorización escrita**. Plantilla de autorización pendiente de incluir — abrí un issue si la necesitás.

## Reportes de bugs / mejoras

Si encontrás un bug o tenés una mejora, abrí un issue. Si encontrás un problema legal/de seguridad **en este script**, contactá en privado a `ariel[at]ayuda.la`.

---

Este script forma parte de un **proyecto de prueba de concepto** con fines educativos y de divulgación técnica. Ayuda.LA y sus colaboradores no ofrecen soporte técnico dedicado sin un contrato de soporte vigente. **No nos hacemos responsables por ningún mal uso** que se le pueda dar a estas herramientas.

**Autor:** Ariel S. Weher · Ayuda.LA · `ariel[at]ayuda.la`
