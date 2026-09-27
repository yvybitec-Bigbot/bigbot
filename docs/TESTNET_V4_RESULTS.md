# Testnet V4 results — BIGBOT Dispenser + Vault Armor v2

> **TESTNET ONLY** — PulseChain Testnet V4, chainId `943`, explorer https://scan.v4.testnet.pulsechain.com. Nothing here is deployed on mainnet.

## English

A 17-test suite exercised `BigBotDispenser` (two instances) and `BotVaultFactory` v2 / `BotVault` v2 on PulseChain Testnet V4 (24 Sep 2026). **Result: 17/17 PASS.** Sources are in [`contracts/dispenser/`](../contracts/dispenser/) and [`contracts/vault/v2/`](../contracts/vault/v2/); design in [`DISPENSER_AND_BURN.md`](DISPENSER_AND_BURN.md).

**About `MockSignal`:** on testnet, the signal token is a **mock ERC-20** (`MockERC20`, mintable test token), *not* BIGBOT. Its address `0xeb6F7B997c0020f5C0334815d9BEAAB661bCfEf6` is identical to the mainnet BIGBOT address only by coincidence: the same deployer account had the same nonce on both chains, so `CREATE` produced the same address on a different chainId. The testnet contract is a mock; do not confuse it with mainnet BIGBOT (chainId 369).

## Español

Una batería de 17 pruebas sobre `BigBotDispenser` (dos instancias) y `BotVaultFactory` v2 / `BotVault` v2 en PulseChain Testnet V4 (24 sep 2026). **Resultado: 17/17 OK.**

**Sobre `MockSignal`:** en testnet el token de señal es un **ERC-20 de prueba** (mock, acuñable), *no* BIGBOT. Su dirección coincide con la de BIGBOT en mainnet solo por casualidad: la misma cuenta desplegadora tenía el mismo nonce en ambas cadenas. Es un mock de testnet; no confundir con BIGBOT de mainnet (chainId 369).

## Parameters used

| | |
|--|--|
| Dispenser Scenario B | 1000 tPLS/BIGBOT · cap 369/address · daily cap 20,000 · stock 2,000,000 · priceOnlyIncrease |
| Dispenser Cheap | 1 tPLS/BIGBOT · cap 369/address · daily cap 20,000 · stock 10,000 (to run the vault flow cheaply) |
| Vault v2 | burn 1 per arm · burn 50 per createVault · minArmDelay 15 s (test only) · armTTL 600 s · maxWithdrawBps 5000 · maxArmsPerDay 10 |
| Compiler | solc 0.8.20 · optimizer 200 · viaIR |

## Tests (17/17 PASS)

