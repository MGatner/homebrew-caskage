class BrewCaskage < Formula
  desc "Homebrew command for building macOS packages from installed casks."
  homepage "https://github.com/mgatner/homebrew-caskage"
  url "https://github.com/mgatner/homebrew-caskage.git", :tag => "v1.0.0" 

  head "https://github.com/mgatner/homebrew-caskage.git"

  def install
    bin.install "cmd/brew-caskage.rb"
  end

    def caveats
        <<~EOS
          You can uninstall this formula, as `brew tap mgatner/caskage` is all that's
          needed to install brew-caskage and keep it up to date.
        EOS
    end

  test do
    system "brew", "caskage", "--help"
  end
end
