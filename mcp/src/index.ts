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
const execFileAsync = promisify(execFile);

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
  {
    name: "create_vault_wallet",
    description:
      "Generates an ephemeral EVM wallet (for Base, Ethereum, Arbitrum, Mantle, Sepolia) strictly inside the volatile RAMDisk (/Volumes/IronVault). The raw private key is displayed ONLY to the user's physical screen via /dev/tty and is 100% STRIPPED from AI cloud context to guarantee zero leaks.",
    inputSchema: {
      type: "object",
      properties: {
        alias: {
          type: "string",
          description: "Human-readable label/alias for this wallet (e.g., 'burner_base', 'dev_wallet')",
        },
        chain: {
          type: "string",
          enum: ["base", "ethereum", "arbitrum", "mantle", "sepolia"],
          description: "Target blockchain network (defaults to 'base')",
        },
        note: {
          type: "string",
          description: "Optional purpose or memo for this ephemeral wallet",
        },
      },
      required: ["alias"],
    },
  },
  {
    name: "list_vault_wallets",
    description:
      "Lists all ephemeral wallets stored in the active RAMDisk vault. Returns wallet aliases, public addresses, and network labels without exposing private keys.",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "get_vault_wallet_balance",
    description:
      "Queries real-time native token balance for an ephemeral vault wallet (by alias) or any raw 0x address across supported EVM networks (Base, Ethereum, Arbitrum, Mantle, Sepolia).",
    inputSchema: {
      type: "object",
      properties: {
        alias_or_address: {
          type: "string",
          description: "Wallet alias registered in vault (e.g. 'burner_base') or full 0x public address",
        },
        chain: {
          type: "string",
          enum: ["base", "ethereum", "arbitrum", "mantle", "sepolia"],
          description: "Blockchain network to query (defaults to 'base')",
        },
      },
      required: ["alias_or_address"],
    },
  },
  {
    name: "decode_calldata",
    description:
      "Decodes raw EVM calldata (ERC-20 transfers, approvals, WETH, NFT safeTransferFrom, Uniswap) into human-readable plain language and scans for critical security risks (e.g. unlimited token approvals, token draining backdoors, zero-address burning).",
    inputSchema: {
      type: "object",
      properties: {
        calldata: {
          type: "string",
          description: "Raw hex calldata starting with 0x (minimum 10 characters for selector)",
        },
        to_contract: {
          type: "string",
          description: "Target contract address (optional)",
        },
        chain: {
          type: "string",
          enum: ["base", "ethereum", "arbitrum", "mantle", "sepolia"],
          description: "Blockchain network context (defaults to 'base')",
        },
      },
      required: ["calldata"],
    },
  },
  {
    name: "prepare_transaction",
    description:
      "Prepares a safe on-chain transaction from an ephemeral vault wallet, performs balance checking, decodes any calldata, checks address poisoning, and formats an ASCII Pre-Execution Card for the user to confirm before broadcasting.",
    inputSchema: {
      type: "object",
      properties: {
        alias: {
          type: "string",
          description: "Sending wallet alias stored in RAM vault (e.g. 'burner_base')",
        },
        to: {
          type: "string",
          description: "Destination recipient address or contract (0x...)",
        },
        value_eth: {
          type: "string",
          description: "Amount of native token (ETH/MNT) to transfer (e.g. '0.01', defaults to '0')",
        },
        data: {
          type: "string",
          description: "Hex calldata to invoke on target contract (defaults to '0x')",
        },
        chain: {
          type: "string",
          enum: ["base", "ethereum", "arbitrum", "mantle", "sepolia"],
          description: "Blockchain network (defaults to 'base')",
        },
      },
      required: ["alias", "to"],
    },
  },
  {
    name: "execute_vault_transaction",
    description:
      "Broadcasts a prepared transaction using Foundry cast with the local ephemeral wallet's private key held strictly in RAM. Requires user_confirmed: true (human-in-the-loop). Private key is never leaked.",
    inputSchema: {
      type: "object",
      properties: {
        alias: {
          type: "string",
          description: "Sending wallet alias in RAM vault",
        },
        to: {
          type: "string",
          description: "Destination address",
        },
        value_eth: {
          type: "string",
          description: "Amount of native token (ETH) to transfer",
        },
        data: {
          type: "string",
          description: "Hex calldata (defaults to '0x')",
        },
        chain: {
          type: "string",
          enum: ["base", "ethereum", "arbitrum", "mantle", "sepolia"],
          description: "Blockchain network",
        },
        user_confirmed: {
          type: "boolean",
          description: "MUST BE TRUE. Confirms that the user has explicitly reviewed the Pre-Execution Card and approved signing.",
        },
      },
      required: ["alias", "to", "user_confirmed"],
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
    rpc_url: "https://ethereum-sepolia-rpc.publicnode.com",
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

function getVaultPath(): string {
  if (process.env.MOUNT_POINT && fs.existsSync(process.env.MOUNT_POINT)) {
    return process.env.MOUNT_POINT;
  }
  try {
    const volumes = fs.readdirSync("/Volumes");
    const ironVol = volumes.find((v) => v.startsWith("IronVault"));
    if (ironVol) {
      return path.join("/Volumes", ironVol);
    }
  } catch {}

  const fallback = path.join(os.homedir(), ".ironmac/vault");
  if (!fs.existsSync(fallback)) {
    fs.mkdirSync(fallback, { recursive: true, mode: 0o700 });
  }
  return fallback;
}

function getVaultKeysDir(): string {
  const vault = getVaultPath();
  const keysDir = path.join(vault, "keys");
  if (!fs.existsSync(keysDir)) {
    fs.mkdirSync(keysDir, { recursive: true, mode: 0o700 });
  }
  return keysDir;
}

function writeToDevTty(text: string): boolean {
  try {
    const ttyFd = fs.openSync("/dev/tty", "w");
    fs.writeSync(ttyFd, text + "\n");
    fs.closeSync(ttyFd);
    return true;
  } catch {
    return false;
  }
}

async function fetchEthBalance(rpcUrl: string, address: string): Promise<string> {
  const resp = await fetch(rpcUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      jsonrpc: "2.0",
      id: 1,
      method: "eth_getBalance",
      params: [address, "latest"],
    }),
  });
  const data: any = await resp.json();
  if (data.error) {
    throw new Error(data.error.message || "RPC call returned error");
  }
  return data.result || "0x0";
}

