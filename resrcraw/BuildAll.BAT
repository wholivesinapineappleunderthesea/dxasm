pushd %~dp0
call BuildShader.BAT
python GenASMEmbed.py
popd