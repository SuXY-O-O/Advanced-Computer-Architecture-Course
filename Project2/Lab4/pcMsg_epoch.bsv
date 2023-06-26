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
// add for lab4
import Scoreboard::*;

// change for lab4
// typedef struct {
//   Addr pc;
//   Addr ppc;
//   Data inst;
//   Bool epoch;
// } Fetch2Execute deriving (Bits, Eq);

// add for lab4
typedef struct {
  Addr pc;
  Addr ppc;
  Data inst;
  Bool epoch;
  Data d1;
  Data d2;
  DecodedInst decodedInst;
} Fetch2Execute deriving (Bits, Eq);

// add for lab4
typedef struct {
  Addr pc;
  Data inst;
  Maybe#(FullIndx) dst;
  Data data;
} Execute2Writeback deriving (Bits, Eq);

// add for lab4
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

  // change for lab4
  Fifo#(2, Fetch2Execute) ir <- mkPipelineFifo;
  Fifo#(2, Execute2Writeback) wreg <- mkPipelineFifo;
  // Fifo#(2, Fetch2Execute) ir <- mkCFFifo;
  Fifo#(1, Redirect) execRedirect <- mkBypassFifo;
  Fifo#(1, WritebackData) writebackBypass <- mkBypassFifo;
  //Fifo#(2, Redirect)   execRedirect <- mkCFFifo;

  // add for lab4
  Scoreboard#(2) scoreBoard <- mkCFScoreboard;

  //This design uses two epoch registers, one for each stage of the pipeline. Execute sets the eEpoch and discards any instruction that doesn't match it. It passes the information about change of epoch to fetch stage indirectly by passing a valid execRedirect using a Fifo. Fetch changes fEpoch everytime it gets a execRedirect and tags every instruction with its epoch

  Reg#(Bool) fEpoch <- mkReg(False);
  Reg#(Bool) eEpoch <- mkReg(False);

  rule doFetch(cop.started);
    let inst = iMem.req(pc);

    $display("Fetch: pc: %h inst: (%h) expanded: ", pc, inst, showInst(inst));

    // add for lab4
    // let dInst = decode(inst);
    // let flag1 = scoreBoard.search2(dInst.src1);
    // let flag2 = scoreBoard.search2(dInst.src2);

    // dequeue the incoming redirect and update the predictor whether it's a mispredict or not
    if(execRedirect.notEmpty)
    begin
      execRedirect.deq;
      pcPred.update(execRedirect.first);
    end
    // change pc and the fetch's copy of the epoch only on a mispredict
    if(execRedirect.notEmpty && execRedirect.first.mispredict)
    begin
      fEpoch <= !fEpoch;
      pc <= execRedirect.first.nextPc;
    end
    // fetch the new instruction on a non mispredict
    else
    begin
      // change for lab4, decode and read register
      // let ppc = pcPred.predPc(pc);
      // pc <= ppc;
      // ir.enq(Fetch2Execute{pc: pc, ppc: ppc, inst: inst, epoch: fEpoch});
      let decodedInst = decode(inst);
      Bool dataConflict = False;
      Data rVal1 = ?;
      Data rVal2 = ?;
      // read src1 from regs or bypass
      if (scoreBoard.search1(decodedInst.src1))
      begin
        if (writebackBypass.notEmpty 
          && isValid(writebackBypass.first.dst) 
          && validRegValue(writebackBypass.first.dst) == validRegValue(decodedInst.src1))
        begin
          rVal1 = writebackBypass.first.data;
        end
        else 
        begin
          dataConflict = True;
        end
      end
      else 
      begin
        rVal1 = rf.rd1(validRegValue(decodedInst.src1));
      end
      // read src2 from regs or bypass
      if (scoreBoard.search2(decodedInst.src2))
      begin
        if (writebackBypass.notEmpty 
          && isValid(writebackBypass.first.dst) 
          && validRegValue(writebackBypass.first.dst) == validRegValue(decodedInst.src2))
        begin
          rVal2 = writebackBypass.first.data;
        end
        else 
        begin
          dataConflict = True;
        end
      end
      else 
      begin
        rVal2 = rf.rd2(validRegValue(decodedInst.src2));
      end
      // clear writeback bypass
      writebackBypass.deq();
      // if read all success, fire it
      if (!dataConflict)
      begin
        let ppc = pcPred.predPc(pc);
        pc <= ppc;
        ir.enq(Fetch2Execute{pc:pc , ppc:ppc , inst:inst , epoch:fEpoch , d1:rVal1 , d2:rVal2 , decodedInst:decodedInst});
        scoreBoard.insert(decodedInst.dst);
      end
      // if ((!flag1) && (!flag2))
      // begin
      //   let ppc = pcPred.predPc(pc);
      //   pc <= ppc;
      //   let rVal1 = rf.rd1(validRegValue(dInst.src1));
      //   let rVal2 = rf.rd2(validRegValue(dInst.src2));
      //   ir.enq(Fetch2Execute{pc:pc , ppc:ppc , inst:inst , epoch:fEpoch , decodedInst:dInst , d1:rVal1 , d2: rVal2});
      //   scoreBoard.insert(dInst.dst);
      // end
    end
  endrule

  rule doExecute;
    let inst  = ir.first.inst;
    let pc    = ir.first.pc;
    let ppc   = ir.first.ppc;
    let epoch = ir.first.epoch;

    // Proceed only if the epochs match
    if(epoch == eEpoch)
    begin
      $display("Execute: pc: %h inst: (%h) expanded: ", pc, inst, showInst(inst));
  
      // change for lab4
      // let dInst = decode(inst);
      // let rVal1 = rf.rd1(validRegValue(dInst.src1));
      // let rVal2 = rf.rd2(validRegValue(dInst.src2)); 
      let dInst = ir.first.decodedInst;
      let rVal1 = ir.first.d1;
      let rVal2 = ir.first.d2;    
  
      let copVal = cop.rd(validRegValue(dInst.src1));
  
      let eInst = exec(dInst, rVal1, rVal2, pc, ppc, copVal);
  
      if(eInst.iType == Unsupported)
      begin
        $fwrite(stderr, "Executing unsupported instruction at pc: %x. Exiting\n", pc);
        $finish;
      end

      // memory
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

      // change for lab4, move to writeback
      // if (isValid(eInst.dst) && validValue(eInst.dst).regType == Normal)
      //   rf.wr(validRegValue(eInst.dst), eInst.data);
      wreg.enq(Execute2Writeback{pc:pc , inst:inst , dst:eInst.dst , data:eInst.data});
      writebackBypass.enq(WritebackData{dst:eInst.dst , data:eInst.data});

  
      // Send the branch resolution to fetch stage, irrespective of whether it's mispredicted or not
       // TBD: put code here that does what the comment immediately above says
      if (eInst.brTaken)
        execRedirect.enq(Redirect{nextPc: eInst.addr, mispredict: eInst.mispredict, brType: eInst.iType});
      // On a branch mispredict, change the epoch, to throw away wrong path instructions
       // TBD: put code here that does what the comment immediately above says
      if (eInst.brTaken && eInst.mispredict)
        eEpoch <= !eEpoch;
  
      cop.wr(eInst.dst, eInst.data);
    end
    // add for lab4
    else
    begin
      // clear scoreboard when mispredict
      scoreBoard.remove;
    end

    ir.deq;
  endrule

  // add for lab4
  rule doWriteback;
    if (isValid(wreg.first.dst) && validValue(wreg.first.dst).regType == Normal)
    begin
      rf.wr(validRegValue(wreg.first.dst), wreg.first.data);
      let pc = wreg.first.pc;
      let inst = wreg.first.inst;
      $display("WriteBack: pc: %h inst: (%h) expanded: ", pc, inst, showInst(inst));
    end
      
    wreg.deq();
    scoreBoard.remove;
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

//comments
// This code also works with either (or both) Fifo replaced with CFFifo
// If both Fifos are CFFifo, then fetch and execute are also conflict free
// If either Fifo is not CFFifo, then fetch and execute can be scheduled concurrently, with execute<fetch
// If BypassFifo is used for pc-redirect, then the processor is slightly faster
// This is by far the most robust solution as we will see later
