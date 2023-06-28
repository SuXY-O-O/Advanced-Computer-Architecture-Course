/*

Copyright (C) 2012 Muralidaran Vijayaraghavan <vmurali@csail.mit.edu>

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
import Fifo::*;
import AddrPred::*;
import Scoreboard::*;

typedef struct {
  Addr pc;
  Addr ppc;
  Data inst;
  Bool epoch;
  DecodedInst dInst;
  Data rVal1;
  Data rVal2;
} Fetch2Execute deriving (Bits, Eq);

typedef struct {
  Maybe#(FullIndx) dst;
  Data data;
} Execute2WriteBack deriving (Bits, Eq);

typedef struct {
  Maybe#(FullIndx) dst;
  Data data;
} WritebackData deriving (Bits, Eq);


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
  AddrPred pcPred <- mkBtb;

  Fifo#(2, Fetch2Execute) ireg <- mkPipelineFifo;
  Fifo#(2, Execute2WriteBack) wreg <- mkPipelineFifo;
  
  Fifo#(1, Redirect) execRedirect <- mkBypassFifo;
  // add for lab4, bypassing data from writeback to fetch
  Fifo#(1, WritebackData) writebackBypass <- mkBypassFifo;

  Scoreboard#(2) scoreboard <- mkCFScoreboard;

  Reg#(Bool) fEpoch <- mkReg(False);
  Reg#(Bool) eEpoch <- mkReg(False);

  rule doFetch(cop.started);
    let inst = iMem.req(pc);
    $display("Fetch: pc: %h inst: (%h) expanded: ", pc, inst, showInst(inst));

    // add for lab4, decode here
    let dInst = decode(inst);

    // add for lab4, check scoreboard
    let flag1 = scoreboard.search2(dInst.src1);
    let flag2 = scoreboard.search2(dInst.src2);
    let flagWriting = flag1 || flag2;

    // dequeue the incoming redirect and update the predictor whether it's a mispredict or not
    if(execRedirect.notEmpty)
    begin
      execRedirect.deq;
      pcPred.update(execRedirect.first);
    end

    // add for lab4, clean the bypass data
    if(writebackBypass.notEmpty)
    begin
      writebackBypass.deq;
    end

    // change pc and the fetch's copy of the epoch only on a mispredict
    if(execRedirect.notEmpty && execRedirect.first.mispredict)
    begin
      fEpoch <= !fEpoch;
      pc <= execRedirect.first.nextPc;
    end    
    // add for lab4, try to fetch the new instruction on a non mispredict
    else
    begin 
      // add for lab4, if data conflict and have bypass data, check bypass data
      if(writebackBypass.notEmpty && flagWriting)
      begin
        let rVal2 = rf.rd2(validRegValue(dInst.src2));
        let rVal1 = rf.rd1(validRegValue(dInst.src1));
        if((!flag2) && dInst.src1==writebackBypass.first.dst)
        begin
          // add display will stack overflow ?????????? 
          // $display("Fetch and read reg from bypass(R1): pc: %h inst: (%h) expanded: ", pc, inst, showInst(inst));
          let ppc = pcPred.predPc(pc);
          pc <= ppc;
          ireg.enq(Fetch2Execute{pc:pc , ppc:ppc , inst:inst , epoch:fEpoch , dInst:dInst , rVal1:writebackBypass.first.data , rVal2: rVal2});
          if(isValid(dInst.dst))
            scoreboard.insert(dInst.dst);
        end
        else if((!flag1) && dInst.src2==writebackBypass.first.dst)
        begin
          // $display("Fetch and read reg from bypass(R2): pc: %h inst: (%h) expanded: ", pc, inst, showInst(inst));
          let ppc = pcPred.predPc(pc);
          pc <= ppc;
          ireg.enq(Fetch2Execute{pc:pc , ppc:ppc , inst:inst , epoch:fEpoch , dInst:dInst , rVal1: rVal1, rVal2: writebackBypass.first.data});
          if(isValid(dInst.dst))
            scoreboard.insert(dInst.dst);
        end
      end
      // add for lab4, fire if there is no data conflict
      else if(!flagWriting)
      begin
        let ppc = pcPred.predPc(pc);
        let rVal2 = rf.rd2(validRegValue(dInst.src2));
        let rVal1 = rf.rd1(validRegValue(dInst.src1));
        // $display("Fetch and read reg: pc: %h inst: (%h) expanded: ", pc, inst, showInst(inst));
        pc <= ppc;
        ireg.enq(Fetch2Execute{pc:pc , ppc:ppc , inst:inst , epoch:fEpoch , dInst:dInst , rVal1:rVal1 , rVal2: rVal2});
        if(isValid(dInst.dst))
          scoreboard.insert(dInst.dst);
      end 
      // add for lab4, do nothing if there is data conflict, write a useless line here to make bluespec happy
      else 
        let ppc = pcPred.predPc(pc);
    end
  endrule

  rule doExecute;
    let inst  = ireg.first.inst;
    let pc    = ireg.first.pc;
    let ppc   = ireg.first.ppc;
    let epoch = ireg.first.epoch;

    // add for lab4
    let dInst = ireg.first.dInst;
    let rVal1 = ireg.first.rVal1;
    let rVal2 = ireg.first.rVal2;

    // Proceed only if the epochs match
    if(epoch == eEpoch)
    begin
      let copVal = cop.rd(validRegValue(dInst.src1));
      let eInst = exec(dInst, rVal1, rVal2, pc, ppc, copVal);  
      $display("Execute: pc: %h inst: (%h) expanded: ", pc, inst, showInst(inst));
  
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

      // add for lab4, add writeback stage
      wreg.enq(Execute2WriteBack{dst:eInst.dst , data:eInst.data});
      writebackBypass.enq(WritebackData{dst:eInst.dst , data:eInst.data});

      // Send the branch resolution to fetch stage, irrespective of whether it's mispredicted or not
       // TBD: put code here that does what the comment immediately above says
      if(eInst.brTaken)
        execRedirect.enq(Redirect{nextPc: eInst.addr,mispredict:eInst.mispredict});
      // On a branch mispredict, change the epoch, to throw away wrong path instructions
       // TBD: put code here that does what the comment immediately above says
      if(eInst.brTaken && eInst.mispredict)
        eEpoch <= !eEpoch;
      
      cop.wr(eInst.dst, eInst.data);
    end
    else
    begin
      if(isValid(dInst.dst))
        scoreboard.remove;
    end
    ireg.deq();
  endrule
  
  rule doWriteBack;
    let dst = wreg.first.dst;
    let data = wreg.first.data;
    if (isValid(dst) && validValue(dst).regType == Normal)
      rf.wr(validRegValue(dst), data);
    if (isValid(dst))
      scoreboard.remove;
    wreg.deq();
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