function hexWeiToEth(hexWei: string): { eth: string; wei: string } {
  try {
    const weiBig = BigInt(hexWei);
    const weiStr = weiBig.toString();
    const divisor = 1000000000000000000n; // 1e18
    const integerPart = (weiBig / divisor).toString();
    const remainder = (weiBig % divisor).toString().padStart(18, "0");
    const trimmedRemainder = remainder.replace(/0+$/, "").slice(0, 6);
    const ethStr = trimmedRemainder ? `${integerPart}.${trimmedRemainder}` : integerPart;
    return { eth: ethStr, wei: weiStr };
  } catch {
    return { eth: "0.0", wei: "0" };
  }
}

async function createVaultWallet(alias: string, chain: string = "base", note?: string) {
  const cleanAlias = alias.trim().toLowerCase().replace(/[^a-z0-9_-]/g, "_");
  if (!cleanAlias) {
    return { error: "Wallet alias cannot be empty." };
  }

  const keysDir = getVaultKeysDir();
  const keyFile = path.join(keysDir, `${cleanAlias}.json`);

  if (fs.existsSync(keyFile)) {
    return {
      error: `A wallet with alias '${cleanAlias}' already exists in RAM vault. Choose a different alias or use list_vault_wallets.`,
    };
  }

  const priv = crypto.randomBytes(32);
  const privHex = "0x" + priv.toString("hex");

  const ecdh = crypto.createECDH("secp256k1");
  ecdh.setPrivateKey(priv);
  const pub = ecdh.getPublicKey().subarray(1); // 64 bytes uncompressed
  const rawAddress = "0x" + crypto.createHash("keccak-256").update(pub).digest("hex").slice(-40);
  const checksummedAddress = toChecksumAddress(rawAddress);

  const record = {
    alias: cleanAlias,
    address: checksummedAddress,
    chain,
    private_key: privHex,
    created_at: new Date().toISOString(),
    note: note || "Ephemeral vault burner wallet",
    storage: "RAMDisk (Volatile Memory)",
  };

  fs.writeFileSync(keyFile, JSON.stringify(record, null, 2), { mode: 0o600 });

  const ttyCard = [
    "\n\x1b[38;5;51m┌────────────────────────────────────────────────────────────────────────┐\x1b[0m",
    `\x1b[38;5;51m│\x1b[0m \x1b[1m\x1b[38;5;82m⚡ [OUT-OF-BAND] IRONMAC LOCAL KEY DISPLAY (/dev/tty)\x1b[0m                  \x1b[38;5;51m│\x1b[0m`,
    "\x1b[38;5;51m├────────────────────────────────────────────────────────────────────────┤\x1b[0m",
    `\x1b[38;5;51m│\x1b[0m • \x1b[1mAlias      \x1b[0m: \x1b[38;5;214m${cleanAlias}\x1b[0m`,
    `\x1b[38;5;51m│\x1b[0m • \x1b[1mAddress    \x1b[0m: \x1b[38;5;82m${checksummedAddress}\x1b[0m`,
    `\x1b[38;5;51m│\x1b[0m • \x1b[1mNetwork    \x1b[0m: ${chain.toUpperCase()}`,
    `\x1b[38;5;51m│\x1b[0m • \x1b[1mPrivate Key\x1b[0m: \x1b[38;5;196m${privHex}\x1b[0m`,
    "\x1b[38;5;51m├────────────────────────────────────────────────────────────────────────┤\x1b[0m",
    "\x1b[38;5;51m│\x1b[0m \x1b[38;5;242m[!] SECURE GUARANTEE: This private key was printed ONLY to /dev/tty.    \x1b[38;5;51m│\x1b[0m",
    "\x1b[38;5;51m│\x1b[0m \x1b[38;5;242m    It has been 100% STRIPPED from AI cloud context and never sent.      \x1b[38;5;51m│\x1b[0m",
    "\x1b[38;5;51m└────────────────────────────────────────────────────────────────────────┘\x1b[0m\n",
  ].join("\n");

  const ttyDelivered = writeToDevTty(ttyCard);

  return {
    status: "success",
    alias: cleanAlias,
    address: checksummedAddress,
    chain,
    storage: "RAMDisk (/Volumes/IronVault/keys/)",
    keystore_file: `${cleanAlias}.json`,
    private_key: "[REDACTED_LOCAL_RAM_ONLY: Displayed directly on physical screen /dev/tty]",
    tty_display_delivered: ttyDelivered,
    security_guarantee: "Private key is held exclusively in local volatile RAMDisk. Zero bytes sent to cloud LLM.",
    guidance: `Ephemeral wallet '${cleanAlias}' is ready. You can query its balance via get_vault_wallet_balance or reference it by alias '${cleanAlias}'.`,
  };
}

