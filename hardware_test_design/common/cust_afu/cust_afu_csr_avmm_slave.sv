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


// Copyright 2023 Intel Corporation.
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

module cust_afu_csr_avmm_slave(
 
// AVMM Slave Interface
   input               clk,
   input               reset_n,
   input  logic [63:0] writedata,
   input  logic        read,
   input  logic        write,
   input  logic [7:0]  byteenable,
   output logic [63:0] readdata,
   output logic        readdatavalid,
   input  logic [21:0] address,
   input logic poison,
   output logic        waitrequest,

   output logic o_start_proc,
   output logic [63:0] func_type_out,
   output logic [63:0] page_addr_0_out,
   output logic [63:0] test_case_out,
   input logic [63:0] delay_out,
   input logic [63:0] resp_out,
   input logic [63:0] addr_cnt_out,
   input logic [63:0] data_cnt_out,
   input logic [63:0] resp_cnt_out,
   input logic [63:0] id_cnt_out,
   input logic [63:0] id_cnt_1_out,
   output logic [63:0] seed_init_out,
   output logic [63:0] num_request_out,
   output logic [63:0] addr_range_out
);

 // [harry] original version use 32-bit register, we only need to use 64-bit register
 // this code is imported from ex_default_csr/ex_default_csr_avmm_slave.sv
 // in ed_top_wrapper_typ2.sv, you can we move the ex_default_csr interface into the cust_afu_wrapper


logic [63:0] func_type_reg;     //0
logic [63:0] page_addr0_reg;    //8
logic [63:0] delay_reg;         //16
logic [63:0] test_case_reg;     //24
logic [63:0] resp_reg;          //32
logic [63:0] addr_cnt_reg;      //40
logic [63:0] data_cnt_reg;      //48
logic [63:0] resp_cnt_reg;      //56
logic [63:0] id_cnt_reg;        //64
logic [63:0] id_cnt_1_reg;      //72
logic [63:0] seed_reg;          //80
logic [63:0] num_request_reg;   //88
logic [63:0] addr_range_reg;    //96

logic [63:0] mask ;
logic config_access;

// assign func_type_out = func_type_reg;
// assign page_addr_0_out = page_addr0_reg;
// assign test_case_out = test_case_reg;

// assign delay_reg = delay_out;
// assign resp_reg = resp_out;

 assign mask[7:0]   = byteenable[0]? 8'hFF:8'h0; 
 assign mask[15:8]  = byteenable[1]? 8'hFF:8'h0; 
 assign mask[23:16] = byteenable[2]? 8'hFF:8'h0; 
 assign mask[31:24] = byteenable[3]? 8'hFF:8'h0; 
 assign mask[39:32] = byteenable[4]? 8'hFF:8'h0; 
 assign mask[47:40] = byteenable[5]? 8'hFF:8'h0; 
 assign mask[55:48] = byteenable[6]? 8'hFF:8'h0; 
 assign mask[63:56] = byteenable[7]? 8'hFF:8'h0; 
 assign config_access = address[21];  


//Terminating extented capability header
//  localparam EX_CAP_HEADER  = 32'h00000000;
   localparam EX_CAP_HEADER  = 64'h00000000;

always @(posedge clk) begin
    func_type_out <= func_type_reg;
    page_addr_0_out <= page_addr0_reg;
    test_case_out <= test_case_reg;
    delay_reg <= delay_out;
    resp_reg <= resp_out;
    addr_cnt_reg <= addr_cnt_out;
    data_cnt_reg <= data_cnt_out;
    resp_cnt_reg <= resp_cnt_out;
    id_cnt_reg <= id_cnt_out;
    id_cnt_1_reg <= id_cnt_1_out;
    seed_init_out <= seed_reg;
    num_request_out <= num_request_reg;
    addr_range_out <= addr_range_reg;
end


