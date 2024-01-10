#pragma once

#include <string>
#include <vector>
#include <unordered_map>

std::vector<std::string> jsondata_get_exported_vars(const std::string &ab_path);
std::unordered_map<std::string, std::string> jsondata_get_arch_targets(const std::string &ab_path);
std::vector<std::string> jsondata_get_arch_groups(const std::string &ab_path, const std::string &this_arch);
std::string jsondata_serialize_map(const std::unordered_map<std::string, const char*> &map);
