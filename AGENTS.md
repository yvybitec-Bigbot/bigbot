# AGENTS.md — BIGBOT / Bot Vault Armor

Machine-oriented summary for coding agents and bots.

## Identity

- Repo: `yvybitec-Bigbot/bigbot` (MIT, copyright 2026 yvybitec-Bigbot)
- Purpose: open-source BIGBOT ERC-20 + Bot Vault Armor custody pattern for agent wallets

## On-chain facts

### BIGBOT token — PulseChain MAINNET (chainId 369)

- Address: `0xeb6F7B997c0020f5C0334815d9BEAAB661bCfEf6`
- Deployer: `0x44f4F9F703fCA7A81a108e6485d391476F2c30B9`
- Deploy tx: `0xf5963f88359f6d7b9135c9f9ed1539234b4741913cdc1a6ab4592800bfa7154b`
- Decimals: 6 · Supply: 8315002026 human / `8315002026000000` raw
- Solc: 0.8.20 · optimizer runs: 200
- No owner / tax / pause / blacklist / remint
- Source: `contracts/token/BigBot.sol`
- Explorer: https://scan.pulsechain.com/address/0xeb6F7B997c0020f5C0334815d9BEAAB661bCfEf6

### Bot Vault Armor — PulseChain TESTNET V4 ONLY (chainId 943)

- Factory: `0xa39f82C2C3efDa612f77238A12aA2a694aFD09c9`
- Example Vault: `0x3A92c476FC72a83876da2FE9fa2acba2FCc2D297`
- Mainnet: **not deployed**
- Source: `contracts/vault/{BotVault,BotVaultFactory}.sol`
- Descriptor: `.well-known/bigbot-vault.json`
- Addresses file: `deployments/addresses.json`

### Vault Armor v2 (burn) + BigBotDispenser — PulseChain TESTNET V4 ONLY (chainId 943)

- BigBotDispenser (Scenario B): `0x813b35Ae3a79B798916be0b76DD3c7b5AAAEDB26`
- BotVaultFactory v2: `0x60e7C9BfF5FD5315ea8f82aEE4b9Df1B3BD1B44a`
- Example BotVault v2: `0x6b136bC4f46dD6FcaB4728633fbc88CfCBbd7D0a`
- Testnet signal token `0xeb6F…CfEf6` on chain 943 is a **MockERC20**, not BIGBOT (same address only by deployer-nonce coincidence)
- v2: `arm` burns `signalAmount` to `0x…dEaD`; factory burns `createBurnAmount` on `createVault`
- Mainnet: **not deployed**
- Source: `contracts/dispenser/BigBotDispenser.sol`, `contracts/vault/v2/{BotVault_v2,BotVaultFactory_v2}.sol`
- Docs: `docs/DISPENSER_AND_BURN.md`, `docs/TESTNET_V4_RESULTS.md` (17/17 PASS)

## Security model (Vault)

1. Immutable `operator` and `keyMaster` must differ.
2. `arm(token, maxAmount, nonce)` — only keyMaster; pulls `signalAmount` of `signalToken` to `signalSink`.
3. `withdraw(token, amount, to)` — only operator; requires active arm, delay met, `to == allowedExit`, amount ≤ armed max.
4. Decoys → `trapAddress`. Errors on real path → revert.
5. No upgradeable proxy. `tripwire()` freezes without moving funds.

**Hard limit:** attacker with both roles + allowlisted exit can drain after delay/caps.

## Do / Don't

- DO fork under MIT; DO keep roles on separate keys; DO verify bytecode against this repo.
- DON'T publish private keys, mnemonics, `.env`, keystores, Cloudflare tunnel URLs, or airdrop allowlists/claim packs.
- DON'T treat testnet Vault / Dispenser / v2 addresses as mainnet.

## Related docs

- `docs/BOT_VAULT_ARMOR_v1.md` — full design
- `docs/BIGBOT_KEY_RAIL_v0.md` — token-as-signal-rail thesis
- `docs/DISPENSER_AND_BURN.md` — dispenser + v2 burn design (testnet only)
- `docs/TESTNET_V4_RESULTS.md` — v2/dispenser testnet results
- `llms.txt` — short crawl summary
