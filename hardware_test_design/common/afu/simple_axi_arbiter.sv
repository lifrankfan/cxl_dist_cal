
`include "cxl_ed_defines.svh.iv"
import mc_axi_if_pkg::*;
import afu_axi_if_pkg::*;

module simple_axi_arbiter (
    input  logic             clk,
    input  logic             rst_n,

    // Slave 0 (Host / CXL IP)
    input  t_to_mc_axi4      s0_axi_w,
    output t_from_mc_axi4    s0_axi_r,

    // Slave 1 (User AFU)
    input  t_to_mc_axi4      s1_axi_w,
    output t_from_mc_axi4    s1_axi_r,

    // Master (Memory Controller)
    output t_to_mc_axi4      m_axi_w,
    input  t_from_mc_axi4    m_axi_r
);

    // ------------------------------------------------------------------------
    // Write Channel Arbitration (AW & W)
    // ------------------------------------------------------------------------
    // Simple priority: Round Robin or Fixed. Let's use Round Robin.
    // We lock the grant until WLAST is seen to avoid interleaving W data.

    typedef enum logic [1:0] {IDLE, GRANT_S0, GRANT_S1} state_t;
    state_t wr_state;
    logic wr_priority; // 0: S0, 1: S1

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            wr_state <= IDLE;
            wr_priority <= 0;
        end else begin
            case (wr_state)
                IDLE: begin
                    if (s0_axi_w.awvalid && s1_axi_w.awvalid) begin
                        if (wr_priority == 0) wr_state <= GRANT_S0;
                        else                  wr_state <= GRANT_S1;
                    end else if (s0_axi_w.awvalid) begin
                        wr_state <= GRANT_S0;
                    end else if (s1_axi_w.awvalid) begin
                        wr_state <= GRANT_S1;
                    end
                end
                GRANT_S0: begin
                    // Stay in GRANT_S0 until transaction completes (WLAST accepted)
                    // Note: AXI allows AW and W to be independent. 
                    // But for simplicity, we assume we hold grant until WLAST && WVALID && WREADY.
                    if (s0_axi_w.wvalid && s0_axi_w.wlast && m_axi_r.wready) begin
                        wr_state <= IDLE;
                        wr_priority <= 1; // Rotate priority
                    end
                end
                GRANT_S1: begin
                    if (s1_axi_w.wvalid && s1_axi_w.wlast && m_axi_r.wready) begin
                        wr_state <= IDLE;
                        wr_priority <= 0; // Rotate priority
                    end
                end
            endcase
        end
    end

    // ------------------------------------------------------------------------
    // Read Channel Arbitration (AR)
    // ------------------------------------------------------------------------
    // Simple Round Robin for AR. No locking needed as R channel is separate.

    logic rd_priority;
    logic grant_s0_rd;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            rd_priority <= 0;
        end else begin
            if (s0_axi_w.arvalid && s1_axi_w.arvalid) begin
                if (m_axi_r.arready) begin
                    rd_priority <= ~rd_priority; // Rotate after grant
                end
            end else if (s0_axi_w.arvalid && m_axi_r.arready) begin
                rd_priority <= 1; // Give chance to S1 next
            end else if (s1_axi_w.arvalid && m_axi_r.arready) begin
                rd_priority <= 0; // Give chance to S0 next
            end
        end
    end

    always_comb begin
        if (s0_axi_w.arvalid && s1_axi_w.arvalid) begin
            grant_s0_rd = (rd_priority == 0);
        end else if (s0_axi_w.arvalid) begin
            grant_s0_rd = 1;
        end else if (s1_axi_w.arvalid) begin // Added this else if to ensure S1 gets grant if S0 is not valid
            grant_s0_rd = 0;
        end else begin // No AR requests
            grant_s0_rd = 0; // Default to S0 or arbitrary
        end
    end

    // Unified Combinational Logic
    always_comb begin
        // --------------------------------------------------------------------
        // 1. Default Assignments / Initialization
        // --------------------------------------------------------------------
        m_axi_w = '0;
        
        s0_axi_r = '0;
        s0_axi_r.bresp = afu_axi_if_pkg::t_axi4_resp_encoding'(0);
        s0_axi_r.rresp = afu_axi_if_pkg::t_axi4_resp_encoding'(0);

        s1_axi_r = '0;
        s1_axi_r.bresp = afu_axi_if_pkg::t_axi4_resp_encoding'(0);
        s1_axi_r.rresp = afu_axi_if_pkg::t_axi4_resp_encoding'(0);

        // --------------------------------------------------------------------
        // 2. Write Channel Arbitration (AW & W)
        // --------------------------------------------------------------------
        case (wr_state)
            IDLE: begin
                // No grant
            end
            GRANT_S0: begin
                // Assign all fields from S0, will overwrite specific ones later if needed
                m_axi_w = s0_axi_w;
                m_axi_w.awid[11] = 1'b0; 
                
                s0_axi_r.awready = m_axi_r.awready;
                s0_axi_r.wready  = m_axi_r.wready;
            end
            GRANT_S1: begin
                m_axi_w = s1_axi_w;
                m_axi_w.awid[11] = 1'b1;

                s1_axi_r.awready = m_axi_r.awready;
                s1_axi_r.wready  = m_axi_r.wready;
            end
        endcase

        // --------------------------------------------------------------------
        // 3. Read Channel Arbitration (AR)
        // --------------------------------------------------------------------
        // We must overwrite AR fields in m_axi_w
        
        // Determine grant (combinational logic moved here or referenced)
        // Using the grant_s0_rd logic defined below (we can move it inside or keep it)
        // Since grant_s0_rd is driven by another always_comb, we can use it.
        
        if (grant_s0_rd) begin
            m_axi_w.arvalid = s0_axi_w.arvalid;
            m_axi_w.arid    = s0_axi_w.arid;
            m_axi_w.arid[11]= 1'b0;
            m_axi_w.araddr  = s0_axi_w.araddr;
            m_axi_w.arlen   = s0_axi_w.arlen;
            m_axi_w.arsize  = s0_axi_w.arsize;
            m_axi_w.arburst = s0_axi_w.arburst;
            m_axi_w.arprot  = s0_axi_w.arprot;
            m_axi_w.arqos   = s0_axi_w.arqos;
            m_axi_w.arcache = s0_axi_w.arcache;
            m_axi_w.arlock  = s0_axi_w.arlock;
            m_axi_w.arregion= s0_axi_w.arregion;
            m_axi_w.aruser  = s0_axi_w.aruser;
            
            s0_axi_r.arready = m_axi_r.arready;
        end else begin
            m_axi_w.arvalid = s1_axi_w.arvalid;
            m_axi_w.arid    = s1_axi_w.arid;
            m_axi_w.arid[11]= 1'b1;
            m_axi_w.araddr  = s1_axi_w.araddr;
            m_axi_w.arlen   = s1_axi_w.arlen;
            m_axi_w.arsize  = s1_axi_w.arsize;
            m_axi_w.arburst = s1_axi_w.arburst;
            m_axi_w.arprot  = s1_axi_w.arprot;
            m_axi_w.arqos   = s1_axi_w.arqos;
            m_axi_w.arcache = s1_axi_w.arcache;
            m_axi_w.arlock  = s1_axi_w.arlock;
            m_axi_w.arregion= s1_axi_w.arregion;
            m_axi_w.aruser  = s1_axi_w.aruser;
            
            s1_axi_r.arready = m_axi_r.arready;
        end

        // --------------------------------------------------------------------
        // 4. Write Response Channel (B)
        // --------------------------------------------------------------------
        // Overwrite bready
        m_axi_w.bready = 0; 

        if (m_axi_r.bvalid) begin
            if (m_axi_r.bid[11] == 1'b0) begin
                // Route to S0
                s0_axi_r.bvalid = 1'b1;
                s0_axi_r.bid    = m_axi_r.bid;
                s0_axi_r.bresp  = m_axi_r.bresp;
                s0_axi_r.buser  = m_axi_r.buser;
                m_axi_w.bready  = s0_axi_w.bready;
            end else begin
                // Route to S1
                s1_axi_r.bvalid = 1'b1;
                s1_axi_r.bid    = m_axi_r.bid;
                s1_axi_r.bid[11]= 1'b0; 
                s1_axi_r.bresp  = m_axi_r.bresp;
                s1_axi_r.buser  = m_axi_r.buser;
                m_axi_w.bready  = s1_axi_w.bready;
            end
        end

        // --------------------------------------------------------------------
        // 5. Read Response Channel (R)
        // --------------------------------------------------------------------
        // Overwrite rready
        m_axi_w.rready = 0;

        if (m_axi_r.rvalid) begin
            if (m_axi_r.rid[11] == 1'b0) begin
                 s0_axi_r.rvalid = 1'b1;
                 s0_axi_r.rid    = m_axi_r.rid;
                 s0_axi_r.rdata  = m_axi_r.rdata;
                 s0_axi_r.rresp  = m_axi_r.rresp;
                 s0_axi_r.rlast  = m_axi_r.rlast;
                 s0_axi_r.ruser  = m_axi_r.ruser;
                 m_axi_w.rready  = s0_axi_w.rready;
            end else begin
                 s1_axi_r.rvalid = 1'b1;
                 s1_axi_r.rid    = m_axi_r.rid;
                 s1_axi_r.rid[11]= 1'b0;
                 s1_axi_r.rdata  = m_axi_r.rdata;
                 s1_axi_r.rresp  = m_axi_r.rresp;
                 s1_axi_r.rlast  = m_axi_r.rlast;
                 s1_axi_r.ruser  = m_axi_r.ruser;
                 m_axi_w.rready  = s1_axi_w.rready;
            end
        end
    end

endmodule
