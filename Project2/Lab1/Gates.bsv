
function Bit#(1) orGate(Bit#(1) op1, Bit#(1) op2);
    return op1 | op2;
endfunction

function Bit#(1) andGate(Bit#(1) op1, Bit#(1) op2);
    return op1 & op2;
endfunction

function Bit#(1) xorGate(Bit#(1) op1, Bit#(1) op2);
    return op1 ^ op2;
endfunction

function Bit#(1) notGate(Bit#(1) op1);
    return ~op1;
endfunction

