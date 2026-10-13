`timescale 1ns/1ps
module trace_probe;
  integer tf;
  initial tf = $fopen("sim/trace.txt", "w");
  always @(negedge tb_apb_top.PCLK) begin
    $fdisplay(tf, "%0t busy=%b done=%b err=%b rdata=%h", $time,
              tb_apb_top.busy, tb_apb_top.done, tb_apb_top.err, tb_apb_top.rdata);
    $fflush(tf);
  end
endmodule
