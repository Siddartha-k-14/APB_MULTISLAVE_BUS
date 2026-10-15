@echo off
REM -----------------------------------------------------------------------------
REM Yosys sweep v2 (no chparam). Run in the OSS CAD Suite terminal from the
REM project root (the folder containing rtl, tb, synth):
REM     synth\run_synth_v2.bat
REM
REM For each N it writes copies of apb_top.v and apb_interconnect.v into build\
REM with the default "parameter N_SLAVES = <N>", then synthesizes exactly like
REM the manual single run (no chparam). Source files in rtl\ are not changed.
REM
REM Outputs:
REM   netlist\<top>_N<n>.v         gate-level netlist
REM   reports\<top>_N<n>_stat.txt  cell counts
REM   reports\<top>_N<n>_ltp.txt   longest topological path (logic depth)
REM   reports\summary.txt          cells, flip-flops and depth for every run
REM -----------------------------------------------------------------------------

if not exist netlist mkdir netlist
if not exist reports mkdir reports
if not exist build mkdir build
if exist reports\summary.txt del reports\summary.txt

copy /y rtl\apb_slave.v build\apb_slave.v >nul
copy /y rtl\apb_master.v build\apb_master.v >nul

for %%N in (2 4 8 16 32) do (
  powershell -NoProfile -Command "(Get-Content rtl/apb_top.v) -replace 'parameter N_SLAVES\s*=\s*4','parameter N_SLAVES = %%N' | Set-Content build/apb_top.v"
  powershell -NoProfile -Command "(Get-Content rtl/apb_interconnect.v) -replace 'parameter N_SLAVES\s*=\s*4','parameter N_SLAVES = %%N' | Set-Content build/apb_interconnect.v"
  for %%A in (apb_top apb_interconnect) do (
    echo Synthesizing %%A with N_SLAVES=%%N ...
    yosys -q -l reports/%%A_N%%N.log -p "read_verilog build/apb_slave.v build/apb_master.v build/apb_interconnect.v build/apb_top.v; hierarchy -check -top %%A; synth -flatten -top %%A; opt_clean -purge; tee -q -o reports/%%A_N%%N_stat.txt stat; tee -q -o reports/%%A_N%%N_ltp.txt ltp -noff; write_verilog -noattr netlist/%%A_N%%N.v"
  )
)

for %%A in (apb_top apb_interconnect) do (
  for %%N in (2 4 8 16 32) do (
    echo === %%A  N=%%N === >> reports\summary.txt
    findstr /R /C:"[0-9] cells$" reports\%%A_N%%N_stat.txt >> reports\summary.txt
    findstr /C:"DFF" reports\%%A_N%%N_stat.txt >> reports\summary.txt
    findstr /C:"length=" reports\%%A_N%%N_ltp.txt >> reports\summary.txt
  )
)

echo.
type reports\summary.txt
echo.
echo Done. "process cannot access the file" messages are harmless.
