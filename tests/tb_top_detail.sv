`timescale 1ns/1ps
// Digital error injection/control integration, using the ideal clock/TRNG
// fixtures in tb_top_timing.sv. This is not a physical MRAM or timing model.
module tb_top_detail;
  reg clk=0,rst_n=0,sclk=0,cs_n=1,mosi=0,active=0;
  reg [15:0] injected_data=16'hbeef;
  reg [21:0] configured_start=22'h12000;
  wire miso;
  reg [7:0] cfg[0:23],bytes[0:63],unused,checksum;
  integer produced[0:1],received_details[0:1];
  reg [21:0] expected_address[0:1][1:31];
  reg [15:0] expected_actual[0:1][1:31],expected_word[0:1][1:31];
  integer case_no,period_cfg,enable_detail,faults,acks=0,summaries=0;
  integer pauses=0,aborted=0,polls=0,total_details=0,n,k,frame_loop,frame_index,before_ack;
  reg detected;
  reg [21:0] captured_address;
  reg [15:0] captured_expected;
  integer captured_loop,captured_index;
  reg prior_stall=0;
  reg [360:0] prior_state;
  reg [21:0] reference_address=0;
  wire [360:0] memory_state={dut.addr_compare_count,dut.dq_drive,dut.dq_write_data,dut.hold_release_count,dut.hold_sample_count,dut.dout_ref_addr,dut.addr,dut.addr_d,dut.addr_cnt,dut.addr_hold_cnt,
    dut.rd_en,dut.rd_en_d,dut.rd_en_d2,dut.R_EN,dut.R_WN,dut.R_GN,dut.R_UBN,
    dut.R_LBN,dut.R_DQ,dut.dout,dut.dout_d1,dut.dout_d2,dut.dout_ref,
    dut.keep,dut.flg,dut.random_seed,dut.random_state};
  always #2.5 clk=~clk;
  top dut(.clkp(clk),.clkn(~clk),.rst_n(rst_n),.spi_sclk(sclk),.spi_cs_n(cs_n),
    .spi_mosi(mosi),.spi_miso(miso));
  initial begin
    force dut.RD_DATA=injected_data;
    force dut.dout_ref=16'hcafe;
    force dut.dout_d1=16'h1234;
  end
  always @(posedge clk) begin
    detected=0;
    if(!rst_n) reference_address<=0;
    else if(active && !dut.detail_stall && dut.addr_hold_cnt==dut.vio_t_AVAV)
      reference_address<=dut.addr_d;
    if(active && rst_n) begin
      if(dut.send_frame_ack) acks=acks+1;
      if(dut.u_spi_protocol.detail_pending && dut.err_flg)
        $fatal(1,"Producer violated single-entry mailbox backpressure");
      if((!enable_detail || (!dut.spi_start_test && dut.start_d1==dut.start_d2 && !dut.next_loop_start_d1)) &&
         !dut.detail_stall && dut.flg && dut.rd_en_d) begin
        if(dut.addr_hold_cnt==dut.vio_t_AVQV-dut.vio_t_AVAV &&
           dut.addr_d!=dut.vio_addr_ini && dut.RD_DATA!=dut.dout_ref) begin
          detected=1;captured_expected=dut.dout_ref;captured_address=reference_address;
        end else if(dut.addr_hold_cnt==dut.vio_t_AVQV && dut.RD_DATA!=dut.dout_d1) begin
          detected=1;captured_expected=dut.dout_d1;captured_address=dut.addr_d;
        end
      end
      if(detected) begin
        captured_loop=dut.loop_idx;
        if(captured_loop>1) $fatal(1,"Unexpected loop progression");
        produced[captured_loop]=produced[captured_loop]+1;
        captured_index=produced[captured_loop];
        if(captured_index>31) $fatal(1,"Unexpected repeated compare events");
        expected_address[captured_loop][captured_index]=captured_address;
        expected_actual[captured_loop][captured_index]=injected_data;
        expected_word[captured_loop][captured_index]=captured_expected;
      end
    end
    #1;
    if(active && rst_n) begin
      if(dut.addr_compare_count!==dut.addr_cnt) $fatal(1,"Address replica diverged during detail control");
      if(dut.hold_release_count!==dut.addr_hold_cnt || dut.hold_sample_count!==dut.addr_hold_cnt)
        $fatal(1,"Timer replicas diverged during detail/start/loop control");
      if(detected && (dut.error_addr_snapshot!==captured_address ||
         dut.error_data_snapshot!==injected_data || dut.error_expected_snapshot!==captured_expected))
        $fatal(1,"Compare-edge snapshot used wrong operands");
      if(dut.loop_idx>acks) $fatal(1,"Loop advanced without summary ACK");
      if(!enable_detail && dut.detail_stall) $fatal(1,"Disabled logging stalled MRAM");
      if(prior_stall && dut.detail_stall && memory_state!==prior_state)
        $fatal(1,"MRAM state moved under detail backpressure");
      if(dut.detail_stall) pauses=pauses+1;
      prior_stall=dut.detail_stall;prior_state=memory_state;
    end else prior_stall=0;
  end
  task byte_io(input [7:0] data,output [7:0] result);
    integer b;
    begin
      for(b=7;b>=0;b=b-1) begin
        mosi=data[b];#111;sclk=1;#1;result[b]=miso;#110;sclk=0;
      end
    end
  endtask
  task configure;
    integer i;
    begin
      for(i=0;i<24;i=i+1) cfg[i]=0;
      cfg[0]=8'h55;cfg[1]=8'h83;cfg[2]=2;cfg[3]=5;
      cfg[4]=configured_start[7:0];cfg[5]=configured_start[15:8];
      cfg[6]={2'b0,configured_start[21:16]};
      cfg[8]=4;cfg[12]=2;cfg[16]=period_cfg;cfg[17]=1;cfg[18]=1;cfg[19]=enable_detail;
      checksum=0;for(i=1;i<=21;i=i+1) checksum=checksum+cfg[i];
      cfg[22]=checksum;cfg[23]=8'haa;
      cs_n=0;#100;
      for(i=0;i<24;i=i+1) byte_io(cfg[i],unused);
      #100;cs_n=1;#200;
    end
  endtask
  task poll(input integer abort_after);
    integer i;
    begin
      cs_n=0;#100;
      for(i=0;i<64;i=i+1) begin
        if(abort_after!=0 && i==abort_after) begin cs_n=1;#100;disable poll;end
        byte_io(0,bytes[i]);
      end
      #100;cs_n=1;#100;
    end
  endtask
  initial begin
    for(case_no=0;case_no<6;case_no=case_no+1) begin
      active=0;rst_n=0;cs_n=1;sclk=0;#30;
      produced[0]=0;produced[1]=0;received_details[0]=0;received_details[1]=0;
      acks=0;summaries=0;pauses=0;aborted=0;polls=0;
      enable_detail=(case_no!=2);faults=(case_no<3 || case_no==5);
      period_cfg=(case_no==0 || case_no==2 || case_no==4)?7:10;
      injected_data=faults?16'hbeef:((period_cfg==7)?16'hcafe:16'h1234);
      configured_start=22'h12000;
      @(negedge clk);rst_n=1;active=1;#100;configure;
      if(case_no==5) begin
        // Restart the SAME mode with an unsent old record and a different base.
        // The old producer can run between CRC commit and the new frame tail.
        wait(dut.u_spi_protocol.detail_pending);active=0;
        period_cfg=7;configured_start=22'h22000;
        fork
          begin configure;end
          begin
            wait(dut.spi_start_test===1'b1);@(negedge clk);
            produced[0]=0;produced[1]=0;received_details[0]=0;received_details[1]=0;
            acks=0;summaries=0;pauses=0;aborted=0;polls=0;active=1;
          end
        join
      end
      while(summaries<2) begin
        wait(dut.u_spi_protocol.detail_pending || dut.u_spi_protocol.pending_test_complete);
        #100;
        if(enable_detail && !aborted && dut.u_spi_protocol.detail_pending) begin
          before_ack=acks;poll(12);aborted=1;
          if(!dut.detail_stall || acks!=before_ack) $fatal(1,"Partial detail consumed/advanced producer");
        end
        before_ack=acks;poll(0);polls=polls+1;
        if(polls>40) $fatal(1,"Too many polls without completion");
        if(bytes[0]==0) begin
          for(n=0;n<64;n=n+1) if(bytes[n]!==0) $fatal(1,"Partial idle frame");
        end else begin
          if(bytes[0]!==8'h55 || bytes[2]!==8'hff ||
             {bytes[10],bytes[9],bytes[8],bytes[7]}!==32'd4)
            $fatal(1,"Bad report header/total");
          frame_loop={bytes[6],bytes[5],bytes[4],bytes[3]};
          if(frame_loop>1) $fatal(1,"Bad loop field");
          if(bytes[1]==8'h19) begin
            frame_index={bytes[15],bytes[14],bytes[13],bytes[12]};
            if(!enable_detail || frame_index!=received_details[frame_loop]+1 ||
               frame_index>produced[frame_loop]) $fatal(1,"Detail lost, reordered or duplicated");
            if(bytes[11]!==1 || bytes[24]!==8'haa ||
               {bytes[19],bytes[18],bytes[17],bytes[16]}!=={10'd0,expected_address[frame_loop][frame_index]} ||
               {bytes[21],bytes[20]}!==expected_actual[frame_loop][frame_index] ||
               {bytes[23],bytes[22]}!==expected_word[frame_loop][frame_index])
              $fatal(1,"Detailed snapshot does not match comparison event");
            for(n=25;n<64;n=n+1) if(bytes[n]!==0) $fatal(1,"Bad detail padding");
            if(acks!=before_ack) $fatal(1,"Detail frame ACKed the loop");
            received_details[frame_loop]=received_details[frame_loop]+1;total_details=total_details+1;
          end else if(bytes[1]==8'h11) begin
            if(frame_loop!=summaries || bytes[16]!==8'haa ||
               {bytes[15],bytes[14],bytes[13],bytes[12]}!==produced[frame_loop] ||
               bytes[11]!==((produced[frame_loop]!=0)?8'd1:8'd0))
              $fatal(1,"Wrong summary count/flag/loop");
            if(enable_detail && received_details[frame_loop]!=produced[frame_loop])
              $fatal(1,"Summary overtook pending error records");
            if(acks!=before_ack+1) $fatal(1,"Summary ACK mismatch");
            for(n=17;n<64;n=n+1) if(bytes[n]!==0) $fatal(1,"Bad summary padding");
            summaries=summaries+1;
          end else $fatal(1,"Unknown report type %h",bytes[1]);
        end
      end
      if(dut.loop_done!==1 || acks!=2) $fatal(1,"Final loop did not terminate");
      if(faults && (produced[0]==0 || produced[1]==0)) $fatal(1,"Fault injection did not execute");
      if(enable_detail && faults && pauses==0) $fatal(1,"Backpressure was not exercised");
      if(!faults && (produced[0]!=0 || produced[1]!=0 || pauses!=0)) $fatal(1,"False error or pause");
      $display("PASS case %0d: period=%0d detail=%0d errors=%0d/%0d pause cycles=%0d",case_no,period_cfg,enable_detail,produced[0],produced[1],pauses);
      active=0;
    end
    $display("PASS: %0d top-level detailed records; both compare branches, frozen memory, slow/aborted polling, exact summaries and disabled/no-error modes",total_details);
    $finish;
  end
  initial begin #10000000;$fatal(1,"Top-level detail watchdog expired");end
endmodule
