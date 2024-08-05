#include "abspiral.hpp"
#include "stdwrapper.hpp"

#include <memory>
#include <vector>
#include <fstream>
#include <unordered_map>

using lut_t = std::unordered_map<std::string, std::unordered_set<std::string>>;

static int
lut_read(const fs::path &file, lut_t &lut) {
  std::ifstream f(file);
  if (! f.is_open()) {
    return -1;
  }
  std::string line;
  while (std::getline(f, line)) {
    const size_t delim_pos = line.find(',');
    if (delim_pos == std::string::npos) return -1;
    const auto key = line.substr(0, delim_pos);
    if (const auto search = lut.find(key); search == lut.end()) {
      lut.emplace(key, std::unordered_set<std::string>());
    }
    std::unordered_set<std::string> &target = lut.find(key)->second;

    auto value = line.substr(delim_pos + 1, line.size());
    size_t pos;
    std::string token;
    while ((pos = value.find(',')) != std::string::npos) {
      target.emplace(value.substr(0, pos));
      value.erase(0, pos + 1);
    }
    target.emplace(value.substr(0, value.size()));
  }
  return 0;
}

void
insert_from_lut(const lut_t &lut,
                const std::string &key,
                const std::string &suffix,
                std::unordered_set<std::string> &out) {
  const auto search = lut.find(key);
  if (search != lut.end()) {
    for (const auto &prov : search->second) {
      out.emplace(fmt::format("{0}{1}", prov, suffix));
      // Package names can't just be t64 and considered a suffix, a suffixed
      // package name should always have a length of >= 4.
      if (prov.size() < 4) {
        continue;
      }
      if (prov.substr(prov.size() - 4, prov.size() - 1) == "t64") {
        out.emplace(fmt::format("{0}{1}", prov.substr(0, prov.size() - 3), suffix));
      }
    }
  }
}

int
spiral_from_sonames(const std::string &lut_file,
                    const std::vector<std::string> &sonames,
                    std::unordered_set<std::string> &spiral_provides) {
  lut_t lut;
  if (lut_read(lut_file, lut) != 0) {
    return 1;
  }
  for (const auto &soname_and_arch: sonames) {
    std::string soname{};
    std::string arch_suffix;
    const size_t delim_pos = soname_and_arch.find(':');
    if (delim_pos != std::string::npos) {
      soname = soname_and_arch.substr(0, delim_pos);
      arch_suffix = soname_and_arch.substr(delim_pos, soname_and_arch.length());
    } else {
      soname = soname_and_arch;
    }
    insert_from_lut(lut, soname, arch_suffix, spiral_provides);
    const size_t suffix_pos = soname.find(".so");
    if (suffix_pos == std::string::npos)
      continue;
    insert_from_lut(lut, soname.substr(0, suffix_pos + 3), arch_suffix, spiral_provides);
  }
  return 0;
}
