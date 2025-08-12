// batch-compile-zk.ts
import fs from "fs";
import path from "path";
import { execSync } from "child_process";
import toml from "toml";
import { parse } from "@solidity-parser/parser";

const CONTRACTS_DIR = "contracts";
const BATCH_SIZE = 20; // adjust as needed
const ZK_SOLC_BIN = "zk-solc"; // must be installed and in PATH
const BUILD_DIR = "zk-out";

// Load remappings from foundry.toml
function loadRemappings(): Record<string, string> {
  const foundryTomlPath = path.resolve("foundry.toml");
  if (!fs.existsSync(foundryTomlPath)) {
    throw new Error("foundry.toml not found");
  }
  const tomlData = toml.parse(fs.readFileSync(foundryTomlPath, "utf-8"));
  const remappings: Record<string, string> = {};

  if (tomlData.profile?.default?.remappings || tomlData.remappings) {
    const remapList: string[] = tomlData.profile?.default?.remappings || tomlData.remappings || [];
    remapList.forEach((r) => {
      const [prefix, target] = r.split("=");
      remappings[prefix.trim()] = target.trim();
    });
  }
  return remappings;
}

// Find all Solidity files in contracts/
function getAllContracts(): string[] {
  const files: string[] = [];
  function walk(dir: string) {
    fs.readdirSync(dir, { withFileTypes: true }).forEach((entry) => {
      const fullPath = path.join(dir, entry.name);
      if (entry.isDirectory()) walk(fullPath);
      else if (entry.isFile() && entry.name.endsWith(".sol")) files.push(fullPath);
    });
  }
  walk(CONTRACTS_DIR);
  return files;
}

// Parse imports for a Solidity file
function getImports(filePath: string): string[] {
  const content = fs.readFileSync(filePath, "utf-8");
  let imports: string[] = [];
  try {
    const ast = parse(content, { tolerant: true });
    ast.children.forEach((node: any) => {
      if (node.type === "ImportDirective") {
        imports.push(node.path);
      }
    });
  } catch (err) {
    console.error(`Failed to parse ${filePath}:`, err);
  }
  return imports;
}

// Resolve import path to actual file
function resolveImport(importPath: string, remappings: Record<string, string>): string {
  for (const prefix in remappings) {
    if (importPath.startsWith(prefix)) {
      return path.resolve(remappings[prefix], importPath.slice(prefix.length));
    }
  }
  return path.resolve(CONTRACTS_DIR, importPath);
}

// Build dependency graph
function buildDependencyGraph(files: string[], remappings: Record<string, string>) {
  const graph: Record<string, Set<string>> = {};
  files.forEach((file) => {
    const imports = getImports(file).map((imp) => resolveImport(imp, remappings));
    graph[file] = new Set(imports.filter((f) => fs.existsSync(f) && f.endsWith(".sol")));
  });
  return graph;
}

// Topological sort
function topoSort(graph: Record<string, Set<string>>): string[] {
  const visited = new Set<string>();
  const result: string[] = [];

  function visit(node: string) {
    if (visited.has(node)) return;
    visited.add(node);
    (graph[node] || []).forEach(visit);
    result.push(node);
  }

  Object.keys(graph).forEach(visit);
  return result;
}

// Batch compile
function batchCompile(files: string[]) {
  console.log(`Compiling ${files.length} contracts in batches of ${BATCH_SIZE}...`);
  for (let i = 0; i < files.length; i++) {
    const contract = files[i];
    console.log(`\n[${i + 1}/${files.length}] Compiling ${contract} ...`);
    try {
      execSync(
        `forge build --zksync --contracts ${contract}`,
        { stdio: "inherit" }
      );
    } catch (err) {
      console.error(`Error compiling ${contract}:`, err);
      process.exit(1);
    }
  }
}

function main() {
  const remappings = loadRemappings();
  const allFiles = getAllContracts();
  const depGraph = buildDependencyGraph(allFiles, remappings);
  const sortedFiles = topoSort(depGraph);
  batchCompile(sortedFiles);
}

main();
