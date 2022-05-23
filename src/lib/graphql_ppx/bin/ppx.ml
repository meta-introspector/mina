open Base
open Ppxlib

let (let*) x f = Result.bind x ~f

(* Declare possible attributes on record fields *)

let attr_subquery =
  Ppxlib.Attribute.declare "graphql2.subquery"
    Attribute.Context.label_declaration
    Ast_pattern.(single_expr_payload (pexp_constant (pconst_string __ __)))
    (fun str _ -> str)
                                                                          

(* The functor is used to factorize the loc parameter in all Ast_builder functions *)
module Make (B : Ast_builder.S) = struct
  let mkloc txt = {txt; loc=B.loc}
  let loc = B.loc

  (** Create the type:
   type ('kind, 'name) r =
      {
       res_kind: 'kind;
       res_name: 'name;
      }
  *)
  (* TODO: mutation fields *)
  module R_type = struct
    let type_name = "r"
    let field_prefix = "res_"

    let make fields params =
      let name = mkloc type_name in
      let params' = List.map params ~f:(fun p -> (p, Invariant)) in
      let make_r_field label typ =
        let name = mkloc (field_prefix ^ label.pld_name.txt) in
        B.label_declaration ~name ~mutable_:Immutable ~type_:typ
      in
      let kind = Ptype_record (List.map2_exn fields params ~f:make_r_field) in
      let td = B.type_declaration ~name ~cstrs:[]
          ~params:params' ~kind ~private_:Public ~manifest:None
      in
      B.pstr_type Recursive [td]
  end

  (* Create a core_type from a type name and optional type parameters *)
  let mkconstr ?(args=[]) name =
    let ident = Longident.parse name in
    let loc = mkloc ident in
    B.ptyp_constr loc args

  (** Create the type:
      type 'a modifier = 'a option
      if needed. In general, it is better to source it from the user.
  *)
  module Res_type = struct
    let type_name = "modifier"
    let make () =
      [%stri type 'a modifier = 'a option]
  end

  module Out_type = struct
    let type_name = "out"
    let make () =
      [%stri type out = t modifier]
  end

  (* Create the GADT type of the form:
   type _ query =
    Empty: (unit, unit, unit) r query
  | Address :
      {siblings: (unit, 'name, 'id) r query;
       subquery: 'a Address.Gql.query;
      } -> 
      ('a Address.Gql.res, 'name, 'id) r query
  | Name:
      {siblings : ('address, unit, 'id) r query;} ->
      ('address, string, 'id) r query

  | Id: {siblings: ('address, 'name, unit) r query}  ->
        ('address, 'name, int) r query
  *)
  module Query_type = struct
    let type_name = "query"
    let empty_field = "Empty"
    let siblings_name = "siblings"
    let subquery_name = "subquery"

    (* Create the result type of the gadt from the list of type params *)
    let mkres params =
      let res_r = mkconstr R_type.type_name ~args:params in
      mkconstr type_name ~args:[res_r]

    let make _td fields params =
      let name = mkloc type_name in
      let params' = [(B.ptyp_any, Invariant)] in
      let replace_var_by_type params to_replace replacement =
        List.map params ~f:(fun p ->
            if Poly.(p = to_replace) then replacement (* replace *)
            else p (* keep *)
          ) 
      in
      let type_of_module type_name mod_name =
        let var = B.ptyp_var "a" in
        let foreign_type = if String.is_empty mod_name then type_name
          else mod_name ^ "." ^ type_name
        in
        mkconstr foreign_type ~args:[var]
      in
      let make_r_constr label typ =
        let name = mkloc (String.capitalize label.pld_name.txt) in
        let res_type = match Attribute.get attr_subquery label with
          | None -> label.pld_type
          | Some mod_name -> type_of_module Res_type.type_name mod_name
        in
        (* Replace type variable of current field by the actual type when requested *)
        let res_params = replace_var_by_type params typ res_type in
        let res = Some (mkres res_params) in
        (* Type of the siblings field in the arg record *)
        let sibling_type =
          mkres (replace_var_by_type params typ ([%type: unit]))
        in
        (* Siblings field in the arg record *)
        let sibling_field =
          B.label_declaration ~name:(mkloc siblings_name) ~mutable_:Immutable
            ~type_:sibling_type
        in
        let args =
          match Attribute.get attr_subquery label with
          | None -> (* no subquery attribute *) Pcstr_record [sibling_field]
          | Some mod_name ->
            let typ = type_of_module type_name mod_name in
            let subquery_field =
              B.label_declaration ~name:(mkloc subquery_name)
                ~mutable_:Immutable ~type_:typ
            in
            Pcstr_record [sibling_field; subquery_field]
        in
        B.constructor_declaration ~name ~args ~res
      in
      (* Empty constructor, with only units *)
      let empty =
        let name = mkloc empty_field in
        let args = Pcstr_tuple [] in
        let res_params = List.map params ~f:(fun _ -> [%type: unit]) in
        let res = Some (mkres res_params) in
        B.constructor_declaration ~name ~args ~res
      in
      let constructors = empty :: (List.map2_exn fields params ~f:make_r_constr)
      in
      (* Assemble all *)
      let kind = Ptype_variant constructors in
      let typedecl = B.type_declaration ~name ~cstrs:[]
          ~params:params' ~kind ~private_:Public ~manifest:None in
      B.pstr_type Recursive [typedecl]
  end

  let module_name = "Gql"

  (* Derive a whole module from the type declaration *)
  let derive_type 
    (td : type_declaration) (rec_fields : label_declaration list)
    ~fields ~mutations =
    ignore mutations; ignore fields;
    (* Create type variables for each field of the record *)
    let params = List.map rec_fields ~f:(fun label -> B.ptyp_var label.pld_name.txt)
    in
    (* Create types *)
    let r_type = R_type.make rec_fields params in
    let res_type = Res_type.make () in
    let query_type = Query_type.make td rec_fields params in
    let out_type = Out_type.make () in
    let all_items = [r_type; res_type; out_type; query_type] in
    (* Make module with created items *)
    let expr = B.pmod_structure all_items in
    let module_binding = B.module_binding ~name:(mkloc module_name) ~expr in
    Result.return [B.pstr_module module_binding]
    
end

(** Return the list of the names of values defined in a module. *)
let names_of_values_in_module str =
  List.map str ~f:(fun str_item ->
      match str_item.pstr_desc with
      | Pstr_value (_, vbs) ->
        List.filter_map vbs ~f:(fun {pvb_pat; _} -> match pvb_pat.ppat_desc with
            | Ppat_var {txt; _} -> Some txt
            | _ -> None
          )
      | _ -> []
    )
  |> List.concat

(** Check that the Fields submodule defines a value for each field of the record *)
let check_fields rec_fields fields =
  (* Set of names from record definition *)
  let rec_field_names =
    List.map rec_fields ~f:(fun x -> x.pld_name.txt)
    |> Set.of_list (module String)
  in
  let (mod_expr, fields) = fields in
  (* Set of names of values from the Fields submodule *)
  let fields_names = names_of_values_in_module fields
                     |> Set.of_list (module String)
  in
  (* Compute difference between the two: should be empty *)
  let missing = Set.diff rec_field_names fields_names in
  if Set.is_empty missing then Result.return ()
  else (
    let loc = mod_expr.pmod_loc in
    let missing_str = Set.sexp_of_m__t (module String) missing |>
                      Sexp.to_string_hum in
    let msg = Printf.sprintf "There must be one field value in the Fields
    submodule for each field in the definition of type t. Missing: %s."
        missing_str
    in Result.fail (loc, msg)
  )

(* Detect deriver calls on record type declarations, and generate the derivation *)
let impl_generator ~fields ~mutations type_decl =
  let td = type_decl in
  let loc = td.ptype_loc in
  match td.ptype_kind with
  | Ptype_record rec_fields ->
    let* () = check_fields rec_fields fields in
    let builder = Ast_builder.make loc in
    let module B = (val builder : Ast_builder.S) in
    let module T = Make(B) in
    T.derive_type td rec_fields ~mutations ~fields
  | _ -> Result.fail (loc, "Type t must be a record type.")

(** In a structure, find a type declaration for a type named [name] *)
let find_type structure name =
  let f str_item = match str_item.pstr_desc with
    | Pstr_type (_, tds) ->
      List.find tds ~f:(fun {ptype_name = {txt;_}; _} -> String.(txt = name))
    | _ -> None
  in
  List.find_map structure ~f

(** In a structure, find an explicit module declaration
 * for a module named [name] *)
let find_module structure name =
  let f str_item = match str_item.pstr_desc with
    | Pstr_module {pmb_name = {txt; _};
                   pmb_expr = {pmod_desc = Pmod_structure s; _} as e;
                   _ } when String.(txt = name) -> Some (e, s)
    | _ -> None
  in
  List.find_map structure ~f

(** Check the payload is valid, and pass important parts to the generator.
    Returns the payload itself, plus the generated items *)
let ppx_entrypoint ~ctxt payload =
  let module B = Ast_builder.Default in
  let loc = Expansion_context.Extension.extension_point_loc ctxt in
  let make_error loc msg =
    let ext =
      Location.Error.createf ~loc "%s" msg
      |> Location.Error.to_extension
    in
    [Ast_builder.Default.pstr_extension ~loc ext []] |> B.pmod_structure ~loc
  in
  let go () =
    let* fields = Result.of_option (find_module payload "Fields")
        ~error:(loc, "A submodule Fields is required in the module, but was not found.")
    in
    let* type_decl = Result.of_option (find_type payload "t")
        ~error:(loc, "A base type t is required in the module, but was not found.")
    in
    let mutations = find_module payload "Mutations" in
    let* generated_items = impl_generator type_decl ~fields ~mutations in
    let items = payload @ generated_items in
    B.pmod_structure ~loc items |> Result.return
  in match go () with
  | Ok x -> x
  | Error (loc, msg) -> make_error loc msg

let extension =
  Extension.V3.declare
    "derive_graphql"
    Extension.Context.module_expr
    Ast_pattern.(pstr __)
    ppx_entrypoint

let rule = Context_free.Rule.extension extension

(* Register the deriver *)
let graphql2_rewriter =
  Driver.register_transformation ~rules:[rule] "graphql2"
