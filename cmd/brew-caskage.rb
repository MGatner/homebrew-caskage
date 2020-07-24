#:Usage: brew caskage [options] cask
#:
#:Build a macOS installer package from a cask. It must be already
#:installed; 'brew caskage' doesn't handle this for you automatically. The
#:'--identifier-prefix' option is strongly recommended in order to follow
#:the conventions of macOS installer packages (Default 'org.homebrew').
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

  def caskage_args
    Homebrew::CLI::Parser.new do
      usage_banner <<~EOS
      `caskage` [<options>] <cask>

      Build a macOS installer package from a cask. It must be already
      installed; 'brew caskage' doesn't handle this for you automatically. The
      '--identifier-prefix' option is strongly recommended in order to follow
      the conventions of macOS installer packages (Default 'org.homebrew').
      EOS
      flag "--identifier-prefix=",
             description: "Set a custom identifier prefix to be"\
                          "prepended to the built package's identifier"\
                          "default package identifier is 'org.homebrew'"
      switch "--skip-cask-deps",
             description: "Skip the casks's dependencies in the build."
      flag "--install-location=",
             description: "Custom install location for package"
      flag "--custom-ownership",
             description: "Custom ownership for package"
      flag "--preinstall-script=",
             description: "Custom preinstall script file"
      flag "--postinstall-script=",
             description: "Custom postinstall script file"
      flag "--scripts=",
             description: "Custom preinstall and postinstall scripts folder"
      flag "--pkgvers=",
             description: "Set the version string in the resulting .pkg file"
      switch :debug,
             description: "Print extra debug information"
      formula_options
      min_named :formula
    end
  end

  def caskage
    caskage_args.parse

    odebug "DEBUG: args..." if Homebrew.args.debug?
    pp ARGV if Homebrew.args.debug?

    identifier_prefix = 'org.homebrew'
    if (args.identifier_prefix != nil)
      odebug "DEBUG: --identifier-prefix=#{args.identifier_prefix}" if Homebrew.args.debug?
      identifier_prefix = args.identifier_prefix
    end

    f = Formulary.factory ARGV.last
    name = f.name
    identifier = identifier_prefix + ".#{name}"
    version = f.version.to_s
    version += "_#{f.revision}" if f.revision.to_s != '0'

    # Make sure it's installed first
    if not f.latest_version_installed?
      onoe "#{f.name} is not installed. First install it with 'brew install #{f.name}'."
      abort
    end

    # Setup staging dir
    pkg_root = Dir.mktmpdir 'brew-pkg'
    staging_root = pkg_root + HOMEBREW_PREFIX
    ohai "Creating package staging root using Homebrew prefix #{HOMEBREW_PREFIX}"
    FileUtils.mkdir_p staging_root


    pkgs = [ARGV.last] # NOTE: was [f] but this didn't allow taps with conflicting formula names.

    # Add deps if we specified --with-deps
    if args.with_deps?
      odebug "DEBUG: --with-deps" if Homebrew.args.debug?
      pkgs += f.recursive_dependencies if args.with_deps?
    else
      odebug "DEBUG: without deps" if Homebrew.args.debug?
    end

    pkgs.each do |pkg|
      odebug "DEBUG: packaging formula #{pkg}" if Homebrew.args.debug?
      formula = Formulary.factory(pkg.to_s)
      dep_version = formula.version.to_s
      dep_version += "_#{formula.revision}" if formula.revision.to_s != '0'

      ohai "Staging formula #{formula.name}"
      # Get all directories for this keg, rsync to the staging root
      if File.exists?(File.join(HOMEBREW_CELLAR, formula.name, dep_version))
        # dirs = Pathname.new(File.join(HOMEBREW_CELLAR, formula.name, dep_version)).children.select { |c| c.directory? }.collect { |p| p.to_s }
        # dirs.each {|d| safe_system "rsync", "-a", "#{d}", "#{staging_root}/" }
        dirs = ["etc", "bin", "sbin", "include", "share", "lib", "Frameworks"]
        dirs.each do |d|
          sourcedir = Pathname.new(File.join(HOMEBREW_CELLAR, formula.name, dep_version, d))
          if File.exists?(sourcedir)
            ohai "rsyncing #{sourcedir} to #{staging_root}"
            safe_system "rsync", "-a", "#{sourcedir}", "#{staging_root}/"
          end
        end
        # Add kegs if not specified --without-kegs
        if File.exists?("#{HOMEBREW_CELLAR}/#{formula.name}/#{dep_version}") and not args.without_kegs?
          odebug "DEBUG: with kegs" if Homebrew.args.debug?
          ohai "Staging directory #{HOMEBREW_CELLAR}/#{formula.name}/#{dep_version}"
          safe_system "mkdir", "-p", "#{staging_root}/Cellar/#{formula.name}/"
          safe_system "rsync", "-a", "#{HOMEBREW_CELLAR}/#{formula.name}/#{dep_version}", "#{staging_root}/Cellar/#{formula.name}/"
	else
          odebug "DEBUG: --without-kegs" if Homebrew.args.debug?
        end
        # Add opt dir if not specified --without-opt
        if File.exists?("/usr/local/opt/#{formula.name}") and not args.without_opt? and not args.without_kegs?
          odebug "DEBUG: with opt" if Homebrew.args.debug?
          ohai "Staging link in #{staging_root}/opt"
          FileUtils.mkdir_p "#{staging_root}/opt"
          safe_system "rsync", "-a", "/usr/local/opt/#{formula.name}", "#{staging_root}/opt"
	else
          odebug "DEBUG: --without-opt" if Homebrew.args.debug?
        end
      end

      # Write out a LaunchDaemon plist if we have one
      if formula.plist
        ohai "Plist found at #{formula.plist_name}, staging for /Library/LaunchDaemons/#{formula.plist_name}.plist"
        launch_daemon_dir = File.join staging_root, "Library", "LaunchDaemons"
        FileUtils.mkdir_p launch_daemon_dir
        fd = File.new(File.join(launch_daemon_dir, "#{formula.plist_name}.plist"), "w")
        fd.write formula.plist
        fd.close
      end
    end

    # Add scripts if specified
    found_scripts = false
    if (args.scripts != nil)
      odebug "DEBUG: --scripts=#{args.scripts}" if Homebrew.args.debug?
      scripts_path = args.scripts
      if File.directory?(scripts_path)
        pre = File.join(scripts_path,"preinstall")
        post = File.join(scripts_path,"postinstall")
        if File.exists?(pre)
          File.chmod(0755, pre)
          found_scripts = true
          ohai "Adding preinstall script"
        end
        if File.exists?(post)
          File.chmod(0755, post)
          found_scripts = true
          ohai "Adding postinstall script"
        end
      end
      if not found_scripts
        opoo "No scripts found in #{scripts_path}"
      end
    end

    # Add preinstall script if specified 
    found_scripts = false
    if (args.preinstall_script != nil)
      odebug "DEBUG: --preinstall-script=#{args.preinstall_script}" if Homebrew.args.debug?
      preinstall_script = args.preinstall_script
      if File.exists?(preinstall_script)
        scripts_path = Dir.mktmpdir "#{name}-#{version}-scripts"
        pre = File.join(scripts_path,"preinstall")
        safe_system "cp", "-a", "#{preinstall_script}", "#{pre}"
        File.chmod(0755, pre)
        found_scripts = true
        ohai "Adding preinstall script"
      end
    end
    # Add postinstall script if specified 
    if (args.postinstall_script != nil)
      odebug "DEBUG: --postinstall-script=#{args.postinstall_script}" if Homebrew.args.debug?
      postinstall_script = args.postinstall_script
      if File.exists?(postinstall_script)
        if not found_scripts
          scripts_path = Dir.mktmpdir "#{name}-#{version}-scripts"
	end
        post = File.join(scripts_path,"postinstall")
        safe_system "cp", "-a", "#{postinstall_script}", "#{post}"
        File.chmod(0755, post)
        found_scripts = true
        ohai "Adding postinstall script"
      end
    end

    # Custom ownership
    found_ownership = false
    if (args.custom_ownership != nil)
      odebug "DEBUG: --custom-ownership=#{args.custom_ownership}" if Homebrew.args.debug?
      custom_ownership = args.custom_ownership
       if ['recommended', 'preserve', 'preserve-other'].include? custom_ownership
        found_ownership = true
        ohai "Setting pkgbuild option --ownership with value #{custom_ownership}"
       else
        opoo "#{custom_ownership} is not a valid value for pkgbuild --ownership option, ignoring"
       end
    end

    # Custom install location
    found_installdir = false
    if (args.install_location != nil)
      odebug "DEBUG: --install-location=#{args.install_location}" if Homebrew.args.debug?
      install_dir = args.install_location
      found_installdir = true
        ohai "Setting install directory option --install-location with value #{install_dir}"
    end

    found_pkgvers = false
    if (args.pkgvers != nil)
      odebug "DEBUG: --pkgvers=#{args.pkgvers}" if Homebrew.args.debug?
      version = args.pkgvers
      found_pkgvers = true
      ohai "Setting pkgbuild option --version with value #{version}"
    end

    # Build it
    pkgfile = "#{name}-#{version}.pkg"
    ohai "Building package #{pkgfile}"
    pargs = [
      "--quiet",
      "--root", "#{pkg_root}",
      "--identifier", identifier,
      "--version", version
    ]
    if found_scripts
      pargs << "--scripts"
      pargs << scripts_path 
    end
    if found_ownership
      pargs << "--ownership"
      pargs << custom_ownership 
    end
    if found_installdir
      pargs << "--install-location"
      pargs << install_dir 
    end

    pargs << "#{pkgfile}"
    odebug "DEBUG: pkgbuild #{pargs}" if Homebrew.args.debug?
    safe_system "pkgbuild", *pargs

    FileUtils.rm_rf pkg_root if not Homebrew.args.debug?
  end
end

Homebrew.caskage
