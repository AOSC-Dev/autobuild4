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

std::string
autobuild_serialized_variables(const std::vector<std::string> &variables) {
  json j{};
  for (const auto &variable : variables) {
    j[variable] = json_from_shell_var(find_variable(variable.c_str()));
  }
  return j.dump();
}
