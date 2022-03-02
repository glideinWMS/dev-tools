import subprocess

from time import sleep
from tempfile import TemporaryFile, NamedTemporaryFile


class ShellSubprocess(object):
    """
    Interactive shell running in a persistent process
    """

    def __init__(self):
        self.stdout = TemporaryFile()
        self.stderr = TemporaryFile()
        self.process = subprocess.Popen(
            "/bin/bash", stdin=subprocess.PIPE, stdout=self.stdout, stderr=self.stderr
        )
        self.stdin = self.process.stdin

    def execute(self, cmd):
        """Execute a command in the shell.

        Args:
            cmd (string, list): command to execute
        """
        if isinstance(cmd, list):
            cmd = subprocess.list2cmdline(cmd)

        self.stdin.write(cmd.encode() + b"\n")
        self.stdin.flush()

    def run(self, cmd):
        """Execute a command in the shell an return the stdout, stderr and exit code.
        NOTE: This method clears the stdout and stderr buffers. TODO: Update this note.

        Args:
            cmd (string, list): command to execute
        """
        with NamedTemporaryFile() as outfile, NamedTemporaryFile() as errfile, NamedTemporaryFile() as exitfile:

            self.execute(
                f"({cmd}) 1> {outfile.name} 2> {errfile.name}; echo $? > {exitfile.name}"
            )

            wait_time = 0.0001
            while True:
                exitfile.seek(0)
                exit_code = exitfile.read()
                if exit_code:
                    break
                sleep(wait_time)
                wait_time *= 2

            outfile.seek(0)
            out = outfile.read()

            errfile.seek(0)
            err = errfile.read()

            exit_code = int(exit_code.strip())

        return out, err, exit_code

    def read_stdout(self):
        """Read stdout from the shell

        Returns:
            bytes: stdout
        """
        self.stdout.seek(0)
        return self.stdout.read()

    def read_stderr(self):
        """Read stderr from the shell

        Returns:
            bytes: stderr
        """
        self.stderr.seek(0)
        return self.stderr.read()

    def clear_stdout(self):
        """Clear stdout from the shell"""
        self.stdout.seek(0)
        self.stdout.truncate()

    def clear_stderr(self):
        """Clear stderr from the shell"""
        self.stderr.seek(0)
        self.stderr.truncate()

    def close(self):
        """Close the shell"""
        self.process.terminate()
        self.stdout.close()
        self.stderr.close()
