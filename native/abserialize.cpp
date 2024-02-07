#include <nlohmann/json.hpp>

#include "abserialize.hpp"

extern "C" {
#include "bashincludes.h"
}

using json = nlohmann::json;

inline static json json_from_shell_var(SHELL_VAR *var) {
  if (!var)
    return {};

  json j{};
  if (var->attributes & att_integer) {
    j = var->value;
  } else if (var->attributes & att_function) {
    j = make_command_string(function_cell(var));
  } else if (var->attributes & att_array) {
    j = json::array();
    const ARRAY *ag_a = array_cell(var);
    for (ARRAY_ELEMENT *ae = element_forw(ag_a->head); ae != ag_a->head;
         ae = element_forw(ae)) {
      j.push_back(ae->value);
    }
  } else if (var->attributes & att_assoc) {
    j = json::object();
    const HASH_TABLE *ag_h = assoc_cell(var);
    for (size_t i = 0; i < ag_h->nbuckets; i++) {
      const auto *bucket = ag_h->bucket_array[i];
      for (const BUCKET_CONTENTS *bc = bucket; bc; bc = bc->next) {
        j[bc->key] = static_cast<char *>(bc->data);
      }
    }
  } else {
    j = var->value;
  }

  return j;
}

static SHELL_VAR *shell_var_from_json(json &input, const char *name) {
  if (input.is_discarded())
    return nullptr;
  SHELL_VAR *var = bind_variable(name, nullptr, ASS_FORCE);
  if (input.is_null()) {
    return var;
  }
  if (input.is_string()) {
    const auto str = input.template get<std::string>();
    var->value = strdup(str.c_str());
  } else if (input.is_boolean()) {
    const auto value = input.template get<bool>();
    var->value = strdup(value ? "1" : "0");
  } else if (input.is_number_integer()) {
    const auto value = input.template get<int>();
    var->value = itos(value);
    var->attributes |= att_integer;
  } else {
    return nullptr;
  }
  return var;
}

int autobuild_deserialize_variable(const std::string &content,
                                   const std::string &query,
                                   const std::string &var_name,
                                   const bool allow_failure) {
  json data = json::parse(content, nullptr, false);
  if (data.is_discarded())
    return 1;
  size_t start = 0;
  bool started = false;
  for (size_t i = 0; i < query.size(); i++) {
    if (query[i] == '[') {
      start = i + 1;
      started = true;
    } else if (query[i] == ']' && i > 0 && query[i - 1] != '\\') {
      started = false;
      auto key = query.substr(start, i - start - 1);
      if (!key.empty() && key[0] == '\'') {
        key = key.substr(1, key.size() - 1);
        try {
          data = data[key];
        } catch (...) {
          if (!allow_failure)
            return 3;
        }
      } else {
        const auto *key_str = key.c_str();
        char *endp = nullptr;
        const auto idx = std::strtol(key_str, &endp, 10);
        if (endp != key_str + key.size()) {
          return 2;
        }
        try {
          data = data[idx];
        } catch (...) {
          if (!allow_failure)
            return 3;
        }
      }
    } else if (!started) {
      return 2;
    }
  }

  if (!shell_var_from_json(data, var_name.c_str())) {
    return 4;
  }
  return 0;
}

std::string
autobuild_serialized_variables(const std::vector<std::string> &variables) {
  json j{};
  for (const auto &variable : variables) {
    j[variable] = json_from_shell_var(find_variable(variable.c_str()));
  }
  return j.dump();
}
