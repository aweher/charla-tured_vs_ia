# Ollama — LLM local on-prem

[Ollama](https://ollama.com/) es el runtime más simple para correr modelos LLM locales. Una línea de comando descarga y arranca Llama, Qwen, Mistral, Phi, Gemma, etc. Soberanía total del dato — nada sale de tu infra.

## Arrancar

```bash
docker compose --profile llm up -d
```

Esto levanta Ollama (API en :11434) + Open WebUI (interfaz tipo ChatGPT en :3000).

## Descargar modelos

```bash
# Modelo recomendado para empezar (8B parámetros, ~5GB)
docker exec ollama ollama pull llama3.1:8b

# Más rápido y liviano
docker exec ollama ollama pull qwen2.5:7b
docker exec ollama ollama pull mistral:7b

# Específico para código
docker exec ollama ollama pull qwen2.5-coder:7b

# Ver lo que está descargado
docker exec ollama ollama list
```

## Hardware mínimo

| Modelo | RAM mínima | RAM cómoda | Sin GPU (CPU) | Con RTX 3060 12GB | Con Apple Silicon M2 Pro |
|---|---|---|---|---|---|
| llama3.1:8b | 8 GB | 16 GB | ~3 tokens/s (lento pero usable) | ~50 tokens/s | ~28 tokens/s |
| qwen2.5:7b | 8 GB | 16 GB | similar | similar | similar |
| llama3.1:70b | 64 GB | 128 GB | inviable | requiere 2× RTX 3090 | requiere M2 Ultra 128 GB+ |

**Para una charla en vivo o análisis de logs en NOC: 8B alcanza.** Para análisis profundos de código o generación creativa, querés 70B.

## Habilitar GPU NVIDIA (Linux)

Editá el `docker-compose.yml`, descomentando el bloque `deploy:` del servicio `ollama`. Necesitás:

```bash
# En el host
sudo apt install nvidia-container-toolkit
sudo systemctl restart docker
```

Después:

```bash
docker compose down ollama
docker compose --profile llm up -d ollama
docker exec ollama ollama list
```

## Apple Silicon (M1 / M2 / M3 / M4)

Los chips Apple Silicon aceleran inferencia LLM vía **Metal** (el framework GPU de Apple). La arquitectura de **memoria unificada** (UMA) es la ventaja clave: CPU y GPU comparten el mismo pool de RAM, así que no tenés el cuello de botella de VRAM dedicada que existe en PCs con GPU discreta. Un M2 Pro con 32 GB le gana a una RTX 3060 con 12 GB de VRAM en modelos que no entran en esos 12 GB.

### Rendimiento estimado (Llama 3.1 8B Q4)

| Chip | RAM unificada | GPU cores | ~tokens/s |
|---|---|---|---|
| M1 | 8–16 GB | 7–8 | 12–15 |
| M1 Pro | 16–32 GB | 14–16 | 22–28 |
| M2 | 8–24 GB | 8–10 | 18–24 |
| M2 Pro | 16–32 GB | 16–19 | 26–32 |
| M2 Max | 32–96 GB | 30–38 | 35–42 |
| M2 Ultra | 64–192 GB | 60–76 | 50–60 |
| M3 | 8–24 GB | 8–10 | 20–26 |
| M3 Pro | 18–36 GB | 14–18 | 28–35 |
| M3 Max | 36–128 GB | 30–40 | 40–50 |
| M4 | 16–32 GB | 10 | 22–28 |
| M4 Pro | 24–48 GB | 20 | 30–38 |
| M4 Max | 36–128 GB | 40 | 45–55 |

> **Regla práctica:** priorizá RAM sobre velocidad de chip. Un Mac Mini M2 Pro con 32 GB corre modelos más grandes que un MacBook Pro M3 con 16 GB.

### Opción A — Ollama nativo (recomendado)

Docker Desktop para Mac **no expone Metal a los contenedores**. Para aprovechar la GPU, corré Ollama directo en macOS y dejá solo Open WebUI en Docker:

```bash
# Instalar Ollama nativo
brew install ollama

# Arrancar el servicio (Metal se activa automáticamente)
ollama serve &

# Descargar un modelo
ollama pull llama3.1:8b

# Verificar que Metal está activo
ollama ps
# Debe mostrar "metal" en la columna de procesador
```

Después levantá Open WebUI apuntando al Ollama del host:

```bash
# En docker-compose.yml, cambiar OLLAMA_BASE_URL:
#   OLLAMA_BASE_URL: http://host.docker.internal:11434
docker compose --profile llm up -d open-webui
```

### Opción B — Todo en Docker (sin aceleración GPU)

Si preferís mantener todo containerizado (por simplicidad o por consistencia con el resto del stack), el `docker compose --profile llm up -d` normal funciona, pero Ollama corre solo en CPU dentro del contenedor. Para modelos 8B es usable (~3–5 tokens/s), pero notablemente más lento.

### Qué modelo elegir según tu Mac

| RAM disponible | Modelo recomendado | Cuantización |
|---|---|---|
| 8 GB | qwen2.5:3b, phi3:mini | Q4_K_S |
| 16 GB | llama3.1:8b, qwen2.5:7b | Q4_K_M |
| 32 GB | llama3.1:8b, mixtral:8x7b | Q5_K_M |
| 64 GB+ | llama3.1:70b | Q4_K_M |
| 128 GB+ | llama3.1:70b | Q6_K (mejor calidad) |

### Troubleshooting

```bash
# Verificar que Metal funciona
system_profiler SPDisplaysDataType | grep Metal

# Ver uso de GPU en tiempo real
sudo powermetrics --samplers gpu_power -i1000 -n1

# Si algo falla con Metal, forzar CPU (debug)
OLLAMA_METAL=0 ollama serve

# Limpiar cache de shaders Metal
rm -rf ~/Library/Caches/com.apple.metal
```

> **Nota M5:** al momento de escribir esto, los chips M5 con macOS 26 (Tahoe) tienen un [bug conocido](https://github.com/ollama/ollama/issues/14432) con los shaders Metal de Ollama. Alternativa: usar [MLX](https://github.com/ml-explore/mlx) de Apple hasta que se resuelva.

## Casos de uso para NOC

### 1. Resumir logs de syslog

```bash
cat /var/log/syslog | docker exec -i ollama ollama run llama3.1 \
  "Resumime en 5 bullets los eventos críticos de las últimas 24h. \
   Marcá los high-priority. No inventes datos que no estén en el log."
```

### 2. Analizar configuración antes de commit

```bash
cat router-config.txt | docker exec -i ollama ollama run llama3.1 \
  "Analizá esta configuración Cisco IOS y marcá los riesgos de seguridad. \
   Sé conservador — si no estás seguro, decilo."
```

### 3. Triage de alerts de SIEM

Vía Open WebUI o directamente:

```bash
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.1",
  "prompt": "Tengo 15 alertas de Wazuh sobre intentos SSH desde la misma IP en 5 min. ¿Es brute force, scan, o ruido legítimo? Pregunta lo que necesites para decidir.",
  "stream": false
}'
```

## Open WebUI

Interfaz web tipo ChatGPT, multi-usuario, persistente.

URL: <http://localhost:3000>

Primer acceso: registrate (el primer usuario queda como admin). Ningún dato se envía a APIs externas.

## Lo que NO hace bien (todavía)

- **Hechos puntuales / preguntas factuales recientes.** Los modelos tienen knowledge cutoff. Si necesitás info actualizada, sumá RAG (Open WebUI lo soporta nativo).
- **Decisiones críticas sin supervisión.** Repetilo siempre: la IA asiste, el humano decide.
- **Código de producción sin revisión.** Genera bugs sutiles. Útil para borradores, no para final.

## Privacidad

Los modelos open source (Llama, Qwen, Mistral, Gemma) corren 100% local. Open WebUI guarda historial localmente en `./open-webui/data/`. **Cero telemetría a terceros**, salvo si vos lo activás explícitamente.

## Referencias

- Ollama docs: <https://github.com/ollama/ollama/tree/main/docs>
- Open WebUI: <https://docs.openwebui.com>
- Modelos disponibles: <https://ollama.com/library>
