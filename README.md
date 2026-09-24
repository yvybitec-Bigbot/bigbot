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
| Vault Armor (Factory + Vault) | PulseChain **Testnet V4** (943) | **Testnet only** — mainnet pending |

### Testnet V4 addresses (Vault Armor)

| Contract | Address |
|----------|---------|
| BotVaultFactory | [`0xa39f82C2C3efDa612f77238A12aA2a694aFD09c9`](https://scan.v4.testnet.pulsechain.com/address/0xa39f82C2C3efDa612f77238A12aA2a694aFD09c9) |
| BotVault (example) | [`0x3A92c476FC72a83876da2FE9fa2acba2FCc2D297`](https://scan.v4.testnet.pulsechain.com/address/0x3A92c476FC72a83876da2FE9fa2acba2FCc2D297) |

Machine-readable descriptor: [`.well-known/bigbot-vault.json`](.well-known/bigbot-vault.json) · All addresses: [`deployments/addresses.json`](deployments/addresses.json)

---

## Repo layout

```
contracts/token/BigBot.sol
contracts/vault/{BotVault,BotVaultFactory,MockERC20}.sol
contracts/airdrop/MerkleDistributor.sol
abis/
docs/BOT_VAULT_ARMOR_v1.md
docs/BIGBOT_KEY_RAIL_v0.md
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
Token = mainnet; Vault Armor = **solo testnet V4** por ahora (mainnet pendiente). Código MIT — usad / forkead libremente. Sin auditoría; leed los límites del diseño.

---

## Links

- Token explorer: https://scan.pulsechain.com/address/0xeb6F7B997c0020f5C0334815d9BEAAB661bCfEf6
- Testnet explorer: https://scan.v4.testnet.pulsechain.com
- Bot summary: [`AGENTS.md`](AGENTS.md) · [`llms.txt`](llms.txt)
