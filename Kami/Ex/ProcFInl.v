Require Import Bool String List.
Require Import Kami.Syntax Kami.Semantics Kami.RefinementFacts Kami.Renaming Kami.Wf.
Require Import Kami.Inline Kami.InlineFacts Kami.Tactics.
Require Import Ex.SC Ex.MemTypes Ex.ProcFetch.

Set Implicit Arguments.

Section Inlined.
  Variables addrSize iaddrSize instBytes dataBytes rfIdx: nat.

  Variable (fetch: AbsFetch addrSize iaddrSize instBytes dataBytes).

  Variable (f2dElt: Kind).
  Variable (f2dPack:
              forall ty,
                Expr ty (SyntaxKind (Data instBytes)) -> (* rawInst *)
                Expr ty (SyntaxKind (Pc iaddrSize)) -> (* curPc *)
                Expr ty (SyntaxKind (Pc iaddrSize)) -> (* nextPc *)
                Expr ty (SyntaxKind Bool) -> (* epoch *)
                Expr ty (SyntaxKind f2dElt)).
  Variables
    (f2dRawInst: forall ty, fullType ty (SyntaxKind f2dElt) ->
                            Expr ty (SyntaxKind (Data instBytes)))
    (f2dCurPc: forall ty, fullType ty (SyntaxKind f2dElt) ->
                          Expr ty (SyntaxKind (Pc iaddrSize)))
    (f2dNextPc: forall ty, fullType ty (SyntaxKind f2dElt) ->
                           Expr ty (SyntaxKind (Pc iaddrSize)))
    (f2dEpoch: forall ty, fullType ty (SyntaxKind f2dElt) ->
                          Expr ty (SyntaxKind Bool)).

  Context {indexSize tagSize: nat}.
  Variables (getIndex: forall ty, fullType ty (SyntaxKind (Bit iaddrSize)) ->
                                  Expr ty (SyntaxKind (Bit indexSize)))
            (getTag: forall ty, fullType ty (SyntaxKind (Bit iaddrSize)) ->
                                Expr ty (SyntaxKind (Bit tagSize))).

  Variables (pcInit : ConstT (Pc iaddrSize)).

  Definition fetchICache :=
    fetchICache fetch f2dPack getIndex getTag pcInit.
  Hint Unfold fetchICache: ModuleDefs. (* for kinline_compute *)

  Definition fetchICacheInl: sigT (fun m: Modules => fetchICache <<== m).
  Proof.
    kinline_refine fetchICache.
  Defined.

End Inlined.
