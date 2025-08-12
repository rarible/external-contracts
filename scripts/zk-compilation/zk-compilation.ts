import fs from "fs-extra";
import path from "path";
import { execSync } from "child_process";

// === Directories ===
const contractsDir = path.resolve(__dirname, "../contracts");
const zkArtifactsDir = path.resolve(__dirname, "../zk-artifacts");
const zkBundleDir = path.resolve(__dirname, "../zk_contract_artifacts");

// === Recursively find all .sol files ===
async function getAllSolidityFiles(dir: string): Promise<string[]> {
  const dirents = await fs.readdir(dir, { withFileTypes: true });
  const files = await Promise.all(
    dirents.map(async (dirent) => {
      const res = path.join(dir, dirent.name);
      return dirent.isDirectory() ? await getAllSolidityFiles(res) : res;
    }),
  );
  return files.flat().filter(file => file.endsWith(".sol"));
}

// === Build dependency graph based on import statements ===
async function buildDependencyGraph(files: string[]): Promise<Map<string, string[]>> {
  const graph = new Map<string, string[]>();
  const importRegex = /import\s+["'](.+)["'];/g;

  for (const file of files) {
    const content = await fs.readFile(file, "utf8");
    const imports: string[] = [];

    let match: RegExpExecArray | null;
    while ((match = importRegex.exec(content)) !== null) {
      const importPath = match[1];
      const resolvedPath = path.resolve(path.dirname(file), importPath);
      imports.push(resolvedPath);
    }

    graph.set(path.resolve(file), imports);
  }

  return graph;
}

// === Topological sort ===
function topologicalSort(graph: Map<string, string[]>): string[] {
  const visited = new Set<string>();
  const result: string[] = [];

  function visit(file: string) {
    if (visited.has(file)) return;
    visited.add(file);

    const deps = graph.get(file) || [];
    for (const dep of deps) {
      visit(dep);
    }

    result.push(file);
  }

  for (const file of graph.keys()) {
    visit(file);
  }

  return result;
}

// === Compile a single contract with zk-solc ===
function compileZK(contractPath: string) {
  console.log(`🛠 Compiling: ${contractPath}`);
  try {
    execSync(
      `zk-solc --sol ${contractPath} --circuit --out ${zkArtifactsDir}`,
      { stdio: "inherit" }
    );
  } catch (err) {
    console.error(`❌ Failed to compile ${contractPath}:`, (err as Error).message);
  }
}

// === Copy compiled artifacts to bundle directory ===
async function bundleArtifacts() {
  await fs.ensureDir(zkBundleDir);
  const artifactFiles = await fs.readdir(zkArtifactsDir);
  for (const file of artifactFiles) {
    const src = path.join(zkArtifactsDir, file);
    const dst = path.join(zkBundleDir, file);
    await fs.copy(src, dst);
  }
  console.log(`📦 ZK artifacts bundled to: ${zkBundleDir}`);
}

// === Main ===
async function main() {
  console.log("🔍 Searching for Solidity files...");
  const allSolFiles = await getAllSolidityFiles(contractsDir);

  console.log("🧩 Building dependency graph...");
  const dependencyGraph = await buildDependencyGraph(allSolFiles);

  console.log("📐 Sorting contracts by dependency...");
  const sortedContracts = topologicalSort(dependencyGraph);

  console.log("🚀 Compiling contracts...");
  for (const contract of sortedContracts) {
    compileZK(contract);
  }

  console.log("📦 Bundling artifacts...");
  await bundleArtifacts();

  console.log("✅ ZK compilation complete.");
}

main().catch((err) => {
  console.error("🔥 Script failed:", err);
  process.exit(1);
});
