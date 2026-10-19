"""Run a command on a pseudo-terminal and type answers into it.

    python3 tty.py <answers file> <command> [args...]

The scripts read prompts from /dev/tty, so piping into stdin isn't enough.
Each line of the answers file is typed only after the command has printed
something and then gone quiet, so it lands on the prompt that asked for it
(and hidden prompts really are hidden). Once the answers run out, Ctrl-D is
sent so a further read sees end-of-file instead of hanging.

Prints everything the command wrote and exits with its exit code, or 124 if
it was still running after TIMEOUT seconds.
"""

import os
import pty
import select
import signal
import sys
import time

TIMEOUT = 20
QUIET = 0.1  # seconds of silence that means "waiting for input"

answers_file, argv = sys.argv[1], sys.argv[2:]
with open(answers_file) as f:
    answers = [line + "\n" for line in f.read().split("\n")]
if answers and answers[-1] == "\n":
    answers.pop()  # the file's own trailing newline
answers.append("\x04")

pid, fd = pty.fork()
if pid == 0:
    os.execvp(argv[0], argv)

out = bytearray()
deadline = time.time() + TIMEOUT
seen_output = False
last_output = time.time()
while True:
    if time.time() > deadline:
        os.kill(pid, signal.SIGKILL)
        os.waitpid(pid, 0)
        sys.stdout.write(out.decode(errors="replace").replace("\r", ""))
        sys.stdout.write("\n[tty.py] timed out after %ds\n" % TIMEOUT)
        sys.exit(124)
    ready, _, _ = select.select([fd], [], [], 0.02)
    if ready:
        try:
            chunk = os.read(fd, 4096)
        except OSError:  # EIO: the command closed the terminal
            break
        if not chunk:
            break
        out += chunk
        seen_output = True
        last_output = time.time()
    elif answers and seen_output and time.time() - last_output > QUIET:
        os.write(fd, answers.pop(0).encode())
        seen_output = False

_, status = os.waitpid(pid, 0)
sys.stdout.write(out.decode(errors="replace").replace("\r", ""))
sys.exit(os.waitstatus_to_exitcode(status))
