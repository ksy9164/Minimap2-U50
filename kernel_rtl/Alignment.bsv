package Alignment;

import Vector::*;
import FIFO::*;
import BRAMFIFO::*;
import FIFOLI::*;

interface SWG_IFC;
    method Action set_pe(Bit#(16) d);
    method Action put(Bit#(2) d);
    method ActionValue#(Bit#(64)) getOutput();
endinterface

function Bit#(8) max2(Bit#(8) a, Bit#(8) b);
    Bit#(8) maxAB = (a > b) ? a : b;
    return maxAB;
endfunction

function Bit#(8) max3(Bit#(8) a, Bit#(8) b, Bit#(8) c);
    Bit#(8) maxAB = (a > b) ? a : b;
    return (maxAB > c) ? maxAB : c;
endfunction

(* synthesize *)
module mkSWG(SWG_IFC);
    /* FIFO#(Bit#(2)) inputQ <- mkFIFO; */
    Vector#(9,FIFO#(Bit#(2))) inputQ <- replicateM(mkFIFO);

    Vector#(2,FIFO#(Bit#(8))) pe_initQ <- replicateM(mkFIFO);
    Vector#(8, Reg#(Bit#(2))) target_ch <- replicateM(mkReg(0));

    Vector#(9, Reg#(Bit#(8))) data_e <- replicateM(mkReg(0));
    Vector#(9, Reg#(Bit#(8))) data_f <- replicateM(mkReg(0));
    Vector#(9,FIFO#(Bit#(8))) data_sQ <- replicateM(mkFIFO);

    Vector#(8,FIFOLI#(Bit#(8), 3)) resQ <- replicateM(mkFIFOLI);
    Vector#(4,FIFO#(Bit#(16))) res_1Q <- replicateM(mkFIFO);
    Vector#(2,FIFO#(Bit#(32))) res_2Q <- replicateM(mkFIFO);

    FIFO#(Bit#(64)) outputQ <- mkFIFO;

    for (Bit#(8) i = 0; i < 2; i = i + 1) begin
        rule initPEs;
            pe_initQ[i].deq;
            let d = pe_initQ[i].first;

            target_ch[i * 4] <= d[1: 0];
            target_ch[i * 4 + 1] <= d[3: 2];
            target_ch[i * 4 + 2] <= d[5: 4];
            target_ch[i * 4 + 3] <= d[7: 6];
        endrule
    end

    for (Bit#(8) i = 1; i < 9; i = i +1) begin
        rule alignment;
            if (i != 1) begin
                data_sQ[i - 1].deq;
            end
            inputQ[i - 1].deq;

            Bit#(8) s = 0;

            if (i != 1) begin
                s = data_sQ[i - 1].first;
            end
            Bit#(8) f = data_f[i];
            Bit#(8) e = data_e[i - 1];

            Bit#(2) cur = target_ch[i - 1];
            Bit#(2) in = inputQ[i - 1].first;

            Bit#(8) new_s = 0;

            if (cur == in) begin
                new_s = max3(s + 2, e - 2, f - 1);
            end else begin
                new_s = max3(s - 1, e - 2, f - 1);
            end
            Bit#(8) new_e = max2(s, e) - 2;
            Bit#(8) new_f = max2(s, f) - 1;

            data_e[i] <= new_e;
            data_f[i] <= new_f;
            if (i != 8) begin
                data_sQ[i].enq(new_s);
                inputQ[i].enq(in);
            end
            resQ[i - 1].enq(new_s);
        endrule
    end

    /* Merge Output */
    for (Bit#(8) i = 0; i < 4; i = i +1) begin
        rule mergeOutput;
            resQ[i * 2].deq;
            resQ[i * 2 + 1].deq;
            Bit#(16) d = zeroExtend(resQ[i * 2].first);
            d[15:8] = resQ[i * 2 + 1].first;

            res_1Q[i].enq(d);
        endrule
    end

    /* Merge Output */
    for (Bit#(8) i = 0; i < 2; i = i + 1) begin
        rule mergeOutput_second_stage;
            res_1Q[i * 2].deq;
            res_1Q[i * 2 + 1].deq;
            Bit#(32) d = zeroExtend(res_1Q[i * 2].first);
            d[31:16] = res_1Q[i * 2 + 1].first;

            res_2Q[i].enq(d);
        endrule
    end

    rule mergeOutput_Final;
       res_2Q[0].deq;
       res_2Q[1].deq;

       Bit#(64) d = zeroExtend(res_2Q[0].first);
       d[63:32] = res_2Q[1].first;

       outputQ.enq(d);
    endrule

    method Action set_pe(Bit#(16) d);
        pe_initQ[0].enq(d[7:0]);
        pe_initQ[1].enq(d[15:8]);
    endmethod

    method Action put(Bit#(2) d);
        inputQ[0].enq(d);
    endmethod

    // Method to get the output scores (32 x 8 bits)
    method ActionValue#(Bit#(64)) getOutput();
        outputQ.deq;
        return outputQ.first;
    endmethod
endmodule

endpackage

