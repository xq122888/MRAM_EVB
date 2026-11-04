`timescale 1ns/1ps
module tb_detail_fifo;
  reg clk=0,rst_n=0,clear=0,push=0,pop=0;
  reg [85:0] data=0;
  wire valid,nonempty,overflow;
  wire [85:0] head;
  wire [31:0] dropped;
  reg [85:0] reference[0:20000];
  integer front=0,back=0,count=0,lost=0,accepted=0,consumed=0,cycle_no=0,n;
  reg take,put;
  always #2.5 clk=~clk;
  mram_detail_fifo #(.ADDR_BITS(2)) dut(.clk(clk),.rst_n(rst_n),.clear(clear),
    .push(push),.pop(pop),.push_data(data),.head_valid(valid),.head_data(head),
    .nonempty(nonempty),.overflow(overflow),.dropped_count(dropped));
  always @(posedge clk) begin
    if(!rst_n || clear) begin front=0;back=0;count=0;lost=0;end
    else begin
      if(valid && (count==0 || head!==reference[front]))
        $fatal(1,"FIFO head corrupted or reordered cycle=%0d",cycle_no);
      take=pop && valid;
      put=push && (count<4 || take);
      if(take) begin front=front+1;count=count-1;consumed=consumed+1;end
      if(put) begin reference[back]=data;back=back+1;count=count+1;accepted=accepted+1;end
      if(push && !put) lost=lost+1;
    end
    cycle_no=cycle_no+1;
    #0.2;
    if(nonempty!==(count!=0) || dropped!==lost || overflow!==(lost!=0) || dut.fifo_count!==count)
      $fatal(1,"FIFO occupancy/overflow accounting mismatch cycle=%0d",cycle_no);
    if(valid && head!==reference[front]) $fatal(1,"Prefetched stale/wrong record");
  end
  task send(input integer tag);
    begin
      @(negedge clk);data={32'(tag),22'(tag*3),16'(tag^16'h1234),16'(tag^16'hbeef)};push=1;
    end
  endtask
  task drain;
    begin
      @(negedge clk);push=0;pop=1;
      while(nonempty) @(negedge clk);
      pop=0;repeat(3)@(negedge clk);
    end
  endtask
  initial begin
    #20;@(negedge clk);rst_n=1;
    // Exact capacity includes the prefetched head, not depth plus one.
    for(n=1;n<=7;n=n+1)send(n);
    @(negedge clk);push=0;repeat(6)@(negedge clk);
    if(dropped!=3 || !valid) $fatal(1,"Capacity/idle-head retention failure");
    // Full simultaneous consume/produce must accept the new word, without loss.
    pop=1;push=1;data=86'h123456;
    @(negedge clk);push=0;pop=0;
    if(dropped!=3 || dut.fifo_count!=4) $fatal(1,"Full exchange lost a record");
    drain;
    // Clear cancels both queued data and an outstanding synchronous RAM fetch.
    clear=1;@(negedge clk);clear=0;send(100);
    @(negedge clk);push=0;wait(dut.fetch_pending);@(negedge clk);clear=1;
    @(negedge clk);clear=0;repeat(5)@(negedge clk);
    if(valid || nonempty || overflow || dropped) $fatal(1,"Clear retained an old fetch");
    // Many wraparounds, bursts, empty pops, full drops, and simultaneous pushes/pops.
    for(n=0;n<10000;n=n+1)begin
      @(negedge clk);push=($random&3)!=0;pop=($random&1)!=0;
      data={32'(n),22'(n*7),16'(n),16'(~n)};
    end
    drain;
    if(accepted<100 || consumed<100 || lost<100) $fatal(1,"Insufficient queue stress");
    $display("PASS: BRAM-style FIFO, exact capacity, full exchange, overflow, stable retry head, cancelled fetch, 10000 randomized cycles; accepted=%0d consumed=%0d dropped=%0d",accepted,consumed,lost);
    $finish;
  end
  initial begin #200000;$fatal(1,"FIFO watchdog");end
endmodule

module tb_detail_fifo_capacity;
  reg clk=0,rst_n=0,clear=0,push=0,pop=0;
  reg [85:0] data=0;
  wire valid,nonempty,overflow;
  wire [85:0] head;
  wire [31:0] dropped;
  integer n,received=0;
  always #2.5 clk=~clk;
  mram_detail_fifo dut(.clk(clk),.rst_n(rst_n),.clear(clear),.push(push),.pop(pop),
    .push_data(data),.head_valid(valid),.head_data(head),.nonempty(nonempty),
    .overflow(overflow),.dropped_count(dropped));
  function [85:0] record(input integer index);
    record={32'(index),22'(index*7),16'(index^16'ha55a),16'(index^16'h5aa5)};
  endfunction
  always @(posedge clk) begin
    if(rst_n && pop && valid)begin
      if(head!==record(received+1)) $fatal(1,"Default-depth data/order mismatch at %0d",received);
      received=received+1;
    end
  end
  initial begin
    #20;@(negedge clk);rst_n=1;
    for(n=1;n<=4098;n=n+1)begin @(negedge clk);data=record(n);push=1;end
    @(negedge clk);push=0;
    if(dut.fifo_count!=4096 || dropped!=2 || !overflow) $fatal(1,"Default capacity is not 4096");
    pop=1;
    wait(received==4096);@(negedge clk);pop=0;
    if(nonempty || valid || dropped!=2) $fatal(1,"Default-depth queue did not drain exactly");
    clear=1;@(negedge clk);clear=0;
    if(overflow || dropped) $fatal(1,"Default-depth diagnostics did not reset");
    $display("PASS: default FIFO retains exactly 4096 records, counts 2 overflow drops, drains all 4096 in order");
    $finish;
  end
  initial begin #200000;$fatal(1,"Default FIFO watchdog");end
endmodule
