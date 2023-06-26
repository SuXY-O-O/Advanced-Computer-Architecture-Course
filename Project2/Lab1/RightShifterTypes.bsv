typedef enum {
  LogicalRightShift,
  ArithmeticRightShift,
  LeftShift
} ShiftMode deriving (Bits,Eq);

interface Multiplexer#(type muxed);

    method muxed multiplexer(Bit#(1) sel, muxed a, muxed b);
    
endinterface

interface RightShifter;

    method Bit#(32) shift(ShiftMode mode, Bit#(32) operand, Bit#(5) shamt);
    
endinterface
