

// This module only inverts bit order
module can_ibo
( 
  di,
  do
);

input   [7:0] di;
output  [7:0] do;

assign do[0] = di[7];
assign do[1] = di[6];
assign do[2] = di[5];
assign do[3] = di[4];
assign do[4] = di[3];
assign do[5] = di[2];
assign do[6] = di[1];
assign do[7] = di[0];

endmodule
