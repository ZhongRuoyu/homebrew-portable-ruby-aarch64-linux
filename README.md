# Homebrew Portable Ruby for aarch64 Linux

Port of Homebrew's Portable Ruby to aarch64 Linux. This is a fork of Homebrew's tap [`homebrew/portable-ruby`](https://github.com/Homebrew/homebrew-portable-ruby), with modifications to provide aarch64 Linux support.

## How do I install these formulae

Just `brew install zhongruoyu/portable-ruby-aarch64-linux/<formula>`.

## Bootstrapping Homebrew with Portable Ruby for aarch64 Linux

To bootstrap an existing Homebrew installation with the ported Portable Ruby, run:

```bash
HOMEBREW_PREFIX="$(brew --prefix)" /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/ZhongRuoyu/homebrew-portable-ruby-aarch64-linux/HEAD/bootstrap.sh)"
```

Or, alternatively:

```bash
brew tap zhongruoyu/portable-ruby-aarch64-linux
brew vendor-install-ruby
```

## How do I build packages for these formulae

Homebrew Portable Ruby is designed only for usage internally to Homebrew. If Portable Ruby isn't available for your platform, it is recommended you instead use Ruby from your system's package manager (if available) or rbenv/ruby-build. Usage of Portable Ruby outside of Homebrew, such as embedding into your own apps, is not a goal for this project.

For issuing new Portable Ruby releases, [an automated release workflow is available to use](https://github.com/ZhongRuoyu/homebrew-portable-ruby-aarch64-linux/actions/workflows/release.yml). Dispatch the workflow and all steps of building, tagging and uploading should be handled automatically.

Manual steps are documented below.

### Build

Run `brew portable-package ruby`.

### Upload

Copy the bottle `bottle*.tar.gz` and `bottle*.json` files into a directory on your local machine.

Upload these files to GitHub Packages with:

```sh
brew pr-upload --upload-only --root-url=https://ghcr.io/v2/zhongruoyu/zhongruoyu-portable-ruby-aarch64-linux
```

And to GitHub releases:

```sh
brew pr-upload --upload-only --root-url=https://github.com/ZhongRuoyu/homebrew-portable-ruby-aarch64-linux/releases/download/$VERSION
```

where `$VERSION` is the new package version.

## License

Code is under the [BSD 2 Clause (NetBSD) license](https://github.com/ZhongRuoyu/homebrew-portable-ruby-aarch64-linux/blob/master/LICENSE.txt).
