#pragma once

#include <condition_variable>
#include <deque>
#include <functional>
#include <mutex>
#include <thread>
#include <vector>

#if __cplusplus >= 201703L && !defined(IFCONSTEXPR)
#define IFCONSTEXPR constexpr
#else
#define IFCONSTEXPR
#endif

template <typename T, typename R> class ThreadPool {
  using processor_func_t = std::function<R(T &)>;

  inline static int process_for_result(std::function<void(T &)> &func,
                                       T &data) {
    func(data);
    return 0;
  }

  inline static int process_for_result(std::function<int(T &)> &func, T &data) {
    return func(data);
  }

public:
  explicit ThreadPool(processor_func_t processor,
                      const unsigned int thread_num = std::thread::hardware_concurrency())
      : m_waker(), m_queue({}), m_stop(false), m_has_error(false),
        m_processor(std::move(processor)) {
    for (int i = 0; i < thread_num; ++i) {
      m_workers.emplace_back(std::thread{[&] {
        while (true) {
          std::unique_lock<std::mutex> lock(m_mutex);
          m_waker.wait(lock, [&] { return !m_queue.empty() || m_stop; });
          if (m_queue.empty() && m_stop) {
            lock.unlock();
            break;
          }
          auto task = std::move(m_queue.back());
          m_queue.pop_back();
          lock.unlock();
          if (process_for_result(m_processor, task) != 0)
            m_has_error = true;
        }
      }});
    }
  }
  ~ThreadPool() { wait_for_completion(); }
  void enqueue(T &&task) {
    std::lock_guard<std::mutex> lock(m_mutex);
    m_queue.emplace_back(std::move(task));
    m_waker.notify_all();
  }
  void stop() {
    std::lock_guard<std::mutex> lock(m_mutex);
    m_stop = true;
    m_waker.notify_all();
  }
  void wait_for_completion() {
    stop();
    for (auto &worker : m_workers) {
      if (worker.joinable())
        worker.join();
    }
  }
  bool has_error() const { return m_has_error; }

private:
  std::vector<std::thread> m_workers;
  std::condition_variable m_waker;
  std::mutex m_mutex;
  std::deque<T> m_queue;
  bool m_stop;
  bool m_has_error;
  processor_func_t m_processor;
};
