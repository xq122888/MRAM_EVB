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
  reg [21:0] expected_address[0:1][1:127];
  reg [15:0] expected_actual[0:1][1:127],expected_word[0:1][1:127];
  integer case_no,period_cfg,read_cfg,length_cfg,enable_detail,faults,acks=0,summaries=0;
  integer reported_drops[0:1];
  reg reported_overflow[0:1];
  integer engine_tick=0,read_period,write_cycles,read_tick,offset,slot,total_cycles,tail_cycles;
  reg prior_flg=0,is_read,want_en,want_wn,want_gn,want_bn;
  integer pauses=0,aborted=0,polls=0,total_details=0,n,k,frame_loop,frame_index,before_ack;
  reg detected;
  reg [21:0] captured_address;
  reg [15:0] captured_expected;
  integer captured_loop,captured_index;
  integer read_seen[0:1];
  always #2.5 clk=~clk;
  top dut(.clkp(clk),.clkn(~clk),.rst_n(rst_n),.spi_sclk(sclk),.spi_cs_n(cs_n),
    .spi_mosi(mosi),.spi_miso(miso));
  defparam dut.u_spi_protocol.DETAIL_FIFO_ADDR_BITS=3;
  initial begin
    force dut.RD_DATA=injected_data;
  end
  // Independent returned-data fixture for the new 0000/ffff address pattern.
  always @(dut.A) begin
    if(!faults) injected_data <= #35 ((dut.A-configured_start)%2 ? 16'hffff : 16'h0000);
  end
  reg [42:0] expected_pad;
  always @(posedge clk) begin
    expected_pad={dut.pad_cmd_en,dut.pad_cmd_wn,dut.pad_cmd_gn,dut.pad_cmd_ubn,dut.pad_cmd_lbn,dut.pad_cmd_addr,dut.pad_cmd_dq_write};
    if(active && rst_n && dut.flg && !dut.detail_stall && !dut.read_pipeline_flush) begin
      if(dut.period_event!==dut.period_match) $fatal(1,"Predicted period pulse diverged");
      if(dut.hold_before_two && !dut.count_restart &&
         (dut.count_wrap_cached!==dut.count_wrap_raw || dut.count_less_cached!==dut.addr_count_less))
        $fatal(1,"Cached count boundary was not ready at P-2");
    end
    detected=0;
    if(active && rst_n) begin
      if(dut.send_frame_ack) begin
        reported_drops[dut.loop_idx]=dut.detail_dropped_count;
        reported_overflow[dut.loop_idx]=dut.detail_fifo_overflow;
        acks=acks+1;
      end
      if(dut.detail_stall) $fatal(1,"Error logging paused the MRAM engine");
      if(!dut.detail_stall && !dut.read_pipeline_flush && dut.read_compare_valid) begin
        captured_address=configured_start+read_seen[dut.loop_idx];
        captured_expected=(read_seen[dut.loop_idx]%2)?16'hffff:16'h0000;
        read_seen[dut.loop_idx]=read_seen[dut.loop_idx]+1;
        if(read_seen[dut.loop_idx]>length_cfg) $fatal(1,"Duplicate read sample");
        detected=(injected_data!=captured_expected);
      end
      if(detected) begin
        captured_loop=dut.loop_idx;
        if(captured_loop>1) $fatal(1,"Unexpected loop progression");
        produced[captured_loop]=produced[captured_loop]+1;
        captured_index=produced[captured_loop];
        if(captured_index>127) $fatal(1,"Unexpected repeated compare events");
        expected_address[captured_loop][captured_index]=captured_address;
        expected_actual[captured_loop][captured_index]=injected_data;
        expected_word[captured_loop][captured_index]=captured_expected;
      end
    end
    #1;
    if(active && rst_n) begin
      if({dut.R_EN,dut.R_WN,dut.R_GN,dut.R_UBN,dut.R_LBN,dut.addr_d,dut.dq_write_data}!==expected_pad)
        $fatal(1,"IOB did not follow command during detail traffic or replacement");
      if(dut.addr_compare_count!==dut.addr_cnt) $fatal(1,"Address replica diverged during detail control");
      if(dut.hold_release_count!==dut.addr_hold_cnt || dut.hold_sample_count!==dut.addr_hold_cnt)
        $fatal(1,"Timer replicas diverged during detail/start/loop control");
      if(detected && (dut.error_addr_snapshot!==captured_address ||
         dut.error_data_snapshot!==injected_data || dut.error_expected_snapshot!==captured_expected))
        $fatal(1,"Compare-edge snapshot used wrong operands case=%0d loop=%0d seen=%0d A=%h expectedA=%h value=%h expected=%h",case_no,dut.loop_idx,read_seen[dut.loop_idx],dut.error_addr_snapshot,captured_address,dut.error_data_snapshot,dut.error_expected_snapshot);
      if(dut.loop_idx>acks) $fatal(1,"Loop advanced without summary ACK");
      // Independent active-cycle contract: no error, full queue or host poll
      // is allowed to stretch an address or a CE/WE/OE/BN pulse.
      if(dut.pad_active) begin
        engine_tick=prior_flg?engine_tick+1:0;
        read_period=(read_cfg==1 && period_cfg<8)?8:period_cfg;
        write_cycles=length_cfg*period_cfg;
        tail_cycles=((read_cfg==1)?9:8)-read_period;
        if(tail_cycles<0)tail_cycles=0;
        total_cycles=write_cycles+length_cfg*read_period+tail_cycles;
        is_read=engine_tick>=write_cycles;
        if(is_read)begin
          read_tick=engine_tick-write_cycles;offset=read_tick/read_period;
          if(offset>=length_cfg)offset=length_cfg-1;
          slot=read_tick-offset*read_period;
          want_wn=1;want_en=(read_cfg==0)?0:(slot==0 || slot>=read_period);
          want_gn=want_en;want_bn=want_en;
        end else begin
          offset=engine_tick/period_cfg;slot=engine_tick%period_cfg;
          want_gn=1;want_en=!(slot<period_cfg-2);
          want_wn=!(slot>=1 && slot<period_cfg-3);want_bn=want_en;
        end
        if(engine_tick>=total_cycles || dut.A!==configured_start+offset ||
           {dut.EN,dut.WN,dut.GN,dut.UBN,dut.LBN}!=={want_en,want_wn,want_gn,want_bn,want_bn})
          $fatal(1,"Error/queue changed active pin timing case=%0d loop=%0d tick=%0d",case_no,dut.loop_idx,engine_tick);
      end else if(prior_flg && engine_tick+1!=total_cycles)
        $fatal(1,"Error/queue changed active loop duration");
      prior_flg=dut.pad_active;
    end else prior_flg=0;
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
      cfg[8]=length_cfg;cfg[12]=2;cfg[16]=period_cfg;cfg[17]=1;cfg[18]=read_cfg;cfg[19]=enable_detail;
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
    for(case_no=0;case_no<8;case_no=case_no+1) begin
      active=0;rst_n=0;cs_n=1;sclk=0;#30;
      produced[0]=0;produced[1]=0;received_details[0]=0;received_details[1]=0;read_seen[0]=0;read_seen[1]=0;
      acks=0;summaries=0;pauses=0;aborted=0;polls=0;
      enable_detail=(case_no!=2);faults=(case_no<3 || case_no>=5);
      length_cfg=(case_no>=6)?32:4;read_cfg=(case_no==6)?0:1;
      period_cfg=(case_no==0 || case_no==2 || case_no==4 || case_no>=6)?7:10;
      injected_data=faults?16'hbeef:16'd0;
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
            produced[0]=0;produced[1]=0;received_details[0]=0;received_details[1]=0;read_seen[0]=0;read_seen[1]=0;
            acks=0;summaries=0;pauses=0;aborted=0;polls=0;active=1;
          end
        join
      end
      while(summaries<2) begin
        if(case_no>=6) wait(dut.u_spi_protocol.pending_test_complete && !dut.u_spi_protocol.test_busy);
        wait(dut.u_spi_protocol.detail_pending || dut.u_spi_protocol.pending_test_complete);
        #100;
        if(enable_detail && !aborted && dut.u_spi_protocol.detail_pending) begin
          before_ack=acks;poll(12);aborted=1;
          if(dut.detail_stall || acks!=before_ack) $fatal(1,"Partial detail consumed/advanced producer");
        end
        before_ack=acks;poll(0);polls=polls+1;
        if(polls>40) $fatal(1,"Too many polls without completion");
        if(bytes[0]==0) begin
          for(n=0;n<64;n=n+1) if(bytes[n]!==0) $fatal(1,"Partial idle frame");
        end else begin
          if(bytes[0]!==8'h55 || bytes[2]!==8'hff ||
             {bytes[10],bytes[9],bytes[8],bytes[7]}!==length_cfg)
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
            if(enable_detail && received_details[frame_loop]!=((produced[frame_loop]>8)?8:produced[frame_loop]))
              $fatal(1,"Summary overtook pending error records");
            if(reported_drops[frame_loop]!==((enable_detail)?produced[frame_loop]-received_details[frame_loop]:0) ||
               reported_overflow[frame_loop]!==((enable_detail && produced[frame_loop]>8)?1'b1:1'b0))
              $fatal(1,"ILA loss diagnostics disagree with total minus delivered details");
            if(acks!=before_ack+1) $fatal(1,"Summary ACK mismatch");
            for(n=17;n<64;n=n+1) if(bytes[n]!==0) $fatal(1,"Bad summary padding");
            summaries=summaries+1;
          end else $fatal(1,"Unknown report type %h",bytes[1]);
        end
      end
      if(dut.loop_done!==1 || acks!=2) $fatal(1,"Final loop did not terminate");
      if(faults && (produced[0]==0 || produced[1]==0)) $fatal(1,"Fault injection did not execute");
      if(pauses!=0) $fatal(1,"Error logging stretched MRAM timing");
      if(!faults && (produced[0]!=0 || produced[1]!=0 || pauses!=0)) $fatal(1,"False error or pause");
      $display("PASS case %0d: period=%0d detail=%0d errors=%0d/%0d pause cycles=%0d",case_no,period_cfg,enable_detail,produced[0],produced[1],pauses);
      active=0;
    end
    $display("PASS: %0d top-level detailed records; continuous pins with dense faults/full FIFO, slow/aborted polling, overflow totals, restart and disabled/no-error modes",total_details);
    $finish;
  end
  initial begin #10000000;$fatal(1,"Top-level detail watchdog expired");end
endmodule
