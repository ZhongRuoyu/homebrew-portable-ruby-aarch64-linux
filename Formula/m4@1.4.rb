class M4AT14 < Formula
  desc "Macro processing language"
  homepage "https://www.gnu.org/software/m4"
  url "https://ftp.gnu.org/gnu/m4/m4-1.4.19.tar.gz"
  mirror "https://ftpmirror.gnu.org/m4/m4-1.4.19.tar.gz"
  sha256 "3be4a26d825ffdfda52a56fc43246456989a3630093cced3fbddf4771ee58a70"
  license "GPL-3.0-or-later"

  bottle do
    root_url "https://ghcr.io/v2/zhongruoyu/zhongruoyu-portable-ruby-aarch64-linux"
    sha256 x86_64_linux:  "b585e0a0ba11910d7dd30550c16358353cef2e2510e9ae35f5a69d5e956a0b73"
    sha256 aarch64_linux: "7bf5e38daaf3558ef23c6d5596c1d126be4e0c51149a3489a06f594a94917750"
  end

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
