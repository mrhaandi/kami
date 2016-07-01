Require Import Arith.Peano_dec Bool String List.
Require Import Lib.CommonTactics Lib.ilist Lib.Word Lib.Struct.
Require Import Lib.FMap Lib.Indexer Lib.StringBound.
Require Import Syntax Semantics Notations SemFacts Equiv Refinement Tactics.
Require Import DecompositionOne DecompositionInv.
Require Import Ex.Fifo Ex.NativeFifo.

Set Implicit Arguments.

Section Facts.
  Variable fifoName: string.
  Variable sz: nat.
  Variable dType: Kind.
  Variable default: ConstT dType.

  Definition rsz := S sz.
  Hint Unfold rsz: MethDefs.

  Definition sfifo := simpleFifo fifoName rsz dType.
  Definition nsfifo := @nativeSimpleFifo fifoName dType default.
  Hint Unfold sfifo nsfifo: ModuleDefs.

  Notation "^ s" := (fifoName -- s) (at level 0).

  Fixpoint sfifo_nsfifo_elt_not_full
           (eltv : word rsz -> type dType)
           (enqPv : word rsz)
           (edSub : nat): list (type dType) :=
    match edSub with
    | O => nil
    | S ed =>
      (eltv (enqPv ^- (natToWord rsz edSub)))
        :: (sfifo_nsfifo_elt_not_full eltv enqPv ed)
    end.

  Lemma sfifo_nsfifo_elt_not_full_prop_1:
    forall eltv x, sfifo_nsfifo_elt_not_full eltv (x ^+ $1) 1 = [eltv x].
  Proof.
    intros; simpl; repeat f_equal.
    rewrite wminus_def, <-wplus_assoc, wminus_inv, wplus_comm.
    apply wplus_unit.
  Qed.

  Lemma sfifo_nsfifo_elt_not_full_prop_2:
    forall eltv enqPv edSub,
      edSub <> O ->
      exists tfifo,
        sfifo_nsfifo_elt_not_full eltv enqPv edSub = (eltv (enqPv ^- $ edSub)) :: tfifo.
  Proof.
    intros; destruct edSub; [elim H; auto|].
    eexists; reflexivity.
  Qed.

  Lemma sfifo_nsfifo_elt_not_full_enq:
    forall eltv enqPv elt edSub,
      (edSub <= wordToNat (wones rsz))%nat -> 
      sfifo_nsfifo_elt_not_full eltv enqPv edSub ++ [elt] =
      sfifo_nsfifo_elt_not_full (fun w => if weq w enqPv then elt else eltv w)
                              (enqPv ^+ $1) (S edSub).
  Proof.
    induction edSub; intros.
    - simpl; f_equal.
      destruct (weq _ _); auto.
      elim n; clear n.
      rewrite wminus_def, <-wplus_assoc, wminus_inv.
      rewrite wplus_comm, wplus_unit.
      reflexivity.
    - unfold sfifo_nsfifo_elt_not_full in *.
      fold sfifo_nsfifo_elt_not_full in *.
      rewrite <-IHedSub by omega; clear IHedSub.
      unfold app; f_equal.
      destruct (weq _ _).
      + exfalso.
        rewrite natToWord_S with (n:= S edSub) in e.
        rewrite wminus_plus_distr in e.
        rewrite !wminus_def in e.
        rewrite <-wplus_assoc with (x:= enqPv) in e.
        rewrite wminus_inv in e.
        rewrite wplus_comm with (x:= enqPv), wplus_unit in e.
        rewrite wplus_comm in e.
        rewrite <-wplus_unit with (x:= enqPv) in e at 2.
        apply wplus_cancel in e.
        apply wneg_zero in e.
        apply natToWord_inj in e.
        * inv e.
        * pose proof (wordToNat_bound (wones rsz)); omega.
        * apply pow2_zero.
      + f_equal.
        do 2 rewrite wminus_def.
        rewrite <-wplus_assoc.
        f_equal.
        rewrite natToWord_S with (n:= S edSub).
        apply wplus_cancel with (c:= $1 ^+ $ (S edSub)).
        rewrite <-wplus_assoc, wplus_comm with (x:= ^~ ($1 ^+ $ (S edSub))).
        rewrite wminus_inv.
        rewrite wplus_comm with (x:= ^~ $ (S edSub)).
        rewrite <-wplus_assoc, wminus_inv.
        reflexivity.
  Qed.

  Lemma sfifo_nsfifo_elt_not_full_deq:
    forall eltv enqPv edSub,
      match sfifo_nsfifo_elt_not_full eltv enqPv edSub with
      | nil => nil
      | _ :: t => t
      end = 
      sfifo_nsfifo_elt_not_full eltv enqPv (pred edSub).
  Proof.
    induction edSub; reflexivity.
  Qed.

  Definition sfifo_nsfifo_eta (r: RegsT): option (sigT (fullType type)).
  Proof.
    kgetv ^"elt"%string eltv r (Vector dType rsz) (None (A:= sigT (fullType type))).
    kgetv ^"empty"%string emptyv r Bool (None (A:= sigT (fullType type))).
    kgetv ^"full"%string fullv r Bool (None (A:= sigT (fullType type))).
    kgetv ^"enqP"%string enqPv r (Bit rsz) (None (A:= sigT (fullType type))).
    kgetv ^"deqP"%string deqPv r (Bit rsz) (None (A:= sigT (fullType type))).

    refine (Some (existT _ (listEltK dType type) _)).
    destruct (weq enqPv deqPv).
    - refine (if fullv then _ else _).
      + exact ((eltv deqPv) :: (sfifo_nsfifo_elt_not_full eltv enqPv (wordToNat (wones rsz)))).
      + exact nil.
    - exact (sfifo_nsfifo_elt_not_full eltv enqPv (wordToNat (enqPv ^- deqPv))).
  Defined.
  Hint Unfold sfifo_nsfifo_eta: MethDefs.

  Definition sfifo_nsfifo_theta (r: RegsT): RegsT :=
    match sfifo_nsfifo_eta r with
    | Some er => M.add ^"elt" er (M.empty _)
    | None => M.empty _
    end.
  Hint Unfold sfifo_nsfifo_theta: MethDefs.
  
  Definition sfifo_nsfifo_ruleMap (_: RegsT) (r: string): option string := Some r.
  Hint Unfold sfifo_nsfifo_ruleMap: MethDefs.

  Lemma sfifo_substeps_updates:
    forall (o : RegsT) (u1 u2 : UpdatesT) (ul1 ul2 : UnitLabel)
           (cs1 cs2 : MethsT),
      Substep sfifo o u1 ul1 cs1 ->
      Substep sfifo o u2 ul2 cs2 ->
      CanCombineUL u1 u2 (getLabel ul1 cs1) (getLabel ul2 cs2) ->
      u1 = M.empty (sigT (fullType type)) \/
      u2 = M.empty (sigT (fullType type)).
  Proof. (* SKIP_PROOF_ON 
    intros.
    inv H; inv H0; auto; try inv HInRules.
    CommonTactics.dest_in; simpl in *; invertActionRep.
    - exfalso.
      inv H1; inv H19; simpl in *.
      clear -H1; findeq.
    - exfalso.
      inv H1; simpl in *.
      clear -H17; findeq.
    - exfalso.
      inv H1; simpl in *.
      clear -H17; findeq.
    - exfalso.
      inv H1; inv H17; simpl in *.
      clear -H1; findeq.
      END_SKIP_PROOF_ON *) admit.
  Qed.

  Definition sfifo_inv_0 (o: RegsT): Prop.
  Proof.
    kexistv ^"elt"%string eltv o (Vector dType rsz).
    kexistv ^"empty"%string emptyv o Bool.
    kexistv ^"full"%string fullv o Bool.
    kexistv ^"enqP"%string enqPv o (Bit rsz).
    kexistv ^"deqP"%string deqPv o (Bit rsz).
    exact True.
  Defined.
  Hint Unfold sfifo_inv_0: InvDefs.

  Lemma sfifo_inv_0_ok:
    forall o, reachable o sfifo -> sfifo_inv_0 o.
  Proof. (* SKIP_PROOF_ON
    apply decompositionInv.
    - simpl; kinv_magic.
    - intros; inv H0; inv HInRules.
    - intros; inv H0; CommonTactics.dest_in.
      + kinv_magic.
      + kinv_magic.
    - apply sfifo_substeps_updates.
      END_SKIP_PROOF_ON *) admit.
  Qed.

  Definition sfifo_inv_1 (o: RegsT): Prop.
  Proof.
    kexistv ^"empty"%string emptyv o Bool.
    kexistv ^"full"%string fullv o Bool.
    kexistv ^"enqP"%string enqPv o (Bit rsz).
    kexistv ^"deqP"%string deqPv o (Bit rsz).
    refine (or3 _ _ _).
    - exact (v = true /\ v0 = false /\ (if weq v1 v2 then true else false) = true).
    - exact (v = false /\ v0 = true /\ (if weq v1 v2 then true else false) = true).
    - exact (v = false /\ v0 = false /\ (if weq v1 v2 then true else false) = false).
  Defined.
  Hint Unfold sfifo_inv_1: InvDefs.

  Lemma sfifo_inv_1_ok:
    forall o,
      reachable o sfifo ->
      sfifo_inv_1 o.
  Proof. (* SKIP_PROOF_ON
    apply decompositionInv.
    - simpl; kinv_magic; or3_fst; auto.
    - intros; inv H0; inv HInRules.
    - intros; inv H0; CommonTactics.dest_in.
      + simpl in *; kinv_magic_with kinv_or3.
        * or3_thd; repeat split.
          { destruct (weq _ _); auto.
            exfalso; eapply wplus_one_neq; eauto.
          }
          { destruct (weq _ _); auto.
            exfalso; eapply wplus_one_neq; eauto.
          }
        * destruct (weq x6 (x5 ^+ $0~1)).
          { or3_snd; repeat split.
            destruct (weq _ _); auto.
          }
          { or3_thd; repeat split.
            destruct (weq _ _); auto.
            elim n0; auto.
          }
      + simpl in *; kinv_magic_with kinv_or3.
        * or3_thd; repeat split.
          { destruct (weq _ _); auto.
            exfalso; eapply wplus_one_neq; eauto.
          }
          { destruct (weq _ _); auto.
            exfalso; eapply wplus_one_neq; eauto.
          }
        * destruct (weq x5 (x6 ^+ $0~1)).
          { or3_fst; auto. }
          { or3_thd; auto. }
    - apply sfifo_substeps_updates.
      END_SKIP_PROOF_ON *) admit.
  Qed.

  Lemma sfifo_refines_nsfifo: sfifo <<== nsfifo.
  Proof. (* SKIP_PROOF_ON
    apply decompositionOne with (eta:= sfifo_nsfifo_eta)
                                  (ruleMap:= sfifo_nsfifo_ruleMap)
                                  (specRegName:= ^"elt").

    - kequiv.
    - unfold theta; kdecompose_regmap_init; kinv_finish.
    - auto.
    - auto.
    - intros; inv H0; inv HInRules.
    - intros; inv H0.

      pose proof (sfifo_inv_0_ok H).
      pose proof (sfifo_inv_1_ok H).
      CommonTactics.dest_in; simpl in *; invertActionRep.

      + kinv_red.
        eexists; split.
        * eapply SingleMeth.
          { left; reflexivity. }
          { instantiate (3:= argV).
            simpl; repeat econstructor.
            kregmap_red; kregmap_clear; reflexivity.
            findeq.
          }
          { reflexivity. }

        * kinv_red.
          repeat split.
          { intros; inv H1. }
          { intros; inv H1. }
          { kregmap_red; kregmap_clear; meq.
            { repeat f_equal.
              destruct (weq (x2 ^+ _) x2); [exfalso; eapply wplus_one_neq; eauto|].
              simpl; replace (wordToNat _) with 1.
              { rewrite sfifo_nsfifo_elt_not_full_prop_1.
                destruct (weq x2 x2); intuition idtac.
              }
              { rewrite wminus_def, <-wplus_assoc.
                rewrite wplus_comm with (x:= $0~1), wplus_assoc.
                rewrite wminus_inv, wplus_unit.
                simpl; rewrite roundTrip_0; reflexivity.
              }
            }
            { repeat f_equal.
              destruct (weq (x1 ^+ _) x1); [elim n; auto|].
              unfold evalExpr.
              rewrite sfifo_nsfifo_elt_not_full_enq.
              { unfold sfifo_nsfifo_elt_not_full.
                fold sfifo_nsfifo_elt_not_full.
                repeat f_equal.
                { unfold rsz in *; clear n e n0.
                  destruct (weq _ _); [|clear n].
                  { exfalso.
                    rewrite natToWord_S with (n:= wordToNat _) in e.
                    rewrite !wminus_plus_distr in e.
                    rewrite !wminus_def in e.
                    rewrite <-wplus_assoc with (x:= x1) in e.
                    rewrite !wminus_inv in e.
                    rewrite wplus_comm with (x:= x1) in e.
                    rewrite !wplus_unit in e.
                    rewrite wplus_comm in e.
                    rewrite <-wplus_unit in e.
                    apply wplus_cancel in e.
                    apply wneg_zero in e.
                    rewrite natToWord_wordToNat in e.
                    apply wneg_zero in e.
                    inv e.
                  }
                  { f_equal.
                    rewrite wminus_plus_distr.
                    rewrite !wminus_def.
                    rewrite wminus_inv, wplus_unit.
                    rewrite <-wplus_assoc; f_equal.
                    rewrite natToWord_S with (n:= wordToNat _).
                    rewrite <-wminus_def.
                    rewrite wminus_plus_distr.
                    rewrite !wminus_def.
                    rewrite wminus_inv, wplus_unit.
                    rewrite natToWord_wordToNat.
                    rewrite wneg_idempotent.
                    reflexivity.
                  }
                }
                { rewrite wones_wneg_one.
                  apply wplus_cancel with (c:= x1 ^+ $0~1).
                  rewrite wminus_def, <-wplus_assoc.
                  rewrite wplus_comm with (y:= x1 ^+ $0~1).
                  rewrite wminus_inv.
                  rewrite wplus_comm with (x:= ^~ $1), <-wplus_assoc.
                  rewrite wminus_inv.
                  reflexivity.
                }
              }
              { replace (x1 ^- (x1 ^+ $0~1)) with (wones rsz).
                { apply Le.le_refl. }
                { rewrite wones_wneg_one.
                  apply wplus_cancel with (c:= x1 ^+ $0~1).
                  rewrite wplus_comm, <-wplus_assoc, wminus_inv.
                  rewrite wminus_def, <-wplus_assoc.
                  rewrite wplus_comm with (y:= x1 ^+ $0~1).
                  rewrite wminus_inv.
                  reflexivity.
                }
              }
            }
            { repeat f_equal; simpl.
              rewrite sfifo_nsfifo_elt_not_full_enq.
              { repeat f_equal.
                apply natToWord_inj with (sz:= S sz).
                { rewrite natToWord_S.
                  rewrite !natToWord_wordToNat.
                  rewrite !wminus_def.
                  rewrite wplus_assoc, wplus_comm with (x:= $1).
                  reflexivity.
                }
                { pose proof (wordToNat_bound (x1 ^- x2)).
                  remember (pow2 (S sz)) as pt; destruct pt.
                  { pose proof (pow2_zero (S sz)); omega. }
                  { apply Lt.lt_n_S.
                    assert (wordToNat (x1 ^- x2) <> pt).
                    { replace pt with (pow2 (S sz) - 1) by omega.
                      intro Hx.
                      apply pow2_minus_one_wones in Hx.
                      elim n0.
                      apply wplus_cancel with (c:= ^~ $0~1).
                      rewrite <-wplus_assoc, wminus_inv.
                      rewrite wplus_comm, wplus_unit.
                      rewrite wplus_comm.
                      apply wplus_cancel with (c:= ^~ x2).
                      rewrite <-wplus_assoc, wminus_inv.
                      rewrite wplus_comm with (y:= wzero _), wplus_unit.
                      rewrite <-wminus_def; rewrite Hx.
                      rewrite wones_wneg_one.
                      reflexivity.
                    }
                    omega.
                  }
                }
                { apply wordToNat_bound. }
              }
              { rewrite wones_pow2_minus_one.
                apply Lt.lt_n_Sm_le.
                pose proof (wordToNat_bound (x1 ^- x2)).
                unfold rsz in *; omega.
              }
            }
          }

      + kinv_red.
        destruct H13 as [|[|]]; dest; subst; [inv H1| |].
        * eexists; split.
          { unfold rsz in *.
            destruct (weq x1 x2); [|inv H3]; subst.
            eapply SingleMeth.
            { right; left; reflexivity. }
            { instantiate (3:= argV).
              repeat econstructor.
              { kregmap_red; kregmap_clear; reflexivity. }
              { destruct (weq x2 x2); [|elim n; reflexivity].
                reflexivity.
              }
              { findeq. }
            }
            { destruct (weq x2 x2); [|elim n; reflexivity].
              reflexivity.
            }
          }
          { repeat split.
            { intros; inv H2. }
            { intros; inv H2. }
            { kregmap_red; kregmap_clear; meq.
              destruct (weq x2 (x2 ^+ _)); [exfalso; eapply wplus_one_neq; eauto|].
              replace (x2 ^- (x2 ^+ $0~1)) with (wones (S sz)); auto.
              apply wplus_cancel with (c:= x2 ^+ $0~1).
              rewrite wminus_def, <-wplus_assoc.
              rewrite wplus_comm with (x:= ^~ (x2 ^+ _)).
              rewrite wminus_inv, wplus_comm with (y:= $0~1).
              rewrite wplus_assoc.
              replace ((natToWord sz 0)~1) with (natToWord rsz 1) by reflexivity.
              rewrite wones_wneg_one.
              rewrite wplus_comm with (y:= $1), wminus_inv.
              apply wplus_comm.
            }
          }
          
        * eexists; split.
          { unfold rsz in *.
            destruct (weq x1 x2); [inv H3|].
            eapply SingleMeth.
            { right; left; reflexivity. }
            { instantiate (3:= argV).
              repeat econstructor.
              { kregmap_red; kregmap_clear; reflexivity. }
              { destruct (weq x1 x2); [elim n; auto|].
                pose proof (@sfifo_nsfifo_elt_not_full_prop_2 x0 x1 (wordToNat (x1 ^- x2))).
                assert (wordToNat (x1 ^- x2) <> 0).
                { intro Hx.
                  assert ($ (wordToNat (x1 ^- x2)) = natToWord rsz 0)
                    by (rewrite Hx; reflexivity).
                  rewrite natToWord_wordToNat in H4.
                  apply sub_0_eq in H4.
                  elim n; auto.
                }
                specialize (H2 H4); clear H4; dest.
                rewrite H2; reflexivity.
              }
              { findeq. }
            }
            { destruct (weq x1 x2); [elim n; auto|].
              simpl; repeat f_equal.
              pose proof (@sfifo_nsfifo_elt_not_full_prop_2 x0 x1 (wordToNat (x1 ^- x2))).
              assert (wordToNat (x1 ^- x2) <> 0).
              { intro Hx.
                assert ($ (wordToNat (x1 ^- x2)) = natToWord rsz 0)
                  by (rewrite Hx; reflexivity).
                rewrite natToWord_wordToNat in H4.
                apply sub_0_eq in H4.
                elim n; auto.
              }
              specialize (H2 H4); clear H4; dest.
              rewrite H2; unfold listFirstElt, evalExpr; f_equal.

              rewrite natToWord_wordToNat.
              apply wplus_cancel with (c:= x1 ^- x2).
              rewrite wminus_def with (y:= x1 ^- x2), <-wplus_assoc.
              rewrite wplus_comm with (x:= ^~ (x1 ^- x2)).
              rewrite wminus_inv, wminus_def, wplus_comm with (y:= ^~ x2).
              rewrite wplus_assoc, wminus_inv.
              apply wplus_comm.
            }
          }
          { repeat split.
            { intros; inv H2. }
            { intros; inv H2. }
            { kregmap_red; kregmap_clear; meq.
              { simpl; repeat f_equal.
                replace (wordToNat _) with 1.
                { rewrite sfifo_nsfifo_elt_not_full_prop_1; reflexivity. }
                { rewrite wminus_def, <-wplus_assoc, wplus_comm.
                  rewrite <-wplus_assoc, wplus_comm with (y:= x2), wminus_inv.
                  rewrite wplus_comm, wplus_unit.
                  rewrite roundTrip_1; auto.
                }
              }
              { simpl; repeat f_equal.
                rewrite sfifo_nsfifo_elt_not_full_deq.
                f_equal; rewrite wordToNat_natToWord_pred.
                { f_equal.
                  rewrite wminus_plus_distr; reflexivity.
                }
                { intro Hx; apply sub_0_eq in Hx; auto. }
              }
            }
          }

    - intros; subst.
      inv H0; inv H1; inv H3; inv H4.
      + simpl in *; inv H2; inv H1; dest; repeat split; unfold getLabel; simpl; auto.
      + simpl in *; inv H2; inv H1; dest; repeat split; unfold getLabel; simpl; auto.
      + simpl in *; inv H2; inv H1; dest; repeat split; unfold getLabel; simpl; auto.
      + simpl in *; inv H2; inv H1; dest; repeat split; unfold getLabel; simpl; auto.
      + simpl in *; inv H2; inv H1; dest; repeat split; unfold getLabel; simpl; auto.
      + simpl in *; inv H2; inv H1; dest; repeat split; unfold getLabel; simpl; auto.
      + simpl in *; inv H2; inv H1; dest; repeat split; unfold getLabel; simpl; auto.
      + simpl in *; inv H2; inv H1; dest; repeat split; unfold getLabel; simpl; auto.
      + simpl in *; inv H2; inv H1; dest; repeat split; unfold getLabel; simpl; auto.
      + simpl in *; inv H2; inv H1; dest; repeat split; unfold getLabel; simpl; auto.
      + simpl in *; inv H2; inv H1; dest; repeat split; unfold getLabel; simpl; auto.
      + simpl in *; inv H2; inv H1; dest; repeat split; unfold getLabel; simpl; auto.
      + simpl in *; inv H2; inv H1; dest; repeat split; unfold getLabel; simpl; auto.
      + simpl in *; inv H2; inv H1; dest; repeat split; unfold getLabel; simpl; auto.
      + simpl in *; inv H2; inv H1; dest; repeat split; unfold getLabel; simpl; auto.
      + CommonTactics.dest_in; try discriminate; simpl in *.

        * exfalso; inv H2; inv H1; dest; simpl in *; findeq.
        * exfalso; clear HAction1 HAction2 Hsig Hsig0.
          invertActionRep; inv H2; findeq.
        * exfalso; clear HAction1 HAction2 Hsig Hsig0.
          invertActionRep; inv H2; findeq.
        * exfalso; inv H2; inv H1; dest; simpl in *; findeq.
          END_SKIP_PROOF_ON *) admit.
  Qed.

End Facts.

