@echo off
REM -----------------------------------------------------------------------------
REM Runs synth\vivado_fmax.tcl for N = 2, 4, 8, 16, 32 and prints results\vivado\fmax.csv
REM Run from the project root (the folder containing rtl, tb, synth).
REM If "vivado" is not recognized, set the full path first, for example:
REM     set VIVADO="C:\Xilinx\Vivado\2025.2\bin\vivado.bat"
REM -----------------------------------------------------------------------------
if "%VIVADO%"=="" set VIVADO=vivado

if not exist results mkdir results
if not exist results\vivado mkdir results\vivado
echo N,LUT,FF,WNS_ns,Fmax_MHz> results\vivado\fmax.csv

for %%N in (2 4 8 16 32) do (
  echo Vivado synthesis for N=%%N ...
  call %VIVADO% -mode batch -nojournal -nolog -source synth/vivado_fmax.tcl -tclargs %%N
)

echo.
type results\vivado\fmax.csv
