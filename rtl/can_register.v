
// synopsys translate_off
`include "timescale.v"
// synopsys translate_on


module can_register
( data_in,
  data_out,
  we,
  clk
);

parameter WIDTH = 8; // default parameter of the register width

input [WIDTH-1:0] data_in;
input             we;
input             clk;

output [WIDTH-1:0] data_out;
reg    [WIDTH-1:0] data_out;



always @ (posedge clk)
begin
  if (we)                        // write
    data_out<=#1 data_in;
end



endmodule
