// (C) 2001-2023 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel FPGA IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


// Copyright 2022 Intel Corporation.
//
// THIS SOFTWARE MAY CONTAIN PREPRODUCTION CODE AND IS PROVIDED BY THE
// COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
// WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
// OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
// EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
///////////////////////////////////////////////////////////////////////
/*                COHERENCE-COMPLIANCE VALIDATION AFU

  Description   : FPGA CXL Compliance Engine Initiator AFU
                  Speaks to the AXI-to-CCIP+ translator.
                  This afu is the initiatior
                  The axi-to-ccip+ is the responder

  initial -> 07/12/2022 -> Antony Mathew
*/


module cust_afu_wrapper
(
      // Clocks
  input  logic  axi4_mm_clk, 

      // Resets
  input  logic  axi4_mm_rst_n,
  
  // [harry] AVMM interface - imported from ex_default_csr_top
  input  logic        csr_avmm_clk,
  input  logic        csr_avmm_rstn,  
  output logic        csr_avmm_waitrequest,  
  output logic [63:0] csr_avmm_readdata,
  output logic        csr_avmm_readdatavalid,
  input  logic [63:0] csr_avmm_writedata,
  input  logic [21:0] csr_avmm_address,
  input  logic        csr_avmm_write,
  input  logic        csr_avmm_poison,
  input  logic        csr_avmm_read, 
  input  logic [7:0]  csr_avmm_byteenable,

  /*
    AXI-MM interface - write address channel
  */
  output logic [11:0]               awid,   //not sure
  output logic [63:0]               awaddr, 
  output logic [9:0]                awlen,  //must tie to 10'd0
  output logic [2:0]                awsize, //must tie to 3'b110 (64B/T)
  output logic [1:0]                awburst,//must tie to 2'b00
  output logic [2:0]                awprot, //must tie to 3'b000
  output logic [3:0]                awqos,  //must tie to 4'b0000
  output logic [5:0]                awuser, //v1.2
  output logic                      awvalid,
  output logic [3:0]                awcache,//must tie to 4'b0000
  output logic [1:0]                awlock, //must tie to 2'b00
  output logic [3:0]                awregion, //must tie to 4'b0000
  output logic [5:0]                awatop,
  input                             awready,
  
  /*
    AXI-MM interface - write data channel
  */
  output logic [511:0]              wdata,
  output logic [(512/8)-1:0]        wstrb,
  output logic                      wlast,
  output logic                      wuser,  //not sure
  output logic                      wvalid,
   input                            wready,
  
  /*
    AXI-MM interface - write response channel
  */ 
   input [11:0]                     bid,  //not sure
   input [1:0]                      bresp,  //2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
   input [3:0]                      buser,  //must tie to 4'b0000
   input                            bvalid,
  output logic                      bready,
  
  /*
    AXI-MM interface - read address channel
  */
  output logic [11:0]               arid, //not sure
  output logic [63:0]               araddr,
  output logic [9:0]                arlen,  //must tie to 10'd0
  output logic [2:0]                arsize, //must tie to 3'b110
  output logic [1:0]                arburst,  //must tie to 2'b00
  output logic [2:0]                arprot, //must tie to 3'b000
  output logic [3:0]                arqos,  //must tie to 4'b0000
  output logic [5:0]                aruser, //4'b0000": non-cacheable, 4'b0001: cacheable shared, 4'b0010: cachebale owned
  output logic                      arvalid,
  output logic [3:0]                arcache,  //must tie to 4'b0000
  output logic [1:0]                arlock, //must tie to 2'b00
  output logic [3:0]                arregion, //must tie to 4'b0000
   input                            arready,

  /*
    AXI-MM interface - read response channel
  */ 
   input [11:0]                     rid,  //not sure
   input [511:0]                    rdata,  
   input [1:0]                      rresp,  //2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
   input                            rlast,  
   input                            ruser,  //not sure
   input                            rvalid,
   output logic                     rready
);

// Tied to Zero for all inputs. USER Can Modify

//assign awready = 1'b0;
//assign wready  = 1'b0;
//assign arready = 1'b0;
//assign bid     = 16'h0;
//assign bresp   = 4'h0;  
//assign buser   = 4'h0;
//assign bvalid  = 1'b0;
//
//assign rid     = 16'h0; 
//assign rdata   = 512'h0;
//assign rresp   = 4'h0;
//assign rlast   = 1'b0;
//assign ruser   = 4'h0;
//assign rvalid  = 1'b0;


