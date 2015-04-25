Require Import List.
Import ListNotations.
Require Import Omega.

Require Import VerdiTactics.
Require Import Util.
Require Import Net.

Require Import Raft.
Require Import CommonTheorems.
Require Import CommitRecordedCommittedInterface.
Require Import StateMachineSafetyInterface.
Require Import StateMachineSafetyPrimeInterface.
Require Import RaftRefinementInterface.
Require Import MaxIndexSanityInterface.
Require Import LeaderCompletenessInterface.
Require Import SortedInterface.
Require Import LogMatchingInterface.

Require Import RefinedLogMatchingLemmasInterface.

Require Import SpecLemmas.

Require Import UpdateLemmas.
Local Arguments update {_} {_} {_} _ _ _ _ : simpl never.

Section StateMachineSafetyProof.
  Context {orig_base_params : BaseParams}.
  Context {one_node_params : OneNodeParams orig_base_params}.
  Context {raft_params : RaftParams orig_base_params}.

  Context {rri : raft_refinement_interface}.
  Context {si : sorted_interface}.
  Context {lmi : log_matching_interface}.
  Context {smspi : state_machine_safety'interface}.
  Context {rlmli : refined_log_matching_lemmas_interface}.

  Lemma exists_deghost_packet :
    forall net p,
      In p (nwPackets (deghost net)) ->
      exists (q : packet (params := raft_refined_multi_params)),
        In q (nwPackets net) /\ p = deghost_packet q.
  Proof.
    intros.
    unfold deghost in *. simpl in *. do_in_map.
    subst. eexists; eauto.
  Qed.

  Lemma state_machine_safety_deghost :
    forall net,
      commit_recorded_committed net ->
      state_machine_safety' net ->
      state_machine_safety (deghost net).
  Proof.
    intros. unfold state_machine_safety in *. intuition.
    - unfold state_machine_safety_host. intros.
      do 2 eapply_prop_hyp commit_recorded_committed commit_recorded.
      unfold state_machine_safety' in *. intuition. eauto.
    - unfold state_machine_safety_nw. intros.
      eapply_prop_hyp commit_recorded_committed commit_recorded.
      unfold state_machine_safety', state_machine_safety_nw' in *. intuition.
      find_apply_lem_hyp exists_deghost_packet. break_exists.
      intuition. subst. simpl in *. repeat break_match. simpl in *.
      subst. eapply_prop_hyp In In; repeat find_rewrite; simpl; eauto.
  Qed.

  Definition lifted_maxIndex_sanity (net : network) : Prop :=
    (forall h,
      lastApplied (snd (nwState net h)) <= maxIndex (log (snd (nwState net h)))) /\
    (forall h, commitIndex (snd (nwState net h)) <= maxIndex (log (snd (nwState net h)))).

  Lemma lifted_maxIndex_sanity_init :
    refined_raft_net_invariant_init lifted_maxIndex_sanity.
  Proof.
    unfold refined_raft_net_invariant_init, lifted_maxIndex_sanity, maxIndex_lastApplied, maxIndex_commitIndex.
    intuition.
  Qed.

  Ltac update_destruct :=
    match goal with
      | [ H : context [ update _ ?x _ ?y ] |- _ ] =>
        destruct (name_eq_dec x y); subst; rewrite_update; simpl in *
      | [ |- context [ update _ ?x _ ?y ] ] =>
        destruct (name_eq_dec x y); subst; rewrite_update; simpl in *
    end.

  Lemma handleClientRequest_lastApplied :
    forall h st client id c out st' l,
      handleClientRequest h st client id c = (out, st', l) ->
      lastApplied st' = lastApplied st.
  Proof.
    unfold handleClientRequest.
    intros.
    repeat break_match; find_inversion; auto.
  Qed.

  Lemma handleClientRequest_maxIndex :
    forall h st client id c out st' l,
      handleClientRequest h st client id c = (out, st', l) ->
      sorted (log st') ->
      maxIndex (log st) <= maxIndex (log st').
  Proof.
    intros.
    destruct (log st') using (handleClientRequest_log_ind $(eauto)$).
    - auto.
    - simpl in *. break_and.
      destruct (log st); simpl in *.
      + omega.
      + find_insterU. conclude_using eauto. intuition.
  Qed.

  Lemma sorted_host_lifted :
    forall net h,
      refined_raft_intermediate_reachable net ->
      sorted (log (snd (nwState net h))).
  Proof.
    intros.
    pose proof (lift_prop _ logs_sorted_invariant).
    find_insterU. conclude_using eauto.
    unfold logs_sorted, logs_sorted_host in *. break_and.
    unfold deghost in *. simpl in *. break_match. eauto.
  Qed.

  Lemma lifted_maxIndex_sanity_client_request :
    refined_raft_net_invariant_client_request lifted_maxIndex_sanity.
  Proof.
    unfold refined_raft_net_invariant_client_request, lifted_maxIndex_sanity, maxIndex_lastApplied, maxIndex_commitIndex.
    intuition; simpl in *; repeat find_higher_order_rewrite; update_destruct; auto.
    - erewrite handleClientRequest_lastApplied by eauto.
      find_apply_lem_hyp handleClientRequest_maxIndex.
      + eauto with *.
      + match goal with H : _ |- _ => rewrite <- deghost_spec with (net0 := net) in H end.
        eapply handleClientRequest_logs_sorted; eauto.
        * auto using simulation_1.
        * apply logs_sorted_invariant. auto using simulation_1.
    - erewrite handleClientRequest_commitIndex by eauto.
      find_apply_lem_hyp handleClientRequest_maxIndex.
      + eauto with *.
      + match goal with H : _ |- _ => rewrite <- deghost_spec with (net0 := net) in H end.
        eapply handleClientRequest_logs_sorted; eauto using simulation_1.
        apply logs_sorted_invariant. auto using simulation_1.
  Qed.

  Lemma lifted_maxIndex_sanity_timeout :
    refined_raft_net_invariant_timeout lifted_maxIndex_sanity.
  Proof.
    unfold refined_raft_net_invariant_timeout, lifted_maxIndex_sanity, maxIndex_lastApplied, maxIndex_commitIndex.
    intuition; simpl in *; repeat find_higher_order_rewrite; update_destruct; auto;
    erewrite handleTimeout_log_same by eauto.
    - erewrite handleTimeout_lastApplied; eauto.
    - erewrite handleTimeout_commitIndex; eauto.
  Qed.

  Lemma handleAppendEntries_lastApplied :
    forall h st t n pli plt es ci st' m,
      handleAppendEntries h st t n pli plt es ci = (st', m) ->
      lastApplied st' = lastApplied st.
  Proof.
    unfold handleAppendEntries, advanceCurrentTerm;
    intros; repeat break_match; repeat find_inversion; simpl; auto.
  Qed.

  Lemma sorted_maxIndex_app :
    forall l1 l2,
      sorted (l1 ++ l2) ->
      maxIndex l2 <= maxIndex (l1 ++ l2).
  Proof.
    induction l1; intros; simpl in *; intuition.
    destruct l2; intuition. simpl in *.
    specialize (H0 e). conclude H0 intuition. intuition.
  Qed.

  Lemma max_min_thing:
    forall a b c,
      a <= c ->
      max a (min b c) <= c.
  Proof.
    intros.
    destruct (max a (min b c)) using (Max.max_case _ _); intuition.
  Qed.

  Lemma ghost_packet :
    forall (net : network (params := raft_refined_multi_params)) p,
      In p (nwPackets net) ->
      In (deghost_packet p) (nwPackets (deghost net)).
  Proof.
    unfold deghost.
    simpl. intuition.
    apply in_map_iff.
    eexists; eauto.
  Qed.

  Lemma pBody_deghost_packet :
    forall (p : packet (params := raft_refined_multi_params)),
      pBody (deghost_packet p) = pBody p.
  Proof.
    unfold deghost_packet.
    simpl. auto.
  Qed.

  Lemma pDst_deghost_packet :
    forall (p : packet (params := raft_refined_multi_params)),
      pDst (deghost_packet p) = pDst p.
  Proof.
    unfold deghost_packet.
    simpl. auto.
  Qed.

  Lemma lifted_handleAppendEntries_logs_sorted :
    forall net p t n pli plt es ci st' m,
      refined_raft_intermediate_reachable net ->
      handleAppendEntries (pDst p) (snd (nwState net (pDst p))) t n pli plt es ci = (st', m) ->
      pBody p = AppendEntries t n pli plt es ci ->
      In p (nwPackets net) ->
      sorted (log st').
  Proof.
    intros.
    eapply handleAppendEntries_logs_sorted with (net0 := deghost net) (p0 := deghost_packet p).
    - apply simulation_1. auto.
    - apply lift_prop.
      + apply logs_sorted_invariant.
      + auto.
    - rewrite pDst_deghost_packet.
      rewrite deghost_spec. eauto.
    - rewrite pBody_deghost_packet. auto.
    - apply ghost_packet. auto.
  Qed.

  Lemma contiguous_range_exact_lo_elim_exists :
    forall es lo i,
      contiguous_range_exact_lo es lo ->
      lo < i <= maxIndex es -> exists e, eIndex e = i /\ In e es.
  Proof.
    unfold contiguous_range_exact_lo.
    intuition.
  Qed.

  Lemma contiguous_range_exact_lo_elim_lt :
    forall es lo e,
      contiguous_range_exact_lo es lo ->
      In e es ->
      lo < eIndex e.
  Proof.
    unfold contiguous_range_exact_lo.
    intuition.
  Qed.


  Lemma lifted_sms_nw :
    forall (net : network (params := raft_refined_multi_params)) h p t leaderId prevLogIndex prevLogTerm entries leaderCommit e,
      state_machine_safety (deghost net) ->
      In p (nwPackets net) ->
      pBody p = AppendEntries t leaderId prevLogIndex prevLogTerm
                              entries leaderCommit ->
      t >= currentTerm (snd (nwState net h)) ->
      commit_recorded (deghost net) h e ->
      (prevLogIndex > eIndex e \/
       (prevLogIndex = eIndex e /\ prevLogTerm = eTerm e) \/
       eIndex e > maxIndex entries \/
       In e entries).
  Proof.
    unfold state_machine_safety, state_machine_safety_nw.
    intuition.
    match goal with
      | [ H : _ |- _ ] => eapply H with (p := deghost_packet p)
    end.
    - auto using ghost_packet.
    - rewrite pBody_deghost_packet. eauto.
    - rewrite deghost_spec. eauto.
    - auto.
  Qed.

  Lemma commit_recorded_lift_intro :
    forall (net : network (params := raft_refined_multi_params)) h e,
      In e (log (snd (nwState net h))) ->
      (eIndex e <= lastApplied (snd (nwState net h)) \/
       eIndex e <= commitIndex (snd (nwState net h))) ->
      commit_recorded (deghost net) h e.
  Proof.
    unfold commit_recorded.
    intros.
    rewrite deghost_spec.
    auto.
  Qed.

  Lemma lifted_maxIndex_sanity_append_entries :
    forall xs p ys net st' ps' gd d m t n pli plt es ci,
      handleAppendEntries (pDst p) (snd (nwState net (pDst p))) t n pli plt es ci = (d, m) ->
      gd = update_elections_data_appendEntries (pDst p) (nwState net (pDst p)) t n pli plt es ci ->
      pBody p = AppendEntries t n pli plt es ci ->
      lifted_maxIndex_sanity net ->
      state_machine_safety (deghost net) ->
      refined_raft_intermediate_reachable net ->
      nwPackets net = xs ++ p :: ys ->
      (forall h, st' h = update (nwState net) (pDst p) (gd, d) h) ->
      (forall p', In p' ps' -> In p' (xs ++ ys) \/
                         p' = mkPacket (pDst p) (pSrc p) m) ->
      lifted_maxIndex_sanity (mkNetwork ps' st').
  Proof.
    unfold lifted_maxIndex_sanity, maxIndex_lastApplied, maxIndex_commitIndex.
    intros.
    intuition; simpl in *; repeat find_higher_order_rewrite; update_destruct; auto.
    - erewrite handleAppendEntries_lastApplied by eauto.
      assert (sorted (log d)) by (eauto using lifted_handleAppendEntries_logs_sorted).
      match goal with
        | _ : handleAppendEntries ?h ?s ?t ?n ?pli ?plt ?es ?ci = (?s', ?m) |- _ =>
          pose proof handleAppendEntries_log_detailed
               h s t n pli plt es ci s' m
      end.
      intuition; repeat find_rewrite.
      + eauto.
      + subst.
        destruct (le_lt_dec (lastApplied (snd (nwState net (pDst p))))
                            (maxIndex (log d))); auto.
        exfalso.
        assert (In p (nwPackets net)) by (find_rewrite; intuition).
        assert (exists x, eIndex x = maxIndex (log d) /\ In x (log (snd (nwState net (pDst p))))).
        {
          eapply contiguous_range_exact_lo_elim_exists.
          - eapply entries_contiguous_invariant. auto.
          - split.
            + find_apply_lem_hyp maxIndex_non_empty. break_exists.  break_and.
              repeat find_rewrite.
              eapply contiguous_range_exact_lo_elim_lt.
              * eapply entries_contiguous_nw_invariant; eauto.
              * auto.
            + eapply le_trans; [|eauto]. simpl in *. omega.
        }
        break_exists. break_and.
        eapply findAtIndex_None; [|eauto| |]; eauto.
        apply entries_sorted_invariant; auto.
      + subst.
        destruct (le_lt_dec (lastApplied (snd (nwState net (pDst p))))
                            (maxIndex (log d))); auto.
        exfalso.
        assert (In p (nwPackets net)) by (find_rewrite; intuition).
        break_exists; intuition. find_apply_lem_hyp findAtIndex_elim; intuition.

        find_eapply_lem_hyp lifted_sms_nw; eauto;
        [|eapply commit_recorded_lift_intro; eauto;
        left; repeat find_rewrite; auto using lt_le_weak].
        intuition.
        * subst.
          assert (0 < eIndex x) by (eapply entries_contiguous_invariant; eauto).
          omega.
        * destruct (log d); intuition. simpl in *.
          intuition; subst; auto.
          find_apply_hyp_hyp. omega.
      + destruct (le_lt_dec (lastApplied (snd (nwState net (pDst p)))) pli); intuition;
        [eapply le_trans; [| apply sorted_maxIndex_app]; auto;
         break_exists; break_and;
         erewrite maxIndex_removeAfterIndex by (eauto; apply entries_sorted_invariant; auto);
         auto|]; [idtac].

        destruct (le_lt_dec (lastApplied (snd (nwState net (pDst p)))) (maxIndex es)); intuition;
        [match goal with
           | |- context [ maxIndex (?ll1 ++ ?ll2) ] =>
             pose proof maxIndex_app ll1 ll2
         end; simpl in *; intuition|]; [idtac].
        assert (exists x, eIndex x = maxIndex es /\ In x (log (snd (nwState net (pDst p))))).
        {
          eapply contiguous_range_exact_lo_elim_exists.
          - eapply entries_contiguous_invariant. auto.
          - split.
            + find_apply_lem_hyp maxIndex_non_empty. break_exists.  break_and.
              repeat find_rewrite.
              destruct es.
              * simpl in *. intuition.
              * simpl.  subst.
                { eapply le_lt_trans with (m := eIndex x).
                  - omega.
                  - eapply contiguous_range_exact_lo_elim_lt.
                    + eapply entries_contiguous_nw_invariant; eauto.
                    + intuition.
                }
            + eapply le_trans; [|eauto]. simpl in *. omega.
        }
        break_exists. intuition.
        match goal with
          | H : findAtIndex _ _ = None |- _ =>
            eapply findAtIndex_None with (x1 := x) in H
        end; eauto.
        * congruence.
        * apply entries_sorted_invariant. auto.
      +   destruct (le_lt_dec (lastApplied (snd (nwState net (pDst p)))) (maxIndex es)); intuition;
        [match goal with
           | |- context [ maxIndex (?ll1 ++ ?ll2) ] =>
             pose proof maxIndex_app ll1 ll2
         end; simpl in *; intuition|]; [idtac].
        exfalso.
        assert (In p (nwPackets net)) by (find_rewrite; intuition).
        break_exists; intuition. find_apply_lem_hyp findAtIndex_elim; intuition.
        find_copy_apply_lem_hyp maxIndex_non_empty.
        break_exists. intuition.

        find_eapply_lem_hyp lifted_sms_nw; eauto;
        [|eapply commit_recorded_lift_intro; eauto;
        left; repeat find_rewrite; auto using lt_le_weak].

        match goal with
          | _ : In ?x es, _ : maxIndex es = eIndex ?x |- _ =>
            assert (pli < eIndex x)
                   by ( eapply contiguous_range_exact_lo_elim_lt; eauto;
                        eapply entries_contiguous_nw_invariant; eauto)
        end.
        intuition.

        match goal with
          | H : _ = _ ++ _ |- _ => symmetry in H
        end.
        destruct es; intuition;
        simpl in *;
        intuition; subst_max; intuition;
        repeat clean;
        match goal with
          | _ : eIndex ?x' = eIndex ?x, H : context [eIndex ?x'] |- _ =>
            specialize (H x); conclude H ltac:(apply in_app_iff; auto)
          end; intuition.
    - assert (sorted (log d)) by (eauto using lifted_handleAppendEntries_logs_sorted).
      match goal with
        | _ : handleAppendEntries ?h ?s ?t ?n ?pli ?plt ?es ?ci = (?s', ?m) |- _ =>
          pose proof handleAppendEntries_log_detailed
               h s t n pli plt es ci s' m
      end.
      intuition; repeat find_rewrite; try apply max_min_thing;
      match goal with
        | H : context [ lastApplied _ ] |- _ => clear H
      end.
      + eauto.
      + subst.
        destruct (le_lt_dec (commitIndex (snd (nwState net (pDst p))))
                            (maxIndex (log d))); auto.
        exfalso.
        assert (In p (nwPackets net)) by (find_rewrite; intuition).
        assert (exists x, eIndex x = maxIndex (log d) /\ In x (log (snd (nwState net (pDst p))))).
        {
          eapply contiguous_range_exact_lo_elim_exists.
          - eapply entries_contiguous_invariant. auto.
          - split.
            + find_apply_lem_hyp maxIndex_non_empty. break_exists.  break_and.
              repeat find_rewrite.
              eapply contiguous_range_exact_lo_elim_lt.
              * eapply entries_contiguous_nw_invariant; eauto.
              * auto.
            + eapply le_trans; [|eauto]. simpl in *. omega.
        }
        break_exists. intuition.
        find_eapply_lem_hyp findAtIndex_None; eauto.
        apply entries_sorted_invariant. auto.
      + subst.
        destruct (le_lt_dec (commitIndex (snd (nwState net (pDst p))))
                            (maxIndex (log d))); auto.
        exfalso.
        assert (In p (nwPackets net)) by (find_rewrite; intuition).
        break_exists; intuition. find_apply_lem_hyp findAtIndex_elim; intuition.

        find_eapply_lem_hyp lifted_sms_nw; eauto;
        [|eapply commit_recorded_lift_intro; eauto;
        right; repeat find_rewrite; intuition].
        intuition.
        * subst.
          assert (0 < eIndex x) by (eapply entries_contiguous_invariant; eauto).
          omega.
        * destruct (log d); intuition. simpl in *.
          intuition; subst; auto.
          find_apply_hyp_hyp. omega.
      + destruct (le_lt_dec (commitIndex (snd (nwState net (pDst p)))) pli); intuition;
        [eapply le_trans; [| apply sorted_maxIndex_app]; auto;
         break_exists; intuition;
         erewrite maxIndex_removeAfterIndex; eauto; apply entries_sorted_invariant; auto|]; [idtac].
        destruct (le_lt_dec (commitIndex (snd (nwState net (pDst p)))) (maxIndex es)); intuition;
        [match goal with
           | |- context [ maxIndex (?ll1 ++ ?ll2) ] =>
             pose proof maxIndex_app ll1 ll2
         end; simpl in *; intuition|]; [idtac].
        assert (exists x, eIndex x = maxIndex es /\ In x (log (snd (nwState net (pDst p))))).
        {
          eapply contiguous_range_exact_lo_elim_exists.
          - eapply entries_contiguous_invariant. auto.
          - split.
            + find_apply_lem_hyp maxIndex_non_empty. break_exists.  break_and.
              repeat find_rewrite.
              destruct es.
              * simpl in *. intuition.
              * simpl.  subst.
                { eapply le_lt_trans with (m := eIndex x).
                  - omega.
                  - eapply contiguous_range_exact_lo_elim_lt.
                    + eapply entries_contiguous_nw_invariant; eauto.
                    + intuition.
                }
            + eapply le_trans; [|eauto]. simpl in *. omega.
        }
        break_exists. intuition.
        match goal with
          | H : findAtIndex _ _ = None |- _ =>
            eapply findAtIndex_None with (x1 := x) in H
        end; eauto.
        * congruence.
        * apply entries_sorted_invariant; auto.
      + destruct (le_lt_dec (commitIndex (snd (nwState net (pDst p)))) (maxIndex es)); intuition;
        [match goal with
           | |- context [ maxIndex (?ll1 ++ ?ll2) ] =>
             pose proof maxIndex_app ll1 ll2
         end; simpl in *; intuition|]; [idtac].
        exfalso.
        assert (In p (nwPackets net)) by (find_rewrite; intuition).
        break_exists; intuition. find_apply_lem_hyp findAtIndex_elim; intuition.
        find_copy_apply_lem_hyp maxIndex_non_empty.
        break_exists. intuition.

        find_eapply_lem_hyp lifted_sms_nw; eauto;
        [|eapply commit_recorded_lift_intro; eauto;
        right; repeat find_rewrite; intuition].
        match goal with
          | _ : In ?x es, _ : maxIndex es = eIndex ?x |- _ =>
            assert (pli < eIndex x)
              by (eapply contiguous_range_exact_lo_elim_lt; eauto;
                        eapply entries_contiguous_nw_invariant; eauto)
        end.

        intuition.
        * match goal with
            | H : _ = _ ++ _ |- _ => symmetry in H
          end.
          destruct es; intuition;
          simpl in *;
          intuition; subst_max; intuition;
          repeat clean;
          match goal with
            | _ : eIndex ?x' = eIndex ?x, H : context [eIndex ?x'] |- _ =>
              specialize (H x); conclude H ltac:(apply in_app_iff; auto)
          end; intuition.
  Qed.

  Lemma lifted_maxIndex_sanity_append_entries_reply :
    refined_raft_net_invariant_append_entries_reply lifted_maxIndex_sanity.
  Proof.
    unfold refined_raft_net_invariant_append_entries_reply,
           lifted_maxIndex_sanity, maxIndex_lastApplied, maxIndex_commitIndex.
    intuition; repeat find_higher_order_rewrite; update_destruct; auto.
    - erewrite handleAppendEntriesReply_same_lastApplied by eauto.
      erewrite handleAppendEntriesReply_same_log by eauto.
      auto.
    - erewrite handleAppendEntriesReply_same_commitIndex by eauto.
      erewrite handleAppendEntriesReply_same_log by eauto.
      auto.
  Qed.

  Lemma lifted_maxIndex_sanity_request_vote :
    refined_raft_net_invariant_request_vote lifted_maxIndex_sanity.
  Proof.
    unfold refined_raft_net_invariant_request_vote,
           lifted_maxIndex_sanity, maxIndex_lastApplied, maxIndex_commitIndex.
    intuition; repeat find_higher_order_rewrite; update_destruct; auto.
    - erewrite handleRequestVote_same_log by eauto.
      erewrite handleRequestVote_same_lastApplied by eauto.
      auto.
    - erewrite handleRequestVote_same_log by eauto.
      erewrite handleRequestVote_same_commitIndex by eauto.
      auto.
  Qed.

  Lemma lifted_maxIndex_sanity_request_vote_reply :
    refined_raft_net_invariant_request_vote_reply lifted_maxIndex_sanity.
  Proof.
    unfold refined_raft_net_invariant_request_vote_reply,
           lifted_maxIndex_sanity, maxIndex_lastApplied, maxIndex_commitIndex.
    intuition; repeat find_higher_order_rewrite; update_destruct; auto.
    - rewrite handleRequestVoteReply_same_log.
      rewrite handleRequestVoteReply_same_lastApplied.
      auto.
    - rewrite handleRequestVoteReply_same_log.
      rewrite handleRequestVoteReply_same_commitIndex.
      auto.
  Qed.

  Lemma doLeader_same_lastApplied :
    forall st n os st' ms,
      doLeader st n = (os, st', ms) ->
      lastApplied st' = lastApplied st.
  Proof.
    unfold doLeader.
    intros.
    repeat break_match; repeat find_inversion; auto.
  Qed.

  Lemma fold_left_maximum_le' :
    forall l x y,
      x <= y ->
      x <= fold_left max l y.
  Proof.
    induction l; intros.
    - auto.
    - simpl. apply IHl. apply Max.max_case_strong; omega.
  Qed.

  Lemma fold_left_maximum_le :
    forall l x,
      x <= fold_left max l x.
  Proof.
    intros. apply fold_left_maximum_le'.
    auto.
  Qed.

  Lemma fold_left_maxmimum_increase_init :
    forall l x y,
      fold_left max l x = x ->
      x <= y ->
      fold_left max l y = y.
  Proof.
    induction l; intros.
    - auto.
    - simpl in *. revert H.
      repeat (apply Max.max_case_strong; intros).
      + eauto.
      + assert (a = y) by omega. subst_max. eauto.
      + subst x. pose proof (fold_left_maximum_le l a).
        assert (fold_left max l a = a) by omega.
        eauto.
      + subst x.
        pose proof (fold_left_maximum_le l a).
        assert (fold_left max l a = a) by omega.
        assert (a = y) by omega.
        subst. auto.
  Qed.

  Lemma fold_left_maximum_cases :
    forall l x,
      fold_left max l x = x \/
      exists y,
        In y l /\ fold_left max l x = y.
  Proof.
    induction l; simpl.
    - auto.
    - intros.
      specialize (IHl (max x a)).
      intuition.
      + revert H.
        apply Max.max_case_strong; intuition.
        intuition eauto using fold_left_maxmimum_increase_init.
      + break_exists. break_and. eauto.
  Qed.

  Lemma fold_left_maximum_ind :
    forall l x (P : nat -> Prop),
      P x ->
      (forall y, In y l -> P y) ->
      P (fold_left max l x).
  Proof.
    intros.
    destruct (fold_left_maximum_cases l x).
    - find_rewrite. auto.
    - break_exists. break_and. find_rewrite. eauto.
  Qed.

  Lemma doLeader_same_commitIndex :
    forall st n os st' ms,
      doLeader st n = (os, st', ms) ->
      sorted (log st) ->
      commitIndex st <= maxIndex (log st) ->
      commitIndex st' <= maxIndex (log st').
  Proof.
    unfold doLeader.
    intros.
    repeat break_match; repeat find_inversion; simpl; auto;
    apply fold_left_maximum_ind; auto.
    - intros. do_in_map. find_apply_lem_hyp filter_In.
      subst. break_and.
      apply maxIndex_is_max; eauto using findGtIndex_in.
    - intros. do_in_map. find_apply_lem_hyp filter_In.
      break_and. subst.
      apply maxIndex_is_max; eauto using findGtIndex_in.
  Qed.

  Lemma lifted_maxIndex_sanity_do_leader :
    refined_raft_net_invariant_do_leader lifted_maxIndex_sanity.
  Proof.
    unfold refined_raft_net_invariant_do_leader,
           lifted_maxIndex_sanity, maxIndex_lastApplied, maxIndex_commitIndex.
    intuition; repeat find_higher_order_rewrite; update_destruct; auto.
    - erewrite doLeader_same_log by eauto.
      erewrite doLeader_same_lastApplied by eauto.
      repeat match goal with
        | [ H : forall _ , _ |- _ ] => specialize (H h0)
      end.
      repeat find_rewrite. auto.
    - repeat match goal with
                 | [ H : forall _ , _ |- _ ] => specialize (H h0)
               end.
      repeat find_rewrite. simpl in *.
      erewrite doLeader_same_commitIndex; eauto.
      find_eapply_lem_hyp (sorted_host_lifted net h0).
      find_rewrite. auto.
  Qed.

  Lemma doGenericServer_lastApplied :
    forall h st out st' ms,
      doGenericServer h st = (out, st', ms) ->
      lastApplied st' = lastApplied st \/
      (lastApplied st < commitIndex st  /\
       lastApplied st' = commitIndex st).
  Proof.
    unfold doGenericServer.
    intros.
    repeat break_match; repeat find_inversion; simpl.
    - do_bool.
      revert Heqb.
      eapply applyEntries_spec_ind; eauto.
    - do_bool.
      revert Heqb.
      eapply applyEntries_spec_ind; eauto.
  Qed.


  Lemma lifted_maxIndex_sanity_do_generic_server :
    refined_raft_net_invariant_do_generic_server lifted_maxIndex_sanity.
  Proof.
    unfold refined_raft_net_invariant_do_generic_server,
           lifted_maxIndex_sanity, maxIndex_lastApplied, maxIndex_commitIndex.
    intuition; find_higher_order_rewrite; update_destruct; auto;
    erewrite doGenericServer_log by eauto.
    - repeat match goal with
               | [ H : forall _ , _ |- _ ] => specialize (H h0)
             end.
      repeat find_rewrite. simpl in *.
      find_apply_lem_hyp doGenericServer_lastApplied.
      intuition; find_rewrite; auto.
    - repeat match goal with
               | [ H : forall _ , _ |- _ ] => specialize (H h0)
             end.
      repeat find_rewrite. simpl in *.
      erewrite doGenericServer_commitIndex by eauto.
      auto.
  Qed.

  Lemma lifted_maxIndex_sanity_state_same_packet_subset :
    refined_raft_net_invariant_state_same_packet_subset lifted_maxIndex_sanity.
  Proof.
    unfold refined_raft_net_invariant_state_same_packet_subset,
           lifted_maxIndex_sanity, maxIndex_lastApplied, maxIndex_commitIndex.
    intuition; find_reverse_higher_order_rewrite; auto.
  Qed.

  Lemma lifted_maxIndex_sanity_reboot :
    refined_raft_net_invariant_reboot lifted_maxIndex_sanity.
  Proof.
    unfold refined_raft_net_invariant_reboot,
           lifted_maxIndex_sanity, maxIndex_lastApplied, maxIndex_commitIndex.
    unfold reboot.
    intuition; find_higher_order_rewrite; update_destruct; auto with *.
    repeat match goal with
             | [ H : forall _ , _ |- _ ] => specialize (H h0)
           end.
    repeat find_rewrite. simpl in *.
    auto.
  Qed.


  Definition commit_invariant_host (net : network (params := raft_refined_multi_params)) : Prop :=
    forall h e,
      In e (log (snd (nwState net h))) ->
      (eIndex e <= lastApplied (snd (nwState net h)) \/
       eIndex e <= commitIndex (snd (nwState net h))) ->
      committed net e (currentTerm (snd (nwState net h))).

  Definition commit_invariant_nw (net : network (params := raft_refined_multi_params)) : Prop :=
    forall p t leader pli plt es lci,
      In p (nwPackets net) ->
      pBody p = AppendEntries t leader pli plt es lci ->
      (forall e,
         In e es ->
         eIndex e <= lci ->
         committed net e t) /\
      (forall h e ple,
         currentTerm (snd (nwState net h)) <= t ->
         In ple (log (snd (nwState net h))) ->
         eIndex ple = pli ->
         eTerm ple = plt ->
         haveNewEntries (snd (nwState net h)) es = true ->
         In e (log (snd (nwState net h))) ->
         eIndex e <= lci ->
         eIndex e <= pli ->
         committed net e t).

  Definition commit_invariant (net : network (params := raft_refined_multi_params)) : Prop :=
    commit_invariant_host net /\
    commit_invariant_nw net.

  Lemma commit_invariant_init :
    refined_raft_net_invariant_init commit_invariant.
  Proof.
    unfold refined_raft_net_invariant_init, commit_invariant.
    split.
    - unfold commit_invariant_host, commit_recorded_committed, commit_recorded, committed. simpl.
      intuition.
    - unfold commit_invariant_nw; simpl; intuition.
  Qed.

  Lemma commit_invariant_commit_recorded_committed :
    forall net,
      commit_invariant net ->
      commit_recorded_committed net.
  Proof.
    unfold commit_invariant, commit_recorded_committed, commit_recorded.
    intuition; repeat find_rewrite_lem deghost_spec; auto.
  Qed.

  Lemma handleClientRequest_currentTerm :
    forall h st client id c out st' ms,
      handleClientRequest h st client id c = (out, st', ms) ->
      currentTerm st' = currentTerm st.
  Proof.
    unfold handleClientRequest.
    intros.
    repeat break_match; repeat find_inversion; auto.
  Qed.

  Lemma handleClientRequest_commitIndex :
    forall h st client id c out st' ms,
      handleClientRequest h st client id c = (out, st', ms) ->
      commitIndex st' = commitIndex st.
  Proof.
    unfold handleClientRequest.
    intros.
    repeat break_match; repeat find_inversion; auto.
  Qed.

  Lemma directly_committed_allEntries_preserved :
    forall net net' e,
      directly_committed net e ->
      (forall h, In (eTerm e, e) (allEntries (fst (nwState net h))) ->
                 In (eTerm e, e) (allEntries (fst (nwState net' h)))) ->
      directly_committed net' e.
  Proof.
    unfold directly_committed.
    intuition.
    break_exists_exists.
    intuition.
  Qed.

  Lemma update_elections_data_client_request_allEntries :
    forall h st client id c out st' ms,
      handleClientRequest h (snd st) client id c = (out, st', ms) ->
      allEntries (update_elections_data_client_request h st client id c) =
      allEntries (fst st) \/
      (exists e : entry,
         eIndex e = S (maxIndex (log (snd st))) /\
         eTerm e = currentTerm (snd st) /\
         eClient e = client /\ eInput e = c /\ eId e = id /\ type (snd st) = Leader /\
         allEntries (update_elections_data_client_request h st client id c) =
         (currentTerm st', e) :: allEntries (fst st)).
  Proof.
    intros.
    unfold update_elections_data_client_request.
    repeat break_match; repeat find_inversion; auto.
    simpl.
    find_copy_apply_lem_hyp handleClientRequest_log.
    intuition.
    - repeat find_rewrite. do_bool. omega.
    - right.  break_exists_exists. intuition.
      congruence.
  Qed.

  Lemma update_elections_data_client_request_allEntries_ind :
    forall {h st client id c out st' ps},
      handleClientRequest h (snd st) client id c = (out, st', ps) ->
      forall (P : list (term * entry) -> Prop),
        P (allEntries (fst st)) ->
        (forall e,
         eIndex e = S (maxIndex (log (snd st))) ->
         eTerm e = currentTerm (snd st) ->
         eClient e = client -> eInput e = c -> eId e = id -> type (snd st) = Leader ->
         P ((currentTerm st', e) :: allEntries (fst st))) ->
        P (allEntries (update_elections_data_client_request h st client id c)).
  Proof.
    intros.
    find_apply_lem_hyp update_elections_data_client_request_allEntries.
    intuition.
    - find_rewrite. auto.
    - break_exists. intuition.
      repeat find_rewrite.  auto.
  Qed.

  Lemma update_elections_data_client_request_preserves_allEntries :
    forall h st client id c out st' ms t e,
      handleClientRequest h (snd st) client id c = (out, st', ms) ->
      In (t, e) (allEntries (fst st)) ->
      In (t, e) (allEntries (update_elections_data_client_request h st client id c)).
  Proof.
    intros.
    match goal with
      | [ |- context [ allEntries ?x ] ] =>
        destruct (allEntries x)
                 using (update_elections_data_client_request_allEntries_ind $(eauto)$)
    end; intuition.
  Qed.

  Lemma handleClientRequest_preservers_log :
    forall h st client id c out st' ms e,
      handleClientRequest h st client id c = (out, st', ms) ->
      In e (log st) ->
      In e (log st').
  Proof.
    intros.
    destruct (log st') using (handleClientRequest_log_ind $(eauto)$); intuition.
  Qed.

  Lemma committed_log_allEntries_preserved :
    forall net net' e t,
      committed net e t ->
      (forall h e',
         In e' (log (snd (nwState net h))) ->
         In e' (log (snd (nwState net' h)))) ->
      (forall h e' t',
         In (t', e') (allEntries (fst (nwState net h))) ->
         In (t', e') (allEntries (fst (nwState net' h)))) ->
      committed net' e t.
  Proof.
    unfold committed.
    intros.
    break_exists_exists.
    intuition.
    eapply directly_committed_allEntries_preserved; eauto.
  Qed.

  Lemma lift_max_index_sanity :
    forall net h,
      refined_raft_intermediate_reachable net ->
      maxIndex_sanity (deghost net) ->
      lastApplied (snd (nwState net h)) <= maxIndex (log (snd (nwState net h))) /\
      commitIndex (snd (nwState net h)) <= maxIndex (log (snd (nwState net h))).
  Proof.
    intros.
    match goal with
      | [ H : _, H' : _ |- _ ] => apply H in H'; clear H
    end.
    unfold maxIndex_sanity, maxIndex_lastApplied, maxIndex_commitIndex in *.
    break_and.
    rewrite <- deghost_spec with (net0 := net). auto.
  Qed.

  Lemma haveNewEntries_log :
    forall es st st',
      log st = log st' ->
      haveNewEntries st es = true ->
      haveNewEntries st' es = true.
  Proof.
    unfold haveNewEntries.
    intros.
    find_rewrite. auto.
  Qed.

  Lemma commit_invariant_nw_packet_subset :
    forall net net',
      (forall p,
         In p (nwPackets net') ->
         is_append_entries (pBody p) ->
         In p (nwPackets net)) ->
      (forall h,
         log (snd (nwState net h)) = log (snd (nwState net' h))) ->
      (forall h e t,
         In (t, e) (allEntries (fst (nwState net h))) ->
         In (t, e) (allEntries (fst (nwState net' h)))) ->
      (forall h, currentTerm (snd (nwState net h)) <= currentTerm (snd (nwState net' h))) ->
      commit_invariant_nw net ->
      commit_invariant_nw net'.
  Proof.
    unfold commit_invariant_nw.
    intros.
    eapply_prop_hyp In In; [|solve [eauto 10]].
    copy_eapply_prop_hyp In In; [|solve [eauto 10]].
    assert (forall h x, In x (log (snd (nwState net h))) ->
                        In x (log (snd (nwState net' h)))) by (intros; find_higher_order_rewrite; auto).
    assert (forall h x, In x (log (snd (nwState net' h))) ->
                        In x (log (snd (nwState net h)))) by (intros; find_higher_order_rewrite; auto).
    intuition.
    - eapply committed_log_allEntries_preserved; eauto.
    - eapply committed_log_allEntries_preserved; auto.
      + eauto 10 using le_trans, haveNewEntries_log.
      + auto.
      + auto.
  Qed.

  Lemma hCR_preserves_committed :
    forall net net' h client id c out d l e t,
      handleClientRequest h (snd (nwState net h)) client id c = (out, d, l) ->
      (forall h', nwState net' h' = update (nwState net) h (update_elections_data_client_request h (nwState net h) client id c, d) h') ->
      committed net e t ->
      committed net' e t.
  Proof.
    intros.
    eapply committed_log_allEntries_preserved; simpl; eauto.
    - intros. find_higher_order_rewrite.
      update_destruct; eauto using handleClientRequest_preservers_log.
    - intros. find_higher_order_rewrite.
      update_destruct; eauto using update_elections_data_client_request_preserves_allEntries.
  Qed.

  Lemma commit_invariant_client_request :
    forall h net st' ps' gd out d l client id c,
      handleClientRequest h (snd (nwState net h)) client id c = (out, d, l) ->
      gd = update_elections_data_client_request h (nwState net h) client id c ->
      commit_invariant net ->
      maxIndex_sanity (deghost net) ->
      refined_raft_intermediate_reachable net ->
      (forall h', st' h' = update (nwState net) h (gd, d) h') ->
      (forall p', In p' ps' -> In p' (nwPackets net) \/
                         In p' (send_packets h l)) ->
      commit_invariant (mkNetwork ps' st').
  Proof.
    unfold refined_raft_net_invariant_client_request, commit_invariant.
    intros. split.
    - { unfold commit_invariant_host in *. break_and.
        unfold commit_recorded_committed, commit_recorded in *.
        intros. simpl in *.
        repeat find_higher_order_rewrite.
        rewrite update_fun_comm with (f := snd).
        repeat match goal with H : _ |- _ => rewrite update_fun_comm with (f := snd) in H end.
        simpl in *.
        repeat match goal with
                 | [H : _ |- _] => rewrite (update_fun_comm raft_data _) in H
               end.
        rewrite (update_fun_comm raft_data _).
        rewrite update_nop_ext' by (now erewrite <- handleClientRequest_currentTerm by eauto).
        match goal with
          | [H : _ |- _] => rewrite update_nop_ext' in H
              by (now erewrite <- handleClientRequest_lastApplied by eauto)
        end.
        match goal with
          | [H : _ |- _] => rewrite update_nop_ext' in H
              by (now erewrite <- handleClientRequest_commitIndex by eauto)
        end.
        update_destruct.
        - find_copy_apply_lem_hyp handleClientRequest_log.
          break_and. break_or_hyp.
          + repeat find_rewrite.
            eapply committed_log_allEntries_preserved; eauto.
            * simpl. intros. find_higher_order_rewrite.
              update_destruct; repeat find_rewrite; auto.
            * simpl. intros. find_higher_order_rewrite.
              update_destruct; eauto using update_elections_data_client_request_preserves_allEntries.
          + break_exists. break_and. repeat find_rewrite.
            simpl in *.
            match goal with
              | [ H : _ \/ In _ _ |- _ ] => invc H
            end.
            * find_eapply_lem_hyp (lift_max_index_sanity net h0); auto.
              break_and. simpl in *. omega.
            * { eapply committed_log_allEntries_preserved; eauto.
                - simpl. intros. find_higher_order_rewrite.
                  update_destruct; repeat find_rewrite; auto.
                  find_reverse_rewrite.
                  eapply handleClientRequest_preservers_log; eauto.
                - simpl. intros. find_higher_order_rewrite.
                  update_destruct; eauto using update_elections_data_client_request_preserves_allEntries.
              }
        - eapply committed_log_allEntries_preserved; eauto.
          + simpl. intros. find_higher_order_rewrite.
            update_destruct; repeat find_rewrite; eauto using handleClientRequest_preservers_log.
          + simpl. intros. find_higher_order_rewrite.
            update_destruct; eauto using update_elections_data_client_request_preserves_allEntries.
      }
    - break_and. unfold commit_invariant_nw in *.
      simpl. intros.
      eapply_prop_hyp In In.
      break_or_hyp.
      + copy_eapply_prop_hyp In In; [|solve [eauto 10]].
        intuition.
        * eauto using hCR_preserves_committed.
        * find_higher_order_rewrite.
          { update_destruct.
            - find_copy_apply_lem_hyp handleClientRequest_log.
              intuition.
              + eapply hCR_preserves_committed; simpl; eauto.
                find_copy_apply_lem_hyp handleClientRequest_type. break_and.
                repeat find_rewrite.
                eauto using haveNewEntries_log.
              + break_exists. break_and.
                assert (eTerm ple = currentTerm (snd (nwState net h0)) ->
                        eIndex ple <= maxIndex (log (snd (nwState net h0)))) by admit.
                repeat find_rewrite.
                match goal with
                  | [ H : In ple (_ :: _) |- _ ] => simpl in H
                end.
                (* 
                destruct (eq_nat_dec (eIndex ple) (eIndex x)).
                * subst. simpl in *. concludes. omega.
                *
                break_or_hyp.
                * concludes. simpl in *. omega.
                * simpl in *.
                  { intuition.
                    - subst. simpl in *.
                *)
                admit.
            - eauto using hCR_preserves_committed.
          }
      + unfold send_packets in *. exfalso. do_in_map.
        subst. simpl in *.
        eapply handleClientRequest_no_append_entries; eauto 10.
  Admitted.

  Lemma commit_invariant_timeout :
    refined_raft_net_invariant_timeout commit_invariant.
  Admitted.

  Lemma commit_invariant_append_entries :
    refined_raft_net_invariant_append_entries commit_invariant.
  Admitted.

  Lemma commit_invariant_append_entries_reply :
    refined_raft_net_invariant_append_entries_reply commit_invariant.
  Admitted.

  Lemma commit_invariant_request_vote :
    refined_raft_net_invariant_request_vote commit_invariant.
  Admitted.

  Lemma commit_invariant_request_vote_reply :
    refined_raft_net_invariant_request_vote_reply commit_invariant.
  Admitted.

  Lemma commit_invariant_do_leader :
    refined_raft_net_invariant_do_leader commit_invariant.
  Admitted.

  Lemma commit_invariant_do_generic_server :
    refined_raft_net_invariant_do_generic_server commit_invariant.
  Admitted.

  Lemma commit_invariant_state_same_packet_subset :
    refined_raft_net_invariant_state_same_packet_subset commit_invariant.
  Admitted.

  Lemma commit_invariant_reboot :
    refined_raft_net_invariant_reboot commit_invariant.
  Admitted.

  Lemma maxIndex_sanity_lift :
    forall net,
      maxIndex_sanity (deghost net) ->
      lifted_maxIndex_sanity net.
  Proof.
    unfold maxIndex_sanity, lifted_maxIndex_sanity, maxIndex_lastApplied, maxIndex_commitIndex.
    intros. intuition;
    repeat match goal with
      | [ H : forall _, _, h : Net.name |- _ ] => specialize (H h)
    end;
    repeat find_rewrite_lem deghost_spec; auto.
  Qed.

  Lemma maxIndex_sanity_lower :
    forall net,
      lifted_maxIndex_sanity net ->
      maxIndex_sanity (deghost net).
  Proof.
    unfold maxIndex_sanity, lifted_maxIndex_sanity, maxIndex_lastApplied, maxIndex_commitIndex.
    intuition; rewrite deghost_spec;
    repeat match goal with
             | [ H : forall _, _, h : Net.name |- _ ] => specialize (H h)
           end; intuition.
  Qed.

  Definition everything (net : network) : Prop :=
    lifted_maxIndex_sanity net /\
    commit_invariant net /\
    state_machine_safety (deghost net).

  Lemma everything_init :
    refined_raft_net_invariant_init everything.
  Proof.
    unfold refined_raft_net_invariant_init, everything.
    intuition.
    - apply lifted_maxIndex_sanity_init.
    - apply commit_invariant_init.
    - apply state_machine_safety_deghost.
      + apply commit_invariant_commit_recorded_committed.
        apply commit_invariant_init.
      + apply state_machine_safety'_invariant.
        constructor.
  Qed.

  Lemma everything_client_request :
    refined_raft_net_invariant_client_request everything.
  Proof.
    unfold refined_raft_net_invariant_client_request, everything.
    intuition.
    - eapply lifted_maxIndex_sanity_client_request; eauto.
    - eapply commit_invariant_client_request; eauto.
      apply maxIndex_sanity_lower. auto.
    - apply state_machine_safety_deghost.
      + apply commit_invariant_commit_recorded_committed.
        eapply commit_invariant_client_request; eauto.
        apply maxIndex_sanity_lower. auto.
      + apply state_machine_safety'_invariant. subst.
        eapply RRIR_handleInput with (inp := ClientRequest client id c) ; eauto.
  Qed.

  Lemma everything_timeout :
    refined_raft_net_invariant_timeout everything.
  Proof.
    unfold refined_raft_net_invariant_timeout, everything.
    intuition.
    - eapply lifted_maxIndex_sanity_timeout; eauto.
    - eapply commit_invariant_timeout; eauto.
    - apply state_machine_safety_deghost.
      + apply commit_invariant_commit_recorded_committed.
        eapply commit_invariant_timeout; eauto.
      + apply state_machine_safety'_invariant. subst.
        eapply RRIR_handleInput with (inp := Timeout) ; eauto.
  Qed.

  Lemma everything_append_entries :
    refined_raft_net_invariant_append_entries everything.
  Proof.
    unfold refined_raft_net_invariant_append_entries, everything.
    intuition.
    - eapply lifted_maxIndex_sanity_append_entries; eauto.
    - eapply commit_invariant_append_entries; eauto.
    - apply state_machine_safety_deghost.
      + apply commit_invariant_commit_recorded_committed.
        eapply commit_invariant_append_entries; eauto.
      + apply state_machine_safety'_invariant. subst.
        eapply RRIR_handleMessage with (p0 := p); eauto; repeat find_rewrite.
        * simpl.  break_let. simpl in *. repeat find_rewrite. find_inversion.  eauto.
        * auto.
        * simpl. intuition. find_apply_hyp_hyp. intuition.
  Qed.

  Lemma everything_append_entries_reply :
    refined_raft_net_invariant_append_entries_reply everything.
  Proof.
    unfold refined_raft_net_invariant_append_entries_reply, everything.
    intuition.
    - eapply lifted_maxIndex_sanity_append_entries_reply; eauto.
    - eapply commit_invariant_append_entries_reply; eauto.
    - apply state_machine_safety_deghost.
      + apply commit_invariant_commit_recorded_committed.
        eapply commit_invariant_append_entries_reply; eauto.
      + apply state_machine_safety'_invariant. subst.
        eapply RRIR_handleMessage with (p0 := p); eauto; repeat find_rewrite; simpl; eauto.
  Qed.

  Lemma everything_request_vote :
    refined_raft_net_invariant_request_vote everything.
  Proof.
    unfold refined_raft_net_invariant_request_vote, everything.
    intuition.
    - eapply lifted_maxIndex_sanity_request_vote; eauto.
    - eapply commit_invariant_request_vote; eauto.
    - apply state_machine_safety_deghost.
      + apply commit_invariant_commit_recorded_committed.
        eapply commit_invariant_request_vote; eauto.
      + apply state_machine_safety'_invariant. subst.
        eapply RRIR_handleMessage with (p0 := p); eauto; repeat find_rewrite.
        * simpl.  break_let. simpl in *. repeat find_rewrite. find_inversion.  eauto.
        * auto.
        * simpl. intuition. find_apply_hyp_hyp. intuition.
  Qed.

  Lemma everything_request_vote_reply :
    refined_raft_net_invariant_request_vote_reply everything.
  Proof.
    unfold refined_raft_net_invariant_request_vote_reply, everything.
    intuition.
    - eapply lifted_maxIndex_sanity_request_vote_reply; eauto.
    - eapply commit_invariant_request_vote_reply; eauto.
    - apply state_machine_safety_deghost.
      + apply commit_invariant_commit_recorded_committed.
        eapply commit_invariant_request_vote_reply; eauto.
      + apply state_machine_safety'_invariant. subst.
        eapply RRIR_handleMessage with (p0 := p); eauto; repeat find_rewrite; simpl; eauto.
  Qed.

  Lemma everything_do_leader :
    refined_raft_net_invariant_do_leader everything.
  Proof.
    unfold refined_raft_net_invariant_do_leader, everything.
    intuition.
    - eapply lifted_maxIndex_sanity_do_leader; eauto.
    - eapply commit_invariant_do_leader; eauto.
    - apply state_machine_safety_deghost.
      + apply commit_invariant_commit_recorded_committed.
        eapply commit_invariant_do_leader; eauto.
      + apply state_machine_safety'_invariant. subst.
        eapply RRIR_doLeader; eauto.
  Qed.

  Lemma everything_do_generic_server :
    refined_raft_net_invariant_do_generic_server everything.
  Proof.
    unfold refined_raft_net_invariant_do_generic_server, everything.
    intuition.
    - eapply lifted_maxIndex_sanity_do_generic_server; eauto.
    - eapply commit_invariant_do_generic_server; eauto.
    - apply state_machine_safety_deghost.
      + apply commit_invariant_commit_recorded_committed.
        eapply commit_invariant_do_generic_server; eauto.
      + apply state_machine_safety'_invariant. subst.
        eapply RRIR_doGenericServer; eauto.
  Qed.


  Lemma directly_committed_state_same :
    forall net net' e,
      (forall h, nwState net' h = nwState net h) ->
      directly_committed net e ->
      directly_committed net' e.
  Proof.
    unfold directly_committed.
    intuition.
    break_exists_exists.
    intuition.
    find_higher_order_rewrite. auto.
  Qed.

  Lemma committed_state_same :
    forall net net' e t,
      (forall h, nwState net' h = nwState net h) ->
      committed net e t ->
      committed net' e t.
  Proof.
    unfold committed.
    intuition.
    break_exists_exists.
    intuition; repeat find_higher_order_rewrite; auto.
    eauto using directly_committed_state_same.
  Qed.

  Lemma state_machine_safety'_state_same_packet_subset :
    refined_raft_net_invariant_state_same_packet_subset state_machine_safety'.
  Proof.
    unfold refined_raft_net_invariant_state_same_packet_subset, state_machine_safety'.
    intuition.
    - unfold state_machine_safety_host' in *. intuition.
      eauto using committed_state_same.
    - unfold state_machine_safety_nw' in *. intuition.
      find_apply_hyp_hyp.
      eapply_prop_hyp In In; eauto using committed_state_same.
  Qed.

  Lemma everything_state_same_packet_subset :
    refined_raft_net_invariant_state_same_packet_subset everything.
  Proof.
    unfold refined_raft_net_invariant_state_same_packet_subset, everything.
    intuition.
    - eapply lifted_maxIndex_sanity_state_same_packet_subset; eauto.
    - eapply commit_invariant_state_same_packet_subset; eauto.
    - apply state_machine_safety_deghost.
      + apply commit_invariant_commit_recorded_committed.
        eapply commit_invariant_state_same_packet_subset; eauto.
      + eapply state_machine_safety'_state_same_packet_subset; eauto.
        auto using state_machine_safety'_invariant.
  Qed.

  Require Import FunctionalExtensionality.

  Lemma everything_reboot :
    refined_raft_net_invariant_reboot everything.
  Proof.
    unfold refined_raft_net_invariant_reboot, everything.
    intuition.
    - eapply lifted_maxIndex_sanity_reboot; eauto.
    - eapply commit_invariant_reboot; eauto.
    - apply state_machine_safety_deghost.
      + apply commit_invariant_commit_recorded_committed.
        eapply commit_invariant_reboot; eauto.
      + apply state_machine_safety'_invariant.
        eapply RRIR_step_f with (failed := [h]) (out := []); eauto. eapply SF_reboot with (h0 := h); eauto.
        * simpl. auto.
        * { destruct net'. f_equal.
            - simpl in *. congruence.
            - simpl in *. apply functional_extensionality. intros.
              find_higher_order_rewrite. unfold update. simpl. break_if.
              + subst. find_higher_order_rewrite. unfold refined_reboot. simpl. auto.
              + auto.
          }
  Qed.

  Theorem everything_invariant :
    forall net,
      refined_raft_intermediate_reachable net ->
      everything net.
  Proof.
    intros.
    apply refined_raft_net_invariant; auto.
    - apply everything_init.
    - apply everything_client_request.
    - apply everything_timeout.
    - apply everything_append_entries.
    - apply everything_append_entries_reply.
    - apply everything_request_vote.
    - apply everything_request_vote_reply.
    - apply everything_do_leader.
    - apply everything_do_generic_server.
    - apply everything_state_same_packet_subset.
    - apply everything_reboot.
  Qed.

  Theorem state_machine_safety_invariant :
    forall net,
      raft_intermediate_reachable net ->
      state_machine_safety net.
  Proof.
    intros.
    eapply lower_prop; intros; auto.
    find_apply_lem_hyp everything_invariant.
    unfold everything in *. intuition.
  Qed.

  Theorem maxIndex_sanity_invariant :
    forall net,
      raft_intermediate_reachable net ->
      maxIndex_sanity net.
  Proof.
    intros.
    eapply lower_prop; intros; eauto.
    find_apply_lem_hyp everything_invariant.
    unfold everything in *. intuition.
    auto using maxIndex_sanity_lower.
  Qed.

  Theorem commit_recorded_committed_invariant :
    forall net,
      refined_raft_intermediate_reachable net ->
      commit_recorded_committed net.
  Proof.
    intros.
    find_apply_lem_hyp everything_invariant.
    unfold everything in *.
    intuition.
    auto using commit_invariant_commit_recorded_committed.
  Qed.

  Instance smsi : state_machine_safety_interface.
  Proof.
    split.
    exact state_machine_safety_invariant.
  Qed.

  Instance misi : max_index_sanity_interface.
  Proof.
    split.
    exact maxIndex_sanity_invariant.
  Qed.

  Instance crci : commit_recorded_committed_interface.
  Proof.
    split.
    intros.
    find_apply_lem_hyp commit_recorded_committed_invariant.
    unfold commit_invariant, commit_recorded_committed, commit_recorded in *.
    intros.
    find_rewrite_lem (deghost_spec net h).
    intuition;
    repeat match goal with
             | [ H : forall _, _, h : entry |- _ ] => specialize (H h)
             | [ H : forall _, _, h : Net.name |- _ ] => specialize (H h)
           end;
    repeat find_rewrite_lem deghost_spec; auto.
  Qed.
End StateMachineSafetyProof.
