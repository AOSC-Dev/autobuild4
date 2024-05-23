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
    const auto value = line.substr(delim_pos + 1, line.size());
    const auto search = lut.find(key);
    if (search != lut.end()) {
      search->second.emplace(value);
    } else {
      lut.emplace(key, std::unordered_set<std::string>{value});
    }
  }
  return 0;
}

void
insert_from_lut(const lut_t &lut,
                const std::string &key,
                std::unordered_set<std::string> &out) {
  const auto search = lut.find(key);
  if (search != lut.end()) {
    for (const auto &prov : search->second) {
      out.emplace(prov);
      if (prov.substr(prov.size() - 4, prov.size() - 1) == "t64") {
        out.emplace(prov.substr(0, prov.size() - 3));
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
  for (const auto &soname: sonames) {
    insert_from_lut(lut, soname, spiral_provides);
    const size_t suffix_pos = soname.find(".so");
    if (suffix_pos == std::string::npos)
      continue;
    insert_from_lut(lut, soname.substr(0, suffix_pos + 3), spiral_provides);
  }
  return 0;
}
