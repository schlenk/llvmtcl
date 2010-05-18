lappend auto_path .
package require llvmtcl

namespace import llvmtcl::*

LLVMLinkInJIT
LLVMInitializeNativeTarget

set m [LLVMModuleCreateWithName "testmodule"]
set bld [LLVMCreateBuilder]

set ft [LLVMFunctionType [LLVMInt32Type] [list [LLVMInt32Type]] 0]
set fac [LLVMAddFunction $m "fac" $ft]

# Create constants
set two [LLVMConstInt [LLVMInt32Type] 2  0]
set one [LLVMConstInt [LLVMInt32Type] 1  0]

# Create the basic blocks
set entry [LLVMAppendBasicBlock $fac entry]
set exit_lt_2 [LLVMAppendBasicBlock $fac exit_lt_2]
set recurse [LLVMAppendBasicBlock $fac recurse]

# Put arguments on the stack to avoid having to write select and/or phi nodes
LLVMPositionBuilderAtEnd $bld $entry
set arg0_1 [LLVMGetParam $fac 0]
set arg0_2 [LLVMBuildAlloca $bld [LLVMInt32Type] arg0]
set arg0_3 [LLVMBuildStore $bld $arg0_1 $arg0_2]
# Compare input < 2
set arg0_4 [LLVMBuildLoad $bld $arg0_2 "n"]
set cc [LLVMBuildICmp $bld LLVMIntSLT $arg0_4 $two "cc"]
# Branch
LLVMBuildCondBr $bld $cc $exit_lt_2 $recurse
# If n < 2, return 1
LLVMPositionBuilderAtEnd $bld $exit_lt_2
LLVMBuildRet $bld $one
# If >= 2, return n*fac(n-1)
LLVMPositionBuilderAtEnd $bld $recurse
set arg0_5 [LLVMBuildLoad $bld $arg0_2 "n"]
set arg0_minus_1 [LLVMBuildSub $bld $arg0_5 $one "arg0_minus_1"]
set fc [LLVMBuildCall $bld $fac [list $arg0_minus_1] "rec"]
set rt [LLVMBuildMul $bld $arg0_5 $fc "rt"]
LLVMBuildRet $bld $rt
# Done

# Function doing fac(10)
set ft [LLVMFunctionType [LLVMInt32Type] [list] 0]
set fac10 [LLVMAddFunction $m "fac10" $ft]
set ten [LLVMConstInt [LLVMInt32Type] 10 0]
set main [LLVMAppendBasicBlock $fac10 main]
LLVMPositionBuilderAtEnd $bld $main
set rt [LLVMBuildCall $bld $fac [list $ten] "rec"]
LLVMBuildRet $bld $rt


#puts "Input"
#puts [LLVMModuleDump $m]
LLVMWriteBitcodeToFile $m fac.bc






#set vrt [LLVMTclVerifyModule $m LLVMPrintMessageAction]
#puts "Verify: $vrt"

lassign [LLVMCreateJITCompilerForModule $m 0] rt EE msg
set i [LLVMCreateGenericValueOfInt [LLVMInt32Type] 4 0]
set res [LLVMRunFunction $EE $fac $i]
puts "res=$res=[LLVMGenericValueToInt $res 0]"
set res [LLVMRunFunction $EE $fac10 {}]
puts "res=$res=[LLVMGenericValueToInt $res 0]"

puts [time {LLVMRunFunction $EE $fac10 {}} 100]

LLVMOptimizeModule $m 3 0 1 1 1 0

#puts "Optimized"
#puts [LLVMModuleDump $m]
LLVMWriteBitcodeToFile $m fac-optimized.bc

puts [time {LLVMRunFunction $EE $fac10 {}} 100]
