Require Import Bool String List.
Require Import Lib.CommonTactics Lib.ilist Lib.Word Lib.Indexer Lib.StringBound.
Require Import Lts.Syntax Lts.Notations Lts.Semantics Lts.Specialize Lts.Duplicate Lts.RefinementFacts.
Require Import Lts.Wf Lts.ParametricEquiv Lts.Tactics.
Require Import Ex.MemTypes Ex.SC Ex.Fifo.

Set Implicit Arguments.

Section Middleman.
  Variable inName outName: string.
  Variable addrSize lgDataBytes: nat.

  Definition RqFromProc := MemTypes.RqFromProc lgDataBytes (Bit addrSize).
  Definition RsToProc := MemTypes.RsToProc lgDataBytes.

  Definition getReq := MethodSig (inName -- "deq")() : RqFromProc.
  Definition setRep := MethodSig (outName -- "enq")(RsToProc) : Void.
  Definition exec := MethodSig "exec"(RqFromProc) : RsToProc.

  Definition processLd {ty} : ActionT ty Void :=
    (Call req <- getReq();
     Assert !#req@."op";
     Call rep <- exec(#req);
     Call setRep(#rep);
     Retv)%kami_action.

  Definition processSt {ty} : ActionT ty Void :=
    (Call req <- getReq();
     Assert #req@."op";
     Call rep <- exec(#req);
     Call setRep(#rep);
     Retv)%kami_action.

  Definition mid := MODULE {
    Rule "processLd" := processLd
    with Rule "processSt" := processSt
  }.

End Middleman.

Hint Unfold mid : ModuleDefs.
Hint Unfold RqFromProc RsToProc getReq setRep exec processLd processSt : MethDefs.

Section MemAtomic.
  Variables (addrSize fifoSize lgDataBytes: nat).

  Variable n: nat.

  Definition minst := memInst n addrSize lgDataBytes.

  Definition inQ := @simpleFifo "rqFromProc" fifoSize (RqFromProc addrSize lgDataBytes).
  Definition outQ := @simpleFifo "rsToProc" fifoSize (RsToProc lgDataBytes).
  Definition ioQ := ConcatMod inQ outQ.

  Definition ios (i: nat) := duplicate ioQ i.

  Definition midQ := mid "rqFromProc" "rsToProc" addrSize lgDataBytes.
  Definition mids (i: nat) := duplicate midQ i.
  
  Definition iom := ConcatMod ioQ midQ.
  Definition ioms (i: nat) := duplicate iom i.

  Definition memAtomicWoQ := ConcatMod (mids n) minst.
  Definition memAtomic := ConcatMod (ioms n) minst.

End MemAtomic.

Hint Unfold minst inQ outQ ioQ midQ mids iom ioms memAtomicWoQ memAtomic : ModuleDefs.

Section Facts.
  Variables (addrSize fifoSize lgDataBytes: nat).

  Lemma midQ_ModEquiv:
    forall ty1 ty2, ModEquiv ty1 ty2 (midQ addrSize lgDataBytes).
  Proof.
    kequiv.
  Qed.
  Hint Resolve midQ_ModEquiv.

  Lemma iom_ModEquiv:
    forall ty1 ty2, ModEquiv ty1 ty2 (iom addrSize fifoSize lgDataBytes).
  Proof.
    kequiv.
  Qed.
  Hint Resolve iom_ModEquiv.

  Variable n: nat.

  Lemma mids_ModEquiv:
    forall ty1 ty2, ModEquiv ty1 ty2 (mids addrSize lgDataBytes n).
  Proof.
    kequiv.
  Qed.
  Hint Resolve mids_ModEquiv.

  Lemma ioms_ModEquiv:
    forall ty1 ty2, ModEquiv ty1 ty2 (ioms addrSize fifoSize lgDataBytes n).
  Proof.
    kequiv.
  Qed.
  Hint Resolve ioms_ModEquiv.

  Lemma memAtomicWoQ_ModEquiv:
    forall ty1 ty2, ModEquiv ty1 ty2 (memAtomicWoQ addrSize lgDataBytes n).
  Proof.
    kequiv.
  Qed.

  Lemma memAtomic_ModEquiv:
    forall ty1 ty2, ModEquiv ty1 ty2 (memAtomic addrSize fifoSize lgDataBytes n).
  Proof.
    kequiv.
  Qed.

End Facts.

Hint Immediate midQ_ModEquiv iom_ModEquiv
     mids_ModEquiv ioms_ModEquiv memAtomicWoQ_ModEquiv memAtomic_ModEquiv.

Section MemAtomicWoQ.
  Variables (addrSize fifoSize lgDataBytes: nat).
  Variable n: nat.

  Lemma ios_memAtomicWoQ_memAtomic:
    ((ios addrSize fifoSize lgDataBytes n ++ memAtomicWoQ addrSize lgDataBytes n)%kami)
      <<== (memAtomic addrSize fifoSize lgDataBytes n).
  Proof.
    unfold memAtomic, memAtomicWoQ.
    krewrite assoc left.
    kmodular_sim_l.
    - apply duplicate_regs_ConcatMod; [kequiv|kequiv|kvr|kvr| |]; auto.
    - apply duplicate_rules_ConcatMod; [kequiv|kequiv|kvr|kvr| |]; auto.
    - apply duplicate_defs_ConcatMod; [kequiv|kequiv|kvr|kvr| |]; auto.
  Qed.

End MemAtomicWoQ.

