Require Import List.
Import ListNotations.

(* a function, which get S and return a product type of four subtypes *)
(* right associativity here *)
(* % type is to explicitly denote the type *)
Definition GenHandler (W S O A : Type) : Type := S -> A * list O * S * list W % type.

(* see definition of nop to get an example of {} usage *)
Definition ret {W S O A : Type} (a : A) : GenHandler W S O A := fun s => (a, [], s, []).

(* bind is a monad, which get m's output and feed it to f *)
Definition bind {W S O A B : Type} (m : GenHandler W S O A) (f : A -> GenHandler W S O B) : GenHandler W S O B :=
  fun s =>
  (* after bind, get one more parameter again and feed it to m.
  Get output of m and feed it to f. Finally merge them together *)
    let '(a, os1, s', ws1) := m s in
    let '(b, os2, s'', ws2) := f a s' in
    (b, os2 ++ os1, s'', ws2 ++ ws1).

(* tt is the only value of type unit *)
Definition send {W S O} (w : W) : GenHandler W S O unit := fun s => (tt, [], s, [w]).

(* fun should be lambda expression - anonymous function *)
Definition write_output {W S O} (o : O) : GenHandler W S O unit := fun s => (tt, [o], s, []).

Definition modify {W S O} (f : S -> S) : GenHandler W S O unit := fun s => (tt, [], f s, []).

Definition put {W S O} (s : S) : GenHandler W S O unit := fun _ => (tt, [], s, []).

Definition get {W S O} : GenHandler W S O S := fun s => (s, [], s, []).

Definition runGenHandler {W S O A} (s : S) (h : GenHandler W S O A) :
  A * list O * S * list W % type :=
  h s.

Definition runGenHandler_ignore {W S O A} (s : S) (h : GenHandler W S O A) :
  list O * S * list W % type :=
  let '(_, os, s', ms) := h s in (os, s', ms).

(* for single node semantics *)
Definition runGenHandler1_ignore {W S O A} (h : GenHandler W S O A) (s : S) : list O * S := 
  let '(_, os, d, _) := runGenHandler s h in
  (os, d).

(* ret need four types as parameters, which is the first four *)
(* tt is the only actual parameter of ret *)
Definition nop {W S O : Type} := @ret W S O _ tt.

Notation "a >> b" := (bind a (fun _ => b)) (at level 50).

Notation "x <- c1 ;; c2" := (@bind _ _ _ _ _ c1 (fun x => c2))
                              (at level 100, c1 at next level, right associativity).

(* ignore e1's return value and return e2 *) 
Notation "e1 ;; e2" := (_ <- e1 ;; e2)
                         (at level 100, right associativity).

(* identifiers in {} might be generic type got from parameters *)
Definition when {W S O A} (b : bool) (m : GenHandler W S O A) : GenHandler W S O unit :=
  if b then m ;; ret tt else nop.

Ltac monad_unfold :=
  repeat unfold
         runGenHandler_ignore,
         runGenHandler,
         runGenHandler1_ignore,
         bind,
         send,
         write_output,
         get,
         when,
         put,
         nop,
         modify,
         ret in *.

