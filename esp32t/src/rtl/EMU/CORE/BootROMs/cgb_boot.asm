;MIT License
;
;Copyright (c) 2015-2023 Lior Halphon
;
;Permission is hereby granted, free of charge, to any person obtaining a copy
;of this software and associated documentation files (the "Software"), to deal
;in the Software without restriction, including without limitation the rights
;to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;copies of the Software, and to permit persons to whom the Software is
;furnished to do so, subject to the following conditions:
;
;The above copyright notice and this permission notice shall be included in all
;copies or substantial portions of the Software.
;
;THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;SOFTWARE.

; Note:
; rBANK ($ff50) is used as special MiSTer read-only register to add OSD boot options

INCLUDE	"hardware.inc"

SECTION "BootCode", ROM0[$0]
Start:
; Init stack pointer
    ld sp, $fffe

; Clear memory VRAM
    call ClearMemoryPage8000

; Clear OAM
    ld h, $fe
    ld c, $a0
.clearOAMLoop
    ldi [hl], a
    dec c
    jr nz, .clearOAMLoop

IF !DEF(CGB0)
; Init waveform
    ld c, $10
    ld hl, $FF30
.waveformLoop
    ldi [hl], a
    cpl
    dec c
    jr nz, .waveformLoop
ENDC

; Clear chosen input palette
    ldh [InputPalette], a
; Clear title checksum
    ldh [TitleChecksum], a

; Init Audio
    ld a, $80
    ldh [rNR52], a
    ldh [rNR11], a
    ld a, $f3
    ldh [rNR12], a
    ldh [rNR51], a
    ld a, $77
    ldh [rNR50], a

; Init BG palette
    ld a, $fc
    ldh [rBGP], a

; Load logo from ROM.
; A nibble represents a 4-pixels line, 2 bytes represent a 4x4 tile, scaled to 8x8.
; Tiles are ordered left to right, top to bottom.
; These tiles are not used, but are required for DMG compatibility. This is done
; by the original CGB Boot ROM as well.
    ld de, $104 ; Logo start
    ld hl, $8010 ; This is where we load the tiles in VRAM

.loadLogoLoop
    ld a, [de] ; Read 2 rows
    ld b, a
    call DoubleBitsAndWriteRowTwice
    inc de
    ld a, e
    cp $34 ; End of logo
    jr nz, .loadLogoLoop
    call ReadTrademarkSymbol

; Clear the second VRAM bank
    ld a, 1
    ldh [rVBK], a
    call ClearMemoryPage8000
    call CheckFastBoot
    call z, LoadTileset

    ld b, 3
; Load Tilemap
    ld hl, $98C2
    ld d, 3
    ld a, 8

.tilemapLoop
    ld c, $10

.tilemapRowLoop

    call .write_with_palette
    add d ; d = 3 for CGB logo, d = 1 for Nintendo logo
    dec c
    jr nz, .tilemapRowLoop
    sub 47 ; 3*16 = 48 not 44?
    push de
    ld de, $10
    add hl, de
    pop de

    dec b ; Hit 3 times for CGB logo, then once more for Nintendo logo
    jr nz, .tilemapLoop

    dec d ; Hit twice, once at end of CGB logo, next at end of Nintendo logo
    jr z, .endTilemap
    dec d ; Prev. dec + this one takes d = 3 to d = 1

    ; Nintendo Logo
    ld a, $37    ; Offset into tile map? d is now 1 though?
    ld l, $a7
    ld bc, $0101 ; 1 row, 7 columns for Nintendo logo
    jr .tilemapRowLoop

.write_with_palette
    push af
    ; Switch to second VRAM Bank
    ld a, 1
    ldh [rVBK], a
    ld [hl], 8
    ; Switch to back first VRAM Bank
    xor a
    ldh [rVBK], a
    pop af
    ldi [hl], a
    ret
.endTilemap

    ; Expand Palettes
    ld de, AnimationColors
    ld c, 8
    ld hl, BgPalettes
    xor a
.expandPalettesLoop:
    cpl

    ; One white
    ldi [hl], a
    ldi [hl], a

    ; The actual color
    call CheckAGBPalette
    ld a, [de]
    inc de
    ldi [hl], a
    ld a, [de]
    inc de
    ldi [hl], a

    xor a
    ; Two blacks
    ldi [hl], a
    ldi [hl], a
    ldi [hl], a
    ldi [hl], a

    dec c
    jr nz, .expandPalettesLoop

    call LoadPalettesFromHRAM

    ; Turn on LCD
    ld a, $91
    ldh [rLCDC], a

    call CheckFastBoot
    jr z, .doAnimation

    ld a, $83
    call PlaySound
    ld b, 5
    call WaitBFrames
    jr .fastBoot

