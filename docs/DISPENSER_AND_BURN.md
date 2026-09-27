# BIGBOT Dispenser + Vault Armor v2 (burn)

> **Status: NOT deployed on PulseChain mainnet.** Code is tested on **PulseChain Testnet V4 (chainId 943)** only — see [`TESTNET_V4_RESULTS.md`](TESTNET_V4_RESULTS.md).
> Not audited. MIT. No price promise of any kind.

## Goal

BIGBOT is used by Bot Vault Armor as a **signal / usage ticket**: every withdrawal window must be *armed* by paying a small amount of BIGBOT. This design:

1. gives bots a simple, predictable way to **get** BIGBOT (a fixed-price dispenser), and
2. makes BIGBOT **get spent** on use (burns in Vault Armor v2), so it behaves like a utility coupon rather than a trading asset.

On-chain there is no way to tell a bot from a human, and nobody can stop a holder from creating a liquidity pool. The design therefore does not try to block anyone; it makes use cheap and speculation unattractive.

---

## 1. BigBotDispenser — fixed-price sale, no buyback

Source: [`contracts/dispenser/BigBotDispenser.sol`](../contracts/dispenser/BigBotDispenser.sol) · ABI: [`abis/BigBotDispenser.json`](../abis/BigBotDispenser.json)

- Sells BIGBOT for PLS at a **fixed price** (`pricePerRaw`, PLS wei per raw unit; BIGBOT has 6 decimals).
- **Never buys back** — no price floor, no "hold and wait for the pump".
- `buy(bigbotRaw)` requires `msg.value == quote(bigbotRaw)` exactly. Plain PLS transfers revert.
- **Per-address lifetime cap** (`maxPerAddress`, immutable) and optional **global daily cap** (`maxPerDayGlobal`).
- No mint: it only distributes BIGBOT the owner has deposited into it.
- **No proxy**, no upgrade.
- Owner can: pause/unpause, withdraw collected PLS, withdraw unsold BIGBOT, change the daily cap, transfer ownership, and change price. With `priceOnlyIncrease = true` (immutable), the price can **only go up**.
- `nonReentrant` guard; state updated before the token transfer (checks-effects-interactions).

### Ceiling effect

If the dispenser sells at 1,000 PLS per BIGBOT and someone opens a BIGBOT/PLS pool, no rational buyer pays more than 1,000 PLS in the pool while the dispenser has stock. The dispenser price acts as a **ceiling**; since it never buys back, there is no artificial floor either.

### Known limits

- **Sybil:** many addresses can each buy up to the cap. Mitigated (not eliminated) by the per-address cap, daily cap, a non-trivial price, and burns on use.
- **Front-running:** with a fixed price there is nothing to snipe except remaining daily cap/stock; the daily cap and pause help.
- **Owner power:** the owner can withdraw PLS and unsold stock — that is real power; choose the owner key carefully.

---

## 2. Vault Armor v2 — burn on use

Sources: [`contracts/vault/v2/BotVault_v2.sol`](../contracts/vault/v2/BotVault_v2.sol), [`contracts/vault/v2/BotVaultFactory_v2.sol`](../contracts/vault/v2/BotVaultFactory_v2.sol) · ABIs: [`abis/BotVault_v2.json`](../abis/BotVault_v2.json), [`abis/BotVaultFactory_v2.json`](../abis/BotVaultFactory_v2.json)

v1 (unchanged, in `contracts/vault/`) transfers the signal amount to a `signalSink`. v2 changes:

| | v1 | v2 |
|--|--|--|
| `arm()` | `transferFrom(keyMaster → signalSink, signalAmount)` | `transferFrom(keyMaster → 0x…dEaD, signalAmount)` + `Burned` event |
| `createVault()` | free | optional `transferFrom(caller → 0x…dEaD, createBurnAmount)` + `CreateBurned` event |
| `signalSink` | receives payments | kept only for ABI parity (set to `0x…dEaD`), unused for payments |

Everything else is the same as v1: immutable `operator ≠ keyMaster`, per-arm cap in bps of TVL, daily arm limit, `minArmDelay`, `armTTL`, withdraw only to `allowedExit`, decoy functions (`emergencyWithdraw` / `ownerWithdraw` / `migrate`) → `trapAddress`, `tripwire()` freeze, no proxy.

BIGBOT has no `burn()` function, so sending to `0x000000000000000000000000000000000000dEaD` is the burn: irreversible, but `totalSupply()` does not decrease.

**Hard limit (same as v1):** an attacker controlling **both** `operator` and `keyMaster` (with the allowlisted exit) can still drain after delay/caps.

Compile note: Factory v2 needs `viaIR` (stack-too-deep otherwise). Tested with solc `0.8.20`, optimizer 200 runs, `viaIR: true`.

---

## 3. Proposed parameters — "Scenario B"

| Parameter | Value |
|-----------|-------|
| Dispenser price | **1,000 PLS per BIGBOT** (`pricePerRaw = 1e15` wei) |
| Per-address cap | **369 BIGBOT** |
| Global daily cap | **20,000 BIGBOT** |
| Dispenser stock | **2,000,000 BIGBOT** |
| Price policy | `priceOnlyIncrease = true` |
| Burn per `arm` | **1 BIGBOT** |
| Burn per `createVault` | **50 BIGBOT** |

These are the parameters exercised on Testnet V4. They are a proposal, not a mainnet deployment. BIGBOT total supply is fixed at 8,315,002,026; a 2M dispenser stock is ~0.024 % of supply.

---

## 4. Status

| Component | Testnet V4 (943) | Mainnet (369) |
|-----------|------------------|---------------|
| BigBotDispenser | Tested (17/17 suite) | **Not deployed** |
| BotVault v2 / BotVaultFactory v2 | Tested (17/17 suite) | **Not deployed** |
| BotVault v1 / Factory v1 | Deployed (reference) | Not deployed |

Testnet addresses: [`deployments/addresses.json`](../deployments/addresses.json) → `vaultArmorV2Testnet`.

---

## Español (resumen)

- **Dispensador:** vende BIGBOT a precio fijo por PLS, **nunca recompra**, tope por dirección y tope diario global, precio solo puede subir, sin proxy. Su precio actúa como **techo** frente a cualquier pool.
- **Vault Armor v2:** cada `arm` **quema** 1 BIGBOT (envío a `0x…dEaD`) y crear un vault quema 50 BIGBOT. Resto igual que v1.
- **Escenario B:** 1.000 PLS/BIGBOT, tope 369 por dirección, 20.000/día, stock 2.000.000.
- **Estado:** probado solo en **testnet V4** (17/17). **NO desplegado en mainnet.** Sin auditoría.
