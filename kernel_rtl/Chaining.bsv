package Chaining;

import FIFO::*;
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

    Vector#(64, Reg#(Bit#(48))) past_x <- replicateM(mkReg(0));
    Vector#(64, Reg#(Bit#(48))) past_y <- replicateM(mkReg(0));
    Vector#(64, Reg#(Bit#(48))) past_dp <- replicateM(mkReg(0));

    Vector#(64, FIFO#(Tuple3#(Bit#(48), Bit#(48), Bit#(32)))) stage3 <- replicateM(mkFIFO);
    Vector#(16, FIFO#(Tuple3#(Bit#(48), Bit#(48), Bit#(32)))) stage2 <- replicateM(mkFIFO);
    Vector#(4, FIFO#(Tuple3#(Bit#(48), Bit#(48), Bit#(32)))) stage1 <- replicateM(mkFIFO);

    Vector#(64, FIFO#(Bit#(48))) res_1Q <- replicateM(mkFIFO);
    Vector#(16, FIFO#(Tuple2#(Bit#(48), Bit#(8)))) res_2Q <- replicateM(mkFIFO);
    Vector#(4, FIFO#(Tuple2#(Bit#(48), Bit#(8)))) res_3Q <- replicateM(mkFIFO);
    FIFO#(Tuple2#(Bit#(48), Bit#(8))) resQ <- mkFIFO;

    // To 4 -> 16
    for (Bit#(32) i = 0; i < 4; i = i +1) begin
        rule toStage2;
            stage1[i].deq;
            let d = stage1[i].first;

            for (Bit#(32) j = 0; j < 4; j = j + 1) begin
                stage2[i * 4 + j].enq(d);
            end
        endrule
    end

    // To 16 -> 64
    for (Bit#(32) i = 0; i < 16; i = i + 1) begin
        rule toStage3;
            stage2[i].deq;
            let d = stage2[i].first;

            for (Bit#(32) j = 0; j < 4; j = j + 1) begin
                stage3[i * 4 + j].enq(d);
            end
        endrule
    end

    for (Bit#(32) i = 0; i < 64; i = i + 1) begin
        rule doDynamic;
            stage3[i].deq;
            let x = tpl_1(stage3[i].first);
            let y = tpl_2(stage3[i].first);
            let w = tpl_3(stage3[i].first);

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
            res_1Q[i * 4].deq;
            res_1Q[i * 4 + 1].deq;
            res_1Q[i * 4 + 2].deq;
            res_1Q[i * 4 + 3].deq;

            let a = res_1Q[i * 4].first;
            let b = res_1Q[i * 4 + 1].first;
            let c = res_1Q[i * 4 + 2].first;
            let d = res_1Q[i * 4 + 3].first;

            if (a >= b) begin
                if (c >= d) begin
                    if (a >= c) begin
                        res_2Q[i].enq(tuple2(a, i * 4));
                    end else begin // c >=
                        res_2Q[i].enq(tuple2(c, i * 4 + 2));
                    end
                end else begin
                    if (a >= d) begin
                        res_2Q[i].enq(tuple2(a, i * 4));
                    end else begin
                        res_2Q[i].enq(tuple2(d, i * 4 + 3));
                    end
                end
            end else begin
                if (c >= d) begin
                    if (b >= c) begin
                        res_2Q[i].enq(tuple2(b, i * 4 + 1));
                    end else begin // c >=
                        res_2Q[i].enq(tuple2(c, i * 4 + 2));
                    end
                end else begin
                    if (b >= d) begin
                        res_2Q[i].enq(tuple2(b, i * 4 + 1));
                    end else begin
                        res_2Q[i].enq(tuple2(d, i * 4 + 3));
                    end
                end
            end
        endrule
    end

    for (Bit#(8) i = 0; i < 4; i = i + 1) begin
        rule res_relay2;
            res_2Q[i * 4].deq;
            res_2Q[i * 4 + 1].deq;
            res_2Q[i * 4 + 2].deq;
            res_2Q[i * 4 + 3].deq;

            let a = tpl_1(res_2Q[i * 4].first);
            let b = tpl_1(res_2Q[i * 4 + 1].first);
            let c = tpl_1(res_2Q[i * 4 + 2].first);
            let d = tpl_1(res_2Q[i * 4 + 3].first);

            let idx_a = tpl_2(res_2Q[i * 4].first);
            let idx_b = tpl_2(res_2Q[i * 4 + 1].first);
            let idx_c = tpl_2(res_2Q[i * 4 + 2].first);
            let idx_d = tpl_2(res_2Q[i * 4 + 3].first);

            if (a >= b) begin
                if (c >= d) begin
                    if (a >= c) begin
                        res_3Q[i].enq(tuple2(a, idx_a));
                    end else begin // c >=
                        res_3Q[i].enq(tuple2(c, idx_c));
                    end
                end else begin
                    if (a >= d) begin
                        res_3Q[i].enq(tuple2(a, idx_a));
                    end else begin
                        res_3Q[i].enq(tuple2(d, idx_d));
                    end
                end
            end else begin
                if (c >= d) begin
                    if (b >= c) begin
                        res_3Q[i].enq(tuple2(b, idx_a));
                    end else begin // c >=
                        res_3Q[i].enq(tuple2(c, idx_c));
                    end
                end else begin
                    if (b >= d) begin
                        res_3Q[i].enq(tuple2(b, idx_b));
                    end else begin
                        res_3Q[i].enq(tuple2(d, idx_d));
                    end
                end
            end
        endrule
    end

    // we can only send idx
    rule res_relay3;
        res_3Q[0].deq;
        res_3Q[1].deq;
        res_3Q[2].deq;
        res_3Q[3].deq;

        let a = tpl_1(res_3Q[0].first);
        let b = tpl_1(res_3Q[0 + 1].first);
        let c = tpl_1(res_3Q[0 + 2].first);
        let d = tpl_1(res_3Q[0 + 3].first);

        let idx_a = tpl_2(res_3Q[0].first);
        let idx_b = tpl_2(res_3Q[0 + 1].first);
        let idx_c = tpl_2(res_3Q[0 + 2].first);
        let idx_d = tpl_2(res_3Q[0 + 3].first);

        if (a >= b) begin
            if (c >= d) begin
                if (a >= c) begin
                    resQ.enq(tuple2(a, idx_a));
                end else begin // c >=
                    resQ.enq(tuple2(c, idx_c));
                end
            end else begin
                if (a >= d) begin
                    resQ.enq(tuple2(a, idx_a));
                end else begin
                    resQ.enq(tuple2(d, idx_d));
                end
            end
        end else begin
            if (c >= d) begin
                if (b >= c) begin
                    resQ.enq(tuple2(b, idx_a));
                end else begin // c >=
                    resQ.enq(tuple2(c, idx_c));
                end
            end else begin
                if (b >= d) begin
                    resQ.enq(tuple2(b, idx_b));
                end else begin
                    resQ.enq(tuple2(d, idx_d));
                end
            end
        end
    endrule
    // Enqueue d to the first 4 FIFOs
    method Action enq(Tuple3#(Bit#(48), Bit#(48), Bit#(32)) d);
            for (Bit#(32) j = 0; j < 4; j = j + 1) begin
                stage1[j].enq(d);
            end
    endmethod

    // Dequeue the final output from the last FIFO
    method ActionValue#(Tuple2#(Bit#(48), Bit#(8))) deq;
        let result = resQ.deq();
        return resQ.first; // returning the third value of the tuple
    endmethod

endmodule
endpackage