.doAnimation
    call DoIntroAnimation

    ld a, 1 ; frames to wait after playing the chime
    ldh [WaitLoopCounter], a
    ld b, 1 ; frames to wait before playing the chime
    call WaitBFrames

    ; Play first sound
    ld a, $83
    call PlaySound
    ld b, 5
    call WaitBFrames
    ; Play second sound
    ld a, $c1
    call PlaySound

.waitLoop
    call GetInputPaletteIndex
    ;call WaitFrame
    ld hl, WaitLoopCounter
    dec [hl]
    jr nz, .waitLoop

.fastBoot
    call Preboot
    call CheckAGB
    jr z, .cgbmode
    inc b ; AGB mode set b = 1, reset z flag
.cgbmode
    ld a, $11
    jr BootGame

HDMAData:
    db $D0, $00, $98, $A0, $12
    db $D0, $00, $80, $00, $40

SECTION "BootGame", ROM0[$fe]
BootGame:
    ldh [rBANK], a ; unmap boot ROM

SECTION "MoreStuff", ROM0[$200]
; Game Palettes Data
TitleChecksums:
    db $00 ; Default
    db $88 ; ALLEY WAY
    db $16 ; YAKUMAN
    db $36 ; BASEBALL, (Game and Watch 2)
    db $D1 ; TENNIS
    db $DB ; TETRIS
    db $F2 ; QIX
    db $3C ; DR.MARIO
    db $8C ; RADARMISSION
    db $92 ; F1RACE
    db $3D ; YOSSY NO TAMAGO
    db $5C ;
    db $58 ; X
    db $C9 ; MARIOLAND2
    db $3E ; YOSSY NO COOKIE
    db $70 ; ZELDA
    db $1D ;
    db $59 ;
    db $69 ; TETRIS FLASH
    db $19 ; DONKEY KONG
    db $35 ; MARIO'S PICROSS
    db $A8 ;
    db $14 ; POKEMON RED, (GAMEBOYCAMERA G)
    db $AA ; POKEMON GREEN
    db $75 ; PICROSS 2
    db $95 ; YOSSY NO PANEPON
    db $99 ; KIRAKIRA KIDS
    db $34 ; GAMEBOY GALLERY
    db $6F ; POCKETCAMERA
    db $15 ;
    db $FF ; BALLOON KID
    db $97 ; KINGOFTHEZOO
    db $4B ; DMG FOOTBALL
    db $90 ; WORLD CUP
    db $17 ; OTHELLO
    db $10 ; SUPER RC PRO-AM
    db $39 ; DYNABLASTER
    db $F7 ; BOY AND BLOB GB2
    db $F6 ; MEGAMAN
    db $A2 ; STAR WARS-NOA
    db $49 ;
    db $4E ; WAVERACE
    db $43 ;
    db $68 ; LOLO2
    db $E0 ; YOSHI'S COOKIE
    db $8B ; MYSTIC QUEST
    db $F0 ;
    db $CE ; TOPRANKINGTENNIS
    db $0C ; MANSELL
    db $29 ; MEGAMAN3
    db $E8 ; SPACE INVADERS
    db $B7 ; GAME&WATCH
    db $86 ; DONKEYKONGLAND95
    db $9A ; ASTEROIDS/MISCMD
    db $52 ; STREET FIGHTER 2
    db $01 ; DEFENDER/JOUST
    db $9D ; KILLERINSTINCT95
    db $71 ; TETRIS BLAST
    db $9C ; PINOCCHIO
    db $BD ;
    db $5D ; BA.TOSHINDEN
    db $6D ; NETTOU KOF 95
    db $67 ;
    db $3F ; TETRIS PLUS
    db $6B ; DONKEYKONGLAND 3
; For these games, the 4th letter is taken into account
FirstChecksumWithDuplicate:
    ; Let's play hangman!
    db $B3 ; ???[B]????????
    db $46 ; SUP[E]R MARIOLAND
    db $28 ; GOL[F]
    db $A5 ; SOL[A]RSTRIKER
    db $C6 ; GBW[A]RS
    db $D3 ; KAE[R]UNOTAMENI
    db $27 ; ???[B]????????
    db $61 ; POK[E]MON BLUE
    db $18 ; DON[K]EYKONGLAND
    db $66 ; GAM[E]BOY GALLERY2
    db $6A ; DON[K]EYKONGLAND 2
    db $BF ; KID[ ]ICARUS
    db $0D ; TET[R]IS2
    db $F4 ; ???[-]????????
    db $B3 ; MOG[U]RANYA
    db $46 ; ???[R]????????
    db $28 ; GAL[A]GA&GALAXIAN
    db $A5 ; BT2[R]AGNAROKWORLD
    db $C6 ; KEN[ ]GRIFFEY JR
    db $D3 ; ???[I]????????
    db $27 ; MAG[N]ETIC SOCCER
    db $61 ; VEG[A]S STAKES
    db $18 ; ???[I]????????
    db $66 ; MIL[L]I/CENTI/PEDE
    db $6A ; MAR[I]O & YOSHI
    db $BF ; SOC[C]ER
    db $0D ; POK[E]BOM
    db $F4 ; G&W[ ]GALLERY
    db $B3 ; TET[R]IS ATTACK
