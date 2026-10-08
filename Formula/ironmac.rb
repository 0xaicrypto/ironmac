class Ironmac < Formula
  desc "Hardened Web3 & Crypto Workstation Suite for macOS"
  homepage "https://github.com/0xaicrypto/ironmac"
  url "https://github.com/0xaicrypto/ironmac/archive/refs/tags/v0.4.0.tar.gz"
  sha256 "117d3e45d56a784dc6f5fcd6e92d56b6108de1bd80ae4270cfeec06cf1f15ae5"
  license "MIT"
  head "https://github.com/0xaicrypto/ironmac.git", branch: "main"

  depends_on :macos
  depends_on "node" => :recommended

  def install
    # Compile native MenuBar companion if swiftc is available
    if which("swiftc") && (buildpath/"app/IronMacMenu.swift").exist?
      system "swiftc", "-O", "app/IronMacMenu.swift", "-o", "bin/ironmac-menu"
    end

    # Copy all files into libexec
    libexec.install Dir["*"]

    # Symlink ironmac CLI to bin
    bin.install_symlink libexec/"bin/ironmac" => "ironmac"
    bin.install_symlink libexec/"bin/ironmac-menu" => "ironmac-menu" if (libexec/"bin/ironmac-menu").exist?
  end

  def post_install
    chmod 0755, libexec/"bin/ironmac"
    chmod 0755, Dir[libexec/"modules/*.sh"]
    chmod 0755, libexec/"bin/ironmac-menu" if (libexec/"bin/ironmac-menu").exist?
    chmod 0755, libexec/"mcp/dist/index.js" if (libexec/"mcp/dist/index.js").exist?
  end

  test do
    assert_match "IronMac v#{version}", shell_output("#{bin}/ironmac --version")
    assert_match "Usage: ironmac <command>", shell_output("#{bin}/ironmac help")
  end
end
