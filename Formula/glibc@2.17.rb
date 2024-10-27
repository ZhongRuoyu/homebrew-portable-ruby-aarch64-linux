require "os/linux/glibc"

class GlibcBaseRequirement < Requirement
  def message
    tool = self.class::TOOL
    version = self.class::VERSION
    <<~EOS
      #{[tool, version].compact.join(" ")} is required to build glibc.
      Install #{tool} with your host package manager if you have sudo access:
        sudo apt-get install #{tool}
        sudo yum install #{tool}
    EOS
  end

  def display_s
    "#{self.class::TOOL} #{self.class::VERSION}".strip
  end
end

class GawkRequirement < GlibcBaseRequirement
  fatal true
  satisfy(build_env: false) { which(TOOL).present? }
  TOOL = "gawk".freeze
  VERSION = "3.1.2 (or later)".freeze
end

class MakeRequirement < GlibcBaseRequirement
  fatal true
  satisfy(build_env: false) { which(TOOL).present? }
  TOOL = "make".freeze
  VERSION = "3.79 (or later)".freeze
end

class SedRequirement < GlibcBaseRequirement
  fatal true
  satisfy(build_env: false) { which(TOOL).present? }
  TOOL = "sed".freeze
  VERSION = "3.02 (or later)".freeze
end

class LinuxKernelRequirement < Requirement
  fatal true

  MINIMUM_LINUX_KERNEL_VERSION = "2.6.16".freeze

  satisfy(build_env: false) do
    OS.kernel_version >= MINIMUM_LINUX_KERNEL_VERSION
  end

  def message
    <<~EOS
      Linux kernel version #{MINIMUM_LINUX_KERNEL_VERSION} or later is required by glibc.
      Your system has Linux kernel version #{OS.kernel_version}.
    EOS
  end

  def display_s
    "Linux kernel #{MINIMUM_LINUX_KERNEL_VERSION} (or later)"
  end
end

