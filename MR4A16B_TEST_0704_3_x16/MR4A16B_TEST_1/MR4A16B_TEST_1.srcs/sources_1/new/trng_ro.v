`timescale 1ns/1ps

// Physical entropy candidate. Digital simulation cannot establish its entropy
// rate or independence: validate raw samples and health status on the board.
module trng_8bit #(
    parameter SAMPLE_LOG2=7,
    parameter RPT_LIMIT=64,
    parameter WATCHDOG_BITS=16
)(
    input wire clk, rst_n,
    output reg [7:0] rnd_data,
    output reg rnd_valid,
    output reg health_fail
);
    (* keep="true" *) wire [4:0] ro_taps;
    generate
        genvar ring_no;
        for (ring_no=0;ring_no<5;ring_no=ring_no+1) begin : ro_bank
            (* dont_touch="true" *) mram_ring_oscillator #(.LENGTH(5+2*ring_no)) u_ring(.bit_out(ro_taps[ring_no]));
        end
    endgenerate
    (* ASYNC_REG="TRUE", SHREG_EXTRACT="NO" *) reg [4:0] ro_meta,ro_sync;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin ro_meta<=0;ro_sync<=0;end
        else begin ro_meta<=ro_taps;ro_sync<=ro_meta;end
    end
    reg [SAMPLE_LOG2-1:0] sample_counter;
     wire sample_tick=&sample_counter;
     wire raw_bit=^ro_sync;
    reg previous_raw,have_raw,pair_pending,pair_first;
    reg source_qualified;
    reg [7:0] repetition_count,window_count;
    reg [8:0] ones_count;
    wire [8:0] ones_next=ones_count+{8'd0,raw_bit};
    reg [WATCHDOG_BITS-1:0] valid_watchdog;
    reg [7:0] shift_reg;
    reg [2:0] bit_count;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) sample_counter<=0;
        else sample_counter<=sample_counter+1'b1;
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) valid_watchdog<=0;
        else if(rnd_valid) valid_watchdog<=0;
        else if(!(&valid_watchdog)) valid_watchdog<=valid_watchdog+1'b1;
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rnd_data<=0;rnd_valid<=0;health_fail<=0;source_qualified<=0;
            previous_raw<=0;have_raw<=0;pair_pending<=0;pair_first<=0;
            repetition_count<=0;window_count<=0;ones_count<=0;
            shift_reg<=0;bit_count<=0;
        end else begin
            rnd_valid<=0;
            if(&valid_watchdog) health_fail<=1;
            if(!health_fail && sample_tick) begin
                // Basic stuck/bias checks, not a certified entropy assessment.
                have_raw<=1;previous_raw<=raw_bit;
                if(have_raw && raw_bit==previous_raw) begin
                    if(repetition_count>=RPT_LIMIT-1) health_fail<=1;
                    else repetition_count<=repetition_count+1'b1;
                end else repetition_count<=1;
                window_count<=window_count+1'b1;
                if(window_count==8'hff) begin
                    if(ones_next<9'd32 || ones_next>9'd224) health_fail<=1;
                    else source_qualified<=1;
                    ones_count<=0;
                end else ones_count<=ones_next;
                // Von Neumann pairs: discard 00/11; 01->0, 10->1.
                if(!pair_pending) begin pair_first<=raw_bit;pair_pending<=1;end
                else begin
                    pair_pending<=0;
                    if(pair_first!=raw_bit) begin
                        shift_reg<={shift_reg[6:0],pair_first};
                        bit_count<=bit_count+1'b1;
                        if(bit_count==3'd7) begin
                            rnd_data<={shift_reg[6:0],pair_first};
                            // Do not offer bytes until one raw-sample window
                            // has passed the basic startup balance check.
                            if(source_qualified) rnd_valid<=1;
                            bit_count<=0;
                        end
                    end
                end
            end
        end
    end
endmodule

// Use explicit, preserved LUTs so synthesis cannot collapse the odd inverter
// ring. Only these intentional physical loops receive ALLOW_COMBINATORIAL_LOOPS.
(* keep_hierarchy="yes" *)
module mram_ring_oscillator #(parameter LENGTH=5)(output wire bit_out);
    (* keep="true",dont_touch="true" *) wire [LENGTH-1:0] ring;
    generate
        genvar stage;
        for(stage=0;stage<LENGTH;stage=stage+1) begin : invert
            (* dont_touch="true" *) LUT1 #(.INIT(2'b01)) u_inv(
                .I0(ring[(stage+LENGTH-1)%LENGTH]),.O(ring[stage]));
        end
    endgenerate
    assign bit_out=ring[LENGTH-1];
endmodule

module mram_trng_seed(
    input wire clk,rst_n,take,
    output reg [31:0] seed_data,
    output wire seed_ready,
    output wire health_fail
);
    wire [7:0] entropy_byte;
    wire entropy_valid,source_fail;
    trng_8bit u_entropy(.clk(clk),.rst_n(rst_n),.rnd_data(entropy_byte),
        .rnd_valid(entropy_valid),.health_fail(source_fail));
    reg [31:0] partial_seed,last_taken;
    reg [1:0] byte_count;
    reg ready_reg,have_last,local_fail;
    reg [2:0] rejected_count;
    wire [31:0] candidate={partial_seed[23:0],entropy_byte};
    assign health_fail=source_fail || local_fail;
    assign seed_ready=ready_reg && !health_fail;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            seed_data<=0;partial_seed<=0;last_taken<=0;byte_count<=0;
            ready_reg<=0;have_last<=0;local_fail<=0;rejected_count<=0;
        end else begin
            // The cached word is immutable until consumed. Discard incoming
            // bytes while full; a consumed seed is never offered a second time.
            if(take && ready_reg) begin
                last_taken<=seed_data;have_last<=1;ready_reg<=0;
                partial_seed<=0;byte_count<=0;rejected_count<=0;
            end
            if(health_fail) begin ready_reg<=0;partial_seed<=0;byte_count<=0;end
            else if(entropy_valid && !ready_reg && !take) begin
                partial_seed<=candidate;byte_count<=byte_count+1'b1;
                if(byte_count==2'd3) begin
                    byte_count<=0;partial_seed<=0;
                    if(candidate!=32'd0 && candidate!=32'hffffffff &&
                       (!have_last || candidate!=last_taken)) begin
                        seed_data<=candidate;ready_reg<=1;rejected_count<=0;
                    end else if(rejected_count==3'd7) local_fail<=1;
                    else rejected_count<=rejected_count+1'b1;
                end
            end
        end
    end
endmodule
