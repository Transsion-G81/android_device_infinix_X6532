#include <string>
#include <android-base/file.h>

namespace android {
namespace base {
bool WriteStringToFd(const std::string& content, borrowed_fd fd) {
    return WriteStringToFd(std::string_view(content), fd);
}
}  // namespace base
}  // namespace android
