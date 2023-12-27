#pragma once

#include <cstdint>
#include <string>
#include <vector>

enum class BinaryType : uint8_t {
  Invalid = 0,
  Static,
  Dynamic,
  Executable,
  Relocatable,
  KernelObject,
  LLVM_IR,
};

struct ELFParseResult {
  std::vector<const char *> needed_libs;
  std::string build_id;
  BinaryType bin_type;
};

int elf_copy_to_symdir(const char *src_path, const char *dst_path,
                       const char *build_id);
int elf_copy_debug_symbols(const char *src_path, const char *dst_path,
                           bool strip_only, bool use_eu_strip);
int elf_copy_debug_symbols_parallel(const std::vector<std::string> &directories,
                                    const char *dst_path);