ChecksumsEnd:

PalettePerChecksum:
MACRO palette_index ; palette, flags
    db ((\1)) | (\2) ; | $80 means game requires DMG boot tilemap
ENDM
    palette_index 0, 0  ; Default Palette
    palette_index 4, 0  ; ALLEY WAY
    palette_index 5, 0  ; YAKUMAN
    palette_index 35, 0 ; BASEBALL, (Game and Watch 2)
    palette_index 34, 0 ; TENNIS
    palette_index 3, 0  ; TETRIS
    palette_index 31, 0 ; QIX
    palette_index 15, 0 ; DR.MARIO
    palette_index 10, 0 ; RADARMISSION
    palette_index 5, 0  ; F1RACE
    palette_index 19, 0 ; YOSSY NO TAMAGO
    palette_index 36, 0 ;
    palette_index 7, $80 ; X
    palette_index 37, 0 ; MARIOLAND2
    palette_index 30, 0 ; YOSSY NO COOKIE
    palette_index 44, 0 ; ZELDA
    palette_index 21, 0 ;
    palette_index 32, 0 ;
    palette_index 31, 0 ; TETRIS FLASH
    palette_index 20, 0 ; DONKEY KONG
    palette_index 5, 0  ; MARIO'S PICROSS
    palette_index 33, 0 ;
    palette_index 13, 0 ; POKEMON RED, (GAMEBOYCAMERA G)
    palette_index 14, 0 ; POKEMON GREEN
    palette_index 5, 0  ; PICROSS 2
    palette_index 29, 0 ; YOSSY NO PANEPON
    palette_index 5, 0  ; KIRAKIRA KIDS
    palette_index 18, 0 ; GAMEBOY GALLERY
    palette_index 9, 0  ; POCKETCAMERA
    palette_index 3, 0  ;
    palette_index 2, 0  ; BALLOON KID
    palette_index 26, 0 ; KINGOFTHEZOO
    palette_index 25, 0 ; DMG FOOTBALL
    palette_index 25, 0 ; WORLD CUP
    palette_index 41, 0 ; OTHELLO
    palette_index 42, 0 ; SUPER RC PRO-AM
    palette_index 26, 0 ; DYNABLASTER
    palette_index 45, 0 ; BOY AND BLOB GB2
    palette_index 42, 0 ; MEGAMAN
    palette_index 45, 0 ; STAR WARS-NOA
    palette_index 36, 0 ;
    palette_index 38, 0 ; WAVERACE
    palette_index 26, $80 ;
    palette_index 42, 0 ; LOLO2
    palette_index 30, 0 ; YOSHI'S COOKIE
    palette_index 41, 0 ; MYSTIC QUEST
    palette_index 34, 0 ;
    palette_index 34, 0 ; TOPRANKINGTENNIS
    palette_index 5, 0  ; MANSELL
    palette_index 42, 0 ; MEGAMAN3
    palette_index 6, 0  ; SPACE INVADERS
    palette_index 5, 0  ; GAME&WATCH
    palette_index 33, 0 ; DONKEYKONGLAND95
    palette_index 25, 0 ; ASTEROIDS/MISCMD
    palette_index 42, 0 ; STREET FIGHTER 2
    palette_index 42, 0 ; DEFENDER/JOUST
    palette_index 40, 0 ; KILLERINSTINCT95
    palette_index 2, 0  ; TETRIS BLAST
    palette_index 16, 0 ; PINOCCHIO
    palette_index 25, 0 ;
    palette_index 42, 0 ; BA.TOSHINDEN
    palette_index 42, 0 ; NETTOU KOF 95
    palette_index 5, 0  ;
    palette_index 0, 0  ; TETRIS PLUS
    palette_index 39, 0 ; DONKEYKONGLAND 3
    palette_index 36, 0 ;
    palette_index 22, 0 ; SUPER MARIOLAND
    palette_index 25, 0 ; GOLF
    palette_index 6, 0  ; SOLARSTRIKER
    palette_index 32, 0 ; GBWARS
    palette_index 12, 0 ; KAERUNOTAMENI
    palette_index 36, 0 ;
    palette_index 11, 0 ; POKEMON BLUE
    palette_index 39, 0 ; DONKEYKONGLAND
    palette_index 18, 0 ; GAMEBOY GALLERY2
    palette_index 39, 0 ; DONKEYKONGLAND 2
    palette_index 24, 0 ; KID ICARUS
    palette_index 31, 0 ; TETRIS2
    palette_index 50, 0 ;
    palette_index 17, 0 ; MOGURANYA
    palette_index 46, 0 ;
    palette_index 6, 0  ; GALAGA&GALAXIAN
    palette_index 27, 0 ; BT2RAGNAROKWORLD
    palette_index 0, 0  ; KEN GRIFFEY JR
    palette_index 47, 0 ;
    palette_index 41, 0 ; MAGNETIC SOCCER
    palette_index 41, 0 ; VEGAS STAKES
    palette_index 0, 0  ;
    palette_index 0, 0  ; MILLI/CENTI/PEDE
    palette_index 19, 0 ; MARIO & YOSHI
    palette_index 34, 0 ; SOCCER
    palette_index 23, 0 ; POKEBOM
    palette_index 18, 0 ; G&W GALLERY
    palette_index 29, 0 ; TETRIS ATTACK

