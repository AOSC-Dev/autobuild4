#include "abspiral.hpp"
#include "stdwrapper.hpp"

#include <memory>
#include <unordered_map>
#include <vector>

using lut_t = std::unordered_map<std::string, std::unordered_set<std::string>>;
// defined in abspiral_data.cpp
extern const char *lut_lookup(const char *soname);

void insert_from_lut(const std::string &key, const std::string &suffix,
                     std::unordered_set<std::string> &out) {
  const auto search = lut_lookup(key.c_str());
  if (search) {
    const std::string package_string{search};
    std::unordered_set<std::string> package_names;
    size_t pos = 0, prev_pos = 0;
    while ((pos = package_string.find(',', pos)) != std::string::npos) {
      package_names.emplace(package_string.substr(prev_pos, pos - prev_pos));
      prev_pos = ++pos;
    }
    if (prev_pos < package_string.length()) {
      package_names.emplace(package_string.substr(prev_pos));
    }
    for (const auto &prov : package_names) {
      out.emplace(fmt::format("{0}{1}", prov, suffix));
      // Package names can't just be t64 and considered a suffix, a suffixed
      // package name should always have a length of >= 4.
      if (prov.size() < 4) {
        continue;
      }
      if (prov.substr(prov.size() - 4, prov.size() - 1) == "t64") {
        out.emplace(
            fmt::format("{0}{1}", prov.substr(0, prov.size() - 3), suffix));
      }
    }
  }
}

int spiral_from_sonames(const std::vector<std::string> &sonames,
                        std::unordered_set<std::string> &spiral_provides) {
  for (const auto &soname_and_arch : sonames) {
    std::string soname{};
    std::string arch_suffix;
    const size_t delim_pos = soname_and_arch.find(':');
    if (delim_pos != std::string::npos) {
      soname = soname_and_arch.substr(0, delim_pos);
      arch_suffix = soname_and_arch.substr(delim_pos, soname_and_arch.length());
    } else {
      soname = soname_and_arch;
    }
    insert_from_lut(soname, arch_suffix, spiral_provides);
    const size_t suffix_pos = soname.find(".so");
    if (suffix_pos == std::string::npos)
      continue;
    insert_from_lut(soname.substr(0, suffix_pos + 3), arch_suffix,
                    spiral_provides);
  }
  return 0;
}
