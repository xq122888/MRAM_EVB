`timescale 1ns/1ps
// These models are for cycle-level comparison only. They do not validate the
// clock wizard, TRNG, physical MRAM, metastability, or implementation timing.
module clk_wiz_0(input clk_in1_p, clk_in1_n, resetn,
                 output clk_200m, clk_400m, locked);
  assign clk_200m=clk_in1_p;
  assign clk_400m=clk_in1_p;
  assign locked=resetn;
endmodule
module trng_8bit(input clk,rst_n,output [7:0] rnd_data,output rnd_valid);
  assign rnd_data=8'ha5;
  assign rnd_valid=rst_n;
endmodule
// Deterministic seed-source fixture for DIGITAL top-level tests only.
// The production RO/synchronizer/conditioner is tested separately with injected
// raw samples; neither fixture establishes physical entropy quality.
module mram_trng_seed(input clk,rst_n,take,output reg [31:0] seed_data,
                      output reg seed_ready,output wire health_fail);
  reg [13:0] wait_cycles;
  reg [31:0] next_value;
  reg [31:0] fixture_seed=32'h6d2b79f5;
  initial begin
    if($value$plusargs("fixture_seed=%h",fixture_seed)) begin
      if(fixture_seed==0 || fixture_seed==32'hffffffff)
        $fatal(1,"Invalid digital fixture seed");
    end
  end
  assign health_fail=1'b0;
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin seed_data<=fixture_seed;seed_ready<=0;wait_cycles<=0;end
    else if(take && seed_ready) begin
      next_value=seed_data^(seed_data<<13);
      next_value=next_value^(next_value>>17);
      seed_data<=next_value^(next_value<<5);seed_ready<=0;wait_cycles<=0;
    end else if(!seed_ready) begin
      if(wait_cycles==14'd9999) seed_ready<=1;
      else wait_cycles<=wait_cycles+1'b1;
    end
  end
endmodule
// Historical pin/state equivalence to a317d2b intentionally no longer runs:
// that implementation contains the first-cycle/loop-restart waveform bugs.
// tb_mram_pins.sv now checks an independent external-pin contract instead.
module tb_top_predicates;
  reg [20:0] hold=0, length=0;
  reg [22:0] count=0;
  reg [15:0] period=0;
  reg split_banks=0;
  reg [15:0] period_w_alt=0,period_r_alt=0;
  wire [15:0] unit_period_w=split_banks?period_w_alt:period;
  wire [15:0] unit_period_r=split_banks?period_r_alt:period;
  reg [31:0] index=0,loops=0;
  wire [31:0] decoded_last_loop=loops-32'd1;
  wire [20:0] decoded_last_address=length-21'd1;
  wire [15:0] decoded_period_last_w=unit_period_w-16'd1;
  wire [15:0] decoded_period_last_r=unit_period_r-16'd1;
  wire [15:0] decoded_period_before_last_w=unit_period_w-16'd2;
  wire [15:0] decoded_period_before_last_r=unit_period_r-16'd2;
  wire [20:0] decoded_gn_write={5'b0,unit_period_w}-{5'b0,dut.spi_t_gl2gh_w};
  wire [20:0] decoded_gn_read={5'b0,unit_period_r}-{5'b0,dut.spi_t_gl2gh_r};
  wire [20:0] decoded_compare_early_w = {5'b0,dut.spi_t_avqv_r} - {5'b0,dut.spi_t_avav_w};
  wire [20:0] decoded_compare_early_r = {5'b0,dut.spi_t_avqv_r} - {5'b0,dut.spi_t_avav_r};
  wire [20:0] decoded_en_release_w = {5'b0,dut.spi_t_avav_w} - {5'b0,dut.spi_t_el2eh_w};
  wire [20:0] decoded_en_release_r = {5'b0,dut.spi_t_avav_r} - {5'b0,dut.spi_t_el2eh_r};
  wire [20:0] decoded_wn_release_w = {5'b0,dut.spi_t_avav_w} - {5'b0,dut.spi_t_wl2wh_w};
  wire [20:0] decoded_wn_release_r = {5'b0,dut.spi_t_avav_r} - {5'b0,dut.spi_t_wl2wh_w};
  wire [20:0] decoded_ub_release_w = {5'b0,dut.spi_t_avav_w} - {5'b0,dut.spi_t_ubl2ubh_w};
  wire [20:0] decoded_ub_release_r = {5'b0,dut.spi_t_avav_r} - {5'b0,dut.spi_t_ubl2ubh_r};
  wire [20:0] decoded_lb_release_w = {5'b0,dut.spi_t_avav_w} - {5'b0,dut.spi_t_lbl2lbh_w};
  wire [20:0] decoded_lb_release_r = {5'b0,dut.spi_t_avav_r} - {5'b0,dut.spi_t_lbl2lbh_r};
  wire decoded_period_has_one_w = (dut.spi_t_avav_w >= 16'd1);
  wire decoded_period_has_one_r = (dut.spi_t_avav_r >= 16'd1);
  wire decoded_period_has_two_w = (dut.spi_t_avav_w >= 16'd2);
  wire decoded_period_has_two_r = (dut.spi_t_avav_r >= 16'd2);
  reg [1:0] read_select=0;
  reg [15:0] unit_gl_w=2,unit_gl_r=10;
  reg [15:0] unit_avqv=9,unit_en_w=3,unit_en_r=10,unit_wn=2;
  reg [15:0] unit_ub_w=2,unit_ub_r=10,unit_lb_w=2,unit_lb_r=10;
  wire phase_d=read_select[0],phase_d2=read_select[1];
  wire [15:0] unit_selected_period=phase_d2?unit_period_r:unit_period_w;
  // Exhaust the new 7/9-bit LUT comparators against the native operator.
  wire slice_less7,slice_less9;
  mram_less_lut #(.WIDTH(7)) lt_slice7(.a(count[6:0]),.b(length[6:0]),.less(slice_less7));
  mram_less_lut #(.WIDTH(9)) lt_slice9(.a(count[8:0]),.b(length[8:0]),.less(slice_less9));
  reg [4:0] unit_tx_length=0,unit_tx_pointer=0;
  integer n,k,cases=0;
  top dut(.clkp(1'b0),.clkn(1'b1),.rst_n(1'b0),.spi_cs_n(1'b1),
          .spi_sclk(1'b0),.spi_mosi(1'b0));
  initial begin
    force dut.addr_hold_cnt=hold;force dut.t_AVAV=unit_selected_period;
    force dut.u_spi_protocol.tx_byte_cnt=unit_tx_length;
    force dut.u_spi_protocol.tx_byte_ptr=unit_tx_pointer;
    force dut.hold_release_count=hold;force dut.hold_sample_count=hold;
    force dut.addr_cnt=count;force dut.addr_num=length;
    force dut.addr_compare_count=count;
    force dut.loop_idx=index;force dut.loop_count=loops;
    force dut.rd_en_d=phase_d;force dut.rd_en_d2=phase_d2;
    force dut.spi_t_gl2gh_w=unit_gl_w;force dut.spi_t_gl2gh_r=unit_gl_r;
    force dut.spi_t_avqv_r=unit_avqv;
    force dut.spi_t_el2eh_w=unit_en_w;force dut.spi_t_el2eh_r=unit_en_r;
    force dut.spi_t_wl2wh_w=unit_wn;
    force dut.spi_t_ubl2ubh_w=unit_ub_w;force dut.spi_t_ubl2ubh_r=unit_ub_r;
    force dut.spi_t_lbl2lbh_w=unit_lb_w;force dut.spi_t_lbl2lbh_r=unit_lb_r;
    force dut.spi_last_loop_index=decoded_last_loop;
    force dut.spi_last_test_address=decoded_last_address;
    force dut.spi_t_avav_w=unit_period_w;force dut.spi_t_avav_r=unit_period_r;
    force dut.spi_period_last_w=decoded_period_last_w;
    force dut.spi_period_last_r=decoded_period_last_r;
    force dut.spi_period_before_last_w=decoded_period_before_last_w;
    force dut.spi_period_before_last_r=decoded_period_before_last_r;
    force dut.spi_gn_release_w=decoded_gn_write;
    force dut.spi_gn_release_r=decoded_gn_read;
    force dut.spi_compare_early_w=decoded_compare_early_w;
    force dut.spi_compare_early_r=decoded_compare_early_r;
    force dut.spi_en_release_w=decoded_en_release_w;
    force dut.spi_en_release_r=decoded_en_release_r;
    force dut.spi_wn_release_w=decoded_wn_release_w;
    force dut.spi_wn_release_r=decoded_wn_release_r;
    force dut.spi_ub_release_w=decoded_ub_release_w;
    force dut.spi_ub_release_r=decoded_ub_release_r;
    force dut.spi_lb_release_w=decoded_lb_release_w;
    force dut.spi_lb_release_r=decoded_lb_release_r;
    force dut.spi_period_has_one_w=decoded_period_has_one_w;
    force dut.spi_period_has_one_r=decoded_period_has_one_r;
    force dut.spi_period_has_two_w=decoded_period_has_two_w;
    force dut.spi_period_has_two_r=decoded_period_has_two_r;
  end
  task check;
    begin
      #1;cases=cases+1;
      if(dut.u_spi_protocol.tx_more_bytes !== (unit_tx_pointer < (unit_tx_length-1)) ||
         slice_less7 !== (count[6:0]<length[6:0]) ||
         slice_less9 !== (count[8:0]<length[8:0]) ||
         dut.loop_idx_inc !== (index+32'd1) ||
         dut.addr_cnt_inc !== ((count+32'd1) & 32'h007fffff) ||
         dut.gn_release_match !== (hold==(unit_selected_period-dut.t_GL2GH)) ||
         dut.hold_before_one !== (hold+1==unit_selected_period) ||
         dut.hold_before_one !== (hold==unit_selected_period-1) ||
         dut.hold_before_two !== (hold+2==unit_selected_period) ||
         dut.period_match !== (hold==unit_selected_period) ||
         dut.early_match !== (hold==dut.t_AVQV-unit_selected_period) ||
         dut.late_match !== (hold==dut.t_AVQV) ||
         dut.en_release_match !== (hold==unit_selected_period-dut.t_EL2EH) ||
         dut.wn_release_match !== (hold==unit_selected_period-dut.t_WL2WH) ||
         dut.ub_release_match !== (hold==unit_selected_period-dut.t_UBL2UBH) ||
         dut.lb_release_match !== (hold==unit_selected_period-dut.t_LBL2LBH) ||
         dut.addr_count_less !== (count<length) ||
         dut.addr_count_equal !== (count==length) ||
         dut.addr_is_last !== (count==length-1) ||
         dut.addr_is_last !== (count+1==length) ||
         dut.loop_has_more !== (index<loops-1))
        $fatal(1,"Predicate mismatch period=%h hold=%h addr=%h/%h loop=%h/%h",
          period,hold,count,length,index,loops);
    end
  endtask
  initial begin
    // Exhaust every timing limit, including zero, one, and the 16-bit maximum.
    for(n=0;n<65536;n=n+1) begin
      period=n;length=n;count=n;index=n;loops=n;
      hold=n;check;
      hold=n-1;count=n-1;index=n-1;check;
      hold=n-2;count=n+1;index=n+1;check;
      hold=21'h1fffff;count=23'h7fffff;index=32'hffffffff;check;
      hold=dut.t_AVQV-period;check;
      hold=hold+1;check;
    end
    // Exercise full-width counters and both sides of the loop boundary.
    for(n=0;n<20000;n=n+1) begin
      period=$random;hold=$random;length=$random;count=$random;
      unit_gl_w=$random;unit_gl_r=$random;read_select=n%4;
      unit_avqv=$random;unit_en_w=$random;unit_en_r=$random;unit_wn=$random;
      unit_ub_w=$random;unit_ub_r=$random;unit_lb_w=$random;unit_lb_r=$random;
      loops=$random;index=$random;check;
      hold=dut.t_AVQV-unit_selected_period;check;
      hold=unit_selected_period-dut.t_EL2EH;check;
      hold=unit_selected_period-dut.t_WL2WH;check;
      hold=unit_selected_period-dut.t_UBL2UBH;check;
      hold=unit_selected_period-dut.t_LBL2LBH;check;
      index=loops-1;check;
      index=loops;check;
      index=loops+1;check;
    end
    for(n=0;n<=12;n=n+1) begin
      period=n;
      for(k=0;k<4;k=k+1) begin
        read_select=k;#1;
        hold=period-dut.t_GL2GH;check;
        hold=hold+1;check;
      end
    end
    split_banks=1;
    for(n=0;n<512;n=n+1) begin
      period_w_alt=(n<256)?n:(65535-(n-256));
      period_r_alt=(n<256)?(65535-n):(n-256);
      for(k=0;k<4;k=k+1) begin
        read_select=k;#1;
        hold=dut.t_AVQV-unit_selected_period;check;
        hold=hold+1;check;
        hold=unit_selected_period-dut.t_WL2WH;check;
        hold=unit_selected_period-1;check;
        hold=unit_selected_period-2;check;
        hold=(phase_d2?unit_period_w:unit_period_r)-1;check;
        hold=21'h0ffff;check;
        hold=21'h0fffe;check;
        hold=21'h1fffff;check;
      end
    end
    // All 512 x 512 input pairs cover the complete 9-bit domain and repeat
    // every 7-bit pair, while the controller predicates remain checked too.
    for(n=0;n<512;n=n+1) begin
      for(k=0;k<512;k=k+1) begin count=n;length=k;check;end
    end
    for(n=0;n<32;n=n+1) begin
      for(k=0;k<32;k=k+1) begin unit_tx_length=n;unit_tx_pointer=k;check;end
    end
    $display("PASS: %0d predicate comparisons against original arithmetic, including unequal banks and GN underflow",cases);
    $finish;
  end
endmodule