Dups4thLetterArray:
    db "BEFAARBEKEK R-URAR INAILICE R"

; We assume the last three arrays fit in the same $100 byte page!

PaletteCombinations:
MACRO palette_comb ; Obj0, Obj1, Bg
    db (\1) * 8, (\2) * 8, (\3) *8
ENDM
MACRO raw_palette_comb ; Obj0, Obj1, Bg
    db (\1) * 2, (\2) * 2, (\3) * 2
ENDM
    palette_comb  4,  4, 29 ;  0, Right + A + B
    palette_comb 18, 18, 18 ;  1, Right
    palette_comb 20, 20, 20 ;  2
    palette_comb 24, 24, 24 ;  3, Down + A
    palette_comb  9,  9,  9 ;  4
    palette_comb  0,  0,  0 ;  5, Up
    palette_comb 27, 27, 27 ;  6, Right + B
    palette_comb  5,  5,  5 ;  7, Left + B
    palette_comb 12, 12, 12 ;  8, Down
    palette_comb 26, 26, 26 ;  9
    palette_comb 16,  8,  8 ; 10
    palette_comb  4, 28, 28 ; 11
    palette_comb  4,  2,  2 ; 12
    palette_comb  3,  4,  4 ; 13
    palette_comb  4, 29, 29 ; 14
    palette_comb 28,  4, 28 ; 15
    palette_comb  2, 17,  2 ; 16
    palette_comb 16, 16,  8 ; 17
    palette_comb  4,  4,  7 ; 18
    palette_comb  4,  4, 18 ; 19
    palette_comb  4,  4, 20 ; 20
    palette_comb 19, 19,  9 ; 21
    raw_palette_comb 4 * 4 - 1, 4 * 4 - 1, 11 * 4 ; 22
    palette_comb 17, 17,  2 ; 23
    palette_comb  4,  4,  2 ; 24
    palette_comb  4,  4,  3 ; 25
    palette_comb 28, 28,  0 ; 26
    palette_comb  3,  3,  0 ; 27
    palette_comb  0,  0,  1 ; 28, Up + B
    palette_comb 18, 22, 18 ; 29
    palette_comb 20, 22, 20 ; 30
    palette_comb 24, 22, 24 ; 31
    palette_comb 16, 22,  8 ; 32
    palette_comb 17,  4, 13 ; 33
    raw_palette_comb 28 * 4 - 1, 0 * 4, 14 * 4 ; 34
    raw_palette_comb 28 * 4 - 1, 4 * 4, 15 * 4 ; 35
    raw_palette_comb 19 * 4, 23 * 4 - 1, 9 * 4 ; 36
    palette_comb 16, 28, 10 ; 37
    palette_comb  4, 23, 28 ; 38
    palette_comb 17, 22,  2 ; 39
    palette_comb  4,  0,  2 ; 40, Left + A
    palette_comb  4, 28,  3 ; 41
    palette_comb 28,  3,  0 ; 42
    palette_comb  3, 28,  4 ; 43, Up + A
    palette_comb 21, 28,  4 ; 44
    palette_comb  3, 28,  0 ; 45
    palette_comb 25,  3, 28 ; 46
    palette_comb  0, 28,  8 ; 47
    palette_comb  4,  3, 28 ; 48, Left
    palette_comb 28,  3,  6 ; 49, Down + B
    palette_comb  4, 28, 29 ; 50
    palette_comb 30, 30, 30 ; 51, Right + A + B 
    palette_comb 31, 31, 31 ; 52, Left + A + B

