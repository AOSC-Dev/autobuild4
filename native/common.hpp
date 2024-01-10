#pragma once

#include <cstdint>
#include <string>
#include <vector>

enum class LogLevel : uint8_t {
  Debug,
  Info,
  Warning,
  Error,
  Critical,
};

enum class VersionOp: uint8_t {
  INVALID,
  // <<
  Lt,
  // <=
  Le,
  // >>
  Gt,
  // >=
  Ge,
  // =
  Eq,
  // unused
  Ne,
};

struct DiagnosticFrame {
  std::string file;
  std::string function;
  uintptr_t line;
};

struct Diagnostic {
  LogLevel level;
  int code;
  std::vector<DiagnosticFrame> frames;
};
