@echo off
REM -----------------------------------------------------------------------------
REM Yosys sweep for Windows. Run inside the OSS CAD Suite terminal (start.bat),
REM from the project root (the folder that contains rtl, tb, synth):
REM     synth\run_synth.bat
REM
REM Synthesizes two tops for N = 2, 4, 8, 16, 32:
REM   apb_top          : whole system (master + interconnect + slaves)
REM   apb_interconnect : decoder + response mux only (the bus itself)
REM Outputs:
REM   netlist\<top>_N<n>.v         gate-level netlist
REM   reports\<top>_N<n>_stat.txt  cell counts
REM   reports\<top>_N<n>_ltp.txt   longest topological path (logic depth)
REM   reports\summary.txt          total cells and depth for every run
REM -----------------------------------------------------------------------------

if not exist netlist mkdir netlist
if not exist reports mkdir reports
if exist reports\summary.txt del reports\summary.txt

for %%A in (apb_top apb_interconnect) do (
  for %%N in (2 4 8 16 32) do (
    echo Synthesizing %%A with N_SLAVES=%%N ...
    yosys -q -l reports/%%A_N%%N.log -p "read_verilog rtl/apb_slave.v rtl/apb_master.v rtl/apb_interconnect.v rtl/apb_top.v; chparam -set N_SLAVES %%N %%A; hierarchy -check -top %%A; synth -flatten -top %%A; opt_clean -purge; tee -q -o reports/%%A_N%%N_stat.txt stat; tee -q -o reports/%%A_N%%N_ltp.txt ltp -noff; write_verilog -noattr netlist/%%A_N%%N.v"
  )
)

for %%A in (apb_top apb_interconnect) do (
  for %%N in (2 4 8 16 32) do (
    echo === %%A  N=%%N === >> reports\summary.txt
    findstr /R /C:"[0-9] cells$" reports\%%A_N%%N_stat.txt >> reports\summary.txt
    findstr /C:"length=" reports\%%A_N%%N_ltp.txt >> reports\summary.txt
  )
)

echo.
type reports\summary.txt
echo.
echo Done. If a run printed "process cannot access the file" (antivirus lock on a
echo temp file), re-run the script. Open reports\ if any number is missing.
