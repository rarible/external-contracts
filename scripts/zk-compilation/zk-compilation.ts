#!/usr/bin/env ts-node

import fs from "fs";
import path from "path";
import { execSync } from "child_process";
import toml from "toml";

type DependencyGraph = Record<string, Set<string>>;

const contractsDir = path.resolve("contracts");
const outDir = path.resolve("out");
const foundryTomlPath = path.resolve("foundry.toml");

// ===== Load remappings from foundry.toml =====
function loadRemappings(): Record<string, string> {
  const tomlContent = fs.readFileSync(foundryTomlPath, "utf8");
  const parsed = toml.parse(tomlContent);
  const remappingsArray: string[] = parsed.remappings || [];
  const remappings: Record<string, string> = {};

  for (const mapping of remappingsArray) {
    const [key, val] = mapping.split("=");
    remappings[key.trim()] = val.trim();
  }

  return remappings;
}

const remappings = loadRemappings();

// ===== Utility: Resolve imports with remappings =====
function resolveImport(importPath: string): string {
  for (const [prefix, target] of Object.entries(remappings)) {
    if (importPath.startsWith(prefix)) {
      return path.resolve(target, importPath.replace(prefix, ""));
    }
  }
  if (importPath.startsWith(".")) {
    return path.resolve(importPath);
  }
  return importPath; // leave unresolved if external
}

// ===== Find all .sol files =====
function findSolFiles(dir: string): string[] {
  let results: string[] = [];
  for (const file of fs.readdirSync(dir)) {
    const full = path.join(dir, file);
    if (fs.statSync(full).isDirectory()) {
      results = results.concat(findSolFiles(full));
    } else if (file.endsWith(".sol")) {
      results.push(full);
    }
  }
  return results;
}

// ===== Parse imports from a Solidity file =====
function parseImports(filePath: string): string[] {
  const content = fs.readFileSync(filePath, "utf8");
  const regex = /^\s*import\s+["']([^"']+)["'];/gm;
  const imports: string[] = [];
  let match;
  while ((match = regex.exec(content)) !== null) {
    imports.push(match[1]);
  }
  return imports;
}

// ===== Build dependency graph =====
function buildDependencyGraph(files: string[]): DependencyGraph {
  const graph: DependencyGraph = {};
  for (const file of files) {
    const imports = parseImports(file).map(resolveImport);
    graph[file] = new Set();
    for (const imp of imports) {
      if (imp.endsWith(".sol") && fs.existsSync(imp)) {
        graph[file].add(path.resolve(imp));
      }
    }
  }
  return graph;
}

// ===== Topological sort =====
function topologicalSort(graph: DependencyGraph): string[] {
  const visited = new Set<string>();
  const result: string[] = [];

  function visit(node: string) {
    if (visited.has(node)) return;
    visited.add(node);
    for (const dep of graph[node] || []) {
      visit(dep);
    }
    result.push(node);
  }

  for (const node of Object.keys(graph)) {
    visit(node);
  }
  return result;
}

// ===== Compile contracts in order (with error logging) =====
function compileContractsInOrder(sortedFiles: string[]) {
  const compiled = new Set<string>();
  const failedContracts: string[] = [];

  for (const file of sortedFiles) {
    if (compiled.has(file)) continue;

    console.log(`\n=== Compiling ${file} ===`);
    try {
      execSync(
        `forge build ${file} --zksync --out ${outDir}`,
        { stdio: "inherit" }
      );
      compiled.add(file);
    } catch (err) {
      console.error(`❌ Error compiling ${file}:`, (err as Error).message);
      failedContracts.push(file);
      // Continue with next file instead of exiting
    }
  }

  if (failedContracts.length > 0) {
    console.log("\n=== Compilation finished with errors ===");
    failedContracts.forEach((f) => console.log(` - ${f}`));
  } else {
    console.log("\n🎉 All contracts compiled successfully");
  }
}

// ===== Main =====
function main() {
  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir);

  console.log("Scanning Solidity contracts...");
  const allFiles = findSolFiles(contractsDir);
  console.log(`Found ${allFiles.length} contracts.`);

  console.log("Building dependency graph...");
  const graph = buildDependencyGraph(allFiles);

  console.log("Sorting contracts (topological order)...");
  const sortedFiles = topologicalSort(graph);
  console.log(`Compilation order:`);
  sortedFiles.forEach((f, i) => console.log(`${i + 1}. ${f}`));

  compileContractsInOrder(sortedFiles);
}

main();
