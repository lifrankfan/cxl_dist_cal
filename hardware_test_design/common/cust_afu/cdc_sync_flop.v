///////////////////////////////////////////////////////////////////////////////
// File: cdc_sync_flop.v
// Author: Saeed Fouladi Fard PhD PEng
// Copyright (c) 2021. Eidetic Communications Inc.
// All rights reserved.
// This license message must appear in all versions of this code including
// modified versions.
////////////////////////////////////////////////////////////////////////////////
// This module implements synchronization flops
////////////////////////////////////////////////////////////////////////////////
`default_nettype none

module cdc_sync_flop
 #( 
   parameter APPLY_RESET = 1,       // Apply reset signal or not 
   parameter RESET_LEVEL = 1,       // Reset level, 1 or 0
   parameter WIDTH       = 8,       // Number of data bits
   parameter NUM_SYNC    = 2        // Number of synchronization stage flops (1, 2 or 3)
  )
  (
   // Source signals
   input  wire             clk    , // clock
   input  wire             reset  , // reset
   input  wire [WIDTH-1:0] i_data , // Input data
   output wire [WIDTH-1:0] o_data   // Output data
  );
  
  // --------------------------------------------------------------------------
  // -- Settings
  localparam RST = (RESET_LEVEL==0) ? 1'b0 : 1'b1;
  localparam SL  = (NUM_SYNC>3)     ? 3    : 
                   (NUM_SYNC<1)     ? 1    : NUM_SYNC;
  
  // --------------------------------------------------------------------------
  // -- Processing
  integer         i;
  // Vivado
  (* ASYNC_REG = "TRUE" *)
  // Quartus
  (* PRESERVE *)
  (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION \"FORCED IF ASYNCHRONOUS\"" *)
  reg [WIDTH-1:0] s_data[SL-1:0];
  
  assign o_data = s_data[SL-1];
  
  generate
    if (APPLY_RESET==0) begin : wo_reset
      always @(posedge(clk)) begin
        s_data[0]   <= i_data;
        for (i=1; i<SL; i=i+1) begin
          s_data[i] <= s_data[i-1];
        end
      end
    end else begin : w_reset
      always @(posedge(clk)) begin
        if (reset==RST) begin
          for (i=0; i<SL; i=i+1) begin
            s_data[i] <= {(WIDTH){1'b0}};
          end
        end else begin
          s_data[0]   <= i_data;
          for (i=1; i<SL; i=i+1) begin
            s_data[i] <= s_data[i-1];
          end
        end
      end
    end
  endgenerate
  
endmodule // cdc_sync_flop

`default_nettype wire