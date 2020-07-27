class BrewCaskPkg < Formula
  desc "Homebrew command for building macOS packages from installed casks."
  homepage "https://github.com/mgatner/homebrew-caskpkg"
  url "https://github.com/mgatner/homebrew-caskpkg.git", :tag => "v1.0.0" 

  head "https://github.com/mgatner/homebrew-caskpkg.git"

  def install
    bin.install "cmd/brewcask-pkg.rb"
  end

    def caveats
        <<~EOS
          You can uninstall this formula, as `brew tap mgatner/caskpkg` is all that's
          needed to install brewcask-pkg and keep it up to date.
        EOS
    end

  test do
    system "brew", "caskpkg", "--help"
  end
end
