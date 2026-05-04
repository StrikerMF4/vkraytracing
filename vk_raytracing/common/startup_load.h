#pragma once

#include <atomic>
#include <mutex>
#include <stdexcept>
#include <string>

namespace StartupLoad
{
struct Snapshot
{
  std::string detail;
  std::string error;
};

class Feedback
{
public:
  void requestCancel()
  {
    m_cancelRequested.store(true, std::memory_order_relaxed);
  }

  bool isCancelRequested() const
  {
    return m_cancelRequested.load(std::memory_order_relaxed);
  }

  void setDetail(const std::string& detail)
  {
    std::lock_guard<std::mutex> lock(m_mutex);
    m_detail = detail;
  }

  void setError(const std::string& error)
  {
    std::lock_guard<std::mutex> lock(m_mutex);
    m_error = error;
  }

  Snapshot snapshot() const
  {
    std::lock_guard<std::mutex> lock(m_mutex);
    return {m_detail, m_error};
  }

private:
  mutable std::mutex m_mutex;
  std::atomic<bool>  m_cancelRequested{false};
  std::string        m_detail;
  std::string        m_error;
};

class Cancelled : public std::runtime_error
{
public:
  explicit Cancelled(const std::string& message)
      : std::runtime_error(message)
  {
  }
};

inline void throwIfCancelled(Feedback* feedback)
{
  if(feedback != nullptr && feedback->isCancelRequested())
    throw Cancelled("La carga inicial fue cancelada.");
}
}  // namespace StartupLoad
