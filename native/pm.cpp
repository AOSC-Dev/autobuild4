#include "pm.hpp"

std::string autobuild_to_deb_version(const std::string &ab_version) {
  std::string name_part{};
  name_part.reserve(ab_version.size());
  VersionOp op_part{};
  std::string version_part{};
  uint8_t parser_state = 0;

  for (auto ch : ab_version) {
    switch (ch) {
    case '<':
      if (parser_state == 0) {
        parser_state = 1;
        continue;
      }
      if (parser_state == 1) {
        op_part = VersionOp::Lt;
        parser_state = 10;
        continue;
      }
      // TODO: handle invalid version
      break;
    case '>':
      if (parser_state == 0) {
        parser_state = 2;
        continue;
      }
      if (parser_state == 2) {
        op_part = VersionOp::Gt;
        parser_state = 10;
        continue;
      }
      // TODO: handle invalid version
      break;
    case '=':
      switch (parser_state) {
      case 0:
        parser_state = 3;
        continue;
      case 1:
        op_part = VersionOp::Le;
        parser_state = 10;
        continue;
      case 2:
        op_part = VersionOp::Ge;
        parser_state = 10;
        continue;
      case 3:
        op_part = VersionOp::Eq;
        parser_state = 10;
        continue;
      default:
        // TODO: handle invalid version
        break;
      }
      break;
    default:
      if (parser_state == 0)
        name_part += ch;
      if (parser_state == 10)
        version_part += ch;
      break;
    }
  }

  std::string deb_version{name_part};
  if (op_part != VersionOp::INVALID) {
    deb_version += " (";
    switch (op_part) {
    case VersionOp::Lt:
      deb_version += "<<";
      break;
    case VersionOp::Gt:
      deb_version += ">>";
      break;
    case VersionOp::Le:
      deb_version += "<=";
      break;
    case VersionOp::Ge:
      deb_version += ">=";
      break;
    case VersionOp::Eq:
      deb_version += "=";
      break;
    default:
      break;
    }
    deb_version += " " + version_part;
    deb_version += ")";
  }
  // invalid situations:
  if (deb_version.empty() && op_part == VersionOp::INVALID) {
    return {};
  }

  return deb_version;
}
