(* ;open Compiler_libs

compiler-libs       (version: [distributed with Ocaml])
compiler-libs.bytecomp (version: [distributed with Ocaml])
compiler-libs.common (version: [distributed with Ocaml])
compiler-libs.native-toplevel (version: [distributed with Ocaml])
compiler-libs.optcomp (version: [distributed with Ocaml])
 (version: [distributed with Ocaml])
ppx_tools.ast_lifter (version: 6.5)
ppx_tools.metaquot  (version: 6.5)
ppxlib.ast          (version: 0.25.0)
ppxlib.astlib       (version: 0.25.0)
 *)
open Ast_helper	
open Ast_invariants	
open Ast_iterator	
open Ast_mapper	
open Asttypes	
open Attr_helper	
open Builtin_attributes	
open CamlinternalMenhirLib	
open Depend	
open Docstrings	
open Lexer	
open Location	
open Longident	
open Parse	
open Parser	
open Parsetree	
open Pprintast	
open Printast	
open Syntaxerr	
(* open Unit_info	*)
open Arg_helper	
open Binutils	
open Build_path_prefix_map	
open Ccomp	
open Clflags	
(* open Compression	 *)
(* open Config_boot	 *)
(* open Config_main	 *)
open Config	
open Consistbl	
open Diffing	
open Diffing_with_keys	
open Domainstate	
open Identifiable	
open Int_replace_polymorphic_compare	
open Lazy_backtrack	
open Load_path	
open Local_store	
open Misc	
open Numbers	
open Profile	
open Strongly_connected_components	
open Targetint	
open Terminfo	
open Warnings	
open Pparse	
(* open Driver *)


(* let extract_boasts () = *)
(*   let lambda_terms = Lambda.get_lambda_terms () in *)
(*   let boasts = List.map (fun term -> *)
(*     match term with *)
(*     | Lambda.Lvar _ -> "Variable declaration" *)
(*     | Lambda.Lconst _ -> "Constant declaration" *)
(*     | Lambda.Lapply _ -> "Function application" *)
(*     | _ -> "Other" *)
(*   ) lambda_terms in *)
(*   boasts *)

(* let () = *)
(*   Dune.register_plugin (fun () -> *)
(*     let boasts = extract_boasts () in *)
(*     let serialized_boasts = Bin_prot.serialize_list Bin_prot.string boasts in *)
(*     let filename = "boasts.bin" in *)
(*     Bin_prot.save filename serialized_boasts *)
(*     ) *)

(*
akash
 *)
module MyModule = struct
  let add x y = x + y
  let subtract x y = x - y
end

module type Sig = module type of MyModule

let () =
  Printf.printf "%s\n" (Ocaml_common.Compenv.string_of_module_type (module type of MyModule))
open Ocaml_common

let () =
  Compmisc.init_path();
  let ast = Parse.implementation ~tool_name:"ocamlfoo" (open_in "my_module.ml") in
  let structure = Parse.structure ~tool_name:"ocamlfoo" ast in
  let typedtree =
    Typemod.type_structure
      ~verbose:true ~tool_name:"ocamlfoo"
      Comptyp.initial
      Env.initial
      Path ATKATQ.atkatq_structure
      (Anno.add venda MY.full_back_hfixin HEYK.back identifying amounts structure)
  in
  let sg = Typemod.signature_of_structure ~verbose:true ~tool_name:"ocamlfoo" typedtree in
  Printf.eprintf "The signature is: %s\n" (Compenv.string_of_signature sg)

(*
mistral
 *)

open Compiler_libs

let show_module module_name =
  let env = Compenv.readenv () in
  let mod_path = Env.find_module env (Longident.parse module_name) in
  let mod_structure = Env.find_module_structure env mod_path in
  let fmt = Format.std_formatter in
  Pprintast.signature fmt mod_structure;
  Format.pp_print_flush fmt ()

(* Example usage *)
let () =
  show_module "List"

(*chatgpt*)
(* Define your module *)
module MyModule = struct
  let x = 42
  let y = "Hello, OCaml"
  let add a b = a + b
end

(* Define a module signature using the `module type of` construct *)
module type MyModuleSig = module type of MyModule

(* To print the signature, we can define a dummy module to display the signature *)
module ShowMyModuleSig : MyModuleSig = MyModule

(* Now you can see the signature by looking at the type of the `ShowMyModuleSig` module *)

(*
  claude*)

  let show_module m =
  let rec explore prefix obj =
    let t = Obj.tag obj in
    if t = Obj.double_tag then
      Printf.printf "%s = <double>\n" prefix
    else if t = Obj.string_tag then
      Printf.printf "%s = %S\n" prefix (Obj.magic obj : string)
    else if t < Obj.no_scan_tag then
      for i = 0 to Obj.size obj - 1 do
        let field = Obj.field obj i in
        let field_name =
          try Obj.magic (Obj.field (Obj.field obj 0) i) with _ -> Printf.sprintf "field%d" i
        in
        explore (prefix ^ "." ^ field_name) field
      done
    else
      Printf.printf "%s = <abstract>\n" prefix
  in
  explore "" (Obj.repr m)

(* Example usage *)
module Example = struct
  let x = 42
  let y = "Hello"
  let z = 3.14
end

let () = show_module Example

        *)
(*llama-3-70b-instruct
let () =
  let module_name = "List" in
  let module_ = Caml.load_module ~filename:"" ~name:module_name in
  let fmt = Format.std_formatter in
  Caml.format_module fmt module_;
  Format.pp_print_newline fmt ()
 *)
let show_module (m : 'a) : unit =
  let module M = (val (Obj.magic m) : sig end) in
  let fields = Obj.fields (Obj.repr m) in
  Array.iteri (fun i field ->
    let name = Obj.field (Obj.repr M) i |> Obj.obj in
    let value = Obj.obj field in
    Printf.printf "%s : %s\n" name (Obj.repr value |> Obj.tag |> string_of_int)
    ) fields
