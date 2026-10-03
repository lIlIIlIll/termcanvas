/* Keep the complete fork-to-exec interval outside the managed runtime.
 * All allocation, environment merging and PATH parsing occur in the parent.
 * The child uses only async-signal-safe libc calls and never returns to CJ. */
#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <unistd.h>

extern char **environ;

/* Cangjie calls these fixed-arity entry points. In particular, Apple's ARM64
 * ABI passes variadic arguments on the stack, so declaring libc fcntl/ioctl
 * as fixed-arity foreign functions does not pass their third argument safely. */
int32_t termcanvas_fcntl(int32_t fd, int32_t command, int32_t value)
{
    return fcntl(fd, command, value);
}

int32_t termcanvas_ioctl(int32_t fd, uint64_t request, void *argument)
{
    return ioctl(fd, (unsigned long)request, argument);
}

static void release_strings(char **strings)
{
    if (!strings) return;
    for (size_t i = 0; strings[i]; ++i) free(strings[i]);
    free(strings);
}

/* A bare NAME removes an inherited variable, matching POSIX putenv. */
static char **prepare_environment(char *const overrides[])
{
    size_t inherited = 0, count = 0;
    while (environ[inherited]) ++inherited;
    while (overrides[count]) ++count;
    char **result = calloc(inherited + count + 1, sizeof(*result));
    if (!result) return NULL;
    size_t used = 0;
    for (size_t i = 0; i < inherited; ++i) {
        result[used] = strdup(environ[i]);
        if (!result[used]) { release_strings(result); return NULL; }
        ++used;
    }
    for (size_t i = 0; i < count; ++i) {
        const char *value = overrides[i];
        size_t key = strcspn(value, "=");
        if (!key) { release_strings(result); errno = EINVAL; return NULL; }
        for (size_t j = 0; j < used;) {
            if (!strncmp(result[j], value, key) && result[j][key] == '=') {
                free(result[j]);
                memmove(result + j, result + j + 1, (used - j) * sizeof(*result));
                --used;
            } else ++j;
        }
        if (value[key] == '=') {
            result[used] = strdup(value);
            if (!result[used]) { release_strings(result); return NULL; }
            ++used;
        }
    }
    return result;
}

static char **prepare_paths(const char *command, char *const environment[])
{
    const char *path = "/bin:/usr/bin";
    for (size_t i = 0; environment[i]; ++i)
        if (!strncmp(environment[i], "PATH=", 5)) path = environment[i] + 5;
    size_t count = 1;
    if (!strchr(command, '/'))
        for (const char *p = path; *p; ++p) if (*p == ':') ++count;
    char **result = calloc(count + 1, sizeof(*result));
    if (!result) return NULL;
    if (strchr(command, '/')) {
        result[0] = strdup(command);
        if (!result[0]) { free(result); return NULL; }
        return result;
    }
    for (size_t i = 0; i < count; ++i) {
        size_t length = strcspn(path, ":");
        result[i] = malloc(length + strlen(command) + 2);
        if (!result[i]) { release_strings(result); return NULL; }
        memcpy(result[i], path, length);
        size_t offset = length;
        if (length) result[i][offset++] = '/';
        strcpy(result[i] + offset, command);
        path += length;
        if (*path == ':') ++path;
    }
    return result;
}

static void child_failure(int fd, unsigned char stage)
{
    ssize_t written;
    do { written = write(fd, &stage, 1); } while (written < 0 && errno == EINTR);
    _exit(127);
}

int32_t termcanvas_spawn(char *const argv[], char *const overrides[], const char *cwd,
    int32_t input, int32_t output, int32_t errors, int32_t terminal,
    int32_t error_fd, const int32_t close_fds[], int64_t close_count)
{
    char **environment = prepare_environment(overrides);
    if (!environment) return -1;
    char **paths = prepare_paths(argv[0], environment);
    if (!paths) { release_strings(environment); return -1; }
    size_t argc = 0;
    while (argv[argc]) ++argc;
    /* execvp-compatible fallback for executable scripts without a shebang. */
    char **shell_argv = calloc(argc + 2, sizeof(*shell_argv));
    if (!shell_argv) { release_strings(paths); release_strings(environment); return -1; }
    shell_argv[0] = (char *)"/bin/sh";
    for (size_t i = 1; i < argc; ++i) shell_argv[i + 1] = argv[i];
    pid_t child = fork();
    if (child == 0) {
        if (setsid() < 0) child_failure(error_fd, 1);
        if (terminal >= 0 && ioctl(terminal, TIOCSCTTY, 0) != 0) child_failure(error_fd, 1);
        if (dup2(input, STDIN_FILENO) < 0 || dup2(output, STDOUT_FILENO) < 0 ||
            dup2(errors, STDERR_FILENO) < 0) child_failure(error_fd, 2);
        for (int64_t i = 0; i < close_count; ++i)
            if (close_fds[i] > STDERR_FILENO && close_fds[i] != error_fd) close(close_fds[i]);
        if (*cwd && chdir(cwd) != 0) child_failure(error_fd, 3);
        for (size_t i = 0; paths[i]; ++i) {
            execve(paths[i], argv, environment);
            if (errno == ENOEXEC) {
                shell_argv[1] = paths[i];
                execve("/bin/sh", shell_argv, environment);
                break;
            }
            if (errno != ENOENT && errno != ENOTDIR && errno != EACCES) break;
        }
        child_failure(error_fd, 5);
    }
    int saved_errno = errno;
    free(shell_argv);
    release_strings(paths);
    release_strings(environment);
    errno = saved_errno;
    return (int32_t)child;
}
