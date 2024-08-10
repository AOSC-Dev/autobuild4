#include "logger.hpp"
#include "abconfig.h"
#include "stdwrapper.hpp"

#include <fstream>
#include <iostream>

#include <nlohmann/json.hpp>

typedef std::lock_guard<std::mutex> io_lock_guard;

inline const char *level_to_string(const LogLevel level) {
  switch (level) {
  case LogLevel::Debug:
    return "DEBUG";
  case LogLevel::Info:
    return "INFO";
  case LogLevel::Warning:
    return "WARN";
  case LogLevel::Error:
    return "ERROR";
  case LogLevel::Critical:
    return "CRIT";
  }
  return "UNK";
}

void NoLogger::log(const LogLevel lvl, const std::string message) {
  return;
}

void NoLogger::logException(const std::string message) {
  io_lock_guard guard(this->m_io_mutex);
  std::cerr << "autobuild encountered an error and couldn't continue."
            << std::endl;
  if (!message.empty()) {
    std::cerr << message << std::endl;
  } else {
    std::cerr << "Look at the stacktrace to see what happened." << std::endl;
  }
  fprintf(stderr,
          "------------------------------autobuild "
          "%s------------------------------\n",
          ab_version);
  fprintf(stderr, "Go to %s for more information on this error.\n", ab_url);
}

void NoLogger::logDiagnostic(Diagnostic diagnostic) {
  this->error("Build error detected ^o^");
  for (const auto &diag : diagnostic.frames) {
    const auto filename = diag.file.empty() ? "<unknown>" : diag.file;
    const auto function = (diag.function.empty() || diag.function == "source")
                              ? "<unknown>"
                              : diag.function;
    io_lock_guard guard(this->m_io_mutex);
    printf("%s(%zu): In function `%s':\n", filename.c_str(), diag.line,
           function.c_str());
  }
  std::cerr << fmt::format("Command exited with {0}.", diagnostic.code)
            << std::endl;
}

void PlainLogger::log(const LogLevel lvl, const std::string message) {
  io_lock_guard guard(this->m_io_mutex);
  switch (lvl) {
  case LogLevel::Info:
    std::cout << "[INFO]:  ";
    break;
  case LogLevel::Warning:
    std::cout << "[WARN]:  ";
    break;
  case LogLevel::Error:
    std::cout << "[ERROR]: ";
    break;
  case LogLevel::Critical:
    std::cout << "[CRIT]:  ";
    break;
  case LogLevel::Debug:
    std::cout << "[DEBUG]: ";
    break;
  }

  std::cout << message << std::endl;
  std::cout.flush();
}

void PlainLogger::logDiagnostic(Diagnostic diagnostic) {
  this->error("Build error detected ^o^");
  for (const auto &diag : diagnostic.frames) {
    const auto filename = diag.file.empty() ? "<unknown>" : diag.file;
    const auto function = (diag.function.empty() || diag.function == "source")
                              ? "<unknown>"
                              : diag.function;
    io_lock_guard guard(this->m_io_mutex);
    printf("%s(%zu): In function `%s':\n", filename.c_str(), diag.line,
           function.c_str());
  }
  std::cerr << fmt::format("Command exited with {0}.", diagnostic.code)
            << std::endl;
}

void PlainLogger::logException(std::string message) {
  io_lock_guard guard(this->m_io_mutex);
  std::cerr << "autobuild encountered an error and couldn't continue."
            << std::endl;
  if (!message.empty()) {
    std::cerr << message << std::endl;
  } else {
    std::cerr << "Look at the stacktrace to see what happened." << std::endl;
  }
  fprintf(stderr,
          "------------------------------autobuild "
          "%s------------------------------\n",
          ab_version);
  fprintf(stderr, "Go to %s for more information on this error.\n", ab_url);
}

using json = nlohmann::json;

void JsonLogger::log(LogLevel lvl, std::string message) {
  const json line = {
      {"event", "log"}, {"level", level_to_string(lvl)}, {"message", message}};
  io_lock_guard guard(this->m_io_mutex);
  std::cout << line.dump() << std::endl;
}