class GlibcAT217 < Formula
  desc "GNU C Library"
  homepage "https://www.gnu.org/software/libc/"
  url "https://ftp.gnu.org/gnu/glibc/glibc-2.17.tar.gz"
  mirror "https://ftpmirror.gnu.org/gnu/glibc/glibc-2.17.tar.gz"
  sha256 "a3b2086d5414e602b4b3d5a8792213feb3be664ffc1efe783a829818d3fca37a"
  license all_of: ["GPL-2.0-or-later", "LGPL-2.1-or-later"]

  bottle do
    root_url "https://ghcr.io/v2/zhongruoyu/zhongruoyu-portable-ruby-aarch64-linux"
    rebuild 1
    sha256 x86_64_linux:  "0202d518c6b1f7c2ef71ba4ebd25afb6366477c269a769d4dfa104e169d14c2b"
    sha256 aarch64_linux: "fd4ea7170beced1ee87c368fbc4ba73ac80e404e16a9899de397472d3f3f97c4"
  end

  keg_only :versioned_formula

  depends_on GawkRequirement => :build
  depends_on MakeRequirement => :build
  depends_on SedRequirement => :build
  depends_on :linux
  depends_on LinuxKernelRequirement

  on_arm do
    depends_on "zhongruoyu/portable-ruby-aarch64-linux/linux-headers@4.4" => :build
  end

  on_intel do
    depends_on "linux-headers@4.4" => :build
  end

  # Backport of:
  # https://sourceware.org/git/?p=glibc.git;a=commit;h=e9177fba13549a8e2a6232f46080e5c6d3e467b1
  patch do
    url "https://git.centos.org/rpms/glibc/raw/ca483cc5b0e3e6a595a2c103755dee4d72f14f25/f/SOURCES/glibc-rh1500908.patch"
    sha256 "48bfb15f5a26161bbef3d58e18d44876a170ddbfcc5922a39c77fd8da9fe68f6"
  end

  # Backport of:
  # https://sourceware.org/git/?p=glibc.git;a=commit;h=43d06ed218fc8be58987bdfd00e21e5720f0b862
  patch :DATA

  def install
    # Fix checking version of gnumake... 4.3, bad
    inreplace "configure",
              "3.79* | 3.[89]*)",
              "3.79* | 3.[89]* | [4-9].* | [1-9][0-9]*)"

    # Fix checking version of gcc-11... 11.4.0, bad
    inreplace "configure",
              "4.[3-9].* | 4.[1-9][0-9].* | [5-9].* )",
              "4.[3-9].* | 4.[1-9][0-9].* | [5-9].* | [1-9][0-9]* )"

    # Setting RPATH breaks glibc.
    %w[
      LDFLAGS LD_LIBRARY_PATH LD_RUN_PATH LIBRARY_PATH
      HOMEBREW_DYNAMIC_LINKER HOMEBREW_LIBRARY_PATHS HOMEBREW_RPATH_PATHS
    ].each { |x| ENV.delete x }

    # Fix relocation R_X86_64_32S against symbol `__libc_csu_fini' can not be
    # used when making a PIE object; recompile with -fPIE
    # See https://sourceware.org/pipermail/libc-alpha/2020-March/111688.html
    ENV.append "LDFLAGS", "-no-pie" if Hardware::CPU.intel?

    # Use brewed ld.so.preload rather than the host's /etc/ld.so.preload
    inreplace "elf/rtld.c",
              '= "/etc/ld.so.preload";',
              '= SYSCONFDIR "/ld.so.preload";'

    mkdir "build" do
      args = [
        "--disable-debug",
        "--disable-dependency-tracking",
        "--disable-silent-rules",
        "--prefix=#{prefix}",
        "--sysconfdir=#{etc}",
        "--enable-obsolete-rpc",
        "--without-gd",
        "--without-selinux",
        "--with-headers=#{Formula["linux-headers@4.4"].include}",
      ]
      system "../configure", *args
      system "make", "all"
      system "make", "install"
      prefix.install_symlink "lib" => "lib64"
    end

    # Fix quoting of filenames that contain @
    inreplace [lib/"libc.so", lib/"libpthread.so"],
              %r{(#{Regexp.escape(prefix)}/\S*) },
              '"\1" '

    # Remove executables/dylibs that link with system libnsl
    [
      sbin/"nscd",
      lib/"libnss_nisplus-#{version}.so",
      lib/"libnss_compat-#{version}.so",
      lib/"libnss_nis-#{version}.so",
    ].each(&:unlink)
  end

  def post_install
    # Compile locale definition files
    mkdir_p lib/"locale"

    # Get all extra installed locales from the system, except C locales
    locales = ENV.filter_map do |k, v|
      v if k[/^LANG$|^LC_/] && v != "C" && !v.start_with?("C.")
    end

    # en_US.UTF-8 is required by gawk make check
    locales = (locales + ["en_US.UTF-8"]).sort.uniq
    ohai "Installing locale data for #{locales.join(" ")}"
    locales.each do |locale|
      lang, charmap = locale.split(".", 2)
      if charmap.present?
        charmap = "UTF-8" if charmap == "utf8"
        system bin/"localedef", "-i", lang, "-f", charmap, locale
      else
        system bin/"localedef", "-i", lang, locale
      end
    end

    # Set the local time zone
    sys_localtime = Pathname("/etc/localtime")
    brew_localtime = etc/"localtime"
    etc.install_symlink sys_localtime if sys_localtime.exist? && !brew_localtime.exist?

    # Set zoneinfo correctly using the system installed zoneinfo
    sys_zoneinfo = Pathname("/usr/share/zoneinfo")
    brew_zoneinfo = share/"zoneinfo"
    share.install_symlink sys_zoneinfo if sys_zoneinfo.exist? && !brew_zoneinfo.exist?
  end

  test do
    assert_match "Usage", shell_output("#{lib}/ld-#{version}.so 2>&1", 127)
    safe_system "#{lib}/libc.so.6", "--version"
    safe_system "#{bin}/locale", "--version"
  end
end

__END__
commit f6610cf4ec687bd37da8c7ea2664df6545e79bf5
Author: Fangrui Song <maskray@google.com>
Commit: Ruoyu Zhong <zhongruoyu@outlook.com>

    aarch64: Make elf_machine_{load_address,dynamic} robust [BZ #28203]

    The AArch64 ABI is largely platform agnostic and does not specify
    _GLOBAL_OFFSET_TABLE_[0] ([1]). glibc ld.so turns out to be probably the
    only user of _GLOBAL_OFFSET_TABLE_[0] and GNU ld defines the value
    to the link-time address _DYNAMIC. [2]

    In 2012, __ehdr_start was implemented in GNU ld and gold in binutils
    2.23.  Using adrp+add / (-mcmodel=tiny) adr to access
    __ehdr_start/_DYNAMIC gives us a robust way to get the load address and
    the link-time address of _DYNAMIC.

    [1]: From a psABI maintainer, https://bugs.llvm.org/show_bug.cgi?id=49672#c2
    [2]: LLD's aarch64 port does not set _GLOBAL_OFFSET_TABLE_[0] to the
    link-time address _DYNAMIC.
    LLD is widely used on aarch64 Android and ChromeOS devices.  Software
    just works without the need for _GLOBAL_OFFSET_TABLE_[0].

    Reviewed-by: Szabolcs Nagy <szabolcs.nagy@arm.com>

diff --git a/ports/sysdeps/aarch64/dl-machine.h b/ports/sysdeps/aarch64/dl-machine.h
index 94f1108e15..3e4fa7f900 100644
--- a/ports/sysdeps/aarch64/dl-machine.h
+++ b/ports/sysdeps/aarch64/dl-machine.h
@@ -31,40 +31,22 @@ elf_machine_matches_host (const ElfW(Ehdr) *ehdr)
   return ehdr->e_machine == EM_AARCH64;
 }

-/* Return the link-time address of _DYNAMIC.  Conveniently, this is the
-   first element of the GOT. */
+/* Return the run-time load address of the shared object.  */
+
 static inline ElfW(Addr) __attribute__ ((unused))
-elf_machine_dynamic (void)
+elf_machine_load_address (void)
 {
-  ElfW(Addr) addr = (ElfW(Addr)) &_DYNAMIC;
-  return addr;
+  extern const ElfW(Ehdr) __ehdr_start attribute_hidden;
+  return (ElfW(Addr)) &__ehdr_start;
 }

-/* Return the run-time load address of the shared object.  */
+/* Return the link-time address of _DYNAMIC.  */

 static inline ElfW(Addr) __attribute__ ((unused))
-elf_machine_load_address (void)
+elf_machine_dynamic (void)
 {
-  /* To figure out the load address we use the definition that for any symbol:
-     dynamic_addr(symbol) = static_addr(symbol) + load_addr
-
-     The choice of symbol is arbitrary. The static address we obtain
-     by constructing a non GOT reference to the symbol, the dynamic
-     address of the symbol we compute using adrp/add to compute the
-     symbol's address relative to the PC. */
-
-  ElfW(Addr) static_addr;
-  ElfW(Addr) dynamic_addr;
-
-  asm ("					\n\
-	adrp	%1, _dl_start;			\n\
-        add	%1, %1, #:lo12:_dl_start        \n\
-        ldr	%w0, 1f				\n\
-	b	2f				\n\
-1:	.word	_dl_start			\n\
-2:						\n\
-       " : "=r" (static_addr),  "=r" (dynamic_addr));
-  return dynamic_addr - static_addr;
+  extern ElfW(Dyn) _DYNAMIC[] attribute_hidden;
+  return (ElfW(Addr)) _DYNAMIC - elf_machine_load_address ();
 }

 /* Set up the loaded object described by L so its unrelocated PLT
