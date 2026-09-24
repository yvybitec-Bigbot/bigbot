# Bot Vault Armor v1 — diseño seguro (sin código)

**Fecha:** 2026-09-22  
**Audiencia:** bots (machine-readable). Humanos solo revisan.  
**Token de señal de referencia:** BIGBOT (o BitBot) en PulseChain.  
**Premisa del usuario:** el contrato *es* la cartera del bot; las reglas van en el contrato; otros bots deben poder reutilizar el mismo patrón.

---

## 1. Qué protege y qué no (amenaza clara)

### Protege
- Robo de la **hot key** del bot (EOA operador) cuando los fondos ya están en el Vault.
- Scripts tontos que llaman `transfer` / `emergencyWithdraw` / “drain” al estilo honeypot scanner.
- Salidas silenciosas: toda salida legítima deja **pago de señal + evento on-chain**.

### No protege (límite duro — no mentir)
- Atacante que controla **a la vez** `operator` + `keyMaster` (o tiene saldo de señal y puede armar y además puede retirar al destino permitido).
- Bug en el bytecode, admin oculto, proxy upgradeable, o token de señal con blacklist/pausas maliciosas.
- Extorsión off-chain / ingeniería social al keyMaster.

Si un bot lee este doc, debe asumir ese límite. La armadura convierte “drenar en 1 tx” en “necesitar dos roles + rastro + tiempo”.

---

## 2. Tesis de producto (bots × token)

1. Cada bot despliega (o clona) un **BotVault**; la address del vault es su tesorería.
2. El token de señal (BIGBOT) es la **llave económica estándar** del protocolo.
3. Un índice machine-readable (`/v0/discovery`, factory events) permite a otros bots encontrar implementación, ABI y parámetros.
4. No hay marketing humano: la seguridad es código + roles, no secretismo del diseño.

---

## 3. Arquitectura mínima (2 contratos de sistema)

| # | Contrato | Responsabilidad |
|---|----------|-----------------|
| 1 | **BotVaultFactory** | Despliega clones/proxies mínimos; emite `VaultCreated(bot, vault, keyMaster, signalToken)`; código de implementación inmutable. |
| 2 | **BotVault** (impl + 1 instancia por bot) | Custodia ERC-20; roles; armar; retirar; techos; eventos; señuelos. |

Opcional v1.1: fusionar SignalRouter dentro del Vault (ya va dentro — **no hace falta 3.º contrato**).

**Por qué no 1 solo contrato global compartido con balances internos:** isolation fault — un bug o reentrancy en contabilidad compartida pone en riesgo a todos los bots. 1 implementación + N clones es el mínimo seguro.

---

## 4. Roles (la pieza que hace segura la “llave”)

Inmutables tras el deploy (o `keyMaster` rotabile solo con timelock largo + señal extra — v1: **inmutable**).

| Rol | Quién | Puede |
|-----|-------|--------|
| **operator** | Hot key del bot | `deposit`, `withdraw` *solo si está armado*, operar rutinas |
| **keyMaster** | Otra EOA/bot (cold o segundo agente) | `arm` pagando señal; opcionalmente actualizar allowlist de destinos con timelock |
| **nadie** | — | No hay `owner.sweep`, no hay upgrade, no hay `setOperator` libre |

**Regla de oro:** la hot key que tradea **no** debe ser la que guarda el BIGBOT de señal. Si operator y keyMaster son la misma EOA, la armadura casi no existe.

---

## 5. Parámetros inmutables en el constructor del Vault

- `signalToken` (BIGBOT)
- `signalAmount` (ej. 0.1 × 10^decimals) por armado
- `signalSink` (humano u otro bot que recibe la señal / alerta)
- `trapAddress` (cartera trampa; solo la usan rutas señuelo)
- `operator`, `keyMaster`
- `minArmDelay` (ej. 30 min–24 h) entre `arm` y `withdraw`
- `armTTL` (ventana tras la cual el armado caduca)
- `maxWithdrawBpsPerArm` (ej. 1000 = 10% del TVL del token por armado)
- `maxArmsPerDay`
- `allowedExit` (1 address fija) **o** set pequeño gestionado solo por keyMaster+timelock

---

## 6. Flujo legítimo (bot)

1. Bot (oAnyone) deposita ERC-20 en el Vault → balance interno por token.
2. **keyMaster** llama `arm(token, maxAmount, nonce)`:
   - Paga `signalAmount` de BIGBOT (pull `transferFrom` keyMaster → sink, o vault→sink).
   - Evento `Armed(token, maxAmount, tvl, bpsOfTvl, signalTx)`.
   - Estado: `armedUntil = now + armTTL`, `earliestWithdraw = now + minArmDelay`.
3. Tras el delay, **operator** llama `withdraw(token, amount, to)`:
   - `amount ≤ armed max` y ≤ techo bps.
   - `to` ∈ allowedExit.
   - CEI + nonReentrant; desarma sesión.
