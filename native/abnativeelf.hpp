#pragma once

#include <cstdint>
#include <mutex>
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
  std::string soname;
  BinaryType bin_type;
  bool has_debug_info;
};

template <typename T> class GuardedSet {
public:
  GuardedSet() = default;
  GuardedSet(std::unordered_set<T> set) : m_set{std::move(set)} {}
  template <typename Iterator> void insert(Iterator begin, Iterator end) {
    auto lock_guard = std::lock_guard<std::mutex>{m_mutex};
    m_set.insert(begin, end);
  }
  const std::unordered_set<T> &get_set() const { return m_set; }

private:
  std::mutex m_mutex;
  std::unordered_set<T> m_set;
};

constexpr int AB_ELF_STRIP_ONLY = 1 << 0;
constexpr int AB_ELF_USE_EU_STRIP = 1 << 1;
constexpr int AB_ELF_FIND_SO_DEPS = 1 << 2;
constexpr int AB_ELF_CHECK_ONLY = 1 << 3;
constexpr int AB_ELF_SAVE_WITH_PATH = 1 << 4;

int elf_copy_to_symdir(const char *src_path, const char *dst_path,
                       const char *build_id);
int elf_copy_debug_symbols(const char *src_path, const char *dst_path,
                           int flags, GuardedSet<std::string> &symbols);
int elf_copy_debug_symbols_parallel(const std::vector<std::string> &directories,
                                    const char *dst_path,
                                    std::unordered_set<std::string> &so_deps,
                                    int flags = AB_ELF_USE_EU_STRIP);
