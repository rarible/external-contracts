# Creator Token (ERC721-C) Transfer Policy Guide

This guide explains how to configure transfer policies for ERC721-C contracts on **Base** network using the Creator Token Transfer Validator.

## Contract Addresses (Base Mainnet)

| Contract | Address |
|----------|---------|
| Transfer Validator | `0x721C008fdff27BF06E7E123956E2Fe03B63342e3` |
| RulesetWhitelist | `0x00721CE73fDE1e57A9048E0e19B7ee7c8D3F10E3` |
| RulesetBlacklist | `0x00721C2b7f77bBC59659E65BE4bb799D94995844` |
| RulesetVanilla | `0x00721CC6Ea8D83309720e2b5581529d2B3762b73` |
| RulesetSoulbound | `0x00721Cbc023e08a3DAf2d21b683C7F0CB281cccf` |

## Available Rulesets

| Ruleset ID | Name | Description |
|------------|------|-------------|
| 0 | RulesetWhitelist | Only whitelisted operators can transfer |
| 1 | RulesetVanilla | No restrictions |
| 2 | RulesetSoulbound | No transfers allowed (soulbound) |
| 3 | RulesetBlacklist | Blacklisted operators are blocked |

## Ruleset Options

| rulesetOptions | Effect |
|----------------|--------|
| 0 | OTC Enabled (default) - Direct wallet-to-wallet transfers allowed |
| 1 | OTC Disabled - Only whitelisted operators can transfer |

## Pre-existing Lists (Base Mainnet)

| List ID | Whitelist Count | Blacklist Count | Description |
|---------|-----------------|-----------------|-------------|
| **0** | 4 operators | 0 | Default Limit Break list (no blacklist) |
| **1** | 4 operators | 12 blocked | **Recommended** - Standard list with blacklist |
| 2 | 0 | 0 | Empty |
| 3 | 1 | 0 | Custom |
| 4 | 0 | 0 | Empty |
| 5 | 0 | 0 | Empty |
| 6 | 5 | 0 | Standard + 1 custom |
| 7 | 5 | 0 | Standard + 1 custom |
| 8 | 11 | 0 | Custom marketplace list |
| 9 | 1 | 0 | Custom |
| 10 | 4 | 0 | Standard operators only |
| 11 | 0 | 0 | Empty |
| 12 | - | - | - |
| 13 | 3 | 0 | Custom |
| 14 | 0 | 0 | Empty |
| 15 | 0 | 0 | Empty |
| 16 | - | - | - |
| 17 | 1 | 0 | Custom |

> **WARNING:** Using `rulesetId=0` (Whitelist mode) with an **empty list** will **block ALL transfers** except OTC (caller == from). Always use a list with whitelisted operators, or use **rulesetId=1** (Vanilla) for no restrictions.

### Recommended Lists for Whitelist Mode:
- **List 0** - Standard operators, no blacklist
- **List 1** - Standard operators + blacklist (most complete protection)
- **List 10** - Standard operators, no blacklist

### Standard Whitelisted Operators (Lists 0, 1, 10):
| Address | Name |
|---------|------|
| `0x9A1D00bEd7CD04BCDA516d721A596eb22Aac6834` | PaymentProcessor |
| `0x9A1D001670C8b17F8B7900E8d7a41e785B3F0515` | PaymentProcessorV2 |
| `0x9a1D00000000fC540e2000560054812452eB5366` | PaymentProcessor Encoder |
| `0x0E00009d00d1000069ed00A908e00081F5006008` | Seaport 1.6 |

