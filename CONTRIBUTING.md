# Contributing

Thanks for helping. This is a small project, so the process is light.

## Reporting a bug

Open an issue with:

- your macOS version (`sw_vers -productVersion`)
- the output of `caffeine-watch status`
- the raw output of `pmset -g assertions` (remove anything you'd rather not share)
- what you expected to see instead

The raw `pmset` output shows the same assertions the app reads, so it matters most.

## Making a change

1. Fork and branch from `main`.
2. Build and run it: `./build.sh && open build/CaffeineWatch.app`, and `swift run CaffeineWatch status` for the CLI.
3. Keep it dependency-free and cheap to poll. Each poll spawns a few short processes; don't add more without a reason.
4. Match the existing style: small files, plain Swift, comments only where the reason isn't obvious.
5. Open a pull request saying what changed and how you checked it. Include a screenshot for UI changes.

If you change the icon, update both `Sources/CaffeineWatch/Icon.swift` and `scripts/make-icon.swift`, then regenerate `Resources/AppIcon.icns`.

## Releasing (maintainer)

The git tag is the version. Follow [semver](https://semver.org): patch for fixes, minor for new features, major for breaking CLI changes.

```sh
git tag v0.2.0 && git push origin v0.2.0
```

`.github/workflows/release.yml` then builds the universal app with that version, publishes the GitHub release with `CaffeineWatch.zip`, and bumps `Casks/caffeine-watch.rb` in [omarhoumz/homebrew-tap](https://github.com/omarhoumz/homebrew-tap). The cask bump needs a `HOMEBREW_TAP_TOKEN` secret (a fine-grained token with Contents read/write on the tap); without it the workflow warns and prints the sha256 to set by hand.

## Ideas welcome

- signed and notarized release builds
- notify when `caffeinate` stops
