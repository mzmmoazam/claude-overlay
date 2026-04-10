class ClaudeOverlay < Formula
  desc "Manage project-level Claude Code config for custom model providers"
  homepage "https://github.com/mzmmoazam/claude-overlay"
  url "https://github.com/mzmmoazam/claude-overlay/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "PLACEHOLDER_SHA256"
  license "MIT"

  depends_on "python@3"

  def install
    bin.install "bin/claude-overlay"
    (lib/"claude-overlay").install "lib/engine.py"
    (lib/"claude-overlay/presets").install Dir["lib/presets/*.json"]
  end

  def caveats
    <<~EOS
      Run 'claude-overlay configure' to set up your provider credentials.

      You'll need to set environment variables in your shell profile:
        export DATABRICKS_TOKEN="your-token"
        export TAVILY_API_KEY="your-tavily-key"
    EOS
  end

  test do
    assert_match "claude-overlay", shell_output("#{bin}/claude-overlay --version")
  end
end
