class BinutilsAT226 < Formula
  desc "GNU binary tools for native development"
  homepage "https://www.gnu.org/software/binutils/binutils.html"
  url "https://ftp.gnu.org/gnu/binutils/binutils-2.26.1.tar.bz2"
  mirror "https://ftpmirror.gnu.org/binutils/binutils-2.26.1.tar.bz2"
  sha256 "39c346c87aa4fb14b2f786560aec1d29411b6ec34dce3fe7309fe3dd56949fd8"
  license all_of: ["GPL-2.0-or-later", "GPL-3.0-or-later", "LGPL-2.0-or-later", "LGPL-3.0-only"]

  keg_only :versioned_formula

  depends_on "zhongruoyu/portable-ruby-aarch64-linux/bison@3.0" => :build

  # Backport of:
  # https://sourceware.org/git/?p=binutils-gdb.git;a=commit;h=e5d70d6b5a5c2832ad199ac1b91f68324b4a12c9
  # https://sourceware.org/git/?p=binutils-gdb.git;a=commit;h=a3972330f49f81b3bea64af0970d22f42ae56ec3
  patch :DATA

  def install
    bison = Formula["zhongruoyu/portable-ruby-aarch64-linux/bison@3.0"]
    ENV["M4"] = bison.deps.map(&:to_formula)
                     .find { |d| d.name.match?(/^m4(@.+)?$/) }
                     .opt_bin/"m4"

    # Work around failure from GCC 10+ using default of `-fno-common`
    # multiple definition of `...'; ....o:(.bss+0x0): first defined here
    ENV.append_to_cflags "-fcommon" if OS.linux?

    make_args = OS.mac? ? [] : ["MAKEINFO=true"] # for gprofng

    args = [
      "--disable-debug",
      "--disable-dependency-tracking",
      "--enable-deterministic-archives",
      "--prefix=#{prefix}",
      "--infodir=#{info}",
      "--mandir=#{man}",
      "--disable-werror",
      "--enable-interwork",
      "--enable-multilib",
      "--enable-64-bit-bfd",
      "--enable-gold",
      "--enable-plugins",
      "--enable-targets=all",
      "--disable-nls",
    ]
    system "./configure", *args
    system "make", *make_args
    system "make", "install", *make_args

    if OS.mac?
      Dir["#{bin}/*"].each do |f|
        bin.install_symlink f => "g" + File.basename(f)
      end
    else
      bin.install_symlink "ld.gold" => "gold"
      # Reduce the size of the bottle.
      bin_files = bin.children.select(&:elf?)
      system "strip", *bin_files, *lib.glob("*.a")
    end
  end

  test do
    assert_match "Usage:", shell_output("#{bin}/strings #{bin}/strings")
  end
end

__END__
diff --git a/gas/ChangeLog b/gas/ChangeLog
index 0c5540389508f5e61b6b7f828a63d9ef4bae9b81..a19c20a1eed648b138a06320764940a4b62951ee 100644
--- a/gas/ChangeLog
+++ b/gas/ChangeLog
@@ -1,3 +1,11 @@
+2017-10-25  Alan Modra  <amodra@gmail.com>
+
+	PR 22348
+	* config/tc-crx.c (instruction, output_opcode): Make static.
+	(relocatable, ins_parse, cur_arg_num): Likewise.
+	(parse_insn): Adjust for renamed opcodes globals.
+	(check_range): Likewise
+
 2016-06-29  Tristan Gingold  <gingold@adacore.com>

 	* configure: Regenerate.
diff --git a/gas/config/tc-crx.c b/gas/config/tc-crx.c
index 0acb05eaa8b775b192269f59c934a3c9a19b3549..a2eab104e261837b6e7d924fc3b94d448a528f76 100644
--- a/gas/config/tc-crx.c
+++ b/gas/config/tc-crx.c
@@ -69,21 +69,21 @@ static struct hash_control *reg_hash;
 /* CRX coprocessor registers hash table.  */
 static struct hash_control *copreg_hash;
 /* Current instruction we're assembling.  */
