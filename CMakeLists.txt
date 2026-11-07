cmake_minimum_required(VERSION 3.16)
project(usdspec_conformance NONE)
enable_testing()

# This project has no C++ of its own: CMake is only a ctest runner for the Lean
# proofs and the conformance scripts. Implementations under test are external.
#
#   -DLIGHTUSD_ROOT=<LightUSD checkout>       (reflection table, native XID source)
#   -DLIGHTUSD_BUILD_DIR=<LightUSD build dir> (lusdcat, lusdchecker)
#   -DORACLE_PYTHON=python3.11  -DORACLE_PYTHONPATH=<dir with pxr from usd-core==26.11>
#   -DAOUSD_SUPPLEMENTAL_ROOT=<core-spec-supplemental .../releases/1.0.1>
set(LIGHTUSD_ROOT "" CACHE PATH "LightUSD source checkout")
set(LIGHTUSD_BUILD_DIR "" CACHE PATH "LightUSD build directory")
set(ORACLE_PYTHON "" CACHE STRING "Python (3.11) used with the stock OpenUSD oracle")
set(ORACLE_PYTHONPATH "" CACHE PATH "site-packages directory holding usd-core==26.11")
set(AOUSD_SUPPLEMENTAL_ROOT "" CACHE PATH "AOUSD supplemental suite root")
set(STRICT_PCP_ORACLE_DIFF 15 CACHE STRING "Strict stock-OpenUSD PCP difference ratchet (goal: 0)")
find_program(LAKE lake HINTS $ENV{HOME}/.elan/bin)
find_package(Python3 REQUIRED COMPONENTS Interpreter)

set(SRC ${CMAKE_CURRENT_SOURCE_DIR})
set(LEAN_DIR ${SRC}/verif/lean)
set(LUSDCAT ${LIGHTUSD_BUILD_DIR}/lusdcat)
set(LUSDCHECKER ${LIGHTUSD_BUILD_DIR}/lusdchecker)
if(NOT EXISTS ${LUSDCHECKER})
  set(LUSDCHECKER ${LIGHTUSD_BUILD_DIR}/checker/lusdchecker)
endif()

function(conf_test name)
  add_test(NAME ${name} COMMAND ${ARGN})
  set_tests_properties(${name} PROPERTIES LABELS "conformance" SKIP_RETURN_CODE 77)
endfunction()

# ---- Lean proofs and generated artifacts (need only elan/lake) ----
if(LAKE)
  add_test(NAME lean_build COMMAND ${LAKE} build WORKING_DIRECTORY ${LEAN_DIR})
  add_test(NAME lean_test COMMAND ${LAKE} exe usdspec-test WORKING_DIRECTORY ${LEAN_DIR})
  add_test(NAME lean_vectors_check
    COMMAND ${LAKE} exe usdspec-gen --check --out ${SRC}/tests/next/generated/lean
    WORKING_DIRECTORY ${LEAN_DIR})
  add_test(NAME lean_axioms COMMAND ${LAKE} env lean Audit/Axioms.lean WORKING_DIRECTORY ${LEAN_DIR})
  set_tests_properties(lean_build lean_test lean_vectors_check lean_axioms
    PROPERTIES LABELS "lean;proofs" TIMEOUT 3600)
  set_tests_properties(lean_test lean_vectors_check lean_axioms PROPERTIES DEPENDS lean_build)
  conf_test(lean_axiom_audit_tests ${Python3_EXECUTABLE} ${SRC}/scripts/test-lean-axioms.py --lake ${LAKE})
  if(LIGHTUSD_ROOT)
    set(UNI_ENV ${CMAKE_COMMAND} -E env LIGHTUSD_ROOT=${LIGHTUSD_ROOT})
  endif()
  conf_test(lean_unicode_conformance ${UNI_ENV} ${Python3_EXECUTABLE} ${SRC}/scripts/test-lean-unicode-data.py
    --conformance --lake ${LAKE})
  set_tests_properties(lean_unicode_conformance PROPERTIES DEPENDS lean_build TIMEOUT 600)
else()
  message(WARNING "lake not found: Lean proof tests are not registered")
endif()

# ---- Registry and documentation gates (pure Python) ----
conf_test(spec_citations ${Python3_EXECUTABLE} ${SRC}/scripts/check-lean-spec-citations.py --max-unverified 0)
conf_test(model_split ${Python3_EXECUTABLE} ${SRC}/scripts/check-lean-model-split.py)
conf_test(issue_tags bash ${SRC}/scripts/check-lean-issues.sh)
conf_test(reflection_checker_tests ${Python3_EXECUTABLE} ${SRC}/scripts/test-check-lean-reflection.py)

