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
- DON'T treat testnet Vault addresses as mainnet.

## Related docs

- `docs/BOT_VAULT_ARMOR_v1.md` — full design
- `docs/BIGBOT_KEY_RAIL_v0.md` — token-as-signal-rail thesis
- `llms.txt` — short crawl summary
