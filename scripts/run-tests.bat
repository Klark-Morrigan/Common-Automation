@echo off
rem Thin launcher so run-tests.sh can be double-clicked from Explorer.
rem Delegates to Git Bash. PATH is searched for bash so this works on
rem any box with Git for Windows or WSL bash installed.
bash "%~dp0run-tests.sh" %*
