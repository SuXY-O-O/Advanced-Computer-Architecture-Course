import RightShifterTypes::*;
import Gates::*;
import FIFO::*;

function Bit#(1) multiplexer1(Bit#(1) sel, Bit#(1) a, Bit#(1) b);
    return orGate(andGate(a, sel),andGate(b, notGate(sel))); 
endfunction

function Bit#(32) multiplexer32(Bit#(1) sel, Bit#(32) a, Bit#(32) b);
	Bit#(32) res_vec = 0;
	for (Integer i = 0; i < 32; i = i+1)
	    begin
		res_vec[i] = multiplexer1(sel, a[i], b[i]);
	    end
	return res_vec; 
endfunction

function Bit#(n) multiplexerN(Bit#(1) sel, Bit#(n) a, Bit#(n) b);
	Bit#(n) res_vec = 0;
	for (Integer i = 0; i < valueof(n); i = i+1)
	    begin
		res_vec[i] = multiplexer1(sel, a[i], b[i]);
	    end
	return res_vec; 
endfunction

function Bit#(n) mkHeadSign(Bit#(1) sign, Integer num);
	Bit#(n) result = 0;
	for(Integer i = 0;i < num;i = i+1)
	  begin
		result[i] = sign;
	  end
	  return result;
endfunction

module mkRightShifterPipelined (RightShifterPipelined);
	Reg#(Int#(32)) opcount <- mkReg(0);
	Reg#(Int#(32)) opused <- mkReg(0);

    	FIFO#(Bit#(32)) operand0 <- mkFIFO();
	FIFO#(Bit#(32)) operand1 <- mkFIFO();
	FIFO#(Bit#(32)) operand2 <- mkFIFO();
	FIFO#(Bit#(32)) operand4 <- mkFIFO();
	FIFO#(Bit#(32)) operand8 <- mkFIFO();
	FIFO#(Bit#(32)) operand16 <- mkFIFO();

	//Reg#(Bool) ready0 <- mkReg(False);
	//Reg#(Bool) ready1 <- mkReg(False);
	//Reg#(Bool) ready2 <- mkReg(False);
	//Reg#(Bool) ready4 <- mkReg(False);
	//Reg#(Bool) ready8 <- mkReg(False);

	FIFO#(Bit#(5)) shamt0 <- mkFIFO();
	FIFO#(Bit#(4)) shamt1 <- mkFIFO();
	FIFO#(Bit#(3)) shamt2 <- mkFIFO();
	FIFO#(Bit#(2)) shamt4 <- mkFIFO();
	FIFO#(Bit#(1)) shamt8 <- mkFIFO();

	FIFO#(Bit#(1)) sign0 <- mkFIFO();
	FIFO#(Bit#(1)) sign1 <- mkFIFO();
	FIFO#(Bit#(1)) sign2 <- mkFIFO();
	FIFO#(Bit#(1)) sign4 <- mkFIFO();
	FIFO#(Bit#(1)) sign8 <- mkFIFO();

	rule step0 (True);
		let op0 = operand0.first();
		let si0 = sign0.first();
		let sh0 = shamt0.first();
		operand1.enq(multiplexerN(sh0[0], {si0, op0[31:1]}, op0));
		sign1.enq(si0);
		shamt1.enq(sh0[4:1]);
		operand0.deq();
		sign0.deq();
		shamt0.deq();
	endrule

	rule step1 (True);
		let op1 = operand1.first();
		let si1 = sign1.first();
		let sh1 = shamt1.first();
		operand2.enq(multiplexerN(sh1[0], {mkHeadSign(si1, 2), op1[31:2]}, op1));
		sign2.enq(si1);
		shamt2.enq(sh1[3:1]);
		operand1.deq();
		sign1.deq();
		shamt1.deq();
	endrule

	rule step2 (True);
		let op2 = operand2.first();
		let si2 = sign2.first();
		let sh2 = shamt2.first();
		operand4.enq(multiplexerN(sh2[0], {mkHeadSign(si2, 4), op2[31:4]}, op2));
		sign4.enq(si2);
		shamt4.enq(sh2[2:1]);
		operand2.deq();
		sign2.deq();
		shamt2.deq();
	endrule

	rule step4 (True);
		let op4 = operand4.first();
		let si4 = sign4.first();
		let sh4 = shamt4.first();
		operand8.enq(multiplexerN(sh4[0], {mkHeadSign(si4, 8), op4[31:8]}, op4));
		sign8.enq(si4);
		shamt8.enq(sh4[1]);
		operand4.deq();
		sign4.deq();
		shamt4.deq();
	endrule

	rule step8 (True);
		let op8 = operand8.first();
		let si8 = sign8.first();
		let sh8 = shamt8.first();
		operand16.enq(multiplexerN(sh8[0], {mkHeadSign(si8, 16), op8[31:16]}, op8));
		operand8.deq();
		sign8.deq();
		shamt8.deq();
	endrule

    method Action push(ShiftMode mode, Bit#(32) operand, Bit#(5) shamt);
	/* Write your code here */
		opcount <= opcount + 1;
		shamt0.enq(shamt);
		operand0.enq(operand);
		if (mode == LogicalRightShift)
		begin
			sign0.enq(0);
		end
		if (mode == ArithmeticRightShift)
		begin
			sign0.enq(operand[31]);
		end
    endmethod
	
    method ActionValue#(Bit#(32)) pull();
	/* Write your code here */
		let result = operand16.first();
		operand16.deq();
		return result;
    endmethod

endmodule

