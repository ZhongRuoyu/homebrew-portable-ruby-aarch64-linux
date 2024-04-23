class M4AT14 < Formula
  desc "Macro processing language"
  homepage "https://www.gnu.org/software/m4"
  url "https://ftp.gnu.org/gnu/m4/m4-1.4.19.tar.gz"
  mirror "https://ftpmirror.gnu.org/m4/m4-1.4.19.tar.gz"
  sha256 "3be4a26d825ffdfda52a56fc43246456989a3630093cced3fbddf4771ee58a70"
  license "GPL-3.0-or-later"

  keg_only :versioned_formula

  def install
    system "./configure", "--disable-dependency-tracking", "--prefix=#{prefix}"
    system "make"
    system "make", "install"
  end

  test do
    assert_match "Homebrew",
      pipe_output("#{bin}/m4", "define(TEST, Homebrew)\nTEST\n")
  end
end