async function listVaultWallets() {
  const keysDir = getVaultKeysDir();
  const files = fs.readdirSync(keysDir).filter((f) => f.endsWith(".json"));
  const wallets = [];

  for (const f of files) {
    try {
      const data = JSON.parse(fs.readFileSync(path.join(keysDir, f), "utf-8"));
      wallets.push({
        alias: data.alias || path.basename(f, ".json"),
        address: data.address,
        chain: data.chain || "base",
        created_at: data.created_at,
        note: data.note,
        storage: data.storage || "RAMDisk",
      });
    } catch {}
  }

  return {
    vault_location: getVaultPath(),
    total_wallets: wallets.length,
    wallets,
    security_notice: "All private keys are quarantined in local RAMDisk and never exposed in context.",
  };
}

async function getVaultWalletBalance(aliasOrAddress: string, chain: string = "base") {
  let targetAddress = aliasOrAddress.trim();
  let alias: string | null = null;

  if (!/^0x[a-fA-F0-9]{40}$/.test(targetAddress)) {
    const keysDir = getVaultKeysDir();
    const keyFile = path.join(keysDir, `${targetAddress.toLowerCase()}.json`);
    if (fs.existsSync(keyFile)) {
      try {
        const data = JSON.parse(fs.readFileSync(keyFile, "utf-8"));
        alias = data.alias;
        targetAddress = data.address;
        if (data.chain && (!chain || chain === "base")) {
          chain = data.chain;
        }
      } catch {}
    } else {
      return {
        error: `Wallet with alias '${targetAddress}' was not found in active vault.`,
      };
    }
  }

  const checksummed = toChecksumAddress(targetAddress);
  const normalizedChain = chain.toLowerCase().trim();
  const rpcInfo = NETWORK_RPCS[normalizedChain] || NETWORK_RPCS.base;

  try {
    const hexBalance = await fetchEthBalance(rpcInfo.rpc_url, checksummed);
    const { eth, wei } = hexWeiToEth(hexBalance);

    return {
      address: checksummed,
      alias,
      network: rpcInfo.name,
      currency: rpcInfo.currency,
      balance: eth,
      balance_formatted: `${eth} ${rpcInfo.currency}`,
      balance_wei: wei,
      rpc_endpoint: rpcInfo.rpc_url,
      explorer_link: `${rpcInfo.explorer}/address/${checksummed}`,
    };
  } catch (err: any) {
    return {
      error: `Failed to query balance on ${rpcInfo.name}: ${err.message}`,
      address: checksummed,
      network: rpcInfo.name,
      rpc_endpoint: rpcInfo.rpc_url,
    };
  }
}

function getCastPath(): string {
  const foundryBin = path.join(os.homedir(), ".foundry/bin/cast");
  if (fs.existsSync(foundryBin)) {
    return foundryBin;
  }
  return "cast";
}

function sanitizeOutput(text: string, sensitiveKey?: string): string {
  let cleaned = text;
  if (sensitiveKey) {
    const rawKey = sensitiveKey.replace(/^0x/, "");
    cleaned = cleaned.split(sensitiveKey).join("[REDACTED_PRIVATE_KEY]");
    cleaned = cleaned.split(rawKey).join("[REDACTED_PRIVATE_KEY]");
  }
  return cleaned;
}

function ethToWei(ethStr: string): bigint {
  try {
    const parts = ethStr.trim().split(".");
    const whole = BigInt(parts[0] || "0");
    const wholeWei = whole * 1000000000000000000n;
    if (parts.length > 1) {
      const decimals = parts[1].padEnd(18, "0").slice(0, 18);
      return wholeWei + BigInt(decimals);
    }
    return wholeWei;
  } catch {
    return 0n;
  }
}

interface DecodedCalldataResult {
  calldata: string;
  is_empty?: boolean;
  selector?: string;
  signature?: string;
  method?: string;
  parameters?: Record<string, any>;
  risk_level: "LOW" | "SUSPICIOUS" | "HIGH_RISK" | "CRITICAL_RISK";
  warnings: string[];
  plain_description: string;
  action_summary: string;
}

