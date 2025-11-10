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
  input logic  axi4_mm_clk, 

    // Resets
  input logic  axi4_mm_rst_n,
  
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
  input                            awready,
  
  /*
    AXI-MM interface - write data channel
  */
  output logic [511:0]              wdata,
  output logic [(512/8)-1:0]        wstrb,
  output logic                      wlast,
  output logic                      wuser,  //not sure
  output logic                      wvalid,
//  output logic [7:0]                wid, //removed in v3.0.2
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
  assign awatop         = '0  ; 
//  assign  wdata        = '1;    //v3.0.3
//  assign  wstrb        = '1   ; //v1.1 
//  assign  wlast        = '1   ; //v1.1
  assign  wuser        = '0   ; //set to not poison in v1.2
//  assign  wvalid       = '1   ; //v1.1
  assign  wid          = '0   ; //not sure
//  assign  bready       = '0   ;//v1.1
//  assign  arid         = '0   ;//v3.0
 //assign  araddr       = '0   ;
  assign  arlen        = '0   ;
  assign  arsize       = 3'b110   ;//must tie to 3'b110
  assign  arburst      = '0   ;
  assign  arprot       = '0   ;
  assign  arqos        = '0   ;
//  assign  aruser       = '0   ; //v1.2
  //assign  arvalid      = 1'b1   ; 
  assign  arcache      = '0   ;
  assign  arlock       = '0   ;
  assign  arregion     = '0   ;
//  assign  rready       = 1'b1   ;//v3.0.5

logic [63:0] func_type_out;   // function type selector
logic [63:0] page_addr_0_out; // base address for page 0
logic [63:0] delay_out; // store the delay result
logic [63:0] test_case; 
logic [63:0] resp_out; //record the response of read/write
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

logic start_proc;

logic start_proc_cdc; //input to cdc
logic [63:0] test_case_cdc;
logic [63:0] seed_init_cdc;
logic [63:0] num_request_cdc;
logic [63:0] addr_range_cdc;
//CSR block
cust_afu_csr_avmm_slave cust_afu_csr_avmm_slave_inst(
    .clk          (csr_avmm_clk),
    .reset_n      (csr_avmm_rstn),
    .writedata    (csr_avmm_writedata),
    .read         (csr_avmm_read),
    .write        (csr_avmm_write),
    .byteenable   (csr_avmm_byteenable),
    .readdata     (csr_avmm_readdata),
    .readdatavalid(csr_avmm_readdatavalid),
    .address      (csr_avmm_address),
    .poison       (csr_avmm_poison),
    .waitrequest  (csr_avmm_waitrequest),

    .o_start_proc  (start_proc_cdc),
    .func_type_out (func_type_out),   //not used in this module
    .page_addr_0_out(page_addr_0_out),
    .delay_out(delay_out),
    .resp_out(resp_out),
    .test_case_out(test_case_cdc),//see above for definition
    .addr_cnt_out(addr_cnt_out),
    .data_cnt_out(data_cnt_out),
    .resp_cnt_out(resp_cnt_out),
    .id_cnt_out(id_cnt_out),
    .id_cnt_1_out(id_cnt_1_out),
    .seed_init_out(seed_init_cdc),
    .num_request_out(num_request_cdc),
    .addr_range_out(addr_range_cdc)
);

cdc_sync_flop #(.RESET_LEVEL(0), .WIDTH(64)) test_case_cdc_inst (
  .clk(axi4_mm_clk),
  .reset(axi4_mm_rst_n),
  .i_data(test_case_cdc),
  .o_data(test_case)
);


cdc_sync_flop #(.RESET_LEVEL(0), .WIDTH(1)) start_proc_cdc_inst (
  .clk(axi4_mm_clk),
  .reset(axi4_mm_rst_n),
  .i_data(start_proc_cdc),
  .o_data(start_proc)
);

cdc_sync_flop #(.RESET_LEVEL(0), .WIDTH(64)) seed_cdc_inst (
  .clk(axi4_mm_clk),
  .reset(axi4_mm_rst_n),
  .i_data(seed_init_cdc),
  .o_data(seed_init_out)
);

cdc_sync_flop #(.RESET_LEVEL(0), .WIDTH(64)) num_request_cdc_inst (
  .clk(axi4_mm_clk),
  .reset(axi4_mm_rst_n),
  .i_data(num_request_cdc),
  .o_data(num_request_out)
);

cdc_sync_flop #(.RESET_LEVEL(0), .WIDTH(64)) addr_range_cdc_inst (
  .clk(axi4_mm_clk),
  .reset(axi4_mm_rst_n),
  .i_data(addr_range_cdc),
  .o_data(addr_range_out)
);

always_ff @(posedge axi4_mm_clk) begin
  pre_test_case <= test_case;
  pre_test_case1 <= pre_test_case;
end

psedu_read_write psedu_read_write_inst(
    .axi4_mm_clk(axi4_mm_clk),
    .axi4_mm_rst_n(axi4_mm_rst_n),
    .test_case(test_case),
    .pre_test_case(pre_test_case1),
    .num_request(num_request_out),
    .addr_range(addr_range_out),
    .start_proc(start_proc),
    .rvalid(rvalid),
    .rlast(rlast),
    .rresp(rresp),
    .arready(arready),
    .wready(wready),
    .awready(awready),
    .bvalid(bvalid),
    .bresp(bresp),
    .page_addr_0(page_addr_0_out),
    .seed_init(seed_init_out),
    .arvalid(arvalid),
    .arid(arid),
    .aruser(aruser),
    .rready(rready),
    .awvalid(awvalid),
    .awid(awid),
    .awuser(awuser),
    .wvalid(wvalid),
    .wdata(wdata),
    .wlast(wlast),
    .wstrb(wstrb),
    .bready(bready),
    .araddr(araddr),
    .awaddr(awaddr)
);

cal_delay cal_delay_inst(
  .clk(axi4_mm_clk),
  .reset_n(axi4_mm_rst_n),
  .m_axi_arvalid(arvalid), 
  .m_axi_arready(arready),
  .m_axi_rvalid(rvalid),
  .m_axi_rready(rready),
  .m_axi_awvalid(awvalid),
  .m_axi_awready(awready),
  .m_axi_wready(wready),
  .m_axi_wvalid(wvalid),
  .m_axi_bvalid(bvalid),
  .m_axi_bready(bready),
  .test_case(test_case),
  .pre_test_case(pre_test_case1),
  .num_request(num_request_out),
  .rid(rid),
  .bid(bid),
  .arid(arid),
  .awid(awid),
  .result(delay_out),
  .result_h(resp_out),
  .addr_cnt(addr_cnt_out),
  .data_cnt(data_cnt_out),
  .resp_cnt(resp_cnt_out),
  .id_cnt(id_cnt_out),
  .id_cnt_1(id_cnt_1_out)
);

endmodule