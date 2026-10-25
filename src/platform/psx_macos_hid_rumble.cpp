// macOS DualShock 4 rumble over Bluetooth, written directly to IOKit HID.
//
// WHY THIS EXISTS: SDL's HIDAPI PS4 driver passes the Bluetooth effects report
// id to IOHIDDeviceSetReport as a separate argument and strips it from the
// payload (hidapi's convention). The DS4-compatible pads used here accept every
// such write at the API level (IOReturn 0) and ignore it, so rumble never
// starts. The convention these pads DO obey -- verified variant by variant
// against the hardware, including that a frame with a zeroed CRC leaves the
// motor running -- is: report id 0 passed to IOHIDDeviceSetReport, with the
// report id byte (0x11) inside a 78-byte buffer:
//
//   frame[0]      = 0x11   Bluetooth effects report id
//   frame[1]      = 0xC0   HID output + CRC present
//   frame[3]      = 0x03   effect mask (rumble | led)
//   frame[6]      = small / high-frequency motor (0..255)
//   frame[7]      = large / low-frequency motor  (0..255)
//   frame[74..77] = CRC32 over the byte 0xA2 followed by frame[0..73]
//
// THREADING: IOHIDDeviceSetReport is a SYNCHRONOUS Bluetooth write and measured
// 5-20 ms per call (spikes to ~78 ms) on this hardware. Calling it from the
// frame loop cost 30-90 ms frames -- a visible FPS collapse. All writes now
// happen on a dedicated worker thread; the frame loop only publishes the
// latest motor values (a one-slot mailbox, so a slow link can never build a
// queue). The pad holds its effect until told otherwise, so the worker sends on
// change and re-sends the active effect at most every kKeepaliveMs.
//
// Scope: only DS4-family pads (VID 0x054c, PID 0x05c4 / 0x09cc). Everything
// else keeps SDL's rumble path, which is correct for it.

#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

#if defined(__APPLE__)

#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/hid/IOHIDKeys.h>
#include <IOKit/hid/IOHIDManager.h>

#include <chrono>
#include <condition_variable>
#include <mutex>
#include <thread>

namespace {

constexpr int kKeepaliveMs = 100; /* ≤10 writes/s; the pad holds the effect */

IOHIDDeviceRef g_dev = nullptr;

/* --- one-slot mailbox between the frame loop and the writer thread ---------
 */
std::mutex g_mu;
std::condition_variable g_cv;
uint8_t g_req_small = 0;
uint8_t g_req_large = 0;
bool g_req_pending = false;
bool g_quit = false;
std::thread g_worker;

uint8_t g_sent_small = 0;
uint8_t g_sent_large = 0;
bool g_sent_any = false;

/* --- write-cost instrumentation (PSX_RUMBLE_TRACE=1) ---------------------- */
double now_ms(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (double)ts.tv_sec * 1000.0 + (double)ts.tv_nsec / 1e6;
}
bool trace_enabled(void) {
  static const bool on = [] {
    const char *e = getenv("PSX_RUMBLE_TRACE");
    return e && e[0] && e[0] != '0';
  }();
  return on;
}
double g_win_start = 0.0;
unsigned g_win_calls = 0;
double g_win_total_ms = 0.0;
double g_win_max_ms = 0.0;

void account_write(double ms) {
  if (!trace_enabled())
    return;
  const double t = now_ms();
  if (g_win_start == 0.0)
    g_win_start = t;
  g_win_calls++;
  g_win_total_ms += ms;
  if (ms > g_win_max_ms)
    g_win_max_ms = ms;
  if (t - g_win_start >= 1000.0) {
    fprintf(stdout,
            "psxrecomp hid-rumble: %u writes/s, avg %.2f ms, max %.2f ms "
            "(writer thread)\n",
            g_win_calls, g_win_total_ms / (double)g_win_calls, g_win_max_ms);
    fflush(stdout);
    g_win_start = t;
    g_win_calls = 0;
    g_win_total_ms = 0.0;
    g_win_max_ms = 0.0;
  }
}

uint32_t crc32_ieee(const uint8_t *data, size_t len) {
  uint32_t crc = 0xFFFFFFFFu;
  for (size_t i = 0; i < len; ++i) {
    crc ^= (uint32_t)data[i];
    for (int b = 0; b < 8; ++b)
      crc = (crc & 1u) ? ((crc >> 1) ^ 0xEDB88320u) : (crc >> 1);
  }
  return ~crc;
}

void build_frame(uint8_t small, uint8_t large, uint8_t out[78]) {
  memset(out, 0, 78);
  out[0] = 0x11;
  out[1] = 0xC0;
  out[3] = 0x03;
  out[6] = small;
  out[7] = large;
  uint8_t crc_input[75];
  crc_input[0] = 0xA2;
  memcpy(&crc_input[1], out, 74);
  const uint32_t crc = crc32_ieee(crc_input, sizeof(crc_input));
  out[74] = (uint8_t)(crc & 0xFFu);
  out[75] = (uint8_t)((crc >> 8) & 0xFFu);
  out[76] = (uint8_t)((crc >> 16) & 0xFFu);
  out[77] = (uint8_t)((crc >> 24) & 0xFFu);
}

bool write_frame(uint8_t small, uint8_t large) {
  if (!g_dev)
    return false;
  uint8_t frame[78];
  build_frame(small, large, frame);
  uint8_t buf[78];
  memcpy(buf, frame, sizeof(buf));
  const double t0 = trace_enabled() ? now_ms() : 0.0;
  const IOReturn r = IOHIDDeviceSetReport(g_dev, kIOHIDReportTypeOutput,
                                          0 /* report id */, buf, sizeof(buf));
  if (trace_enabled())
    account_write(now_ms() - t0);
  return r == kIOReturnSuccess;
}

/* Writer thread: drains the mailbox, re-sends the active effect as a keepalive,
 * and never blocks the caller of update(). A stop request is sent once, then
 * the loop idles. */
void writer_loop() {
  using namespace std::chrono;
  for (;;) {
    uint8_t s = 0, l = 0;
    bool have = false;
    {
      std::unique_lock<std::mutex> lk(g_mu);
      g_cv.wait_for(lk, milliseconds(kKeepaliveMs),
                    [&] { return g_quit || g_req_pending; });
      if (g_quit)
        break;
      if (g_req_pending) {
        s = g_req_small;
        l = g_req_large;
        g_req_pending = false;
        have = true;
      } else if (g_sent_any) {
        /* No change and the last effect is still active: refresh it so
         * a dropped Bluetooth frame cannot leave the pad silent. */
        s = g_sent_small;
        l = g_sent_large;
        have = true;
      }
    }
    if (!have)
      continue;
    /* Change of value always writes; an identical refresh also writes on
     * the keepalive tick, which is what keeps a sustained effect alive. */
    if (!g_sent_any || s != g_sent_small || l != g_sent_large || s || l) {
      (void)write_frame(s, l);
      g_sent_small = s;
      g_sent_large = l;
      g_sent_any = (s || l);
    }
  }
}

bool ds4_family(uint16_t vid, uint16_t pid) {
  /* DualShock 4 v1/v2 only. DualSense uses a different frame layout and is
   * deliberately left on SDL's path. */
  return vid == 0x054C && (pid == 0x05C4 || pid == 0x09CC);
}

} // namespace