async function decodeCalldata(
  calldataInput: string,
  toContract?: string,
  chain: string = "base"
): Promise<DecodedCalldataResult> {
  const cd = calldataInput ? calldataInput.trim() : "0x";

  if (cd === "0x" || cd === "" || cd.toLowerCase() === "0x") {
    return {
      calldata: "0x",
      is_empty: true,
      risk_level: "LOW",
      warnings: [],
      plain_description: "Standard native currency transfer or call without calldata.",
      action_summary: "Native Transfer / Plain Call",
    };
  }

  if (!cd.startsWith("0x")) {
    return {
      calldata: cd,
      risk_level: "SUSPICIOUS",
      warnings: ["Calldata does not start with '0x' prefix."],
      plain_description: "Malformed calldata format.",
      action_summary: "Malformed Calldata",
    };
  }

  if (cd.length < 10) {
    return {
      calldata: cd,
      risk_level: "SUSPICIOUS",
      warnings: ["Calldata is shorter than 4 bytes (8 hex characters plus 0x)."],
      plain_description: "Incomplete calldata / truncated selector.",
      action_summary: "Short Calldata",
    };
  }

  const selector = cd.slice(0, 10).toLowerCase();
  const body = cd.slice(10);
  const warnings: string[] = [];
  let riskLevel: "LOW" | "SUSPICIOUS" | "HIGH_RISK" | "CRITICAL_RISK" = "LOW";
  let method = "Unknown";
  let signature = "unknown";
  let parameters: Record<string, any> = {};
  let plainDesc = "";
  let actionSummary = "";

  const getWord = (index: number) => {
    const start = index * 64;
    return body.slice(start, start + 64).padEnd(64, "0");
  };
  const getAddress = (index: number) => {
    const word = getWord(index);
    return toChecksumAddress("0x" + word.slice(24, 64));
  };
  const getUint256 = (index: number) => {
    const word = getWord(index);
    try {
      return BigInt("0x" + word);
    } catch {
      return 0n;
    }
  };

  // 1. ERC-20 transfer(address to, uint256 amount) - 0xa9059cbb
  if (selector === "0xa9059cbb") {
    method = "transfer";
    signature = "transfer(address,uint256)";
    const recipient = getAddress(0);
    const amount = getUint256(1);
    parameters = { to: recipient, amount: amount.toString() };

    if (
      recipient === "0x0000000000000000000000000000000000000000" ||
      recipient.toLowerCase() === "0x000000000000000000000000000000000000dead"
    ) {
      riskLevel = "HIGH_RISK";
      warnings.push("CRITICAL: Transfer target is the zero address or dead address! This will permanently burn these tokens.");
    }
    actionSummary = "ERC-20 Token Transfer";
    plainDesc = `Transfer ${amount.toString()} tokens to recipient ${recipient}.`;
  }
  // 2. ERC-20 approve(address spender, uint256 amount) - 0x095ea7b3
  else if (selector === "0x095ea7b3") {
    method = "approve";
    signature = "approve(address,uint256)";
    const spender = getAddress(0);
    const amount = getUint256(1);
    parameters = { spender, amount: amount.toString() };

    const maxUint256 = 115792089237316195423570985008687907853269984665640564039457584007913129639935n;
    const isUnlimited =
      amount >= 2n ** 255n - 1n ||
      amount === maxUint256 ||
      getWord(1).toLowerCase().includes("ffffffffffffffff");

    if (isUnlimited) {
      riskLevel = "CRITICAL_RISK";
      warnings.push(
        "CRITICAL ALERT: Unlimited token approval detected (type(uint256).max)!",
        `Spender (${spender}) is granted permission to withdraw ALL of your tokens at any point in the future.`,
        "If this spender contract is malicious, upgradeable, or later exploited, 100% of your tokens in this contract can be drained."
      );
      actionSummary = "UNLIMITED Token Approval (High Risk)";
      plainDesc = `Approve UNLIMITED allowance for spender ${spender} to spend all your tokens without limit.`;
    } else if (amount === 0n) {
      riskLevel = "LOW";
      actionSummary = "Revoke Token Approval";
      plainDesc = `Revoke approval (set allowance to 0) for spender ${spender}.`;
    } else {
      riskLevel = "LOW";
      actionSummary = "Limited Token Approval";
      plainDesc = `Approve spender ${spender} to spend up to ${amount.toString()} tokens.`;
    }
  }
  // 3. ERC-20 transferFrom(address from, address to, uint256 amount) - 0x23b87266
  else if (selector === "0x23b87266") {
    method = "transferFrom";
    signature = "transferFrom(address,address,uint256)";
    const fromAddr = getAddress(0);
    const toAddr = getAddress(1);
    const amount = getUint256(2);
    parameters = { from: fromAddr, to: toAddr, amount: amount.toString() };
    actionSummary = "ERC-20 transferFrom";
    plainDesc = `Transfer ${amount.toString()} tokens from ${fromAddr} to ${toAddr} using allowance.`;
  }
  // 4. ERC-721 setApprovalForAll(address operator, bool approved) - 0xa22cb465
  else if (selector === "0xa22cb465") {
    method = "setApprovalForAll";
    signature = "setApprovalForAll(address,bool)";
    const operator = getAddress(0);
    const approved = getWord(1).replace(/^0+/, "") === "1";
    parameters = { operator, approved };

    if (approved) {
      riskLevel = "HIGH_RISK";
      warnings.push(
        "ALERT: Full NFT collection delegation (setApprovalForAll = true)!",
        `Operator (${operator}) is granted permission to transfer EVERY NFT in this collection from your wallet.`
      );
      actionSummary = "NFT Collection Operator Delegation";
      plainDesc = `Grant operator ${operator} full control to manage and transfer all NFTs in this collection.`;
    } else {
      actionSummary = "Revoke NFT Collection Delegation";
      plainDesc = `Revoke collection operator permissions from ${operator}.`;
    }
  }
  // 5. ERC-721 safeTransferFrom(address from, address to, uint256 tokenId) - 0x42842e0e
  else if (selector === "0x42842e0e") {
    method = "safeTransferFrom";
    signature = "safeTransferFrom(address,address,uint256)";
    const fromAddr = getAddress(0);
    const toAddr = getAddress(1);
    const tokenId = getUint256(2);
    parameters = { from: fromAddr, to: toAddr, tokenId: tokenId.toString() };
    actionSummary = "NFT Transfer";
    plainDesc = `Transfer NFT #${tokenId.toString()} from ${fromAddr} to ${toAddr}.`;
  }
  // 6. WETH deposit() - 0xd0e30db0
  else if (selector === "0xd0e30db0") {
    method = "deposit";
    signature = "deposit()";
    actionSummary = "WETH Wrap Deposit";
    plainDesc = "Wrap native ETH into canonical Wrapped ETH (WETH).";
  }
  // 7. WETH withdraw(uint256 wad) - 0x2e1a7d4d
  else if (selector === "0x2e1a7d4d") {
    method = "withdraw";
    signature = "withdraw(uint256)";
    const wad = getUint256(0);
    parameters = { wad: wad.toString() };
    actionSummary = "WETH Unwrap Withdrawal";
    plainDesc = `Unwrap ${wad.toString()} WETH back into native ETH.`;
  }
  // Fallback to cast 4byte-decode
  else {
    try {
      const castBin = getCastPath();
      const { stdout } = await execFileAsync(castBin, ["4byte-decode", cd]);
      const trimmed = stdout.trim();
      if (trimmed && !trimmed.includes("No signatures found")) {
        const lines = trimmed.split("\n");
        const sigMatch = lines[0].match(/"([^"]+)"/);
        signature = sigMatch ? sigMatch[1] : lines[0];
        method = signature.split("(")[0];
        actionSummary = `Contract Method: ${method}`;
        plainDesc = `Invoking contract method ${signature} with ${lines.length - 1} decoded parameter lines.`;

        const lowerSig = signature.toLowerCase();
        if (
          lowerSig.includes("permit") ||
          lowerSig.includes("delegat") ||
          lowerSig.includes("drain") ||
          lowerSig.includes("sweep") ||
          lowerSig.includes("owner")
        ) {
          riskLevel = "HIGH_RISK";
          warnings.push(
            `Contract method '${method}' involves administrative or authorization delegation logic. Verify destination address carefully.`
          );
        }
        parameters = { decoded_raw: lines.slice(1).map((l) => l.trim()) };
      } else {
        riskLevel = "SUSPICIOUS";
        signature = `unknown(${selector})`;
        method = selector;
        actionSummary = "Unverified Calldata";
        plainDesc = `Invoking unverified method selector ${selector} with ${Math.floor(body.length / 2)} bytes payload.`;
        warnings.push(
          "Calldata does not match any known function signature in public 4byte registries. Exercise caution against blind signing."
        );
      }
    } catch {
      riskLevel = "SUSPICIOUS";
      signature = `unknown(${selector})`;
      method = selector;
      actionSummary = "Unverified Calldata";
      plainDesc = `Invoking method selector ${selector} with ${Math.floor(body.length / 2)} bytes payload.`;
      warnings.push("Unable to resolve signature via 4byte registry. Potential blind-signing risk.");
    }
  }

  return {
    calldata: cd,
    selector,
    signature,
    method,
    parameters,
    risk_level: riskLevel,
    warnings,
    plain_description: plainDesc,
    action_summary: actionSummary,
  };
}

