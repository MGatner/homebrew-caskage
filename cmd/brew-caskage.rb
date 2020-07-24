#:Usage: brew caskage [options] cask
#:
#:Build a macOS installer package from a cask. It must be already
#:installed; 'brew caskage' doesn't handle this for you automatically. The
#:'--identifier-prefix' option is strongly recommended in order to follow
#:the conventions of OS X installer packages (Default 'org.homebrew').
#:
#:Options:
#:  --identifier-prefix
#:		Set a custom identifier prefix to be prepended to the built
#:		package's identifier (default: 'org.homebrew').
#:
#:  --skip-cask-deps
#:		Skip the casks's dependencies in the build.
#:
#:  --install-location
#:		Custom install location for package.
#:
#:  --custom-ownership
#:		Custom ownership for package.
#:
#:  --preinstall-script
#:		Custom preinstall script file.
#:
#:  --postinstall-script
#:		Custom postinstall script file.
#:
#:  --scripts
#:		Custom preinstall and postinstall scripts folder.
#:
#:  --pkgvers
#:		Set the version string in the resulting .pkg file.
#:
#:  -d, --debug
#:		Print extra debug information.
#:
#:  -h, --help
#:		Show this message.
#:

require 'formula'
require 'formulary'
require 'dependencies'
require 'shellwords'
require "cli/parser"
require 'cmd/deps'
require 'optparse'
require 'ostruct'
require "cleanup"
require 'tmpdir'
require 'set'
require 'pp'

module Homebrew
  module_function

  extend self

end

Homebrew.caskage
