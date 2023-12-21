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

struct DiagnosticFrame {
  std::string file;
  std::string function;
  uintptr_t line;
};

struct Diagnostic {
  LogLevel level;
  std::string message;
  std::vector<DiagnosticFrame> frames;
};
