/*
Version: 5.00
Modified: 21/01/24
Purpose: simulate read/write
test_case:  
0. idle

Timing method = T(last data recv) - T(first request)
1. NC RD random #num_request requests at once, host
2. CS RD random #num_request requests at once, host
3. CO RD random #num_request requests at once, host
4. NC RD random #num_request requests at once, HDM, device bias
5. CS RD random #num_request requests at once, HDM, device bias
6. CO RD random #num_request requests at once, HDM, device bias
7. NC RD random #num_request requests at once, HDM, host bias
8. CS RD random #num_request requests at once, HDM, host bias
9. CO RD random #num_request requests at once, HDM, host bias

//switch on wready and awready version
Timing method = T(last b channel response recv) - T(first request)
10. NC WR random #num_request requests, host
11. CO WR random #num_request requests, host
12. NCP WR random #num_request requests, host
13. NC WR random #num_request requests, HDM, device bias
14. CO WR random #num_request requests, HDM, device bias
15. NCP WR random #num_request requests, HDM, device bias
16. NC WR random #num_request requests, HDM, host bias
17. CO WR random #num_request requests, HDM, host bias
18. NCP WR random #num_request requests, HDM, host bias

73. barrier
74. flush single DCOH host cache
75. flush entire DCOH host cache
76. flush entire DCOH device cache
*/

module cal_delay(
    input logic clk,
    input logic reset_n,
    input logic m_axi_arvalid,
    input logic m_axi_arready,
    input logic m_axi_rvalid,
    input logic m_axi_rready,
    input logic m_axi_awvalid,
    input logic m_axi_awready,
    input logic m_axi_wready,
    input logic m_axi_wvalid,
    input logic m_axi_bvalid,
    input logic m_axi_bready,    
    input logic [63:0] test_case,
    input logic [63:0] pre_test_case,
    input logic [63:0] num_request,
    input logic [11:0] rid,
    input logic [11:0] bid,
    input logic [11:0] arid,
    input logic [11:0] awid,
    output logic [63:0] result,
    output logic [63:0] result_h,
    output logic [63:0] addr_cnt,   //record (# of request) data return time
    output logic [63:0] data_cnt,
    output logic [63:0] resp_cnt,   
    output logic [63:0] id_cnt,     //data/response id
    output logic [63:0] id_cnt_1    //address id
);

enum logic [2:0] {
    STATE_IDLE,
    STATE_CNT,
    STATE_CNT_DOWN
} state;

logic [63:0] result_next; 
logic [63:0] result_h_next;

