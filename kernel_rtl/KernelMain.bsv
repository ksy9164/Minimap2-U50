import FIFO::*;
import Vector::*;
import Chaining::*;

typedef 2 MemPortCnt;

interface MemPortIfc;
	method ActionValue#(MemPortReq) readReq;
	method ActionValue#(MemPortReq) writeReq;
	method ActionValue#(Bit#(512)) writeWord;
	method Action readWord(Bit#(512) word);
endinterface

interface KernelMainIfc;
	method Action start(Bit#(32) param);
	method Bool done;
	interface Vector#(MemPortCnt, MemPortIfc) mem;
endinterface

typedef struct {
	Bit#(64) addr;
	Bit#(32) bytes;
} MemPortReq deriving (Eq,Bits);

typedef 128 Kval;
typedef 128 Wval;
//typedef 35 Kval;
//typedef 40 Wval;

module mkKernelMain(KernelMainIfc);
	Vector#(MemPortCnt, FIFO#(MemPortReq)) readReqQs <- replicateM(mkFIFO);
	Vector#(MemPortCnt, FIFO#(MemPortReq)) writeReqQs <- replicateM(mkFIFO);
	Vector#(MemPortCnt, FIFO#(Bit#(512))) writeWordQs <- replicateM(mkFIFO);
	Vector#(MemPortCnt, FIFO#(Bit#(512))) readWordQs <- replicateM(mkFIFO);

	Reg#(Bit#(32)) cycleCounter <- mkReg(0);
	Reg#(Bool) started <- mkReg(False);
	Reg#(Bit#(32)) bytesToRead <- mkReg(0);

	ChainingIfc chain <- mkChaining;

	FIFO#(Bit#(512)) resultQ <-mkFIFO;

	rule incCycle;
		cycleCounter <= cycleCounter + 1;
	endrule

	//////////////////////////////////////////////////////////////////////////
	Reg#(Bit#(64)) readReqOff <- mkReg(0);
	Reg#(Bit#(64)) writeReqOff <- mkReg(0);
	Reg#(Bool) kernelDone <- mkReg(False);

	rule sendReadReq (bytesToRead > 0);
		if ( bytesToRead > 64 ) bytesToRead <= bytesToRead - 64;
		else bytesToRead <= 0;

		readReqQs[0].enq(MemPortReq{addr:zeroExtend(readReqOff), bytes:64});
		readReqOff <= readReqOff+ 64;
	endrule

    // This is a simple calculation for testing
	rule addNumber;
		let d = readWordQs[0].first;
		readWordQs[0].deq;

		chain.enq(tuple3(d[256:256-47], d[64:64-47], d[312:312-31]));

/*         d[63:32] = bytesToRead;
 *         d = d + 7;
 *
 *         resultQ.enq(d); */
	endrule

	rule writeResult;
		/* let d = resultQ.first; */
	    let d <- chain.deq;

		writeReqQs[1].enq(MemPortReq{addr:writeReqOff, bytes:64});
		writeReqOff <= writeReqOff + 64;
		writeWordQs[1].enq(zeroExtend(tpl_1(d)));
	endrule

	rule checkDone;
	    if (writeReqOff == readReqOff && started && writeReqOff != 0) begin
	        kernelDone <= True;
	    end 	
	endrule

	//////////////////////////////////////////////////////////////////////////

	
	Vector#(MemPortCnt, MemPortIfc) mem_;
	for (Integer i = 0; i < valueOf(MemPortCnt); i=i+1) begin
		mem_[i] = interface MemPortIfc;
			method ActionValue#(MemPortReq) readReq;
				readReqQs[i].deq;
				return readReqQs[i].first;
			endmethod
			method ActionValue#(MemPortReq) writeReq;
				writeReqQs[i].deq;
				return writeReqQs[i].first;
			endmethod
			method ActionValue#(Bit#(512)) writeWord;
				writeWordQs[i].deq;
				return writeWordQs[i].first;
			endmethod
			method Action readWord(Bit#(512) word);
				readWordQs[i].enq(word);
			endmethod
		endinterface;
	end

	method Action start(Bit#(32) param);
		started <= True;
		bytesToRead <= param;
		readReqOff <= 0;
	    writeReqOff <= 0;
	    kernelDone <= False;
	endmethod
	method Bool done;
	    let d = kernelDone;
	    return d;
	endmethod
	interface mem = mem_;
endmodule

