# SkyrimNet Swirling Malice

フォロワーの一人にクロスヘアを合わせ、MCM の「見ているフォロワーを登録」を押して、支配者として登録する。ジャーナルに、その人の名前のクエストが付く。

二人きりになると、支配者はプレイヤーを自分のものにすると告げ、シーンが始まる。終わると、もう一人をだまして連れてくるよう命じる。

室内に大人を一人連れてくると、支配者はその人を自分のものだと宣言し、シーンの開始と同時に記録する。一人の支配者につき10人まで。支配者は5人まで。

牢屋のある都市では、濡れ衣を着せる相手と会話して、大人一人に盗みの濡れ衣を着せる。同じ場所の衛兵が逮捕し、牢屋へ連れていく。衛兵がいなければ、そこにいる別の大人が連れていく。牢屋ではシーンが再生され、24時間で釈放される。

セリフは SkyrimNet が話します。シーンは初期設定では OStim、MCM で SexLab にも切り替えられます。

https://github.com/nightlantern-mods/skyrimnet_SwirlingMalice

Aim the crosshair at one follower, then press "Register the follower you are looking at" in the MCM to make them a dominant. A journal quest in their name is added.

Be alone with them. They claim you, and a scene starts. After it, they order you to deceive someone else and bring that person to them.

Bring one adult indoors. The dominant declares that person theirs, and the person is recorded when the scene starts. Ten people per dominant, five dominants.

In a city with a jail, talk to one adult and frame them for theft. A guard in the same place arrests them and takes them to jail. If no guard is there, another adult nearby takes them. A scene plays in the jail, and they are released after 24 hours.

SkyrimNet speaks the lines. Scenes use OStim by default, or SexLab from the MCM.

https://github.com/nightlantern-mods/skyrimnet_SwirlingMalice

Version 0.1.0. First public release.

Repository: https://github.com/nightlantern-mods/skyrimnet_SwirlingMalice

リポジトリ: https://github.com/nightlantern-mods/skyrimnet_SwirlingMalice

For Skyrim Special Edition. Register the follower under the crosshair as a dominant. Up to five dominants, and each keeps a separate record of up to ten people. In a city with a jail, one dialogue choice frames one adult. Children are not registered and are not framed. Guards are not framed. SkyrimNet speaks the lines. The MCM chooses whether OStim or SexLab plays the scene. The default is OStim.

The plugin is light (the ESL flag is set) and its only master is Skyrim.esm. It can be added to a save that does not already contain it.

## Requirements

