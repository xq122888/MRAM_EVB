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
module tb_top_timing;
  reg clk=0,rst_n=0,start=0,ack=0;
  reg [3:0] mode=0;
  reg [20:0] length=4;
  reg [15:0] period=7;
  reg [31:0] loops=4;
  wire [15:0] dq_new,dq_ref;
  wire en_new,en_ref,wn_new,wn_ref,gn_new,gn_ref;
  wire ub_new,ub_ref,lb_new,lb_ref,err_new,err_ref;
  wire [21:0] addr_new,addr_ref;
  wire [31:0] decoded_last_loop=loops-32'd1;
  wire [20:0] decoded_last_address=length-21'd1;
  wire [15:0] decoded_period_last=period-16'd1;
  wire [15:0] decoded_period_before_last=period-16'd2;
  wire [20:0] decoded_gn_write={5'b0,period}-{5'b0,dut.spi_t_gl2gh_w};
  wire [20:0] decoded_gn_read={5'b0,period}-{5'b0,dut.spi_t_gl2gh_r};
  reg checking=0;
  integer cycles=0,advances=0,finished=0,n,m,t,trial;
  reg [31:0] seed;
  always #2.5 clk=~clk;
  assign dq_new=(!en_new && wn_new && !gn_new)?16'h1234:16'hzzzz;
  assign dq_ref=(!en_ref && wn_ref && !gn_ref)?16'h1234:16'hzzzz;
  top dut(.clkp(clk),.clkn(~clk),.rst_n(rst_n),.spi_cs_n(1'b1),
    .spi_sclk(1'b0),.spi_mosi(1'b0),.DQ(dq_new),.A(addr_new),
    .EN(en_new),.WN(wn_new),.GN(gn_new),.UBN(ub_new),.LBN(lb_new),.err_flg(err_new));
  top_reference refdut(.clkp(clk),.clkn(~clk),.rst_n(rst_n),.spi_cs_n(1'b1),
    .spi_sclk(1'b0),.spi_mosi(1'b0),.DQ(dq_ref),.A(addr_ref),
    .EN(en_ref),.WN(wn_ref),.GN(gn_ref),.UBN(ub_ref),.LBN(lb_ref),.err_flg(err_ref));
  initial begin
    force dut.spi_start_test=start; force refdut.spi_start_test=start;
    force dut.send_frame_ack=ack; force refdut.send_frame_ack=ack;
    force dut.vio_TMODE=mode; force refdut.vio_TMODE=mode;
    force dut.vio_addr_num=length; force refdut.vio_addr_num=length;
    force dut.vio_t_AVAV=period; force refdut.vio_t_AVAV=period;
    force dut.loop_count=loops; force refdut.loop_count=loops;
    force dut.spi_last_loop_index=decoded_last_loop;
    force dut.spi_last_test_address=decoded_last_address;
    force dut.spi_t_avav_w=period;force dut.spi_t_avav_r=period;
    force dut.spi_period_last_w=decoded_period_last;
    force dut.spi_period_last_r=decoded_period_last;
    force dut.spi_period_before_last_w=decoded_period_before_last;
    force dut.spi_period_before_last_r=decoded_period_before_last;
    force dut.spi_gn_release_w=decoded_gn_write;
    force dut.spi_gn_release_r=decoded_gn_read;
    force dut.vio_din_sel=3; force refdut.vio_din_sel=3;
  end
  always @(posedge clk) begin
    #1;
    if(checking) begin
      cycles=cycles+1;
      if ({dut.loop_idx,dut.loop_done,dut.loop_finish,dut.frame_ack_latched,
           dut.next_loop_start_d1,dut.next_loop_start_d2,dut.next_loop_start_d3,
           dut.addr_cnt,dut.addr_hold_cnt,dut.err_cnt,dut.dout,dut.rd_en,
           dut.keep,dut.flg,addr_new,en_new,wn_new,gn_new,ub_new,lb_new,err_new}
       !=={refdut.loop_idx,refdut.loop_done,refdut.loop_finish,refdut.frame_ack_latched,
           refdut.next_loop_start_d1,refdut.next_loop_start_d2,refdut.next_loop_start_d3,
           refdut.addr_cnt,refdut.addr_hold_cnt,refdut.err_cnt,refdut.dout,refdut.rd_en,
           refdut.keep,refdut.flg,addr_ref,en_ref,wn_ref,gn_ref,ub_ref,lb_ref,err_ref})
        $fatal(1,"Cycle mismatch mode=%d period=%d length=%d cycle=%d idx=%h/%h pulse=%b/%b",
          mode,period,length,cycles,dut.loop_idx,refdut.loop_idx,
          dut.next_loop_start_d1,refdut.next_loop_start_d1);
      if(dut.next_loop_start_d1) advances=advances+1;
      if(dut.loop_done) finished=finished+1;
    end
  end
  task boot;
    begin
      checking=0;rst_n=0;start=0;ack=0;#30;
      @(negedge clk);rst_n=1;
      repeat(8) @(negedge clk);
      checking=1;start=1;
      repeat(3) @(negedge clk);
      start=0;
    end
  endtask
  task run_cycles(input integer count);
    integer c;
    begin
      for(c=0;c<count;c=c+1) begin
        @(negedge clk);
        // Completion can arrive late or be latched ahead of loop_finish.
        ack=(c%37==30);
      end
      ack=0;
    end
  endtask
  initial begin
    #1;
    for(m=0;m<3;m=m+1) begin
      mode=m;
      for(t=0;t<5;t=t+1) begin
        case(t) 0:period=7;1:period=8;2:period=35;3:period=255;4:period=65535;endcase
        length=(t==4)?1:4;
        loops=(t==0)?1:((t==1)?2:5);
        boot;run_cycles((t==4)?140000:12000);
        // Restart without external reset, including a nonzero prior loop.
        @(negedge clk);start=1;repeat(3) @(negedge clk);start=0;
        run_cycles(3000);
      end
    end
    mode=0;period=7;length=2;
    for(trial=0;trial<8;trial=trial+1) begin
      loops=32'hffffffff;boot;checking=0;
      @(negedge clk);
      case(trial)
        0:seed=32'h000001fe;1:seed=32'h0000fffe;
        2:seed=32'h00fffffe;3:seed=32'h7ffffffe;
        4:seed=32'hfffffffc;5:seed=32'hffffffff;
        6:seed=0;7:seed=32'hfffffffe;
      endcase
      dut.loop_idx=seed;refdut.loop_idx=seed;
      refdut.loop_idx_d1=seed;
      if(trial==5 || trial==6) loops=0;
      checking=1;run_cycles(1000);
    end
    if(advances<20 || finished<20) $fatal(1,"Insufficient functional coverage");
    $display("PASS: %0d cycle comparisons; %0d loop/restart pulses; %0d done cycles; modes 0/1/2 and 32-bit carry boundaries",cycles,advances,finished);
    $finish;
  end
  initial begin #10000000;$fatal(1,"Watchdog expired");end
endmodule

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
  reg [1:0] read_select=0;
  reg [15:0] unit_gl_w=2,unit_gl_r=10;
  wire phase_d=read_select[0],phase_d2=read_select[1];
  wire [15:0] unit_selected_period=phase_d2?unit_period_r:unit_period_w;
  integer n,k,cases=0;
  top dut(.clkp(1'b0),.clkn(1'b1),.rst_n(1'b0),.spi_cs_n(1'b1),
          .spi_sclk(1'b0),.spi_mosi(1'b0));
  initial begin
    force dut.addr_hold_cnt=hold;force dut.vio_t_AVAV=unit_selected_period;
    force dut.addr_cnt=count;force dut.vio_addr_num=length;
    force dut.loop_idx=index;force dut.loop_count=loops;
    force dut.rd_en_d=phase_d;force dut.rd_en_d2=phase_d2;
    force dut.spi_t_gl2gh_w=unit_gl_w;force dut.spi_t_gl2gh_r=unit_gl_r;
    force dut.spi_last_loop_index=decoded_last_loop;
    force dut.spi_last_test_address=decoded_last_address;
    force dut.spi_t_avav_w=unit_period_w;force dut.spi_t_avav_r=unit_period_r;
    force dut.spi_period_last_w=decoded_period_last_w;
    force dut.spi_period_last_r=decoded_period_last_r;
    force dut.spi_period_before_last_w=decoded_period_before_last_w;
    force dut.spi_period_before_last_r=decoded_period_before_last_r;
    force dut.spi_gn_release_w=decoded_gn_write;
    force dut.spi_gn_release_r=decoded_gn_read;
  end
  task check;
    begin
      #1;cases=cases+1;
      if(dut.loop_idx_inc !== (index+32'd1) ||
         dut.addr_cnt_inc !== ((count+32'd1) & 32'h007fffff) ||
         dut.gn_release_match !== (hold==(unit_selected_period-dut.vio_t_GL2GH)) ||
         dut.hold_before_one !== (hold+1==unit_selected_period) ||
         dut.hold_before_one !== (hold==unit_selected_period-1) ||
         dut.hold_before_two !== (hold+2==unit_selected_period) ||
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
    end
    // Exercise full-width counters and both sides of the loop boundary.
    for(n=0;n<20000;n=n+1) begin
      period=$random;hold=$random;length=$random;count=$random;
      unit_gl_w=$random;unit_gl_r=$random;read_select=n%4;
      loops=$random;index=$random;check;
      index=loops-1;check;
      index=loops;check;
      index=loops+1;check;
    end
    for(n=0;n<=12;n=n+1) begin
      period=n;
      for(k=0;k<4;k=k+1) begin
        read_select=k;#1;
        hold=period-dut.vio_t_GL2GH;check;
        hold=hold+1;check;
      end
    end
    split_banks=1;
    for(n=0;n<512;n=n+1) begin
      period_w_alt=(n<256)?n:(65535-(n-256));
      period_r_alt=(n<256)?(65535-n):(n-256);
      for(k=0;k<4;k=k+1) begin
        read_select=k;#1;
        hold=unit_selected_period-1;check;
        hold=unit_selected_period-2;check;
        hold=(phase_d2?unit_period_w:unit_period_r)-1;check;
        hold=21'h0ffff;check;
        hold=21'h0fffe;check;
        hold=21'h1fffff;check;
      end
    end
    $display("PASS: %0d predicate comparisons against original arithmetic, including unequal banks and GN underflow",cases);
    $finish;
  end
endmodule
