typedef enum {
  LogicalRightShift,
  ArithmeticRightShift,
  LeftShift
} ShiftMode deriving (Bits,Eq);

interface Multiplexer#(type muxed);

    method muxed multiplexer(Bit#(1) sel, muxed a, muxed b);
    
endinterface

interface RightShifterPipelined;

    method Action push(ShiftMode mode, Bit#(32) operand, Bit#(5) shamt);
    method ActionValue#(Bit#(32)) pull();
    
endinterface
