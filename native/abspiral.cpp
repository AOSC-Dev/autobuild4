#include "abspiral.hpp"
#include "stdwrapper.hpp"

#include <memory>
#include <vector>
#include <fstream>
#include <unordered_map>

using lut_t = std::unordered_map<std::string, std::string>;

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
    auto key = line.substr(0, delim_pos);
    auto value = line.substr(delim_pos + 1, line.size());
    lut.emplace(key, value);
  }
  return 0;
}

static std::unique_ptr<std::string>
lut_lookup(const lut_t &lut,
           const std::string &key) {
  const auto search = lut.find(key);
  if (search != lut.end()) {
    return std::unique_ptr<std::string> (new std::string (search->second));
  }
  return std::unique_ptr<std::string> {};
}

static inline std::unique_ptr<std::string>
without_sover(const std::string &soname) {
  const size_t suffix_pos = soname.find(".so");
  if (suffix_pos == std::string::npos) return std::unique_ptr<std::string> {};
  return std::unique_ptr<std::string> (new std::string (soname.substr(0, suffix_pos + 3)));
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
    const auto provides = lut_lookup(lut, soname);
    if (provides) spiral_provides.emplace(*provides);
    const auto lib = without_sover(soname);
    if (! lib) continue;
    const auto provides_dev = lut_lookup(lut, *lib);
    if (provides_dev) spiral_provides.emplace(*provides_dev);
  }
  return 0;
}
