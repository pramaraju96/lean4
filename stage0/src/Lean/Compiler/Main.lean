/-
Copyright (c) 2022 Microsoft Corporation. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Leonardo de Moura
-/
import Lean.Compiler.Decl
import Lean.Compiler.TerminalCases
import Lean.Compiler.CSE
import Lean.Compiler.Stage1
import Lean.Compiler.Simp

namespace Lean.Compiler

/--
We do not generate code for `declName` if
- Its type is a proposition.
- Its type is a type former.
- It is tagged as `[macroInline]`.
- It is a type class instance.

Remark: we still generate code for declarations tagged as `[inline]`
and `[specialize]` since they can be partially applied.
-/
def shouldGenerateCode (declName : Name) : CoreM Bool := do
  if (← isCompIrrelevant |>.run') then return false
  if hasMacroInlineAttribute (← getEnv) declName then return false
  if (← Meta.isMatcher declName) then return false
  -- TODO: check if type class instance
  return true
where
  isCompIrrelevant : MetaM Bool := do
    let info ← getConstInfo declName
    Meta.isProp info.type <||> Meta.isTypeFormerType info.type

/--
A checkpoint in code generation to print all declarations in between
compiler passes in order to ease debugging.
The trace can be viewed with `set_option trace.Compiler.step true`.
-/
def checkpoint (stepName : Name) (decls : Array Decl) (cfg : Check.Config := {}): CoreM Unit := do
  for decl in decls do
    withOptions (fun opts => opts.setBool `pp.motives.pi false) do
      let clsName := `Compiler ++ stepName
      if (← Lean.isTracingEnabledFor clsName) then
        Lean.addTrace clsName m!"{decl.name} : {decl.type} :=\n{decl.value}"
      decl.check cfg

@[export lean_compile_stage1]
def compileStage1Impl (declNames : Array Name) : CoreM (Array Decl) := do
  let declNames ← declNames.filterM shouldGenerateCode
  if declNames.isEmpty then return #[]
  let decls ← declNames.mapM toDecl
  checkpoint `init decls { terminalCasesOnly := false }
  let decls ← decls.mapM (·.terminalCases)
  checkpoint `terminalCases decls
  let decls ← decls.mapM (·.simp)
  checkpoint `simp decls
  -- Remark: add simplification step here, `cse` is useful after simplification
  let decls ← decls.mapM (·.cse)
  checkpoint `cse decls
  saveStage1Decls decls
  return decls

/--
Run the code generation pipeline for all declarations in `declNames`
that fulfill the requirements of `shouldGenerateCode`.
-/
def compile (declNames : Array Name) : CoreM Unit := do profileitM Exception "compiler new" (← getOptions) do
  discard <| compileStage1Impl declNames

builtin_initialize
  registerTraceClass `Compiler
  registerTraceClass `Compiler.init (inherited := true)
  registerTraceClass `Compiler.terminalCases (inherited := true)
  registerTraceClass `Compiler.simp (inherited := true)
  registerTraceClass `Compiler.cse (inherited := true)

end Lean.Compiler
