/*

Copyright (C) 2012

Arvind <arvind@csail.mit.edu>
Derek Chiou <derek@ece.utexas.edu>
Muralidaran Vijayaraghavan <vmurali@csail.mit.edu>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/


import Types::*;
import ProcTypes::*;
import MemTypes::*;
import RFile::*;
import IMemory::*;
import DMemory::*;
import Decode::*;
import Exec::*;
import Cop::*;

//typedef enum {Fetch, Execute} State deriving (Bits, Eq);
typedef enum {
  Fetch, 
  Execute,
  Writeback
} State deriving (Bits, Eq);

interface Proc;
   method ActionValue#(Tuple2#(RIndx, Data)) cpuToHost;
   method Action hostToCpu(Bit#(32) startpc);
endinterface

(* synthesize *)
module [Module] mkProc(Proc);
  Reg#(Addr) pc <- mkRegU;
  RFile      rf <- mkRFile;
  IMemory  iMem <- mkIMemory;
  DMemory  dMem <- mkDMemory;
  Cop       cop <- mkCop;
  
  Reg#(State) state <- mkReg(Fetch);
  Reg#(Data)     ir <- mkRegU;

  // add for writeback
  Reg#(Maybe#(FullIndx)) eInstDst <- mkRegU;
  Reg#(Data) eInstData <- mkRegU;
  Reg#(Addr) eInstAddr <- mkRegU;
  Reg#(Bool) eInstBrTaken <- mkRegU;

  rule doFetch(cop.started && state == Fetch);
    let inst = iMem.req(pc);

    $display("pc: %h inst: (%h) expanded: ", pc, inst, showInst(inst));

    // store the instruction in a register
    ir <= inst;

    // switch to execute state
    state <= Execute;
  endrule

  rule doExecute(cop.started && state == Execute);
    let inst = ir;

    let dInst = decode(inst);

    let rVal1 = rf.rd1(validRegValue(dInst.src1));
    let rVal2 = rf.rd2(validRegValue(dInst.src2));     

    let copVal = cop.rd(validRegValue(dInst.src1));

    let eInst = exec(dInst, rVal1, rVal2, pc, ?, copVal);

    if(eInst.iType == Unsupported)
    begin
      $fwrite(stderr, "Executing unsupported instruction at pc: %x. Exiting\n", pc);
      $finish;
    end

    if(eInst.iType == Ld)
    begin
      let data <- dMem.req(MemReq{op: Ld, addr: eInst.addr, byteEn: ?, data: ?});
      eInst.data = gatherLoad(eInst.addr, eInst.byteEn, eInst.unsignedLd, data);
    end
    else if(eInst.iType == St)
    begin
      match {.byteEn, .data} = scatterStore(eInst.addr, eInst.byteEn, eInst.data);
      let d <- dMem.req(MemReq{op: St, addr: eInst.addr, byteEn: byteEn, data: data});
    end

    //if (isValid(eInst.dst) && validValue(eInst.dst).regType == Normal)
      //rf.wr(validRegValue(eInst.dst), eInst.data);

    //pc <= eInst.brTaken ? eInst.addr : pc + 4;

    //cop.wr(eInst.dst, eInst.data);

    // switch back to fetch
    //state <= Fetch;

    // if (isValid(eInst.dst) && validValue(eInst.dst).regType == Normal)
    //   rf.wr(validRegValue(eInst.dst), eInst.data);

    // pc <= eInst.brTaken ? eInst.addr : pc + 4;

    // cop.wr(eInst.dst, eInst.data);

    // // switch back to fetch
    // state <= Fetch;

    // add for writeback
    state <= Writeback;
    eInstAddr <= eInst.addr;
    eInstData <= eInst.data;
    eInstBrTaken <= eInst.brTaken;
    eInstDst <= eInst.dst;
  endrule

  // add for writeback
  rule doWriteback(cop.started && state == Writeback);
    if (isValid(eInstDst) && validValue(eInstDst).regType == Normal)
    begin
      rf.wr(validRegValue(eInstDst), eInstData);
    end

    pc <= eInstBrTaken ? eInstAddr : pc + 4;

    cop.wr(eInstDst, eInstData);

    state <= Fetch;
  endrule
  
  method ActionValue#(Tuple2#(RIndx, Data)) cpuToHost;
    let ret <- cop.cpuToHost;
    return ret;
  endmethod

  method Action hostToCpu(Bit#(32) startpc) if (!cop.started);
    cop.start;
    pc <= startpc;
  endmethod
endmodule

//comment
// Minimal change from the 1-cycle implementation : Only ir and state were introduced
// The fetch and execute rules are mutually exclusive
// Princeton architecture doesn't add any complication to the Harvard architecture used in this example because the memory ports are accessed serially
