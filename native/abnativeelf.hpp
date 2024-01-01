#pragma once

#include <cstdint>
#include <string>
#include <unordered_set>
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
  bool has_debug_info;
};

constexpr int AB_ELF_STRIP_ONLY = 1 << 0;
constexpr int AB_ELF_USE_EU_STRIP = 1 << 1;
constexpr int AB_ELF_FIND_SO_DEPS = 1 << 2;

int elf_copy_to_symdir(const char *src_path, const char *dst_path,
                       const char *build_id);
int elf_copy_debug_symbols(const char *src_path, const char *dst_path,
                           int flags, std::unordered_set<std::string> &so_deps);
int elf_copy_debug_symbols_parallel(const std::vector<std::string> &directories,
                                    const char *dst_path);