### List 1 Blacklisted Operators (known royalty bypassers):
| Address |
|---------|
| `0x6c19f753427781B788AcAe35D9B194691e89b568` |
| `0xFA36f4AB9640efd797a80442E441F9cFdE637483` |
| `0x257CA2d502eC6f41aD44F318Ed18A2d39Af7933F` |
| `0x4747be3Df61e444347A36A6939A7A1117BAe2fD5` |
| `0x654d975F5477Ec353B60537a6780C0022328eCA7` |
| `0x7906f5f02212343C605D0e1CECD544DFD1FCA6DC` |
| `0x49b43F5156103AaDfA789c06b8a9e7Cd803499e8` |
| `0xBa75718Ff97B9225a56B92A9138e0B738F75Db66` |
| `0x233De1fe836FB2FE794f5EEFB80e0Fb1d6CA868E` |
| `0x8d03D41a5Ed91Fb9e5d847b2A70BFaBAE31A2154` |
| `0x6FffeE14e2504f327578A51B15Def4eD9Ca119Ec` |
| `0x7ad45465bf8c48cF9348E14931e965f8E65D0C4F` |

### Check List Contents
```bash
# Check whitelist (listType=1)
cast call 0x721C008fdff27BF06E7E123956E2Fe03B63342e3 \
  "getListAccounts(uint48,uint8)(address[])" <LIST_ID> 1 \
  --rpc-url https://mainnet.base.org

# Check blacklist (listType=0)
cast call 0x721C008fdff27BF06E7E123956E2Fe03B63342e3 \
  "getListAccounts(uint48,uint8)(address[])" <LIST_ID> 0 \
  --rpc-url https://mainnet.base.org

# Check list owner
cast call 0x721C008fdff27BF06E7E123956E2Fe03B63342e3 \
  "listOwners(uint48)(address)" <LIST_ID> \
  --rpc-url https://mainnet.base.org
```

---

## 1. How to Disable OTC (Enforce Royalties)

Disabling OTC ensures that only whitelisted marketplaces (that pay royalties) can facilitate transfers.

### Step 1: Set Ruleset with OTC Disabled

```bash
cast send 0x721C008fdff27BF06E7E123956E2Fe03B63342e3 \
  "setRulesetOfCollection(address,uint8,address,uint8,uint16)" \
  <YOUR_COLLECTION_ADDRESS> \
  0 \
  0x0000000000000000000000000000000000000000 \
  0 \
  1 \
  --rpc-url https://mainnet.base.org \
  --private-key <YOUR_PRIVATE_KEY>
```

Parameters:
- `collection`: Your NFT contract address
- `rulesetId`: `0` (RulesetWhitelist)
- `customRuleset`: `0x0` (use default)
- `globalOptions`: `0`
- `rulesetOptions`: `1` (OTC Disabled)

### Step 2: Apply List 1 (Whitelist)

```bash
cast send 0x721C008fdff27BF06E7E123956E2Fe03B63342e3 \
  "applyListToCollection(address,uint48)" \
  <YOUR_COLLECTION_ADDRESS> \
  1 \
  --rpc-url https://mainnet.base.org \
  --private-key <YOUR_PRIVATE_KEY>
```

### Verify Configuration

```bash
cast call 0x721C008fdff27BF06E7E123956E2Fe03B63342e3 \
  "getCollectionSecurityPolicy(address)((uint8,uint48,address,uint8,uint16,uint16))" \
  <YOUR_COLLECTION_ADDRESS> \
  --rpc-url https://mainnet.base.org
```

Expected output: `(0, 1, 0x0000000000000000000000000000000000000000, 0, 1, 721)`
- rulesetId: 0
- listId: 1
- rulesetOptions: 1 (OTC Disabled)

### Test Transfer Validation

```bash
# Should return (0, error_selector) - transfer blocked
cast call 0x721C008fdff27BF06E7E123956E2Fe03B63342e3 \
  "validateTransferSim(address,address,address,address,uint256)" \
  <YOUR_COLLECTION_ADDRESS> \
  <CALLER_ADDRESS> \
  <FROM_ADDRESS> \
  <TO_ADDRESS> \
  <TOKEN_ID> \
  --rpc-url https://mainnet.base.org
```

---

## 2. How to Enable OTC (Allow Direct Transfers)