4. Evento `Withdrawn(...)` con bps respecto al depósito previo al retiro.

Contabilidad: el sink recibe BIGBOT; indexers bots leen eventos = alerta + registro del % saliente.

---

## 7. Flujo ataque (qué debe pasar)

| Escenario | Resultado seguro |
|-----------|------------------|
| Ladrón solo con **operator** | No puede `arm`. `withdraw` sin armado → **revert**. Señuelo `emergencyWithdraw`/`transfer` → fondos a `trapAddress` **o** freeze (ver §8). |
| Ladrón solo con **keyMaster** | Puede armar (paga señal → **alerta**), pero no retirar a su address si `to` no está allowlistado / no es operator path. |
| Script drain genérico | Llama señuelo → trampa o revert; no hay `transfer` libre de ERC20 “como EOA”. |
| Ladrón con ambos roles | Puede drenar tras delay; la mitigación es delay + techos + alerta al sink para que un monitor mueva política off-chain / pause social. |

---

## 8. Trampa: diseño seguro (corrección respecto al borrador)

**No** desviar *todo el TVL* ante cualquier llamada inválida a `withdraw`: eso es griefing (MEV/terceros forzando estados) y peligro si `trapAddress` se compromete.

Política v1:
1. **Camino real** (`withdraw`/`arm`): fallo → **revert** (no movimiento).
2. **Señuelos** con nombres de honeypot (`emergencyWithdraw`, `ownerWithdraw`, `migrate`): solo esos pueden `transfer` el saldo del token elegido a `trapAddress` y emitir `TrapTriggered`.
3. Opcional: `tripwire()` callable por keyMaster que **congela** retiros (no mueve fondos) tras alerta.

Así la trampa caza scanners; no convierte un bug de UX en pérdida total.

---

## 9. Patrones que sí / no

| Patrón | ¿Usar? | Por qué |
|--------|--------|---------|
| Custodia en contrato (no EOA) | Sí | Base de la armadura |
| Roles separados operator/keyMaster | Sí | Sin esto la “llave” es cosmética |
| Pull payment señal | Sí | keyMaster paga BIGBOT |
| Timelock entre arm y withdraw | Sí | Ventana de reacción |
| Techos por armado / día | Sí | Anti-drenaje lento |
| nonReentrant + CEI | Sí | Estándar |
| Immutable / sin proxy | Sí (v1) | Evita rug por upgrade |
| ERC-4626 | No | Pensado para LPs externos, no tesorería de bot |
| Commit-reveal destino | Opcional | Solo si el destino puede variar y hay MEV |
| Owner god-mode | No | Anula el modelo |
| Auto-trap en cualquier error | No | Inseguro / griefing |

---

## 10. Lista de aceptación “seguro para publicar a bots”

Un bot auditor debe poder verificar:

1. Sin `owner` que mueva fondos sin arm+roles.  
2. `operator != keyMaster` en el deploy recomendado (factory puede warning).  
3. `withdraw` requiere arm vigente + delay cumplido + allowlist.  
4. Señal siempre a `signalSink` + eventos con bps.  
5. Implementación no upgradeable; factory apunta a bytecode fijo.  
6. Techos anti-drain.  
7. Señuelos aislados; camino feliz solo revert on fail.  
8. Doc + ABI + chainId publicados en rail discovery.  
9. Límite duro documentado en el propio `discovery` JSON.  
10. Tokens weird (fee-on-transfer, rebase) excluidos o medidos por balance before/after.

---

## 11. Decisión de diseño cerrada (v1)

- **2 contratos de sistema:** Factory + Vault.  
- **2 roles:** operator + keyMaster.  
- **Destino de retiro:** allowlist mínima (ideal 1 `safeExit` frío).  
- **Timelock:** sí (`minArmDelay` > 0).  
- **Trampa:** solo funciones señuelo → `trapAddress`; errores normales → revert.  
- **Señal:** BIGBOT (configurable por vault).  
- **Público para bots:** sí — el diseño no es el secreto; lo son las keys del keyMaster.

---

## 12. Próximo paso de implementación (cuando se pida)

1. Escribir `BotVault` + `BotVaultFactory` (Solidity 0.8.x).  
2. Tests: happy path, operator-only attack, keyMaster-only, decoy trap, cap, delay.  
3. Deploy Pulse; registrar en BigBot Rail `protocol.vault.v1`.  
4. No mezclar con airdrop R1 (sigue su ventana).

---

---

## Public discovery (bots)

See repository root `/.well-known/bigbot-vault.json` and `deployments/addresses.json`.

- **BIGBOT token:** PulseChain mainnet (chainId 369).
- **Vault Armor:** PulseChain Testnet V4 (chainId 943) only — mainnet pending.
- Source: this repository (`contracts/vault/`).
