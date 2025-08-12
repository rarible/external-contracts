#!/usr/bin/env bash
set -euo pipefail

CONTRACTS_DIR="contracts"
COMPILED=() # array of compiled contract absolute paths

# To track compiled contracts quickly
declare -A compiled_map

compiled_count=0
total_contracts=0

# Find all contracts under contracts directory
mapfile -t all_contracts < <(find "$CONTRACTS_DIR" -type f -name "*.sol")

total_contracts=${#all_contracts[@]}

echo "Found $total_contracts contracts under $CONTRACTS_DIR"

# Resolve imports and compile recursively
compile_contract() {
  local contract_path="$1"
  # Normalize path to absolute
  contract_path=$(realpath "$contract_path")

  # Check if already compiled
  if [[ ${compiled_map["$contract_path"]+exists} ]]; then
    return
  fi

  # Parse imports (assumes imports are relative paths or absolute within repo)
  # Matches: import "path";
  local imports=()
  while IFS= read -r line; do
    line=$(echo "$line" | xargs)
    if echo "$line" | grep -qE '^import[[:space:]]+"[^"]+"[[:space:]]*;'; then
        imp=$(echo "$line" | sed -E 's|^import[[:space:]]+"([^"]+)".*|\1|')
        local contract_dir
        contract_dir=$(dirname "$contract_path")

        local imp_path
        if [[ "$imp" == /* ]]; then
        imp_path="$imp"
        else
        imp_path="$contract_dir/$imp"
        fi

        imp_path=$(realpath "$imp_path")

        if [[ -f "$imp_path" ]]; then
        imports+=("$imp_path")
        else
        echo "Warning: import $imp_path not found for $contract_path"
        fi
    fi
  done < "$contract_path"


  # Recursively compile dependencies first
  for dep in "${imports[@]}"; do
    compile_contract "$dep"
  done

  # Now compile this contract individually with zk flag
  echo "Compiling $contract_path ..."
  forge build --zksync --contracts "$contract_path"
  compiled_map["$contract_path"]=1
  ((compiled_count++))
  echo "Compiled $compiled_count / $total_contracts contracts."
}

# Iterate over all contracts found and compile them (will skip already compiled)
for contract in "${all_contracts[@]}"; do
  compile_contract "$contract"
done

echo "Compilation done. Total contracts compiled: $compiled_count"
