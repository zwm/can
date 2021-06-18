
// synopsys translate_off
`include "timescale.v"
// synopsys translate_on
`include "can_defines.v"

module can_fifo
( 
  clk,
  rst,

  wr,

  data_in,
  addr,
  data_out,
  fifo_selected,

  reset_mode,
  release_buffer,
  extended_mode,
  overrun,
  info_empty,
  info_cnt

`ifdef CAN_BIST
  ,
  mbist_si_i,
  mbist_so_o,
  mbist_ctrl_i
`endif
);

parameter Tp = 1;

input         clk;
input         rst;
input         wr;
input   [7:0] data_in;
input   [5:0] addr;
input         reset_mode;
input         release_buffer;
input         extended_mode;
input         fifo_selected;

output  [7:0] data_out;
output        overrun;
output        info_empty;
output  [6:0] info_cnt;

`ifdef CAN_BIST
input         mbist_si_i;
output        mbist_so_o;
input [`CAN_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i;       // bist chain shift control
wire          mbist_s_0;
`endif

`ifdef ALTERA_RAM
`else
`ifdef ACTEL_APA_RAM
`else
`ifdef XILINX_RAM
`else
`ifdef ARTISAN_RAM
  reg           overrun_info[0:63];
`else
`ifdef VIRTUALSILICON_RAM
  reg           overrun_info[0:63];
`else
  reg     [7:0] fifo [0:63];
  reg     [3:0] length_fifo[0:63];
  reg           overrun_info[0:63];
`endif
`endif
`endif
`endif
`endif

reg     [5:0] rd_pointer;
reg     [5:0] wr_pointer;
reg     [5:0] read_address;
reg     [5:0] wr_info_pointer;
reg     [5:0] rd_info_pointer;
reg           wr_q;
reg     [3:0] len_cnt;
reg     [6:0] fifo_cnt;
reg     [6:0] info_cnt;
reg           latch_overrun;
reg           initialize_memories;

wire    [3:0] length_info;
wire          write_length_info;
wire          fifo_empty;
wire          fifo_full;
wire          info_full;

assign write_length_info = (~wr) & wr_q;

// Delayed write signal
always @ (posedge clk or posedge rst)
begin
  if (rst)
    wr_q <=#Tp 1'b0;
  else if (reset_mode)
    wr_q <=#Tp 1'b0;
  else
    wr_q <=#Tp wr;
end


// length counter
always @ (posedge clk or posedge rst)
begin
  if (rst)
    len_cnt <= 4'h0;
  else if (reset_mode | write_length_info)
    len_cnt <=#Tp 4'h0;
  else if (wr & (~fifo_full))
    len_cnt <=#Tp len_cnt + 1'b1;
end


// wr_info_pointer
always @ (posedge clk or posedge rst)
begin
  if (rst)
    wr_info_pointer <= 6'h0;
  else if (write_length_info & (~info_full) | initialize_memories)
    wr_info_pointer <=#Tp wr_info_pointer + 1'b1;
  else if (reset_mode)
    wr_info_pointer <=#Tp rd_info_pointer;
end



// rd_info_pointer
always @ (posedge clk or posedge rst)
begin
  if (rst)
    rd_info_pointer <= 6'h0;
  else if (release_buffer & (~info_full))
    rd_info_pointer <=#Tp rd_info_pointer + 1'b1;
end


// rd_pointer
always @ (posedge clk or posedge rst)
begin
  if (rst)
    rd_pointer <= 5'h0;
  else if (release_buffer & (~fifo_empty))
    rd_pointer <=#Tp rd_pointer + {2'h0, length_info};
end


// wr_pointer
always @ (posedge clk or posedge rst)
begin
  if (rst)
    wr_pointer <= 5'h0;
  else if (reset_mode)
    wr_pointer <=#Tp rd_pointer;
  else if (wr & (~fifo_full))
    wr_pointer <=#Tp wr_pointer + 1'b1;
end


// latch_overrun
always @ (posedge clk or posedge rst)
begin
  if (rst)
    latch_overrun <= 1'b0;
  else if (reset_mode | write_length_info)
    latch_overrun <=#Tp 1'b0;
  else if (wr & fifo_full)
    latch_overrun <=#Tp 1'b1;
