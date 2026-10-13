#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Generic Yosys synthesis sweep (no liberty file needed).
# Run from the project root:   bash synth/run_synth.sh
#
# For every N it synthesizes two tops:
#   apb_top          : whole system (master + interconnect + slaves)
#   apb_interconnect : decoder + mux only  <- best view of how the BUS scales
# Outputs:
#   netlist/<top>_N<n>.v         gate-level netlist (simulatable with iverilog)
#   reports/<top>_N<n>_stat.txt  cell count / cell types
#   reports/<top>_N<n>_ltp.txt   longest topological path (logic depth)
# -----------------------------------------------------------------------------
set -e
mkdir -p netlist reports

SRC="rtl/apb_slave.v rtl/apb_master.v rtl/apb_interconnect.v rtl/apb_top.v"
SWEEP="2 4 8 16 32"

for TOP in apb_top apb_interconnect; do
  for N in $SWEEP; do
    echo "Synthesizing $TOP with N_SLAVES=$N ..."
    yosys -q -l reports/${TOP}_N${N}.log -p "
      read_verilog $SRC
      chparam -set N_SLAVES $N $TOP
      hierarchy -check -top $TOP
      synth -flatten -top $TOP
      opt_clean -purge
      tee -q -o reports/${TOP}_N${N}_stat.txt stat
      tee -q -o reports/${TOP}_N${N}_ltp.txt ltp -noff
      write_verilog -noattr netlist/${TOP}_N${N}.v
    "
  done
done

# ---------------- summary table ----------------
echo
printf "%-18s %4s %8s %12s\n" "TOP" "N" "CELLS" "LOGIC_DEPTH"
for TOP in apb_top apb_interconnect; do
  for N in $SWEEP; do
    cells=$(grep -iE "number of cells|^ +[0-9]+ +cells" reports/${TOP}_N${N}_stat.txt | head -1 | grep -oE "[0-9]+" | head -1)
    depth=$(grep -oE "length=[0-9]+" reports/${TOP}_N${N}_ltp.txt | head -1 | cut -d= -f2)
    printf "%-18s %4s %8s %12s\n" "$TOP" "$N" "${cells:-?}" "${depth:-?}"
  done
done | tee reports/summary.txt
echo
echo "If a number shows '?', open the matching file in reports/ - the stat/ltp"
echo "text format differs slightly between Yosys versions."
