#pragma once

#ifdef HAS_STD_FS
#include <filesystem>
namespace fs = std::filesystem;
#else
#include <boost/filesystem.hpp>
namespace fs = boost::filesystem;
#endif

#ifdef HAS_STD_FORMAT
#include <format>
using fmt = std::format;
#else
#include <boost/format.hpp>
using fmt = boost::format;
#endif