end


// Counting data in fifo
always @ (posedge clk or posedge rst)
begin
  if (rst)
    fifo_cnt <= 7'h0;
  else if (reset_mode)
    fifo_cnt <=#Tp 7'h0;
  else if (wr & (~release_buffer) & (~fifo_full))
    fifo_cnt <=#Tp fifo_cnt + 1'b1;
  else if ((~wr) & release_buffer & (~fifo_empty))
    fifo_cnt <=#Tp fifo_cnt - {3'h0, length_info};
  else if (wr & release_buffer & (~fifo_full) & (~fifo_empty))
    fifo_cnt <=#Tp fifo_cnt - {3'h0, length_info} + 1'b1;
end

assign fifo_full = fifo_cnt == 7'd64;
assign fifo_empty = fifo_cnt == 7'd0;


// Counting data in length_fifo and overrun_info fifo
always @ (posedge clk or posedge rst)
begin
  if (rst)
    info_cnt <=#Tp 7'h0;
  else if (reset_mode)
    info_cnt <=#Tp 7'h0;
  else if (write_length_info ^ release_buffer)
    begin
      if (release_buffer & (~info_empty))
        info_cnt <=#Tp info_cnt - 1'b1;
      else if (write_length_info & (~info_full))
        info_cnt <=#Tp info_cnt + 1'b1;
    end
end
        
assign info_full = info_cnt == 7'd64;
assign info_empty = info_cnt == 7'd0;