always_ff @(posedge clk) begin
    if (!reset_n) begin //if reset or test_case change, reset all registers
        state <= STATE_IDLE;
        result <= 64'b0;
        result_next <= 64'b0;
        result_h_next <= 64'b0;
        addr_cnt <= 64'b0;
        data_cnt <= 64'b0;
        resp_cnt <= 64'b0;
        id_cnt <= 64'd0;
        id_cnt_1 <= 64'd0;
    end
    else if (pre_test_case != test_case) begin
        state <= STATE_IDLE;
        result <= 64'b0;
        result_next <= 64'b0;
        result_h_next <= 64'b0;
        addr_cnt <= 64'b0;
        data_cnt <= 64'b0;
        resp_cnt <= 64'b0;
        id_cnt <= 64'd0;
        id_cnt_1 <= 64'd0;
    end
    else begin
        result <= result_next;
        result_h <= result_h_next;
        unique case (test_case) 
            64'd1, 64'd2, 64'd3, 64'd4, 64'd5, 64'd6, 64'd7, 64'd8, 64'd9: begin //RD request
                //calculate addr handshake
                if (m_axi_arvalid & m_axi_arready) begin
                    addr_cnt <= addr_cnt + 64'd1;
                    unique case(addr_cnt)
                        64'd0:  id_cnt_1[3:0] <= arid[3:0];
                        64'd1:  id_cnt_1[7:4] <= arid[3:0];
                        64'd2:  id_cnt_1[11:8] <= arid[3:0];
                        64'd3:  id_cnt_1[15:12] <= arid[3:0];
                        64'd4:  id_cnt_1[19:16] <= arid[3:0];
                        64'd5:  id_cnt_1[23:20] <= arid[3:0];
                        64'd6:  id_cnt_1[27:24] <= arid[3:0];
                        64'd7:  id_cnt_1[31:28] <= arid[3:0];
                        64'd8:  id_cnt_1[35:32] <= arid[3:0];
                        64'd9:  id_cnt_1[39:36] <= arid[3:0];
                        64'd10: id_cnt_1[43:40] <= arid[3:0];
                        64'd11: id_cnt_1[47:44] <= arid[3:0];
                        64'd12: id_cnt_1[51:48] <= arid[3:0];
                        64'd13: id_cnt_1[55:52] <= arid[3:0];
                        64'd14: id_cnt_1[59:56] <= arid[3:0];
                        64'd15: id_cnt_1[63:60] <= arid[3:0];
                        default: id_cnt_1 <= id_cnt_1;
                    endcase
                end
                else begin
                    addr_cnt <= addr_cnt;
                end
                //calculate data handshake
                if (m_axi_rvalid & m_axi_rready) begin
                    data_cnt <= data_cnt + 64'd1;
                    unique case(data_cnt)
                        64'd0:  id_cnt[3:0] <= rid[3:0];
                        64'd1:  id_cnt[7:4] <= rid[3:0];
                        64'd2:  id_cnt[11:8] <= rid[3:0];
                        64'd3:  id_cnt[15:12] <= rid[3:0];
                        64'd4:  id_cnt[19:16] <= rid[3:0];
                        64'd5:  id_cnt[23:20] <= rid[3:0];
                        64'd6:  id_cnt[27:24] <= rid[3:0];
                        64'd7:  id_cnt[31:28] <= rid[3:0];
                        64'd8:  id_cnt[35:32] <= rid[3:0];
                        64'd9:  id_cnt[39:36] <= rid[3:0];
                        64'd10: id_cnt[43:40] <= rid[3:0];
                        64'd11: id_cnt[47:44] <= rid[3:0];
                        64'd12: id_cnt[51:48] <= rid[3:0];
                        64'd13: id_cnt[55:52] <= rid[3:0];
                        64'd14: id_cnt[59:56] <= rid[3:0];
                        64'd15: id_cnt[63:60] <= rid[3:0];
                        default: id_cnt <= id_cnt;
                    endcase
                end
                else begin
                    data_cnt <= data_cnt;
                end
                //calculate delay
                if (state == STATE_IDLE) begin
                    result_next <= result_next;
                    result_h_next <= result_h_next;
                    if (m_axi_arvalid) begin //start cnt
                        state <= STATE_CNT;
                    end
                    else begin
                        state <= STATE_IDLE;
                    end
                end
                else if (state == STATE_CNT) begin
                    result_next <= result_next + 64'd1;
                    if (data_cnt > 64'd0) begin
                        result_h_next <= result_h_next;
                    end
                    else begin
                        result_h_next <= result_h_next + 64'd1;
                    end

                    if (m_axi_rvalid & m_axi_rready) begin //rdata hand shake
                        if (data_cnt == num_request-1) begin
                            state <= STATE_CNT_DOWN;
                        end
                        else begin
                            state <= STATE_CNT;
                        end
                    end
                    else begin
                        state <= STATE_CNT;
                    end
                end
                else begin
                    result_next <= result_next;
                    result_h_next <= result_h_next;
                    state <= state;
                end
            end

            64'd10, 64'd11, 64'd12, 64'd13, 64'd14, 64'd15, 64'd16, 64'd17, 64'd18: begin //WR sequential 16 times
                //calculate addr handshake
                if (m_axi_awvalid & m_axi_awready) begin
                    addr_cnt <= addr_cnt + 64'd1;
                    unique case(addr_cnt)
                        64'd0:  id_cnt_1[3:0] <= awid[3:0];
                        64'd1:  id_cnt_1[7:4] <= awid[3:0];
                        64'd2:  id_cnt_1[11:8] <= awid[3:0];
                        64'd3:  id_cnt_1[15:12] <= awid[3:0];
                        64'd4:  id_cnt_1[19:16] <= awid[3:0];
                        64'd5:  id_cnt_1[23:20] <= awid[3:0];
                        64'd6:  id_cnt_1[27:24] <= awid[3:0];
                        64'd7:  id_cnt_1[31:28] <= awid[3:0];
                        64'd8:  id_cnt_1[35:32] <= awid[3:0];
                        64'd9:  id_cnt_1[39:36] <= awid[3:0];
                        64'd10: id_cnt_1[43:40] <= awid[3:0];
                        64'd11: id_cnt_1[47:44] <= awid[3:0];
                        64'd12: id_cnt_1[51:48] <= awid[3:0];
                        64'd13: id_cnt_1[55:52] <= awid[3:0];
                        64'd14: id_cnt_1[59:56] <= awid[3:0];
                        64'd15: id_cnt_1[63:60] <= awid[3:0];
                        default: id_cnt_1 <= id_cnt_1;
                    endcase
                end
                else begin
                    addr_cnt <= addr_cnt;
                end
                //calculate data handshake
                if (m_axi_wvalid & m_axi_wready) begin
                    data_cnt <= data_cnt + 64'd1;
                end
                else begin
                    data_cnt <= data_cnt;
                end
                //calculate response handshake
                if (m_axi_bready & m_axi_bvalid) begin
                    resp_cnt <= resp_cnt + 64'd1;
                    unique case(resp_cnt)
                        64'd0:  id_cnt[3:0] <= bid[3:0];
                        64'd1:  id_cnt[7:4] <= bid[3:0];
                        64'd2:  id_cnt[11:8] <= bid[3:0];
                        64'd3:  id_cnt[15:12] <= bid[3:0];
                        64'd4:  id_cnt[19:16] <= bid[3:0];
                        64'd5:  id_cnt[23:20] <= bid[3:0];
                        64'd6:  id_cnt[27:24] <= bid[3:0];
                        64'd7:  id_cnt[31:28] <= bid[3:0];
                        64'd8:  id_cnt[35:32] <= bid[3:0];
                        64'd9:  id_cnt[39:36] <= bid[3:0];
                        64'd10: id_cnt[43:40] <= bid[3:0];
                        64'd11: id_cnt[47:44] <= bid[3:0];
                        64'd12: id_cnt[51:48] <= bid[3:0];
                        64'd13: id_cnt[55:52] <= bid[3:0];
                        64'd14: id_cnt[59:56] <= bid[3:0];
                        64'd15: id_cnt[63:60] <= bid[3:0];
                        default: id_cnt <= id_cnt;
                    endcase
                end
                else begin
                    resp_cnt <= resp_cnt; 
                end
                //calculate delay
                if (state == STATE_IDLE) begin
                    result_next <= result_next;
                    result_h_next <= result_h_next;
                    if (m_axi_awvalid) begin
                        state <= STATE_CNT;
                    end
                    else begin
                        state <= STATE_IDLE;
                    end
                end
                else if (state == STATE_CNT) begin
                    result_next <= result_next + 64'd1;
                    if (resp_cnt > 64'd0) begin
                        result_h_next <= result_h_next;
                    end
                    else begin
                        result_h_next <= result_h_next + 64'd1;
                    end

                    if (m_axi_bready & m_axi_bvalid) begin
                        if (resp_cnt == num_request - 1) begin
                            state <= STATE_CNT_DOWN;
                        end
                        else begin
                            state <= STATE_CNT;
                        end
                    end
                    else begin
                        state <= STATE_CNT;
                    end
                end
                else begin
                    result_next <= result_next;
                    result_h_next <= result_h_next;
                    state <= state;
                end
            end

            64'd73, 64'd74, 64'd75, 64'd76: begin //all single write operation
                //calculate addr handshake
                if (m_axi_awvalid & m_axi_awready) begin
                    addr_cnt <= addr_cnt + 64'd1;
                end
                else begin
                    addr_cnt <= addr_cnt;
                end
                //calculate data handshake
                if (m_axi_wvalid & m_axi_wready) begin
                    data_cnt <= data_cnt + 64'd1;
                end
                else begin
                    data_cnt <= data_cnt;
                end
                //calculate response handshake
                if (m_axi_bready & m_axi_bvalid) begin
                    resp_cnt <= resp_cnt + 64'd1;
                end
                else begin
                    resp_cnt <= resp_cnt; 
                end
                //calculate delay
                if (state == STATE_IDLE) begin
                    result_next <= result_next;
                    if (m_axi_awvalid) begin
                        state <= STATE_CNT;
                    end
                    else begin
                        state <= STATE_IDLE;
                    end
                end
                else if (state == STATE_CNT) begin
                    result_next <= result_next + 64'd1;
                    if (m_axi_bvalid) begin
                        state <= STATE_CNT_DOWN;
                    end
                    else begin
                        state <= STATE_CNT;
                    end
                end
                else begin
                    result_next <= result_next;
                    state <= state;
                end
            end


            default: begin
                addr_cnt <= addr_cnt;
                data_cnt <= data_cnt;
                resp_cnt <= resp_cnt; 
                result_next <= result_next;
                state <= state;
            end
        endcase
    end
end


endmodule