-const inst *instruction;
+static const inst *instruction;

 /* Global variables.  */

 /* Array to hold an instruction encoding.  */
-long output_opcode[2];
+static long output_opcode[2];

 /* Nonzero means a relocatable symbol.  */
-int relocatable;
+static int relocatable;

 /* A copy of the original instruction (used in error messages).  */
-char ins_parse[MAX_INST_LEN];
+static char ins_parse[MAX_INST_LEN];

 /* The current processed argument number.  */
-int cur_arg_num;
+static int cur_arg_num;

 /* Generic assembler global variables which must be defined by all targets.  */

@@ -1041,9 +1041,9 @@ parse_insn (ins *insn, char *operands)
   int i;

   /* Handle instructions with no operands.  */
-  for (i = 0; no_op_insn[i] != NULL; i++)
+  for (i = 0; crx_no_op_insn[i] != NULL; i++)
   {
-    if (streq (no_op_insn[i], instruction->mnemonic))
+    if (streq (crx_no_op_insn[i], instruction->mnemonic))
     {
       insn->nargs = 0;
       return;
@@ -1384,7 +1384,7 @@ check_range (long *num, int bits, int unsigned flags, int update)
 		      : instruction->flags & DISPUD4 ? 4
 		      : 0);

-      for (bin = 0; bin < cst4_maps; bin++)
+      for (bin = 0; bin < crx_cst4_maps; bin++)
 	{
 	  if (value == mul * bin)
 	    {
@@ -1401,9 +1401,9 @@ check_range (long *num, int bits, int unsigned flags, int update)
     {
       int is_cst4 = 0;

-      for (bin = 0; bin < cst4_maps; bin++)
+      for (bin = 0; bin < crx_cst4_maps; bin++)
 	{
-	  if (value == (uint32_t) cst4_map[bin])
+	  if (value == (uint32_t) crx_cst4_map[bin])
 	    {
 	      is_cst4 = 1;
 	      if (update)
diff --git a/gold/ChangeLog b/gold/ChangeLog
index ec8dacb9a1b739a933c8652087a00dafbfe9df12..bae3ee8b568abda4a147a6b319c26a190f69a645 100644
--- a/gold/ChangeLog
+++ b/gold/ChangeLog
@@ -1,3 +1,7 @@
+2019-06-10  Martin Liska  <mliska@suse.cz>
+
+	* errors.h: Include string.
+
 2016-02-05  Sriraman Tallam  <tmsriram@google.com>

 	PR gold/19047
diff --git a/gold/errors.h b/gold/errors.h
index 99542c15f73ed9fe292add69272418e3ccd3cb53..51f7fa12cf315d9bf2fc1c7029e5b32097c2075f 100644
--- a/gold/errors.h
+++ b/gold/errors.h
@@ -24,6 +24,7 @@
 #define GOLD_ERRORS_H

 #include <cstdarg>
+#include <string>

 #include "gold-threads.h"

diff --git a/include/ChangeLog b/include/ChangeLog
index 0ceba89c32c4cf216581ebef5b2cf6f57627a3b7..a8d3d19e271144f7d0875cee0883c318cb379c46 100644
--- a/include/ChangeLog
+++ b/include/ChangeLog
@@ -1,3 +1,13 @@
+2017-10-25  Alan Modra  <amodra@gmail.com>
+
+	PR 22348
+	* opcode/cr16.h (instruction): Delete.
+	(cr16_words, cr16_allWords, cr16_currInsn): Delete.
+	* opcode/crx.h (crx_cst4_map): Rename from cst4_map.
+	(crx_cst4_maps): Rename from cst4_maps.
+	(crx_no_op_insn): Rename from no_op_insn.
+	(instruction): Delete.
+
 2015-11-09  Alan Modra  <amodra@gmail.com>

 	PR gdb/17133
diff --git a/include/opcode/cr16.h b/include/opcode/cr16.h
index ad42d14c04ff30546df7f5c7be0c6742c813e7cd..dc0d675439ea09f81bedb9b004ee7ede86d452d2 100644
--- a/include/opcode/cr16.h
+++ b/include/opcode/cr16.h
@@ -404,9 +404,6 @@ extern const unsigned int cr16_num_cc;
 /* Table of instructions with no operands.  */
 extern const char * cr16_no_op_insn[];

-/* Current instruction we're assembling.  */
-extern const inst *instruction;
-
 /* A macro for representing the instruction "constant" opcode, that is,
    the FIXED part of the instruction. The "constant" opcode is represented
    as a 32-bit unsigned long, where OPC is expanded (by a left SHIFT)
@@ -439,11 +436,6 @@ typedef unsigned long long ULONGLONG;
 typedef unsigned long dwordU;
 typedef unsigned short wordU;

-/* Globals to store opcode data and build the instruction.  */
-extern wordU cr16_words[3];
-extern ULONGLONG cr16_allWords;
-extern ins cr16_currInsn;
-
 /* Prototypes for function in cr16-dis.c.  */
 extern void cr16_make_instruction (void);
 extern int  cr16_match_opcode (void);
diff --git a/include/opcode/crx.h b/include/opcode/crx.h
index fbbff92b0b24cdef76bee1cfb3c821b1e89f77de..16edf5bc7be5206e61566e1dc3050fedef8bf003 100644
--- a/include/opcode/crx.h
+++ b/include/opcode/crx.h
@@ -384,14 +384,11 @@ extern const int crx_num_traps;
 #define NUMTRAPS crx_num_traps

 /* cst4 operand mapping.  */
-extern const int cst4_map[];
-extern const int cst4_maps;
+extern const int crx_cst4_map[];
+extern const int crx_cst4_maps;

 /* Table of instructions with no operands.  */
-extern const char* no_op_insn[];
-
-/* Current instruction we're assembling.  */
-extern const inst *instruction;
+extern const char* crx_no_op_insn[];

 /* A macro for representing the instruction "constant" opcode, that is,
    the FIXED part of the instruction. The "constant" opcode is represented
diff --git a/opcodes/ChangeLog b/opcodes/ChangeLog
index 94a6a6ba12b42643830feeff36fbc43040485322..4ee9a83ad40935be7720e9d662365d4cd371aa5d 100644
--- a/opcodes/ChangeLog
+++ b/opcodes/ChangeLog
@@ -1,3 +1,16 @@
+2017-10-25  Alan Modra  <amodra@gmail.com>
+
+	PR 22348
+	* cr16-dis.c (cr16_cinvs, instruction, cr16_currInsn): Make static.
+	(cr16_words, cr16_allWords, processing_argument_number): Likewise.
+	(imm4flag, size_changed): Likewise.
+	* crx-dis.c (crx_cinvs, NUMCINVS, instruction, currInsn): Likewise.
+	(words, allWords, processing_argument_number): Likewise.
+	(cst4flag, size_changed): Likewise.
+	* crx-opc.c (crx_cst4_map): Rename from cst4_map.
+	(crx_cst4_maps): Rename from cst4_maps.
+	(crx_no_op_insn): Rename from no_op_insn.
+
 2016-06-29  Tristan Gingold  <gingold@adacore.com>

 	* configure: Regenerate.
diff --git a/opcodes/cr16-dis.c b/opcodes/cr16-dis.c
index 00c672e4bc7f34a622641225f28048555acf9f49..2c74bc2fcf00cf1d4bae489df7758097dbea5bf5 100644
--- a/opcodes/cr16-dis.c
+++ b/opcodes/cr16-dis.c
@@ -54,7 +54,7 @@ typedef struct
 cinv_entry;

 /* CR16 'cinv' options mapping.  */
-const cinv_entry cr16_cinvs[] =
+static const cinv_entry cr16_cinvs[] =
 {
   {"cinv[i]",     "cinv    [i]"},
   {"cinv[i,u]",   "cinv    [i,u]"},
@@ -78,20 +78,20 @@ typedef enum REG_ARG_TYPE
 REG_ARG_TYPE;

 /* Current opcode table entry we're disassembling.  */
-const inst *instruction;
+static const inst *instruction;
 /* Current instruction we're disassembling.  */
-ins cr16_currInsn;
+static ins cr16_currInsn;
 /* The current instruction is read into 3 consecutive words.  */
-wordU cr16_words[3];
+static wordU cr16_words[3];
 /* Contains all words in appropriate order.  */
-ULONGLONG cr16_allWords;
+static ULONGLONG cr16_allWords;
 /* Holds the current processed argument number.  */
-int processing_argument_number;
+static int processing_argument_number;
 /* Nonzero means a IMM4 instruction.  */
-int imm4flag;
+static int imm4flag;
 /* Nonzero means the instruction's original size is
    incremented (escape sequence is used).  */
-int size_changed;
+static int size_changed;


 /* Print the constant expression length.  */
diff --git a/opcodes/crx-dis.c b/opcodes/crx-dis.c
index 893dcc519f783761331c858ba9ee8536fbdadc56..4cc9d8015de809f5cb0323e2d564c7a88de13526 100644
--- a/opcodes/crx-dis.c
+++ b/opcodes/crx-dis.c
@@ -58,7 +58,7 @@ typedef struct
 cinv_entry;

 /* CRX 'cinv' options.  */
-const cinv_entry crx_cinvs[] =
+static const cinv_entry crx_cinvs[] =
 {
   {"[i]", 2}, {"[i,u]", 3}, {"[d]", 4}, {"[d,u]", 5},
   {"[d,i]", 6}, {"[d,i,u]", 7}, {"[b]", 8},
@@ -81,22 +81,22 @@ typedef enum REG_ARG_TYPE
 REG_ARG_TYPE;

 /* Number of valid 'cinv' instruction options.  */
-int NUMCINVS = ((sizeof crx_cinvs)/(sizeof crx_cinvs[0]));
+static int NUMCINVS = ((sizeof crx_cinvs)/(sizeof crx_cinvs[0]));
 /* Current opcode table entry we're disassembling.  */
-const inst *instruction;
+static const inst *instruction;
 /* Current instruction we're disassembling.  */
-ins currInsn;
+static ins currInsn;
 /* The current instruction is read into 3 consecutive words.  */
-wordU words[3];
+static wordU words[3];
 /* Contains all words in appropriate order.  */
-ULONGLONG allWords;
+static ULONGLONG allWords;
 /* Holds the current processed argument number.  */
-int processing_argument_number;
+static int processing_argument_number;
 /* Nonzero means a CST4 instruction.  */
-int cst4flag;
+static int cst4flag;
 /* Nonzero means the instruction's original size is
    incremented (escape sequence is used).  */
-int size_changed;
+static int size_changed;

 static int get_number_of_operands (void);
 static argtype getargtype     (operand_type);
diff --git a/opcodes/crx-opc.c b/opcodes/crx-opc.c
index c014c7a484bb1aaee0455aa66841398aef017c9c..e8b233b4389d1a9017dead2b74c93af3c978a145 100644
--- a/opcodes/crx-opc.c
+++ b/opcodes/crx-opc.c
@@ -704,15 +704,15 @@ The value in entry <N> is mapped to the value <N>
 Example (for N=5):

     cst4_map[5]=-4  -->>	5		*/
-const int cst4_map[] =
+const int crx_cst4_map[] =
 {
   0, 1, 2, 3, 4, -4, -1, 7, 8, 16, 32, 20, 12, 48
 };

-const int cst4_maps = ARRAY_SIZE (cst4_map);
+const int crx_cst4_maps = ARRAY_SIZE (crx_cst4_map);

 /* CRX instructions that don't have arguments.  */
-const char* no_op_insn[] =
+const char* crx_no_op_insn[] =
 {
   "di", "ei", "eiwait", "nop", "retx", "wait", NULL
 };
