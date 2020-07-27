# homebrew-caskpkg
Homebrew [external command](https://docs.brew.sh/External-Commands) to build a macOS installer
package from a [cask](https://formulae.brew.sh/cask/)

## Usage

The cask must first already be installed on the system. Using [cyberduck](https://formulae.brew.sh/cask/cyberduck) as an example:

`brew cask pkg cyberduck`

WIP

## Installing it

`brewcask-pkg` is available from this [formulae tap](https://github.com/mgatner/homebrew-caskage). Add the tap:

`brew tap mgatner/caskpkg`

Then install as any other formula:

`brew install brew-caskpkg`

## Extras

You can also define a custom identifier prefix in the reverse-domain convention with the `--identifier-prefix` option,
e.g. `brew cask pkg --identifier-prefix io.cyberduck cyberduck`.

You can set the path to custom **preinstall** and **postinstall** scripts with the `--scripts` option which passed through to the `pkgbuild` command.  
For more information refer to `man pkgbuild` which explains:

> `--scripts scripts_path` archive the entire contents of scripts-path as the package scripts. If this directory contains scripts named preinstall and/or postinstall, these will be run as the top-level scripts of the package [...]

## License

This project uses the [Mozilla Public License](https://github.com/mgatner/homebrew-caskage/blob/develop/LICENSE.md).
It borrows heavily from its [formula counterpart](https://github.com/mgatner/homebrew-pkg),
originally authored by [Tim Sutton](https://github.com/timsutton/brew-pkg) and [Daniel Bair](https://github.com/danielbair/homebrew-pkg).
