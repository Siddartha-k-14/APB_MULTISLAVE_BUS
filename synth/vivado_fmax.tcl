# -----------------------------------------------------------------------------
# vivado_fmax.tcl : post-synthesis timing estimate for one value of N_SLAVES
# Usage (from the project root):
#   vivado -mode batch -nojournal -nolog -source synth/vivado_fmax.tcl -tclargs <N>
# Appends one row to results/vivado/fmax.csv and writes full reports to
# results/vivado/util_N<N>.txt and timing_N<N>.txt
# NOTE: post-synthesis timing is an ESTIMATE (no placement/routing delays), so
# the Fmax is optimistic. Use it to compare designs, not as a sign-off number.
# -----------------------------------------------------------------------------
set n      [lindex $argv 0]
set part   xc7k70tfbv676-1
set period 10.0

file mkdir results/vivado

read_verilog {rtl/apb_slave.v rtl/apb_master.v rtl/apb_interconnect.v rtl/apb_top.v}
synth_design -top apb_top -part $part -mode out_of_context -generic N_SLAVES=$n

create_clock -period $period -name PCLK [get_ports PCLK]

# ---- utilization ----
set util [report_utilization -return_string]
set lut "NA"
set ff  "NA"
regexp {Slice LUTs\*?\s*\|\s*(\d+)} $util -> lut
regexp {Slice Registers\s*\|\s*(\d+)} $util -> ff

# ---- worst setup slack and Fmax ----
set path [lindex [get_timing_paths -max_paths 1 -nworst 1] 0]
set wns  [get_property SLACK $path]
set fmax [expr {1000.0 / ($period - $wns)}]

report_utilization    -file results/vivado/util_N$n.txt
report_timing_summary -file results/vivado/timing_N$n.txt

set fh [open results/vivado/fmax.csv a]
puts $fh [format "%s,%s,%s,%.3f,%.1f" $n $lut $ff $wns $fmax]
close $fh

puts "RESULT N=$n LUT=$lut FF=$ff WNS=$wns ns Fmax=[format %.1f $fmax] MHz"
