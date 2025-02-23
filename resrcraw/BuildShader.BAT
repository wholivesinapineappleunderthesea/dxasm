pushd %~dp0..
mkdir resrc
mkdir resrc\shader
bin\dxc.exe -E PS_Main -T ps_5_0 -Fo resrc\shader\def.ps.bin resrcraw\shader\def.hlsl
bin\dxc.exe -E VS_Main -T vs_5_0 -Fo resrc\shader\def.vs.bin resrcraw\shader\def.hlsl

popd