#pragma once

#ifdef HAS_STD_FS
#include <filesystem>
namespace fs = std::filesystem;
#else
#include <boost/filesystem.hpp>
namespace fs = boost::filesystem;
#endif

#ifdef HAS_STD_FMT
#include <format>
namespace fmt = std;
#else
#define FMT_HEADER_ONLY
#include <fmt/format.h>
#endif
