#pragma once

#include <string>
#include <vector>

std::string
autobuild_serialized_variables(const std::vector<std::string> &variables);
int autobuild_deserialize_variable(const std::string &content, const std::string &query, const std::string &var_name, const bool allow_failure = false);
