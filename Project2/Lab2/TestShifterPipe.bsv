import RightShifterTypes::*;
import RightShifter::*;
import FIFO::*;

(* synthesize *)
module mkTests (Empty);
   RightShifterPipelined rsp <- mkRightShifterPipelined;
   Reg#(Bit#(32)) tbCounter <- mkReg(0);
   FIFO#(Bit#(32)) answerFifo <- mkSizedFIFO(6);
   FIFO#(Bit#(32)) originFifo <- mkSizedFIFO(6);
   
   // there are many ways to write tests.  Here is a very simple
   // version, just to get you started.

   rule run;
	rsp.push(ArithmeticRightShift, -4, 2);
	answerFifo.enq(-1);
        originFifo.enq(tbCounter);
	tbCounter <= tbCounter + 3;
   endrule

   rule test;

      let b <- rsp.pull();
      let answer = answerFifo.first();
      let origin = originFifo.first();
      originFifo.deq();
      answerFifo.deq();
	//$display("origin is ", origin, " result is ", b, " expected ", answer);
      if (b != answer) begin
	$display("result is ", b, " but expected ", answer);
      end
      else begin
	$display("correct!");
      end

      if (tbCounter > 100) $finish(0);

   endrule
endmodule
