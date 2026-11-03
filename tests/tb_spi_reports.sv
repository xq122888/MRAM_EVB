`timescale 1ns/1ps
module tb_spi_reports;
  reg clk=0, rst_n=0, sclk=0, cs_n=1, mosi=0;
  wire miso, ack;
  reg complete=0;
  reg [31:0] loop_no=0;
  integer ack_count=0, frames=0;
  reg [7:0] cfg [0:23];
  reg [7:0] got;
  integer i,half_period;
  always #2.5 clk=~clk;
  always @(posedge clk) if (ack) ack_count=ack_count+1;
  spi_protocol dut(.clk(clk),.rst_n(rst_n),.spi_sclk(sclk),
    .spi_cs_n(cs_n),.spi_mosi(mosi),.spi_miso(miso),
    .current_loop(loop_no),.test_busy(1'b0),.test_done(1'b0),
    .error_cnt(32'h12345678),.err_flag(1'b1),.error_addr(22'd0),
    .error_data(16'd0),.expected_data(16'd0),.test_complete(complete),
    .tx_done_pulse(ack));
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
    integer n;
    begin
      for(n=0;n<24;n=n+1) cfg[n]=0;
      cfg[0]=8'h55;cfg[1]=8'h83;cfg[2]=mode;cfg[3]=1;
      cfg[9]=1;cfg[12]=1;cfg[16]=7;cfg[17]=1;cfg[18]=1;
      sum=0;for(n=1;n<=21;n=n+1) sum=sum+cfg[n];
      cfg[22]=sum;cfg[23]=8'haa;
      cs_n=0;#100;
      for(n=0;n<24;n=n+1) byte_io(cfg[n],unused);
      #100;cs_n=1;#200;
      if(dut.test_mode!==mode || dut.test_length!==256)
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
    $display("PASS: %0d SPI polls; sequential reports, byte boundaries, abort/retry, idle padding, 17-byte report",frames);
    $finish;
  end
  initial begin #200000000; $fatal(1,"Watchdog expired"); end
endmodule