# ---- LightUSD cross-checks ----
if(LIGHTUSD_ROOT)
  set(ENV_LIGHTUSD ${CMAKE_COMMAND} -E env LIGHTUSD_ROOT=${LIGHTUSD_ROOT})
  conf_test(reflection_table ${ENV_LIGHTUSD} ${Python3_EXECUTABLE} ${SRC}/scripts/check-lean-reflection.py
    --check --lightusd ${LIGHTUSD_ROOT} --lusdchecker ${LUSDCHECKER})
  if(LAKE)
    conf_test(reflection_environment ${ENV_LIGHTUSD} ${Python3_EXECUTABLE}
      ${SRC}/scripts/check-lean-reflection.py --check --lightusd ${LIGHTUSD_ROOT} --lake ${LAKE})
    set_tests_properties(reflection_environment PROPERTIES DEPENDS lean_build)
  endif()
endif()

# ---- Differential conformance against LightUSD and stock OpenUSD ----
if(LIGHTUSD_BUILD_DIR AND ORACLE_PYTHON AND ORACLE_PYTHONPATH)
  set(ORACLE_ARGS --oracle-python ${ORACLE_PYTHON} --oracle-pythonpath ${ORACLE_PYTHONPATH})
  conf_test(pcp_json_contract ${Python3_EXECUTABLE} ${SRC}/tests/next/test-pcp-json.py
    --lusdcat ${LUSDCAT} ${ORACLE_ARGS})
  conf_test(primindex_vectors ${Python3_EXECUTABLE} ${SRC}/tests/next/test-prim-index-vectors.py
    --lusdcat ${LUSDCAT} ${ORACLE_ARGS})
  conf_test(layerstack_vectors ${Python3_EXECUTABLE} ${SRC}/tests/next/test-layer-stack-vectors.py
    --lusdcat ${LUSDCAT} ${ORACLE_ARGS})
  conf_test(raw_metadata ${Python3_EXECUTABLE} ${SRC}/tests/next/test-raw-metadata.py
    --lusdcat ${LUSDCAT} ${ORACLE_ARGS})
  conf_test(usda_strings ${Python3_EXECUTABLE} ${SRC}/tests/next/test-usda-strings.py
    --lusdcat ${LUSDCAT} ${ORACLE_ARGS})
  conf_test(usda_keys ${Python3_EXECUTABLE} ${SRC}/tests/next/test-usda-keys.py
    --lusdcat ${LUSDCAT} ${ORACLE_ARGS})
  if(EXISTS ${LIGHTUSD_BUILD_DIR}/test_name_order)
    conf_test(name_order ${Python3_EXECUTABLE} ${SRC}/tests/next/test-name-order.py
      --tool ${LIGHTUSD_BUILD_DIR}/test_name_order ${ORACLE_ARGS})
  endif()
  if(EXISTS ${LIGHTUSD_BUILD_DIR}/test_int64_listop)
    conf_test(listop_modes ${Python3_EXECUTABLE} ${SRC}/tests/next/test-listop-modes.py
      --tool ${LIGHTUSD_BUILD_DIR}/test_int64_listop ${ORACLE_ARGS})
  endif()
  set_tests_properties(pcp_json_contract primindex_vectors layerstack_vectors raw_metadata
    usda_strings usda_keys PROPERTIES LABELS "conformance;pcp;oracle" TIMEOUT 300)
  if(AOUSD_SUPPLEMENTAL_ROOT)
    conf_test(aousd_composition ${Python3_EXECUTABLE} ${SRC}/tests/next/run-aousd-supplemental.py
      --suite-root ${AOUSD_SUPPLEMENTAL_ROOT} --lusdcat ${LUSDCAT} --category composition
      --compare-pcp --pcp-allowlist ${SRC}/tests/next/aousd-pcp-allowlist.txt --max-pcp-diff 0
      --pcp-oracle-python ${ORACLE_PYTHON} --pcp-oracle-pythonpath ${ORACLE_PYTHONPATH}
      --pcp-diff-lines 5
      # Strict lossless comparison against stock OpenUSD has NO allowlist; it is
      # a ratchet at the currently measured 15 differing cases (of 135). Lower
      # this number whenever LightUSD improves; the goal is 0.
      --max-pcp-oracle-diff ${STRICT_PCP_ORACLE_DIFF})
    set_tests_properties(aousd_composition PROPERTIES LABELS "conformance;pcp;oracle" TIMEOUT 600)
  endif()
else()
  message(STATUS "Differential tests not registered: set LIGHTUSD_BUILD_DIR, ORACLE_PYTHON, ORACLE_PYTHONPATH")
endif()

# Local specification audit data is prepared, not distributed.
conf_test(lean_grammar_generate ${Python3_EXECUTABLE} ${SRC}/scripts/extract-usda-peg.py --lean)
set_tests_properties(lean_grammar_generate PROPERTIES LABELS "lean;source-prep" FIXTURES_SETUP local_grammar)
get_property(history_tests DIRECTORY PROPERTY TESTS)
foreach(name IN LISTS history_tests)
  if(NOT name STREQUAL "lean_grammar_generate")
    set_property(TEST ${name} APPEND PROPERTY FIXTURES_REQUIRED local_grammar)
  endif()
endforeach()