void JsonLogger::logDiagnostic(Diagnostic diagnostic) {
  json line = {{"event", "diagnostic"},
               {"level", level_to_string(diagnostic.level)},
               {"exit_code", diagnostic.code}};
  line["frames"] = json::array();
  for (const auto &frame : diagnostic.frames) {
    line["frames"].push_back({{"file", frame.file},
                              {"line", frame.line},
                              {"function", frame.function}});
  }
  io_lock_guard guard(this->m_io_mutex);
  std::cout << line.dump() << std::endl;
}

void JsonLogger::logException(std::string message) {
  const json line = {
      {"event", "exception"}, {"level", "CRIT"}, {"message", message}};
  io_lock_guard guard(this->m_io_mutex);
  std::cout << line.dump() << std::endl;
}

void ColorfulLogger::log(LogLevel lvl, std::string message) {
  io_lock_guard guard(this->m_io_mutex);
  switch (lvl) {
  case LogLevel::Info:
    std::cout << "[\x1b[96mINFO\x1b[0m]:  ";
    break;
  case LogLevel::Warning:
    std::cout << "[\x1b[33mWARN\x1b[0m]:  ";
    break;
  case LogLevel::Error:
    std::cout << "[\x1b[31mERROR\x1b[0m]: ";
    break;
  case LogLevel::Critical:
    std::cout << "[\x1b[93mCRIT\x1b[0m]:  ";
    break;
  case LogLevel::Debug:
    std::cout << "[\x1b[32mDEBUG\x1b[0m]: ";
    break;
  }

  std::cout << "\x1b[1m" << message << "\x1b[0m" << std::endl;
  std::cout.flush();
}

static std::string get_snippet(const std::string &filename, const size_t line) {
  std::ifstream file{filename};
  if (!file.is_open()) {
    return "";
  }
  std::string formatted_snippet{};
  std::string line_str{};
  size_t line_num = 0;
  while (std::getline(file, line_str)) {
    line_num++;
    if (line_num < (line + 2) && line_num > (line - 2)) {
      formatted_snippet +=
          fmt::format("{0}{1:>4} | {2}\e[0m\n",
                      line_num == line ? "\e[1m>" : " ", line_num, line_str);
      continue;
    }
  }

  return formatted_snippet;
}

void ColorfulLogger::logDiagnostic(Diagnostic diagnostic) {
  std::string buffer{};
  // reverse order, most recent call last
  for (auto it = diagnostic.frames.rbegin(); it != diagnostic.frames.rend();
       ++it) {
    const auto &frame = *it;
    if (buffer.empty()) {
      // first call
      buffer += fmt::format("\e[0mIn file included from \e[1m{0}:{1}\n",
                            frame.file, frame.line);
      continue;
    }
    if ((it + 1) == diagnostic.frames.rend()) {
      // last call
      buffer +=
          fmt::format("{0}:{1}: \e[0mIn function `\e[1m{2}':\n"
                      "{0}:{1}: \e[91merror: \e[39mcommand exited with "
                      "\e[93m{3}\e[39m\e[0m\n",
                      frame.file, frame.line, frame.function, diagnostic.code);
      buffer += get_snippet(frame.file, frame.line);
      continue;
    }
    buffer += fmt::format("\e[0m                 from \e[1m{0}:{1}\n",
                          frame.file, frame.line);
  }

  io_lock_guard guard(this->m_io_mutex);
  std::cerr << buffer << std::endl;
}

void ColorfulLogger::logException(std::string message) {
  io_lock_guard guard(this->m_io_mutex);
  std::cerr << "\x1b[1;31m"
            << "autobuild encountered an error and couldn't continue."
            << "\x1b[0m" << std::endl;
  if (!message.empty()) {
    std::cerr << message << std::endl;
  } else {
    std::cerr << "Look at the stacktrace to see what happened." << std::endl;
  }
  fprintf(stderr,
          "------------------------------autobuild "
          "%s------------------------------\n",
          ab_version);
  std::string colored_url{"‘\e[1m"};
  colored_url += ab_url;
  colored_url += "\x1b[0m’";
  fprintf(stderr, "Go to %s for more information on this error.\n",
          colored_url.c_str());
}
