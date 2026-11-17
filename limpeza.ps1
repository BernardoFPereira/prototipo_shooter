# limpeza.ps1 - remove arquivos nao usados do projeto (gerado pelo Claude em 17/11/2026)
# Rode pelo limpeza.bat com o Godot FECHADO. Tudo continua recuperavel pelo historico do Git.
$ErrorActionPreference = "Continue"
$root = $PSScriptRoot
Set-Location -LiteralPath $root

if (Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like "Godot*" }) {
    Write-Host "O Godot esta aberto. Feche o Godot e rode de novo." -ForegroundColor Red
    Read-Host "Enter para sair"; exit 1
}
if (-not (Test-Path -LiteralPath (Join-Path $root "project.godot"))) {
    Write-Host "project.godot nao encontrado - o script precisa estar na raiz do projeto." -ForegroundColor Red
    Read-Host "Enter para sair"; exit 1
}

$lista = @"
Claude outputs\arrows.png
Claude outputs\assistant_box_test.png
Claude outputs\boxes.png
Claude outputs\load.png
Claude outputs\menu.png
Claude outputs\sheet.png
Claude outputs\shield_break_test.png
Claude outputs\trash.png
Lev9FC.tmp
LevB9FF.tmp
LevCE8E.tmp
Scenes\Assets\BlockoutMeshLib.tres
Scenes\Assets\BlockoutMeshLib.tscn
Scenes\Assets\TestCube.glb
Scenes\Assets\ZoneMeshLib.tres
Scenes\Assets\export_presets.cfg
Scenes\Assets\scale.glb
Scenes\Assets\zone_mesh_lib.tscn
Scenes\Maps\.idea\.gitignore
Scenes\Maps\.idea\copilot.data.migration.ask2agent.xml
Scenes\Maps\.idea\encodings.xml
Scenes\Maps\.idea\indexLayout.xml
Scenes\Maps\.idea\vcs.xml
Scenes\Maps\Arena.tscn
Scenes\Maps\BlockoutLevel.tscn
Scenes\Maps\Con18B3.tmp
Scenes\Maps\ConEF33.tmp
Scenes\Maps\ContainedLevel.tscn
Scenes\Maps\Diorama_Lab.tscn
Scenes\Maps\Diorama_Level03_Vert.tscn
Scenes\Maps\Lev6D92.tmp
Scenes\Maps\Level.tscn
Scenes\Maps\Level01_Lab.gd
Scenes\Maps\Level01_Lab_BOX.tscn
Scenes\Maps\Level02_TrashComp_Blocking.tscn
Scenes\Maps\Level02_TrashComp_OLD.tscn
Scenes\Maps\Level03_Vert_BOX.tscn
Scenes\Maps\Level03_Vert_OLD.tscn
Scenes\Maps\Level03_Vert_OLDER.tscn
Scenes\Maps\Level04_Arena_BOX.tscn
Scenes\Maps\Level05_LiminalCrevices.tscn
Scenes\Maps\LevelLayout.tscn
Scenes\Maps\SandboxLevel.tscn
Scenes\Maps\ShipLevel.tscn
UI\ConfigMenu\COLCHETE 1.png
UI\ConfigMenu\COLCHETE 2.png
UI\ConfigMenu\COLCHETE 3.png
UI\ConfigMenu\F_CONFIG PAUSE.png
UI\ConfigMenu\_old\v2 CONFIG BASE (COMPLETA).png
UI\ConfigMenu\_old\v2_btn_off.png
UI\ConfigMenu\_old\v2_btn_on.png
UI\ConfigMenu\_old\v2_btn_tick.png
UI\ConfigMenu\v2_btn_bar.png
UI\ConfigMenu\v2_btn_res_selection.png
UI\ConfigMenu\v2_btn_tick.png
UI\Controls\MAIN MENU CONTROLE A BASE.png
UI\Controls\MAIN MENU CONTROLE A GUIDE.png
UI\Controls\_old\v2 CONTROLES A BASE.png
UI\Controls\_old\v2 CONTROLES A GUIDELINES.png
UI\Controls\_old\v2 CONTROLES B BASE.png
UI\Fonts\zx_spectrum-7.ttf
UI\Fonts\zx_spectrum-7_bold.ttf
UI\GameOver\BOTÃO C 1.png
UI\GameOver\BOTÃO C 2.png
UI\GameOver\BOTÃO D 1.png
UI\GameOver\GAMEOVER GUIDE.png
UI\GameOver\_old\v2 GAMEOVER BASE 2.0.png
UI\GameOver\go_theme.tres
UI\MainMenu\Buttons\BOTÃO B 1.png
UI\MainMenu\Buttons\BOTÃO B 2.png
UI\MainMenu\Buttons\BOTÃO C 1.png
UI\MainMenu\Buttons\BOTÃO C 2.png
UI\MainMenu\F_CONFIG MENU.png
UI\MainMenu\MAIN MENU NO TEXT GUIDE.png
UI\MainMenu\UI_HandClosed-2x.png
UI\MainMenu\UI_HandClosed-3x.png
UI\MainMenu\UI_HandClosed-4x.png
UI\MainMenu\UI_HandClosed.png
UI\MainMenu\UI_HandOpen-2x.png
UI\MainMenu\UI_HandOpen-3x.png
UI\MainMenu\UI_HandOpen-4x.png
UI\MainMenu\UI_HandOpen.png
UI\MainMenu\UI_SliderChecked-4x.png
UI\MainMenu\UI_SliderUnchecked-2x.png
UI\MainMenu\UI_SliderUnchecked-4x.png
UI\MainMenu\UI_VolumeOff1.png
UI\MainMenu\UI_VolumeOn1.png
UI\MainMenu\_old\botão v2.png
UI\MainMenu\_old\v2 BACKGROUND PLACEHOLDER.png
UI\MainMenu\_old\v2 CURSOR A.png
UI\MainMenu\_old\v2 CURSOR B.png
UI\MainMenu\_old\v2 MAIN MENU BASE.png
UI\MainMenu\_old\v2 MAIN MENU GUIDELINES.png
UI\MainMenu\_old\v2_btn_config.png
UI\MainMenu\_old\v2_btn_config_selected.png
UI\MainMenu\_old\v2_btn_controles.png
UI\MainMenu\_old\v2_btn_controles_selected.png
UI\MainMenu\_old\v2_btn_creditos.png
UI\MainMenu\_old\v2_btn_creditos_selected.png
UI\MainMenu\_old\v2_btn_jogar.png
UI\MainMenu\_old\v2_btn_jogar_selected.png
UI\MainMenu\_old\v2_btn_sair.png
UI\MainMenu\_old\v2_btn_sair_selected.png
UI\NextLevel\NÍVEL CONCLUÍDO GUIDE.png
UI\NextLevel\_old\v2 NÍVEL CONCLUIDO GUIDELINES.png
UI\PauseMenu\PAUSE GUIDE.png
UI\PauseMenu\_old\v2 JOGO PAUSADO BASE.png
UI\PauseMenu\_old\v2 JOGO PAUSADO GUIDELINES.png
UI\PauseMenu\_old\v2_btn_reiniciar.png
UI\PauseMenu\_old\v2_btn_reiniciar_selected.png
UI\PauseMenu\_old\v2_btn_retomar.png
UI\PauseMenu\_old\v2_btn_retomar_selected.png
UI\QuitGame\v2 SAIR DO JOGO BASE.png
UI\QuitGame\v2 SAIR DO JOGO GUIDELINES.png
UI\QuitGame\v2_btn_sim.png
UI\QuitGame\v2_btn_sim_selected.png
UI\V2\Background\MatrixDustBackground.tscn
UI\V2\HUD\2DGlowShader.tres
UI\V2\HUD\Enemy\rotating_and_glow.tres
UI\V2\HUD\Player\line-scan-overlay.avif
UI\V2\HUD\Player\settings_panel.gd
UI\V2\HUD\hud-sketch.png
assets\icons\icon bixo.png
assets\icons\icon mao 2.png
assets\icons\icon mao.png
assets\sounds\ambience\Ambience, Designed, Factory, Heavy Mechanics, Huge Reverb, Deep 01 SND37239.wav
assets\sounds\ambience\Ambience, Underwater, Small Bubbles 02 SND46342.wav
assets\sounds\ambience\Ambience, Warfare, Battlefield, Sci-fi, Distant, Low Intensity 03 SND28475.wav.import
assets\sounds\ambience\Designed, Drone, Abstract Machinery, Static 02 SND12650.wav
assets\sounds\ambience\Designed, Drone, Abstract, Morphing, Evolving SND12655.wav
assets\sounds\ambience\Designed, Drone, Dark, Eerie Movement, Creepy, Evil, Horror SND115864.wav
assets\sounds\ambience\Machines, Antique, Printing Press, Heidelberg OHZ, Engine On SND69409.wav
assets\sounds\ambience\Metal, Friction, Object Scrape On Pan Lid, Pitched Down, Horror SND19844.wav
assets\sounds\ambience\Scifi, Computer, Code Fail, Various Styles, Glitch, Tonal, Error SND7213.wav
assets\sounds\ambience\Scifi, Computer, Glitch Or Malfunction SND32463.wav
assets\sounds\hud\8BIT-VozMedia.wav
assets\sounds\sfx\SFX_hoverThruster_old.wav
assets\sounds\sfx\hit_impacts\SFX_BlastHitPlayer.wav
assets\sounds\sfx\hit_impacts\SFX_BlasterHitGround.wav
assets\sounds\sfx\hit_impacts\SFX_BlasterHitPlayer.wav
assets\sounds\sfx\peaks\SFX_hoverThruster.wav.reapeaks
assets\sounds\sfx\player\arm_back.ogg
assets\sounds\sfx\player\peaks\arm_back.ogg.reapeaks
entities\assistant\assistant_text_area.tscn
entities\enemies\MeleeEnemy\.idea\.gitignore
entities\enemies\MeleeEnemy\.idea\copilot.data.migration.ask2agent.xml
entities\enemies\MeleeEnemy\.idea\encodings.xml
entities\enemies\MeleeEnemy\.idea\indexLayout.xml
entities\enemies\MeleeEnemy\.idea\projectSettingsUpdater.xml
entities\enemies\MeleeEnemy\.idea\vcs.xml
entities\enemies\MeleeEnemy\.idea\workspace.xml
entities\enemies\RangedEnemy\.idea\.gitignore
entities\enemies\RangedEnemy\.idea\copilot.data.migration.ask2agent.xml
entities\enemies\RangedEnemy\.idea\encodings.xml
entities\enemies\RangedEnemy\.idea\indexLayout.xml
entities\enemies\RangedEnemy\.idea\projectSettingsUpdater.xml
entities\enemies\RangedEnemy\.idea\vcs.xml
entities\enemies\RangedEnemy\.idea\workspace.xml
entities\enemies\RangedEnemy\ranged_enemy_01.glb
entities\enemies\RangedEnemy\ranged_enemy_01.tscn
entities\funcs.gdshaderinc
entities\healthkits\healthpickup.tscn
entities\player\pause_menu.gd
entities\player\pla14C3.tmp
entities\player\pla1E0F.tmp
entities\player\plaF58E.tmp
entities\player\playerRadar.tscn
entities\sword\arm_projectile.tscn
materials\Prototype\LabGlass.tres
materials\Prototype\default_green.tres
materials\enemy_mockups\damaged_enemy.tres
materials\enemy_mockups\standard_enemy.tres
materials\mapmaterials\DioramaMats\DioramaTEX\level3\plategraytorncables.png
materials\mapmaterials\DioramaMats\DioramaTEX\level3\platewallslgreens.png
materials\mapmaterials\DioramaMats\DioramaTEX\level3\platewalltransparent.png
materials\mapmaterials\DioramaMats\DioramaTEX\texcube_low_cubotex_mtl_Metallic.1001.png
materials\mapmaterials\glassmat.tres
materials\mapmaterials\scanlines1.tres
materials\platform\platformmov_mtl.002.tres
materials\platform\thrustercover_mtl.002.tres
materials\testmats\testmat1.tres
materials\testmats\testmat3.tres
models\ST_assetsCenario_imported\ST_bau_grp.glb
models\ST_assetsCenario_imported\ST_caixaFusiveis.glb
models\ST_assetsCenario_imported\ST_caixaGrande.glb
models\ST_assetsCenario_imported\ST_caixaPequena.glb
models\ST_assetsCenario_imported\ST_capsulaEncubadora01.glb
models\ST_assetsCenario_imported\ST_ficaoComSeparador_grp.glb
models\ST_assetsCenario_imported\ST_fioQuina.glb
models\ST_assetsCenario_imported\ST_fioRetoCurto.glb
models\ST_assetsCenario_imported\ST_fioRetoLngo01.glb
models\ST_assetsCenario_imported\ST_fioRetoLngo02.glb
models\ST_assetsCenario_imported\ST_gancho.glb
models\ST_assetsCenario_imported\ST_manilhaPura.glb
models\ST_assetsCenario_imported\ST_manilhaPura_ST_encanamentoPuro_Cenario_lambert2_BaseColor.png
models\ST_assetsCenario_imported\ST_manilhaRosca.glb
models\ST_assetsCenario_imported\ST_manilhaRosca_St_roscaDoEncanamento_Cenario_lambert2_BaseColor.png
models\ST_assetsCenario_imported\ST_monitorBaseSo.glb
models\ST_assetsCenario_imported\ST_monitorGrande.glb
models\ST_assetsCenario_imported\ST_monitorMedio.glb
models\ST_assetsCenario_imported\ST_monitorTelaSo.glb
models\ST_assetsCenario_imported\ST_placa.glb
models\TestCube.glb
models\blast_door.glb
models\gib_piece.glb
models\heroassets\button.glb
models\heroassets\doorscover.fbx
models\heroassets\plataformavoadora.glb
models\heroassets\plataformavoadora_platformmov_mtl_BaseColor.png
models\heroassets\plataformavoadora_thrustercover_mtl_BaseColor.png
models\heroassets\porta.glb
models\heroassets\props\Chute.glb
models\heroassets\props\Tubogrande.glb
models\heroassets\props\broken-vent01.glb
models\heroassets\props\broken-vent02.glb
models\heroassets\props\broken-vent03.glb
models\heroassets\props\floaty.glb
models\heroassets\props\plataformavoadora.glb
models\heroassets\props\tubobarra_geo.res
models\heroassets\props\tubobolha_geo.res
models\heroassets\props\tubopano_geo.res
models\heroassets\props\tubovidro_geo.res
models\heroassets\props\vent.glb
models\heroassets\props\ventparts.res.depren
models\heroassets\props\ventplane.res.depren
models\heroassets\vent_ventparts_mtl_Emissive.1001.png
models\heroassets\vent_ventparts_mtl_Height.1001.png
models\heroassets\vent_ventparts_mtl_Metallic.1001.png
models\heroassets\vent_ventparts_mtl_Normal.1001.png
models\heroassets\vent_ventparts_mtl_Roughness.1001.png
models\heroassets\vent_ventplane_mtl_BaseColor.1001.png
models\heroassets\vent_ventplane_mtl_Emissive.1001.png
models\heroassets\vent_ventplane_mtl_Height.1001.png
models\heroassets\vent_ventplane_mtl_Metallic.1001.png
models\heroassets\vent_ventplane_mtl_Normal.1001.png
models\heroassets\vent_ventplane_mtl_Roughness.1001.png
models\level2\amasso_geo.glb
models\level2\cuboide_geo.glb
models\level2\placaret_geo.glb
models\level2\placatr_geo.glb
models\level2\retang_geo.glb
models\level2\tonel_geo.glb
models\level3\Cube and DiagBevel.glb
models\level3\elevata.glb
models\level3\esteira.glb
models\level3\platforms and bevels stars.glb
models\player\PlayerArmature.glb
models\player\anims\walk_2.res
models\player\extra_anims_2.glb
models\player\extra_anims_2_John_RocketArms_Arm_mtl_BaseColor.png
models\player\extra_anims_2_John_RocketArms_Mecharms_mtl_BaseColor.png
models\player\extra_anims_2_cannontex.png
models\player\extra_anims_John_RocketArms_Arm_mtl_BaseColor.png
models\player\extra_anims_John_RocketArms_Mecharms_mtl_BaseColor.png
models\player\extra_anims_cannontex.png
models\player\player_armature.tscn
models\rubble01.glb
models\rubble02.glb
models\scale.glb
models\totem_console.glb
navmesh\containedbasement.tres
navmesh\containednavmesh.tres
navmesh\doorareamesh.tres
navmesh\glasswallarea.tres
navmesh\grounddoormesh.tres
navmesh\platmesh.tres
navmesh\standingmesh.tres
navmesh\throwmesh.tres
navmesh\tubesfloor.tres
prefabs\Breakablefloor.tscn
prefabs\ButtonSignal Objects\TubePlat.tscn
prefabs\ButtonSignal Objects\door1.tscn
prefabs\ButtonSignal Objects\door2.tscn
prefabs\ButtonSignal Objects\door3.tscn
prefabs\ButtonSignal Objects\door4.tscn
prefabs\ButtonSignal Objects\door5.tscn
prefabs\ButtonSignal Objects\movable_cube.tscn
prefabs\Level2HeroProps\moedor.tscn
prefabs\ST_cenarioPrefab\ST_bauAberto.tscn
prefabs\ST_cenarioPrefab\ST_bauFechado.tscn
prefabs\ST_cenarioPrefab\ST_caixaGrande.tscn
prefabs\ST_cenarioPrefab\ST_caixaPequena.tscn
prefabs\ST_cenarioPrefab\ST_capsulaEncubadora01.tscn
prefabs\ST_cenarioPrefab\ST_ficaoComSeparador_grp.tscn
prefabs\ST_cenarioPrefab\ST_fioQuina.tscn
prefabs\ST_cenarioPrefab\ST_fioRetoCurto.tscn
prefabs\ST_cenarioPrefab\ST_fioRetoLngo01.tscn
prefabs\ST_cenarioPrefab\ST_fioRetoLngo02.tscn
prefabs\ST_cenarioPrefab\ST_gancho.tscn
prefabs\ST_cenarioPrefab\ST_monitorBaseSo2.tscn
prefabs\ST_cenarioPrefab\ST_monitorGrande2.tscn
prefabs\ST_cenarioPrefab\ST_monitorMedio2.tscn
prefabs\ST_cenarioPrefab\ST_monitorTelaSo2.tscn
prefabs\ST_cenarioPrefab\ST_placa.tscn
prefabs\defaultsword.tscn
prefabs\finale_lights.tscn
prefabs\prefabprops\floatypieces.tscn
prefabs\prefabprops\moedor.tscn
prefabs\prefabprops\prefabsl3\elevator_platform.tscn
prefabs\prefabprops\prefabsl3\moving_platform.tscn
prefabs\prefabprops\vent.tscn
prefabs\trigger.tscn
scripts\Trigger.gd
scripts\contained_level.gd
scripts\menu_manager.gd
scripts\pause_input_handler.gd
shaders\buckshot.gdshader
shaders\explosion_cloud.tres
shaders\overlay.gdshader
shaders\test.tres
textures\Captura de tela 2026-08-30 123016.png
textures\Chute_CeilingChute_geo_ChuteBorder_mtl_BaseColor.png
textures\Chute_CeilingChute_geo_ChuteBorder_mtl_Emissive.png
textures\Chute_CeilingChute_geo_lambert27_BaseColor.png
textures\Cube and DiagBevel_block and diagonalbevel_blocksandbevel_mtl_BaseColor.png
textures\Cube and DiagBevel_block and diagonalbevel_blocksandbevel_mtl_Emissive.png
textures\ST_manilhaPura_ST_encanamentoPuro_Cenario_lambert2_BaseColor.png
textures\ST_manilhaQuina_ST_canoFiacaoCotovelo_cenario_blinn1_BaseColor.png
textures\ST_manilhaReta_ST_canoFiacaoCotovelo_cenario_blinn1_BaseColor.png
textures\ST_manilhaRosca_St_roscaDoEncanamento_Cenario_lambert2_BaseColor.png
textures\button_button_button_mtl_Metallic.1001-button_button_mtl_Roughness.png
textures\button_button_buttoncase_mtl_Roughness.png
textures\button_button_buttondtls_mtl_BaseColor_6.png
textures\button_button_mtl_Metallic.1001.png
textures\button_button_mtl_Normal.1001.png
textures\button_button_mtl_Roughness.1001.png
textures\button_buttoncase_mtl_BaseColor.1001.png
textures\button_buttoncase_mtl_Emissive.1001.png
textures\button_buttoncase_mtl_Height.1001.png
textures\button_buttoncase_mtl_Normal.1001.png
textures\button_buttondtls_mtl_Emissive.1001.png
textures\button_buttondtls_mtl_Height.1001.png
textures\button_buttondtls_mtl_Metallic.1001.png
textures\button_buttondtls_mtl_Normal.1001.png
textures\crosshairs\Crosshair 1.png
textures\crosshairs\Crosshair 2.png
textures\crosshairs\Crosshair4.png
textures\cyclopstextures\chkr_mtl_BaseColor.1001.png
textures\cyclopstextures\darkercubes_mtl_BaseColor.1001.png
textures\cyclopstextures\living quarterstexture.png
textures\cyclopstextures\mossywall1.png
textures\cyclopstextures\mossywall2.png
textures\cyclopstextures\rustbucket2.png
textures\cyclopstextures\scanlines1.png
textures\cyclopstextures\spacerock1.png
textures\cyclopstextures\tex_cube1.png
textures\cyclopstextures\tex_cube2.png
textures\cyclopstextures\tex_ground1.png
textures\cyclopstextures\tex_ground2.png
textures\cyclopstextures\tex_wall1.png
textures\cyclopstextures\tex_wall2.png
textures\cyclopstextures\tex_wall3.png
textures\elevata_elevplat_OpenElevator_mtl_BaseColor.png
textures\elevata_elevplat_OpenElevator_mtl_Emissive.png
textures\esteira_esteira monitor_lambert9_BaseColor.png
textures\lanterninha_lanterninha_standardSurface1_BaseColor.png
textures\level2textures\amasso1_geo_tonel amassado txtr.png
textures\level2textures\amasso2_geo_tonel amassado txtr.png
textures\level2textures\amasso3_geo_tonel amassado txtr.png
textures\level2textures\amasso_geo_tonel amassado txtr.png
textures\level2textures\cuboide1_geo_lixo a txtr.png
textures\level2textures\cuboide2_geo_lixo a txtr.png
textures\level2textures\cuboide3_geo_lixo a txtr.png
textures\level2textures\cuboide_geo_lixo a txtr.png
textures\level2textures\placaret1_geo_painel b txtr.png
textures\level2textures\placaret2_geo_painel b txtr.png
textures\level2textures\placaret3_geo_painel b txtr.png
textures\level2textures\placaret_geo_painel b txtr.png
textures\level2textures\placatr1_geo_painel a txtr.png
textures\level2textures\placatr2_geo_painel a txtr.png
textures\level2textures\placatr3_geo_painel a txtr.png
textures\level2textures\placatr_geo_painel a txtr.png
textures\level2textures\retang1_geo_lixo b txtr.png
textures\level2textures\retang2_geo_lixo b txtr.png
textures\level2textures\retang3_geo_lixo b txtr.png
textures\level2textures\retang_geo_lixo b txtr.png
textures\level2textures\tonel1_geo_tonel txtr.png
textures\level2textures\tonel2_geo_tonel txtr.png
textures\level2textures\tonel3_geo_tonel txtr.png
textures\level2textures\tonel_geo_tonel txtr.png
textures\mesao_Cube and DiagBevel_block and diagonalbevel_blocksandbevel_mtl_BaseColor.png
textures\mesao_button_buttondtls_mtl_BaseColor.png
textures\mesao_lanterninha_standardSurface1_BaseColor.png
textures\planealphatextures\plane1\plano1_Plano1_standardSurface1_BaseColor.png
textures\planealphatextures\plane1\plano1_Plano1_standardSurface1_Emissive.png
textures\planealphatextures\plane2\plano2_Plano2_standardSurface1_BaseColor.png
textures\planealphatextures\plane2\plano2_Plano2_standardSurface1_Emissive.png
textures\planealphatextures\plane3\plano3_Plano3_standardSurface1_BaseColor.png
textures\planealphatextures\plane3\plano3_Plano3_standardSurface1_Emissive.png
textures\planealphatextures\plane4\plano4_Plano4_standardSurface1_BaseColor.png
textures\planealphatextures\plane4\plano4_Plano4_standardSurface1_Emissive.png
textures\planealphatextures\plane5\plano5_Plano5_standardSurface1_BaseColor.png
textures\planealphatextures\plane5\plano5_Plano5_standardSurface1_Emissive.png
textures\planealphatextures\plane6\plano6_Plano6_standardSurface1_BaseColor.png
textures\planealphatextures\plane6\plano6_Plano6_standardSurface1_Emissive.png
textures\planealphatextures\plane7\plano7_Plano7_standardSurface1_BaseColor.png
textures\planealphatextures\plane7\plano7_Plano7_standardSurface1_Emissive.png
textures\planealphatextures\plano1_Plano1_standardSurface1_BaseColor.png
textures\planealphatextures\plano1_Plano1_standardSurface1_Emissive.png
textures\plano2_Plano2_standardSurface1_BaseColor.png
textures\plano2_Plano2_standardSurface1_Emissive.png
textures\plano3_Plano3_standardSurface1_BaseColor.png
textures\plano3_Plano3_standardSurface1_Emissive.png
textures\plano4_Plano4_standardSurface1_BaseColor.png
textures\plano4_Plano4_standardSurface1_Emissive.png
textures\plano5_Plano5_standardSurface1_BaseColor.png
textures\plano5_Plano5_standardSurface1_Emissive.png
textures\plano6_Plano6_standardSurface1_BaseColor.png
textures\plano6_Plano6_standardSurface1_Emissive.png
textures\plano7_Plano7_standardSurface1_BaseColor.png
textures\plano7_Plano7_standardSurface1_Emissive.png
textures\platforms and bevels stars_platforms borders and stars_level3props_mtl_BaseColor.png
textures\platforms and bevels stars_platforms borders and stars_level3props_mtl_Emissive.png
textures\propstextures\ColunaTextr\Pillar_mtl_Base_color.png
textures\propstextures\LabCapsuleTextr\Glassvat_mtl_BaseColor.png
textures\propstextures\LabCapsuleTextr\bubls_mtl_BaseColor.png
textures\propstextures\LabCapsuleTextr\bubls_mtl_Opacity.png
textures\propstextures\LabCapsuleTextr\metalbar_mtl_BaseColor.png
textures\propstextures\LabCapsuleTextr\pnl_mtl_BaseColor.png
textures\propstextures\LabCapsuleTextr\standardSurface1_BaseColor.png
textures\propstextures\LabThingTextr\bubbles_mtl_BaseColor.png
textures\propstextures\LabThingTextr\bubbles_mtl_Opacity.png
textures\propstextures\LabThingTextr\metalcap_mtl_BaseColor.png
textures\propstextures\LabThingTextr\standardSurface5_BaseColor.png
textures\propstextures\PlatformTextr\platformmov_mtl_BaseColor.png
textures\propstextures\PlatformTextr\thrustercover_mtl_BaseColor.png
textures\propstextures\PlatformTextr\thrusterfx_mtl_BaseColor.png
textures\propstextures\PlatformTextr\thrusterfx_mtl_Opacity.png
textures\propstextures\bevel_Bevel_geo_lambert26_BaseColor.png
textures\propstextures\floaty_texcube_low_cubotex_mtl_BaseColor.png
textures\propstextures\floaty_texcube_low_cubotex_mtl_Emissive.png
textures\propstextures\floaty_texcube_low_cubotex_mtl_Metallic.1001-texcube_low_cubotex_mtl_Roughness.png
textures\propstextures\floaty_texcube_low_cubotex_mtl_Roughness.png
textures\propstextures\level3textures\bigdoor_bigdoor_standardSurface1_BaseColor.png
textures\propstextures\level3textures\elevata_elevplat_OpenElevator_mtl_BaseColor.png
textures\propstextures\level3textures\elevata_elevplat_OpenElevator_mtl_Emissive.png
textures\propstextures\level3textures\maquinario_maquinario_maquina_mtl_BaseColor.png
textures\propstextures\level3textures\techdesk_techdesk_lambert29_Emissive.png
textures\propstextures\level3textures\techdesk_techdesk_lambert30_BaseColor.png
textures\propstextures\level3textures\techdesk_techdesk_lambert31_BaseColor.png
textures\propstextures\level3textures\techdesk_techdesk_lambert31_Emissive.png
textures\prototype\Dark\texture_01.png
textures\prototype\Dark\texture_02.png
textures\prototype\Dark\texture_03.png
textures\prototype\Dark\texture_05.png
textures\prototype\Dark\texture_06.png
textures\prototype\Dark\texture_07.png
textures\prototype\Dark\texture_08.png
textures\prototype\Dark\texture_09.png
textures\prototype\Dark\texture_10.png
textures\prototype\Dark\texture_11.png
textures\prototype\Dark\texture_12.png
textures\prototype\Dark\texture_13.png
textures\prototype\Green\texture_01.png
textures\prototype\Green\texture_02.png
textures\prototype\Green\texture_03.png
textures\prototype\Green\texture_04.png
textures\prototype\Green\texture_05.png
textures\prototype\Green\texture_06.png
textures\prototype\Green\texture_07.png
textures\prototype\Green\texture_08.png
textures\prototype\Green\texture_09.png
textures\prototype\Green\texture_10.png
textures\prototype\Green\texture_11.png
textures\prototype\Green\texture_12.png
textures\prototype\Green\texture_13.png
textures\prototype\Light\texture_01.png
textures\prototype\Light\texture_02.png
textures\prototype\Light\texture_03.png
textures\prototype\Light\texture_04.png
textures\prototype\Light\texture_05.png
textures\prototype\Light\texture_06.png
textures\prototype\Light\texture_07.png
textures\prototype\Light\texture_08.png
textures\prototype\Light\texture_09.png
textures\prototype\Light\texture_10.png
textures\prototype\Light\texture_11.png
textures\prototype\Light\texture_12.png
textures\prototype\Light\texture_13.png
textures\prototype\Orange\texture_01.png
textures\prototype\Orange\texture_02.png
textures\prototype\Orange\texture_03.png
textures\prototype\Orange\texture_04.png
textures\prototype\Orange\texture_05.png
textures\prototype\Orange\texture_06.png
textures\prototype\Orange\texture_07.png
textures\prototype\Orange\texture_08.png
textures\prototype\Orange\texture_09.png
textures\prototype\Orange\texture_10.png
textures\prototype\Orange\texture_11.png
textures\prototype\Orange\texture_12.png
textures\prototype\Orange\texture_13.png
textures\prototype\Purple\texture_01.png
textures\prototype\Purple\texture_02.png
textures\prototype\Purple\texture_03.png
textures\prototype\Purple\texture_04.png
textures\prototype\Purple\texture_06.png
textures\prototype\Purple\texture_07.png
textures\prototype\Purple\texture_08.png
textures\prototype\Purple\texture_09.png
textures\prototype\Purple\texture_10.png
textures\prototype\Purple\texture_11.png
textures\prototype\Purple\texture_12.png
textures\prototype\Purple\texture_13.png
textures\prototype\Red\texture_01.png
textures\prototype\Red\texture_02.png
textures\prototype\Red\texture_03.png
textures\prototype\Red\texture_04.png
textures\prototype\Red\texture_05.png
textures\prototype\Red\texture_06.png
textures\prototype\Red\texture_07.png
textures\prototype\Red\texture_08.png
textures\prototype\Red\texture_09.png
textures\prototype\Red\texture_10.png
textures\prototype\Red\texture_11.png
textures\prototype\Red\texture_12.png
textures\prototype\Red\texture_13.png
vfx\VFX_Workshop.tscn
vfx\flash2.tres
vfx\hand_propulsion_mesh.glb
vfx\hand_propulsion_mesh2.glb
vfx\hand_propulsion_mesh3.glb
vfx\pointy_projectile_mesh.glb
vfx\proprulsion_mesh.res
vfx\vortex_streaks.png
"@ -split "`r?`n" | Where-Object { $_.Trim() -ne "" }