Palettes:
    dw $7FFF, $32BF, $00D0, $0000 ;  0
    dw $639F, $4279, $15B0, $04CB ;  1
    dw $7FFF, $6E31, $454A, $0000 ;  2
    dw $7FFF, $1BEF, $0200, $0000 ;  3
    dw $7FFF, $421F, $1CF2, $0000 ;  4
    dw $7FFF, $5294, $294A, $0000 ;  5
    dw $7FFF, $03FF, $012F, $0000 ;  6
    dw $7FFF, $03EF, $01D6, $0000 ;  7
    dw $7FFF, $42B5, $3DC8, $0000 ;  8
    dw $7E74, $03FF, $0180, $0000 ;  9
    dw $67FF, $77AC, $1A13, $2D6B ; 10
    dw $7ED6, $4BFF, $2175, $0000 ; 11
    dw $53FF, $4A5F, $7E52, $0000 ; 12
    dw $4FFF, $7ED2, $3A4C, $1CE0 ; 13
    dw $03ED, $7FFF, $255F, $0000 ; 14
    dw $036A, $021F, $03FF, $7FFF ; 15
    dw $7FFF, $01DF, $0112, $0000 ; 16
    dw $231F, $035F, $00F2, $0009 ; 17
    dw $7FFF, $03EA, $011F, $0000 ; 18
    dw $299F, $001A, $000C, $0000 ; 19
    dw $7FFF, $027F, $001F, $0000 ; 20
    dw $7FFF, $03E0, $0206, $0120 ; 21
    dw $7FFF, $7EEB, $001F, $7C00 ; 22
    dw $7FFF, $3FFF, $7E00, $001F ; 23
    dw $7FFF, $03FF, $001F, $0000 ; 24
    dw $03FF, $001F, $000C, $0000 ; 25
    dw $7FFF, $033F, $0193, $0000 ; 26
    dw $0000, $4200, $037F, $7FFF ; 27
    dw $7FFF, $7E8C, $7C00, $0000 ; 28
    dw $7FFF, $1BEF, $6180, $0000 ; 29
    dw $43E0, $3B40, $2A60, $1DC0 ; 30, gbl
    dw $01EF, $018B, $0147, $00E2 ; 31, dmg


KeyCombinationPalettes:
    db 1  * 3  ; Right
    db 48 * 3  ; Left
    db 5  * 3  ; Up
    db 8  * 3  ; Down
    db 0  * 3  ; Right + A
    db 40 * 3  ; Left + A
    db 43 * 3  ; Up + A
    db 3  * 3  ; Down + A
    db 6  * 3  ; Right + B
    db 7  * 3  ; Left + B
    db 28 * 3  ; Up + B
    db 49 * 3  ; Down + B
    db 51 * 3  ; Right + A + B
    db 52 * 3  ; Left + A + B

TrademarkSymbol:
    db $3c,$42,$b9,$a5,$b9,$a5,$42,$3c

;CGBLogo:
;    incbin "CGB_logo.rle"


AnimationColors:
    dw $7FFF ; White
    dw $774F ; Cyan
    dw $22C7 ; Green
    dw $039F ; Yellow
    dw $017D ; Orange
    dw $241D ; Red
    dw $6D38 ; Purple
    dw $5500 ; Blue
    dw $6D60 ; Blue ; AGB version of blue, only used when AGB mode is set

AnimationColorsEnd:

; Helper Functions
DoubleBitsAndWriteRowTwice:
    call .twice
.twice
; Double the most significant 4 bits, b is shifted by 4
    ld a, 4
    ld c, 0
.doubleCurrentBit
    sla b
    push af
    rl c
    pop af
    rl c
    dec a
    jr nz, .doubleCurrentBit
    ld a, c
; Write as two rows
    ldi [hl], a
    inc hl
    ldi [hl], a
    inc hl
    ret

WaitFrame:
    push hl
    ld hl, $FF0F
    res 0, [hl]
.wait
    bit 0, [hl]
    jr z, .wait
    pop hl
    ret

WaitBFrames:
    call GetInputPaletteIndex
    ;call WaitFrame
    dec b
    jr nz, WaitBFrames
    ret

PlaySound:
    ret

ClearMemoryPage8000:
    ld hl, $8000
; Clear from HL to HL | 0x2000
ClearMemoryPage:
    xor a
    ldi [hl], a
    bit 5, h
    jr z, ClearMemoryPage
    ret

ReadTwoTileLines:
    call ReadTileLine
