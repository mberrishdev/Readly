cask "readly" do
  version "0.1.0"
  # Placeholder until the first real release — scripts/release.sh overwrites
  # this with the actual DMG's sha256 on every release cut.
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/mberrishdev/Readly/releases/download/v#{version}/Readly-#{version}.dmg",
      verified: "github.com/mberrishdev/Readly/"
  name "Readly"
  desc "Menu-bar utility that turns any on-screen selection into copied text"
  homepage "https://github.com/mberrishdev/Readly"

  depends_on macos: ">= :sonoma"
  depends_on arch: :arm64

  app "Readly.app"

  uninstall quit: "com.readly.app"

  zap trash: [
    "~/Library/Application Support/Readly",
    "~/Library/Preferences/com.readly.app.plist",
  ]

  # Readly is ad-hoc signed (no Apple Developer ID yet), so without this
  # macOS reports it as "damaged and can't be opened" on first launch —
  # Gatekeeper's message for a quarantined app it can't notarization-verify,
  # not actual corruption. Clearing the quarantine flag here means a plain
  # `brew install --cask readly` just works; only a manual DMG install
  # (outside Homebrew) still needs this run by hand.
  postflight do
    system_command "/usr/bin/xattr",
                    args: ["-cr", "#{appdir}/Readly.app"]
  end

  caveats do
    <<~EOS
      Readly is ad-hoc signed (no Apple Developer ID yet). This cask already
      clears the quarantine flag for you; if you instead installed the DMG
      manually and macOS says Readly is damaged and can't be opened, run:
        xattr -cr "#{appdir}/Readly.app"

      Readly needs Screen Recording access to capture a selection — grant it
      from the onboarding window that opens on first launch.
    EOS
  end
end
