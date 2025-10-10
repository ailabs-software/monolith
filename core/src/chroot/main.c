#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <errno.h>
#include <limits.h>

#define DEBUG 0

#if defined(DEBUG) && DEBUG == 1
    #define dprint(fmt, ...) fprintf(stderr, "DEBUG: " fmt "\n", ##__VA_ARGS__)
#else
    #define dprint(fmt, ...) ((void)0)
#endif

/*
 * This is a custom chroot command that takes:
 * 1. chroot_path - the new root directory
 * 2. working_dir - working directory inside the chroot
 * 3. command - the command to execute
 * 4+ args - arguments to the command
 */
void usage(const char *program_name)
{
    fprintf(stderr, "Usage: %s <chroot_path> <working_dir> <command> [args...]\n", program_name);
    fprintf(stderr, "\n");
    fprintf(stderr, "Arguments:\n");
    fprintf(stderr, "  chroot_path   - Path to the new root directory\n");
    fprintf(stderr, "  working_dir   - Working directory inside the chroot (relative to new root)\n");
    fprintf(stderr, "  command       - Command to execute in the chrooted environment\n");
    fprintf(stderr, "  args...       - Optional arguments to pass to the command\n");
    fprintf(stderr, "\n");
    fprintf(stderr, "Example:\n");
    fprintf(stderr, "  %s /path/to/jail /home/user /bin/bash -l\n", program_name);
    fprintf(stderr, "  %s /tmp/chroot /tmp /bin/ls -la\n", program_name);
}

/** Frees the arguments list and exits the program */
void cleanup(char ***cmd_args, int exit_code)
{
    free(*cmd_args);
    exit(1);
}

/** This will do the following things in this order:
    1. Change to the chroot directory
    2. Perform the chroot jail
    3. Change to the desired working dir inside the chroot
    4. Execute the command
*/
void handleChildProcess(char ***cmd_args, const char* chroot_path, const char* working_dir, const char* command)
{
    dprint("Using chdir(%s)", chroot_path);
    if (chdir(chroot_path) != 0) {
        perror("chdir to chroot path");
        cleanup(cmd_args, 1);
    }
    
    dprint("Using chroot(%s)", chroot_path);
    if (chroot(chroot_path) != 0) {
        perror("chroot");
        cleanup(cmd_args, 1);
    }
    
    dprint("Using chdir(%s)", working_dir);
    if (chdir(working_dir) != 0) {
        perror("chdir to working directory");
        cleanup(cmd_args, 1);
    }
    
    dprint("Using execvp:");
    dprint("  - Path: %s", command);
    for (int i = 0; (*cmd_args)[i] != NULL; i++) {
        dprint("  - arg[%d]: %s", i, (*cmd_args)[i]);
    }
    if (execvp(command, *cmd_args) == -1) {
        perror("execvp");
        cleanup(cmd_args, 1);
    }
    
    cleanup(cmd_args, 1);
}

/** This will wait for the child process to run and will handle any interruptions
 * (by user, signal, etc) */
void handleParentProcess(pid_t pid, char*** cmd_args)
{
    int status;
    if (waitpid(pid, &status, 0) == -1) {
        perror("waitpid");
        cleanup(cmd_args, 1);
    }
    
    free(*cmd_args);
    
    if (WIFEXITED(status)) {
        int exit_code = WEXITSTATUS(status);
        dprint("Command exited with status: %d\n", exit_code);
        exit(exit_code);
    } else if (WIFSIGNALED(status)) {
        int signal = WTERMSIG(status);
        dprint("Command terminated by signal: %d\n", signal);
        exit(128 + signal);
    } else {
        dprint("Command terminated abnormally\n");
        exit(1);
    }
}

int main(int argc, char *argv[]) {
    if (argc < 4) {
        // minimum arguments not reached
        usage(argv[0]);
        return 1;
    }
    
    const char *chroot_path = argv[1];
    const char *working_dir = argv[2];
    const char *command = argv[3];
    
    // Prepare arguments for execvp (command + its arguments)
    char **cmd_args = malloc((argc - 2) * sizeof(char*));
    if (!cmd_args) {
        perror("malloc");
        return 1;
    }
    
    // Copy command and its arguments
    for (int i = 3; i < argc; i++) {
        cmd_args[i - 3] = argv[i];
    }
    cmd_args[argc - 3] = NULL;
    
    dprint("Custom chroot execution:\n");
    dprint("  Root path: %s\n", chroot_path);
    dprint("  Working dir: %s\n", working_dir);
    dprint("  Command: %s\n", command);
    dprint("  Arguments: ");
    for (int i = 4; i < argc; i++) {
        dprint("   - %s ", argv[i]);
    }
    dprint("\n\n");
    pid_t pid = fork();
    
    if (pid == -1) {
        perror("fork");
        free(cmd_args);
        return 1;
    }
    
    if (pid == 0) {
        handleChildProcess(&cmd_args, chroot_path, working_dir, command);
    } else {
        handleParentProcess(pid, &cmd_args);
    }
    
    return 0;
}