To allow direct wallet-to-wallet transfers again:

### Option A: Keep Whitelist but Enable OTC

```bash
cast send 0x721C008fdff27BF06E7E123956E2Fe03B63342e3 \
  "setRulesetOfCollection(address,uint8,address,uint8,uint16)" \
  <YOUR_COLLECTION_ADDRESS> \
  0 \
  0x0000000000000000000000000000000000000000 \
  0 \
  0 \
  --rpc-url https://mainnet.base.org \
  --private-key <YOUR_PRIVATE_KEY>
```

Parameters:
- `rulesetOptions`: `0` (OTC Enabled)

### Option B: Remove All Restrictions (Vanilla)

```bash
cast send 0x721C008fdff27BF06E7E123956E2Fe03B63342e3 \
  "setRulesetOfCollection(address,uint8,address,uint8,uint16)" \
  <YOUR_COLLECTION_ADDRESS> \
  1 \
  0x0000000000000000000000000000000000000000 \
  0 \
  0 \
  --rpc-url https://mainnet.base.org \
  --private-key <YOUR_PRIVATE_KEY>
```

Parameters:
- `rulesetId`: `1` (RulesetVanilla - no restrictions)

---

## 3. How to Create a Custom List

### Step 1: Create the List

```bash
cast send 0x721C008fdff27BF06E7E123956E2Fe03B63342e3 \
  "createList(string)" \
  "My Custom Whitelist" \
  --rpc-url https://mainnet.base.org \
  --private-key <YOUR_PRIVATE_KEY>
```

This returns a new `listId` in the transaction logs. You can also check:

```bash
cast call 0x721C008fdff27BF06E7E123956E2Fe03B63342e3 \
  "lastListId()(uint48)" \
  --rpc-url https://mainnet.base.org
```

### Step 2: Add Accounts to Whitelist

```bash
# List type: 0 = blacklist, 1 = whitelist, 2 = authorizers
cast send 0x721C008fdff27BF06E7E123956E2Fe03B63342e3 \
  "addAccountsToList(uint48,uint8,address[])" \
  <LIST_ID> \
  1 \
  "[<ADDRESS_1>,<ADDRESS_2>,<ADDRESS_3>]" \
  --rpc-url https://mainnet.base.org \
  --private-key <YOUR_PRIVATE_KEY>
```

### Step 3: Add Accounts to Blacklist (Optional)

```bash
cast send 0x721C008fdff27BF06E7E123956E2Fe03B63342e3 \
  "addAccountsToList(uint48,uint8,address[])" \
  <LIST_ID> \
  0 \
  "[<BLOCKED_ADDRESS_1>,<BLOCKED_ADDRESS_2>]" \
  --rpc-url https://mainnet.base.org \
  --private-key <YOUR_PRIVATE_KEY>
```

### Verify List Contents

```bash
# Get whitelist accounts
cast call 0x721C008fdff27BF06E7E123956E2Fe03B63342e3 \
  "getListAccounts(uint48,uint8)(address[])" \
  <LIST_ID> \
  1 \
  --rpc-url https://mainnet.base.org

# Get blacklist accounts
cast call 0x721C008fdff27BF06E7E123956E2Fe03B63342e3 \
  "getListAccounts(uint48,uint8)(address[])" \
  <LIST_ID> \
  0 \
  --rpc-url https://mainnet.base.org
```

### Remove Accounts from List

```bash
cast send 0x721C008fdff27BF06E7E123956E2Fe03B63342e3 \
  "removeAccountsFromList(uint48,uint8,address[])" \
  <LIST_ID> \
  1 \
  "[<ADDRESS_TO_REMOVE>]" \
  --rpc-url https://mainnet.base.org \
  --private-key <YOUR_PRIVATE_KEY>
```

---

## 4. Apply Custom List to Collection

### Apply Your Custom List

