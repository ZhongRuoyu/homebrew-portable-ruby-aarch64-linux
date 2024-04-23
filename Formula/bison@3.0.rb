class BisonAT30 < Formula
  desc "Parser generator"
  homepage "https://www.gnu.org/software/bison/"
  # X.Y.9Z are beta releases that sometimes get accidentally uploaded to the release FTP
  url "https://ftp.gnu.org/gnu/bison/bison-3.0.5.tar.gz"
  mirror "https://ftpmirror.gnu.org/bison/bison-3.0.5.tar.gz"
  sha256 "cd399d2bee33afa712bac4b1f4434e20379e9b4099bce47189e09a7675a2d566"
  license "GPL-3.0-or-later"

  bottle do
    root_url "https://ghcr.io/v2/zhongruoyu/zhongruoyu-portable-ruby-aarch64-linux"
    sha256 x86_64_linux:  "63faa77be5fca07d1d9daa73dbbf6320607083539dc9c2f5dff63d691e913e15"
    sha256 aarch64_linux: "7adcb6f6d21c9a3de8dcd633887a44bb90194250ced391905dcb3dc208798cfe"
  end

  keg_only :versioned_formula

  depends_on "zhongruoyu/portable-ruby-aarch64-linux/m4@1.4"

  def install
    system "./configure", "--disable-dependency-tracking",
                          "--prefix=#{prefix}"
    system "make", "install"
  end

  test do
    (testpath/"test.y").write <<~EOS
      %{ #include <iostream>
         using namespace std;
         extern void yyerror (char *s);
         extern int yylex ();
      %}
      %start prog
      %%
      prog:  //  empty
          |  prog expr '\\n' { cout << "pass"; exit(0); }
          ;
      expr: '(' ')'
          | '(' expr ')'
          |  expr expr
          ;
      %%
      char c;
      void yyerror (char *s) { cout << "fail"; exit(0); }
      int yylex () { cin.get(c); return c; }
      int main() { yyparse(); }
    EOS
    system "#{bin}/bison", "test.y"
    system ENV.cxx, "test.tab.c", "-o", "test"
    assert_equal "pass", shell_output("echo \"((()(())))()\" | ./test")
    assert_equal "fail", shell_output("echo \"())\" | ./test")
  end
end
