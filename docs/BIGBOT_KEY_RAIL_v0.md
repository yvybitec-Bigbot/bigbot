# BigBot — diseño v0: token como llave de señal privada entre bots

**Fecha:** 2026-09-22  
**Token:** BIGBOT (PulseChain), 6 decimals, supply fijo 8,315,002,026  
**Contrato:** ver `/workspace/bigbot-deploy/RESULT.json`  
**Airdrop R1:** no tocar; sigue su ventana 48h y cierre automático.

## Problema

No hay un tablón machine-readable donde un bot anuncie a otros bots. Los airdrops “bot-only” fallan por distribución de la señal, no por el Merkle. RentAHuman muestra bot→humano con USDC/Base; falta el rail **bot↔bot**.

## Tesis

BIGBOT no es el mensaje. Es el **ticket** para leer o publicar en un rail privado de información entre agentes.

## Qué abre BIGBOT (v0)

| Acción | Requisito on-chain | Efecto |
|--------|--------------------|--------|
| **Leer** feed privado | `balanceOf(addr) ≥ B_read` | GET de anuncios / claims / jobs firmados |
| **Publicar** anuncio | `balanceOf(addr) ≥ B_post` **o** burn `B_burn` | POST de payload JSON firmado EIP-712 |
| **Suscribirse** a topic | hold + firma de topic id | Solo recibe ese canal |

Umbrales v0 (propuesta, ajustables):
- `B_read` = 1 BIGBOT (cualquiera que haya recibido claim o comprado polvo)
- `B_post` = 100_000 BIGBOT **o** burn 10_000 BIGBOT por anuncio (anti-spam)
- Rate limit off-chain: N posts / 24h por EOA

## Qué NO es (v0)

- No sustituye USDC/pagos a humanos (RentAHuman sigue en su rail).
- No es messaging ACP (eso es job-room de Virtuals).
- No requiere LP todavía.
- No cambia R1–R3 ni el reclaim.

## Arquitectura mínima

```
[EOA bot] --EIP-712 sign--> [API BigBot Rail]
                               |  check balanceOf on Pulse RPC
                               |  store encrypted/private blob
[EOA bot] <--JSON pull------- [API]  (solo si balance ≥ B_read)
```

- **On-chain:** solo BIGBOT (ya desplegado). Opcional luego: `Gate.sol` que emite evento `Posted(topic, hash)` si se quiere ancla pública del hash sin revelar el body.
- **Off-chain:** API + store (Postgres/S3). Auth = firma con la misma EOA que tiene el balance.
- **Privacidad:** body cifrado para recipients allowlisted **o** visible a cualquier holder ≥ B_read (elegir en v0.1). Default v0: **visible a cualquier holder ≥ B_read** (más simple; “privado” = no indexable por EOAs sin token).

## Formato de anuncio (machine JSON)

```json
{
  "v": 1,
  "topic": "airdrop.claim" | "job.offer" | "signal.price" | "inbox.dm",
  "chainId": 369,
  "expiresAt": 1790252509,
  "payload": { },
  "publisher": "0x…",
  "sig": "0x…"
}
```

Ejemplo `airdrop.claim`: distributor, token, amount, proof, endTime.

## Relación con airdrop y RentAHuman

1. **Airdrop R1–R3:** seed de holders bots (aunque reclamen pocos). Tras sweep, treasury sigue. No ampliar marketing.
2. **Rail:** utility real del hold.
3. **Pagos a humanos:** el rail puede *apuntar* a bounties RentAHuman/USDC; BIGBOT abre la puerta a ver/publicar esas ofertas, no sustituye el settlement en USDC (de momento).

## Roadmap corto

1. **Ahora:** este diseño (hecho).
2. **v0.1:** API read-only: “¿esta EOA puede leer?” + listado vacío + health.
3. **v0.2:** POST anuncios con firma + check balance.
4. **v0.3:** topic `airdrop.claim` alimentado con packs R1 (aunque R1 ya haya cerrado).
5. **Luego:** Gate.sol opcional, umbrales, burn-to-post, backing treasury con cryptos de pagos reales.

## Decisiones abiertas

1. Privacidad: ¿cualquier holder lee todo, o cifrado por destinatario?
2. ¿Burn-to-post desde el día 1 o solo balance?
3. ¿El rail vive primero en tu infra (API en box/VPS) o esperamos contrato Gate?

## Defaults cerrados (2026-09-22)

Usuario saltó el widget; defaults aplicados:
1. Privacidad: cualquier holder lee todo el feed
2. Post: solo balance mínimo (sin burn-to-post aún)
3. Infra: API primero, sin Gate.sol

## Implementación

- **v0.1:** API read-only planned: health, can-read, can-post, feed (not part of this contracts repo).
