-module(vectorCtest).
-include_lib("eunit/include/eunit.hrl").


init_test() -> ok.


myVTid_test() -> 
    VT = {1, [0]},
    1 = vectorC:myVTid(VT).

myVTvc_test() -> 
    VT = {1, [0]},
    [0] = vectorC:myVTvc(VT).

myCount_test() -> 
    VT1 = {1, [0]},
    0 = vectorC:myCount(VT1),
    VT2 = {2, [0, 1]}, 
    1 = vectorC:myCount(VT2).

foCount_test() -> 
    VT = {2, [0,1,2,3,4]},
    3 = vectorC:foCount(4, VT), 
    0 = vectorC:foCount(10, VT), 
    wrongIndexJ = vectorC:foCount(0, VT).

isVT_test() ->     
    VT1 = {1, [0]},
    true = vectorC:isVT(VT1),
    VT2 = {2, [0, 1]}, 
    true = vectorC:isVT(VT2), 
    false = vectorC:isVT({1,0}),
    false = vectorC:isVT({1, {0}}), 
    false = vectorC:isVT({2, [0]}).


syncVT_test() -> 
    VT1 = {1, [0]},
    VT2 = {2, [0,1]}, 
    {1, [0,1]} = vectorC:syncVT(VT1, VT2),
    VT11 = {1, [0,0,0,0,0,0,0,0,0,0]},
    VT22 = {2, [0,1,2,3,4]}, 
    {1, [0,1,2,3,4,0,0,0,0,0]} = vectorC:syncVT(VT11, VT22).

tickVT_test() -> 
    VT = {1, [0]}, 
    {1, [1]} = vectorC:tickVT(VT).

compVT_test() -> 
    VT12 = {1, [1,2]},
    VT21 = {2, [2,1]}, 
    concurrentVT = vectorC:compVT(VT12, VT21),
    VT34 = {2, [3,4]}, 
    VT340 = {2, [3,4,0]}, 
    beforeVT = vectorC:compVT(VT12, VT34),
    afterVT = vectorC:compVT(VT34, VT12),
    equalVT = vectorC:compVT(VT34, VT340),
    beforeVT = vectorC:compVT(VT12, VT340),
    afterVT = vectorC:compVT(VT340, VT12),
    beforeVT = vectorC:compVT(VT12, VT340),
    VT03 = {2,[0,3]},
    VTR =  {1,[1]},
    concurrentVT = vectorC:compVT(VT03, VTR), 
    VTJ = [0,5],
    VTL = [],
    wrongInput = vectorC:compVT(VTJ, VTL).

aftereVTJ_test() -> 
    VT1 = {2,[0,0]},
    VTR1 = {1,[1]},
    {aftereqVTJ, -1} = vectorC:aftereqVTJ(VT1, VTR1),
    B_VT = {4,[0,0,0,2]},
    HBQ = {6,[0,0,0,0,0,1]},
    {aftereqVTJ, -1} = vectorC:aftereqVTJ(B_VT, HBQ),
    VT_concurrent = {2, [1,2]},
    VT12 = {2, [1,2]},
    VT_before = {3, [0,0,0]},
    VT21_hbq = {1, [2,1]}, 
    {aftereqVTJ, -1} = vectorC:aftereqVTJ(VT_concurrent, VT21_hbq),
    false = vectorC:aftereqVTJ(VT_before, VT21_hbq),
    VT_after = {1, [2,3,4]},
    {aftereqVTJ, 1} = vectorC:aftereqVTJ(VT_after, VT12),
    VT_actual = {1,[0]},
    VT_hbq = {2,[0,1]},
    {aftereqVTJ, -1} = vectorC:aftereqVTJ(VT_actual,VT_hbq), 
    VT03 = {2,[0,3]},
    VTR =  {1,[1]},
    {aftereqVTJ, -1} = vectorC:aftereqVTJ(VT03, VTR), 
    {aftereqVTJ, -3} = vectorC:aftereqVTJ(VTR, VT03),
    VT2 = {3, [2,3,2]},
    VTR2 = {1, [2,3,1,3]},
    false = vectorC:aftereqVTJ(VT2, VTR2).

