class LinuxHeadersAT44 < Formula
  desc "Header files of the Linux kernel"
  homepage "https://kernel.org/"
  url "https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.4.302.tar.gz"
  sha256 "66271f9d9fce8596622e8154ca0ea160e46b78a5a6c967a15b55855f744d1b0b"
  license "GPL-2.0-only"

  bottle do
    root_url "https://ghcr.io/v2/zhongruoyu/zhongruoyu-portable-ruby-aarch64-linux"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "312e64f9cadbac874f0f69ae58b74ced82765ffe54b72aad66cf4baaad33154e"
    sha256 cellar: :any_skip_relocation, aarch64_linux: "0ed7c3d1ef00c3c4f9ad62f105a156a2562fff5ea025175a0a7c756be38e485e"
  end

  keg_only :versioned_formula

  depends_on :linux

  def install
    system "make", "headers_install", "INSTALL_HDR_PATH=#{prefix}"
    rm Dir[prefix/"**/{.install,..install.cmd}"]
  end

  test do
    assert_match "KERNEL_VERSION", File.read(include/"linux/version.h")
  end
end
