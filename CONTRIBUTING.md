# Cómo contribuir

Gracias por interesarte en mejorar este toolkit. La idea es que sea **un proyecto vivo de la comunidad técnica regional**, no un repo estático que nadie toca.

> **Nota:** este proyecto es una **prueba de concepto** con fines educativos que aspira a crecer como proyecto comunitario. Las contribuciones son bienvenidas, pero Ayuda.LA no ofrece soporte técnico dedicado sobre este material sin un contrato de soporte vigente.

## Antes de abrir un PR

1. **Abrí un issue primero** describiendo el cambio que querés hacer. Para correcciones menores (typos, links rotos), podés ir directo al PR.
2. **Probá lo que mandás.** Si agregás un servicio al stack, levantalo, verificá que arranca, documentá los puertos y dependencias.
3. **No incluyas datos sensibles.** Configs anonimizadas. ASNs y prefijos de ejemplo deben ser de los rangos reservados (RFC 5398, 5737, 3849, 6996).

## Tipos de contribución bienvenidas

### Configuraciones probadas en producción

Si tenés una configuración de Suricata, Wazuh, MISP, fastnetmon, etc. que está funcionando en tu operación, **anonimizá** y mandala. Las configs reales valen más que las configs idealizadas.

### Casos de uso regionales

Si resolviste un problema operativo con este stack en un contexto LATAM (un tipo de ataque, un mecanismo de mitigación, una integración con un upstream local), documentalo en `docs/CASES/` con un MD por caso.

### Traducciones

Toda la documentación está en español por decisión deliberada (la audiencia es LATAM). Si querés sumar versión en inglés o portugués, abrí issue para coordinar.

### Mejoras de seguridad

Si encontrás un bug de seguridad **en este repo** (no en las herramientas upstream), por favor reportalo en privado a `ariel[at]ayuda.la` antes de abrir un issue público.

## Reglas de estilo

- **Markdown:** un `#` por archivo, jerarquía consistente, líneas de máximo ~100 caracteres.
- **Código:** seguir el estilo de cada herramienta (ej: configs de Suricata en YAML estándar, no improvisar).
- **Disclaimers:** cualquier herramienta que pueda usarse ofensivamente debe llevar disclaimer claro al inicio del archivo.
- **Idioma:** español neutro / rioplatense. Sin lunfardo. "Incidentes" no "problemas".

## Lo que NO se acepta

- Configuraciones de productos pagos / licenciados (este es un repo open source).
- Material que viole términos de servicio de plataformas (ej: scrapers de LinkedIn).
- Herramientas ofensivas sin disclaimer y sin autorización requerida.
- Promoción de proveedores específicos.

## Código de conducta

- Tratá a todes con respeto. Discutimos código, no personas.
- No tolerancia a discriminación, acoso o lenguaje degradante.
- En caso de conflicto, los maintainers tienen la decisión final.

## Maintainers

- **Ariel S. Weher** · `ariel[at]ayuda.la` · GitHub: [@aweher](https://github.com/aweher)

¿Querés sumarte como maintainer? Mandanos PRs útiles, contribuí en issues, y eventualmente proponé sumarte. La merit-based collaboration es la única forma sostenible.
