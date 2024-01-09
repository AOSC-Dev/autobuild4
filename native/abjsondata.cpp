#include <fstream>
#include <nlohmann/json.hpp>

#include "abjsondata.hpp"

using json = nlohmann::json;

std::vector<std::string>
jsondata_get_exported_vars(const std::string &ab_path) {
  const std::string exported_vars_path = ab_path + "/sets/exports.json";
  std::ifstream exported_vars_file(exported_vars_path);
  json exported_vars_json = json::parse(exported_vars_file);
  std::vector<std::string> exported_vars;
  exported_vars.reserve(64);
  for (json::iterator it = exported_vars_json.begin();
       it != exported_vars_json.end(); ++it) {
    const auto inner_array =
        it.value().template get<std::vector<std::string>>();
    exported_vars.insert(exported_vars.end(), inner_array.begin(),
                         inner_array.end());
  }

  return exported_vars;
}

std::unordered_map<std::string, std::string>
jsondata_get_arch_targets(const std::string &ab_path) {
  // read targets
  const auto arch_targets_path = ab_path + "/sets/arch_targets.json";
  std::ifstream targets_file(arch_targets_path);
  json arch_targets = json::parse(targets_file);
  auto arch_target_var = std::unordered_map<std::string, std::string>{};
  for (json::iterator it = arch_targets.begin(); it != arch_targets.end();
       ++it) {
    arch_target_var.insert(it.key(), it.value().template get<std::string>());
  }
  return arch_target_var;
}

std::vector<std::string>
jsondata_get_arch_groups(const std::string &ab_path,
                         const std::string &this_arch) {
  const auto arch_groups_path = ab_path + "/sets/arch_groups.json";
  std::vector<std::string> groups{};
  std::ifstream groups_file(arch_groups_path);
  json arch_groups = json::parse(groups_file);
  for (json::iterator it = arch_groups.begin(); it != arch_groups.end(); ++it) {
    const auto &group_name = it.key();
    auto group = it.value();
    // search inner array for the target architecture name
    for (json::iterator it = group.begin(); it != group.end(); ++it) {
      const auto arch_value = it.value().template get<std::string>();
      if (arch_value == this_arch) {
        // append the group name to the array
        groups.push_back(group_name);
      }
    }
  }

  return groups;
}
