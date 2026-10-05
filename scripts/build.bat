@echo off
rem Rebuilds FeedTheGiantCapy.rbxlx from the source files in src\.
cd /d "%~dp0\.."
rojo build default.project.json -o FeedTheGiantCapy.rbxlx
