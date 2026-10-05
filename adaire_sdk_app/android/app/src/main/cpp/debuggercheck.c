#include <jni.h>
#include <android/log.h>
#include <unistd.h>
#include <sys/ptrace.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <dirent.h>
#include <sys/stat.h>
#include <signal.h>

#define LOG_TAG "DebuggerCheck"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

int check_tracerpid();
int check_frida();
int check_frida_maps();
int check_chrome_devtools();

// ========== IMPROVED PTrace CHECK ==========
int check_ptrace() {
    // Attempt to trace ourselves
    if (ptrace(PTRACE_TRACEME, 0, 0, 0) == -1) {
        // Double-check with TracerPid to reduce false positives
        if (check_tracerpid()) {
            return 1;  // Confirmed debugger
        }
        return 0;  // Likely false positive on this device
    }

    // Cleanup if successful
    ptrace(PTRACE_DETACH, 0, 0, 0);
    return 0;
}

// ========== ROBUST TRACERPID CHECK ==========
int check_tracerpid() {
    FILE* status = fopen("/proc/self/status", "r");
    if (!status) return 0;

    char buf[256];
    int tracer_pid = 0;

    while (fgets(buf, sizeof(buf), status)) {
        if (strncmp(buf, "TracerPid:", 10) == 0) {
            tracer_pid = atoi(buf + 10);
            break;
        }
    }
    fclose(status);

    // Some OEMs temporarily set TracerPid; re-check once after a short delay
    if (tracer_pid != 0) {
        usleep(100000);  // 100ms
        FILE* status2 = fopen("/proc/self/status", "r");
        if (status2) {
            while (fgets(buf, sizeof(buf), status2)) {
                if (strncmp(buf, "TracerPid:", 10) == 0) {
                    tracer_pid = atoi(buf + 10);
                    break;
                }
            }
            fclose(status2);
        }
    }

    return (tracer_pid != 0);
}

int check_frida() {
    DIR* dir = opendir("/proc");
    if (!dir) return 0;

    struct dirent* entry;
    int detected = 0;

    while ((entry = readdir(dir)) && !detected) {
        if (entry->d_type != DT_DIR) continue;

        char path[64];
        snprintf(path, sizeof(path), "/proc/%s/cmdline", entry->d_name);

        FILE* f = fopen(path, "r");
        if (!f) continue;

        char cmdline[256];
        if (fgets(cmdline, sizeof(cmdline), f)) {
            if (strstr(cmdline, "frida-server") ||
                strstr(cmdline, "frida-helper") ||
                strstr(cmdline, "gadget.so")) {
                LOGI("Frida process detected, killing app");
                kill(getpid(), SIGKILL);  // Immediately kill the app
                detected = 1;
                fclose(f);
                break;
            }
        }
        fclose(f);
    }
    closedir(dir);

    return detected;
}

// ========== MEMORY MAPS CHECK ==========
int check_frida_maps() {
    FILE* maps = fopen("/proc/self/maps", "r");
    if (!maps) return 0;

    char line[512];
    int detected = 0;

    while (fgets(line, sizeof(line), maps) && !detected) {
        if (strstr(line, "frida-agent") ||
            strstr(line, "libfrida") ||
            strstr(line, "gadget.so") ||
            strstr(line, "re.frida.server")) {
            LOGI("Frida library detected in memory, killing app");
            kill(getpid(), SIGKILL);
            detected = 1;
            break;
        }
    }
    fclose(maps);

    return detected;
}

int check_chrome_devtools() {
    DIR *dir = opendir("/proc/self/fd");
    if (!dir) return 0;

    struct dirent *entry;
    int detected = 0;

    while ((entry = readdir(dir)) && !detected) {
        if (entry->d_type != DT_LNK) continue;

        char path[256];
        snprintf(path, sizeof(path), "/proc/self/fd/%s", entry->d_name);

        char link[256];
        ssize_t len = readlink(path, link, sizeof(link)-1);
        if (len > 0) {
            link[len] = '\0';
            if (strstr(link, "devtools") ||
                strstr(link, "chrome")) {
                detected = 1;
            }
        }
    }
    closedir(dir);
    return detected;
}

// ========== PRODUCTION ENTRY POINT ==========
JNIEXPORT jboolean JNICALL
Java_com_adaire_security_DebuggerCheckNative_isDebuggerConnectedNative(
    JNIEnv* env,
    jobject instance
) {
    int score = 0;

    // 1. Primary checks (high confidence)
    if (check_ptrace()) {
        LOGI("High confidence debugger detected");
        score += 40;
    }

    if (check_tracerpid()) {
        LOGI("TracerPid confirmed");
        score += 40;
    }

    // 2. Secondary checks (medium confidence)
    if (check_frida() || check_frida_maps()) {
        LOGI("Frida environment detected");
        score += 30;
    }

    // DevTools related checks (generic; 20 points)
    if (check_chrome_devtools()) {
        LOGI("DevTools-related file descriptors detected");
        score += 20;
    }

    return (score >= 50) ? JNI_TRUE : JNI_FALSE;
}
