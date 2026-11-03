`timescale 1ns/1ps
module tb_spi_reports;
  reg clk=0, rst_n=0, sclk=0, cs_n=1, mosi=0;
  wire miso, ack;
  reg complete=0;
  reg [31:0] loop_no=0;
  integer ack_count=0, frames=0;
  reg [7:0] cfg [0:23];
  reg [7:0] got;
  integer i,half_period,config_checks=0;
  reg [31:0] config_loops=1;
  reg [22:0] config_length=256;
  reg [7:0] config_period=7;
  reg [1:0] config_write_mode=1,config_read_mode=1;
  reg bad_checksum=0;
  reg [7:0] config_chip=8'h83;
  reg [3:0] expected_test_mode=0;
  always #2.5 clk=~clk;
  always @(posedge clk) if (ack) ack_count=ack_count+1;
  spi_protocol dut(.clk(clk),.rst_n(rst_n),.spi_sclk(sclk),
    .spi_cs_n(cs_n),.spi_mosi(mosi),.spi_miso(miso),
    .current_loop(loop_no),.test_busy(1'b0),.test_done(1'b0),
    .error_cnt(32'h12345678),.err_flag(1'b1),.error_addr(22'd0),
    .error_data(16'd0),.expected_data(16'd0),.test_complete(complete),
    .tx_done_pulse(ack));
  // Base and decoded parameters must remain coherent on EVERY clock,
  // including the configuration commit edge, not merely after startup.
  always @(posedge clk) begin
    #1;
    if(rst_n) begin
      if(dut.start_test && (bad_checksum || dut.test_mode!==expected_test_mode ||
         dut.loop_count!==config_loops || dut.test_length!==config_length))
        $fatal(1,"Test started before the new configuration was committed");
      if(dut.last_loop_index !== (dut.loop_count-32'd1) ||
         dut.last_test_address !== (dut.test_length[20:0]-21'd1) ||
         dut.period_last_w !== (dut.t_avav_w-16'd1) ||
         dut.period_before_last_w !== (dut.t_avav_w-16'd2) ||
         dut.period_last_r !== (dut.t_avav_r-16'd1) ||
         dut.period_before_last_r !== (dut.t_avav_r-16'd2) ||
         dut.gn_release_w !== ({5'b0,dut.t_avav_w}-{5'b0,dut.t_gl2gh_w}) ||
         dut.gn_release_r !== ({5'b0,dut.t_avav_r}-{5'b0,dut.t_gl2gh_r}) ||
         dut.compare_early_w !== ({5'b0,dut.t_avqv_r}-{5'b0,dut.t_avav_w}) ||
         dut.compare_early_r !== ({5'b0,dut.t_avqv_r}-{5'b0,dut.t_avav_r}) ||
         dut.en_release_w !== ({5'b0,dut.t_avav_w}-{5'b0,dut.t_el2eh_w}) ||
         dut.en_release_r !== ({5'b0,dut.t_avav_r}-{5'b0,dut.t_el2eh_r}) ||
         dut.wn_release_w !== ({5'b0,dut.t_avav_w}-{5'b0,dut.t_wl2wh_w}) ||
         dut.wn_release_r !== ({5'b0,dut.t_avav_r}-{5'b0,dut.t_wl2wh_w}) ||
         dut.ub_release_w !== ({5'b0,dut.t_avav_w}-{5'b0,dut.t_ubl2ubh_w}) ||
         dut.ub_release_r !== ({5'b0,dut.t_avav_r}-{5'b0,dut.t_ubl2ubh_r}) ||
         dut.lb_release_w !== ({5'b0,dut.t_avav_w}-{5'b0,dut.t_lbl2lbh_w}) ||
         dut.lb_release_r !== ({5'b0,dut.t_avav_r}-{5'b0,dut.t_lbl2lbh_r}))
        $fatal(1,"Decoded configuration is not atomic with base parameters");
    end
  end
  task byte_io(input [7:0] data, output [7:0] result);
    integer b;
    begin
      result=0;
      for(b=7;b>=0;b=b-1) begin
        mosi=data[b]; #(half_period); sclk=1;
        #1; result[b]=miso; #(half_period-1); sclk=0;
      end
    end
  endtask
  task configure(input [3:0] mode);
    reg [7:0] sum, unused;
    reg [767:0] previous_config;
    integer n;
    begin
      expected_test_mode=mode;
      previous_config={dut.test_mode,dut.test_length,dut.loop_count,dut.t_avav_w,
        dut.t_avav_r,dut.last_loop_index,dut.last_test_address,dut.period_last_w,
        dut.period_before_last_w,dut.period_last_r,dut.period_before_last_r,
        dut.gn_release_w,dut.gn_release_r,
        dut.compare_early_w,dut.compare_early_r,dut.en_release_w,dut.en_release_r,
        dut.wn_release_w,dut.wn_release_r,dut.ub_release_w,dut.ub_release_r,
        dut.lb_release_w,dut.lb_release_r,
        dut.write_mode,dut.read_mode};
      for(n=0;n<24;n=n+1) cfg[n]=0;
      cfg[0]=8'h55;cfg[1]=config_chip;cfg[2]=mode;cfg[3]=1;
      cfg[8]=config_length[7:0];cfg[9]=config_length[15:8];
      cfg[10]={1'b0,config_length[22:16]};
      cfg[12]=config_loops[7:0];cfg[13]=config_loops[15:8];
      cfg[14]=config_loops[23:16];cfg[15]=config_loops[31:24];
      cfg[16]=config_period;cfg[17]={6'b0,config_write_mode};cfg[18]={6'b0,config_read_mode};
      sum=0;for(n=1;n<=21;n=n+1) sum=sum+cfg[n];
      cfg[22]=bad_checksum ? (sum^8'h01) : sum;cfg[23]=8'haa;
      cs_n=0;#100;
      for(n=0;n<24;n=n+1) byte_io(cfg[n],unused);
      #100;cs_n=1;#200;
      config_checks=config_checks+1;
      if(bad_checksum) begin
        if({dut.test_mode,dut.test_length,dut.loop_count,dut.t_avav_w,
            dut.t_avav_r,dut.last_loop_index,dut.last_test_address,dut.period_last_w,
            dut.period_before_last_w,dut.period_last_r,dut.period_before_last_r,
            dut.gn_release_w,dut.gn_release_r,
            dut.compare_early_w,dut.compare_early_r,dut.en_release_w,dut.en_release_r,
            dut.wn_release_w,dut.wn_release_r,dut.ub_release_w,dut.ub_release_r,
            dut.lb_release_w,dut.lb_release_r,
            dut.write_mode,dut.read_mode}
           !==previous_config)
          $fatal(1,"Bad checksum changed the committed configuration");
      end else if(dut.test_mode!==mode || dut.test_length!==config_length ||
                  dut.loop_count!==config_loops || dut.write_mode!==config_write_mode ||
                  dut.read_mode!==config_read_mode || dut.t_avav_r!=={8'b0,config_period} ||
                  dut.t_avav_w!==((config_write_mode==3)?16'd10:{8'b0,config_period}))
        $fatal(1,"Configuration RX failed mode=%d length=%d",dut.test_mode,dut.test_length);
    end
  endtask
  task notify;
    begin @(negedge clk);complete=1;#20;complete=0;#100;end
  endtask
  task poll(input integer length, input integer abort_after);
    integer n, before_ack;
    reg [7:0] expected;
    begin
      before_ack=ack_count;
      cs_n=0;#100;
      for(n=0;n<64;n=n+1) begin
        if(abort_after && n==abort_after) begin
          cs_n=1;#100;
          if(ack_count!=before_ack) $fatal(1,"Aborted frame acknowledged");
          disable poll;
        end
        byte_io(0,got);
        expected=0;
        if(length==11) begin
          case(n)
            0: expected=8'h55;1: expected=8'hff;
            2,3,4,5: expected=loop_no >> ((n-2)*8);
            7:expected=1;10:expected=8'haa;
          endcase
        end else if(length==17) begin
          case(n)
            0:expected=8'h55;1:expected=8'h11;2:expected=8'hff;
            3,4,5,6:expected=loop_no >> ((n-3)*8);
            8:expected=1;11:expected=1;
            12:expected=8'h78;13:expected=8'h56;
            14:expected=8'h34;15:expected=8'h12;16:expected=8'haa;
          endcase
        end
        if(got!==expected) $fatal(1,"loop=%d byte=%d got=%h expected=%h",loop_no,n,got,expected);
      end
      #100;cs_n=1;#100;
      if(ack_count!=before_ack+(length!=0)) $fatal(1,"Ack count mismatch");
      frames=frames+1;
    end
  endtask
  initial begin
    half_period=111;#30;rst_n=1;#100;
    configure(0);
    for(i=499;i<=1000;i=i+1) begin
      half_period=100+(i%12); // 5 MHz through approximately 4.5 MHz, drifting phase
      loop_no=i;notify;
      if(i==672) poll(11,4);
      poll(11,0);
      if(i%37==0) poll(0,0);
      // Sweep SCLK phase against the 200 MHz processing clock.
      #1;
    end
    configure(2);loop_no=32'h12345678;notify;poll(17,0);poll(0,0);
    for(i=0;i<8;i=i+1) begin
      config_write_mode=i%4;config_read_mode=(i/2)%4;
      case(i)
        0:begin config_period=0;config_loops=0;config_length=0;end
        1:begin config_period=1;config_loops=1;config_length=1;end
        2:begin config_period=2;config_loops=2;config_length=2;end
        3:begin config_period=255;config_loops=32'hffffffff;config_length=23'h7fffff;end
        4:begin config_period=7;config_loops=32'h00010000;config_length=23'h200000;end
        5:begin config_period=35;config_loops=32'h01000000;config_length=23'h1fffff;end
        6:begin config_period=128;config_loops=32'h80000000;config_length=23'h200001;end
        7:begin config_period=42;config_loops=32'h12345678;config_length=256;end
      endcase
      configure(i%3);
    end
    config_chip=8'h80;config_period=255;config_write_mode=3;config_read_mode=0;
    configure(2);
    config_chip=8'h82;config_period=1;config_write_mode=2;config_read_mode=1;
    configure(2);
    bad_checksum=1;config_period=99;config_loops=9;config_length=123;
    configure(2);
    $display("PASS: %0d SPI polls; %0d configuration checks with atomic decoded thresholds and bad-checksum retention",frames,config_checks);
    $finish;
  end
  initial begin #200000000; $fatal(1,"Watchdog expired"); end
endmodule
