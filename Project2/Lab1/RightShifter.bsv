import RightShifterTypes::*;
import Gates::*;

function Bit#(1) multiplexer1(Bit#(1) sel, Bit#(1) a, Bit#(1) b);
	// Part 1: Re-implement this function using the gates found in the Gates.bsv file
	// return (sel == 0)?a:b; 
	let notsel = notGate(sel);
	let ans1 = andGate(sel, b);
	let ans2 = andGate(notsel, a);
	return orGate(ans1, ans2);
endfunction

function Bit#(32) multiplexer32(Bit#(1) sel, Bit#(32) a, Bit#(32) b);
	// Part 2: Re-implement this function using static elaboration (for-loop and multiplexer1)
	// return (sel == 0)?a:b;
	Bit#(32) ans = 0;
	for (Integer i = 0; i < 32; i = i + 1)
	begin
		ans[i] = multiplexer1(sel, a[i], b[i]);
	end
	return ans; 
endfunction

function Bit#(n) multiplexerN(Bit#(1) sel, Bit#(n) a, Bit#(n) b);
	// Part 3: Re-implement this function as a polymorphic function using static elaboration
	// return (sel == 0)?a:b;
	Bit#(n) ans = 0;
	for (Integer i = 0; i < valueof(n); i = i + 1)
	begin
		ans[i] = multiplexer1(sel, a[i], b[i]);
	end
	return ans;
endfunction


module mkRightShifter (RightShifter);
    method Bit#(32) shift(ShiftMode mode, Bit#(32) operand, Bit#(5) shamt);
	// Parts 4 and 5: Implement this function with the multiplexers you implemented
        Bit#(32) result = 0;

        if (mode == LogicalRightShift) begin
           // result = operand >> shamt;
			result = operand;
			result = multiplexerN(shamt[0], result, {0, result[31:1]});
			result = multiplexerN(shamt[1], result, {0, result[31:2]});
			result = multiplexerN(shamt[2], result, {0, result[31:4]});
			result = multiplexerN(shamt[3], result, {0, result[31:8]});
			result = multiplexerN(shamt[4], result, {0, result[31:16]});
        end

        if(mode == ArithmeticRightShift) 
        begin
	    // Int#(32) signedOperand = unpack(operand);
            // result = pack(signedOperand >> shamt);
			Bit#(1) sign = operand[31];
			Bit#(2) sign2 = {sign, sign};
			Bit#(4) sign4 = {sign, sign, sign, sign};
			Bit#(8) sign8 = 0;
			for (Integer i = 0; i < 8; i = i + 1)
			begin
				sign8[i] = sign;
			end
			Bit#(16) sign16 = 0;
			for (Integer i = 0; i < 16; i = i + 1)
			begin
				sign16[i] = sign;
			end
			result = operand;
			result = multiplexerN(shamt[0], result, {sign, result[31:1]});
			result = multiplexerN(shamt[1], result, {sign2, result[31:2]});
			result = multiplexerN(shamt[2], result, {sign4, result[31:4]});
			result = multiplexerN(shamt[3], result, {sign8, result[31:8]});
			result = multiplexerN(shamt[4], result, {sign16, result[31:16]});
        end
        return result;   
    endmethod
endmodule