```bash
cast send 0x721C008fdff27BF06E7E123956E2Fe03B63342e3 \
  "applyListToCollection(address,uint48)" \
  <YOUR_COLLECTION_ADDRESS> \
  <YOUR_LIST_ID> \
  --rpc-url https://mainnet.base.org \
  --private-key <YOUR_PRIVATE_KEY>
```

### Full Setup with Custom List

```bash
# 1. Create list
cast send 0x721C008fdff27BF06E7E123956E2Fe03B63342e3 \
  "createList(string)" \
  "My Marketplace Whitelist" \
  --rpc-url https://mainnet.base.org \
  --private-key <YOUR_PRIVATE_KEY>

# 2. Get the new list ID
cast call 0x721C008fdff27BF06E7E123956E2Fe03B63342e3 \
  "lastListId()(uint48)" \
  --rpc-url https://mainnet.base.org

# 3. Add whitelisted marketplaces (example: Seaport + PaymentProcessor)
cast send 0x721C008fdff27BF06E7E123956E2Fe03B63342e3 \
  "addAccountsToList(uint48,uint8,address[])" \
  <NEW_LIST_ID> \
  1 \
  "[0x0E00009d00d1000069ed00A908e00081F5006008,0x9A1D00bEd7CD04BCDA516d721A596eb22Aac6834]" \
  --rpc-url https://mainnet.base.org \
  --private-key <YOUR_PRIVATE_KEY>

# 4. Set ruleset with OTC disabled
cast send 0x721C008fdff27BF06E7E123956E2Fe03B63342e3 \
  "setRulesetOfCollection(address,uint8,address,uint8,uint16)" \
  <YOUR_COLLECTION_ADDRESS> \
  0 \
  0x0000000000000000000000000000000000000000 \
  0 \
  1 \
  --rpc-url https://mainnet.base.org \
  --private-key <YOUR_PRIVATE_KEY>

# 5. Apply your custom list
cast send 0x721C008fdff27BF06E7E123956E2Fe03B63342e3 \
  "applyListToCollection(address,uint48)" \
  <YOUR_COLLECTION_ADDRESS> \
  <NEW_LIST_ID> \
  --rpc-url https://mainnet.base.org \
  --private-key <YOUR_PRIVATE_KEY>
```

---

## Quick Reference Commands

### Check Collection Policy
```bash
cast call 0x721C008fdff27BF06E7E123956E2Fe03B63342e3 \
  "getCollectionSecurityPolicy(address)((uint8,uint48,address,uint8,uint16,uint16))" \
  <COLLECTION> --rpc-url https://mainnet.base.org
```

### Check if Account is Whitelisted
```bash
cast call 0x721C008fdff27BF06E7E123956E2Fe03B63342e3 \
  "isAccountInList(uint48,uint8,address)(bool)" \
  <LIST_ID> 1 <ACCOUNT> --rpc-url https://mainnet.base.org
```

### Simulate Transfer
```bash
cast call 0x721C008fdff27BF06E7E123956E2Fe03B63342e3 \
  "validateTransferSim(address,address,address,address,uint256)" \
  <COLLECTION> <CALLER> <FROM> <TO> <TOKEN_ID> --rpc-url https://mainnet.base.org
```

### Get List Owner
```bash
cast call 0x721C008fdff27BF06E7E123956E2Fe03B63342e3 \
  "listOwners(uint48)(address)" \
  <LIST_ID> --rpc-url https://mainnet.base.org
```

---

## Error Codes

| Selector | Error |
|----------|-------|
| `0xe1f1d02e` | CallerOrFromMustBeWhitelisted |
| `0x7f954ba1` | CallerMustHaveElevatedPermissionsForSpecifiedNFT |
| `0x...` | OperatorIsBlacklisted |
| `0x...` | ReceiverAccountIsFrozen |

---

## Important Notes

1. **Only the collection owner** (address with DEFAULT_ADMIN_ROLE) can modify transfer policies.

2. **List ownership**: Only the list owner can modify list contents. If you create a list, you own it.

