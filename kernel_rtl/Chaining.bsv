import FIFO::*;
import FIFOLI::*;
import Vector::*;

// Define bit sizes using typedef
/* typedef Bit#(48) Bit#(48);
 * typedef Bit#(32) Bit#(32); */

function Bit#(48) min (Bit#(48) a, Bit#(48) b);
    return (a < b) ? a : b;
endfunction

function Bit#(48) max (Bit#(48) a, Bit#(48) b);
    return (a > b) ? a : b;
endfunction

function Bit#(48) rc (Bit#(48) l, Bit#(32) w);
    Bit#(48) d = zeroExtend(w);

    return (d * l / 100); // TODO : LOG for the next MSB
endfunction

// Module interface
interface ChainingIfc;
    method Action enq(Tuple3#(Bit#(48), Bit#(48), Bit#(32)) d);
    method ActionValue#(Tuple2#(Bit#(48), Bit#(8))) deq;
endinterface

module mkChaining(ChainingIfc);
    // Define FIFOs array
    // Create hierarchies of FIFOs: 64 -> 16 -> 4 -> 1

    Vector#(32, Reg#(Bit#(48))) past_x <- replicateM(mkReg(0));
    Vector#(32, Reg#(Bit#(48))) past_y <- replicateM(mkReg(0));
    Vector#(32, Reg#(Bit#(48))) past_dp <- replicateM(mkReg(0));

    Vector#(32, FIFO#(Tuple3#(Bit#(48), Bit#(48), Bit#(32)))) stage4 <- replicateM(mkFIFO);
    Vector#(16, FIFO#(Tuple3#(Bit#(48), Bit#(48), Bit#(32)))) stage3 <- replicateM(mkFIFO);
    Vector#(8, FIFO#(Tuple3#(Bit#(48), Bit#(48), Bit#(32)))) stage2 <- replicateM(mkFIFO);
    Vector#(4, FIFO#(Tuple3#(Bit#(48), Bit#(48), Bit#(32)))) stage1 <- replicateM(mkFIFO);
    Vector#(2, FIFOLI#(Tuple3#(Bit#(48), Bit#(48), Bit#(32)), 3)) stage0 <- replicateM(mkFIFOLI);

    Vector#(32, FIFO#(Bit#(48))) res_1Q <- replicateM(mkFIFO);
    Vector#(16, FIFO#(Tuple2#(Bit#(48), Bit#(8)))) res_2Q <- replicateM(mkFIFO);
    Vector#(8, FIFO#(Tuple2#(Bit#(48), Bit#(8)))) res_3Q <- replicateM(mkFIFO);
    Vector#(4, FIFO#(Tuple2#(Bit#(48), Bit#(8)))) res_4Q <- replicateM(mkFIFO);
    Vector#(2, FIFOLI#(Tuple2#(Bit#(48), Bit#(8)), 3)) resQ <- replicateM(mkFIFOLI);
    /* FIFO#(Tuple2#(Bit#(48), Bit#(8))) resQ <- mkFIFO; */

    // To 2 -> 4
    for (Bit#(32) i = 0; i < 2; i = i +1) begin
        rule toStage1;
            stage0[i].deq;
            let d = stage0[i].first;

            for (Bit#(32) j = 0; j < 2; j = j + 1) begin
                stage1[i * 2 + j].enq(d);
            end
        endrule
    end

    // To 4 -> 8
    for (Bit#(32) i = 0; i < 4; i = i +1) begin
        rule toStage2;
            stage1[i].deq;
            let d = stage1[i].first;

            for (Bit#(32) j = 0; j < 2; j = j + 1) begin
                stage2[i * 2 + j].enq(d);
            end
        endrule
    end

    // To 8 -> 16
    for (Bit#(32) i = 0; i < 8; i = i + 1) begin
        rule toStage3;
            stage2[i].deq;
            let d = stage2[i].first;

            for (Bit#(32) j = 0; j < 2; j = j + 1) begin
                stage3[i * 2 + j].enq(d);
            end
        endrule
    end

    // To 16 -> 32
    for (Bit#(32) i = 0; i < 16; i = i + 1) begin
        rule toStage4;
            stage3[i].deq;
            let d = stage3[i].first;

            for (Bit#(32) j = 0; j < 2; j = j + 1) begin
                stage4[i * 2 + j].enq(d);
            end
        endrule
    end

    for (Bit#(32) i = 0; i < 32; i = i + 1) begin
        rule doDynamic;
            stage4[i].deq;
            let x = tpl_1(stage4[i].first);
            let y = tpl_2(stage4[i].first);
            let w = tpl_3(stage4[i].first);

            Bit#(48) a, b, dp;
            if (y - past_y[i] > x - past_x[i]) begin
                a = min(y - past_y[i], zeroExtend(w));
                b = rc((y - past_y[i]) - (x - past_x[i]), w);
            end else begin
                a = min(x - past_x[i], zeroExtend(w));
                b = rc((x - past_x[i]) - (y - past_y[i]), w);
            end

            dp = max(past_dp[i] + a + b, zeroExtend(w));

            if (i != 0) begin
                past_dp[i - 1] <= dp;
                past_x[i - 1] <= x;
                past_y[i - 1] <= y;
            end
            res_1Q[i].enq(dp);
        endrule
    end

    for (Bit#(8) i = 0; i < 16; i = i + 1) begin
        rule relay_result;
            res_1Q[i * 2].deq;
            res_1Q[i * 2 + 1].deq;

            let a = res_1Q[i * 2].first;
            let b = res_1Q[i * 2 + 1].first;

            if (a >= b) begin
                res_2Q[i].enq(tuple2(a, i * 2));
            end else begin
                res_2Q[i].enq(tuple2(b, i * 2 + 1));
            end
        endrule
    end

    for (Bit#(8) i = 0; i < 8; i = i + 1) begin
        rule res_relay2;
            res_2Q[i * 2].deq;
            res_2Q[i * 2 + 1].deq;

            let a = tpl_1(res_2Q[i * 2].first);
            let b = tpl_1(res_2Q[i * 2 + 1].first);

            let idx_a = tpl_2(res_2Q[i * 2].first);
            let idx_b = tpl_2(res_2Q[i * 2 + 1].first);

            if (a >= b) begin
                res_3Q[i].enq(tuple2(a, idx_a));
            end else begin
                res_3Q[i].enq(tuple2(b, idx_a));
            end
        endrule
    end

    for (Bit#(8) i = 0; i < 4; i = i + 1) begin
        rule res_relay3;
            res_3Q[i * 2].deq;
            res_3Q[i * 2 + 1].deq;

            let a = tpl_1(res_3Q[i * 2].first);
            let b = tpl_1(res_3Q[i * 2 + 1].first);

            let idx_a = tpl_2(res_3Q[i * 2].first);
            let idx_b = tpl_2(res_3Q[i * 2 + 1].first);

            if (a >= b) begin
                res_4Q[i].enq(tuple2(a, idx_a));
            end else begin
                res_4Q[i].enq(tuple2(b, idx_a));
            end
        endrule
    end

    // we can only send idx
    for (Bit#(8) i = 0; i < 2; i = i + 1) begin
        rule res_relay4;
            res_4Q[i * 2].deq;
            res_4Q[i * 2 + 1].deq;

            let a = tpl_1(res_4Q[i * 2].first);
            let b = tpl_1(res_4Q[i * 2 + 1].first);

            let idx_a = tpl_2(res_4Q[i * 2].first);
            let idx_b = tpl_2(res_4Q[i * 2 + 1].first);

            if (a >= b) begin
                resQ[i].enq(tuple2(a, idx_a));
            end else begin
                resQ[i].enq(tuple2(b, idx_a));
            end
        endrule
    end
    // Enqueue d to the first 4 FIFOs
    method Action enq(Tuple3#(Bit#(48), Bit#(48), Bit#(32)) d);
        stage0[0].enq(d);
        stage0[1].enq(d);
    endmethod

    // Dequeue the final output from the last FIFO
    method ActionValue#(Tuple2#(Bit#(48), Bit#(8))) deq;
            resQ[0].deq;
            resQ[1].deq;

            let a = tpl_1(resQ[0].first);
            let b = tpl_1(resQ[1].first);

            let idx_a = tpl_2(resQ[0].first);
            let idx_b = tpl_2(resQ[1].first);

            if (a >= b) begin
                return resQ[0].first;
            end else begin
                return resQ[1].first;
            end
    endmethod

endmodule