| # | Test | What it checks | Revert | Tx | Result |
|---|------|----------------|--------|----|--------|
| 1 | `buy_within_cap_ScenarioB` | Scenario B dispenser: buy 2 BIGBOT at 1000 tPLS each |  | [`0x30340cd3bd…`](https://scan.v4.testnet.pulsechain.com/tx/0x30340cd3bd2e9d9a8f89732a0ca39a4e5ad065cc617438bfcf86ed5ad1083836) | ✅ PASS |
| 2 | `buy_over_cap_reverts` | Scenario B: buy beyond 369/address cap reverts | reverted `CapAddress` (`0xceba5aef`) | — (eth_call revert, no tx) | ✅ PASS |
| 3 | `buyer_buy_cheap` | Cheap dispenser (1 tPLS/BIGBOT): buyer purchase |  | [`0xe3d9fa8db8…`](https://scan.v4.testnet.pulsechain.com/tx/0xe3d9fa8db822391b7e96392fa5016610404c9e8de57a57f8208e72b92aca6117) | ✅ PASS |
| 4 | `buy_over_cap_cheap_reverts` | Cheap dispenser: buy after filling cap reverts ¹ | reverted `CapAddress` (`0xceba5aef`) with exact payment | [0x6078a8fc…](https://scan.v4.testnet.pulsechain.com/tx/0x6078a8fcc6128ff34268417c92c953cfd35e6ade009c0b006a188368ac0eac64) (reverted, status 0) | ✅ PASS |
| 5 | `pause_blocks_buys` | Owner pauses; buy reverts while paused | reverted `PausedErr` (`0xda829339`) | [`0x78c0e31226…`](https://scan.v4.testnet.pulsechain.com/tx/0x78c0e3122624d3ac7ab6479ca631f6039d39e073f07fcff65db5ebfed52d8e04) (pause tx) | ✅ PASS |
| 6 | `unpause_ok` | Owner unpauses |  | [`0x1104de9619…`](https://scan.v4.testnet.pulsechain.com/tx/0x1104de96190d9fcf5d8e2d5964a46641c0160d2154594b716918b159a01fe39a) | ✅ PASS |
| 7 | `setPrice_lower_reverts` | Lowering price reverts (priceOnlyIncrease) | reverted `PriceDecreaseForbidden` (`0x77055eca`) | — (eth_call revert, no tx) | ✅ PASS |
| 8 | `setPrice_higher_ok` | Raising price succeeds |  | [`0xc7d6cf9dfb…`](https://scan.v4.testnet.pulsechain.com/tx/0xc7d6cf9dfb55dba49958252efbfcaa05a2d0b79cdfcc276f3cd6a07d1ce51847) | ✅ PASS |
| 9 | `non_owner_setPaused_reverts` | Non-owner setPaused reverts | reverted `NotOwner` (`0x30cd7471`) | — (eth_call revert, no tx) | ✅ PASS |
| 10 | `non_owner_setPrice_reverts` | Non-owner setPrice reverts | reverted `NotOwner` (`0x30cd7471`) | — (eth_call revert, no tx) | ✅ PASS |
| 11 | `non_owner_withdrawPLS_reverts` | Non-owner withdrawPLS reverts | reverted `NotOwner` (`0x30cd7471`) | — (eth_call revert, no tx) | ✅ PASS |
| 12 | `non_owner_withdrawBIGBOT_reverts` | Non-owner withdrawBIGBOT reverts | reverted `NotOwner` (`0x30cd7471`) | — (eth_call revert, no tx) | ✅ PASS |
| 13 | `owner_withdraw_PLS` | Owner withdraws collected tPLS |  | [`0xb0a0015565…`](https://scan.v4.testnet.pulsechain.com/tx/0xb0a0015565da9d6de880ac05055254ec0bd706b71686a89cf53a64fb3c910941) | ✅ PASS |
| 14 | `owner_withdraw_BIGBOT` | Owner withdraws unsold stock |  | [`0x1bdb756dfe…`](https://scan.v4.testnet.pulsechain.com/tx/0x1bdb756dfeb19af025bb7a558c9f5ffc8b522cbad4456a0996bf0bfd36355d95) | ✅ PASS |
| 15 | `create_burn_50` | Factory v2 createVault burns 50 to 0x…dEaD |  | [`0xd056d0e628…`](https://scan.v4.testnet.pulsechain.com/tx/0xd056d0e62853b9c1b6eb537a64b7c50036c286d53b385635145020a8696b3220) | ✅ PASS |
| 16 | `arm_burn_1` | Vault v2 arm burns 1 to 0x…dEaD |  | [`0xf93ad52cf2…`](https://scan.v4.testnet.pulsechain.com/tx/0xf93ad52cf26e2624724e93dfbef944ab1bd1d25144ae115b23f40f992c32e395) | ✅ PASS |
| 17 | `withdraw_after_arm` | Operator withdraws to allowedExit after delay |  | [`0x1478754517…`](https://scan.v4.testnet.pulsechain.com/tx/0x14787545179c66a9879ad152ba5072cfc3bf1640a9b8ac4cd224021166bf16bb) | ✅ PASS |

¹ Rerun on 2026-09-27 with the exact payment (1 BIGBOT = 1e18 wei at 1 tPLS/BIGBOT): the buyer already at the 369 cap got `CapAddress`; tx [0x6078a8fc…](https://scan.v4.testnet.pulsechain.com/tx/0x6078a8fcc6128ff34268417c92c953cfd35e6ade009c0b006a188368ac0eac64). Control: a fresh address bought 1 BIGBOT with the same payment and succeeded, [0x18901993…](https://scan.v4.testnet.pulsechain.com/tx/0x189019931d8319cfb7756efb411a8844cd7d0d0ecb2e26a4a5577409e5a15ae0). The first run had reverted with `InsufficientPLS` because it sent the wrong amount; that result is superseded. / Repetida el 27-09-2026 pagando la cantidad exacta: la dirección que ya tenía 369 fue rechazada por `CapAddress`; una dirección nueva compró con el mismo pago sin problema. Solo red de pruebas.

Revert-path tests were checked via `eth_call`/gas estimation, so they have no on-chain tx.

## Addresses (Testnet V4)

| Contract | Address |
|----------|---------|
| MockSignal (**testnet mock**, see note) | [`0xeb6F7B997c0020f5C0334815d9BEAAB661bCfEf6`](https://scan.v4.testnet.pulsechain.com/address/0xeb6F7B997c0020f5C0334815d9BEAAB661bCfEf6) |
| BigBotDispenser — Scenario B (1000 tPLS/BIGBOT) | [`0x813b35Ae3a79B798916be0b76DD3c7b5AAAEDB26`](https://scan.v4.testnet.pulsechain.com/address/0x813b35Ae3a79B798916be0b76DD3c7b5AAAEDB26) |
| BigBotDispenser — Cheap (1 tPLS/BIGBOT, for vault flow) | [`0x1796Fd37B1a010E2a3A700b2BB3f18Cb3D9cC9D5`](https://scan.v4.testnet.pulsechain.com/address/0x1796Fd37B1a010E2a3A700b2BB3f18Cb3D9cC9D5) |
| BotVaultFactory v2 (create burn 50) | [`0x60e7C9BfF5FD5315ea8f82aEE4b9Df1B3BD1B44a`](https://scan.v4.testnet.pulsechain.com/address/0x60e7C9BfF5FD5315ea8f82aEE4b9Df1B3BD1B44a) |
| MockTreasury (mTREAS, testnet mock) | [`0x7dBD7179838ae4Ada8DcEcFd18F68BE9AB4EAEA7`](https://scan.v4.testnet.pulsechain.com/address/0x7dBD7179838ae4Ada8DcEcFd18F68BE9AB4EAEA7) |
| BotVault v2 (example, burn 1/arm) | [`0x6b136bC4f46dD6FcaB4728633fbc88CfCBbd7D0a`](https://scan.v4.testnet.pulsechain.com/address/0x6b136bC4f46dD6FcaB4728633fbc88CfCBbd7D0a) |

Roles: owner/operator `0x44f4F9F703fCA7A81a108e6485d391476F2c30B9` · keyMaster/buyer `0x884C7EBB7672229f73038B904912D6A4F14DC48E` · trapAddress `0x2fe9e73a524fE09bD7758D2F25aF9b4B70f2D865` · allowedExit `0xF17bef05650C80380754173918535C13BF7F938C` · burn sink `0x000000000000000000000000000000000000dEaD`.

## Key transactions

| Step | Tx |
|------|----|
| `deploy_Dispenser_B` | [`0x47ac85f704887c450ce62aa862b2c43fb3f67bf994f86cb05a5275e7175257ba`](https://scan.v4.testnet.pulsechain.com/tx/0x47ac85f704887c450ce62aa862b2c43fb3f67bf994f86cb05a5275e7175257ba) |
| `deploy_Dispenser_Cheap` | [`0xa4e7dae8386adcb595b7e92fec517516e4c4ddf948598b58968fab177f8a1574`](https://scan.v4.testnet.pulsechain.com/tx/0xa4e7dae8386adcb595b7e92fec517516e4c4ddf948598b58968fab177f8a1574) |
| `stock_B` | [`0xd06e1d82ee7246ddcd0703d3eac2e22e59db0bc5c993de247bafab3f2870ae9b`](https://scan.v4.testnet.pulsechain.com/tx/0xd06e1d82ee7246ddcd0703d3eac2e22e59db0bc5c993de247bafab3f2870ae9b) |
| `stock_Cheap` | [`0x0bd41a5304cb89a6ffd425c7919272c78d6ff934036a06bfc408ec7528f1c2f0`](https://scan.v4.testnet.pulsechain.com/tx/0x0bd41a5304cb89a6ffd425c7919272c78d6ff934036a06bfc408ec7528f1c2f0) |
| `deploy_Factory_v2` | [`0x27c5590f7a06647af4e8a7cc0f84a973dd758df4dee0b85315cefa2a0adc4efc`](https://scan.v4.testnet.pulsechain.com/tx/0x27c5590f7a06647af4e8a7cc0f84a973dd758df4dee0b85315cefa2a0adc4efc) |
| `createVault_v2` | [`0xd056d0e62853b9c1b6eb537a64b7c50036c286d53b385635145020a8696b3220`](https://scan.v4.testnet.pulsechain.com/tx/0xd056d0e62853b9c1b6eb537a64b7c50036c286d53b385635145020a8696b3220) |
| `deposit_treasury` | [`0x4dd3cea6850dc49af9bb156064c6206e5b39a176317d3c3dcfb326ffebe68fc4`](https://scan.v4.testnet.pulsechain.com/tx/0x4dd3cea6850dc49af9bb156064c6206e5b39a176317d3c3dcfb326ffebe68fc4) |
| `arm_v2` | [`0xf93ad52cf26e2624724e93dfbef944ab1bd1d25144ae115b23f40f992c32e395`](https://scan.v4.testnet.pulsechain.com/tx/0xf93ad52cf26e2624724e93dfbef944ab1bd1d25144ae115b23f40f992c32e395) |
| `withdraw_v2` | [`0x14787545179c66a9879ad152ba5072cfc3bf1640a9b8ac4cd224021166bf16bb`](https://scan.v4.testnet.pulsechain.com/tx/0x14787545179c66a9879ad152ba5072cfc3bf1640a9b8ac4cd224021166bf16bb) |

Notes: `MockSignal` has no `burn()`; send-to-dead is the burn, so `totalSupply` does not decrease. Gas on testnet: Dispenser deploy ~752k, Factory v2 deploy ~1.53M, `createVault` v2 ~1.08M, `arm` v2 ~212k, `buy` ~116–133k.
