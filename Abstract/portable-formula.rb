# frozen_string_literal: true

module PortableFormulaMixin
  if OS.mac?
    if Hardware::CPU.arm?
      TARGET_MACOS = :big_sur
      TARGET_DARWIN_VERSION = Version.new("20.1.0").freeze
    else
      TARGET_MACOS = :el_capitan
      TARGET_DARWIN_VERSION = Version.new("15.0.0").freeze
    end

    CROSS_COMPILING = OS.kernel_version.major != TARGET_DARWIN_VERSION.major
  end

  def portable_configure_args
    # Allow cross-compile between Darwin versions (used by our fake El Capitan on High Sierra setup)
    if OS.mac? && CROSS_COMPILING
      cpu = if Hardware::CPU.arm?
        "aarch64"
      else
        "x86_64"
      end
      %W[
        --build=#{cpu}-apple-darwin#{OS.kernel_version}
        --host=#{cpu}-apple-darwin#{TARGET_DARWIN_VERSION}
      ]
    else
      []
    end
  end

  def portable_cflags
    @portable_cflags ||= if OS.linux? && Hardware::CPU.arm?
      cflags = []

      cflags << "-nostdinc"
      gcc = ENV.cc
      gcc_include_dir = Utils.safe_popen_read(gcc, "--print-file-name=include").chomp
      gcc_include_fixed_dir = Utils.safe_popen_read(gcc, "--print-file-name=include-fixed").chomp
      cflags << "-isystem#{gcc_include_dir}" << "-isystem#{gcc_include_fixed_dir}"

      if DevelopmentTools.gcc_version(gcc) >= "9.3.1"
        # Out-of-line atomics require an extra package on older systems.
        # https://learn.arm.com/learning-paths/servers-and-cloud-computing/lse/intro/
        cflags << "-mno-outline-atomics"
      end

      cflags.join(" ")
    else
      ""
    end
  end

  def portable_ldflags
    @portable_ldflags ||= if OS.linux? && Hardware::CPU.arm?
      glibc = Formula["zhongruoyu/portable-ruby-aarch64-linux/glibc@2.17"]
      %W[
        -B#{glibc.opt_lib}
        -Wl,-rpath-link=#{glibc.opt_lib}
      ].join(" ")
    else
      ""
    end
  end

  def install
    if OS.mac?
      if OS::Mac.version > TARGET_MACOS
        target_macos_humanized = TARGET_MACOS.to_s.tr("_", " ").split.map(&:capitalize).join(" ")

        opoo <<~EOS
          You are building portable formula on #{OS::Mac.version}.
          As result, formula won't be able to work on older macOS versions.
          It's recommended to build this formula on macOS #{target_macos_humanized}
          (the oldest version that can run Homebrew).
        EOS
      end

      # Always prefer to linking to portable libs.
      ENV.append "LDFLAGS", "-Wl,-search_paths_first"
    elsif OS.linux?
      # reset Linuxbrew env, because we want to build formula against
      # libraries offered by system (CentOS docker) rather than Linuxbrew.
      ENV.delete "LDFLAGS"
      ENV.delete "LIBRARY_PATH"
      ENV.delete "LD_RUN_PATH"
      ENV.delete "LD_LIBRARY_PATH"
      ENV.delete "TERMINFO_DIRS"
      ENV.delete "HOMEBREW_RPATH_PATHS"
      ENV.delete "HOMEBREW_DYNAMIC_LINKER"

      # https://github.com/Homebrew/homebrew-portable-ruby/issues/118
      ENV.append_to_cflags "-fPIC"
    end

    ENV.append_to_cflags portable_cflags if portable_cflags.present?
    ENV.append "LDFLAGS", portable_ldflags if portable_ldflags.present?

    super

    return if name != "portable-ruby"

    abi_version = `#{bin}/ruby -rrbconfig -e 'print RbConfig::CONFIG["ruby_version"]'`
    abi_arch = `#{bin}/ruby -rrbconfig -e 'print RbConfig::CONFIG["arch"]'`
    inreplace lib/"ruby/#{abi_version}/#{abi_arch}/rbconfig.rb" do |s|
      s.gsub! portable_cflags, "" if portable_cflags.present?
      s.gsub! portable_ldflags, "" if portable_ldflags.present?
    end
  end

  def test
    refute_match(/Homebrew libraries/,
                 shell_output("#{HOMEBREW_BREW_FILE} linkage #{full_name}"))

    super
  end
end

class PortableFormula < Formula
  desc "Abstract portable formula"
  homepage "https://github.com/Homebrew/homebrew-portable-ruby"

  def self.inherited(subclass)
    subclass.class_eval do
      super

      keg_only "portable formulae are keg-only"

      on_linux do
        on_arm do
          depends_on "zhongruoyu/portable-ruby-aarch64-linux/glibc@2.17" => :build
          depends_on "zhongruoyu/portable-ruby-aarch64-linux/linux-headers@4.4" => :build
        end

        on_intel do
          depends_on "glibc@2.13" => :build
          depends_on "linux-headers@4.4" => :build
        end
        # When we move from Ubuntu 22.04, on ARM we should add a dependency to glibc@2.35 and linux-headers@5.15.
        # When doing so, remember to update the C++ Intel conditional in the portable-ruby formula.
      end

      prepend PortableFormulaMixin
    end
  end
end
