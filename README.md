# BIGBOT + Bot Vault Armor

Open-source **BIGBOT** ERC-20 (PulseChain) and **Bot Vault Armor** — wallet security for AI/agent bots.

**License:** MIT · **Org:** [yvybitec-Bigbot](https://github.com/yvybitec-Bigbot)

---

## What is BIGBOT?

BIGBOT is a fixed-supply ERC-20 on **PulseChain mainnet** (chainId `369`):

| | |
|--|--|
| Address | [`0xeb6F7B997c0020f5C0334815d9BEAAB661bCfEf6`](https://scan.pulsechain.com/address/0xeb6F7B997c0020f5C0334815d9BEAAB661bCfEf6) |
| Symbol / decimals | BIGBOT / 6 |
| Total supply | 8,315,002,026 (minted once; no further mint) |
| Compiler | Solidity `0.8.20`, optimizer **200** runs |

**Properties:** no owner powers, no tax, no pause, no blacklist, no upgrade proxy. Full supply minted to the constructor recipient at deploy.

Source: [`contracts/token/BigBot.sol`](contracts/token/BigBot.sol)

---

## What is Bot Vault Armor?

Bot Vault Armor v1 is a **non-upgradeable** custody pattern for bot treasuries:

- **`operator` ≠ `keyMaster`** (immutable roles)
- Withdrawals require **keyMaster** to `arm` (pays a signal token amount to a sink) before **operator** can `withdraw`
- Per-arm **caps** (bps of TVL), daily arm limits, optional **delay** (`minArmDelay`)
- **Decoy trap:** `emergencyWithdraw` / `ownerWithdraw` / `migrate` send funds to `trapAddress` (honeypot-scanner bait)
- Happy-path failures **revert** (no auto-drain)
- `tripwire()` lets keyMaster freeze arms/withdraws without moving funds

Contracts: [`contracts/vault/`](contracts/vault/) · Design: [`docs/BOT_VAULT_ARMOR_v1.md`](docs/BOT_VAULT_ARMOR_v1.md)

### Status

| Component | Network | Status |
|-----------|---------|--------|
| BIGBOT token | PulseChain **mainnet** (369) | **Live** |
| Vault Armor v1 (Factory + Vault) | PulseChain **Testnet V4** (943) | **Testnet only** — mainnet pending |
| Vault Armor v2 (burn) + BigBotDispenser | PulseChain **Testnet V4** (943) | **Testnet only** (17/17 tests) — **not on mainnet** |

### Testnet V4 addresses (Vault Armor)

| Contract | Address |
|----------|---------|
| BotVaultFactory | [`0xa39f82C2C3efDa612f77238A12aA2a694aFD09c9`](https://scan.v4.testnet.pulsechain.com/address/0xa39f82C2C3efDa612f77238A12aA2a694aFD09c9) |
| BotVault (example) | [`0x3A92c476FC72a83876da2FE9fa2acba2FCc2D297`](https://scan.v4.testnet.pulsechain.com/address/0x3A92c476FC72a83876da2FE9fa2acba2FCc2D297) |

---

## BIGBOT Dispenser + Vault Armor v2 (testnet only)

- **BigBotDispenser** — sells BIGBOT for PLS at a **fixed price**, **never buys back**, per-address cap + daily cap, price can only go up, no proxy. The fixed price acts as a ceiling for any secondary pool.
- **Vault Armor v2** — same model as v1, but each `arm` **burns** the signal amount to `0x…dEaD` and the v2 factory can burn a fee on `createVault`.
- Proposed params (Scenario B): **1,000 PLS / BIGBOT**, cap **369** per address, **20,000**/day, stock **2,000,000**; burn **1** per arm, **50** per vault creation.
- **Status: tested on PulseChain Testnet V4 only (17/17 PASS). NOT deployed on mainnet.**

| Contract (Testnet V4) | Address |
|----------|---------|
| BigBotDispenser (Scenario B) | [`0x813b35Ae3a79B798916be0b76DD3c7b5AAAEDB26`](https://scan.v4.testnet.pulsechain.com/address/0x813b35Ae3a79B798916be0b76DD3c7b5AAAEDB26) |
| BotVaultFactory v2 | [`0x60e7C9BfF5FD5315ea8f82aEE4b9Df1B3BD1B44a`](https://scan.v4.testnet.pulsechain.com/address/0x60e7C9BfF5FD5315ea8f82aEE4b9Df1B3BD1B44a) |
| BotVault v2 (example) | [`0x6b136bC4f46dD6FcaB4728633fbc88CfCBbd7D0a`](https://scan.v4.testnet.pulsechain.com/address/0x6b136bC4f46dD6FcaB4728633fbc88CfCBbd7D0a) |

Code: [`contracts/dispenser/`](contracts/dispenser/) · [`contracts/vault/v2/`](contracts/vault/v2/) · Docs: [`docs/DISPENSER_AND_BURN.md`](docs/DISPENSER_AND_BURN.md) · [`docs/TESTNET_V4_RESULTS.md`](docs/TESTNET_V4_RESULTS.md)

Machine-readable descriptor: [`.well-known/bigbot-vault.json`](.well-known/bigbot-vault.json) · All addresses: [`deployments/addresses.json`](deployments/addresses.json)

---

## Repo layout

```
contracts/token/BigBot.sol
contracts/vault/{BotVault,BotVaultFactory,MockERC20}.sol   # v1
contracts/vault/v2/{BotVault_v2,BotVaultFactory_v2}.sol   # v2 (burn) — testnet only
contracts/dispenser/BigBotDispenser.sol                   # testnet only
contracts/airdrop/MerkleDistributor.sol
abis/
docs/BOT_VAULT_ARMOR_v1.md
docs/BIGBOT_KEY_RAIL_v0.md
docs/DISPENSER_AND_BURN.md
docs/TESTNET_V4_RESULTS.md
.well-known/bigbot-vault.json
deployments/addresses.json
AGENTS.md · llms.txt
```

---

## Compile

```bash
solc --version   # expect 0.8.20
solc --optimize --optimize-runs 200 --bin --abi \
  -o out --overwrite \
  contracts/token/BigBot.sol \
  contracts/vault/*.sol \
  contracts/airdrop/MerkleDistributor.sol
```

Dispenser + v2 (Factory v2 needs `viaIR`):

```bash
solc --optimize --optimize-runs 200 --via-ir --bin --abi \
  -o out-v2 --overwrite \
  contracts/dispenser/BigBotDispenser.sol \
  contracts/vault/v2/*.sol
```

Constructor for BIGBOT (as deployed):

```text
("BigBot", "BIGBOT", 6, 8315002026000000, <recipient>)
```

---

## Fork / reuse freely

MIT. Copy, fork, redeploy. Separate `operator` and `keyMaster` keys in production. Read the hard limit in the design doc before relying on this for large treasuries.

Also included: [`MerkleDistributor.sol`](contracts/airdrop/MerkleDistributor.sol) (generic claim + post-deadline sweep) — **no recipient lists** ship in this repo.

---

## Security notes & disclaimer

- Vault Armor does **not** protect an attacker who controls **both** `operator` and `keyMaster` (and can arm toward an allowlisted exit).
- Not audited. Use at your own risk. No warranty (see `LICENSE`).
- Do not commit private keys, mnemonics, `.env`, keystores, or airdrop allowlists.
- Testnet Vault Armor addresses are for experimentation only.

---

## Español (resumen)

**BIGBOT** es un ERC-20 de supply fijo en PulseChain (mainnet): sin owner, sin tax, sin mint posterior.  
**Bot Vault Armor** es la “cartera-contrato” del bot: `operator` ≠ `keyMaster`; hay que **armar** (pagando señal) antes de retirar; hay techos, delay opcional y señuelos hacia `trapAddress`; **sin upgrade**.  
Token = mainnet; Vault Armor = **solo testnet V4** por ahora (mainnet pendiente).  
**Dispensador + Vault Armor v2:** el dispensador vende BIGBOT a precio fijo por PLS (sin recompra, tope por dirección y diario, el precio solo puede subir); v2 **quema** 1 BIGBOT por cada `arm` y 50 al crear un vault. Parámetros propuestos: 1.000 PLS/BIGBOT, 369 por dirección, 20.000/día, stock 2.000.000. **Solo probado en testnet V4 (17/17); NO desplegado en mainnet.** Ver [`docs/DISPENSER_AND_BURN.md`](docs/DISPENSER_AND_BURN.md). Código MIT — usad / forkead libremente. Sin auditoría; leed los límites del diseño.

---

## Links

- Token explorer: https://scan.pulsechain.com/address/0xeb6F7B997c0020f5C0334815d9BEAAB661bCfEf6
- Testnet explorer: https://scan.v4.testnet.pulsechain.com
- Bot summary: [`AGENTS.md`](AGENTS.md) · [`llms.txt`](llms.txt)
