import Axi4LiteControllerXrt::*;
import Axi4MemoryMaster::*;

import Vector::*;
import Clocks :: *;
import Serializer::*;

import KernelMain::*;

interface KernelTopIfc;
	(* always_ready *)
	interface Axi4MemoryMasterPinsIfc#(64,512) in;
	(* always_ready *)
	interface Axi4MemoryMasterPinsIfc#(64,512) out;
	(* always_ready *)
	interface Axi4LiteControllerXrtPinsIfc#(12,32) s_axi_control;
	(* always_ready *)
	method Bool interrupt;
endinterface

(* synthesize *)
(* default_reset="ap_rst_n", default_clock_osc="ap_clk" *)
module kernel (KernelTopIfc);
	Clock defaultClock <- exposeCurrentClock;
	Reset defaultReset <- exposeCurrentReset;

	Axi4LiteControllerXrtIfc#(12,32) axi4control <- mkAxi4LiteControllerXrt(defaultClock, defaultReset);
	Vector#(2, Axi4MemoryMasterIfc#(64,512)) axi4mem <- replicateM(mkAxi4MemoryMaster);
	//Axi4MemoryMasterIfc#(64,512) axi4file <- mkAxi4MemoryMaster;
	Reg#(Bool) started <- mkReg(False);
	Reg#(Bool) kernelDone <- mkReg(False);
	Reg#(Bit#(32)) prevVal <- mkReg(0);

	Reg#(Bit#(32)) cycleCounter <- mkReg(0);
	/* rule incCycle(started && !kernelDone);
     *     cycleCounter <= cycleCounter + 1;
	 * endrule */


	KernelMainIfc kernelMain <- mkKernelMain;

	// Check Started if AXI controller is ready
	rule checkStart (!started || kernelDone);
		if ( axi4control.ap_start ) begin
		    Bit#(32) d = axi4control.scalar00;
		    if (d != prevVal) begin
                kernelMain.start(d);
			    prevVal <= d;
			    kernelDone <= False;
			    started <= True;
			    cycleCounter <= 0;
		    end
		end
	endrule

	rule checkDone (started && cycleCounter > 4096 && !kernelDone);
		Bool done = kernelMain.done;
		if (done) begin
		    axi4control.ap_done();
		    kernelDone <= True;
		end
	endrule
	for ( Integer i = 0; i < valueOf(MemPortCnt); i=i+1 ) begin
		rule relayReadReq00 (started && !kernelDone);
			let r <- kernelMain.mem[i].readReq;
			if ( i == 0 ) axi4mem[i].readReq(axi4control.mem_addr+r.addr,zeroExtend(r.bytes));
			else axi4mem[i].readReq(axi4control.file_addr+r.addr,zeroExtend(r.bytes));
		endrule
		rule relayWriteReq (started && !kernelDone);
			let r <- kernelMain.mem[i].writeReq;
			if ( i == 0 ) axi4mem[i].writeReq(axi4control.mem_addr+r.addr,zeroExtend(r.bytes));
			else axi4mem[i].writeReq(axi4control.file_addr+r.addr,zeroExtend(r.bytes));
		endrule
		rule relayWriteWord (started && !kernelDone);
			let r <- kernelMain.mem[i].writeWord;
			axi4mem[i].write(r);
		endrule
		rule relayReadWord (started && !kernelDone);
			let d <- axi4mem[i].read;
			kernelMain.mem[i].readWord(d);
		endrule
	end

	interface in = axi4mem[0].pins;
	interface out = axi4mem[1].pins;
	//interface m02_axi = axi4mem[2].pins;
	//interface m03_axi = axi4mem[3].pins;
	interface s_axi_control = axi4control.pins;
	interface interrupt = axi4control.interrupt;
endmodule

import "BDPI" function Bit#(64) bdpi_read;
import "BDPI" function Action bdpi_write(Bit#(64) offset);

module kernel_bsim (Empty);
	Clock defaultClock <- exposeCurrentClock;
	Reset defaultReset <- exposeCurrentReset;

	DeSerializerIfc#(64, 8) deserialQ <- mkDeSerializer;
    SerializerIfc#(512, 8) serialQ <- mkSerializer;

	Reg#(Bit#(32)) cycleCounter <- mkReg(0);
	rule incCycle;
		cycleCounter <= cycleCounter + 1;
	endrule

	Reg#(Bool) started <- mkReg(False);

	KernelMainIfc kernelMain <- mkKernelMain;

	rule checkStart (!started);
		kernelMain.start(1024);
		started <= True;
	endrule

	rule relayReadReq00;
		let r <- kernelMain.mem[0].readReq;
	endrule
	rule relayWriteReq;
		let r <- kernelMain.mem[1].writeReq;
	endrule

	rule relayWriteWord;
		let d <- kernelMain.mem[1].writeWord;
	    serialQ.put(d);
	endrule
	rule writeWord;
	    let d <- serialQ.get;
		bdpi_write(d);
	endrule

	rule relayReadWord;
		let d = bdpi_read;
		deserialQ.put(d);
	endrule
	rule readWord;
	    let d <- deserialQ.get;
		kernelMain.mem[0].readWord(d);
	endrule
endmodule