// Selecting which address will be used for reading data from rx fifo
always @ (extended_mode or rd_pointer or addr)
begin
  if (extended_mode)      // extended mode
    read_address = rd_pointer + (addr - 6'd16);
  else                    // normal mode
    read_address = rd_pointer + (addr - 6'd20);
end


always @ (posedge clk or posedge rst)
begin
  if (rst)
    initialize_memories <= 1'b1;
  else if (&wr_info_pointer)
    initialize_memories <=#Tp 1'b0;
end


`ifdef ALTERA_RAM
//  altera_ram_64x8_sync fifo
  lpm_ram_dp fifo
  (
    .q         (data_out),
    .rdclock   (clk),
    .wrclock   (clk),
    .data      (data_in),
    .wren      (wr & (~fifo_full)),
    .rden      (fifo_selected),
    .wraddress (wr_pointer),
    .rdaddress (read_address)
  );
  defparam fifo.lpm_width = 8;
  defparam fifo.lpm_widthad = 6;
  defparam fifo.lpm_numwords = 64;


//  altera_ram_64x4_sync info_fifo
  lpm_ram_dp info_fifo
  (
    .q         (length_info),
    .rdclock   (clk),
    .wrclock   (clk),
    .data      (len_cnt & {4{~initialize_memories}}),
    .wren      (write_length_info & (~info_full) | initialize_memories),
    .wraddress (wr_info_pointer),
    .rdaddress (rd_info_pointer)
  );
  defparam info_fifo.lpm_width = 4;
  defparam info_fifo.lpm_widthad = 6;
  defparam info_fifo.lpm_numwords = 64;


//  altera_ram_64x1_sync overrun_fifo
  lpm_ram_dp overrun_fifo
  (
    .q         (overrun),
    .rdclock   (clk),
    .wrclock   (clk),
    .data      ((latch_overrun | (wr & fifo_full)) & (~initialize_memories)),
    .wren      (write_length_info & (~info_full) | initialize_memories),
    .wraddress (wr_info_pointer),
    .rdaddress (rd_info_pointer)
  );
  defparam overrun_fifo.lpm_width = 1;
  defparam overrun_fifo.lpm_widthad = 6;
  defparam overrun_fifo.lpm_numwords = 64;

`else
`ifdef ACTEL_APA_RAM
  actel_ram_64x8_sync fifo
  (
    .DO      (data_out),
    .RCLOCK  (clk),
    .WCLOCK  (clk),
    .DI      (data_in),
    .PO      (),                       // parity not used
    .WRB     (~(wr & (~fifo_full))),
    .RDB     (~fifo_selected),
    .WADDR   (wr_pointer),
    .RADDR   (read_address)
  );


  actel_ram_64x4_sync info_fifo
  (
    .DO      (length_info),
    .RCLOCK  (clk),
    .WCLOCK  (clk),
    .DI      (len_cnt & {4{~initialize_memories}}),
    .PO      (),                       // parity not used
    .WRB     (~(write_length_info & (~info_full) | initialize_memories)),
    .RDB     (1'b0),                   // always enabled
    .WADDR   (wr_info_pointer),
    .RADDR   (rd_info_pointer)
  );


  actel_ram_64x1_sync overrun_fifo
  (
    .DO      (overrun),
    .RCLOCK  (clk),
    .WCLOCK  (clk),
    .DI      ((latch_overrun | (wr & fifo_full)) & (~initialize_memories)),
    .PO      (),                       // parity not used
    .WRB     (~(write_length_info & (~info_full) | initialize_memories)),
    .RDB     (1'b0),                   // always enabled
    .WADDR   (wr_info_pointer),
    .RADDR   (rd_info_pointer)
  );
`else
`ifdef XILINX_RAM

  RAMB4_S8_S8 fifo
  (
    .DOA(),
    .DOB(data_out),
    .ADDRA({3'h0, wr_pointer}),
    .CLKA(clk),
    .DIA(data_in),
    .ENA(1'b1),
    .RSTA(1'b0),
    .WEA(wr & (~fifo_full)),
    .ADDRB({3'h0, read_address}),
    .CLKB(clk),
    .DIB(8'h0),
    .ENB(1'b1),
    .RSTB(1'b0),
    .WEB(1'b0)
  );


  RAMB4_S4_S4 info_fifo
  (
    .DOA(),
    .DOB(length_info),
    .ADDRA({4'h0, wr_info_pointer}),
    .CLKA(clk),
    .DIA(len_cnt & {4{~initialize_memories}}),
    .ENA(1'b1),
    .RSTA(1'b0),
    .WEA(write_length_info & (~info_full) | initialize_memories),
    .ADDRB({4'h0, rd_info_pointer}),
    .CLKB(clk),
    .DIB(4'h0),
    .ENB(1'b1),
    .RSTB(1'b0),
    .WEB(1'b0)
  );


  RAMB4_S1_S1 overrun_fifo
  (
    .DOA(),
    .DOB(overrun),
    .ADDRA({6'h0, wr_info_pointer}),
    .CLKA(clk),
    .DIA((latch_overrun | (wr & fifo_full)) & (~initialize_memories)),
    .ENA(1'b1),
    .RSTA(1'b0),
    .WEA(write_length_info & (~info_full) | initialize_memories),
    .ADDRB({6'h0, rd_info_pointer}),
    .CLKB(clk),
    .DIB(1'h0),
    .ENB(1'b1),
    .RSTB(1'b0),
    .WEB(1'b0)
  );


`else
`ifdef VIRTUALSILICON_RAM

`ifdef CAN_BIST
    vs_hdtp_64x8_bist fifo
`else
    vs_hdtp_64x8 fifo
`endif
    (
        .RCK        (clk),
        .WCK        (clk),
        .RADR       (read_address),
        .WADR       (wr_pointer),
        .DI         (data_in),
        .DOUT       (data_out),
        .REN        (~fifo_selected),
        .WEN        (~(wr & (~fifo_full)))
    `ifdef CAN_BIST
        ,
        // debug chain signals
        .mbist_si_i   (mbist_si_i),
        .mbist_so_o   (mbist_s_0),
        .mbist_ctrl_i   (mbist_ctrl_i)
    `endif
    );

`ifdef CAN_BIST
    vs_hdtp_64x4_bist info_fifo
`else
    vs_hdtp_64x4 info_fifo
`endif
    (
        .RCK        (clk),
        .WCK        (clk),
        .RADR       (rd_info_pointer),
        .WADR       (wr_info_pointer),
        .DI         (len_cnt & {4{~initialize_memories}}),
        .DOUT       (length_info),
        .REN        (1'b0),
        .WEN        (~(write_length_info & (~info_full) | initialize_memories))
    `ifdef CAN_BIST
        ,
        // debug chain signals
        .mbist_si_i   (mbist_s_0),
        .mbist_so_o   (mbist_so_o),
        .mbist_ctrl_i   (mbist_ctrl_i)
    `endif
    );

    // overrun_info
    always @ (posedge clk)
    begin
      if (write_length_info & (~info_full) | initialize_memories)
        overrun_info[wr_info_pointer] <=#Tp (latch_overrun | (wr & fifo_full)) & (~initialize_memories);
    end
    
    
    // reading overrun
    assign overrun = overrun_info[rd_info_pointer];

`else
`ifdef ARTISAN_RAM

`ifdef CAN_BIST
    art_hstp_64x8_bist fifo
    (
        .CLKR       (clk),
        .CLKW       (clk),
        .AR         (read_address),
        .AW         (wr_pointer),
        .D          (data_in),
        .Q          (data_out),
        .REN        (~fifo_selected),
        .WEN        (~(wr & (~fifo_full))),
        .mbist_si_i   (mbist_si_i),
        .mbist_so_o   (mbist_s_0),
        .mbist_ctrl_i   (mbist_ctrl_i)
    );
    art_hstp_64x4_bist info_fifo
    (
        .CLKR       (clk),
        .CLKW       (clk),
        .AR         (rd_info_pointer),
        .AW         (wr_info_pointer),
        .D          (len_cnt & {4{~initialize_memories}}),
        .Q          (length_info),
        .REN        (1'b0),
        .WEN        (~(write_length_info & (~info_full) | initialize_memories)),
        .mbist_si_i   (mbist_s_0),
        .mbist_so_o   (mbist_so_o),
        .mbist_ctrl_i   (mbist_ctrl_i)
    );
`else
    art_hsdp_64x8 fifo
    (
        .CENA       (1'b0),
        .CENB       (1'b0),
        .CLKA       (clk),
        .CLKB       (clk),
        .AA         (read_address),
        .AB         (wr_pointer),
        .DA         (8'h00),
        .DB         (data_in),
        .QA         (data_out),
        .QB         (),
        .OENA       (~fifo_selected),
        .OENB       (1'b1),
        .WENA       (1'b1),
        .WENB       (~(wr & (~fifo_full)))
    );
    art_hsdp_64x4 info_fifo
    (
        .CENA       (1'b0),
        .CENB       (1'b0),
        .CLKA       (clk),
        .CLKB       (clk),
        .AA         (rd_info_pointer),
        .AB         (wr_info_pointer),
        .DA         (4'h0),
        .DB         (len_cnt & {4{~initialize_memories}}),
        .QA         (length_info),
        .QB         (),
        .OENA       (1'b0),
        .OENB       (1'b1),
        .WENA       (1'b1),
        .WENB       (~(write_length_info & (~info_full) | initialize_memories))
    );
`endif

    // overrun_info
    always @ (posedge clk)
    begin
      if (write_length_info & (~info_full) | initialize_memories)
        overrun_info[wr_info_pointer] <=#Tp (latch_overrun | (wr & fifo_full)) & (~initialize_memories);
    end
    
    
    // reading overrun
    assign overrun = overrun_info[rd_info_pointer];

`else
  // writing data to fifo
  always @ (posedge clk)
  begin
    if (wr & (~fifo_full))
      fifo[wr_pointer] <=#Tp data_in;
  end

  // reading from fifo
  assign data_out = fifo[read_address];


  // writing length_fifo
  always @ (posedge clk)
  begin
    if (write_length_info & (~info_full) | initialize_memories)
      length_fifo[wr_info_pointer] <=#Tp len_cnt & {4{~initialize_memories}};
  end


  // reading length_fifo
  assign length_info = length_fifo[rd_info_pointer];

  // overrun_info
  always @ (posedge clk)
  begin
    if (write_length_info & (~info_full) | initialize_memories)
      overrun_info[wr_info_pointer] <=#Tp (latch_overrun | (wr & fifo_full)) & (~initialize_memories);
  end
  
  
  // reading overrun
  assign overrun = overrun_info[rd_info_pointer];


`endif
`endif
`endif
`endif
`endif





endmodule
