#define MAPBOX_ETERNAL_UNSAFE_ASSUME_SORTED
#include "eternal.hpp"

constexpr std::pair<const mapbox::eternal::string,
                    const mapbox::eternal::string>
    data[] = {
      #include "../data/lut_sonames.cpp.inc"
    };
MAPBOX_ETERNAL_CONSTEXPR auto spiral_lut = mapbox::eternal::map(data);

const char* lut_lookup(const char* soname) {
    const auto found = spiral_lut.find(soname);
    if (found == spiral_lut.end()) return nullptr;
    return found->second.c_str();
}
