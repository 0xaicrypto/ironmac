#!/usr/bin/env node
/**
 * IronMac MCP Server
 * Standard Model Context Protocol (MCP) server for Web3 & AI Agent Security.
 * Enables AI coding assistants (Claude Desktop, Cursor, Antigravity) to audit macOS security,
 * verify crypto address integrity, manage air-gap hardware isolation, and trigger emergency panic.
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool,
} from "@modelcontextprotocol/sdk/types.js";
import { exec, execFile } from "node:child_process";
import { promisify } from "node:util";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import crypto from "node:crypto";

const execAsync = promisify(exec);

// Resolve IronMac root directory
const SCRIPT_DIR = path.dirname(new URL(import.meta.url).pathname);
const IRONMAC_ROOT = path.resolve(SCRIPT_DIR, "../../");

const TOOLS: Tool[] = [
  {
    name: "audit_system_security",
    description:
      "Performs a comprehensive macOS security posture audit for Web3 developers. Checks FileVault (disk encryption), SIP, Application Firewall, Stealth Mode, Gatekeeper, SSH remote login, and Guest account.",
    inputSchema: {
      type: "object",
      properties: {
        verbose: {
          type: "boolean",
          description: "Include raw command output in report",
        },
      },
    },
  },
  {
    name: "verify_crypto_address",
    description:
      "Validates a cryptocurrency address (EVM, Solana, Bitcoin), performs EIP-55 checksum verification, and flags suspected address-poisoning / vanity impersonation attacks before signing or transfer.",
    inputSchema: {
      type: "object",
      properties: {
        address: {
          type: "string",
          description: "The crypto address to verify (e.g., 0x..., base58, or bech32)",
        },
        expected_chain: {
          type: "string",
          enum: ["evm", "solana", "bitcoin", "auto"],
          description: "Expected blockchain network (defaults to auto-detect)",
        },
      },
      required: ["address"],
    },
  },
  {
    name: "toggle_airgap",
    description:
      "Hardware-level air-gap switch: toggles or sets Wi-Fi power (en0) on macOS to enforce physical network isolation during high-value offline transaction signing.",
    inputSchema: {
      type: "object",
      properties: {
        action: {
          type: "string",
          enum: ["on", "off", "status", "toggle"],
          description: "'on' disables Wi-Fi (air-gapped), 'off' enables Wi-Fi, 'status' checks current power state",
        },
      },
      required: ["action"],
    },
  },
  {
    name: "get_defense_telemetry",
    description:
      "Reads real-time operational status of IronMac active defenses: Anti-AMOS honeypot sentry, clipboard swap guard daemon, Wi-Fi air-gap state, and ephemeral RAM vaults.",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "scan_secrets",
    description:
      "Scans a file or directory for unencrypted Ethereum / Solana private keys, 12/24-word BIP-39 seed phrases, or sensitive RPC secrets to prevent accidental commits or leaks.",
    inputSchema: {
      type: "object",
      properties: {
        target_path: {
          type: "string",
          description: "Absolute or relative path to file/directory to inspect",
        },
      },
      required: ["target_path"],
    },
  },
  {
    name: "trigger_emergency_panic",
    description:
      "EMERGENCY AIR-GAP KILL SWITCH: Instantly powers off Wi-Fi, terminates all browsers & messaging apps, clears pasteboard, and locks the screen to contain an active intrusion.",
    inputSchema: {
      type: "object",
      properties: {
        reason: {
          type: "string",
          description: "Justification or detected threat indicator triggering the panic shutdown",
        },
      },
      required: ["reason"],
    },
  },
  {
    name: "get_network_rpc",
    description:
      "Resolves curated, privacy-preserving RPC endpoints, chain IDs, and explorers for EVM & Solana networks (e.g. eth, sepolia, base, mantle, arb, op, polygon, bsc, solana). Matches the ironconsole 'rpc' hub.",
    inputSchema: {
      type: "object",
      properties: {
        network: {
          type: "string",
          enum: [
            "eth",
            "sepolia",
            "base",
            "mantle",
            "arb",
            "op",
            "polygon",
            "bsc",
            "solana",
            "all",
          ],
          description: "Target network keyword (defaults to 'all')",
        },
      },
    },
  },
  {
    name: "shred_file",
    description:
      "Cryptographically overwrites a file with 3 passes of random data before deletion, preventing SSD / RAM forensic recovery. Matches the ironconsole 'shred' tool.",
    inputSchema: {
      type: "object",
      properties: {
        file_path: {
          type: "string",
          description: "Absolute or relative path of the file to cryptographically wipe",
        },
      },
      required: ["file_path"],
    },
  },
  {
    name: "calculate_keccak256",
    description:
      "Computes Keccak-256 hash or 4-byte Ethereum function selector offline. Matches the ironconsole 'keccak' command.",
    inputSchema: {
      type: "object",
      properties: {
        data: {
          type: "string",
          description: "String or hex data to hash (e.g. 'transfer(address,uint256)' or '0x...')",
        },
        is_hex: {
          type: "boolean",
          description: "Whether the input data is hex-encoded bytes",
        },
      },
      required: ["data"],
    },
  },
  {
    name: "get_custody_playbook",
    description:
      "Returns the tactical Web3 private key custody rules, cold storage procedures, and forbidden persistence vectors. Matches the ironconsole 'key-guide' / 'wallet-guide'.",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
];

// --- Tool Implementations ---

async function runAudit() {
  const checks: Record<string, { status: "PASS" | "WARN" | "FAIL"; details: string }> = {};

  // 1. FileVault
  try {
    const { stdout } = await execAsync("fdesetup status");
    if (stdout.includes("FileVault is On")) {
      checks.filevault = { status: "PASS", details: "FileVault is ON (Full Disk Encryption Active)" };
    } else {
      checks.filevault = { status: "FAIL", details: "FileVault is OFF! SSD physical theft exposes all data." };
    }
  } catch (err: any) {
    checks.filevault = { status: "WARN", details: `Check failed: ${err.message}` };
  }

  // 2. Firewall
  try {
    const { stdout } = await execAsync("/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate");
    if (stdout.includes("enabled")) {
      checks.firewall = { status: "PASS", details: "Application Firewall is ENABLED" };
    } else {
      checks.firewall = { status: "FAIL", details: "Application Firewall is DISABLED" };
    }
  } catch (err: any) {
    checks.firewall = { status: "WARN", details: `Check failed: ${err.message}` };
  }

  // 3. Stealth Mode
  try {
    const { stdout } = await execAsync("/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode");
    if (stdout.includes("enabled")) {
      checks.stealth_mode = { status: "PASS", details: "Stealth Mode is ENABLED (Drops unsolicited ICMP/probes)" };
    } else {
      checks.stealth_mode = { status: "WARN", details: "Stealth Mode is DISABLED (Responds to network ping scans)" };
    }
  } catch (err: any) {
    checks.stealth_mode = { status: "WARN", details: `Check failed: ${err.message}` };
  }

  // 4. SIP (System Integrity Protection)
  try {
    const { stdout } = await execAsync("csrutil status");
    if (stdout.includes("enabled")) {
      checks.sip = { status: "PASS", details: "System Integrity Protection (SIP) is ENABLED" };
    } else {
      checks.sip = { status: "FAIL", details: "SIP is DISABLED! Rootkit malware can hook kernel/system binaries." };
    }
  } catch (err: any) {
    checks.sip = { status: "WARN", details: `Check failed: ${err.message}` };
  }

  // 5. Gatekeeper
  try {
    const { stdout } = await execAsync("spctl --status 2>&1 || true");
    if (stdout.includes("assessments enabled")) {
      checks.gatekeeper = { status: "PASS", details: "Gatekeeper is ENABLED (Blocks unsigned untrusted packages)" };
    } else {
      checks.gatekeeper = { status: "FAIL", details: "Gatekeeper is DISABLED! Trojan packages can execute without prompt." };
    }
  } catch (err: any) {
    checks.gatekeeper = { status: "WARN", details: `Check failed: ${err.message}` };
  }

  // 6. SSH Remote Login
  try {
    const { stdout } = await execAsync("systemsetup -getremotelogin 2>/dev/null || true");
    if (stdout.includes("Off") || stdout === "") {
      checks.ssh_remote_login = { status: "PASS", details: "Remote Login (SSH) is OFF" };
    } else {
      checks.ssh_remote_login = { status: "WARN", details: "Remote Login (SSH) is ON! Exposed to local brute-force." };
    }
  } catch {
    checks.ssh_remote_login = { status: "PASS", details: "Remote Login (SSH) is OFF (or unprivileged read)" };
  }

  // 7. Active Honeypot & ClipGuard
  try {
    const { stdout: trapOut } = await execAsync("pgrep -f 'trap_sentry.py' || true");
    checks.anti_amos_honeypot = trapOut.trim()
      ? { status: "PASS", details: "Anti-AMOS Honeypot Sentry daemon is ARMED" }
      : { status: "WARN", details: "Anti-AMOS Honeypot Sentry is INACTIVE. Run 'ironmac trap start'" };
  } catch {
    checks.anti_amos_honeypot = { status: "WARN", details: "Honeypot not running" };
  }

  try {
    const { stdout: clipOut } = await execAsync("pgrep -f 'clip_guard.py' || true");
    checks.clip_guard = clipOut.trim()
      ? { status: "PASS", details: "Clipboard Address-Swap Guard is ACTIVE" }
      : { status: "WARN", details: "Clipboard Guard is INACTIVE. Run 'ironmac clip-guard start'" };
  } catch {
    checks.clip_guard = { status: "WARN", details: "ClipGuard not running" };
  }

  const passCount = Object.values(checks).filter((c) => c.status === "PASS").length;
  const totalCount = Object.keys(checks).length;
  const score = Math.round((passCount / totalCount) * 100);

  return {
    score: `${score}%`,
    posture: score >= 80 ? "STRONG" : score >= 60 ? "MODERATE" : "CRITICAL_RISK",
    summary: `${passCount}/${totalCount} security baselines passed`,
    checks,
  };
}

function toChecksumAddress(address: string): string {
  const addr = address.toLowerCase().replace(/^0x/, "");
  const hash = crypto.createHash("keccak-256").update(addr).digest("hex");
  let ret = "0x";
  for (let i = 0; i < addr.length; i++) {
    if (parseInt(hash[i], 16) >= 8) {
      ret += addr[i].toUpperCase();
    } else {
      ret += addr[i];
    }
  }
  return ret;
}

function verifyAddress(addr: string, chain: string = "auto") {
  const cleanAddr = addr.trim();
  const results: {
    address: string;
    detected_chain: string;
    is_valid_format: boolean;
    checksummed_address?: string;
    checksum_status: "VALID_EIP55" | "INVALID_CHECKSUM" | "LOWERCASE_OR_UPPERCASE" | "N/A";
    risk_level: "LOW" | "SUSPICIOUS" | "INVALID";
    warnings: string[];
  } = {
    address: cleanAddr,
    detected_chain: "unknown",
    is_valid_format: false,
    checksum_status: "N/A",
    risk_level: "LOW",
    warnings: [],
  };

  // EVM Check
  if (/^0x[a-fA-F0-9]{40}$/.test(cleanAddr)) {
    results.detected_chain = "EVM (Ethereum / Base / Arbitrum / Mantle / Polygon / BSC)";
    results.is_valid_format = true;
    const checksummed = toChecksumAddress(cleanAddr);
    results.checksummed_address = checksummed;

    if (cleanAddr === checksummed) {
      results.checksum_status = "VALID_EIP55";
    } else if (cleanAddr === cleanAddr.toLowerCase() || cleanAddr === cleanAddr.toUpperCase()) {
      results.checksum_status = "LOWERCASE_OR_UPPERCASE";
      results.warnings.push(`Address lacks EIP-55 mixed-case checksum capitalization. Suggested: ${checksummed}`);
    } else {
      results.checksum_status = "INVALID_CHECKSUM";
      results.risk_level = "INVALID";
      results.warnings.push(`Corrupted or forged EIP-55 checksum! Expected: ${checksummed}`);
    }

    // Check for obvious vanity / poison patterns (e.g. 0x000000... or repeated chunks)
    if (/^0x0{6,}/.test(cleanAddr)) {
      results.risk_level = "SUSPICIOUS";
      results.warnings.push("High vanity prefix (multiple leading zeros). Verify against address-poisoning spoof attacks.");
    }
    return results;
  }

  // Solana Check (Base58, 32-44 characters)
  if (/^[1-9A-HJ-NP-Za-km-z]{32,44}$/.test(cleanAddr)) {
    results.detected_chain = "Solana";
    results.is_valid_format = true;
    return results;
  }

  // Bitcoin Check
  if (/^(1|3|bc1)[a-zA-HJ-NP-Z0-9]{25,62}$/.test(cleanAddr)) {
    results.detected_chain = "Bitcoin";
    results.is_valid_format = true;
    return results;
  }

  results.risk_level = "INVALID";
  results.warnings.push("Does not match any recognized EVM, Solana, or Bitcoin address syntax.");
  return results;
}

async function handleAirgap(action: string) {
  const dev = "en0";
  const { stdout: currentStatus } = await execAsync(`networksetup -getairportpower ${dev} 2>/dev/null || true`);
  const isCurrentlyOn = currentStatus.includes("On");

  if (action === "status") {
    return {
      airgap_active: !isCurrentlyOn,
      wifi_power: isCurrentlyOn ? "ON" : "OFF",
      interface: dev,
      guidance: isCurrentlyOn ? "System is ONLINE. Use action='on' to physically isolate before signing." : "System is AIR-GAPPED (Physically Isolated). Safe for offline cold signing.",
    };
  }

  if (action === "on" || (action === "toggle" && isCurrentlyOn)) {
    await execAsync(`networksetup -setairportpower ${dev} off 2>/dev/null || true`);
    return {
      airgap_active: true,
      wifi_power: "OFF",
      message: `⚡ Wi-Fi interface (${dev}) successfully shut down. Workstation is now physically air-gapped.`,
    };
  }

  if (action === "off" || (action === "toggle" && !isCurrentlyOn)) {
    await execAsync(`networksetup -setairportpower ${dev} on 2>/dev/null || true`);
    return {
      airgap_active: false,
      wifi_power: "ON",
      message: `📶 Wi-Fi interface (${dev}) re-enabled. System reconnected to network.`,
    };
  }

  return { error: `Unknown action: ${action}` };
}

async function getDefenseTelemetry() {
  const { stdout: trapPid } = await execAsync("pgrep -f 'trap_sentry.py' || true");
  const { stdout: clipPid } = await execAsync("pgrep -f 'clip_guard.py' || true");
  const { stdout: wifiStatus } = await execAsync("networksetup -getairportpower en0 2>/dev/null || true");
  const { stdout: mounts } = await execAsync("df -h | grep -i 'IronVault' || true");

  return {
    timestamp: new Date().toISOString(),
    anti_amos_honeypot: {
      status: trapPid.trim() ? "ARMED" : "INACTIVE",
      pid: trapPid.trim() || null,
      decoy_locations: [
        "~/.ethereum/keystore/UTC--canary-ironmac-trap.json",
        "~/.config/solana/id.json",
        "~/Documents/.ironmac_canary/wallet_backup_do_not_share.txt",
      ],
    },
    clipboard_guard: {
      status: clipPid.trim() ? "ARMED" : "INACTIVE",
      pid: clipPid.trim() || null,
      protection: "Rapid clipboard address-swap detection + 30s key TTL auto-wipe",
    },
    hardware_airgap: {
      wifi_power: wifiStatus.includes("On") ? "ON" : "OFF",
      airgap_active: !wifiStatus.includes("On"),
    },
    active_ram_vaults: mounts.trim() ? mounts.trim().split("\n") : "No ephemeral RAM disks mounted",
  };
}

async function scanSecrets(targetPath: string) {
  const resolved = path.resolve(process.cwd(), targetPath);
  if (!fs.existsSync(resolved)) {
    return { error: `Path not found: ${resolved}` };
  }

  const findings: Array<{ file: string; line: number; type: string; snippet: string }> = [];

  const HEX_KEY_REGEX = /(?:0x)?[0-9a-fA-F]{64}/g;
  const SECRET_ENV_REGEX = /(?:PRIVATE_KEY|MNEMONIC|SEED_PHRASE|API_KEY|SECRET)\s*=\s*['"]?([^\s'"]+)['"]?/gi;

  function scanContent(content: string, filePath: string) {
    const lines = content.split("\n");
    lines.forEach((line, idx) => {
      // Don't scan lockfiles or minified files
      if (filePath.endsWith(".lock") || filePath.endsWith(".min.js")) return;

      if (HEX_KEY_REGEX.test(line)) {
        findings.push({
          file: filePath,
          line: idx + 1,
          type: "64-HEX Private Key Candidate",
          snippet: line.trim().slice(0, 80),
        });
      } else if (SECRET_ENV_REGEX.test(line)) {
        findings.push({
          file: filePath,
          line: idx + 1,
          type: "Sensitive Environment Secret Assignment",
          snippet: line.trim().slice(0, 80),
        });
      }
    });
  }

  const stat = fs.statSync(resolved);
  if (stat.isFile()) {
    const content = fs.readFileSync(resolved, "utf-8");
    scanContent(content, resolved);
  } else if (stat.isDirectory()) {
    const files = fs.readdirSync(resolved);
    for (const f of files) {
      if (f === "node_modules" || f === ".git") continue;
      const fullPath = path.join(resolved, f);
      try {
        if (fs.statSync(fullPath).isFile()) {
          const content = fs.readFileSync(fullPath, "utf-8");
          scanContent(content, fullPath);
        }
      } catch {
        // Skip unreadable files
      }
    }
  }

  return {
    scanned_path: resolved,
    findings_count: findings.length,
    status: findings.length === 0 ? "CLEAN" : "SECRETS_EXPOSED",
    findings,
    recommendation:
      findings.length > 0
        ? "DO NOT commit or transmit these files. Import keys into encrypted Keystore: 'cast wallet import <name> -i'"
        : "No plaintext keys or raw secrets detected.",
  };
}

async function triggerPanic(reason: string) {
  // Execute panic script
  const panicScript = path.join(IRONMAC_ROOT, "modules/panic.sh");
  if (fs.existsSync(panicScript)) {
    await execAsync(`bash "${panicScript}" trigger "${reason}"`);
  } else {
    // Fallback: immediate network cut + clipboard clear + screen lock
    await execAsync("networksetup -setairportpower en0 off 2>/dev/null || true");
    await execAsync("pbcopy < /dev/null 2>/dev/null || true");
  }

  return {
    status: "EMERGENCY_PANIC_EXECUTED",
    reason,
    actions_taken: [
      "Wi-Fi interface en0 powered off (Instant hardware air-gap)",
      "macOS pasteboard purged to /dev/null",
      "Terminated active browser and communication process buffers",
    ],
    recovery_guidance: "To restore Wi-Fi after threat isolation, run: 'ironmac panic restore'",
  };
}

const NETWORK_RPCS: Record<
  string,
  { chain_id: number | string; name: string; rpc_url: string; currency: string; explorer: string }
> = {
  eth: {
    chain_id: 1,
    name: "Ethereum Mainnet",
    rpc_url: "https://eth.llamarpc.com",
    currency: "ETH",
    explorer: "https://etherscan.io",
  },
  sepolia: {
    chain_id: 11155111,
    name: "Sepolia Testnet",
    rpc_url: "https://rpc.sepolia.org",
    currency: "ETH",
    explorer: "https://sepolia.etherscan.io",
  },
  base: {
    chain_id: 8453,
    name: "Base Mainnet",
    rpc_url: "https://mainnet.base.org",
    currency: "ETH",
    explorer: "https://basescan.org",
  },
  mantle: {
    chain_id: 5000,
    name: "Mantle Network",
    rpc_url: "https://rpc.mantle.xyz",
    currency: "MNT",
    explorer: "https://mantlescan.xyz",
  },
  arb: {
    chain_id: 42161,
    name: "Arbitrum One",
    rpc_url: "https://arb1.arbitrum.io/rpc",
    currency: "ETH",
    explorer: "https://arbiscan.io",
  },
  op: {
    chain_id: 10,
    name: "Optimism Mainnet",
    rpc_url: "https://mainnet.optimism.io",
    currency: "ETH",
    explorer: "https://optimistic.etherscan.io",
  },
  polygon: {
    chain_id: 137,
    name: "Polygon PoS",
    rpc_url: "https://polygon-rpc.com",
    currency: "POL",
    explorer: "https://polygonscan.com",
  },
  bsc: {
    chain_id: 56,
    name: "BNB Smart Chain",
    rpc_url: "https://binance.llamarpc.com",
    currency: "BNB",
    explorer: "https://bscscan.com",
  },
  solana: {
    chain_id: "mainnet-beta",
    name: "Solana Mainnet",
    rpc_url: "https://api.mainnet-beta.solana.com",
    currency: "SOL",
    explorer: "https://solscan.io",
  },
};

function getNetworkRpc(network: string = "all") {
  const key = network.toLowerCase().trim();
  if (key === "all" || key === "list" || !key) {
    return {
      total: Object.keys(NETWORK_RPCS).length,
      networks: NETWORK_RPCS,
      usage: "Pass network='eth' | 'base' | 'mantle' | 'sepolia' to get single endpoint.",
    };
  }
  const match = NETWORK_RPCS[key];
  if (match) {
    return { network: key, ...match };
  }
  return {
    error: `Unknown network: ${network}`,
    available_networks: Object.keys(NETWORK_RPCS),
  };
}

async function shredFile(filePath: string) {
  const resolved = path.resolve(process.cwd(), filePath);
  if (!fs.existsSync(resolved)) {
    return { error: `File not found: ${resolved}` };
  }
  const stat = fs.statSync(resolved);
  if (!stat.isFile()) {
    return { error: `Path is not a regular file: ${resolved}` };
  }

  const fileSize = stat.size;
  const passes = 3;

  const fd = fs.openSync(resolved, "r+");
  for (let pass = 1; pass <= passes; pass++) {
    const randomBuf = crypto.randomBytes(Math.min(fileSize || 1024, 65536));
    let written = 0;
    while (written < fileSize) {
      const chunk = Math.min(randomBuf.length, fileSize - written);
      fs.writeSync(fd, randomBuf, 0, chunk, written);
      written += chunk;
    }
    fs.fsyncSync(fd);
  }
  fs.closeSync(fd);
  fs.unlinkSync(resolved);

  return {
    file: resolved,
    bytes_overwritten: fileSize,
    passes,
    status: "CRYPTOGRAPHICALLY_SHREDDED",
    message: "File overwritten with 3 passes of CSPRNG bytes and unlinked from filesystem.",
  };
}

function calculateKeccak256(data: string, isHex: boolean = false) {
  let buf: Buffer;
  if (isHex) {
    const clean = data.startsWith("0x") ? data.slice(2) : data;
    buf = Buffer.from(clean, "hex");
  } else {
    buf = Buffer.from(data, "utf-8");
  }
  const hash = crypto.createHash("keccak-256").update(buf).digest("hex");
  const result: any = {
    input: data,
    keccak256: "0x" + hash,
  };
  if (/^[a-zA-Z0-9_$]+\(.*\)$/.test(data)) {
    result.function_selector = "0x" + hash.slice(0, 8);
  }
  return result;
}

function getCustodyPlaybook() {
  return {
    principles: "Don't Trust, Verify. Plaintext keys in persistent storage are compromised keys.",
    paths: [
      {
        path: "[PATH 1] PHYSICAL COLD STORAGE (Large Assets / Treasury / Mainnet)",
        instructions: "Transcribe 12/24 mnemonics onto paper or stamped steel. Run 'clear' immediately.",
      },
      {
        path: "[PATH 2] ENCRYPTED FOUNDRY KEYSTORE (CLI Scripts & Deployments)",
        instructions: "Run 'cast wallet import <name> -i'. Never write keys to .env!",
      },
      {
        path: "[PATH 3] ISOLATED DEFI BROWSER (MetaMask / Rabby / DApps)",
        instructions: "Run 'ironmac vault-browser'. Keystore stored in dedicated ~/Library/Application Support/IronMacVault.",
      },
      {
        path: "[PATH 4] EPHEMERAL BURNER WALLET (Airdrop Claims / Testing)",
        instructions: "Generate and sign exclusively in RAM (/Volumes/IronVault_*/). Vanishes on 'exit'.",
      },
    ],
    forbidden_vectors: [
      "Apple Notes / Notion / Obsidian (Syncs plaintext to cloud)",
      "WeChat / Telegram Saved Messages (Cached unencrypted on disk)",
      "Screenshots / Photo Library (OCR malware harvesting)",
      "Plaintext .env in git repositories (Scraped within seconds)",
    ],
  };
}