//  assign  awid         = '0   ; //v3.0
  //assign  awaddr       = '0   ; 
  assign  awlen        = '0   ;
  assign  awsize       = 3'b110   ; //must tie to 3'b110
  assign  awburst      = '0   ;
  assign  awprot       = '0   ;
  assign  awqos        = '0   ;
//  assign  awuser       = '0   ; //v1.2
  //assign  awvalid      = '0   ;
  assign  awcache      = '0   ;
  assign  awlock       = '0   ;
  assign  awregion     = '0   ;
  assign  awatop       = '0  ; 
//  assign  wdata        = '1;    //v3.0.3
//  assign  wstrb        = '1   ; //v1.1 
//  assign  wlast        = '1   ; //v1.1
  assign  wuser        = '0   ; //set to not poison in v1.2
//  assign  wvalid       = '1   ; //v1.1
//  assign  wid          = '0   ; //not sure (AXI3 only, removed in AXI4)
//  assign  bready       = '0   ;//v1.1
//  assign  arid         = '0   ;//v3.0
 //assign  araddr       = '0   ; // Now driven by L2 mux
//assign  arlen        = '0   ; // Now driven by L2 mux
  assign  arsize       = 3'b110   ;//must tie to 3'b110
//assign  arburst      = '0   ; // Now driven by L2 mux
  assign  arprot       = '0   ;
  assign  arqos        = '0   ;
//  assign  aruser       = '0   ; //v1.2
  //assign  arvalid      = 1'b1   ; // Now driven by L2 mux
  assign  arcache      = '0   ;
  assign  arlock       = '0   ;
  assign  arregion     = '0   ;
//  assign  rready       = 1'b1   ;//v3.0.5 // Now driven by L2 mux

logic [63:0] func_type_out;      // function type selector
logic [63:0] page_addr_0_cdc;    // base address for page 0 (CSR clk domain)
logic [63:0] page_addr_0_out;    // base address for page 0 (AXI clk domain)
logic [63:0] page_addr_1_cdc;    // query/address 1 (CSR clk domain)
logic [63:0] page_addr_1_out;    // query/address 1 (AXI clk domain)
logic [63:0] delay_mux;          // value fed into CSR delay register
logic [63:0] resp_mux;           // value fed into CSR resp register
logic [63:0] delay_cal;          // raw cal_delay result
logic [63:0] resp_cal;           // raw cal_delay result_h
logic [63:0] test_case; 
logic [63:0] addr_cnt_out;
logic [63:0] data_cnt_out;
logic [63:0] resp_cnt_out;

logic [63:0] id_cnt_out;
logic [63:0] id_cnt_1_out;

logic [63:0] pre_test_case;
logic [63:0] pre_test_case1;

logic [63:0] seed_init_out;
logic [63:0] num_request_out;
logic [63:0] addr_range_out;

logic        start_proc;
logic        l2_start_cdc;   // L2 start signal from CSR domain
logic        l2_start_axi;   // L2 start signal in AXI domain

// CSR-domain versions
logic        start_proc_cdc; 
logic [63:0] test_case_cdc;
logic [63:0] seed_init_cdc;
logic [63:0] num_request_cdc;
logic [63:0] addr_range_cdc;

// helper for 1-bit FIFO CDC
logic [62:0] ignore_start;
logic [62:0] ignore_l2_start;

// CSR block
cust_afu_csr_avmm_slave cust_afu_csr_avmm_slave_inst(
    .clk           (csr_avmm_clk),
    .reset_n       (csr_avmm_rstn),
    .writedata     (csr_avmm_writedata),
    .read          (csr_avmm_read),
    .write         (csr_avmm_write),
    .byteenable    (csr_avmm_byteenable),
    .readdata      (csr_avmm_readdata),
    .readdatavalid (csr_avmm_readdatavalid),
    .address       (csr_avmm_address),
    .poison        (csr_avmm_poison),
    .waitrequest   (csr_avmm_waitrequest),

    .o_start_proc   (start_proc_cdc),
    .o_l2_dist_start(l2_start_cdc),     // L2 start trigger
    .func_type_out  (func_type_out),    // not used in this module
    .page_addr_0_out(page_addr_0_cdc),  // CSR clock domain
  .page_addr_1_out(page_addr_1_cdc),  // CSR clock domain
  .delay_out      (delay_mux),
  .resp_out       (resp_mux),
    .test_case_out  (test_case_cdc),    // see psedu_read_write for definition
    .addr_cnt_out   (addr_cnt_out),
    .data_cnt_out   (data_cnt_out),
    .resp_cnt_out   (resp_cnt_out),
    .id_cnt_out     (id_cnt_out),
    .id_cnt_1_out   (id_cnt_1_out),
    .seed_init_out  (seed_init_cdc),
    .num_request_out(num_request_cdc),
    .addr_range_out (addr_range_cdc)
);