//Write logic
always @(posedge clk) begin
    if (!reset_n) begin
        func_type_reg <= 64'b0;
        page_addr0_reg <= 64'b0;
        o_start_proc <= 1'b0;
        test_case_reg <= 64'b0;
        num_request_reg <= 64'b0;
        addr_range_reg <= 64'b0;
    end
    else begin
        if (write && (address == 22'h0000)) begin 
           func_type_reg <= (writedata & mask) ;
           o_start_proc <= 1'b0;
        end
        else if (write && (address == 22'h0008)) begin //change address
            page_addr0_reg <= (writedata & mask);
            o_start_proc <= 1'b1;
        end
        else if (write && (address == 22'h0018)) begin //change test case
            test_case_reg <= (writedata & mask);
            o_start_proc <= 1'b0;
        end
        else if (write && (address == 22'h0050)) begin //change seed
            seed_reg <= (writedata & mask);
            o_start_proc <= 1'b0;
        end
        else if (write && (address == 22'h0058)) begin //change num_request
            num_request_reg <= (writedata & mask);
            o_start_proc <= 1'b0;
        end
        else if (write && (address == 22'h0060)) begin //change addr_range
            addr_range_reg <= (writedata & mask);
            o_start_proc <= 1'b0;
        end 
        else begin
            func_type_reg <= func_type_reg;
            page_addr0_reg <= page_addr0_reg;
            test_case_reg <= test_case_reg;
            seed_reg <= seed_reg;
            num_request_reg <= num_request_reg;
            addr_range_reg <= addr_range_reg;
            o_start_proc <= 1'b0;
        end        
    end    
end 

//Read logic
always @(posedge clk) begin
    if (!reset_n) begin
        readdata  <= 32'h0;
    end
    else begin
        if (read && (address[21:0] == 22'h0)) begin 
           readdata <= func_type_reg & mask;
        end
        else if(read && (address[21:0] == 22'h0008)) begin //read addr
           readdata <= page_addr0_reg & mask;
        end
        else if (read && (address[21:0] == 22'h0010)) begin //read delay0
            readdata <=  delay_reg & mask;
        end
        else if (read && (address[21:0] == 22'h0018)) begin //read test case
            readdata <=  test_case_reg & mask;
        end
        else if (read && (address[21:0] == 22'h0020)) begin //read resp
            readdata <=  resp_reg & mask;
        end
        else if (read && (address[21:0] == 22'h0028)) begin //read addr_cnt
            readdata <=  addr_cnt_reg & mask;
        end
        else if (read && (address[21:0] == 22'h0030)) begin //read data_cnt
            readdata <=  data_cnt_reg & mask;
        end
        else if (read && (address[21:0] == 22'h0038)) begin //read resp_cnt
            readdata <=  resp_cnt_reg & mask;
        end
        else if (read && (address[21:0] == 22'h0040)) begin //read id_cnt
            readdata <=  id_cnt_reg & mask;
        end
        else if (read && (address[21:0] == 22'h0048)) begin //read id_cnt_1
            readdata <=  id_cnt_1_reg & mask;
        end
        else if (read && (address[21:0] == 22'h0050)) begin //read seed_reg
            readdata <=  seed_reg & mask;
        end
        else if (read && (address[21:0] == 22'h0058)) begin //read num_request_reg
            readdata <=  num_request_reg & mask;
        end
        else if (read && (address[21:0] == 22'h0060)) begin //read addr_range_reg
            readdata <=  addr_range_reg & mask;
        end
        else begin
           readdata  <= 64'h0;
        end        
    end    
end 


//Control Logic
enum int unsigned { IDLE = 0,WRITE = 2, READ = 4 } state, next_state;

always_comb begin : next_state_logic
   next_state = IDLE;
      case(state)
      IDLE    : begin 
                   if( write ) begin
                       next_state = WRITE;
                   end
                   else begin
                     if (read) begin  
                       next_state = READ;
                     end
                     else begin
                       next_state = IDLE;
                     end
                   end 
                end
      WRITE     : begin
                   next_state = IDLE;
                end
      READ      : begin
                   next_state = IDLE;
                end
      default : next_state = IDLE;
   endcase
end


always_comb begin
   case(state)
   IDLE    : begin
               waitrequest  = 1'b1;
               readdatavalid= 1'b0;
             end
   WRITE     : begin 
               waitrequest  = 1'b0;
               readdatavalid= 1'b0;
             end
   READ     : begin 
               waitrequest  = 1'b0;
               readdatavalid= 1'b1;
             end
   default : begin 
               waitrequest  = 1'b1;
               readdatavalid= 1'b0;
             end
   endcase
end

always_ff@(posedge clk) begin
   if(~reset_n)
      state <= IDLE;
   else
      state <= next_state;
end

endmodule