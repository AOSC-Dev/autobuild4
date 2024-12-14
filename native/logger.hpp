#pragma once

#include <cstdint>
#include <mutex>
#include <vector>

#include "common.hpp"

class BaseLogger {
public:
  BaseLogger() : m_io_mutex(), m_level(LogLevel::Info){};
  virtual ~BaseLogger() = default;
  virtual void log(LogLevel lvl, std::string message) = 0;
  virtual void logDiagnostic(Diagnostic diagnostic) = 0;
  virtual void logException(std::string message) = 0;
  virtual const char *loggerName() = 0;
  inline void setLogLevel(const LogLevel lvl) { m_level = lvl; }
  inline void info(const std::string &message) { log(LogLevel::Info, message); }
  inline void debug(const std::string &message) {
    log(LogLevel::Debug, message);
  }
  inline void warning(const std::string &message) {
    log(LogLevel::Warning, message);
  }
  inline void error(const std::string &message) {
    log(LogLevel::Error, message);
  }

protected:
  std::mutex m_io_mutex;

private:
  LogLevel m_level;
};

class NullLogger final : public BaseLogger {
public:
  NullLogger() {}
  void log(LogLevel lvl, std::string message) override;
  void logDiagnostic(Diagnostic diagnostic) override;
  void logException(std::string message) override;
  const char *loggerName() override { return "NullLogger"; }
};

class PlainLogger final : public BaseLogger {
public:
  PlainLogger() {}
  void log(LogLevel lvl, std::string message) override;
  void logDiagnostic(Diagnostic diagnostic) override;
  void logException(std::string message) override;
  const char *loggerName() override { return "PlainLogger"; }
};

class JsonLogger final : public BaseLogger {
public:
  JsonLogger() {}
  void log(LogLevel lvl, std::string message) override;
  void logDiagnostic(Diagnostic diagnostic) override;
  void logException(std::string message) override;
  const char *loggerName() override { return "JsonLogger"; }
};

class ColorfulLogger final : public BaseLogger {
public:
  ColorfulLogger() {}
  void log(LogLevel lvl, std::string message) override;
  void logDiagnostic(Diagnostic diagnostic) override;
  void logException(std::string message) override;
  const char *loggerName() override { return "ColorfulLogger"; }
};