; c = $f0 for even lines, $f for odd lines.
ReadTileLine:
    ld a, [de]
    and c
    ld b, a
    inc e
    inc e
    ld a, [de]
    dec e
    dec e
    and c
    swap a
    or b
    bit 0, c
    jr z, .dontSwap
    swap a
.dontSwap
    inc hl
    ldi [hl], a
    swap c
    ret


; Nintendo Logo
ReadCGBLogoHalfTile:
    call .do_twice
.do_twice
    call ReadTwoTileLines
    inc e
    ld a, e
    ret

LoadTileset:
; Copy CGB Logo
    ld de, 0
    ld hl, $8080
.cgbLogoLoop
    ld a, [de]
    inc de

    ld b, a
    and $0f
    jr z, .skipLiteral
    ld c, a

.literalLoop
    ld a, [de]
    ldi [hl], a
    inc hl
    inc de
    dec c
    jr nz, .literalLoop
.skipLiteral
    swap b
    ld a, b
    and $0f
    jr z, .cgbLogoEnd
    ld c, a
    ld a, [de]
    inc de

.repeatLoop
    ldi [hl], a
    inc hl
    dec c
    jr nz, .repeatLoop
    jr .cgbLogoLoop

.cgbLogoEnd
; Copy (unresized) ROM logo
    ld de, $104
; Nintendo logo
.CGBROMLogoLoop
    ld c, $f0
    call ReadCGBLogoHalfTile
    add a, 22
    ld e, a
    call ReadCGBLogoHalfTile
    sub a, 22
    ld e, a
    cp $1c
    jr nz, .CGBROMLogoLoop
    inc hl
    ; fallthrough
ReadTrademarkSymbol:
    ld de, TrademarkSymbol
    ld c,$08
.loadTrademarkSymbolLoop:
    ld a,[de]
    inc de
    ldi [hl],a
    inc hl
    dec c
    jr nz, .loadTrademarkSymbolLoop
    ret

DoIntroAnimation:
    ; Animate the intro
    ld a, 1
    ldh [rVBK], a
    ld d, 26
.animationLoop
    ld b, 2
    call WaitBFrames
    ld hl, $98C0
    ld c, 3 ; Row count
.loop
    ld a, [hl]
    cp $F ; Already blue
    jr z, .nextTile
    inc [hl]
    and $7
    jr z, .nextLine ; Changed a white tile, go to next line
.nextTile
    inc hl
    jr .loop
.nextLine
    ld a, l
    or $1F
    ld l, a
    inc hl
    dec c
    jr nz, .loop
    dec d
    jr nz, .animationLoop
    ret

Preboot:
    call CheckFastBoot
    jr z, .fadeStart
    ld a, $c1
    call PlaySound ; Play final sound, but fade loop still needed with fastboot to init LCD

.fadeStart
    ld b, 32 ; 32 times to fade
.fadeLoop
    ld c, 32 ; 32 colors to fade
    ld hl, BgPalettes
.frameLoop
    push bc

    ; Brighten Color
    ld a, [hli]
    ld e, a
    ld a, [hld]
    ld d, a
    ; RGB(1,1,1)
    ld bc, $421

   ; Is blue maxed?
    ld a, e
    and $1F
    cp $1F
    jr nz, .blueNotMaxed
    dec c
.blueNotMaxed

    ; Is green maxed?
    ld a, e
    cp $E0
    jr c, .greenNotMaxed
    ld a, d
    and $3
    cp $3
    jr nz, .greenNotMaxed
    res 5, c
.greenNotMaxed

    ; Is red maxed?
    ld a, d
    and $7C
    cp $7C
    jr nz, .redNotMaxed
    res 2, b
.redNotMaxed

    ld a, e
    add c
    ld [hli], a
    ld a, d
    adc b
    ld [hli], a
    pop bc

    dec c
    jr nz, .frameLoop

    ;call WaitFrame
    call LoadPalettesFromHRAM
    ;call WaitFrame
    dec b
    jr nz, .fadeLoop

    ld a, 2
    ldh [rSVBK], a
    ; Clear RAM Bank 2 (Like the original boot ROM)
    ld hl, $D000
    call ClearMemoryPage
    inc a
    call ClearVRAMViaHDMA
    call _ClearVRAMViaHDMA
    call ClearVRAMViaHDMA ; A = $40, so it's bank 0
    xor a
    ldh [rSVBK], a
    cpl
    ldh [rJOYP], a

    ; Final values for CGB mode
    ld d, a
    ld e, c
    ld l, $0d

    ; Check cart CGB compatibility byte
    ld a, [$143]
    bit 7, a
    call z, EmulateDMG
    bit 7, a

    ldh [rKEY0], a ; write CGB compatibility byte, CGB mode
    ldh a, [TitleChecksum]
    ld b, a

    jr z, .skipDMGForCGBCheck
    ldh a, [InputPalette]
