module l2_distance_engine #(
  parameter int BUS_W     = 512,
  parameter int ELEM_BITS = 32,
  parameter int DIM_MAX   = 128
)(
  input  logic                  clk,
  input  logic                  rst_n,

  // CSR
  input  logic [63:0]           test_case,
  input  logic                  start_i,
  input  logic [63:0]           base_pa,
  input  logic [63:0]           query_pa,
  input  logic [63:0]           num_vecs,
  input  logic [63:0]           dim_cfg,   // unused: currently assume dim_cfg == DIM_MAX

  // AXI Read (single master)
  output logic [63:0]           araddr_o,
  output logic [7:0]            arlen_o,
  output logic [2:0]            arsize_o,
  output logic [1:0]            arburst_o,
  output logic                  arvalid_o,
  input  logic                  arready_i,
  input  logic [BUS_W-1:0]      rdata_i,
  input  logic                  rvalid_i,
  input  logic                  rlast_i,
  output logic                  rready_o,

  // Results
  output logic [63:0]           cycles_o,
  output logic [63:0]           done_o,
  output logic [63:0]           last_result_o
);

  // ------------------------------------------------------------
  // Enable + start edge
  // ------------------------------------------------------------
  wire use_engine = (test_case == 64'd100);

  logic start_r;
  wire  start_posedge = start_i && !start_r;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      start_r <= 1'b0;
    else
      start_r <= start_i;
  end

  // ------------------------------------------------------------
  // Geometry on the AXI bus
  // ------------------------------------------------------------
  localparam int BYTES_PER_BEAT   = BUS_W/8;                         // 64B on 512-bit bus
  localparam int ELEMS_PER_BEAT   = BYTES_PER_BEAT / (ELEM_BITS/8);  // 16 elements of 32b
  localparam int BYTES_PER_VEC    = DIM_MAX * (ELEM_BITS/8);         // 128 * 4 = 512
  localparam int BEATS_PER_VEC    = BYTES_PER_VEC / BYTES_PER_BEAT;  // 512 / 64 = 8
  localparam int BEATS_QUERY      = BEATS_PER_VEC;

  // AXI fixed fields
  assign arburst_o = 2'b01;      // INCR
  assign arsize_o  = 3'd6;       // 64B beats on 512-bit bus

  // ------------------------------------------------------------
  // State, counters, buffers
  // ------------------------------------------------------------
  typedef enum logic [3:0] {IDLE, LOAD_Q, LOAD_Q_WAIT, RUN, RUN_WAIT, FLUSH1, FLUSH2, FLUSH3, FLUSH4, FLUSH5, FLUSH6, FLUSH7, DONE} state_t;
  state_t state, nstate;

  // We'll only assert rready when we expect data
  assign rready_o  = use_engine &&
                     ((state == LOAD_Q_WAIT) || (state == RUN_WAIT));

  logic [63:0] cyc;
  logic        count_en;

  logic [63:0] vec_idx;    // index within base vectors
  logic [7:0]  beat_idx;   // 0..7 for 8 beats per vector

  // Query buffer (128 x 32-bit). Each element is Q16.16 fixed-point.
  logic [31:0] qbuf[0:DIM_MAX-1];

  // Distance accumulator: signed Q32.32 (stored in 64 bits)
  logic signed [63:0] acc;

  // AXI address control
  logic [63:0] araddr_r;
  logic [7:0]  arlen_r;
  logic        arfire;

  assign araddr_o  = araddr_r;
  assign arlen_o   = arlen_r;
  assign arvalid_o = use_engine && (state == LOAD_Q || state == RUN);
  assign arfire    = arvalid_o && arready_i;

  // ------------------------------------------------------------
  // Pipeline Stage 1 Registers (Input Capture)
  // Input: rdata_i, qbuf
  // Output: s1_x_reg, s1_q_reg, s1_valid
  // ------------------------------------------------------------
  logic signed [31:0] s1_x_reg [0:ELEMS_PER_BEAT-1];
  logic signed [31:0] s1_q_reg [0:ELEMS_PER_BEAT-1];
  logic               s1_valid;
  logic               s1_rlast;

  // ------------------------------------------------------------
  // Pipeline Stage 2 Registers (Subtitle)
  // Input: s1_x_reg, s1_q_reg
  // Output: s2_diff_reg, s2_valid
  // ------------------------------------------------------------
  logic signed [31:0] s2_diff_reg [0:ELEMS_PER_BEAT-1];
  logic               s2_valid;

  // ------------------------------------------------------------
  // Pipeline Stage 3 Registers (Delay/Pipe for DSP packing)
  // Input: s2_diff_reg
  // Output: s3_diff_pipe, s3_valid
  // ------------------------------------------------------------
  logic signed [31:0] s3_diff_pipe [0:ELEMS_PER_BEAT-1];
  logic               s3_valid;

  // ------------------------------------------------------------
  // Pipeline Stage 4 Registers (Multiplier Stage 1)
  // Input: s3_diff_pipe
  // Output: s4_mult_pipe, s4_valid
  // ------------------------------------------------------------
  logic signed [63:0] s4_mult_pipe [0:ELEMS_PER_BEAT-1];
  logic               s4_valid;

  // ------------------------------------------------------------
  // Pipeline Stage 5 Registers (Multiplier Stage 2 / Final Square)
  // Input: s4_mult_pipe
  // Output: s5_sq_diff, s5_valid
  // ------------------------------------------------------------
  logic signed [63:0] s5_sq_diff [0:ELEMS_PER_BEAT-1];
  logic               s5_valid;

  // ------------------------------------------------------------
  // Pipeline Stage 6 Registers (Partial Reduction 16 -> 4)
  // Input: s5_sq_diff
  // Output: s6_partial_sum, s6_valid
  // ------------------------------------------------------------
  logic signed [63:0] s6_partial_sum [0:3];
  logic               s6_valid;
  
  // ------------------------------------------------------------
  // Pipeline Stage 7 (Sum of Partials)
  // Input: s6_partial_sum
  // Output: s7_sum_of_4, s7_valid
  // ------------------------------------------------------------
  logic signed [63:0] s7_sum_of_4;
  logic               s7_valid;
  
  // ------------------------------------------------------------
  // Cycle counter: per-run reset, active during processing
  // ------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cyc <= 64'd0;
    end else if (!use_engine) begin
      cyc <= 64'd0;
    end else if ((state == IDLE || state == DONE) && start_posedge) begin
      // New run: clear cycle counter at start
      cyc <= 64'd0;
    end else if (count_en) begin
      cyc <= cyc + 64'd1;
    end
  end

  // cycle counter enable
  always_comb begin
    count_en = 1'b0;
    unique case (state)
      LOAD_Q, LOAD_Q_WAIT, RUN, RUN_WAIT, FLUSH1, FLUSH2, FLUSH3, FLUSH4, FLUSH5, FLUSH6, FLUSH7: count_en = use_engine;
      default:                                            count_en = 1'b0;
    endcase
  end

  // ------------------------------------------------------------
  // FSM
  // ------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= IDLE;
    else
      state <= nstate;
  end

  always_comb begin
    nstate = state;
    unique case (state)
      IDLE:
        nstate = (use_engine && start_posedge) ? LOAD_Q : IDLE;

      LOAD_Q:
        nstate = arfire ? LOAD_Q_WAIT : LOAD_Q;

      LOAD_Q_WAIT:
        // Wait for pipeline drain after query load
        nstate = (s6_valid && !s5_valid) ? RUN : LOAD_Q_WAIT;

      RUN:
        nstate = arfire ? RUN_WAIT : RUN;

      RUN_WAIT:
        // Wait for last beat, then go to FLUSH1
        nstate = (rvalid_i && rlast_i) ? FLUSH1 : RUN_WAIT;

      FLUSH1: // Drain Stage 1 -> 2
        nstate = FLUSH2;

      FLUSH2: // Drain Stage 2 -> 3
        nstate = FLUSH3;

      FLUSH3: // Drain Stage 3 -> 4
        nstate = FLUSH4;

      FLUSH4: // Drain Stage 4 -> 5
        nstate = FLUSH5;

      FLUSH5: // Drain Stage 5 -> 6
        nstate = FLUSH6;

      FLUSH6: // Drain Stage 6 -> 7
        nstate = FLUSH7;

      FLUSH7: // Drain Stage 7 -> 8 (Final Accumulation)
        nstate = ((vec_idx + 64'd1 == num_vecs) ? DONE : RUN);

      DONE:
        nstate = (use_engine && start_posedge) ? LOAD_Q :
                 (!use_engine)                 ? IDLE   :
                                               DONE;

      default:
        nstate = IDLE;
    endcase
  end

  // ------------------------------------------------------------
  // Pipeline Stage 1: Input Capture (Registered)
  // Breaks timing path from MC FIFO
  // ------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s1_valid <= 1'b0;
      s1_rlast <= 1'b0;
    end else if (!use_engine) begin
      s1_valid <= 1'b0;
      s1_rlast <= 1'b0;
    end else begin
      s1_valid <= 1'b0;
      
      if (rvalid_i && (state == LOAD_Q_WAIT || state == RUN_WAIT)) begin
        s1_valid <= 1'b1;
        s1_rlast <= rlast_i;
        
        for (int k = 0; k < ELEMS_PER_BEAT; k++) begin
          automatic int idx = beat_idx * ELEMS_PER_BEAT + k;
          s1_x_reg[k] <= rdata_i[k*ELEM_BITS +: ELEM_BITS];
          s1_q_reg[k] <= qbuf[idx];
        end
      end
    end
  end

  // ------------------------------------------------------------
  // Pipeline Stage 2: Compute Differences (Registered)
  // Input: s1_x_reg, s1_q_reg
  // ------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s2_valid <= 1'b0;
    end else if (!use_engine) begin
      s2_valid <= 1'b0;
    end else begin
      s2_valid <= s1_valid; // Propagate valid
      
      if (s1_valid) begin
        for (int k = 0; k < ELEMS_PER_BEAT; k++) begin
          s2_diff_reg[k] <= s1_x_reg[k] - s1_q_reg[k];
        end
      end
    end
  end

  // ------------------------------------------------------------
  // Pipeline Stage 3: Delay/Pipe (Registered)
  // Input: s2_diff_reg
  // ------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s3_valid <= 1'b0;
    end else if (!use_engine) begin
      s3_valid <= 1'b0;
    end else begin
      s3_valid <= s2_valid; // Propagate valid
      
      if (s2_valid) begin
        for (int k = 0; k < ELEMS_PER_BEAT; k++) begin
          s3_diff_pipe[k] <= s2_diff_reg[k];
        end
      end
    end
  end

  // ------------------------------------------------------------
  // Pipeline Stage 4: Multiplier Stage 1 (Registered)
  // Input: s3_diff_pipe
  // ------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s4_valid <= 1'b0;
    end else if (!use_engine) begin
      s4_valid <= 1'b0;
    end else begin
      s4_valid <= s3_valid; // Propagate valid
      
      if (s3_valid) begin
        for (int k = 0; k < ELEMS_PER_BEAT; k++) begin
           // To infer DSP pipeline registers, we just register the multiply result
           // This intermediate register allows retiming into the DSP
           s4_mult_pipe[k] <= s3_diff_pipe[k] * s3_diff_pipe[k];
        end
      end
    end
  end

  // ------------------------------------------------------------
  // Pipeline Stage 5: Multiplier Stage 2 / Final Square (Registered)
  // Input: s4_mult_pipe
  // ------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s5_valid <= 1'b0;
    end else if (!use_engine) begin
      s5_valid <= 1'b0;
    end else begin
      s5_valid <= s4_valid; // Propagate valid
      
      if (s4_valid) begin
        for (int k = 0; k < ELEMS_PER_BEAT; k++) begin
          s5_sq_diff[k] <= s4_mult_pipe[k];
        end
      end
    end
  end

  // ------------------------------------------------------------
  // Pipeline Stage 6: Partial Reduction 16 -> 4 (Registered)
  // Input: s5_sq_diff
  // ------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s6_valid <= 1'b0;
    end else if (!use_engine) begin
      s6_valid <= 1'b0;
    end else begin
      s6_valid <= s5_valid; // Propagate valid

      if (s5_valid) begin
        s6_partial_sum[0] <= s5_sq_diff[0]  + s5_sq_diff[1]  + s5_sq_diff[2]  + s5_sq_diff[3];
        s6_partial_sum[1] <= s5_sq_diff[4]  + s5_sq_diff[5]  + s5_sq_diff[6]  + s5_sq_diff[7];
        s6_partial_sum[2] <= s5_sq_diff[8]  + s5_sq_diff[9]  + s5_sq_diff[10] + s5_sq_diff[11];
        s6_partial_sum[3] <= s5_sq_diff[12] + s5_sq_diff[13] + s5_sq_diff[14] + s5_sq_diff[15];
      end
    end
  end

  // ------------------------------------------------------------
  // Pipeline Stage 7: Sum of Partials (Registered)
  // Input: s6_partial_sum
  // ------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s7_valid <= 1'b0;
    end else if (!use_engine) begin
      s7_valid <= 1'b0;
    end else begin
      s7_valid <= s6_valid; // Propagate valid

      if (s6_valid) begin
        s7_sum_of_4 <= s6_partial_sum[0] + s6_partial_sum[1] + s6_partial_sum[2] + s6_partial_sum[3];
      end
    end
  end

  // ------------------------------------------------------------
  // Main Control Logic & Stage 4 (Final Accumulation)
  // ------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      vec_idx       <= 64'd0;
      beat_idx      <= 8'd0;
      araddr_r      <= 64'd0;
      arlen_r       <= 8'd0;
      cycles_o      <= 64'd0;
      done_o        <= 64'd0;
      last_result_o <= 64'd0;
      acc           <= '0;
      for (int i = 0; i < DIM_MAX; i++) qbuf[i] <= 32'd0;
    end else begin
      if (!use_engine) begin
        vec_idx       <= 64'd0;
        beat_idx      <= 8'd0;
        cycles_o      <= 64'd0;
        done_o        <= 64'd0;
        last_result_o <= 64'd0;
        acc           <= '0;
      end else begin
        // New run prep
        if ((state == IDLE || state == DONE) && start_posedge) begin
          vec_idx       <= 64'd0;
          beat_idx      <= 8'd0;
          cycles_o      <= 64'd0;
          done_o        <= 64'd0;
          last_result_o <= 64'd0;
          acc           <= '0;
          araddr_r      <= query_pa;
          arlen_r       <= BEATS_QUERY - 1;
        end

        // -----------------------
        // Stage 8 Accumulation
        // -----------------------
        if (s7_valid && state != LOAD_Q_WAIT) begin
             acc <= acc + s7_sum_of_4;
        end

        // -----------------------
        // State actions
        // -----------------------
        unique case (state)
          IDLE: begin
            araddr_r <= query_pa;
            arlen_r  <= BEATS_QUERY - 1;
          end

          LOAD_Q_WAIT: begin
            // Load qbuf
            if (rvalid_i) begin
              for (int k = 0; k < ELEMS_PER_BEAT; k++) begin
                automatic int idx = beat_idx * ELEMS_PER_BEAT + k;
                if (idx < DIM_MAX) qbuf[idx] <= rdata_i[k*ELEM_BITS +: ELEM_BITS];
              end
              if (rlast_i) begin
                beat_idx <= 8'd0;
                araddr_r <= base_pa;
                arlen_r  <= BEATS_PER_VEC - 1;
                acc      <= '0; // Clear accumulator
              end else begin
                beat_idx <= beat_idx + 8'd1;
              end
            end
          end

          RUN: begin
            araddr_r <= base_pa + vec_idx * BYTES_PER_VEC;
            arlen_r  <= BEATS_PER_VEC - 1;
          end

          RUN_WAIT: begin
            if (rvalid_i) begin
              if (rlast_i) beat_idx <= 8'd0;
              else         beat_idx <= beat_idx + 8'd1;
            end
          end
          
          FLUSH7: begin
            // Final result capture capture
            last_result_o <= acc + s7_sum_of_4; 
            acc <= '0; // Clear for next vector

            if (vec_idx + 64'd1 == num_vecs) begin
              // Done
            end else begin
              vec_idx <= vec_idx + 64'd1;
              araddr_r <= base_pa + (vec_idx + 64'd1) * BYTES_PER_VEC;
            end
          end

          DONE: begin
            done_o   <= 64'd1;
            cycles_o <= cyc;
          end
          
          default: ; 
        endcase
      end
    end
  end

endmodule
