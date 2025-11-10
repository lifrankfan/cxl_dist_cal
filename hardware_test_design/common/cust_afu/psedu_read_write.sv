/*
Version: 5.0.1
Modified: 24/01/24
Purpose: simulate read/write
test_case:  
0. idle

Timing method = T(last data recv) - T(first request)
1. NC RD random #num_request requests at once, host
2. CO RD random #num_request requests at once, host
3. CS RD random #num_request requests at once, host
4. NC RD random #num_request requests at once, HDM, device bias
5. CO RD random #num_request requests at once, HDM, device bias
6. CS RD random #num_request requests at once, HDM, device bias
7. NC RD random #num_request requests at once, HDM, host bias
8. CO RD random #num_request requests at once, HDM, host bias
9. CS RD random #num_request requests at once, HDM, host bias

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
module psedu_read_write (
    input logic axi4_mm_clk,
    input logic axi4_mm_rst_n,
    input logic [63:0] test_case,
    input logic [63:0] pre_test_case,
    input logic [63:0] num_request,
    input logic [63:0] addr_range,
    input logic start_proc,
    input logic rvalid,
    input logic rlast,
    input logic [1:0] rresp,
    input logic arready,
    input logic wready,
    input logic awready,
    input logic bvalid,
    input logic [1:0] bresp,
    input logic [63:0] page_addr_0,
    input logic [63:0] seed_init,
    output logic arvalid,
    output logic [11:0] arid,
    output logic [5:0] aruser,
    output logic rready,
    output logic awvalid,
    output logic [11:0] awid,
    output logic [5:0] awuser,
    output logic wvalid,
    output logic [511:0] wdata,
    output logic wlast, 
    output logic [(512/8)-1:0] wstrb, 
    output logic bready, 
    output logic [63:0] araddr,
    output logic [63:0] awaddr
);

    enum logic [4:0] {
        STATE_IDLE,
        STATE_R_WAIT,
        STATE_W_WAIT,
        STATE_ADDR,
        STATE_DATA,
        STATE_R64,
        STATE_W64,
        STATE_WRES,
        STATE_R_DONE,
        STATE_W_DONE,
        STATE_EXCEP
    } state;

    logic [63:0] seed; //generating random address
    logic [63:0] random_offset_32K;
    logic [63:0] random_offset_128K;
    logic [63:0] random_offset_1M;
    logic [63:0] random_offset_4M;
    logic [63:0] random_offset_16M;
    logic [63:0] random_offset_32M;
    logic [63:0] addr_offset;
    logic [63:0] rw_cnt;
    assign rready = 1'b1;
    assign bready = 1'b1;
/*---------------------------------
functions
-----------------------------------*/

    function void set_w_done_inf();     //55-72
        if (rw_cnt == num_request-1) begin
            state <= STATE_W_DONE;
            awvalid <= 1'b0;
            wvalid <= 1'b0;
        end
        else begin
            seed <= seed ^ (seed << 1) ^ (seed >> 1);
            state <= STATE_ADDR;
            //address
            awid <= awid + 12'd1;
            rw_cnt <= rw_cnt + 64'd1;
            awvalid <= 1'b1;
            unique case (test_case)
                64'd10: begin
                    awuser <= 6'b000000; //non-cacheable
                end        
                64'd11: begin
                    awuser <= 6'b000001; //cacheable own
                end
                64'd12: begin
                    awuser <= 6'b000010; //non-cacheable push
                end
                64'd13: begin
                    awuser <= 6'b110000; //non-cacheable
                end        
                64'd14: begin
                    awuser <= 6'b110001; //cacheable own
                end
                64'd15: begin
                    awuser <= 6'b110010; //non-cacheable push
                end
                64'd16: begin
                    awuser <= 6'b100000; //non-cacheable
                end        
                64'd17: begin
                    awuser <= 6'b100001; //cacheable own
                end
                64'd18: begin
                    awuser <= 6'b100010; //non-cacheable push
                end

                default: begin
                    awuser <= 6'b000000; //non-cacheable
                end
            endcase

            unique case(addr_range) 
                64'd1: begin
                    addr_offset <= random_offset_32K;
                end
                64'd2: begin
                    addr_offset <= random_offset_128K;
                end
                64'd3: begin
                    addr_offset <= random_offset_1M;
                end
                64'd4: begin
                    addr_offset <= random_offset_4M;
                end
                64'd5: begin
                    addr_offset <= random_offset_16M;
                end
                64'd6: begin
                    addr_offset <= random_offset_32M;
                end

                default: begin
                    addr_offset <= random_offset_32K;
                end
            endcase
            //data
            wvalid <= 1'b1;
            wdata <= '1;
            wlast <= 1'b1;
            wstrb <= 64'hffffffffffffffff;
        end
    endfunction