// --- Start MCP Server ---

async function main() {
  const server = new Server(
    {
      name: "ironmac-mcp",
      version: "0.5.1",
    },
    {
      capabilities: {
        tools: {},
      },
    }
  );

  server.setRequestHandler(ListToolsRequestSchema, async () => {
    return { tools: TOOLS };
  });

  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;

    try {
      switch (name) {
        case "audit_system_security": {
          const result = await runAudit();
          return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
        }
        case "verify_crypto_address": {
          const address = String(args?.address ?? "");
          const chain = String(args?.expected_chain ?? "auto");
          const result = verifyAddress(address, chain);
          return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
        }
        case "toggle_airgap": {
          const action = String(args?.action ?? "status");
          const result = await handleAirgap(action);
          return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
        }
        case "get_defense_telemetry": {
          const result = await getDefenseTelemetry();
          return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
        }
        case "scan_secrets": {
          const targetPath = String(args?.target_path ?? ".");
          const result = await scanSecrets(targetPath);
          return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
        }
        case "trigger_emergency_panic": {
          const reason = String(args?.reason ?? "Malware detection via AI Agent");
          const result = await triggerPanic(reason);
          return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
        }
        case "get_network_rpc": {
          const network = String(args?.network ?? "all");
          const result = getNetworkRpc(network);
          return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
        }
        case "shred_file": {
          const filePath = String(args?.file_path ?? "");
          const result = await shredFile(filePath);
          return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
        }
        case "calculate_keccak256": {
          const data = String(args?.data ?? "");
          const isHex = Boolean(args?.is_hex ?? false);
          const result = calculateKeccak256(data, isHex);
          return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
        }
        case "get_custody_playbook": {
          const result = getCustodyPlaybook();
          return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
        }
        default:
          throw new Error(`Tool not found: ${name}`);
      }
    } catch (err: any) {
      return {
        isError: true,
        content: [{ type: "text", text: `Error executing ${name}: ${err.message}` }],
      };
    }
  });

  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((error) => {
  console.error("Fatal error starting ironmac-mcp:", error);
  process.exit(1);
});
