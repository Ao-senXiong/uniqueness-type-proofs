Require Export Arith.EqNat.
Require Export Arith.Le.
Require Import Coq.Arith.Arith.
Require Import Coq.Bool.Bool.
Require Import Coq.Program.Equality.
Require Import Coq.Lists.List.
Require Import Psatz.
Require Import ZArith.
Require Import Coq.Arith.Compare_dec.
Import ListNotations.

Require Import env.
Require Import vars.
Require Import defs.
Require Import semantics.

Import OpeningNotations.
Local Open Scope opening.

Definition heap := list (ty * list (ty * tm)).

Definition store := list (ty * tm).

Definition tenv := list ty.  (* static type env *)  

(* field types *)
Inductive f_has_ty : class_table -> nat (* class name *) -> nat (* field name *) ->  ty  ->  Prop :=
  | ty_f: forall c ct fl init ml f T, 
    indexr c ct = Some(cls_def fl init ml) ->
    indexr f fl = Some  T ->
    wf_ty T ct ->
    (* wf_normal_ty T ct -> *)
    f_has_ty ct c f T
.


(* expression types *)
Inductive tm_has_ty: tenv -> class_table -> tm -> ty -> Prop :=
  | ty_tm_true: forall Γ ct,
    tm_has_ty Γ ct ttrue TBool
  
  | ty_tm_false: forall Γ ct,
    tm_has_ty Γ ct tfalse TBool

  | ty_tm_varB: forall Γ ct x,
    indexr x Γ  = Some TBool ->
    tm_has_ty Γ ct $x TBool
  
  (* | ty_tm_varBot: forall Γ ct x c,
    indexr x Γ  = Some (TCls c TSBot)  ->
    tm_has_ty Γ ct $x (TCls c TSBot) *)

  | ty_tm_varC: forall Γ ct x c ts ,
    indexr x Γ  = Some (TCls c ts) ->
    ts <> TSBot ->
    wf_ty (TCls c ts) ct ->
    tm_has_ty Γ ct $x (TCls c ts)
  
  | ty_tm_facc: forall Γ ct x c f T ts c' ts',
    wf_ty T ct ->
    c < length ct ->
    tm_has_ty Γ ct $x (TCls c ts) ->
    wf_ty (TCls c ts) ct ->
    (T = TCls c' ts' -> ts' = TSShared) ->
    f_has_ty ct c f T ->
    tm_has_ty Γ ct (tfacc $x f) T

  (* | ty_tm_oid: forall Γ h ct l c object,
    c < length ct ->
    indexr l h = Some ((TCls c), object) ->
    l < length h ->
    tm_has_ty Γ h ct (& l) (TCls c) 
  
  | ty_tm_oid_facc: forall Γ h ct c oid f fvlues T v,
    c < length ct ->
    indexr oid h = Some ((TCls c), fvlues) ->
    indexr f fvlues = Some (T, v) ->
    value v ->
    tm_has_ty Γ h ct v T ->
    tm_has_ty Γ h ct (toidfacc oid f) T *)
.

(* constructor's parameter list types *)

Inductive parameter_has_ty : tenv -> class_table -> list var -> list ty -> Prop :=
 | ty_parameter_nil: forall Γ ct,
   parameter_has_ty Γ ct [] []

 | ty_parameter_cons: forall Γ ct x xs T Ts,
   tm_has_ty Γ ct $x T ->
   parameter_has_ty Γ ct xs Ts ->
   parameter_has_ty Γ ct (($x)::xs) (T::Ts)
.

(* Inductive object_valid_type : list (ty * tm) -> tenv -> class_table -> list ty -> Prop := 
| o_nil: forall Γ ct ,
  object_valid_type [] Γ ct []

| o_cons: forall fs Γ ct T v o,
  value v ->
  tm_has_ty Γ ct v T ->
  length o = length fs ->
  object_valid_type o Γ ct fs ->
  object_valid_type ((T, v) :: o) Γ ct (T :: fs)
. *)

(* statements types *)
Inductive stmt_has_ty: tenv -> class_table -> stmt -> tenv -> Prop :=
  | ty_stmt_skip : forall Γ ct,
    stmt_has_ty Γ ct sskip Γ

  | ty_stmt_assgnC: forall Γ ct x y,
    tm_has_ty Γ ct $x TBool ->
    tm_has_ty Γ ct $y TBool ->
    stmt_has_ty Γ ct (sassgn $x $y) Γ
    
  | ty_stmt_assgnU: forall Γ ct x y c ts Γ',
    tm_has_ty Γ ct $x (TCls c ts) ->
    tm_has_ty Γ ct $y (TCls c TSUnique) ->
    Γ' = update (update Γ y (TCls c TSBot)) x (TCls c TSUnique) ->
    stmt_has_ty Γ ct (sassgn $x $y) Γ'

  | ty_stmt_assgnS: forall Γ ct x y c ts Γ',
    tm_has_ty Γ ct $x (TCls c ts) ->
    tm_has_ty Γ ct $y (TCls c TSShared) ->
    Γ' = update Γ x (TCls c TSShared) ->
    stmt_has_ty Γ ct (sassgn $x $y) Γ'

  | ty_stmt_loadC: forall Γ ct x y f,
    tm_has_ty Γ ct $x TBool ->
    tm_has_ty Γ ct (tfacc $y f) TBool ->
    stmt_has_ty Γ ct (sload $x $y f) Γ

  | ty_stmt_loadS: forall Γ Γ' ct x y f c ts,
    tm_has_ty Γ ct $x (TCls c ts) ->
    tm_has_ty Γ ct (tfacc $y f) (TCls c TSShared) ->
    Γ' = update Γ x (TCls c TSShared) ->
    stmt_has_ty Γ ct (sload $x $y f) Γ'

  | ty_stmt_storeC: forall Γ ct x y f c,
    tm_has_ty Γ ct $x (TCls c TSShared) ->
    tm_has_ty Γ ct (tfacc $x f) TBool ->
    tm_has_ty Γ ct $y TBool ->
    stmt_has_ty Γ ct (sstore $x f $y) Γ

  | ty_stmt_storeS: forall Γ ct x y f c c',
    tm_has_ty Γ ct $x (TCls c TSShared) ->
    tm_has_ty Γ ct (tfacc $x f) (TCls c' TSShared) ->
    tm_has_ty Γ ct $y (TCls c' TSShared) ->
    stmt_has_ty Γ ct (sstore $x f $y) Γ

  | ty_stmt_storeU: forall Γ ct x y f c c' Γ',
    tm_has_ty Γ ct $x (TCls c TSShared) ->
    tm_has_ty Γ ct (tfacc $x f) (TCls c' TSShared) ->
    tm_has_ty Γ ct $y (TCls c' TSUnique) ->
    Γ' = update Γ y (TCls c' TSBot) ->
    stmt_has_ty Γ ct (sstore $x f $y) Γ'

  | ty_stmt_mcall: forall Γ ct c x y z m s t T1 T2 fs init ms ts,    (* x := y.m (z) *)
    tm_has_ty Γ ct $x T2 ->
    tm_has_ty Γ ct $y (TCls c ts) ->
    indexr c ct = Some(cls_def fs init ms) ->
    indexr m ms = Some (m_decl T1 T2 s t) ->
    tm_has_ty Γ ct (t <~ᵗ $y; $z) T2 ->
    stmt_has_ty Γ ct (s <~ˢ $y; $z) Γ ->
    tm_has_ty Γ ct $z T1 -> (* only one parameter here, change it to para_has_ty in the future. *)
    stmt_has_ty Γ ct (smcall $x $y m $z) Γ

  | ty_stmt_slettmC: forall Γ Γ' ct t T1 T1' s,       (* var x : T2 = t in S *)  (* bound variable is implicit *)
    closed_stmt 1 (length Γ) s ->
    tm_has_ty Γ ct t T1 ->
    (forall c, T1 <> TCls c TSUnique) ->
    stmt_has_ty (T1::Γ) ct (open_rec_stmt 0 $(S (length Γ)) s) (T1' :: Γ') ->
    stmt_has_ty Γ ct (slettm T1 t s) Γ'

  | ty_stmt_slettmU: forall Γ Γ' ct x c s T1',       (* var x : T2 = t in S *)  (* bound variable is implicit *)
    closed_stmt 1 (length Γ) s ->
    tm_has_ty Γ ct $x (TCls c TSUnique) ->
    (* teval t σ h (T1, v) ->
    tm_has_ty Γ σ h ct v T1 -> (* consider use tm_safety *)
    value v -> (* try to eliminate these two lines by proving the progress property of term. *) *)
    stmt_has_ty ((TCls c TSUnique)::(update Γ x (TCls c TSBot))) ct (open_rec_stmt 0 $(S (length Γ)) s) (T1' :: Γ') ->
    stmt_has_ty Γ ct (slettm (TCls c TSUnique) $x s) Γ'

  | ty_stmt_sletnew: forall Γ ct c ps Ts s this s0 fs ms init ts,    (* var x : C2 = new C1 in S *) 
                                                       (* var x : C = new C(ps) in S *)
    indexr c ct = Some(cls_def fs init ms) ->
    init = init_decl Ts s0 this ->
    closed_stmt 1 (length Γ) s ->
    closed_var_list 0 (length Γ) ps ->
    parameter_has_ty Γ ct ps fs ->
    (* object_valid_type objrec Γ ct fs ->
    (forall objrec', object_valid_semantic objrec' fs -> objrec = objrec') -> *)
    (* need to make sure that objrec is the right result returned by constructor. *)
    (* two ways of doing this:
    1. extend the definition of constructor ("init" above) and make it assign every field through sstore. 
       then the equality of type are also obvious.
    2. take use of the definition of HeapOK and make sure the new object fit (maybe partial) description of an object in that def. *)
    stmt_has_ty ((TCls c ts)::Γ) ct (open_rec_stmt 0 $(S (length Γ)) s) Γ -> 
    stmt_has_ty Γ ct (sletnew (TCls c ts) (TCls c ts) ps s) Γ
  
  | ty_stmt_sif: forall Γ ct x s1 s2,   
    tm_has_ty Γ ct $x TBool ->
    stmt_has_ty Γ ct s1 Γ -> 
    stmt_has_ty Γ ct s2 Γ ->
    stmt_has_ty Γ ct (sif $x s1 s2) Γ

  | ty_stmt_sloop: forall Γ ct x c l s s',   
    tm_has_ty Γ ct $x TBool ->
    loop_body s c l s' ->
    stmt_has_ty Γ ct s' Γ->
    c < l ->
    closed_stmt 0 (length Γ) s ->
    stmt_has_ty Γ ct (sloop $x c l s) Γ
 
  | ty_stmt_sseq: forall Γ ct s1 s2 ,
    stmt_has_ty Γ ct s1 Γ ->
    (* step s1 σ h ct σ' h' -> *)
    stmt_has_ty Γ ct s2 Γ ->
    closed_stmt 0 (length Γ) s2 ->
    (* stmt_has_ty Γ σ' h' ct s2 -> *)
    (* should we also modify Γ so it can remain identical to the store 
    since we need this property in StoreOK? *)
    stmt_has_ty Γ ct (sseq s1 s2) Γ
.


(* type-check method body *)
Inductive m_has_ty:class_table -> nat (* class name *) -> nat (* method name *) -> Prop :=
  | ty_m: forall ct c m fl init ml Tr Tp t s ts Γ,              (* implicit (lambda ret. s; t) t1 *)
    indexr c ct  = Some(cls_def fl init ml) ->
    indexr m ml = Some(m_decl Tp Tr s t) ->
    stmt_has_ty (Tr :: Tp :: [(TCls c ts)]) ct s Γ ->
    tm_has_ty (Tr :: Tp :: [(TCls c ts)]) ct t Tr ->
    m_has_ty ct c m
.


Lemma tm_has_ty_closed: forall  {Γ ct t T },  tm_has_ty Γ ct t T ->  closed_tm 0 (length Γ) t.
Proof. intros. induction H; auto.
      + constructor. apply indexr_var_some' in H. auto.
      + constructor. apply indexr_var_some' in H. auto.
      (* + constructor. apply indexr_var_some' in H. auto. *)
      + constructor. inversion H1; subst. apply indexr_var_some' in H10. auto.
Qed.


Lemma stmt_has_ty_closed: forall  {Γ Γ' ct s},  stmt_has_ty Γ ct s Γ' ->  closed_stmt 0 (length Γ) s.
Proof. intros. induction H; auto; constructor; auto.
       all: try apply tm_has_ty_closed in H; inversion H; subst; auto;
       try apply tm_has_ty_closed in H0; inversion H0; subst; auto;
       try apply tm_has_ty_closed in H1; inversion H1; subst; auto;
       try apply tm_has_ty_closed in H5; inversion H5; subst; auto. 
Qed.


Lemma f_ty_inversion: forall {ct c f T}, wf_ct ct -> f_has_ty ct c f T -> 
      exists fl init ml, indexr c ct = Some (cls_def fl init ml) 
              /\ indexr f fl = Some T.
Proof. intros. induction H0. 
       + exists fl. exists init. exists ml.  intuition.
Qed.

Lemma tfacc_type_inversion: forall {Γ ct x f T}, wf_ct ct -> tm_has_ty Γ ct (tfacc $ x f) T -> 
  exists c, c < length ct -> f_has_ty ct c f T.
Proof. intros. inversion H0. subst. exists c. auto.
Qed.


(* Lemma obj_type_inversion: forall {Γ h ct l c}, tm_has_ty Γ h ct (& l) (TCls c) -> 
  exists object, indexr l h = Some ((TCls c), object) /\ l < length h.
Proof. intros. inversion H. subst. exists object. auto.
Qed. *)

Lemma tbool_inversion: forall {Γ ct v}, (value v) -> tm_has_ty Γ ct v TBool -> 
           (v = ttrue \/ v = tfalse).
Proof. intros. inversion H0; subst; intuition.
       inversion H. inversion H. 
       (* inversion H. *)
Qed.

(* Lemma tm_store_irre: forall {Γ σ h ct t T}, 
  tm_has_ty Γ σ h ct t T -> 
  forall σ', tm_has_ty Γ σ' h ct t T.
Proof. 
  intros. induction H; subst; econstructor; eauto.
Qed. *)

(* Lemma type_to_semantic: forall{objrec Γ ct fs}, object_valid_type objrec Γ ct fs ->
  object_valid_semantic objrec fs.
Proof.
  intros. induction H. constructor. constructor; auto.
Qed. *)

(* Lemma tm_preservasion: forall {Γ s σ h ct t T σ' h'},
  tm_has_ty Γ σ h ct t T -> step s σ h ct σ' h' ->
  tm_has_ty Γ σ' h' ct t T.
Proof.
  intros. induction H0; subst; auto. 1,2,4: eapply tm_store_irre; eauto. 
  inversion H; subst. 1-4: econstructor; eauto. destruct (l =? l0) eqn:E1.
  apply Nat.eqb_eq in E1; subst. econstructor; eauto. erewrite update_indexr_hit; eauto.
  rewrite H6 in H3. inversion H3; subst. eauto. erewrite <- update_length. 
  eapply indexr_var_some'; eauto. apply Nat.eqb_neq in E1. econstructor; eauto.
  erewrite update_indexr_miss; eauto. erewrite <- update_length. eapply indexr_var_some'; eauto.
Admitted. *)

(* Lemma object_valid_hit: forall {object Γ ct fs f T v }, object_valid_type object Γ ct fs ->
  indexr f object = Some (T, v) -> (value v /\ tm_has_ty Γ ct v T /\ indexr f fs = Some T ).
Proof.
  intros. induction H; subst. inversion H0. destruct (f =? length o) eqn: E1. 
  + apply Nat.eqb_eq in E1. subst. rewrite indexr_head in H0. inversion H0; subst. rewrite H2.
    rewrite indexr_head. intuition.
  + apply Nat.eqb_neq in E1. rewrite indexr_skip in H0; auto. intuition. rewrite H2 in E1.
    rewrite indexr_skip; auto.
Qed. *)

(* Lemma toidfacc_store_irre: forall {Γ σ h ct oid f Tf}, 
  tm_has_ty Γ σ h ct (toidfacc oid f) Tf -> 
  forall σ', tm_has_ty Γ σ' h ct (toidfacc oid f) Tf.
Proof. intros. inversion H. subst. econstructor; eauto. 
  eapply tm_store_irre; eauto.
Qed. *)


(* Lemma para_store_irre: forall {Γ σ h ct p T},
parameter_has_ty Γ σ h ct p T -> 
  forall σ', parameter_has_ty Γ σ' h ct p T.
Proof.
  intros. induction H; subst; econstructor; try eapply tm_store_irre; eauto.
Qed. *)

(* Lemma stmt_store_irre: forall {Γ σ h ct s T Tv v}, 
  stmt_has_ty Γ σ h ct s T -> 
  stmt_has_ty Γ ((Tv,v) :: σ) h ct s T.
Proof.
  intros. induction H; subst; econstructor; try eapply tm_store_irre;
  try eapply para_store_irre; eauto.
Admitted. *)


(* Lemma teval_has_type: forall {Γ σ h ct t v T}, 
  teval t σ h (T, v) -> 
  tm_has_ty Γ σ h ct v T /\ value v.
Proof.
  intros. inversion H; subst; auto; intuition; try econstructor; eauto.
  admit. apply indexr_var_some' in H4. auto. inversion H6; subst.  


  inversion H9; subst. assert (tm_has_ty Γ σ h ct ttrue TBool). { constructor. }
Admitted. *)




(*
Lemma test: forall {Γ σ h ct x v T},
  indexr x σ = Some (T, v) -> value v -> tm_has_ty Γ σ h ct v T.
Proof. intros. induction v.
   + admit.
   + admit.
   + admit.
   + inversion H0.
   + admit.
   + inversion H0. 
*)