.skipDMGForCGBCheck
    ; Set registers to match the original CGB boot
    xor a
    ld c, a
    ld h, c
    ret

GetKeyComboPalette:
    ld hl, KeyCombinationPalettes - 1 ; Return value is 1-based, 0 means nothing down
    ld c, a
    ld b, 0
    add hl, bc
    ld a, [hl]
    ret

EmulateDMG:
    ld a, 1
    ldh [rOPRI], a ; DMG Emulation sprite priority
    call GetPaletteIndex
    bit 7, a
    call nz, LoadDMGTilemap
    res 7, a
    ld b, a
    add b
    add b
    ld b, a
    ldh a, [InputPalette]
    and a
    jr z, .nothingDown
    call GetKeyComboPalette
    jr .paletteFromKeys
.nothingDown
    ld a, b
.paletteFromKeys
    call WaitFrame
    call LoadPalettesFromIndex
    ld a, 4
    ; Set the final values for DMG mode
    ld de, 8
    ld l, $7c
    ret

GetPaletteIndex:
    ld hl, $14B
    ld a, [hl] ; Old Licensee
    cp $33
    jr z, .newLicensee
    dec a ; 1 = Nintendo
    jr nz, .notNintendo
    jr .doChecksum
.newLicensee
    ld l, $44
    ld a, [hli]
    cp "0"
    jr nz, .notNintendo
    ld a, [hl]
    cp "1"
    jr nz, .notNintendo

.doChecksum
    ld l, $34
    ld c, $10
    xor a

.checksumLoop
    add [hl]
    inc l
    dec c
    jr nz, .checksumLoop
    ldh [TitleChecksum], a
    ld b, a

    ; c = 0
    ld hl, TitleChecksums

.searchLoop
    ld a, l
    sub LOW(ChecksumsEnd) ; use sub to zero out a
    ret z
    ld a, [hli]
    cp b
    jr nz, .searchLoop

    ; We might have a match, Do duplicate/4th letter check
    ld a, l
    sub FirstChecksumWithDuplicate - TitleChecksums + 1
    jr c, .match ; Does not have a duplicate, must be a match!
    ; Has a duplicate; check 4th letter
    push hl
    ld a, l
    add Dups4thLetterArray - FirstChecksumWithDuplicate - 1 ; -1 since hl was incremented
    ld l, a
    ld a, [hl]
    pop hl
    ld c, a
    ld a, [$134 + 3] ; Get 4th letter
    cp c
    jr nz, .searchLoop ; Not a match, continue

.match
    ld a, l
    add PalettePerChecksum - TitleChecksums - 1; -1 since hl was incremented
    ld l, a
    ld a, b
    ldh [TitleChecksum], a
    ld a, [hl]
    ret

.notNintendo
    xor a
    ret

; optimizations in callers rely on this returning with b = 0
GetPaletteCombo:
    ld hl, PaletteCombinations
    ld b, 0
    ld c, a
    add hl, bc
    ret

LoadPalettesFromIndex: ; a = index of combination
    call GetPaletteCombo

    ; Obj Palettes
    ld e, 0
.loadObjPalette
    ld a, [hli]
    push hl
    ld hl, Palettes
    ; b is already 0
    ld c, a
    add hl, bc
    ld d, 8
    ld c, $6A
    call LoadPalettes
    pop hl
    bit 3, e
    jr nz, .loadBGPalette
    ld e, 8
    jr .loadObjPalette
.loadBGPalette
    ;BG Palette
    ld c, [hl]
    ; b is already 0
    ld hl, Palettes
    add hl, bc
    ld d, 8
    jr LoadBGPalettes

LoadPalettesFromHRAM:
    ld hl, BgPalettes
    ld d, 64

LoadBGPalettes:
    ld e, 0
    ld c, LOW(rBGPI)

LoadPalettes:
    ld a, $80
    or e
    ld [c], a
    inc c
.loop
    ld a, [hli]
    ld [c], a
    dec d
    jr nz, .loop
    ret

ClearVRAMViaHDMA:
    ldh [rVBK], a
    ld hl, HDMAData
_ClearVRAMViaHDMA:
    call WaitFrame ; Wait for vblank
    ld c, $51
    ld b, 5
.loop
    ld a, [hli]
    ldh [c], a
    inc c
    dec b
    jr nz, .loop
    ret

; clobbers AF and HL
GetInputPaletteIndex:
    ld a, [$143]
    bit 7, a
    ret nz ; if CGB game, palette cannot be chosen

    ld a, $20 ; Select directions
    ldh [rJOYP], a
    ldh a, [rJOYP]
    cpl
    and $F
    ret z ; No direction keys pressed, no palette

    ld l, 0
