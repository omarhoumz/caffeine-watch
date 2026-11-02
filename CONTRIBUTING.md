# Contributing

Thanks for helping. This is a small project, so the process is light.

## Reporting a bug

Open an issue with:

- your macOS version (`sw_vers -productVersion`)
- the output of `caffeine-watch status`
- the raw output of `pmset -g assertions` (remove anything you'd rather not share)
- what you expected to see instead

Most bugs come from a `pmset` line format the parser hasn't seen, so the raw output matters most.

## Making a change

1. Fork and branch from `main`.
2. Build and run it: `./build.sh && open build/CaffeineWatch.app`, and `swift run CaffeineWatch status` for the CLI.
3. Keep it dependency-free and cheap to poll. Each poll spawns a few short processes; don't add more without a reason.
4. Match the existing style: small files, plain Swift, comments only where the reason isn't obvious.
5. Open a pull request saying what changed and how you checked it. Include a screenshot for UI changes.

If you change the icon, update both `Sources/CaffeineWatch/Icon.swift` and `scripts/make-icon.swift`, then regenerate `Resources/AppIcon.icns`.

## Releasing (maintainer)

1. Bump `CFBundleShortVersionString` in `build.sh`, commit, tag `vX.Y.Z`, push.
2. `./build.sh && ditto -c -k --keepParent build/CaffeineWatch.app build/CaffeineWatch.zip`
3. `gh release create vX.Y.Z build/CaffeineWatch.zip`
4. In [omarhoumz/homebrew-tap](https://github.com/omarhoumz/homebrew-tap), update `version` and `sha256` in `Casks/caffeine-watch.rb`.

## Ideas welcome

- signed and notarized release builds
- start a `caffeinate` from the menu
- notify when `caffeinate` stops
