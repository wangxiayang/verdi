Require Import List.

Require Import VerdiTactics.
Require Import Net.
Require Import Raft.
Require Import RaftRefinementInterface.

Require Import AllEntriesLogMatchingInterface.

Section AllEntriesLogMatching.

  Context {orig_base_params : BaseParams}.
  Context {one_node_params : OneNodeParams orig_base_params}.
  Context {raft_params : RaftParams orig_base_params}.

  Instance aelmi : allEntries_log_matching_interface.
  Admitted.
End AllEntriesLogMatching.
