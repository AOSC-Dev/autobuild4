#pragma once

#include <condition_variable>
#include <deque>
#include <functional>
#include <mutex>
#include <thread>
#include <vector>

template <typename T> class ThreadPool {
  using processor_func_t = std::function<void(T &)>;

public:
  ThreadPool(processor_func_t processor,
             int thread_num = std::thread::hardware_concurrency())
      : m_waker(), m_queue({}), m_stop(false), m_processor(processor) {
    for (int i = 0; i < thread_num; ++i) {
      m_workers.emplace_back(std::thread{[&] {
        while (true) {
          std::unique_lock<std::mutex> lock(m_mutex);
          m_waker.wait(lock, [&] { return !m_queue.empty(); });
          if (m_queue.empty() && m_stop) {
            break;
          }
          auto task = std::move(m_queue.back());
          m_queue.pop_back();
          m_processor(task);
          lock.unlock();
        }
      }});
    }
  }
  ~ThreadPool() {
    stop();
    for (auto &worker : m_workers) {
      worker.join();
    }
  }
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

private:
  std::vector<std::thread> m_workers;
  std::condition_variable m_waker;
  std::mutex m_mutex;
  std::deque<T> m_queue;
  bool m_stop;
  processor_func_t m_processor;
};
