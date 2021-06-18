
// synopsys translate_off
`include "timescale.v"
// synopsys translate_on


module can_register_asyn
( data_in,
  data_out,
  we,
  clk,
  rst
);

parameter WIDTH = 8; // default parameter of the register width
parameter RESET_VALUE = 0;

input [WIDTH-1:0] data_in;
input             we;
input             clk;
input             rst;

output [WIDTH-1:0] data_out;
reg    [WIDTH-1:0] data_out;



always @ (posedge clk or posedge rst)
begin
  if (rst)                            // asynchronous reset
    data_out<=#1 RESET_VALUE;
  else if (we)                        // write
    data_out<=#1 data_in;
end



endmodule
