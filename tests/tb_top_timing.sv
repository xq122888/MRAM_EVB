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
  reg [31:0] index=0,loops=0;
  integer n,k,cases=0;
  top dut(.clkp(1'b0),.clkn(1'b1),.rst_n(1'b0),.spi_cs_n(1'b1),
          .spi_sclk(1'b0),.spi_mosi(1'b0));
  initial begin
    force dut.addr_hold_cnt=hold;force dut.vio_t_AVAV=period;
    force dut.addr_cnt=count;force dut.vio_addr_num=length;
    force dut.loop_idx=index;force dut.loop_count=loops;
  end
  task check;
    begin
      #1;cases=cases+1;
      if(dut.hold_before_one !== (hold+1==period) ||
         dut.hold_before_one !== (hold==period-1) ||
         dut.hold_before_two !== (hold+2==period) ||
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
      loops=$random;index=$random;check;
      index=loops-1;check;
      index=loops;check;
      index=loops+1;check;
    end
    $display("PASS: %0d predicate comparisons against original widened arithmetic",cases);
    $finish;
  end
endmodule
