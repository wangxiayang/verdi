Require Import List.
Import ListNotations.

Require Import VerdiTactics.
Require Import Util.
Require Import Net.

Require Import Raft.
Require Import RaftRefinementInterface.
Require Import CommonDefinitions.

Require Import LeaderLogsVotesWithLogInterface.

Section LeaderLogsVotesWithLog.
  Context {orig_base_params : BaseParams}.
  Context {one_node_params : OneNodeParams orig_base_params}.
  Context {raft_params : RaftParams orig_base_params}.

  Instance llvwli : leaderLogs_votesWithLog_interface.
  Admitted.
End LeaderLogsVotesWithLog.