extern "C" {

int psx_host_rumble_attach(uint16_t vid, uint16_t pid) {
  if (!ds4_family(vid, pid))
    return 0;
  if (g_dev)
    return 1;

  IOHIDManagerRef mgr =
      IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
  if (!mgr)
    return 0;

  int vid_i = (int)vid, pid_i = (int)pid;
  CFNumberRef vid_n =
      CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &vid_i);
  CFNumberRef pid_n =
      CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &pid_i);
  const void *keys[] = {CFSTR(kIOHIDVendorIDKey), CFSTR(kIOHIDProductIDKey)};
  const void *vals[] = {vid_n, pid_n};
  CFDictionaryRef match = CFDictionaryCreate(kCFAllocatorDefault, keys, vals, 2,
                                             &kCFTypeDictionaryKeyCallBacks,
                                             &kCFTypeDictionaryValueCallBacks);
  IOHIDManagerSetDeviceMatching(mgr, match);
  IOHIDManagerOpen(mgr, kIOHIDOptionsTypeNone);

  int attached = 0;
  CFSetRef devices = IOHIDManagerCopyDevices(mgr);
  if (devices) {
    const CFIndex count = CFSetGetCount(devices);
    if (count > 0) {
      const void **list = (const void **)calloc((size_t)count, sizeof(void *));
      if (list) {
        CFSetGetValues(devices, list);
        IOHIDDeviceRef dev = (IOHIDDeviceRef)list[0];
        if (IOHIDDeviceOpen(dev, kIOHIDOptionsTypeNone) == kIOReturnSuccess) {
          g_dev = dev;
          attached = 1;
        }
        free(list);
      }
    }
    CFRelease(devices);
  }
  if (!attached) {
    IOHIDManagerClose(mgr, kIOHIDOptionsTypeNone);
    CFRelease(mgr);
  }
  CFRelease(match);
  CFRelease(vid_n);
  CFRelease(pid_n);

  if (attached) {
    {
      std::lock_guard<std::mutex> lk(g_mu);
      g_quit = false;
      g_req_pending = false;
      g_sent_any = false;
      g_sent_small = g_sent_large = 0;
    }
    g_worker = std::thread(writer_loop);
  }
  return attached;
}

/* Called from the frame loop: publish the latest motor values. Never blocks on
 * the device -- the writer thread owns every HID write. */
void psx_host_rumble_update(uint8_t small, uint8_t large) {
  if (!g_dev)
    return;
  {
    std::lock_guard<std::mutex> lk(g_mu);
    g_req_small = small;
    g_req_large = large;
    g_req_pending = true;
  }
  g_cv.notify_one();
}

void psx_host_rumble_detach(void) {
  if (!g_dev)
    return;
  {
    std::lock_guard<std::mutex> lk(g_mu);
    g_req_small = 0;
    g_req_large = 0;
    g_req_pending = true;
    g_quit = true;
  }
  g_cv.notify_one();
  if (g_worker.joinable())
    g_worker.join();
  /* Belt and braces: several zero frames, because one can be dropped and the
   * motor persists until a valid stop frame lands. */
  for (int i = 0; i < 4; ++i)
    (void)write_frame(0, 0);
  g_sent_any = false;
  g_sent_small = g_sent_large = 0;
  IOHIDDeviceClose(g_dev, kIOHIDOptionsTypeNone);
  g_dev = nullptr;
}

} // extern "C"

#else /* !__APPLE__ */

extern "C" {
int psx_host_rumble_attach(uint16_t vid, uint16_t pid) {
  (void)vid;
  (void)pid;
  return 0;
}
void psx_host_rumble_update(uint8_t small, uint8_t large) {
  (void)small;
  (void)large;
}
void psx_host_rumble_detach(void) {}
}

#endif /* __APPLE__ */