// ============================================================================
// Clock domain crossing: CSR (csr_avmm_clk) -> AXI (axi4_mm_clk)
// Replaces previous cdc_sync_flop instances with dual-clock FIFO IP
// ============================================================================

// page_addr_0 (64-bit)
fifo page_addr_0_cdc_inst (
  .data    (page_addr_0_cdc),
  .wrreq   (1'b1),
  .rdreq   (1'b1),
  .wrclk   (csr_avmm_clk),
  .rdclk   (axi4_mm_clk),
  .q       (page_addr_0_out),
  .rdempty (),
  .wrfull  ()
);

// page_addr_1 (64-bit)
fifo page_addr_1_cdc_inst (
  .data    (page_addr_1_cdc),
  .wrreq   (1'b1),
  .rdreq   (1'b1),
  .wrclk   (csr_avmm_clk),
  .rdclk   (axi4_mm_clk),
  .q       (page_addr_1_out),
  .rdempty (),
  .wrfull  ()
);

// test_case (64-bit)
fifo test_case_cdc_inst (
  .data    (test_case_cdc),
  .wrreq   (1'b1),
  .rdreq   (1'b1),
  .wrclk   (csr_avmm_clk),
  .rdclk   (axi4_mm_clk),
  .q       (test_case),
  .rdempty (),
  .wrfull  ()
);

// start_proc (1-bit -> 64-bit FIFO)
fifo start_proc_cdc_inst (
  .data    ({63'b0, start_proc_cdc}),
  .wrreq   (1'b1),
  .rdreq   (1'b1),
  .wrclk   (csr_avmm_clk),
  .rdclk   (axi4_mm_clk),
  .q       ({ignore_start, start_proc}),
  .rdempty (),
  .wrfull  ()
);

// seed_init (64-bit)
fifo seed_cdc_inst (
  .data    (seed_init_cdc),
  .wrreq   (1'b1),
  .rdreq   (1'b1),
  .wrclk   (csr_avmm_clk),
  .rdclk   (axi4_mm_clk),
  .q       (seed_init_out),
  .rdempty (),
  .wrfull  ()
);

// num_request (64-bit)
fifo num_request_cdc_inst (
  .data    (num_request_cdc),
  .wrreq   (1'b1),
  .rdreq   (1'b1),
  .wrclk   (csr_avmm_clk),
  .rdclk   (axi4_mm_clk),
  .q       (num_request_out),
  .rdempty (),
  .wrfull  ()
);

// addr_range (64-bit)
fifo addr_range_cdc_inst (
  .data    (addr_range_cdc),
  .wrreq   (1'b1),
  .rdreq   (1'b1),
  .wrclk   (csr_avmm_clk),
  .rdclk   (axi4_mm_clk),
  .q       (addr_range_out),
  .rdempty (),
  .wrfull  ()
);

// l2_start (1-bit -> 64-bit FIFO)
fifo l2_start_cdc_inst (
  .data    ({63'b0, l2_start_cdc}),
  .wrreq   (1'b1),
  .rdreq   (1'b1),
  .wrclk   (csr_avmm_clk),
  .rdclk   (axi4_mm_clk),
  .q       ({ignore_l2_start, l2_start_axi}),
  .rdempty (),
  .wrfull  ()
);

// ============================================================================

always_ff @(posedge axi4_mm_clk) begin
  if (!axi4_mm_rst_n) begin
    pre_test_case  <= 64'd0;
    pre_test_case1 <= 64'd0;
  end else begin
    pre_test_case  <= test_case;
    pre_test_case1 <= pre_test_case;
  end
end

// ------------------------------------------------------------
// L2 Distance Engine instance (read-only, streaming)
// Activated when test_case == 64'd100
// ------------------------------------------------------------
logic [63:0] l2_araddr;
logic [7:0]  l2_arlen;
logic [2:0]  l2_arsize;
logic [1:0]  l2_arburst;
logic        l2_arvalid;
logic        l2_rready;
logic [63:0] l2_cycles;
logic [63:0] l2_done;
wire         l2_use = (test_case == 64'd100);

l2_distance_engine #(
  .BUS_W      (512),
  .ELEM_BITS  (32),
  .DIM_MAX    (128)
) u_l2 (
  .clk        (axi4_mm_clk),
  .rst_n      (axi4_mm_rst_n),
  .test_case  (test_case),
  .start_i    (l2_start_axi),
  .base_pa    (page_addr_0_out),
  .query_pa   (page_addr_1_out),
  .num_vecs   (num_request_out),
  .dim_cfg    (addr_range_out),
  .araddr_o   (l2_araddr),
  .arlen_o    (l2_arlen),
  .arsize_o   (l2_arsize),
  .arburst_o  (l2_arburst),
  .arvalid_o  (l2_arvalid),
  .arready_i  (arready),
  .rdata_i    (rdata),
  .rvalid_i   (rvalid),
  .rlast_i    (rlast),
  .rready_o   (l2_rready),
  .cycles_o   (l2_cycles),
  .done_o     (l2_done)
);

// AXI read channel multiplexing (only read path used by engine)
assign araddr  = l2_use ? l2_araddr  : 64'd0;
assign arvalid = l2_use ? l2_arvalid : 1'b0;
assign arburst = l2_use ? l2_arburst : 2'b00;
assign arsize  = 3'b110; // fixed 64B beats
assign arlen   = l2_use ? {2'b00, l2_arlen} : 10'd0; // widen 8-bit -> 10-bit
assign rready  = l2_use ? l2_rready  : 1'b1; // default ready when not using engine

// Mux results destined for CSR space
// When test_case selects L2 engine (100), present cycles and done flag;
// otherwise forward cal_delay measurement infrastructure values.
assign delay_mux = l2_use ? l2_cycles : delay_cal;
assign resp_mux  = l2_use ? {63'd0, l2_done[0]} : resp_cal;


// psedu_read_write psedu_read_write_inst(
//     .axi4_mm_clk   (axi4_mm_clk),
//     .axi4_mm_rst_n (axi4_mm_rst_n),

//     .test_case     (test_case),
//     .pre_test_case (pre_test_case1),
//     .num_request   (num_request_out),
//     .addr_range    (addr_range_out),
//     .start_proc    (start_proc),

//     .rvalid        (rvalid),
//     .rlast         (rlast),
//     .rresp         (rresp),
//     .arready       (arready),
//     .wready        (wready),
//     .awready       (awready),
//     .bvalid        (bvalid),
//     .bresp         (bresp),

//     .page_addr_0   (page_addr_0_out),
//     .seed_init     (seed_init_out),

//     .arvalid       (arvalid),
//     .arid          (arid),
//     .aruser        (aruser),
//     .rready        (rready),

//     .awvalid       (awvalid),
//     .awid          (awid),
//     .awuser        (awuser),

//     .wvalid        (wvalid),
//     .wdata         (wdata),
//     .wlast         (wlast),
//     .wstrb         (wstrb),

//     .bready        (bready),

//     .araddr        (araddr),
//     .awaddr        (awaddr)
// );

cal_delay cal_delay_inst(
  .clk           (axi4_mm_clk),
  .reset_n       (axi4_mm_rst_n),

  .m_axi_arvalid (arvalid), 
  .m_axi_arready (arready),
  .m_axi_rvalid  (rvalid),
  .m_axi_rready  (rready),
  .m_axi_awvalid (awvalid),
  .m_axi_awready (awready),
  .m_axi_wready  (wready),
  .m_axi_wvalid  (wvalid),
  .m_axi_bvalid  (bvalid),
  .m_axi_bready  (bready),

  .test_case     (test_case),
  .pre_test_case (pre_test_case1),
  .num_request   (num_request_out),

  .rid           (rid),
  .bid           (bid),
  .arid          (arid),
  .awid          (awid),

  .result        (delay_cal),
  .result_h      (resp_cal),
  .addr_cnt      (addr_cnt_out),
  .data_cnt      (data_cnt_out),
  .resp_cnt      (resp_cnt_out),
  .id_cnt        (id_cnt_out),
  .id_cnt_1      (id_cnt_1_out)
);

endmodule