3. **Testing**: Always test configuration changes on testnet first.

4. **Royalty flow**: ERC721-C doesn't pay royalties directly - it restricts transfers to whitelisted marketplaces that honor EIP-2981 royalties.

5. **Simulation vs Reality**: Use `validateTransferSim` to test policies before actual transfers.

---

## Common Pitfalls

### 1. Empty Whitelist Blocks All Transfers

**Problem:** Using `rulesetId=0` (Whitelist) with an empty list (e.g., List 2, 4, 5, 11, 14, 15) blocks ALL transfers.

**Symptoms:** 
- Error: `0xe1f1d02e` (`CallerOrFromMustBeWhitelisted`)
- Only OTC transfers work (caller == from)

**Solution:** Either:
- Use **List 0 or 1** (has whitelisted operators): `applyListToCollection(collection, 1)`
- Or use **Vanilla mode** (no restrictions): `setRulesetOfCollection(collection, 1, 0x0, 0, 0)`

### 2. Wrong List Applied

**Problem:** Collection is using an empty list (e.g., List 2) instead of a populated one.

**Empty lists:** 2, 4, 5, 11, 14, 15

**Populated lists:** 0, 1, 3, 6, 7, 8, 9, 10, 13, 17

**How to check:**
```bash
cast call 0x721C008fdff27BF06E7E123956E2Fe03B63342e3 \
  "getCollectionSecurityPolicy(address)((uint8,uint48,address,uint8,uint16,uint16))" \
  <COLLECTION> --rpc-url https://mainnet.base.org
```

Look at `listId` in the response. If it's an empty list and you're using Whitelist mode, change to List 0 or 1.

### 3. OTC Disabled When Not Intended

**Problem:** Direct wallet-to-wallet transfers fail unexpectedly.

**Check:** Look at `rulesetOptions` in the policy:
- `0` = OTC Enabled
- `1` = OTC Disabled

### 4. Caller Not in Whitelist

**Problem:** A specific marketplace/operator can't transfer.

**Solution:** Add the operator to your list's whitelist:
```bash
cast send 0x721C008fdff27BF06E7E123956E2Fe03B63342e3 \
  "addAccountsToList(uint48,uint8,address[])" \
  <LIST_ID> 1 "[<OPERATOR_ADDRESS>]" \
  --rpc-url https://mainnet.base.org --private-key <KEY>
```

---

## Example: Full Royalty Enforcement Setup

```bash
# Variables
COLLECTION="0xYourCollectionAddress"
PRIVATE_KEY="0xYourPrivateKey"
RPC="https://mainnet.base.org"
VALIDATOR="0x721C008fdff27BF06E7E123956E2Fe03B63342e3"

# 1. Set Whitelist Ruleset with OTC Disabled
cast send $VALIDATOR \
  "setRulesetOfCollection(address,uint8,address,uint8,uint16)" \
  $COLLECTION 0 0x0000000000000000000000000000000000000000 0 1 \
  --rpc-url $RPC --private-key $PRIVATE_KEY

# 2. Apply Standard Whitelist (List 1)
cast send $VALIDATOR \
  "applyListToCollection(address,uint48)" \
  $COLLECTION 1 \
  --rpc-url $RPC --private-key $PRIVATE_KEY

# 3. Verify
cast call $VALIDATOR \
  "getCollectionSecurityPolicy(address)((uint8,uint48,address,uint8,uint16,uint16))" \
  $COLLECTION --rpc-url $RPC

# Expected: (0, 1, 0x0000000000000000000000000000000000000000, 0, 1, 721)
```

---

## Support

For issues or questions about Creator Token Standards, refer to:
- [Limit Break Creator Token Standards](https://github.com/limitbreakinc/creator-token-standards)
- [ERC721-C Documentation](https://medium.com/limit-break/introducing-erc721-c-a-new-standard-for-enforceable-on-chain-programmable-royalties-defaa127410)