/*---------------------------------
state machine
-----------------------------------*/
    always_ff @(posedge axi4_mm_clk) begin
        if (!axi4_mm_rst_n) begin
            state <= STATE_IDLE;
            arvalid <= '0;
            aruser <= '0;
            arid <= '0;
            awvalid <= '0;
            awuser <= '0;
            awid <= '0;
            wvalid <= '0;
            wdata <= '0;
            wlast <= '0;
            wstrb <= '0;
            addr_offset <= '0;
            rw_cnt <= '0;
            seed <= '0;
        end
        else if (pre_test_case != test_case) begin
            state <= STATE_IDLE;
            arvalid <= '0;
            aruser <= '0;
            arid <= '0;
            awvalid <= '0;
            awuser <= '0;
            awid <= '0;
            wvalid <= '0;
            wlast <= '0;
            wdata <= '0; 
            wstrb <= '0;
            addr_offset <= '0;
            rw_cnt <= '0;
            seed <= '0;
        end
        else begin
            unique case (test_case)
/*--------------
latency test
----------------*/
                64'd1, 64'd2, 64'd3, 64'd4, 64'd5, 64'd6, 64'd7, 64'd8, 64'd9: begin //RD request
                    if (state == STATE_IDLE) begin
                        if (start_proc == 1'b1) begin
                            seed <= seed_init;
                            state <= STATE_ADDR;
                            unique case (test_case)
                                64'd1: begin
                                    aruser <= 6'b000000; //non-cacheable
                                end
                                64'd3: begin
                                    aruser <= 6'b000001; //cacheable shared
                                end
                                64'd2: begin
                                    aruser <= 6'b000010; //cacheable owned
                                end
                                64'd4: begin
                                    aruser <= 6'b110000; //non-cacheable
                                end
                                64'd6: begin
                                    aruser <= 6'b110001; //cacheable shared
                                end
                                64'd5: begin
                                    aruser <= 6'b110010; //cacheable owned
                                end
                                64'd7: begin
                                    aruser <= 6'b100000; //non-cacheable
                                end
                                64'd9: begin
                                    aruser <= 6'b100001; //cacheable shared
                                end
                                64'd8: begin
                                    aruser <= 6'b100010; //cacheable owned
                                end

                                default: begin
                                    aruser <= 6'b000000; //non-cacheable
                                end
                            endcase

                            unique case(addr_range) 
                                64'd1: begin
                                    addr_offset <= random_offset_32K;
                                end
                                64'd2: begin
                                    addr_offset <= random_offset_128K;
                                end
                                64'd3: begin
                                    addr_offset <= random_offset_1M;
                                end
                                64'd4: begin
                                    addr_offset <= random_offset_4M;
                                end
                                64'd5: begin
                                    addr_offset <= random_offset_16M;
                                end
                                64'd6: begin
                                    addr_offset <= random_offset_32M;
                                end

                                default: begin
                                    addr_offset <= random_offset_32K;
                                end
                            endcase
                            arid <= 12'd0;
                            arvalid <= 1'b1;
                        end
                        else begin
                            state <= STATE_IDLE;
                        end
                    end
                    else if (state == STATE_ADDR) begin
                        if (arready) begin
                            if (rw_cnt == num_request-1) begin
                                state <= STATE_R_DONE;
                                arvalid <= 1'b0;
                            end
                            else begin
                                seed <= seed ^ (seed << 1) ^ (seed >> 1);
                                arid <= arid + 12'd1;
                                rw_cnt <= rw_cnt + 64'd1;
                                arvalid <= 1'b1;
                                unique case (test_case)
                                    64'd1: begin
                                        aruser <= 6'b000000; //non-cacheable
                                    end
                                    64'd3: begin
                                        aruser <= 6'b000001; //cacheable shared
                                    end
                                    64'd2: begin
                                        aruser <= 6'b000010; //cacheable owned
                                    end
                                    64'd4: begin
                                        aruser <= 6'b110000; //non-cacheable
                                    end
                                    64'd6: begin
                                        aruser <= 6'b110001; //cacheable shared
                                    end
                                    64'd5: begin
                                        aruser <= 6'b110010; //cacheable owned
                                    end
                                    64'd7: begin
                                        aruser <= 6'b100000; //non-cacheable
                                    end
                                    64'd9: begin
                                        aruser <= 6'b100001; //cacheable shared
                                    end
                                    64'd8: begin
                                        aruser <= 6'b100010; //cacheable owned
                                    end
                                    
                                    default: begin
                                        aruser <= 6'b000000; //non-cacheable
                                    end
                                endcase

                                unique case(addr_range) 
                                    64'd1: begin
                                        addr_offset <= random_offset_32K;
                                    end
                                    64'd2: begin
                                        addr_offset <= random_offset_128K;
                                    end
                                    64'd3: begin
                                        addr_offset <= random_offset_1M;
                                    end
                                    64'd4: begin
                                        addr_offset <= random_offset_4M;
                                    end
                                    64'd5: begin
                                        addr_offset <= random_offset_16M;
                                    end
                                    64'd6: begin
                                        addr_offset <= random_offset_32M;
                                    end

                                    default: begin
                                        addr_offset <= random_offset_32K;
                                    end
                                endcase

                                state <= STATE_ADDR;
                            end
                        end
                        else begin
                            state <= STATE_ADDR;
                            arid <= arid;
                            aruser <= aruser;
                            arvalid <= 1'b1;
                        end
                    end
                    else begin
                        state <= state;
                        arvalid <= 1'b0;
                    end
                end

                64'd10, 64'd11, 64'd12, 64'd13, 64'd14, 64'd15, 64'd16, 64'd17, 64'd18: begin //all WR sequential 16 times
                    if (state == STATE_IDLE) begin
                        if (start_proc == 1'b1) begin
                            seed <= seed_init;
                            state <= STATE_ADDR;
                            //address
                            awid <= 12'd0;
                            awvalid <= 1'b1;
                            unique case (test_case)
                                64'd10: begin
                                    awuser <= 6'b000000; //non-cacheable
                                end        
                                64'd11: begin
                                    awuser <= 6'b000001; //cacheable own
                                end
                                64'd12: begin
                                    awuser <= 6'b000010; //non-cacheable push
                                end
                                64'd13: begin
                                    awuser <= 6'b110000; //non-cacheable
                                end        
                                64'd14: begin
                                    awuser <= 6'b110001; //cacheable own
                                end
                                64'd15: begin
                                    awuser <= 6'b110010; //non-cacheable push
                                end
                                64'd16: begin
                                    awuser <= 6'b100000; //non-cacheable
                                end        
                                64'd17: begin
                                    awuser <= 6'b100001; //cacheable own
                                end
                                64'd18: begin
                                    awuser <= 6'b100010; //non-cacheable push
                                end

                                default: begin
                                    awuser <= 6'b000000; //non-cacheable
                                end
                            endcase

                            unique case(addr_range) 
                                64'd1: begin
                                    addr_offset <= random_offset_32K;
                                end
                                64'd2: begin
                                    addr_offset <= random_offset_128K;
                                end
                                64'd3: begin
                                    addr_offset <= random_offset_1M;
                                end
                                64'd4: begin
                                    addr_offset <= random_offset_4M;
                                end
                                64'd5: begin
                                    addr_offset <= random_offset_16M;
                                end
                                64'd6: begin
                                    addr_offset <= random_offset_32M;
                                end

                                default: begin
                                    addr_offset <= random_offset_32K;
                                end
                            endcase
                            //data
                            wvalid <= 1'b1;
                            wdata <= '1;
                            wlast <= 1'b1;
                            wstrb <= 64'hffffffffffffffff;
                        end
                        else begin
                            state <= STATE_IDLE;
                        end
                    end
                    else if (state == STATE_ADDR) begin
                        //change status
                        if (awready & wready) begin
                            set_w_done_inf();
                        end
                        else if (wvalid == 1'b0) begin
                            if (awready) begin
                                set_w_done_inf();
                            end
                            else begin
                                state <= STATE_ADDR;
                            end
                        end
                        else if (awvalid == 1'b0) begin
                            if (wready) begin
                                set_w_done_inf();
                            end
                            else begin
                                state <= STATE_ADDR; 
                            end
                        end
                        else begin
                            //change address
                            if (awready) begin
                                awvalid <= 1'b0;
                            end
                            else begin
                                awvalid <= awvalid;
                            end
                            //change data
                            if (wready) begin
                                wvalid <= 1'b0; 
                                wlast <= 1'b0;
                                wstrb <= 64'h0;
                                wdata <= '0;
                            end
                            else begin
                                wvalid <= wvalid;
                                wlast <= wlast;
                                wstrb <= wstrb;
                                wdata <= wdata;
                            end
                            state <= STATE_ADDR;
                        end
                    end
                    else begin
                        state <= state; 
                        awvalid <= 1'b0;
                    end
                end

                64'd73,64'd74,64'd75,64'd76: begin
                    if (state == STATE_IDLE) begin
                        if (start_proc == 1'b1) begin
                            state <= STATE_ADDR;
                            addr_offset <= 64'd0;
                            awvalid <= 1'b1;
                            if (test_case == 64'd73) begin //barrier
                                awuser <= 6'b000011; 
                            end
                            else if (test_case == 64'd74) begin //flush single DCOH cache line
                                awuser <= 6'b000100; 
                            end
                            else if (test_case == 64'd75) begin //flush entire DCOH host cache
                                awuser <= 6'b000101; 
                            end
                            else if (test_case == 64'd76) begin //flush entire DCOH device cache
                                awuser <= 6'b000110; 
                            end
                            else begin //should never enter this case
                                awuser <= 6'b111111; 
                            end
                        end
                        else begin
                            state <= STATE_IDLE;
                        end
                    end
                    else if (state == STATE_ADDR) begin
                        if (awready) begin
                            state <= STATE_DATA;
                            awvalid <= 1'b0;
                            wvalid <= 1'b1;
                            wlast <= 1'b1;
                            wstrb <= 64'h0;
                        end
                        else begin
                            state <= STATE_ADDR;
                            awvalid <= 1'b1;
                        end
                    end
                    else if (state == STATE_DATA) begin
                        if (wready) begin
                            state <= STATE_WRES;
                            wvalid <= 1'b0;
                            wlast <= 1'b0;
                            wstrb <= 64'h0;
                        end
                        else begin
                            state <= STATE_DATA;
                            wvalid <= 1'b1;
                            wlast <= 1'b1;
                            wstrb <= wstrb; 
                        end
                    end
                    else if (state == STATE_WRES) begin
                        if (bvalid) begin
                            state <= STATE_W_WAIT;
                        end
                        else begin
                            state <= STATE_WRES;
                        end
                    end
                    else if (state == STATE_W_WAIT) begin
                        if (!bvalid) begin
                            state <= STATE_W_DONE;
                        end
                        else begin
                            state <= STATE_W_WAIT;
                        end
                    end
                    else begin
                        state <= state; 
                        awvalid <= 1'b0;
                    end       
                end

                default: begin
                    state <= state; 
                    awvalid <= 1'b0;
                    arvalid <= 1'b0;
                end
            endcase
        end
    end


    always_comb begin
        random_offset_32K = {49'b0, seed[8:0], 6'b0};
        random_offset_128K = {47'b0, seed[10:0], 6'b0};
        random_offset_1M = {44'b0, seed[13:0], 6'b0};
        random_offset_4M = {42'b0, seed[15:0], 6'b0};
        random_offset_16M = {40'b0, seed[17:0], 6'b0};
        random_offset_32M = {39'b0, seed[18:0], 6'b0};
    end

    always_comb begin
        araddr = page_addr_0 + addr_offset;
        awaddr = page_addr_0 + addr_offset;
    end

endmodule