.directionLoop
    inc l
    rra
    jr nc, .directionLoop

    ; c = 1: Right, 2: Left, 3: Up, 4: Down

    ld a, $10 ; Select buttons
    ldh [rJOYP], a
    ldh a, [rJOYP]
    cpl
    rla
    rla
    and $C
    add l
    ld l, a
    ldh a, [InputPalette]
    cp l
    ret z ; No change, don't load
    ld a, l
    ldh [InputPalette], a
    ; Slide into change Animation Palette

ChangeAnimationPalette:
    push bc
    push de
    call GetKeyComboPalette
    call GetPaletteCombo
    inc l
    inc l
    ld c, [hl]
    ld hl, Palettes + 1
    add hl, bc
    ld a, [hld]
    cp $7F ; Is white color?
    jr nz, .isWhite
    inc hl
    inc hl
.isWhite
    push af
    ld a, [hli]

    push hl
    ld hl, BgPalettes ; First color, all palettes
    call ReplaceColorInAllPalettes
    ld l, LOW(BgPalettes + 2)  ; Second color, all palettes
    call ReplaceColorInAllPalettes
    pop hl
    ldh [BgPalettes + 6], a ; Fourth color, first palette

    ld a, [hli]
    push hl
    ld hl, BgPalettes + 1 ; First color, all palettes
    call ReplaceColorInAllPalettes
    ld l, LOW(BgPalettes + 3) ; Second color, all palettes
    call ReplaceColorInAllPalettes
    pop hl
    ldh [BgPalettes + 7], a ; Fourth color, first palette

    pop af
    jr z, .isNotWhite
    inc hl
    inc hl
.isNotWhite
    ; Mixing code by ISSOtm
    ldh a, [BgPalettes + 7 * 8 + 2]
    and ~$21
    ld b, a
    ld a, [hli]
    and ~$21
    add a, b
    ld b, a
    ld a, [BgPalettes + 7 * 8 + 3]
    res 2, a ; and ~$04, but not touching carry
    ld c, [hl]
    res 2, c ; and ~$04, but not touching carry
    adc a, c
    rra ; Carry sort of "extends" the accumulator, we're bringing that bit back home
    ld [BgPalettes + 7 * 8 + 3], a
    ld a, b
    rra
    ld [BgPalettes + 7 * 8 + 2], a
    dec l

    ld a, [hli]
    ldh [BgPalettes + 7 * 8 + 6], a ; Fourth color, 7th palette
    ld a, [hli]
    ldh [BgPalettes + 7 * 8 + 7], a ; Fourth color, 7th palette

    ld a, [hli]
    ldh [BgPalettes + 4], a ; Third color, first palette
    ld a, [hli]
    ldh [BgPalettes + 5], a ; Third color, first palette


    ;call WaitFrame
    call LoadPalettesFromHRAM
    ; Delay the wait loop while the user is selecting a palette
    ld a, 48
    ldh [WaitLoopCounter], a
    pop de
    pop bc
    ret

ReplaceColorInAllPalettes:
    ld de, 8
    ld c, e
.loop
    ld [hl], a
    add hl, de
    dec c
    jr nz, .loop
    ret

LoadDMGTilemap:
    push af
    ;call WaitFrame
    ld a, $19      ; Trademark symbol
    ld [$9910], a ; ... put in the superscript position
    ld hl,$992f   ; Bottom right corner of the logo
    ld c,$c       ; Tiles in a logo row
.tilemapLoop
    dec a
    jr z, .tilemapDone
    ldd [hl], a
    dec c
    jr nz, .tilemapLoop
    ld l, $0f ; Jump to top row
    jr .tilemapLoop
.tilemapDone
    pop af
    ret

CheckAGB:
    ldh a, [rBANK]
    bit 0, a
    ret

CheckFastBoot:
    ld a, 2
    bit 1, a
    ret

CheckAGBPalette:
    push hl
    call CheckAGB
    jr z, .normalPalette
; Check if we are loading the final blue color
    ld hl, AnimationColors+14
    ld a, e
    cp a, l
    jr nz, .normalPalette
    inc de ; Skip the CGB blue, use AGB blue
    inc de
.normalPalette
    pop hl
    ret

BootEnd:
IF BootEnd > $900
    FAIL "BootROM overflowed: {BootEnd}"
ENDC

SECTION "HRAM", HRAM[$FF80]
TitleChecksum:
    ds 1
BgPalettes:
    ds 8 * 4 * 2
InputPalette:
    ds 1
WaitLoopCounter:
    ds 1