Write-Host ("Vou APAGAR {0} arquivos (+ .import e cache importado de cada um)." -f $lista.Count) -ForegroundColor Yellow
$ok = Read-Host "Digite SIM para continuar"
if ($ok -ne "SIM") { Write-Host "Cancelado."; exit 0 }

$log = Join-Path $root "limpeza_log.txt"
"Limpeza $(Get-Date)" | Out-File -LiteralPath $log -Encoding utf8
$apagados = 0; $bytes = 0; $dirs = New-Object System.Collections.Generic.HashSet[string]

function Apagar([string]$p) {
    if (Test-Path -LiteralPath $p -PathType Leaf) {
        $script:bytes += (Get-Item -LiteralPath $p -Force).Length
        Remove-Item -LiteralPath $p -Force
        $script:apagados++
        "APAGADO  $p" | Out-File -LiteralPath $log -Append -Encoding utf8
    }
}

foreach ($rel in $lista) {
    $f = Join-Path $root $rel
    $imp = "$f.import"
    if (Test-Path -LiteralPath $imp -PathType Leaf) {
        # apaga tambem o cache em .godot/imported apontado pelo .import
        $txt = Get-Content -LiteralPath $imp -Raw -Encoding UTF8
        foreach ($m in [regex]::Matches($txt, 'res://(\.godot/imported/[^"]+)')) {
            Apagar (Join-Path $root ($m.Groups[1].Value -replace '/', '\'))
        }
        Apagar $imp
    }
    if (-not (Test-Path -LiteralPath $f)) { "NAO EXISTE $rel" | Out-File -LiteralPath $log -Append -Encoding utf8 }
    Apagar $f
    [void]$dirs.Add([System.IO.Path]::GetDirectoryName($f))
}

# remove pastas que ficaram vazias (sobe ate a raiz)
foreach ($d in ($dirs | Sort-Object Length -Descending)) {
    $cur = $d
    while ($cur -and $cur.Length -gt $root.Length -and (Test-Path -LiteralPath $cur)) {
        if ((Get-ChildItem -LiteralPath $cur -Force | Measure-Object).Count -eq 0) {
            Remove-Item -LiteralPath $cur -Force
            "PASTA    $cur" | Out-File -LiteralPath $log -Append -Encoding utf8
            $cur = [System.IO.Path]::GetDirectoryName($cur)
        } else { break }
    }
}

Write-Host ("Pronto: {0} arquivos apagados, {1:N1} MB liberados. Log em limpeza_log.txt" -f $apagados, ($bytes/1MB)) -ForegroundColor Green
Write-Host "Abra o Godot, espere reimportar e teste o jogo. Depois pode apagar limpeza.bat, limpeza.ps1 e o log."
Read-Host "Enter para sair"