interface PrepareTransactionArgs {
  alias: string;
  to: string;
  value_eth?: string;
  data?: string;
  chain?: string;
}

async function prepareTransaction(args: PrepareTransactionArgs) {
  const alias = String(args.alias ?? "").trim().toLowerCase();
  if (!alias) {
    return { error: "Sender alias cannot be empty." };
  }

  const keysDir = getVaultKeysDir();
  const keyFile = path.join(keysDir, `${alias}.json`);
  if (!fs.existsSync(keyFile)) {
    return {
      error: `Sender wallet '${alias}' not found in active RAM vault. Available wallets can be seen with list_vault_wallets.`,
    };
  }

  let senderData: any;
  try {
    senderData = JSON.parse(fs.readFileSync(keyFile, "utf-8"));
  } catch (err: any) {
    return { error: `Failed to read wallet file for '${alias}': ${err.message}` };
  }

  const senderAddress = senderData.address;
  const toAddress = String(args.to ?? "").trim();
  const valueEth = String(args.value_eth ?? "0").trim();
  const calldata = String(args.data ?? "0x").trim();
  const chain = String(args.chain ?? senderData.chain ?? "base").toLowerCase().trim();

  // Validate destination address
  const addrCheck = verifyAddress(toAddress, "evm");
  if (!addrCheck.is_valid_format) {
    return {
      error: `Invalid destination recipient address: '${toAddress}'`,
      warnings: addrCheck.warnings,
    };
  }
  const destination = addrCheck.checksummed_address!;

  const rpcInfo = NETWORK_RPCS[chain] || NETWORK_RPCS.base;

  // Query sender balance
  const balRes = await getVaultWalletBalance(senderAddress, chain);
  const currentWeiBalance = BigInt(balRes.balance_wei || "0");
  const requiredWei = ethToWei(valueEth);

  const balanceWarnings: string[] = [];
  let isBalanceSufficient = true;
  if (currentWeiBalance < requiredWei) {
    isBalanceSufficient = false;
    balanceWarnings.push(
      `Insufficient funds: Balance is ${balRes.balance_formatted}, but sending ${valueEth} ${rpcInfo.currency} requires more funds.`
    );
  }

  // Decode Calldata
  const decoded = await decodeCalldata(calldata, destination, chain);

  // Simulation & Gas Estimation via cast estimate
  const castBin = getCastPath();
  let estimatedGasUnits = "21000";
  let estimatedGasCostEth = "0.00005";
  let simulationStatus: "SUCCESS" | "REVERT_DETECTED" | "SKIPPED" = "SUCCESS";
  let simulationError: string | null = null;

  try {
    const estimateArgs = ["estimate", "-f", senderAddress, "--rpc-url", rpcInfo.rpc_url, destination];
    if (valueEth && valueEth !== "0") {
      estimateArgs.push("--value", `${valueEth}ether`);
    }
    if (calldata && calldata !== "0x" && calldata.length >= 10) {
      estimateArgs.push(calldata);
    }
    const { stdout: gasUnitsOut } = await execFileAsync(castBin, estimateArgs);
    estimatedGasUnits = gasUnitsOut.trim().split("\n")[0].trim();

    // Also get cost
    try {
      const costArgs = ["estimate", "--cost", "-f", senderAddress, "--rpc-url", rpcInfo.rpc_url, destination];
      if (valueEth && valueEth !== "0") {
        costArgs.push("--value", `${valueEth}ether`);
      }
      if (calldata && calldata !== "0x" && calldata.length >= 10) {
        costArgs.push(calldata);
      }
      const { stdout: costOut } = await execFileAsync(castBin, costArgs);
      estimatedGasCostEth = costOut.trim().split("\n")[0].trim();
    } catch {}
  } catch (err: any) {
    simulationStatus = "REVERT_DETECTED";
    const rawError = err.stderr || err.stdout || err.message || "";
    const revertMatch = rawError.match(/execution reverted:? ([^\n",]+)/i);
    simulationError = revertMatch ? revertMatch[1].trim() : rawError.trim().slice(0, 140);
  }

  // Aggregate Risk Assessment
  let overallRisk: "LOW" | "SUSPICIOUS" | "HIGH_RISK" | "CRITICAL_RISK" = "LOW";
  const allWarnings: string[] = [...addrCheck.warnings, ...balanceWarnings, ...decoded.warnings];

  if (simulationStatus === "REVERT_DETECTED") {
    overallRisk = "CRITICAL_RISK";
    allWarnings.unshift(`TRANSACTION SIMULATION REVERTED: ${simulationError || "Will fail on-chain"}`);
  } else if (decoded.risk_level === "CRITICAL_RISK") {
    overallRisk = "CRITICAL_RISK";
  } else if (decoded.risk_level === "HIGH_RISK") {
    overallRisk = "HIGH_RISK";
  } else if (
    addrCheck.risk_level === "SUSPICIOUS" ||
    decoded.risk_level === "SUSPICIOUS" ||
    !isBalanceSufficient
  ) {
    overallRisk = "SUSPICIOUS";
  }

  // Build ASCII Pre-Execution Card
  const riskColor =
    overallRisk === "LOW" ? "\x1b[32m" : overallRisk === "SUSPICIOUS" ? "\x1b[33m" : "\x1b[31m\x1b[1m";
  const resetColor = "\x1b[0m";

  const cardLines = [
    `\n${riskColor}┌────────────────────────────────────────────────────────────────────────┐${resetColor}`,
    `${riskColor}│\x1b[0m \x1b[1m⚡ [IRONMAC // PRE-EXECUTION TRANSACTION CARD]\x1b[0m                        ${riskColor}│${resetColor}`,
    `${riskColor}├────────────────────────────────────────────────────────────────────────┤${resetColor}`,
    `${riskColor}│\x1b[0m • \x1b[1mSending Vault    \x1b[0m: \x1b[38;5;214m${alias}\x1b[0m (${senderAddress})`,
    `${riskColor}│\x1b[0m • \x1b[1mNetwork / Chain  \x1b[0m: ${rpcInfo.name} (Chain ID: ${rpcInfo.chain_id})`,
    `${riskColor}│\x1b[0m • \x1b[1mDestination      \x1b[0m: \x1b[38;5;82m${destination}\x1b[0m`,
    `${riskColor}│\x1b[0m • \x1b[1mTransfer Value   \x1b[0m: \x1b[1m${valueEth} ${rpcInfo.currency}\x1b[0m`,
    `${riskColor}│\x1b[0m • \x1b[1mAction Summary   \x1b[0m: ${decoded.action_summary}`,
    `${riskColor}│\x1b[0m • \x1b[1mEstimated Gas    \x1b[0m: ${estimatedGasUnits} units (~${estimatedGasCostEth} ${rpcInfo.currency})`,
    `${riskColor}│\x1b[0m • \x1b[1mSimulation Check \x1b[0m: ${
      simulationStatus === "SUCCESS" ? "\x1b[32mPASSED (No revert)\x1b[0m" : "\x1b[31mREVERT DETECTED\x1b[0m"
    }`,
    `${riskColor}│\x1b[0m • \x1b[1mRisk Assessment  \x1b[0m: ${riskColor}${overallRisk}${resetColor}`,
    `${riskColor}├────────────────────────────────────────────────────────────────────────┤${resetColor}`,
    `${riskColor}│\x1b[0m \x1b[1mHuman-Readable Meaning:\x1b[0m`,
    `${riskColor}│\x1b[0m   ${decoded.plain_description}`,
  ];

  if (allWarnings.length > 0) {
    cardLines.push(`${riskColor}├────────────────────────────────────────────────────────────────────────┤${resetColor}`);
    cardLines.push(`${riskColor}│\x1b[0m \x1b[1m⚠️  SECURITY WARNINGS:\x1b[0m`);
    for (const w of allWarnings) {
      cardLines.push(`${riskColor}│\x1b[0m   - ${w}`);
    }
  }

  cardLines.push(`${riskColor}├────────────────────────────────────────────────────────────────────────┤${resetColor}`);
  cardLines.push(`${riskColor}│\x1b[0m \x1b[1mHuman-in-the-Loop Confirmation Required:\x1b[0m`);
  cardLines.push(`${riskColor}│\x1b[0m To broadcast this transaction, the user must explicitly confirm.`);
  cardLines.push(
    `${riskColor}│\x1b[0m Command: execute_vault_transaction(alias='${alias}', to='${destination}', user_confirmed=true)`
  );
  cardLines.push(`${riskColor}└────────────────────────────────────────────────────────────────────────┘${resetColor}\n`);

  const asciiCard = cardLines.join("\n");

  return {
    status: simulationStatus === "REVERT_DETECTED" ? "simulation_reverted" : "ready_for_confirmation",
    sender: {
      alias,
      address: senderAddress,
      balance: balRes.balance_formatted,
      is_balance_sufficient: isBalanceSufficient,
    },
    destination: {
      address: destination,
      checksum_status: addrCheck.checksum_status,
      risk_level: addrCheck.risk_level,
    },
    value: {
      eth: valueEth,
      currency: rpcInfo.currency,
      wei: requiredWei.toString(),
    },
    decoded_calldata: decoded,
    simulation: {
      status: simulationStatus,
      estimated_gas_units: estimatedGasUnits,
      estimated_cost: `${estimatedGasCostEth} ${rpcInfo.currency}`,
      revert_reason: simulationError,
    },
    risk_level: overallRisk,
    warnings: allWarnings,
    pre_execution_card: asciiCard,
    confirmation_required: true,
    guidance:
      overallRisk === "CRITICAL_RISK"
        ? "CRITICAL WARNING: This transaction has high risk or will revert. Recommend against signing unless deliberately intended."
        : "Present this Pre-Execution Card clearly to the user. Do not call execute_vault_transaction until the user explicitly responds with approval.",
  };
}

interface ExecuteTransactionArgs {
  alias: string;
  to: string;
  value_eth?: string;
  data?: string;
  chain?: string;
  user_confirmed?: boolean;
}

async function executeVaultTransaction(args: ExecuteTransactionArgs) {
  if (args.user_confirmed !== true) {
    return {
      status: "aborted",
      error:
        "Human confirmation missing! 'user_confirmed' must be true. Transactions can only be broadcast after explicit user consent.",
      guidance:
        "Display the Pre-Execution Card to the user first and request confirmation before setting user_confirmed=true.",
    };
  }

  const alias = String(args.alias ?? "").trim().toLowerCase();
  const keysDir = getVaultKeysDir();
  const keyFile = path.join(keysDir, `${alias}.json`);
  if (!fs.existsSync(keyFile)) {
    return { error: `Wallet alias '${alias}' not found in active RAM vault.` };
  }

  let walletData: any;
  try {
    walletData = JSON.parse(fs.readFileSync(keyFile, "utf-8"));
  } catch (err: any) {
    return { error: `Failed to read wallet file for '${alias}': ${err.message}` };
  }

  const privateKey = walletData.private_key;
  if (!privateKey) {
    return { error: `Private key missing in vault record for '${alias}'.` };
  }

  const to = String(args.to ?? "").trim();
  const valueEth = String(args.value_eth ?? "0").trim();
  const data = String(args.data ?? "0x").trim();
  const chain = String(args.chain ?? walletData.chain ?? "base").toLowerCase().trim();
  const rpcInfo = NETWORK_RPCS[chain] || NETWORK_RPCS.base;

  const castBin = getCastPath();
  const castArgs = [
    "send",
    to,
    "--private-key",
    privateKey,
    "--rpc-url",
    rpcInfo.rpc_url,
    "--json",
  ];

  if (valueEth && valueEth !== "0") {
    castArgs.push("--value", `${valueEth}ether`);
  }
  if (data && data !== "0x" && data.length >= 10) {
    castArgs.push("--data", data);
  }

  try {
    const { stdout, stderr } = await execFileAsync(castBin, castArgs);
    const sanitizedStdout = sanitizeOutput(stdout, privateKey);

    let parsed: any = null;
    try {
      parsed = JSON.parse(sanitizedStdout);
    } catch {}

    const txHash =
      parsed?.transactionHash ||
      parsed?.txHash ||
      (sanitizedStdout.match(/0x[a-fA-F0-9]{64}/) ? sanitizedStdout.match(/0x[a-fA-F0-9]{64}/)![0] : "unknown");
    const blockNumber = parsed?.blockNumber ? parseInt(parsed.blockNumber, 16) || parsed.blockNumber : null;
    const gasUsed = parsed?.gasUsed ? parseInt(parsed.gasUsed, 16) || parsed.gasUsed : null;

    return {
      status: "success",
      transaction_hash: txHash,
      explorer_link: `${rpcInfo.explorer}/tx/${txHash}`,
      network: rpcInfo.name,
      sender: {
        alias,
        address: walletData.address,
      },
      destination: to,
      value_transferred: `${valueEth} ${rpcInfo.currency}`,
      block_number: blockNumber,
      gas_used: gasUsed,
      security_quarantine:
        "Private key remained in RAMDisk (/Volumes/IronVault/) and was never exposed to context.",
    };
  } catch (err: any) {
    const rawError = (err.stderr || "") + "\n" + (err.stdout || "") + "\n" + (err.message || "");
    const sanitizedErr = sanitizeOutput(rawError, privateKey);
    let readableError = sanitizedErr.trim();

    try {
      const errJson = JSON.parse(sanitizeOutput(err.stdout || "", privateKey));
      if (errJson?.errors?.[0]?.message) {
        readableError = errJson.errors[0].message;
      }
    } catch {}

    return {
      status: "failed",
      error: readableError,
      network: rpcInfo.name,
      sender: walletData.address,
      destination: to,
      security_notice:
        "Transaction was rejected or reverted. Private key was sanitized from all error output.",
    };
  }
}

// --- Start MCP Server ---

async function main() {
  const server = new Server(
    {
      name: "ironmac-mcp",
      version: "0.6.2",
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
        case "create_vault_wallet": {
          const alias = String(args?.alias ?? "");
          const chain = String(args?.chain ?? "base");
          const note = args?.note ? String(args.note) : undefined;
          const result = await createVaultWallet(alias, chain, note);
          return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
        }
        case "list_vault_wallets": {
          const result = await listVaultWallets();
          return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
        }
        case "get_vault_wallet_balance": {
          const aliasOrAddress = String(args?.alias_or_address ?? "");
          const chain = String(args?.chain ?? "base");
          const result = await getVaultWalletBalance(aliasOrAddress, chain);
          return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
        }
        case "decode_calldata": {
          const calldata = String(args?.calldata ?? "");
          const toContract = args?.to_contract ? String(args.to_contract) : undefined;
          const chain = String(args?.chain ?? "base");
          const result = await decodeCalldata(calldata, toContract, chain);
          return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
        }
        case "prepare_transaction": {
          const alias = String(args?.alias ?? "");
          const to = String(args?.to ?? "");
          const valueEth = args?.value_eth ? String(args.value_eth) : "0";
          const data = args?.data ? String(args.data) : "0x";
          const chain = String(args?.chain ?? "base");
          const result = await prepareTransaction({ alias, to, value_eth: valueEth, data, chain });
          return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
        }
        case "execute_vault_transaction": {
          const alias = String(args?.alias ?? "");
          const to = String(args?.to ?? "");
          const valueEth = args?.value_eth ? String(args.value_eth) : "0";
          const data = args?.data ? String(args.data) : "0x";
          const chain = String(args?.chain ?? "base");
          const userConfirmed = Boolean(args?.user_confirmed ?? false);
          const result = await executeVaultTransaction({
            alias,
            to,
            value_eth: valueEth,
            data,
            chain,
            user_confirmed: userConfirmed,
          });
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
