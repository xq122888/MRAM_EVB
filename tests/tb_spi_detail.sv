`timescale 1ns/1ps
module tb_spi_detail;
  reg clk=0,rst_n=0,sclk=0,cs_n=1,mosi=0;
  reg error_valid=0,complete=0,busy=1;
  reg [31:0] loop_no=17,error_count=0;
  reg [3:0] selected_mode=2;
  reg [21:0] address=22'h312345;
  reg [15:0] actual=16'hbeef,expected=16'hcafe;
  wire miso,ack,stall;
  reg [7:0] cfg[0:23],bytes[0:63],discarded;
  integer n,bit_no,acks=0,details=0;
  reg [7:0] checksum;
  always #2.5 clk=~clk;
  always @(posedge clk) if(ack) acks=acks+1;
  spi_protocol #(.DETAIL_FIFO_ADDR_BITS(3)) dut(.clk(clk),.rst_n(rst_n),.spi_sclk(sclk),.spi_cs_n(cs_n),
    .spi_mosi(mosi),.spi_miso(miso),.tx_done_pulse(ack),.detail_stall(stall),
    .current_loop(loop_no),.test_busy(busy),.test_done(1'b0),.error_cnt(error_count),
    .err_flag(error_valid),.error_addr(address),.error_data(actual),
    .expected_data(expected),.test_complete(complete));
  task byte_io(input [7:0] data,output [7:0] result);
    integer b;
    begin
      for(b=7;b>=0;b=b-1) begin
        mosi=data[b];#111;sclk=1;#1;result[b]=miso;#110;sclk=0;
      end
    end
  endtask
  task configure(input enabled);
    integer i;
    begin
      for(i=0;i<24;i=i+1) cfg[i]=0;
      cfg[0]=8'h55;cfg[1]=8'h83;cfg[2]=selected_mode;cfg[3]=5;
      cfg[9]=1;cfg[12]=2;cfg[16]=7;cfg[17]=1;cfg[18]=1;cfg[19]=enabled;
      checksum=0;for(i=1;i<=21;i=i+1) checksum=checksum+cfg[i];
      cfg[22]=checksum;cfg[23]=8'haa;
      cs_n=0;#100;
      for(i=0;i<24;i=i+1) byte_io(cfg[i],discarded);
      #100;cs_n=1;#200;error_count=0;
      if(dut.err_detail_print!==enabled) $fatal(1,"Flag byte 19 did not configure detail mode");
    end
  endtask
  task emit_error(input [21:0] a,input [15:0] got,input [15:0] want);
    begin
      if(stall) $fatal(1,"Producer attempted an event while backpressured");
      @(negedge clk);address=a;actual=got;expected=want;error_valid=1;
      @(negedge clk);error_valid=0;error_count=error_count+1;
      #20;
    end
  endtask
  task notify;
    begin @(negedge clk);complete=1;@(negedge clk);complete=0;#100;end
  endtask
  task poll(input integer abort_bytes);
    integer i;
    begin
      cs_n=0;#100;
      for(i=0;i<64;i=i+1) begin
        if(abort_bytes!=0 && i==abort_bytes) begin
          cs_n=1;#100;disable poll;
        end
        byte_io(0,bytes[i]);
      end
      #100;cs_n=1;#100;
    end
  endtask
  task check_detail(input [31:0] idx,input [21:0] a,input [15:0] got,input [15:0] want);
    integer i;
    begin
      if(bytes[0]!==8'h55 || bytes[1]!==8'h19 || bytes[2]!==8'hff ||
         {bytes[6],bytes[5],bytes[4],bytes[3]}!==loop_no ||
         {bytes[10],bytes[9],bytes[8],bytes[7]}!==32'd256 || bytes[11]!==1 ||
         {bytes[15],bytes[14],bytes[13],bytes[12]}!==idx ||
         {bytes[19],bytes[18],bytes[17],bytes[16]}!=={10'd0,a} ||
         {bytes[21],bytes[20]}!==got || {bytes[23],bytes[22]}!==want || bytes[24]!==8'haa)
        $fatal(1,"25-byte detail mismatch index=%d",idx);
      for(i=25;i<64;i=i+1) if(bytes[i]!==0) $fatal(1,"Nonzero padding after detail");
      details=details+1;
    end
  endtask
  task check_summary(input [31:0] count);
    integer i;
    begin
      if(bytes[0]!==8'h55 || bytes[1]!==8'h11 || bytes[2]!==8'hff ||
         {bytes[6],bytes[5],bytes[4],bytes[3]}!==loop_no ||
         bytes[11]!==((count!=0)?8'd1:8'd0) ||
         {bytes[15],bytes[14],bytes[13],bytes[12]}!==count || bytes[16]!==8'haa)
        $fatal(1,"Summary flag/count mismatch (flag=%h count=%h)",bytes[11],{bytes[15],bytes[14],bytes[13],bytes[12]});
      for(i=17;i<64;i=i+1) if(bytes[i]!==0) $fatal(1,"Nonzero summary padding");
    end
  endtask
  task check_basic;
    integer i;
    begin
      if(bytes[0]!==8'h55 || bytes[1]!==8'hff ||
         {bytes[5],bytes[4],bytes[3],bytes[2]}!==loop_no ||
         {bytes[9],bytes[8],bytes[7],bytes[6]}!==32'd256 || bytes[10]!==8'haa)
        $fatal(1,"Write/read basic report changed");
      for(i=11;i<64;i=i+1) if(bytes[i]!==0) $fatal(1,"Basic padding changed");
    end
  endtask
  initial begin
    #30;rst_n=1;#100;configure(1);
    emit_error(22'h312345,16'hbeef,16'hcafe);
    if(stall) $fatal(1,"Queued detail stalled producer");
    // Input buses move after capture; the pending packet must retain its record.
    address=0;actual=0;expected=0;
    emit_error(22'h020001,16'h1234,16'h5678);
    notify;
    fork
      begin poll(12);end
      begin #500;emit_error(22'h020002,16'habcd,16'h4321);end
    join
    if(stall || acks!=0 || !dut.detail_pending) $fatal(1,"Aborted detail was consumed");
    poll(0);check_detail(1,22'h312345,16'hbeef,16'hcafe);
    if(acks!=0 || stall) $fatal(1,"Detail incorrectly ACKed a loop or retained backpressure");
    // Even with a pending completion, busy keeps the summary from overtaking
    // late errors; an otherwise empty poll must not ACK the loop.
    poll(0);check_detail(2,22'h020001,16'h1234,16'h5678);
    poll(0);check_detail(3,22'h020002,16'habcd,16'h4321);
    if(acks!=0) $fatal(1,"Second error ACKed loop");
    poll(0);for(n=0;n<64;n=n+1) if(bytes[n]!==0) $fatal(1,"Busy summary transmitted early");
    busy=0;#100;
    poll(8);if(acks!=0 || !dut.pending_test_complete) $fatal(1,"Aborted summary was ACKed");
    poll(0);check_summary(3);if(acks!=1) $fatal(1,"Summary did not ACK exactly once");
    poll(0);for(n=0;n<64;n=n+1) if(bytes[n]!==0) $fatal(1,"Completed frame replayed");
    if(acks!=1) $fatal(1,"Idle polling generated ACK");
    // New valid configuration discards an unsent record from the old test.
    busy=1;emit_error(22'h001234,16'h1111,16'h2222);
    configure(1);if(stall || dut.detail_pending) $fatal(1,"Restart retained old error");
    poll(0);for(n=0;n<64;n=n+1) if(bytes[n]!==0) $fatal(1,"Restart leaked old record");
    busy=0;notify;poll(0);check_summary(0);if(acks!=2) $fatal(1,"No-error detail mode failed");
    // Disabled mode keeps ordinary summary reporting, including sticky flag.
    configure(0);busy=1;emit_error(22'h020001,16'h3333,16'h4444);
    if(stall || dut.detail_pending) $fatal(1,"Disabled mode queued error");
    notify;poll(0);for(n=0;n<64;n=n+1) if(bytes[n]!==0) $fatal(1,"Disabled mode sent a premature summary");
    if(acks!=2) $fatal(1,"Premature disabled summary ACK");
    busy=0;#100;poll(0);check_summary(1);if(acks!=3) $fatal(1,"Disabled summary failed");
    selected_mode=0;configure(1);emit_error(22'h000123,16'h5555,16'haaaa);
    if(stall || dut.detail_pending) $fatal(1,"Write mode incorrectly enabled detail logging");
    notify;poll(0);check_basic;if(acks!=4) $fatal(1,"Write mode ACK mismatch");
    selected_mode=1;configure(1);emit_error(22'h000124,16'h5555,16'haaaa);
    if(stall || dut.detail_pending) $fatal(1,"Read mode incorrectly enabled detail logging");
    notify;poll(0);check_basic;if(acks!=5) $fatal(1,"Read mode ACK mismatch");
    // Saturation must not pause the producer or truncate the total count.
    selected_mode=2;configure(1);busy=1;
    for(n=0;n<12;n=n+1)emit_error(22'h200000+n,16'(n),16'(~n));
    if(stall || !dut.detail_overflow || dut.detail_dropped_count!=4)
      $fatal(1,"FIFO overflow did not count the four dropped records");
    for(n=0;n<8;n=n+1)begin
      poll(0);check_detail(n+1,22'h200000+n,16'(n),16'(~n));
    end
    // Once space is available, preserve the original index including dropped IDs.
    emit_error(22'h20000c,16'h7777,16'h8888);
    poll(0);check_detail(13,22'h20000c,16'h7777,16'h8888);
    busy=0;notify;poll(0);check_summary(13);
    if(acks!=6 || dut.detail_overflow || dut.detail_dropped_count)
      $fatal(1,"Summary ACK did not reset per-loop queue diagnostics");
    // A synchronous-RAM fetch leaves a short interval with queued data but no
    // ready head. Completion must not overtake that data at this CS boundary.
    configure(1);busy=1;notify;busy=0;
    @(negedge clk);cs_n=0;
    wait(dut.cs_n_sync==2'b10);
    @(negedge clk);address=22'h2abcde;actual=16'h1357;expected=16'h2468;error_valid=1;
    @(negedge clk);error_valid=0;error_count=1;
    #100;for(n=0;n<64;n=n+1)byte_io(0,bytes[n]);
    #100;cs_n=1;#100;
    for(n=0;n<64;n=n+1)if(bytes[n]!==0)$fatal(1,"Summary overtook an in-flight RAM fetch");
    if(acks!=6) $fatal(1,"Prefetch gap ACKed the loop");
    poll(0);check_detail(1,22'h2abcde,16'h1357,16'h2468);
    poll(0);check_summary(1);if(acks!=7)$fatal(1,"Prefetch-gap completion failed");
    $display("PASS: %0d detailed frames; snapshots, 22-bit addresses, concurrent producer, retry, ordering, overflow accounting, index gaps, restart and summary-only ACK",details);
    $finish;
  end
  initial begin #5000000;$fatal(1,"Detailed protocol watchdog expired");end
endmodule