| Mod | Notes |
|---|---|
| Skyrim Special Edition | The plugin is built for Skyrim SE. Its only master is Skyrim.esm. |
| [SKSE64](https://skse.silverlock.org/) | Menus, crosshair, mod events, display names. |
| [SkyrimNet](https://github.com/MinLL/SkyrimNet-GamePlugin) | `SkyrimNetApi.DirectNarration`, and the events `SkyrimNet_AudioStarted` and `SkyrimNet_AudioEnded`. The project files do not name a minimum version. |
| [OStim Standalone](https://www.nexusmods.com/skyrimspecialedition/mods/98163) (`OStim.esp`) or SexLab (`SexLab.esm`) | The MCM chooses one. The default is OStim. If the one you pick is missing, the scene does not start. See the note under this table. |
| [SkyUI](https://www.nexusmods.com/skyrimspecialedition/mods/12604) | The MCM page. |
| [MCM Helper](https://www.nexusmods.com/skyrimspecialedition/mods/53000) | `SSM_Main` extends `MCM_ConfigBase`. `config.json` sets `minMcmVersion` to 9. |
| [PapyrusUtil SE](https://www.nexusmods.com/skyrimspecialedition/mods/13048) | `MiscUtil.ScanCellNPCs` and `StorageUtil` FormLists. The slave record is kept in that FormList and is saved with the game save (the SKSE co-save), not in a settings file. |

`SSM_Scene` names script types from both OStim (`OThreadBuilder`, `OFurniture`, `OThread`, `OActor`) and SexLab (`SexLabFramework`, `SexLabUtil`, `SexLabThread`) in the same file. Before it branches, it calls `OFurniture.FindFurniture`. Papyrus loads a script only when every type that script names is present. The project files do not record which SexLab version supplies `StartScene`, `GetThread`, and `GetStatus`. No address for SexLab is given here, because this project does not record one.

Optional. Nothing else stops if these are absent. Their scripts are separate files, and the main scripts do not name those types.

| Mod | What it adds |
|---|---|
| Leash (`Leash.esm`) | The arrested person can be leashed. The collar is Leash's own armor, form `0x00000D69`. It is not in this archive. |
| SkyrimNet_Leashed (`SkyrimNet_Leashed.esp`) | Tells SkyrimNet about that leash (`NotifyLeash` / `NotifyUnleash`). This is a different mod from Leash. |
| SeverActions (`SeverActions.esp`) | If that mod is holding the person, they are released in the jail. Uses its quest form `0x000D62` and its SKSE functions. |

The pages linked above are the ones already used in the author's other public readme. This project does not record a page for SexLab, Leash, SkyrimNet_Leashed, or SeverActions, so those names are not links.

## Installation

Install the archive with Mod Organizer 2 or Vortex and choose one language. The two choices install the same scripts. They differ in the plugin text and in the MCM language files.

- **English.** English plugin. All ten SkyUI language files contain English, including the file named for Japanese. A game whose language is not English still shows English in the MCM, not raw `$keys` and not Japanese.
- **Japanese.** Japanese plugin text where a Japanese line exists. The MCM is Japanese when the game language is Japanese. The other nine language files are English, so a game set to another language does not show Japanese bytes as the wrong characters.

SkyUI reads only `Interface/Translations/skyrimnet_SwirlingMalice_<language>.txt` for the game's language. Those files are UTF-16 LE with a BOM, tab-separated, which is the encoding SkyUI requires. The installer XML (`fomod/info.xml`, `fomod/ModuleConfig.xml`) is UTF-8 without a BOM, and the encoding in the first line is written in double quotes. That is the form Vortex accepts. Every path in the archive is ASCII.

Three lines stay in English even in the Japanese MCM file, because that is what the Japanese file says: the names OStim and SexLab, and the section title `Small Acts of Malice`. In the Japanese plugin, the quest name `Small Acts of Malice` and the cell name `Malice Holding` are also still English. The Japanese string list does not contain a replacement for them.

## Credits and rights

This archive contains only this mod's own plugin (`skyrimnet_SwirlingMalice.esp`), its compiled `SSM_*` scripts, the matching `SSM_*.psc` sources, its MCM Helper configuration, its SkyUI translation files, and this notice. It does not include any file from the mods named above. Install those from their own pages. Their copyright stays with their authors. Compile-only stubs are not included.

The scripts use records from Skyrim.esm by reference and do not redistribute them. Among them: the vanilla armor Prisoner's Cuffs (`PrisonerCuffsPlayer`, `0x0010E039`), the vanilla idles `OffsetBoundStandingPlayerInstant` (`0x00109837`) and `BoundStandingCut` (`0x00109B6A`), the keyword `ActorTypeNPC` (`0x00013794`), jail markers, locations, and exterior doors, and the punisher NPC's vanilla template, voice, race, class, and outfits. No Skyrim.esm mesh, texture, or animation is in this archive. The fallback animation event names `OffsetBoundStandingPlayerInstant` and `BoundStandingCut` are vanilla names, not shipped files.

The Elder Scrolls V: Skyrim is a trademark of Bethesda Softworks / ZeniMax Media. This mod is not affiliated with or endorsed by Bethesda, ZeniMax, or the authors of any mod named above.

License: the Swirling Malice project folder had no license file of its own. The `LICENSE` file in this archive is the same MIT notice as the author's other mod, skyrimnet_Brothel: Copyright (c) 2026 takafumi. That name is copied from that other mod. It was not written down in this mod's project.

## クレジットと権利

このアーカイブに入っているのは、この MOD 自身のプラグイン（`skyrimnet_SwirlingMalice.esp`）、コンパイル済みの `SSM_*` スクリプト、対応する `SSM_*.psc`、MCM Helper の設定、SkyUI の翻訳ファイル、この説明だけです。上に挙げた MOD のファイルは一つも含みません。それぞれの配布元から入手してください。それらの著作権は各作者にあります。コンパイル専用のスタブは入っていません。

必須:

- SKSE（Skyrim Script Extender）
- SkyUI
- MCM Helper
- PapyrusUtil SE（`StorageUtil` と `MiscUtil`）
- SkyrimNet（`SkyrimNetApi` と、音声イベント `SkyrimNet_AudioStarted` / `SkyrimNet_AudioEnded`）
- シーン用は OStim Standalone（`OStim.esp`）または SexLab（`SexLab.esm`）。MCM で選びます。初期値は OStim です。

シーン用スクリプト `SSM_Scene` は、OStim の型と SexLab の型を同じファイルの中で名指ししています。分岐の前に `OFurniture.FindFurniture` を呼びます。Papyrus は、スクリプトが名指しした型が揃っていないとそのスクリプトを読みません。SexLab のどの版かは、このプロジェクトのファイルには書かれていません。

任意（入っているときだけ、その部分が働きます）:

- Leash（`Leash.esm`）。逮捕した人をリードでつなぎます。首輪は Leash の防具 `0x00000D69` で、このアーカイブには入っていません。
- SkyrimNet_Leashed（`SkyrimNet_Leashed.esp`）。そのリードのことを SkyrimNet に伝えます。Leash とは別の MOD です。
- SeverActions（`SeverActions.esp`）。その MOD が捕らえている人を、牢屋で解放します。クエスト `0x000D62` と、その SKSE の関数を使います。

ゲーム本体: スクリプトは Skyrim.esm のレコードを参照するだけで、再配布はしていません。本体の防具 Prisoner's Cuffs（`0x0010E039`）、本体のアイドル `OffsetBoundStandingPlayerInstant`（`0x00109837`）と `BoundStandingCut`（`0x00109B6A`）、キーワード `ActorTypeNPC`（`0x00013794`）、各地の牢屋とそのロケーションと扉、処罰役 NPC のテンプレート・声・種族・クラス・服装です。メッシュ、テクスチャ、アニメーションは入っていません。

The Elder Scrolls V: Skyrim は Bethesda Softworks / ZeniMax Media の商標です。この MOD は Bethesda、ZeniMax、上に挙げた MOD の作者のいずれとも無関係で、承認も受けていません。

ライセンス: Swirling Malice のプロジェクトフォルダには、独自のライセンスファイルがありません。同梱の `LICENSE` は、作者の別の MOD（skyrimnet_Brothel）と同じ MIT です。Copyright (c) 2026 takafumi。この名前は、その別の MOD から写したものです。
