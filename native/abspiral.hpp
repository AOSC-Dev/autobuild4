#pragma once

#include <vector>
#include <unordered_set>

int spiral_from_sonames(const std::vector<std::string> &sonames,
                        std::unordered_set<std::string> &spiral_provides);
