        org 0x0000
;___________________________________________________________________
; Originally disassembled with dZ80 v1.31
;
; Memory map:
;   $0000-3fff ROM
;   $6000-6fff RAM
;   $6900-6A7f sprites
;   $7000-73ff unknown; probably not used
;   $7400-77ff Video RAM
;       top left corner:      $77A0
;       bottom left corner:   $77BF
;       top right corner:     $7440
;       bottom right corner:  $745F
;
;   Note that the monitor is rotated 90 degrees, so $77A1 is the tile under
;   $77A0, not the tile to the right of it.


; I/O ports

IN0         equ     $7c00       ; player 1 joystick and jump button
IN1         equ     $7c80       ; player 2 joystick and jump button
IN2         equ     $7d00       ; coins; start buttons
DSW1        equ     $7d80       ; DIP switches

; IN0 and IN1
;   bit 7 : ?
;   bit 6 : reset
;   bit 5 : ?
;   bit 4 : JUMP
;   bit 3 : DOWN
;   bit 2 : UP
;   bit 1 : LEFT
;   bit 0 : RIGHT
;
; (IN0 is read on player 1's turn; IN1 is read on player 2's turn)

; IN2:
;   bit 7: COIN
;   bit 6: ? Radarscope does some wizardry with this bit
;   bit 5 : ?
;   bit 4 : ?
;   bit 3 : START 2
;   bit 2 : START 1
;   bit 1 : ?
;   bit 0 : ? if this is 1, the code jumps to $4000, outside the rom space

; DSW1:
;   bit 7 : COCKTAIL or UPRIGHT cabinet (1 = UPRIGHT)
;   bit 6 : \ 000 = 1 coin 1 play   001 = 2 coins 1 play  010 = 1 coin 2 plays
;   bit 5 : | 011 = 3 coins 1 play  100 = 1 coin 3 plays  101 = 4 coins 1 play
;   bit 4 : / 110 = 1 coin 4 plays  111 = 5 coins 1 play
;   bit 3 : \bonus at
;   bit 2 : / 00 = 7000  01 = 10000  10 = 15000  11 = 20000
;   bit 1 : \ 00 = 3 lives  01 = 4 lives
;   bit 0 : / 10 = 5 lives  11 = 6 lives

; 7800-780F P8257 Control registers
; @TODO@ -- define constants for this


REG_MUSIC       equ $7c00

; Values written to REG_MUSIC
; @TODO@ -- update code to use these
MUS_NONE        equ $00
MUS_INTRO       equ $01     ; Music when DK climbs ladder
MUS_HOWHIGH     equ $02     ; How high can you get?
MUS_OUTATIME    equ $03     ; Running out of time
MUS_HAMMER      equ $04     ; Hammer music
MUS_ENDING1     equ $05     ; Music after beating even-numbered rivet levels
MUS_HAMMERHIT   equ $06     ; Hammer hit
MUS_FANFARE     equ $07     ; Music for completing a non-rivet stage
MUS_25M         equ $08     ; Music for barrel stage
MUS_50M         equ $09     ; Music for pie factory
MUS_75M         equ $0a     ; Music for elevator stage (or lack thereof)
MUS_100M        equ $0b     ; Music for rivet stage
MUS_ENDING2     equ $0c     ; Music after beating odd-numbered rivet levels
MUS_RM_RIVET    equ $0d     ; Used when rivet removed
MUS_DK_FALLS    equ $0e     ; Music when DK is about to fall in rivet stage
MUS_DK_ROAR     equ $0f     ; Zerbert. Zerbert. Zerbert.

; Sound effects get their own registers
REG_SFX         equ $7d00   ; The first of 8 sound registers, but only the first 6 are used

; These are added to REG_SFX to produce the register to write to
; These are also used by RAM (@TODO@ -- what variable?) to queue sounds
SFX_WALK        equ 0
SFX_JUMP        equ 1
SFX_BOOM        equ 2       ; DK pounds ground; barrel hits Mario
SFX_SPRING      equ 3       ; (writes to i8035's P1)
SFX_FALL        equ 4       ; (writes to i8035's P2)
SFX_POINTS      equ 5       ; Got points, grabbed the hammer, etc.

REG_SFX_DEATH   equ $7d80   ; plays when Mario dies (triggers i8035's interrupt)

; Some other hardware registers
REG_FLIPSCREEN      equ $7d82
REG_SPRITE          equ $7d83   ; cleared at program start and never used
REG_VBLANK_ENABLE   equ $7d84
REG_DMA             equ $7d85   ; @TODO@ -- what does this do, exactly?

;___________________________________________________________________
; Background palette selectors
;
; These registers each store 1 bit. Only the least-significant bit
; matters when writing. The two values together determine the palette
; for the whole screen. Note that the colors can change from row to row
; in each palette. For example, in the high score screen palette, the
; first row of tiles shows red text; the second and third rows have
; white text; the fourth row has blue text; etc. You can see this in
; MAME by looking at the 0's on the screen while the game is booting up.
;
; Palettes:
; A | B
; -----
; 0 | 0     high score screen
; 0 | 1     barrel and elevator stages
; 1 | 0     pie factory stage
; 1 | 1     rivet stage
;___________________________________________________________________
REG_PALETTE_A       equ $7d86
REG_PALETTE_B       equ $7d87


; Machine accepts no more than 90 credits (this is a BCD value)
MAX_CREDITS     equ $90


RAM             equ $6000
SPRITE_RAM      equ $7000
VIDEO_RAM       equ $7400

;___________________________________________________________________
; Notes on variables (READ THIS)
;
; Donkey Kong's code is a little nutty and often depends on variables
; being stored in a certain way. For instance, if there's a variable at
; RAM+$a, it may do "DEC HL" to get at the variable at RAM+9, even
; if these variables are loosely related at best. If you're making a
; hack, we strongly suggest you keep the addresses of existing variables
; intact!
;
; For the same reason, it's hard to be 100% sure that every variable has
; been documented. It's easy to miss a variable if it's never directly
; referenced by address.
;
; Finally, be aware that, intentionally or not, some variables may have
; been used for more than one purpose.
;___________________________________________________________________

; Number of credits in BCD. Can't go over MAX_CREDITS.
NumCredits      equ RAM+1

; Counts number of coins inserted until next credit is reached
; E.g., if the machine is set to 4 coins/credit, this starts at 0 and counts up to 4 with each coin.
; When it's 4, it'll be reset to 0 and a credit will be added.
CoinCounter     equ RAM+2

; Usually 1. When a coin is inserted, it changes to 0 momentarily.
; (In MAME, this value will be 0 while the coin key is held down.)
CoinSwitch      equ RAM+3

; 1 when in attract mode, 2 when credits in waiting for start, 3 when playing game
GameMode1       equ RAM+5

; 1 when no credits have been inserted, 0 if any credits exist or a game is being played
NoCredits       equ RAM+7

; General-purpose timer. 16-bit. The code uses the MSB rather than the LSB for 8-bit timers.
WaitTimer       equ RAM+8
WaitTimerLSB    equ WaitTimer
WaitTimerMSB    equ WaitTimer+1

; Attract mode: $1
; Intro: $7
; How High Can You Get?: $a
; Right before play: $b
; During play: $c
; Dead: $d
; Game over: $10
; Rivets cleared: $16
; @TODO@ -- list is not complete. Range is [0..$17], and most, possibly all, values seem to be used
GameMode2       equ RAM+$a

; Both of these are 0 if it's player 1's turn, and 1 if it's player 2's turn.
; @TODO@ -- try to find why these are two variables and give them better names.
PlayerTurnA     equ RAM+$d
PlayerTurnB     equ RAM+$e

; 0 if 1-player game, 1 if 2-player game
TwoPlayerGame   equ RAM+$f

; The same as RawInput below, except when jump is pressed, bit 7 is set momentarily
InputState      equ RAM+$10

; Right sets bit 0, left sets bit 1, up sets bit 2, down sets bit 3, jump sets bit 4
RawInput        equ RAM+$11

; constantly changing ... timer of some sort? (@TODO@ -- better name?)
RngTimer1       equ RAM+$18

; RngTimer2 - constantly changing timer - very fast (@TODO@ -- better name?)
RngTimer2       equ RAM+$19

; Constantly counts down from FF to 00 and then FF to 00 again and again, once per frame
FrameCounter    equ RAM+$1a

; Initial number of lives (set with dip switches)
StartingLives   equ RAM+$20

; score needed for bonus life in thousands
ExtraLifeThreshold  equ RAM+$21

CoinsPerCredit  equ RAM+$22

; Coins needed for a two-player game (always CoinsPerCredit*2)
CoinsPer2Credits    equ RAM+$23

; Seems to be used for the same purpose as CoinsPerCredit (@TODO@ -- why is this a distinct variable?)
CoinsPerCredit2 equ RAM+$24

CreditsPerCoin  equ RAM+$25

; 0 = cocktail, 1 = upright cabinet
UprightCab      equ RAM+$26

; Timer counting delay before cursor can move. Keeps the cursor from moving too fast.
; (@XXX@ -- verify this is this variable's function!!)
HSCursorDelay   equ RAM+$30

; Toggles between 0 and 1 as the player's high score in the table blinks
HSBlinkToggle   equ RAM+$31

; Toggles HSBlinkToggle in table whenever it's zero
HSBlinkTimer    equ RAM+$32

; Time left to register name in seconds
HSRegiTime      equ RAM+$33

; Decrements HSRegiTime when zero
HSTimer         equ RAM+$34

; Which character the cursor is highlighting when entering high score
HSCursorPos     equ RAM+$35

; Address of screen RAM for current initial being entered (16-bit variable)
HSInitialPos    equ RAM+$36

; Something to do with high score entry.
; Changing this value to FF in the debugger on high score screen causes the
; game to prompt for another name after entering the first.
Unk6038         equ RAM+$38

; Number of lives remaining for player 1
P1NumLives      equ RAM+$40

; $6041-6047 = ???
Unk6041         equ RAM+$41

; Number of lives for player 2
P2NumLives      equ RAM+$48

; $6049-604f probably serve the same purpose as 6041-6047, but for player 2
Unk6049         equ RAM+$49

NumObstaclesJumped  equ RAM+$60

; $6080 - $608F are used for sounds - they are a buffer to set up a sound to be played on the hardware
; $6080 = 1 or 3 when mario is walking, makes the walking sound
; $6081 counts down 3, 2, 1, 0 when mario jumps
; $6082 = boom sound
; $6083 counts down 3,2,1,0 when the springs bounce on the elevator level
; $6084 used for falling sounds
; $6085 = 1 when the bonus sound is played
; $6086 =
; $6089 = used to determine which music is played: (not all used during play?)
; $608A is used for same?
; $60B0 and $60B1 are some sort of counter.  counts from #C0 192 (decimal) to #FE (256) by twos, then again and again.  Related to #60C0 - #60FF ?
; $60B2, $60B3, $60B4 - player 1 score
; $60B5, $60B6, $60B7 - player 2 score
; $60B8 = ???
; $60C0 - $60FF - loaded with $FF, used for a timer, in conjunction with #60B0 ?
; $6100 - $61A5 - high score table
; $61C6, $61C7 = ???
; $6200 is 1 when mario is alive, 0 when dead
; $6202 varies from 0, 2, 4, 1 when mario is walking left or right
; $6203 = Mario's X position
; $6204 = varies between 80 and 0 when mario jumping left or right
; $6205 = Mario's Y position
; $6206 = left 4 bits vary when mario jumping
; $6207 = a movement indicator. when moving right, 128 bit is set. (bit 7) move left, 128 bit is cleared
; $6207 continuted.  walking, bits 0  and 1 flip around.  jump sets bits 1,2,3 on.  when climbing a ladder,
; $6207 cont.  bit 7 flips on and off, and bits 0,1,2 flip around
; $6208 = ?
; $620C = mario's jump height?
; $620F is movement indicator.  when still it is on 0, 1, or 2.  when moving it moves between 2,1,0,2,1,0... when on a ladder it goes to counts down from 4.  when it reaches zero, it animates mario climbing.
; $620E is set whenever mario jumps, it holds marios Y value when he jumped.
; $6210 = FF when jumping to the left and afterwards until another jump, 0 otherwise
; $6211 = 0 when jumping straight up, #80 when jumping left or right
; $6212 =
; $6214 = is counted from 0 while mario is jumping.
; $6215 is 1 when mario is on ladder, 0 otherwise
; $6216 is 1 while mario is jumping, 0 otherwise
; $6217 is 1 when hammer is active, 0 otherwise
; $6218 = 0, turns to 1 while mario is grabbing the hammer until he lands
; $6219 = 0, turns to 1 when mario is moving on a moving or broken ladder, [but this is never checked ???]
; $621B,C = the top and bottom locations of a ladder mario is on or near
; $621E = counts down from 4 when mario is landing from a jump.  0 otherwise
; $621F = 1 when mario is at apex or on way down after jump, 0 otherwise.
; $6220 = set to 1 when mario falls too far, 0 otherwise
; $6221
; $6222 = toggles between 0 and 1 when mario on ladder.  otherwise 0
; $6224 = toggles between 0 and 1 when mario on ladder.  used for sounds while on ladder
; $6225 = 1 when a bonus sound is to be played, 0 otherwise
; $6227 is screen $:  1-girders, 2-pie, 3-elevator, 4-rivets
; $6228 is the number of lives remaining for current player
; $6229  is the level $
; $622C = game start flag.  1 when game begins, 0 after mario has died ?
; $622D = 0, changed to 1 when player is awarded extra life
; $6280 to $6287 = left side retractable ladder on conveyors?
; $6288, 6289, 628A = ???
; $6290 = counts down how many rivets are left from 8
; $62A0 = top conveyor direction reverse counter
; $62A1 = master direction for top conveyor, 01 = right, FF = left
; $62A2 = middle conveyor direction reverse counter
; $62A3 = master direction for middle conveyor, 01 = outwards, FF = inwards
; $62A5 = bottom conveyor direction reverse counter
; $62A6 = master direction for bottom conveyor, 01 = right, FF = left
; $62A7 = counts down from $34 to zero on elevators
; $62A8
; $62AA
; $62AC -
; $62AF = some sort of timer connected with the barrels counts down from 18 to 00 , then kong moves position for next barrel grab  See #638F
; continued  also used for counter during game intro, used for kong animation
; $62B1 - Bonus timer
; $62B2 controls the timer for blue barrels
; $62B3 = controls the timers for all levels except girders.  Is #78 (120), #64 (100), #50,(80) or #3C (60) depending on level.
; level 1 rivets 5000 bonus lasts 99 seconds (say 100) =  100 bonus every 2 seconds
; level 2 rivets 6000 bonus lasts 99 seconds = 100 bonus every 5/3 (1.66666...) seconds
; level 3 rivets 7000 bonus lasts 92 seconds = 100 bonus every 4/3 (1.3333...) seconds
; level 4 rivets 8000 bonus lasts 80 seconds = 100 bonus every 1 seconds
; level 1 barrels 4700 bonus lasts 94 seconds = 100 bonus every 2 seconds
; level 2 barrels 5700 bonus lasts 105 seconds = 100 bonus every 1.842 seconds ???
; level 3 barrels 6700 bonus lasts 93 seconds = 100 bonus every 1.388 seconds
; level 4 barrels 7700 bonus lasts 130 seconds = 100 bonus every 5/3 seconds 1.666 ?
;
; $62B4 a timer used on conveyors ?
; $62B8 = a timer used on conveyors and girders ?
; $62B9 - used for fire release on conveyors and girders ?  0 when no fires onscreen, 1 when fires are onscreen, 3 when a fire is to be released
; $6300 - ladder sprites / locations ???
; $6340 - usually 0, changes when mario picks up bonus item. jumps over item turns to 1 quickly, then 2 until bonus disappears
; $6341 - timer counts down when mario picks up bonus item or jumps an item for showing bonus on screen
; $6342
; $6343 - changes to 14 when umbrella picked up, 0C for hat, 10 for purse
; $6345 - usually 0.  changes to 1, then 2 when items are hit with the hammer
; $6348 - $00, turns to $01 when the oil can is on fire on girders
; $6350 - 0, turns to 1 when an item has been hit with hammer, back to 0 after score sprite appears in its place
; $6351 through $6354 used for temp storage for items hit with hammer
; $6380 - Internal difficulty. Dictates speed of fires, wild barrel behavior, barrel steerability and other things. Ranges from 1 to 5.
; $6381 = timer that controls when #6380 changes ?
; $6382 = 00 and turns to 80 when a blue barrel is about to be deployed.
;         First blue barrel has this at 81 and then 02.  changes to 1 for crazy barrel
;               Bit 7 is set when barrel is blue
;               Bit 0 is set when barrel is crazy
;               bit 1 is set for the second barrel of the round which can't be crazy
; $6383 = timer used in conjunction with the tasks
; $6384 = timer ?
; $6385 = varies from 0 to 7 while the intro screen runs, when kong climbs the dual ladders and scary music is played
; $6386 - is zero until time runs out.  then it turns to 2, then when it turns to 3 mario dies
; $6387 - is zero until time runs out.  then it counts down from FF to 00, when it hits 00 mario dies and #6386 is set to 3
; $6388 = usually zero, counts from 1 to 5 when the level is complete
; $6389 - ????
; $638C is the onscreen timer
; $638D = counts from 5 to 0 while kong is bouncing during intro
; $638E = counts from $1E to A while kong is climbing ladders at beginning of game
; $638F = Counts down 3,2,1,0 as a barrel is being deployed.  See #62AF
; $6390 - counts from 0 to 7F periodically
; $6391 - is 0, then changed to 1 when timer in #6390 is counting up
; $6392 = barrel deployment indicator.  0 normally, 1 when a barrel is being deployed
; $6393 - Barrel deployment indicator. This gets set to 1 as soon as the barrel deployment process begins, and gets set back to 0 as soon as
;         kong releases the barrel being deployed.
; $6396 = bouncer release flag.  0 normally, 3 when bouncer is to be deployed
; $6398 = 1 when riding an elevator ?
; $639B = pie deployment counter
; $639D = normally 0.  1 while mario dying, 2 when dead
; $639A = indicator for the fires/deployment
; $63A0 = usually 0, flips to 1 quickly when a firefox is deployed
; $63A1 =  number of firefoxes active
; $63A2 = used as a temporary counter
; $63A3 = top conveyor direction for this frame,  flips between 00 (stationary) and either 1 (right) or FF (left) depending on kongs direction
; $63A4 = middle left conveyor direction for this frame
; $63A5 = middle right conveyor direction for this frame
; $63A6 = bottom conveyor direction for this frame
; $63B3 - ???
; $63B5 - ???
; $63B7 - ???
; $63B8 is zero but turns to 1 when the timer expires but before mario dies
; $63B9 - is 1 during girders, changes to 0A when item is hit with hammer.
        ;  on rivets it is 07.  conveyors turns to 6 when pie hit, 5 when fire hit. changes to 0A when mario dies
; $63C0 - ???
; $63C8,9 -  Used during fireball movement processing to store the address of the fireball data array for the current fireball being processed
; $63CC -  ???
; $6400 to $649F - Fireball data tables. There are 5 fireball slots, each with 32 bytes for storing data associated with that fireball. The first
;                  fireball's slot is #6400 to #641F, the second fireball's slot is #6420 to #643F, etc. The following is a description of the data
;                  stored at each offset into a fireball's slot:
; +00 - Fireball status. 0 = inactive (this fireball slot is free), 1 = active
; +01,02 - Empty
; +03 - Fireball actual X-position. This seems to be the same as +0E.
; +04 - Empty
; +05 - Fireball actual Y-position. This Y-position has been adjusted for the bobbing up and down that a each fireball is constantly doing. Note that
;       this bobbing up and down is mainly for visual effect and has no impact on any fireball movement logic (this uses +0F instead, which does not
;       account for the bobbing up and down), however hitboxes are still determined by this actual Y-position and not the effective Y-position
; +06 - Empty
; +07 - Fireball graphic data
; +08 - Fireball color. 0 = blue (Mario has hammer), 1 = normal
; +09 - (Width of fireball hitbox - 1)/2
; +0A - (Height of fireball hitbox - 1)/2
; +0B,0C - Empty
; +0D - Fireball direction of movement. It can take on the following values:
;         0 = left, but it can also mean "frozen" in the case of a freezer that is currently in freezer mode
;         1 = right
;         2 = "special" left, this is different from 0 since here the fireball behaves identically to a right-moving fireball, only moving left instead
;             of right. This means that ladders are permitted to be taken, speed is deterministic and not slowed, and freezers aren't frozen when
;             the direction is 2, unlike a direction of 0. The direction gets set to 2 only immediately after a fireball hits the right edge of a
;             girder, and it will stay at 2 until a "decision point" for reversing direction at which point the direction will become either 0 or 1.
;         4 = descending ladder
;         8 = ascending ladder
; +0E - Fireball effective X-position. This seems to be the same as +03.
; +0F - Fireball effective Y-position. This Y-position does not account for the fireball bobbing up and down and is treated as the true Y-position for
;       the purposes of all fireball movement.
; +10 to +12 - Empty
; +13 - This counter is used as an index into a table that determines how to adjust the fireball's Y-position to make it bob up and down.
; +14 - Ladder climb timer. This timer counts down from 2 as a fireball climbs a ladder. A fireball is only allowed to climb a pixel when this reaches
;       0, at which point it gets reset back to 2. This has the effect of causing fireballs to climb ladders at 1/3 of the speed at which they descend
;       ladders.
; +15 - Fireball animation change timer. This timer counts down from 2, and when it reaches 0 the fireball changes it's graphics.
; +16 - Fireball direction reverse counter. When this counter reaches 0 a fireball reverses direction with 50% probability. Such a decision is referred
;       to as a "decision point".
; +17 - Empty
; +18 - Fireball spawning flag. This is set to 1 to indicate that the fireball is in the process of spawning. Often fireballs follow a special
;       trajectory, such as when jumping out of an oil can, while this is set.
; +19 - Fireball freezer mode flag. Setting this to 2 indicates that freezer mode has been enguaged, at which point a fireball can potentially start
;       freezing. Only fireballs in the 2nd and 4th fireball slots can enter freezer mode.
; +1A,1B - During fireball spawning, when jumping out of an oil can, this is used to store the current index into the Y-position table that dictactes
;          the arc that the fireball follows as it comes out of the oil can.
; +1C - Fireball freeze timer. Freezers use this as a timer until a frozen fireball should unfreeze.
; +1D - Fireball freeze flag. If this gets set during freezer mode, then as long as Mario is not above the fireball it will immediately set the freeze
;       timer (+1C) for 256 frames and says frozen until the timer reaches 0, this can only happen when a fireball reaches the top of a ladder, all
;       other instances of a fireball freezing are caused by the direction being set to 0 during freezer mode and have nothing to do with the freeze
;       timer.
; +1E - Empty
; +1F - When a fireball is climbing up or down a ladder, this stores the Y-position of the other end of the ladder (the end the fireball is headed
;       towards).
; $64A7 -
; $6500 - $65AF = the ten bouncer values, 6510, 6520, etc. are starting values
;        +3 is the X pos, +5 is the Y pos
; $65A0 - $65?? = values for the 6 pies
; $6600 - 665F  = the 6 elevator values.  6610, 6620, 6630, 6640 ,6650 are starting values
;       + 3 is the X position, + 5 is the Y position
; $6680 -
; $6687 -
; $6688
; hammer code for top hammer of girders, lower hammer on rivets, upper left hammer on conveyors
; $6689 - changes from 5 to 6 when hammer active
; $668A - changes from 6 to 3 when hammer active
; $668E - changes from 0 to 10 when hammer active
; $668F - changes from 0 to F0 when hammer active
; $66A0 - ???
; $6700 range - barrel info +20, +40, +60, +80, +A0, +C0, +E0 for the barrels
; 00 = barrel not in use.  $02 = barrel being deployed.  #01 = barrel rolling
; $6701 - crazy barrel indicator.  00 for normal, #01 for crazy barrel
; $6702 - motion indicator.  02 = rolling right, 08 = rolling down, 04 = rolling left, bit 1 set when rolling down ladder
; $6703 - barrel X
; $6705 - barrel Y
; $6707 - right 2 bits are 01 when rolling, 10 when being deployed.  bit 7 toggles as it rolls
; $6708
; $670E = edge indicator.  counts from 0 to 3 while barrel is going over edge
; $670F = counts from 4 to 1 then over again when barrel is moving
; $6710 = 0 when deployed.  changed to #FF when at left edge and after landing after falling off right edge of girder. changed to 1 when after landing after falling off left edge of girder and starting to roll right changed to 0 while falling off right edge of girder
; $6711 = 60 when barrel is rolling around the right edge, A0 when rolling around left edge
;
; $6714 =
; $6715 =
; $6717 = position of next ladder it is going down or the ladder it just passed.
; ladders are :  70, 6A, 93, 8D, 8B, B3, B0, AC, D1, CD, F3, EE
; $6719 = grabs the Y value of the barrel when its crazy, and has hit a girder
; $6900 - $6907 = 2 sprites used for the girl
; $6908 - ($6908 + $28) = animation states for kong and maybe other things
        ; $6909 - kong's right leg
        ; $6913 -
        ; $6919 - kong's mouth
        ; $691D - kong's right arm
        ; $692D - girl under kong's arms during game intro
        ; $692F - girl under kong's arms ???
; $6944 - $694C = 2 sprites for moving ladders on conveyors
; $694C = mario sprite X value
; $694D = mario sprite value.
; $694E = mario sprite color ?
; $694F = mario sprite Y value

; 00 = mario facing left
; 01, 02 = mario running left
; 03 = mario on ladder with left hand up
; 04 = mario on ladder with butt showing
; 05 = mario on ladder with butt showing
; 06 = mario standing above ladder with back to screen
; 07 = blank???
; 08 = mario with hammer up, facing left
; 09 = mario with hammer down, facing left
; 0A = mario with hammer up, facing left
; 0B = mario with hammer down, facing left
; 0C = mario with hammer up, facing left
; 0D = mario with hammer down, facing left
; 0E = mario jumping left
; 0F = mario landing left
; 10 = top of girl
; 11 = bottom of girl
; 12 = bottom of girl (2nd pose)
; 13 = bottom of girl (fat)
; 14 = legs of girl when being carried
; 15 = rolling barrel
; 16, 17 = barrel going down ladder or crazy
; 18 = barrel next to kong (vertical)
; 19 = blue barrel (skull)
; 1A, 1B = barrel going down ladder or crazy
; 1C, 1D = blank ?
; 1E = hammer
; 1F = smashing down hammer
; 20, 21, 22 = crazy kong face
; 23 = kong face, frowning
; 24 = kong face, growling
; 25 = kong chest
; 26 = kong left leg
; 27 = kong right leg
; 28 = kong right arm
; 29 = kong left arm
; 2A = kong right shoulder
; 2B = part of kong ?
; 2C = kong right foot
; 2D = kong left arm grabbing barrel
; 2E = kong bottom center
; 2F = kong top right shoulder
; 30 = kong face facing left
; 31 = kong right arm
; 32 = kong shoulder
; 33 = kong shoulder
; 34 = kong left arm
; 35 = kong right arm
; 36 = kong left foot climbing ladder
; 37 = kong right foot climbing ladder
; 38 = blank ?
; 39 = lines for smashed item
; 3A = solid block ?
; 3B = bouncer (1)
; 3C = bouncer (2 squished)
; 3D = fireball (1)
; 3E = fireball (2)
; 3F = blank ?
; 40 = fire on top of oil can
; 41 = fire on top of oil can (2)
; 42 =  fire on top of oil can (3)
; 43 =  fire on top of oil can (4)
; 44 =  flat girder (used for elevator?)
; 45 = elevator receptacle
; 46 =  ladder
; 47, 48 = blank ?
; 49 = oil can
; 4A = blank?
; 4B = pie
; 4C = pie spilling over
; 4D = firefox
; 4E = firefox (2)
; 4F = blanK?
; 50 = edge of conveyor pulley
; 51 = edge of conveyor pulley (2)
; 52 = edge of conveyor pulley (3)
; 53 - 5F = blank ?
; 60 = circle for item being hit with hammer
; 61 = small circle for item being hit with hammer
; 62 = smaller circle for item being hit with hammer
; 63 = burst for item being hit with hammer
; 64 - 71  = blank
; 72 = square for hiscore select
; 73 = hat
; 74 = purse
; 75 = umbrella
; 76 = heart
; 77 = broken heart
; 78 = dying, mario upside down
; 79 = dying, mario head to right
; 7A = mario dead
; 7B = 100 points_array
; 7C = 200 points_array
; 7D = 300 points_array
; 7E = 500 points_array
; 7F = 800 points_array
; all values from 80-FF are mirror images of items 0 -7F
; 80 = starting value, mario facing right
; 81, 82 = mario running to right
; 83 = mario on ladder with right hand up
; 84 = mario on ladder with butt showing
; 85 = mario on ladder with butt showing (2)
; 86 =
; 88 = mario with hammer up, facing right
; 89 = mario with hammer down, facing right
; 8A = mario with hammer up, facing right
; 8B = mario with hammer down, facing right
; 8C = mario with hammer up, facing right
; 8D = mario with hammer down, facing right
; 8E = mario jumping right
; 8F = mario landing right
; FA = mario dead with circle (halo?)
; F8 = dying, right side up
; F9 = dying, head on left
; 3rd sprite is the color
; 0 = red
; 1 = white
; 2 = blue
; 3,4,5,6 = cyan
; 7 = white
; 8 = orange
; 9, A = pink
; B = light brown
; C = blue
; D = orange
; E = blue
; F = black
; 10 =
; $6980 - X position of a barrel and bouncers (all sprites??) , #6981 = sprite type? , 2= sprite color?, #6983 = Y position
; Add 4 to each barrel/sprite in question up to #6A08
; $69B8 start for pie sprites
; $6A0C - $6A0C + 12 - positions of the bonus extra items, umbrella, purse, etc.
; $6A1C - $6A1F = hammer sprite
; $6A20 - $6A23 heart sprite
; $6A24 - $6A27 sprite used for kong's aching head lines
; $6A29 - sprite for oilcan fire
; $7400-77ff - video ram
; $7700 = 1 up area Letter P
; $7701 = score 10's value
; $7702 = under the score 10's value
; $7708 = area where Kong is on girders
; $7721 = score 100's value
; $7741 = score 1000's value
; $7761 = score 10,000 value
; $7781 = score 100,000 value
; $7641 is the start of high score 100,000 place
; $7521 - the start of player 2 score (100,000's place)
; characters data
; 00 - 09 = 0 - 9
; 10 = empty
; 11 - 2A = A to Z
; 12 = B
; 13 = C
; 14 = D
; 15 = E
; 16 = F
; 17 = G
; 18 = H
; 19 = I
; 1A = J
; 1B = K
; 1C = L
; 1D = M
; 1E = N
; 1F = O
; 20 = P
; 21 = Q
; 22 = R
; 23 = S
; 24 = T
; 25 = U
; 26 = V
; 27 = W
; 28 = X
; 29 = Y
; 2A = Z
; 2B = .
; 2C = -
; 2D = high -
; 2E = :
; 2F = high -
; 30 = <
; 31 = >
; 32 = I
; 33 = II
; 34 = = (equals sign)
; 35 = -
; 36 , 37 = !! (two exlamations)
; 38 , 39= !
; 3A = '
; 3B, 3C = "
; 3D = " (skinny quote marks)
; 3E = L shape (right, bottom)
; 3F = L shape, (right, top)
; 40 = L shape
; 41 = L shape, (left, top)
; 42 = .
; 43 = ,
; 44 - 48 = some graphic (RUB END) ?
; 49, 4A = copyrigh logo
; 4B, 4C = some logo?
; 4D, - 4F = solid blocks of various colors
; 50 = 67 = kong graphics (retarded brother?)
; 6C - 6F = a graphic
; 70-79 = 0 - 9 (larger, used in score and tiemr)
; 80 - 89 = 0-9
; 8A = M
; 8B = m
; 8F-8C = some graphic
; 9F= Left half of trademark symbol
; 9E = right half of TM sybmol
; B1 = Red square with Yellow lines top and bottom
; B0 = Girder with hole in center used in rivets screen
; B6 = white line on top
; B7 = wierd icon?
; B8 = red line on bottom
; C0 - C7 = girder with ladder on bottom going up
; D0 - D7 = ladder graphic with girder under going up and out
; DD = HE  (help graphic)
; DE = EL
; DF = P!
; E1 - E7 = grider graphic going up and out
; EC - E8 = blank ?
; EF = P!
; EE = EL (part of help graphic)
; ED = HE (help graphic)
; F6 - F0 = girder graphic in several vertical phases coming up from bottom
; F7 = bottom yellow line
; FA - F8 = blank ?
; FB = ? (actually a question mark)
; FC = right red edge
; FD = left red edge
; FE = X graphic
; FF = Extra Mario Icon


;___________________________________________________________________
;
; game start power-on
;
;___________________________________________________________________


        LD      A,$00                           ; A := 0
        LD      (REG_VBLANK_ENABLE),A           ; disable interrupts
        JP      Init                            ; skip ahead

;
; RST     $8
; if there are credits or the game is being played it returns immediately.  if not, it returns to higher subroutine
;

        LD      A,(NoCredits)   ; load A with 1 when no credits have been inserted, 0 if any credits exist or game is being played
        RRCA                    ; any credits in the game ?
        RET     NC              ; yes, return

        INC     SP
        INC     SP
        RET                     ; else return to higher subroutine

;
; RST     $10
; if mario is alive, it returns.  if mario is dead, it returns to the higher subroutine.
;

        LD      A,($6200)       ; 1 when mario is alive, 0 when dead
        RRCA                    ; is mario alive?
        RET     C               ; yes, return

        INC     SP              ; no, increase SP by 2 and return
        INC     SP
        RET                     ; effectively returns twice

;
; RST     $18
;

        LD      HL,WaitTimerMSB ; load timer that counts down
        DEC     (HL)            ; Count it down...
        RET     Z               ; Ret if zero

        INC     SP              ; otherwise Increase SP twice
        INC     SP
        RET                     ; and return - effectively returns to higher subroutine

;
; RST     $20
;

        LD      HL,WaitTimerLSB ; load HL with timer
        DEC     (HL)            ; count it down
        JR      Z,$0018         ; If zero skip up and count down the other timer

        POP     HL              ; else move stack pointer up and return to higher subroutine
        RET


;
; RST     $28
; jumps program to (2*A + Next program address)
; used in conjuction with a jump table after the call
;

        ADD     A,A             ; A := A * 2
        POP     HL              ; load HL with address of jump table
        LD      E,A             ; load E with A
        LD      D,$00           ; D := 0
        JP      $0032           ; skip ahead

;
; RST $30
;

        JR      $0044           ; this core sub is actually at $0044

;
; continuation of RST $28 from $002D above
;

        ADD     HL,DE           ; HL is now 2A more than it was
        LD      E,(HL)          ; load E with low byte from the table
        INC     HL              ; next table entry
        LD      D,(HL)          ; load D with high byte from table
        EX      DE,HL           ; DE <> HL
        JP      (HL)            ; jump to the address in HL

;
; RST     $38
; HL and C are preloaded
; updates $A (10 decimal) by adding C from each location from HL to HL + $40 by 4
; [the bytes affected are offset by 4 bytes each]
;
; Also $003D is called from several places. used for updating girl's sprite
;

        LD      DE,$0004        ; load offset of 4 to add
        LD      B,$0A           ; for B = 1 to $A (10 decimal)

        LD      A,C             ; Load A with C
        ADD     A,(HL)          ; Add the contents of HL into A
        LD      (HL),A          ; put back into HL, this increases the value in HL by C
        ADD     HL,DE           ; next HL to do will be 4 more than previous
        DJNZ    $003D           ; next B

        RET

; continuation of rst $30
; used to check a screen number.  if it doesn't match, the 2nd level of subroutine is returned
; A is preloaded with the check value, in binary

        ld      HL,$6227        ; Load HL with address of Screen $
        ld      B,(HL)          ; load B with Screen $, For B = 1 to screen $ (1, 2, 3 or 4)

        RRCA                    ; Rotate A right with carry
        DJNZ    $0048           ; Next B

        RET    c                ; ret if carry

        POP     HL              ; otherwise HL gets the stack = return to higher subroutine
        RET

; HL is preloaded with source data of kong sprites values
; this subroutine copies the memory values of HL to HL + $28 into $6908 through $6908 + $28
; used to set all the kong sprites

        LD      DE,$6908        ; Kong's Sprites start
        LD      BC,$0028        ; $28 bytes to copy
        LDIR                    ; copy
        RET

; this subroutine takes the value of RngTimer1 and adds into it the values from FrameCounter and RngTimer2
; it returns with A loaded with this result and also RngTimer1 with the answer.
; random number generator

        LD      A,(RngTimer1)           ; load A with timer
        LD      HL,FrameCounter         ; load HL with other timer address
        ADD     A,(HL)                  ; add
        LD      HL,RngTimer2            ; load HL with yet another timer address
        ADD     A,(HL)                  ; add
        LD      (RngTimer1),A           ; store
        RET

; interrupt routine

        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL
        PUSH    IX
        PUSH    IY                      ; save all registers

        XOR     A                       ; A := 0
        LD      (REG_VBLANK_ENABLE),A   ; disable interrupts
        LD      A,(IN2)                 ; load A with Credit/Service/Start Info
        AND     $01                     ; is the Service button being pressed?
        JP      NZ,$4000                ; yes, jump to $4000 [??? this would cause a crash ???]

        LD      HL,$0138                ; load HL with start of table data
        CALL    $0141                   ; refresh the P8257 Control registers / refresh sprites to hardware
        LD      A,(NoCredits)           ; load the credit indicator
        AND     A                       ; are there credits present / is a game being played ?
        JP      NZ,$00B5                ; No, jump ahead

        LD      A,(UprightCab)          ; yes, load A with upright/cocktail
        AND     A                       ; upright ?
        JP      NZ,$0098                ; yes, jump ahead

        LD      A,(PlayerTurnB)         ; else load A with player number
        AND     A                       ; is this player 2 ?
        LD      A,(IN1)                 ; load A with raw input from player 2
        JP      NZ,$009B                ; yes, skip next step

        LD      A,(IN0)                 ; load A with raw input from player 1
        LD      B,A                     ; copy to B
        AND     $0F                     ; mask left 4 bits to zero
        LD      C,A                     ; copy this to C
        LD      A,(RawInput)            ; load A with player input
        CPL                             ; The contents of A are inverted (one’s complement).
        AND     B                       ; logical and with raw input - checks for jump button
        AND     $10                     ; mask all bits but 4.  if jump was pressed it is there
        RLA
        RLA
        RLA                             ; rotate left 3 times
        OR      C                       ; mix back into masked input
        LD      H,B                     ; load H with B = raw input
        LD      L,A                     ; load L with A = modified input
        LD      (InputState),HL         ; store into input memories, InputState and RawInput
        LD      A,B                     ; load A with raw input
        BIT     6,A                     ; is the bit 6 set for reset?
        JP      NZ,$0000                ; if reset, jump back to $0000 for a reboot

        LD      HL,FrameCounter         ; else load HL with Timer constantly counts down from FF to 00 and then FF to 00 again and again ... 1 count per frame
        DEC     (HL)                    ; decrease this timer
        CALL    $0057                   ; update the random number gen
        CALL    $017B                   ; check for credits being inserted and handle them
        CALL    $00E0                   ; update all sounds
        LD      HL,$00D2                ; load HL with return address
        PUSH    HL                      ; push to stack so any RETs go there ($00D2)
        LD      A,(GameMode1)           ; load A with game mode1

; GameMode1 is 0 when game is turned on, 1 when in attract mode.  2 when credits in waiting for start, 3 when playing game

        RST     $28             ; jump based on above:

        hex     C3 01           ; $01C3 = startup
        hex     3C 07           ; $073C = attract mode
        hex     B2 08           ; $08B2 = credits, waiting
        hex     FE 06           ; $06FE = playing game

; return here from any of the jumps above, based on return address pushed to stack at $00C5

        POP     IY
        POP     IX
        POP     HL
        POP     DE
        POP     BC                      ; restore all registers except AF

        LD      A,$01                   ; A := 1
        LD      (REG_VBLANK_ENABLE),A   ; enable interrupts
        POP     AF                      ; restore AF
        RET                             ; ret from interrupt

; called from $00BF
; updates all sounds

        LD      HL,$6080        ; source data at sound buffer
        LD      DE,REG_SFX      ; set destination to sound outputs
        LD      A,(NoCredits)   ; load A with credit indicator
        AND     A               ; have credits been inserted / is there a game being played ?
        RET     NZ              ; no, return [change to NOP to enable sound in demo ]

; this sub writes the sound buffer to the hardware
; sounds have durations to play in the buffer

        LD      B,$08                   ; yes, there was a credit or a game is being played.  For B = 1 to 8 Do:

        LD      A,(HL)                  ; load A with sound duration / sound effect for the sound
        AND     A                       ; is there a sound to play ?
        JP      Z,$00F5                 ; no, skip next 2 steps

        DEC     (HL)                    ; yes, decrease the duration
        LD      A,$01                   ; A := 1

        LD      (DE),A                  ; store sound to output (play sound)
        INC     E                       ; next output address
        INC     L                       ; next source address
        DJNZ    $00ED                   ; Next B

        LD      HL,$608B                ; load HL with music timer
        LD      A,(HL)                  ; load A with this value
        AND     A                       ; == 0 ?
        JP      NZ,$0108                ; no, skip ahead 4 steps

        DEC     L                       ; else
        DEC     L                       ; HL := $6089
        LD      A,(HL)                  ; load A with this value to use for music
        JP      $010B                   ; skip next 3 steps

        DEC     (HL)                    ; decrease timer
        DEC     L                       ; HL := $608A
        LD      A,(HL)                  ; load A with this tune to use

        LD      (REG_MUSIC),A           ; play music
        LD      HL,$6088                ; load HL with address/counter for mario dying sound
        XOR     A                       ; A := 0
        CP      (HL)                    ; compare.  is mario dying ?
        JP      Z,$0118                 ; no, skip next 2 steps

        DEC     (HL)                    ; else decrease the counter
        INC     A                       ; A := 1

        LD      (REG_SFX_DEATH),A       ; store A into digital sound trigger -death (?)
        RET

; clear all sounds
; called from several places

        LD      B,$08                   ; For B = 1 to 8
        XOR     A                       ; A := 0
        LD      HL,REG_SFX              ; [REG_SFX..REG_SFX+7] get all zeros
        LD      DE,$6080                ; $6080-$6088 get all zeros - clears sound buffer

        LD      (HL),A                  ; clear this memory - clears sound outputs
        LD      (DE),A                  ; clear this memory
        INC     L                       ; next memory
        INC     E                       ; next memory
        DJNZ    $0125                   ; Next B

        LD      B,$04                   ; For B = 1 to 4

        LD      (DE),A                  ; $6088-$608B get all zeros
        INC     E                       ; next DE
        DJNZ    $012D                   ; Next B

        LD      (REG_SFX_DEATH),A       ; clear the digital sound trigger (death)
        LD      (REG_MUSIC),A           ; clear the sound output
        RET

; data used in sub below

        hex 53 00 69 80 41 00 70 80
        hex 81

; called from $007D
; HL is preloaded with $0138
; This copies the sprite data from $6900 to $7000
; Presumably the reason sprite data isn't stored in $7000 in the first place is to ensure it's updated only during vblank.

        XOR     A               ; A := 0
        LD      (REG_DMA),A     ; store into P8257 DRQ DMA Request
        LD      A,(HL)          ; load table data ($53)
        LD      ($7808),A       ; store into P8257 control register
        INC     HL              ; next table entry
        LD      A,(HL)          ; load table data ($00)
        LD      ($7800),A       ; store into P8257 control register
        INC     HL              ; next table entry
        LD      A,(HL)          ; load table data ($69)
        LD      ($7800),A       ; store into P8257 control register
        INC     HL              ; next table entry
        LD      A,(HL)          ; load table data ($80)
        LD      ($7801),A       ; store into P8257 control register
        INC     HL              ; next table entry
        LD      A,(HL)          ; load table data ($41)
        LD      ($7801),A       ; store into P8257 control register
        INC     HL              ; next table entry
        LD      A,(HL)          ; load table data ($00)
        LD      ($7802),A       ; store into P8257 control register
        INC     HL              ; next table entry
        LD      A,(HL)          ; load table data ($70)
        LD      ($7802),A       ; store into P8257 control register
        INC     HL              ; next table entry
        LD      A,(HL)          ; load table data ($80)
        LD      ($7803),A       ; store into P8257 control register
        INC     HL              ; next table entry
        LD      A,(HL)          ; load table data ($81)
        LD      ($7803),A       ; store into P8257 control register
        LD      A,$01           ; A := 1
        LD      (REG_DMA),A     ; store into P8257 DRQ DMA Request
        XOR     A               ; A := 0
        LD      (REG_DMA),A     ; store into P8257 DRQ DMA Request
        RET

; called from $00BC
; checks for and handles credits

        LD      A,(IN2)         ; load A with IN2
        BIT     7,A             ; is the coin switch active?
        LD      HL,CoinSwitch   ; load HL with pointer to coin switch indicator
        JP      NZ,$0189        ; yes, skip next 2 steps
        LD      (HL),$01        ; otherwise store 1 into coin switch indicator  -  this is for coin insertion
        RET
        LD      A,(HL)          ; Load A with coin switch indicator
        AND     A               ; has a coin been inserted ?
        RET     Z               ; no, return

; coin has been inserted

        PUSH    HL                      ; else save HL to stack
        LD      A,(GameMode1)           ; load A with game mode1
        CP      $03                     ; is someone playing?
        JP      Z,$019D                 ; yes, skip ahead and don't play the sound

        CALL    $011C                   ; no, then clear all sounds
        LD      A,$03                   ; load sound duration
        LD      ($6083),A               ; plays the coin insert sound

        POP     HL                      ; restore HL from stack
        LD      (HL),$00                ; store 0 into coin switch indicator - no more coins
        DEC     HL                      ; HL := CoinCounter
        INC     (HL)                    ; increase this counter
        LD      DE,CoinsPerCredit2      ; load DE with # of coins needed per credit
        LD      A,(DE)                  ; load A with coins needed
        SUB     (HL)                    ; has the player inserted enough coins for a new credit?
        RET     NZ                      ; yes, return (CoinCounter is now zero)

        LD      (HL),A                  ; no; restore CoinCounter
        INC     DE                      ; DE := CreditsPerCoin
        DEC     HL                      ; HL := NumCredits
        EX      DE,HL                   ; DE := NumCredits, HL := CreditsPerCoin
        LD      A,(DE)                  ; load A with number of credits in BCD
        CP      MAX_CREDITS             ; is the number of credits already maxed out?
        RET     NC                      ; yes; return

        ADD     A,(HL)                  ; add number of credits with # of credits per coin
        DAA                             ; decimal adjust
        LD      (DE),A                  ; store result in credits
        LD      DE,$0400                ; load task #4 - draws credits on screen if any are present
        CALL    $309F                   ; insert task
        RET

; table data used below in 01C6

        hex       00 37 00 AA AA AA 50 76 00

; this is called when the game is first turned on or reset from #00C9

        CALL    $0874                   ; clears the screen and sprites
        LD      HL,$01BA                ; start of table data above
        LD      DE,$60B2                ; set destination
        LD      BC,$0009                ; set counter to 9
        LDIR                            ; copy 9 bytes above into #60B2-#60BB
        LD      A,$01                   ; A := 1
        LD      (NoCredits),A           ; store into credit indicator == no credits exist
        LD      ($6229),A               ; initialize level to 1
        LD      ($6228),A               ; set number of lives remaining to 1
        CALL    $06B8                   ; if a game is played or credits exist, display remaining lives-1 and level
        CALL    $0207                   ; set all dip switch settings and create default high score table from ROM
        LD      A,$01                   ; A := 1
        LD      (REG_FLIPSCREEN),A      ; store into flip screen setting
        LD      (GameMode1),A           ; store into game mode 1
        LD      ($6227),A               ; initialize screen to 1 (girders)
        XOR     A                       ; A := 0
        LD      (GameMode2),A           ; store into game mode 2
        CALL    $0A53                   ; draw "1UP" on screen
        LD      DE,$0304                ; load task data to draw "HIGH SCORE"
        CALL    $309F                   ; insert task to draw text
        LD      DE,$0202                ; load task #2, parameter 2 to display the high score
        CALL    $309F                   ; insert task
        LD      DE,$0200                ; load task #2, parameter 0 to display player 1 score
        CALL    $309F                   ; insert task
        RET

; this sub reads and sets the dip switch settings, and creates the default high score table

        LD      A,(DSW1)                ; load A with Dip switch settings
        LD      C,A                     ; copy to C
        LD      HL,StartingLives        ; set destination address to initial number of lives
        AND     $03                     ; mask bits, now between 0 and 3 inclusive
        ADD     A,$03                   ; Add 3, now between 3 and 6 inclusive
        LD      (HL),A                  ; store in initial number of lives
        INC     HL                      ; next HL, now at ExtraLifeThreshold = score needed for extra life
        LD      A,C                     ; load A with original value of dip switches
        RRCA                            ;
        RRCA                            ; rotate right twice
        AND     $03                     ; mask bits, now between 0 and 3
        LD      B,A                     ; copy to B.  used in minisub below for loop counter
        LD      A,$07                   ; A := 7 = default score for extra life
        JP      Z,$0226                 ; on zero, jump ahead and use 7

        LD      A,$05                   ; A : = 5

        ADD     A,$05                   ; add 5
        DAA                             ; decimal adjust
        DJNZ    $0221                   ; loop until done

        LD      (HL),A                  ; store the result in score for extra life
        INC     HL                      ; HL := CoinsPerCredit
        LD      A,C                     ; load A with dipswitch
        LD      BC,$0101                ; B := 1, C := 1
        LD      DE,$0102                ; D := 1, E := 2
        AND     $70                     ; mask bits.  turns off all except the 3 used for coins/credits
        RLA
        RLA
        RLA
        RLA                             ; rotate left 4 times.  now in lower 3 bits
        JP      Z,$0247                 ; if zero, skip ahead and leave BC and DE alone

        JP      C,$0241                 ; if there was a carry, skip ahead

        INC     A                       ; increase A
        LD      C,A                     ; store into C
        LD      E,D                     ; E := 1
        JP      $0247                   ; skip ahead

        ADD     A,$02                   ; else A := 2
        LD      B,A                     ; B := 2
        LD      D,A                     ; D := 2
        ADD     A,A                     ; A := 4
        LD      E,A                     ; E := 4

        LD      (HL),D                  ; store D into CoinsPerCredit
        INC     HL                      ; HL := CoinsPer2Credits
        LD      (HL),E                  ; store E into CoinsPer2Credits
        INC     HL                      ; HL := CoinsPerCredit2
        LD      (HL),B                  ; store B into CoinsPerCredit2
        INC     HL                      ; HL := CreditsPerCoin
        LD      (HL),C                  ; store DE and BC into coins/credits
        INC     HL                      ; HL := UprightCab = memory for upright/cocktail
        LD      A,(DSW1)                ; load A with dipswitch settings
        RLCA                            ; rotate left
        LD      A,$01                   ; A := 1
        JP      C,$0259                 ; if carry, skip next step

        DEC     A                       ; A := 0

        LD      (HL),A                  ; store into upright / cocktail
        LD      HL,$3565                ; source = #3565 = default high score table
        LD      DE,$6100                ; dest = #6100 = high score RAM
        LD      BC,$00AA                ; byte counter = #AA
        LDIR                            ; copy high score table into RAM
        RET

; come here from game power-on
; first, clear system RAM
Init
        LD      B,$10           ; for B = 0 to #10
        LD      HL,RAM          ; set destination
        XOR     A               ; A := 0

        LD      C,A             ; For C = 0 to #FF

        LD      (HL),A          ; store 0 into memory
        INC     HL              ; next location
        DEC     C               ; Next C
        JR      NZ,$026D        ; Loop until done

        DJNZ    $026C           ; Next B

; clears sprite memory

        LD      B,$04           ; For B = 1 to 4
        LD      HL,SPRITE_RAM   ; load HL with start address
        LD      C,A             ; For C = 0 to #FF

        LD      (HL),A          ; Clear this memory
        INC     HL              ; next memory
        DEC     C               ; Next C
        JR      NZ,$027A        ; loop until done

        DJNZ    $0279           ; Next B

; this subroutine clears the VIDEO RAM with #10 (clear shape)

        LD      B,$04           ; for B = 1 to 4
        LD      A,$10           ; $10 is the code for clear on the screen
        LD      HL,$7400        ; load HL with beginning of graphics memory

        LD      C,$00           ; For C = 1 to #FF

        LD      (HL),A          ; load clear into video RAM
        INC     HL              ; next location
        DEC     C               ;
        JR      NZ,$028A        ; Next C

        DJNZ    $0288           ; Next B

; Loads $60C0 to $60FF (task list) with #FF

        LD      HL,$60C0        ; HL points to start of task list
        LD      B,$40           ; For B = 1 to #40
        LD      A,$FF           ; load A with code for no task

        LD      (HL),A          ; store into task location
        INC     HL              ; next location
        DJNZ    $0298           ; Next B

; reset some memories to 0 and 1

        LD      A,$C0                   ; load A with #C0 for the #60B0 and #60B1 timers
        LD      ($60B0),A               ; store into timer
        LD      ($60B1),A               ; store into timer
        XOR     A                       ; A := 0
        LD      (REG_SPRITE),A          ; Clear dkong_spritebank_w  /* 2 PSL Signal */

        LD      (REG_PALETTE_A),A       ; clear palette bank selector
        LD      (REG_PALETTE_B),A       ; clear palette bank selector
        INC     A                       ; A: = 1
        LD      (REG_FLIPSCREEN),A      ; set flip screen setting
        LD      SP,$6C00                ; set Stack Pointer to #6C00
        CALL    $011C                   ; clear all sounds
        LD      A,$01                   ; A := 1
        LD      (REG_VBLANK_ENABLE),A   ; enable interrupts

;
; arrive after RET encountered after #0306 jump
; check for tasks and do them if they exist
;

        LD      H,$60                   ; H := #60
        LD      A,($60B1)               ; load A with task pointer
        LD      L,A                     ; copy to L.  HL now has #60XX which is the current task
        LD      A,(HL)                  ; load A with task
        ADD     A,A                     ; double.  Is there a task to do ?
        JR      NC,$02E3                ; yes, skip ahead to handle task

        CALL    $0315                   ; else flash the "1UP" above the score when it is time to do so
        CALL    $0350                   ; check for and handle awarding extra lives
        LD      HL,RngTimer2            ; load HL with timer
        INC     (HL)                    ; increase the timer
        LD      HL,$6383                ; load HL with address of memory used to track tasks
        LD      A,(FrameCounter)        ; load A with timer that constantly counts down from #FF to 0
        CP      (HL)                    ; equal ?
        JR      Z,$02BD                 ; yes, loop back to check for more tasks

        LD      (HL),A                  ; else store A into the memory, for next time
        CALL    $037F                   ; check for updating of difficulty
        CALL    $03A2                   ; check for releasing fires on girders and conveyors
        JR      $02BD                   ; loop back to check for more tasks

; arrive from $02C5
; loads data from the task list at #60C0 through #60CF
; tasks are loaded in subroutine at #309F
; HL is preloaded with task pointer
; A is preloaded with 2x the task number

        AND     $1F             ; mask bits.  A now between 0 and #1F
        LD      E,A             ; copy to E
        LD      D,$00           ; D := 0
        LD      (HL),$FF        ; overwrite the task with empty entry
        INC     L               ; next HL
        LD      C,(HL)          ; load C with the 2nd byte of the task (parameter)
        LD      (HL),$FF        ; overwrite the task with empty entry
        INC     L               ; next HL
        LD      A,L             ; load A with low byte of the address
        CP      $C0             ; < #C0 ?
        JR      NC,$02F6        ; no, skip next step

        LD      A,$C0           ; reset low byte to #C0

        LD      ($60B1),A       ; store into the task pointer
        LD      A,C             ; load A with the 2nd byte of the task
        LD      HL,$02BD        ; load HL with return address
        PUSH    HL              ; push to stack so RET will go to #02BD = task list
        LD      HL,$0307        ; load HL with data from table below
        ADD     HL,DE           ; add the offset based on byte 1 of the task
        LD      E,(HL)          ; load E with the low byte from the table below
        INC     HL              ; next HL
        LD      D,(HL)          ; load D with the high byte from the table
        EX      DE,HL           ; DE <> HL
        JP      (HL)            ; jump to address from the table

; data for jump table used above
; task table

        hex       1C 05         ; $051C ; 0, for adding to score.  parameter is score in hundreds
        hex       9B 05         ; $059B ; 1, clears and displays scores.  parameter 0 for p1, 1 for p2
        hex       C6 05         ; $05C6 ; 2, displays score.  0 for p1, 1 for p2, 2 for highscore
        hex       E9 05         ; $05E9 ; 3, used to draw text.  parameter is code for text to draw
        hex       11 06         ; $0611 ; 4, draws credits on screen if any are present
        hex       2A 06         ; $062A ; 5, parameter 0 adds bonus to player's score , parameter 1 update onscreen bonus timer and play sound & change to red if below 1000
        hex       B8 06         ; $06B8 ; 6, draws remaining lives and level number.  parameter 1 to draw lives-1

; called from $02C7
; flashes 1UP or 2UP

        LD      A,($601A)               ; load A with timer constantly counts down from FF to 00 and then FF to 00 again and again ... 1 count per frame
        LD      B,A                     ; copy to B
        AND     $0F                     ; mask bits, now between 0 and #F.  Is it zero ?
        RET     NZ                      ; no, return

        RST     $8                      ; if credits exist or someone is playing, continue.  else RET

        LD      A,(PlayerTurnA)         ; Load A with player # (0 for player 1, 1 for player 2)
        CALL    $0347                   ; Loads HL with location for score (either player 1 or 2)
        LD      DE,$FFE0                ; load DE with offset for each column
        BIT     4,B                     ; test bit 4 of timer.  Is it zero ?
        JR      Z,$033E                 ; yes, skip ahead

        LD      A,$10                   ; A := #10 = blank character
        LD      (HL),A                  ; clear the text "1" from "1UP" or "2" from "2UP"
        ADD     HL,DE                   ; add offset for next column
        LD      (HL),A                  ; clear the text "U" from "1UP"
        ADD     HL,DE                   ; next column
        LD      (HL),A                  ; clear the text "P" from "1UP"
        LD      A,(TwoPlayerGame)       ; load A with # of players in game
        AND     A                       ; is this a 1 player game?
        RET     Z                       ; yes, return

        LD      A,(PlayerTurnA)         ; Load current player #
        XOR     $01                     ; change player from 1 to 2 or from 2 to 1
        CALL    $0347                   ; Loads HL with location for score (either player 1 or 2)

        INC     A                       ; increase A, now it has the number of the player
        LD      (HL),A                  ; draw player number on screen
        ADD     HL,DE                   ; next column
        LD      (HL),$25                ; draw "U" on screen
        ADD     HL,DE                   ; next column
        LD      (HL),$20                ; draw "P" on screen
        RET

; called from $033B

        LD      HL,$7740        ; for player 1 HL gets #7740 VRAM address
        AND     A               ; is this player 2?
        RET     Z               ; no, then return

        LD      HL,$74E0        ; player 2 gets #74E0 location on screen
        RET

; called from $02CA
; checks for and handles extra life

        LD      A,($622D)       ; load A with high score indicator
        AND     A               ; has this player already been awarded extra life?
        RET     NZ              ; yes, return

        LD      HL,$60B3        ; load HL with address for player 1 score
        LD      A,(PlayerTurnA) ; load A with 0 when player 1 is up, 1 when player 2 is up
        AND     A               ; player 1 up ?
        JR      Z,$0361         ; yes, skip next step

        LD      HL,$60B6        ; else load HL with address of player 2 score

        LD      A,(HL)          ; load A with a byte of the player's score
        AND     $F0             ; mask bits
        LD      B,A             ; copy to B
        INC     HL              ; next score byte
        LD      A,(HL)          ; load A with byte of player's score
        AND     $0F             ; mask bits
        OR      B               ; mix together the 2 score bytes
        RRCA
        RRCA
        RRCA
        RRCA                            ; rotate right 4 times, this swaps the high and low bytes
        LD      HL,ExtraLifeThreshold   ; load HL with score needed for extra life
        CP      (HL)                    ; compare player's score to high score.  is it greater?
        RET     C                       ; no, return

        LD      A,$01                   ; A := 1
        LD      ($622D),A               ; store into extra life indicator
        LD      HL,$6228                ; load HL with address of number of lives remaining
        INC     (HL)                    ; increase
        JP      $06B8                   ; skip ahead and update # of lives on the screen

; called from $02DB
; checks timers and increments difficulty if needed

; [timer_6384++ ; IF timer_6384 != 256 THEN RETURN ; timer_6384 := 0 ; ]

        LD      HL,$6384        ; load HL with timer address
        LD      A,(HL)          ; load A with the timer
        INC     (HL)            ; increase the timer
        AND     A               ; was the timer at zero?
        RET     NZ              ; no, return

; [timer_6381++ ; IF (timer_6381/8) != INT(timer_6381/8) THEN RETURN]

        LD      HL,$6381        ; load HL with timer
        LD      A,(HL)          ; load A with timer value
        LD      B,A             ; copy to B
        INC     (HL)            ; increase timer
        AND     $07             ; mask bits.  are right 3 bits == #000 ? does for every 8 steps of #6381
        RET     NZ              ; no, return

; increase difficulty if not at max

; [ difficulty := (timer_6381 div 8) + level ; IF difficulty > 5 THEN difficulty := 5 ; RET]

        LD      A,B             ; load A with original timer value
        RRCA                    ; roll right 3 times... (div 8)
        RRCA
        RRCA
        LD      B,A             ; store result into B
        LD      A,($6229)       ; load A with level number
        ADD     A,B             ; add B to A
        CP      $05             ; is this answer > 5 ?
        JR      C,$039E         ; no, skip next step

        LD      A,$05           ; otherwise A := 5

        LD      ($6380),A       ; store result into difficulty
        RET                    ;ret to #02DE

; called from $02DE

        LD      A,$03           ; A := 3 = 0011 binary
        RST     $30             ; only continue if level is girders or conveyors, else RET

        RST     $10             ; if mario is alive, continue, else RET

        LD      A,($6350)       ; load A with 1 when an item has been hit with hammer
        RRCA                    ; has an item been hit with the hammer ?
        RET     C               ; yes, return, we don't do anything here while hammer hits occur

        LD      HL,$62B8        ; load HL with this counter
        DEC     (HL)            ; decrease.  at zero?
        RET     NZ              ; no, return

        LD      (HL),$04        ; yes, reset counter to 4
        LD      A,($62B9)       ; load A with fire release indicator
        RRCA                    ; roll right.  carry?  Is there a fire onscreen or is it time to release a new fire?
        RET     NC              ; no, return

; a fire is onscreen or to be released

        LD      HL,$6A29        ; load HL with sprite for fire above oil can
        LD      B,$40           ; B := #40
        LD      IX,$66A0        ; load IX with fire array start ?
        RRCA                    ; roll A right again.  carry ?  Is it time to release anothe fire?
        JP      NC,$03E4        ; no, skip ahead, animate oilcan, reset timer and return

; release a fire

        LD      (IX+$09),$02    ; store 2 into sprite +9 indicator (size ???)
        LD      (IX+$0A),$02    ; store 2 into sprite +#A indicator (size ???)
        INC     B
        INC     B               ; B := #42 = extra fire oilcan sprite value
        CALL    $03F2           ; randomly store B or B+1 into (HL) - animates the oilcan fire with extra fire
        LD      HL,$62BA        ; load HL with this timer.  usually it is set at #10 when a level begins
        DEC     (HL)            ; decrease timer.  zero ?
        RET     NZ              ; no, return

; release a fire, or do something when fires already exist

        LD      A,$01           ; A := 1
        LD      ($62B9),A       ; store into fire release indicator
        LD      ($63A0),A       ; store into other fireball release indicator

        LD      A,$10           ; A := #10
        LD      ($62BA),A       ; reset timer back to #10
        RET

        LD      (IX+$09),$02    ; set +9 to 2 (size ???)
        LD      (IX+$0A),$00    ; set +A to 0 (size ???)
        CALL    $03F2           ; randomly store B or B+1 into (HL) - animates the oilcan fire
        JP      $03DE           ; skip back, reset timer, and return

; called from $03CE and $03EC above
; animates the oilcan fire

        LD      (HL),B          ; store B into (HL) - set the oilcan fire sprite
        LD      A,(RngTimer2)   ; load A with random number
        RRCA                    ; rotate right.  carry ?
        RET     C               ; yes, return

        INC     B               ; else increase B
        LD      (HL),B          ; store B into (HL) - set the oilcan fire sprite with higher value
        RET

; called from main routine at $19B0
; animates kong, checks for kong beating chest, animates girl and her screams for help

        LD      A,($6227)       ; load A with screen number
        CP      $02             ; are we on the conveyors?
        JP      NZ,$0413        ; no, skip ahead

; conveyors

        LD      HL,$6908        ; load HL with kongs sprite start
        LD      A,($63A3)       ; load A with kongs direction
        LD      C,A             ; copy to C for subroutine below
        RST     $38             ; move kong
        LD      A,($6910)       ; load A with kong's X position
        SUB     $3B             ; subtract #3B (59 decimal)
        LD      ($63B7),A       ; store into kong's position

; $6390 - counts from 0 to 7F periodically
; $6391 - is 0, then changed to 1 when timer in #6390 is counting up

        LD      A,($6391)               ; load A with indicator
        AND     A                       ; == 0 ?
        JP      NZ,$0426                ; no, skip next 5 steps

        LD      A,(FrameCounter)        ; else load A with this clock counts down from #FF to 00 over and over...
        AND     A                       ; == 0 ?
        JP      NZ,$0486                ; no, skip ahead

        LD      A,$01                   ; else A := 1
        LD      ($6391),A               ; store into indicator

        LD      HL,$6390                ; load HL with timer
        INC     (HL)                    ; increase
        LD      A,(HL)                  ; load A with timer value
        CP      $80                     ; == #80 ?
        JP      Z,$0464                 ; yes, skip ahead

        LD      A,($6393)               ; else get barrel deployment
        AND     A                       ; is a barrel deployment in progress?
        JP      NZ,$0486                ; yes, jump ahead

        LD      A,(HL)                  ; else load A with timer
        LD      B,A                     ; copy to B
        AND     $1F                     ; mask bits, now == 0 ?
        JP      NZ,$0486                ; no, skip ahead

        LD      HL,$39CF                ; else load HL with start of table data
        BIT     5,B                     ; is bit 5 turned on timer ?  (1/8 chance???)
        JR      NZ,$0448                ; no, skip ahead

; kong is beating his chest

        LD      HL,$39F7        ; start of table data
        CALL    $004E           ; update kong's sprites
        LD      A,$03           ; load sound duration of 3
        LD      ($6082),A       ; play boom sound using sound buffer

        LD      A,($6227)       ; load A with screen number
        RRCA                    ; is this the girders or the elevators ?
        JP      NC,$0478        ; no, skip ahead

        RRCA                    ; else is this the rivets ?
        JP      C,$0486         ; yes, skip ahead

; else pie factory

        LD      HL,$690B        ; load HL with start of Kong sprite data
        LD      C,$FC           ; C := #FC.  used in sub below to move kong by -4
        RST     $38             ; move kong
        JP      $0486           ; skip ahead

; arrive here from $042D when timer in #6390 is #80

        XOR     A               ; A := 0
        LD      (HL),A          ; clear timer
        INC     HL              ; increase address to #6391
        LD      (HL),A          ; clear this one too
        LD      A,($6393)       ; Load Barrel deployment indicator
        AND     A               ; is a deployment in progress?
        JP      NZ,$0486        ; yes, jump ahead

        LD      HL,$385C        ; else load HL with start of table data for kongs sprites
        CALL    $004E           ; update kong's sprites
        JP      $0450           ; jump back

; arrive here from $0454 when on rivets and conveyors
; moves kong, updates girl and her screams for help

        LD      HL,$6908        ; load HL with start of kong sprite X position
        LD      C,$44           ; set offset to #44, used only on rivets
        RRCA                    ; roll screen number right (again).  is this the conveyors screen?
        JP      NC,$0485        ; no, skip next 2 steps

        LD      A,($63B7)       ; load A with kong's position
        LD      C,A             ; copy to C for sub below, controls position of kong

        RST     $38             ; move kong to his position

        LD      A,($6390)       ; load A with timer
        LD      C,A             ; copy to C
        LD      DE,$0020        ; DE := #20, used for offset in call at #04A6
        LD      A,($6227)       ; load A with screen number
        CP      $04             ; are we on the rivets level?
        JP      Z,$04BE         ; yes, jump ahead to handle

        LD      A,C             ; load A with the timer
        AND     A               ; == 0 ?
        JP      Z,$04A1         ; yes, skip next 3 steps

        LD      A,$EF           ; else A := #EF
        BIT     6,C             ; is bit 6 of the timer set ?
        JP      NZ,$04A3        ; no, skip next step

        LD      A,$10           ; A := #10

        LD      HL,$75C4        ; load HL with address of a location in video RAM where girl yells "HELP"
        CALL    $0514           ; update girl yelling "HELP"
        LD      A,($6905)       ; load A with girl's sprite

        LD      ($6905),A       ; store girl's sprite
        BIT     6,C             ; is bit 6 of the timer set ?
        RET     Z               ; yes, return

        LD      B,A             ; else B := A
        LD      A,C             ; A := C (timer)
        AND     $07             ; mask bits, now betwen 0 and 7.  zero ?
        RET     NZ              ; no, return

        LD      A,B             ; restore A which has girl's sprite
        XOR     $03             ; toggle bits 0 and 1
        LD      ($6905),A       ; store into girl's sprite
        RET                    ;ret to #19B3 - main routine

; arrive here when we are on the rivets level

        LD      A,$10           ; A := #10 = code for clear space
        LD      HL,$7623        ; load HL with video RAM for girl location
        CALL    $0514           ; clear the "help" the girl yells on the left side
        LD      HL,$7583        ; load HL with video RAM right of girl
        CALL    $0514           ; clear the "help" the girl yells on the right side
        BIT     6,C             ; check timer bit 6.  zero?
        JP      Z,$0509         ; yes, skip ahead

        LD      A,($6203)       ; load A with mario X position
        CP      $80             ; is mario on left side of screen ?
        JP      NC,$04F1        ; yes, skip ahead

        LD      A,$DF           ; else A := #DF
        LD      HL,$7623        ; load HL with video RAM for girl location
        CALL    $0514           ; draw "help" on the left side

        LD      A,($6901)       ; load A with sprite used for girl
        OR      $80             ; set bit 7
        LD      ($6901),A       ; store into sprite used for girl
        LD      A,($6905)       ; load A with girl's sprite
        OR      $80             ; set bit 7
        JP      $04AC           ; jump back and animate girl

        LD      A,$EF           ; A := #EF
        LD      HL,$7583        ; load HL with video RAM for girl location
        CALL    $0514           ; draw "help" on the right side

        LD      A,($6901)       ; load A with sprite used for girl
        AND     $7F             ; mask bits, turns off bit 7
        LD      ($6901),A       ; store result
        LD      A,($6905)       ; load A with girl's sprite
        AND     $7F             ; mask bits, turns off bit 7
        JP      $04AC           ; jump back and store into girl's sprite and check for animation and RET

; jump from $04CE

        LD      A,($6203)       ; load A with mario X position
        CP      $80             ; is mario on left side of screen?
        JP      NC,$04F9        ; yes, jump back

        JP      $04E1           ; else jump back

;
; this sub gets called a lot
; HL is preloaded with an address of video RAM ?
; DE is preloaded with an offset to add
; A is preloaded with a value to write
; writes A into HL, A-1 into HL+DE, A-2 into HL+2DE
;

        LD      B,$03           ; for B = 1 to 3

        LD      (HL),A          ; store A into memory
        ADD     HL,DE           ; next memory
        DEC     A               ; decrease A
        DJNZ    $0516           ; next B

        RET

;
; Task $0, arrive from jump at $0306
; adds score
; parameter in A is the score to add in hundreds
;

        LD      C,A             ; copy score to C
        RST     $8              ; only continue if credits exist or someone is playing, else RET
        CALL    $055F           ; load DE with address of player score
        LD      A,C             ; load score
        ADD     A,C             ; double
        ADD     A,C             ; triple
        LD      C,A             ; C is now 3 times A for use in the scoring table
        LD      HL,$3529        ; $3529 holds table data for scoring
        LD      B,$00           ; B := 0
        ADD     HL,BC           ; add offset for scoring table
        AND     A               ; clear carry flag
        LD      B,$03           ; for B = 1 to 3

        LD      A,(DE)          ; load A with current score
        ADC     A,(HL)          ; add the amount the player just scored
        DAA                     ; decimal adjust
        LD      (DE),A          ; store result in score
        INC     DE              ; next byte of score
        INC     HL              ; next byte of score to add
        DJNZ    $052E           ; Next B

        PUSH    DE              ; save DE
        DEC     DE              ; DE is now the last byte of score
        LD      A,(PlayerTurnA)       ; 0 for player 1, 1 for player 2
        CALL    $056B           ; update onscreen score
        POP     DE              ; restore DE
        DEC     DE              ; decrement
        LD      HL,$60BA        ; load HL with high score address
        LD      B,$03           ; for B = 1 to  3

        LD      A,(DE)          ; load A with player score
        CP      (HL)            ; compare to high score
        RET     C               ; if less, then return

        JP      NZ,$0550        ; if greater, then skip ahead to update

        DEC     DE              ; next score byte
        DEC     HL              ; next highscore byte
        DJNZ    $0545           ; next B

        RET

        CALL    $055F           ; load DE with address of player score
        LD      HL,$60B8        ; load HL with high score address

        LD      A,(DE)          ; load A with player score byte
        LD      (HL),A          ; store into high score byte
        INC     DE              ; next address
        INC     HL              ; next address
        DJNZ    $0556           ; next B

        JP      $05DA           ; skip ahead to update high score onscreen

; called from $051E and $0550
; loads DE with address of current player's score

        LD      DE,$60B2        ; load DE with player 1 score
        LD      A,(PlayerTurnA) ; load number of players
        AND     A               ; is this player 2 ?
        RET     Z               ; no, return

        LD      DE,$60B5        ; else load DE with player 2 score
        RET

; called from $053B
; update onscreen score

        LD      IX,$7781        ; load IX with the start of the score in video RAM (100,000's place)
        AND     A               ; is this player 1?
        JR      Z,$057C         ; Yes, jump ahead

        LD      IX,$7521        ; else load IX with #7521 - the start of player 2 score (100,000's place)
        JR      $057C           ; skip next step

        LD      IX,$7641        ; $7641 is the start of high score 100,000 place

        EX      DE,HL           ; DE <> HL
        LD      DE,$FFE0        ; offset is inverse of 20 ?  to add to next column in scoreboard
        LD      BC,$0304        ; For B = 1 to 3

; can arrive here from $0627 to draw number of credits

        LD      A,(HL)          ; get digit
        RRCA
        RRCA
        RRCA
        RRCA                    ; rotate right 4 times
        CALL    $0593           ; draw to screen
        LD      A,(HL)          ; get digit
        CALL    $0593           ; draw to screen
        DEC     HL              ; next digit
        DJNZ    $0583           ; Next B

        RET

; called from $0588 and $058C above

        AND     $0F             ; mask out left 4 bits of A
        LD      (IX+$00),A      ; store A on screen
        ADD     IX,DE           ; adjust to next location
        RET

;
; task $1
; called from $0306
; parameter is 0 when 1 player game, 1 when 2 player game
; clears score and runs task $2 as well
;

        CP      $03             ; task parameter < 3 ?
        JP      NC,$05BD        ; yes, skip ahead [when would it do this???  A always 0 or 1 ???]

; $60B2, $60B3, $60B4 - player 1 score

; $60B5, $60B6, $60B7 - player 2 score

        PUSH    AF              ; save AF
        LD      HL,$60B2        ; load HL with player 1 score
        AND     A               ; parameter == 0 ?
        JP      Z,$05AB         ; yes, skip next step

        LD      HL,$60B5        ; else load HL with player 2 score
        CP      $02             ; parameter == 2 ? [when would it do this ??? A always 0 or 1 ??? ]
        JP      NZ,$05B3        ; no, skip next step

        LD      HL,$60B8        ; load HL with high score

        XOR     A               ; A := 0
        LD      (HL),A          ; clear score
        INC     HL              ; next score memory
        LD      (HL),A          ; clear score
        INC     HL              ; next score memory
        LD      (HL),A          ; clear score
        POP     AF              ; restore AF
        JP      $05C6           ; jump ahead to task 2

; never arrive here ???

        DEC     A               ; decrease A
        PUSH    AF              ; save AF
        CALL    $059B           ; ???  call myself ???
        POP     AF              ; restore AF
        RET     Z              ;ret if Zero

        JR      $05BD           ; else loop again

;
; task $2 - displays score
; called from $0306 and at end of task #1, from #05BA
; parameter is 0 for player 1, 1 for player 2, and 3 for high score
;

        CP      $03             ; task parameter == 3 ?
        JP      Z,$05E0         ; yes, skip ahead to handle high score

        LD      DE,$60B4        ; load DE with player 1 score
        AND     A               ; parameter == 0 ? (1 player game)
        JP      Z,$05D5         ; yes, skip next step

        LD      DE,$60B7        ; else load DE with player 2 score

        CP      $02             ; parameter == 2 ?
        JP      NZ,$056B        ; no, jump back and display score

; arrive here from $055C

        LD      DE,$60BA        ; yes, load DE with high score
        JP      $0578           ; jump back and display high score

        DEC     A               ; decrease A
        PUSH    AF              ; save AF
        CALL    $05C6           ; call this sub again for the lower parameter
        POP     AF              ; restore AF.  A == 0 ?  are we done?
        RET     Z               ; yes, return

        JR      $05E0           ; else loop back again

; task $3
; draws text to screen
; called from $0306 with code for text to draw in A

        LD      HL,$364B        ; start of table data
        ADD     A,A             ; double the parameter
        PUSH    AF              ; save AF to stack
        AND     $7F             ; mask bits
        LD      E,A             ; copy to E
        LD      D,$00           ; D := 0
        ADD     HL,DE           ; add to table to get pointer
        LD      E,(HL)          ; load E with first byte from table
        INC     HL              ; next table entry
        LD      D,(HL)          ; load D with 2nd byte from table
        EX      DE,HL           ; DE <> HL
        LD      E,(HL)          ; load E with 1st byte from dereferenced table
        INC     HL              ; next table entry
        LD      D,(HL)          ; load D with 2ndy byte from derefernced table
        INC     HL              ; next table entry
        LD      BC,$FFE0        ; load BC with offset to print characters across
        EX      DE,HL           ; DE <> HL.  HL now has screen destination, DE has table pointer

        LD      A,(DE)          ; load A with table data
        CP      $3F             ; end code reached?
        JP      Z,$0026         ; yes, return to program.  This will effectively RET twice

        LD      (HL),A          ; draw letter to screen
        POP     AF              ; restore AF from stack.  is there a carry?
        JR      NC,$060C        ; no, skip next step

        LD      (HL),$10        ; yes, write a blank space to the screen

        PUSH    AF              ; save AF
        INC     DE              ; next table data
        ADD     HL,BC           ; add screen offset for next column
        JR      $0600           ; loop again

;
; task $4
; jump from $0306
; draws credits on screen if any are present
;

        LD      A,(NoCredits)   ; 1 when no credits have been inserted; 0 if any credits exist
        RRCA                    ; credits in game ?
        RET     NC              ; yes, return

; called from $08F0

        LD      A,$05           ; load text code for "CREDIT"
        CALL    $05E9           ; draw to screen
        LD      HL,NumCredits   ; load HL with pointer to number of credits
        LD      DE,$ffe0        ; load DE with #ffe0 = offset for columns?
        LD      IX,$74Bf        ; load IX with screen address to draw
        LD      B,$01           ; B := 1
        JP      $0583           ; jump back to draw number of credits on screen and return

;
; task $5
; called from $0306
; parameter 0 = adds bonus to player's score
; parameter 1 = update onscreen bonus timer and play sound & change to red if below 1000

        AND     A               ; parameter == 0 ?
        JP      Z,$0691         ; yes, skip ahead and add bonus to player's score

        LD      A,($638C)       ; else load onscreen timer
        AND     a               ; timer == 0 ?
        JP      NZ,$06A8        ; no, jump ahead

        LD      A,($63B8)       ; else load A with timer expired indicator
        AND     a               ; has timer expired ?
        RET     NZ              ; yes, return

; the following code sets up the on screen timer initial value

        LD      A,($62B0)       ; load a with value from #62B0 (expects a decimal number here)
        LD      BC,$000A        ; B := 0, C := #0A (10 decimal)

        INC     b               ; increment b
        SUB     c               ; subtract 10 decimal from A
        JP      NZ,$0640        ; loop again if not zero; counts how many tens there are

        LD      A,b             ; load a with the number of tens in the counter
        RLCA                    ; rotate left (x2)
        RLCA                    ; rotate left (x4)
        RLCA                    ; rotate left (x8)
        RLCA                    ; rotate left (x16)
        LD      ($638C),A       ; load on screen timer with result.  hex value converts to decimal.


        LD      HL,$384A        ; load HL with #384A - table data
        LD      DE,$7465        ; load DE with #7465 - screen location for bonus timer
        LD      A,$06           ; For A = 1 to 6

; draws timer box on screen with all zeros

        LD      IX,$001D        ; load IX with #001D offset used for each column
        LD      BC,$0003        ; counter := 3
        LDIR                    ; transfer (HL) to (DE) 3 times
        ADD     IX,DE           ; add offset DE to IX
        PUSH    IX              ;
        POP     de              ; load DE with IX
        DEC     a               ; decrease counter
        JP      NZ,$0655        ; loop again if not zero

; check to see if timer is below 1000

        LD      A,($638C)       ; load a with value from on screen timer

        LD      c,A             ; copy to C
        AND     $0F             ; zeroes out left 4 bits
        LD      B,A             ; store result in B
        LD      A,C             ; restore a with original value from timer
        RRCA                    ; rotate right 4 times.  divides by 16
        RRCA
        RRCA
        RRCA
        AND     $0F             ; and with #0F - zero out left 4 bits
        JP      NZ,$0689        ; jump if not zero to #0689

; arrive here when timer runs below 1000

        LD      A,$03           ; else load A with warning sound
        LD      ($6089),A       ; set warning sound
        LD      A,$70           ; A := #70 = color code for red?
        LD      ($7486),A       ; store A into #7486 = paint score red (MSB) ?
        LD      ($74A6),A       ; store A into #74A6 = paint score red (LSB) ?
        ADD     A,b             ; A = A + B
        LD      B,A             ; B := A
        LD      A,$10           ; A = #10 = code for blank space

        LD      ($74E6),A       ; draw timer to screen (MSB)
        LD      A,b             ; A := B
        LD      ($74C6),A       ; draw timer to screen (LSB)
        RET

;
; continuation of task $5 when parameter = 0 from #062B
; adds bonus to player's score
;

        LD      A,($638C)       ; load A with timer value from #638C
        LD      B,A             ; copy to B
        AND     $0F             ; and with #0F - mask four left bits.  how has low byte of bonus
        PUSH    BC              ; save BC
        CALL    $051C           ; add to score
        POP     BC              ; restore BC
        LD      A,b             ; load A with timer
        RRCA                    ; rotate right 4 times
        RRCA
        RRCA
        RRCA
        AND     $0F             ; mask four left bits to zero
        ADD     A,$0A           ; add #0A (10 decimal) - this indicates scores of thousands to add
        JP      $051C           ; jump to add score (thousands) and RET

; jump here from $0632

        SUB     $01             ; subtract 1 from bonus timer
        JR      NZ,$06b1        ; If not zero, skip next 2 steps

; timer at zero

        LD      HL,$63B8        ; load HL with mario dead flag
        LD      (HL),$01        ; store 1 - mario will die soon on next timer click

        DAA                     ; Decimal adjust
        LD      ($638C),A       ; store A into timer
        JP      $066A           ; jump back

;
; task $6
; called from $01DC and $0306.  also jump here from #037C after high score has been exceeded
; parameter used to subtract the number of lives to draw
;

        LD      C,A             ; load C with the task parameter
        RST     $8              ; is the game being played or credits exists?  If so, continue.  Else RET

        LD      B,$06           ; For B = 1 to 6
        LD      DE,$FFE0        ; load DE with offset for next column
        LD      HL,$7783        ; load HL with screen location where mario extra lives drawn

        LD      (HL),$10        ; clear this area of screen
        ADD     HL,DE           ; add offset for next column
        DJNZ    $06C2           ; next B

        LD      A,($6228)       ; load A with number of lives remaining
        SUB     C               ; subtract the task parameter.  zero lives to draw?
        JP      Z,$06D7         ; yes, skip next 5 steps

        LD      B,A             ; For B = 1 to A
        LD      HL,$7783        ; load HL with screen location to draw remaining lives

        LD      (HL),$FF        ; draw the extra mario
        ADD     HL,DE           ; add offset for next column
        DJNZ    $06D2           ; next B

        LD      HL,$7503        ; load HL with screen location for "L="
        LD      (HL),$1C        ; draw "L"
        LD      HL,$74E3        ; next location
        LD      (HL),$34        ; draw "="
        LD      A,($6229)       ; load A with level #
        CP      $64             ; level < #64 (100 decimal) ?
        JR      c,$06Ed         ; yes, skip next 2 steps

        LD      A,$63           ; otherwise A := #63 (99 decimal)
        LD      ($6229),A       ; store into level #

        LD      BC,$ff0A        ; B: = #FF, C := #0A (10 decimal)

        INC     b               ; increment B
        SUB     c               ; subtract 10 decimal
        JP      NC,$06f0        ; not carry, loop again (counts tens)

        ADD     A,C             ; add 10 back to A to get a number from 0 to 9
        LD      ($74A3),A       ; draw level to screen (low byte)
        LD      A,b             ; load a with b (number of tens)
        LD      ($74C3),A       ; draw level to screen (high byte)
        RET

; start of main routine when playing a game
; arrive here from $00C9

        LD      A,(GameMode2)   ; load A with game mode2
        RST     $28             ; jump based on what the game state is

        hex       86 09         ; (0) #0986     game start = clears screen, clears sounds, sets screen flip if needed
        hex       AB 09         ; (1) #09AB     copy player data, set screen, set next game mode based on number of players
        hex       D6 09         ; (2) #09D6     clears palettes, draws "PLAYER <I>", draws player2 score, draws "2UP" (2 player game only)
        hex       FE 09         ; (3) #09FE     copy player data into correct area (2 player game only)
        hex       1B 0A         ; (4) #0A1B     clears palletes, draws "PLAYER <II>", update player2 score, draw "2UP" to screen (2 player game only)
        hex       37 0A         ; (5) #0A37     updates high score, player score, remaining lives, level, 1UP
        hex       63 0A         ; (6) #0A63     clears screen and sprites, check for intro screen to run
        hex       76 0A         ; (7) #0A76     kong clims ladders and scary music played
        hex       DA 0B         ; (8) #0BDA     draw goofy kongs, how high can you get, play music
        hex       00 00         ; (9)           unused
        hex       91 0C         ; (A) #0C91     clears screen, update timers, draws current screen, sets background music
        hex       3C 12         ; (B) #123C     set initial mario sprite position and draw remaining lives and level
        hex       7A 19         ; (C) #197A     for when playing a game.  this is the main routine
        hex       7C 12         ; (D) #127C     mario died.  handle mario dying animations
        hex       F2 12         ; (E) #12F2     clear sounds, decrease life, check for and handle game over
        hex       44 13         ; (F) #1344     clear sounds, clear game start flag, draw game over if needed PL2, set game mode2 accordingly
        hex       8F 13         ; (10) #138F    check for game over status on a 2 player game
        hex       A1 13         ; (11) #13A1    check for game over status on a 2 player game
        hex       AA 13         ; (12) #13AA    flip screen if needed, reset game mode2 to zero, set player 2
        hex       BB 13         ; (13) #13BB    set player 1, reset game mode2 to zero, set screen flip to not flipped
        hex       1E 14         ; (14) #141E    draw credits on screen, clears screen and sprites, checks for high score, flips screen if necessary
        hex       86 14         ; (15) #1486    player enters initials in high score table
        hex       15 16         ; (16) #1615    handle end of level animations
        hex       6B 19         ; (17) #196B    clear screen and all sprites, set game mode2 to #12 for player1 or #13 for player2
        hex       00 00 00 00 00 00 00 00 00 00 ; unused

; arrive from $00C9 when attract mode starts

        LD      HL,GameMode2    ; load HL with game mode2 address
        LD      A,(NumCredits)  ; load A with number of credits
        AND     A               ; any credits exist ?
        JP      NZ,$075C        ; yes, skip ahead, zero out game mode2, increase game mode1, and RET

        LD      A,(HL)          ; else load A with game mode2
        RST     $28             ; jump based on A

        hex     79 07           ; 0       #0779         ; clear screen, set color palettes, draw attract mode text and high score table,
                                                        ; [continued] increase game mode2, clear sprites, ; draw "1UP" on screen , draws number of coins needed for play
        hex     63 07           ; 1       #0763
        hex     3C 12           ; 2       #123C         set initial mario sprite position and draw remaining lives and level
        hex     77 19           ; 3       #1977         set artificial input for demo play [change to #197A to enable playing in demo part 1/2]
        hex     7C 12           ; 4       #127C         handle mario dying animations
        hex     C3 07           ; 5       #07C3         clears the screen and sprites and increase game mode2
        hex     CB 07           ; 6       #07CB         handle intro splash screen ?
        hex     4B 08           ; 7       #084B         counts down a timer then resets game mode2 to 0
        hex     00 00 00 00     ; unused

; arrive from $0743 when credits exist

        LD      (HL),$00        ; set game mode2 to zero
        LD      HL,GameMode1    ; load HL with game mode1
        INC     (HL)            ; increase
        RET

; arrive here from $0747 during attract mode when GameMode2 == 1

        RST     $20             ; only continue here once per frame, else RET

        XOR     A               ; A := 0
        LD      ($6392),A       ; clear barrel deployment indicator
        LD      ($63A0),A       ; clear fireball release indicator
        LD      A,$01           ; A := 1
        LD      ($6227),A       ; load screen number with 1
        LD      ($6229),A       ; load level # with 1
        LD      ($6228),A       ; load number of lives with 1
        JP      $0C92           ; skip ahead

; arrive from $0747 when GameMode2 == 0
; clear screen, set color palettes, draw attract mode text and high score table, increase game mode2, clear sprites, ; draw "1UP" on screen , draws number of coins needed for play

        LD      HL,REG_PALETTE_A
        LD      (HL),$00                ; clear palette bank selector
        INC     HL
        LD      (HL),$00                ; clear palette bank selector
        LD      DE,$031B                ; load task data for text "INSERT COIN"
        CALL    $309F                   ; insert task to draw text
        INC     E                       ; load task data for text "PLAYER    COIN"
        CALL    $309F                   ; insert task to draw text
        CALL    $0965                   ; draws credits on screen if any are present and displays high score table
        LD      HL,WaitTimerMSB         ; load HL with timer address
        LD      (HL),$02                ; set timer at 2
        INC     HL                      ; load HL with game mode2
        INC     (HL)                    ; increase
        CALL    $0874                   ; clears the screen and sprites
        CALL    $0A53                   ; draw "1UP" on screen
        LD      A,(TwoPlayerGame)       ; load A with number of players in game
        CP      $01                     ; 2 player game?
        CALL    Z,$09EE                 ; yes, skip ahead to handle

        LD      DE,(CoinsPerCredit)     ; D := CoinsPer2Credits; E := CoinsPerCredit
        LD      HL,$756C                ; load HL with screen RAM location
        CALL    $07AD                   ; run this sub below twice

        LD      (HL),E                  ; draw to screen number of coins needed for 1 player game
        INC     HL                      ;
        INC     HL                      ; next screen location 2 rows down
        LD      (HL),D                  ; draw to screen number of coins neeeded for 2 player game
        LD      A,D                     ; A := D
        SUB     $0A                     ; subtract #A (10 decimal). result == 0 ?
        JP      NZ,$07BC                ; no, skip next 3 steps

        LD      (HL),A                  ; else draw this zero to screen
        INC     A                       ; increase A, A := 1 now
        LD      ($758E),A               ; draw 1 to screen in front of the zero, so it draws "10" credits needed for 2 players

        LD      DE,$0201                ; D := 2, E := 1, used for next loop for 1 player and 2 players
        LD      HL,$768C                ; set screen location to draw for next loop if needed
        RET

; arrive from $0747 when GameMode2 == 5

        CALL    $0874           ; clears the screen and sprites
        LD      HL,GameMode2    ; load HL with game mode 2
        INC     (HL)            ; increase game mode2
        RET

; arrive from jump at $0747 when GameMode2 == 6

        LD      A,($638A)       ; load A with kong screen flash counter
        CP      $00             ; == 0 ?  time to flash?
        JP      NZ,$082D        ; no, skip ahead : load C with (#638B), decreases #638A, loads A with (#638A); loads C with #638B, decreases #638A returns to #07DA

        LD      A,$60           ; else A := #60
        LD      ($638A),A       ; store into kong screen flash counter
        LD      C,$5F           ; C := #5F

; can arrive here from jump at $0838

        CP      $00                     ; A == 0 ? [why not AND A ?]
        JP      Z,$083B                 ; yes, skip ahead

        LD      HL,REG_PALETTE_A        ; load pallete bank
        LD      (HL),$00                ; clear palette bank selector
        LD      A,C                     ; A := C
        RLC     A                       ; rotate left.  carry bit set?
        JR      NC,$07EB                ; no, skip next step

        LD      (HL),$01                ; set pallete bank selector to 1

        INC     HL                      ; HL := REG_PALETTE_B = 2nd pallete bank
        LD      (HL),$00                ; clear the pallete bank selector
        RLC     A                       ; rotate left again.  carry bit set ?
        JR      NC,$07F4                ; no, skip next step

        LD      (HL),$01                ; set pallete bank selector to 1

        LD      ($638B),A               ; store A into ???

; draws DONKEY KONG logo to screen

        LD      HL,$3D08        ; load HL with start of table data

        LD      A,$B0           ; A := #B0 = code for girder on screen
        LD      B,(HL)          ; get first data.  this is used as a loop counter
        INC     HL              ; next table entry
        LD      E,(HL)          ; load E with table data
        INC     HL              ; next entry
        LD      D,(HL)          ; load D with table data.  DE now has an address

        LD      (DE),A          ; draw girder on screen
        INC     DE              ; next address
        DJNZ    $0801           ; Next B

        INC     HL              ; next table entry
        LD      A,(HL)          ; get data
        CP      $00             ; done ?
        JP      NZ,$07FA        ; no, loop again

        LD      DE,$031E        ; load task data for text "(C) 1981"
        CALL    $309F           ; insert task to draw text
        INC     DE              ; load task data for text "NINTENDO OF AMERICA"
        CALL    $309F           ; insert task to draw text
        LD      HL,$39CF        ; load HL with table data for kong beating chest
        CALL    $004E           ; update kong's sprites
        CALL    $3F24           ; draw TM logo onscreen [patch? orig japanese had 3 NOPs here]
        NOP                     ; no operation
        LD      HL,$6908        ; load HL with start of kong sprite X pos
        LD      C,$44           ; load C with offset to add X
        RST     $38             ; draw kong in new position
        LD      HL,$690B        ; load HL with start of kong sprite Y pos
        LD      C,$78           ; load C with offset to add Y
        RST     $38             ; draw kong
        RET

; jump here from $07D0
; loads C with $638B, decreases $638A

        LD      A,($638B)       ; load A with ???
        LD      C,A             ; copy to C
        LD      A,($638A)       ; load A with kong intro flash counter
        DEC     A               ; decrease
        LD      ($638A),A       ; store result
        JP      $07DA           ; jump back

; jump here from $07DC

        LD      HL,WaitTimerMSB ; load HL with timer address
        LD      (HL),$02        ; set timer to 2
        INC     HL              ; HL := GameMode2
        INC     (HL)            ; increase game mode2
        LD      HL,$638A        ; load HL with kong intro flash counter
        LD      (HL),$00        ; clear counter
        INC     HL              ; HL := #638B = ???
        LD      (HL),$00        ; clear this memory
        RET

; arrive from $0747 when GameMode2 == 7

        RST     $20             ; update timer and continue here only when complete, else RET

        LD      HL,GameMode2    ; load HL with game mode2
        LD      (HL),$00        ; set to 0
        RET

; called from $0986
; clears screen and all sprites

        LD      HL,$7400        ; $7400 is beginning of video RAM
        LD      C,$04           ; for C= 1 to 4
        LD      B,$00           ; for B = 1 to 256
        LD      A,$10           ; $10 is clear for screen in video RAM

        LD      (HL),A          ; clear this screen element
        INC     HL              ; next screen location
        DJNZ    $085B           ; Next B

        DEC     C               ; Next C
        JP      NZ,$0857        ; loop until done

        LD      HL,$6900        ; load HL with start of sprite RAM
        LD      C,$02           ; for C = 1 to 2
        LD      B,$C0           ; for B = 1 to #C0
        XOR     A               ; A := 0

        LD      (HL),A          ; clear RAM
        INC     HL              ; next memory
        DJNZ    $086B           ; next B

        DEC     C               ; next C
        JP      NZ,$0868        ; loop until done

        RET

; called from many places.  EG $08BA and #01C3 and #0C92 and other places
; clears the screen and sprites

        LD      HL,$7404        ; load HL with start of video RAM
        LD      C,$20           ; For C = 1 to #20

        LD      B,$1C           ; for B = 1 to #1C
        LD      A,$10           ; A := #10
        LD      DE,$0004        ; DE = 4, used as offset to add later

        LD      (HL),A          ; store into memory
        INC     HL              ; next memory
        DJNZ    $0880           ; Next B

        ADD     HL,DE           ; add offset of 4
        DEC     C               ; decrease counter
        JP      NZ,$0879        ; loop until zero

        LD      HL,$7522        ; load HL with screen location
        LD      DE,$0020        ; load DE with offset to use
        LD      C,$02           ; for C = 1 to 2
        LD      A,$10           ; A := #10 = clear screen byte

        LD      B,$0E           ; for B = 1 to #0E
        LD      (HL),A          ; clear the screen element
        ADD     HL,DE           ; add offset for next
        DJNZ    $0895           ; Next B

        LD      HL,$7523        ; load HL with next screen location
        DEC     C               ; done ?
        JP      NZ,$0893        ; no, loop again

        LD      HL,$6900        ; load HL with start of sprite RAM
        LD      B,$00           ; For B = 0 to #FF
        LD      A,$00           ; A := 0

        LD      (HL),A          ; clear memory
        INC     HL              ; next memory
        DJNZ    $08A7           ; Next B

        LD      B,$80           ; For B = 0 to #80
        LD      (HL),A          ; store memory
        INC     HL              ; next memory
        DJNZ    $08AD           ; Next B

        RET

; jump from $00C9
; arrive here when credits have been inserted, waiting for game to start

        LD      A,(GameMode2)   ; load A with game mode2

; GameMode2 = 1 during attract mode, 7 during intro , A during how high can u get,
;         B right before play, C during play, D when dead, 10 when game over

        RST     $28                     ; jump based on A

        hex     BA 08                   ; #08BA display screen to press start etc.
        hex     F8 08                   ; #08F8 wait for start buttons to be pressed

        CALL    $0874                   ; clear the screen and sprites
        XOR     A                       ; A := 0
        LD      (NoCredits),A           ; store into credit indicator
        LD      DE,$030C                ; load DE with task code to display "PUSH" onscreen
        CALL    $309F                   ; insert task
        LD      HL,GameMode2            ; load A with game mode2
        INC     (HL)                    ; increase game mode2
        CALL    $0965                   ; draw credits on screen if any are present and displays high score table
        XOR     A                       ; A := 0
        LD      HL,REG_PALETTE_A        ; load HL with pallete bank
        LD      (HL),A                  ; clear palette bank selector
        INC     L                       ; next pallete bank
        LD      (HL),A                  ; clear palette bank selector

; called from $08F8

        LD      B,$04                   ; B := 4 = 0100 binary
        LD      E,$09                   ; E := 9 , code for "ONLY 1 PLAYER BUTTON"
        LD      A,(NumCredits)          ; load A with number of credits
        CP      $01                     ; == 1 ?
        JP      Z,$08E4                 ; yes, skip next 2 steps

        LD      B,$0C                   ; B := #0C = 1100 binary
        INC     E                       ; E := #0A, code for "1 OR 2 PLAYERS BUTTON"

        LD      A,(FrameCounter)        ; load A with # Timer constantly counts down from FF to 00
        AND     $07                     ; mask bits. zero ?
        JP      NZ,$08F3                ; no, skip next 3 steps

        LD      A,E                     ; yes, load A with E for code of text to draw, for buttons to press to start
        CALL    $05E9                   ; draw text to screen
        CALL    $0616                   ; draw credits on screen

        LD      A,(IN2)                 ; load A with IN2 [Credit/Service/Start Info]
        AND     B                       ; mask bits with B
        RET

; jump from $08B5 when GameMode2 == 1

        CALL    $08D5           ; draws press player buttons and loads A with IN2, masked by possible player numbers
        CP      $04             ; is the player 1 button pressed ?
        JP      Z,$0906         ; yes, skip ahead

        CP      $08             ; is the player 2 button pressed ?
        JP      Z,$0919         ; yes, skip ahead

        RET                     ; ret to #00D2

; player 1 start

        CALL    $0977           ; subtract 1 credit and update screen credit counter
        LD      HL,P2NumLives   ; load HL with RAM used for player 2
        LD      B,$08           ; for B = 1 to 8
        XOR     A               ; A := 0

        LD      (HL),A          ; clear memory
        INC     L               ; next memory
        DJNZ    $090F           ; Next B

        LD      HL,$0000        ; clear HL
        JP      $0938           ; skip ahead

; 2 players start

        CALL    $0977                   ; subtract 1 credit and update screen credit counter
        CALL    $0977                   ; subtract 1 credit and update screen credit counter
        LD      DE,P2NumLives           ; load DE with RAM location used for player 2
        LD      A,(StartingLives)       ; load initial number of lives
        LD      (DE),A                  ; store into number of lives player 2
        INC     E                       ; DE := Unk6049
        LD      HL,$095E                ; load HL with source data table start
        LD      BC,$0007                ; counter = 7
        LDIR                            ; copy #095E into Unk6049 for 7 bytes
        LD      DE,$0101                ; load task #1, parameter 1.  clears player 1 and 2 scores and displays them.
        CALL    $309F                   ; insert task
        LD      HL,$0100                ; HL := #100

        LD      (PlayerTurnB),HL        ; store HL into PlayerTurnB and TwoPlayerGame.  TwoPlayerGame is the number of players in the game
        CALL    $0874                   ; clear the screen and sprites
        LD      DE,P1NumLives           ; load DE with address for number of lives player 1
        LD      A,(StartingLives)       ; number of initial lives set with dip switches (3, 4, 5, or 6)
        LD      (DE),A                  ; store into number of lives
        INC     E                       ; DE := Unk6041
        LD      HL,$095E                ; load HL with start of table data
        LD      BC,$0007                ; counter = 7
        LDIR                            ; copy #095E into Unk6041 for 7 bytes
        LD      DE,$0100                ; load task #1, parameter 0.  clears player 1 score and displays it
        CALL    $309F                   ; insert task
        XOR     A                       ; A := 0
        LD      (GameMode2),A           ; reset game mode2
        LD      A,$03                   ; A := 3
        LD      (GameMode1),A           ; store into game mode1
        RET

; table data use in code above - gets copied to Unk6041 to Unk6041+7

        hex      01 65 3A 01 00 00 00   ; #3A65 is start of table data for screens/levels

; called from $08CB

        LD      DE,$0400        ; set task #4 = draws credits on screen if any are present
        CALL    $309F           ; insert task
        LD      DE,$0314        ; set task #3, parameter 14 through 1A.  For display of high score table
        LD      B,$06           ; for B = 1 to 6

        CALL    $309F           ; insert task
        INC     E               ; increase task parameter
        DJNZ    $0970           ; Next B

        RET

; subtract 1 credit and update screen credit counter

        LD      HL,NumCredits   ; load HL with pointer to number of credits
        LD      A,$99           ; A := #99
        ADD     A,(HL)          ; add to number of credits.   equivalent of subtracting 1
        DAA                     ; decimal adjust
        LD      (HL),A          ; store into number of credits
        LD      DE,$0400        ; set task #4 = draws credits on screen if any are present
        CALL    $309F           ; insert task
        RET

; arrive here when a game begins
; clears screen, clears sounds, sets screen flip if needed
; jump from $0701 when GameMode2 == 0

        CALL    $0852                   ; clear screen and all sprites
        CALL    $011C                   ; clear all sounds
        LD      DE,REG_FLIPSCREEN       ; load DE with flip screen setting
        LD      A,$01                   ; A := 1
        LD      (DE),A                  ; store
        LD      HL,GameMode2            ; load HL with game mode 2 address
        LD      A,(PlayerTurnB)         ; load A with 0 when player 1 is up, = 1 when player 2 is up
        AND     A                       ; is player 1 up?
        JP      NZ,$099F                ; no, skip next 2 steps

        LD      (HL),$01                ; set game mode 2 to 1
        RET

        LD      A,(UprightCab)          ; load A with upright/cocktail
        DEC     A                       ; is this cocktail mode ?
        JP      Z,$09A8                 ; no, skip next 2 steps

        XOR     A                       ; A := 0
        LD      (DE),A                  ; set screen to flipped

        LD      (HL),$03                ; set game mode 2 to 3
        RET

; jump from $0701 when GameMode2 == 1
; copy player data, set screen, set next game mode based on number of players

        LD      HL,P1NumLives           ; load HL with source data location
        LD      DE,$6228                ; load DE with destination data location.  start with remaining lives
        LD      BC,$0008                ; byte counter set to 8
        LDIR                            ; copy (HL) into (DE) from P1NumLives to P2NumLives into #6228 to #622F
        LD      HL,($622A)              ; EG #3A65.  start of table data for screens/levels
        LD      A,(HL)                  ; load screen number from table
        LD      ($6227),A               ; store screen number
        LD      A,(TwoPlayerGame)       ; load A with number of players
        AND     A                       ; 1 player game?
        LD      HL,WaitTimerMSB         ; load HL with timer address
        LD      DE,GameMode2            ; load DE with game mode2 address
        JP      Z,$09D0                 ; if 1 player game, skip ahead

; 2 player game

        LD      (HL),$78        ; store #78 into timer
        EX      DE,HL           ; DE <> HL.  HL now has game mode2
        LD      (HL),$02        ; GameMode2 := 2
        RET

; 1 player game

        LD      (HL),$01        ; store 1 into timer
        EX      DE,HL           ; DE <> HL.  HL now has game mode2
        LD      (HL),$05        ; GameMode2 := 5
        RET


; used to draw players during 2 player game
; jump here from $0701
; clears palettes, draws "PLAYER <I>", draws player2 score, draws "2UP"

        XOR     A                       ; A := 0
        LD      (REG_PALETTE_A),A       ; clear palette bank selector
        LD      (REG_PALETTE_B),A       ; clear palette bank selector
        LD      DE,$0302                ; load task data for text #2 "PLAYER <I>"
        CALL    $309F                   ; insert task to draw
        LD      DE,$0201                ; load task #2, parameter 1 to display player 2 score
        CALL    $309F                   ; insert task
        LD      A,$05                   ; A := 5
        LD      (GameMode2),A           ; store into game mode2

        LD      A,$02                   ; load A with "2"
        LD      ($74E0),A               ; write to screen
        LD      A,$25                   ; load A with "U"
        LD      ($74C0),A               ; write to screen
        LD      A,$20                   ; load A with "P"
        LD      ($74A0),A               ; write to screen
        RET

; arrive from $0701 when GameMode2 == 3

        LD      HL,P2NumLives           ; source location is ???
        LD      DE,$6228                ; destination is player lives remaining plus other player variables
        LD      BC,$0008                ; byte counter set to 8
        LDIR                            ; copy
        LD      HL,($622A)              ; load HL with table for screens/levels
        LD      A,(HL)                  ; load A with screen number from table
        LD      ($6227),A               ; store A into screen number
        LD      A,$78                   ; A := #78
        LD      (WaitTimerMSB),A        ; store into timer
        LD      A,$04                   ; A := 4
        LD      (GameMode2),A           ; store into game mode2
        RET

; arrive from $0701 when GameMode2 == 4
; clears palletes, draws "PLAYER <II>", update player2 score, draw "2UP" to screen

        XOR     A                       ; A := 0
        LD      (REG_PALETTE_A),A       ; clear palette bank selector
        LD      (REG_PALETTE_B),A       ; clear palette bank selector
        LD      DE,$0303                ; load task data for text #3 "PLAYER <II>"
        CALL    $309F                   ; insert task to draw text
        LD      DE,$0201                ; load task #2, parameter 1 to display player 2 score
        CALL    $309F                   ; insert task
        CALL    $09EE                   ; draw "2UP" to screen
        LD      A,$05                   ; A := 5
        LD      (GameMode2),A           ; store into game mode2
        RET

; arrive from $0701 when GameMode2 == 5
; updates high score, player score, remaining lives, level, 1UP

        LD      DE,$0304        ; load task data for text #4 "HIGH SCORE"
        CALL    $309F           ; insert task to draw text
        LD      DE,$0202        ; load task #2, parameter 2 to display high score
        CALL    $309F           ; insert task
        LD      DE,$0200        ; load task #2, parameter 0 to display player 1 score
        CALL    $309F           ; insert task
        LD      DE,$0600        ; load task #6 parameter 0 to display lives remaining and level
        CALL    $309F           ; insert task
        LD      HL,GameMode2    ; load HL with game mode2 address
        INC     (HL)            ; increase game mode

;  called from $01F1 , $0798, and other places
; draw "1UP" on screen

        LD      A,$01           ; load A with "1"
        LD      ($7740),A       ; write to screen
        LD      A,$25           ; load A with "U"
        LD      ($7720),A       ; write to screen
        LD      A,$20           ; load A with "P"
        LD      ($7700),A       ; write to screen
        RET

; arrive from $0701 when GameMode2 == 6
; clears screen and sprites, check for intro screen to run

        RST     $18             ; count down WaitTimerMSB and only continue here if == 0, else return to higher sub.
        CALL    $0874           ; clears the screen and sprites
        LD      HL,WaitTimerMSB ; load HL with timer
        LD      (HL),$01        ; set timer to 1
        INC     L               ; HL := GameMode2
        INC     (HL)            ; increase game mode2 to 7
        LD      DE,$622C        ; load DE with game start flag address
        LD      A,(DE)          ; load A with game start flag
        AND     A               ; is this game just beginning?
        RET     NZ              ; yes, return

        INC     (HL)            ; else increase game mode2 to 8 - skip kong intro to begin
        RET

; arrive from $0701 when GameMode2 == 7

        LD      A,($6385)       ; varies from 0 to 7 while the intro screen runs, when kong climbs the dual ladders and scary music is played
        RST     $28             ; jump based on A

        hex     8A 0A           ; 0       #0A8A
        hex     BF 0A           ; 1       #0ABF
        hex     E8 0A           ; 2       #0AE8
        hex     69 30           ; 3       #3069
        hex     06 0B           ; 4       #0B06
        hex     69 30           ; 5       #3069
        hex     68 0B           ; 6       #0B68
        hex     B3 0B           ; 7       #0BB3

; arrive from $0A79 when intro screen indicator == 0

        XOR     A                       ; A := 0
        LD      (REG_PALETTE_A),A       ; clear palette bank selector
        INC     A                       ; A := 1
        LD      (REG_PALETTE_B),A       ; store into palette bank selector
        LD      DE,$380D                ; load DE with start of table data
        CALL    $0DA7                   ; draw the screen
        LD      A,$10                   ; A := #10
        LD      ($76A3),A               ; erase a graphic near top of screen
        LD      ($7663),A               ; erase a graphic near top of screen
        LD      A,$D4                   ; A := #D4
        LD      ($75AA),A               ; draw a ladder at top of screen
        XOR     A                       ; A := 0
        LD      ($62AF),A               ; store into kong climbing counter
        LD      HL,$38B4                ; load HL with start of table data
        LD      ($63C2),HL              ; store
        LD      HL,$38CB                ; load HL with start of table data
        LD      ($63C4),HL              ; store
        LD      A,$40                   ; A := #40
        LD      (WaitTimerMSB),A        ; set timer to #40
        LD      HL,$6385                ; load HL with intro screen counter
        INC     (HL)                    ; increase
        RET

; arrive from $0A79 when intro screen indicator == 1

        RST     $18             ; count down timer and only continue here if zero, else RET
        LD      HL,$388C        ; load HL with start of table data for kong
        CALL    $004E           ; update kong's sprites
        LD      HL,$6908        ; load HL with start of Kong sprite
        LD      C,$30           ; load offset to add
        RST     $38             ; move kong
        LD      HL,$690B        ; load HL with start of Kong sprite
        LD      C,$99           ; load offset to add
        RST     $38             ; move kong
        LD      A,$1F           ; A := #1F
        LD      ($638E),A       ; store into kong ladder climb counter
        XOR     A               ; A := 0
        LD      ($690C),A       ; store into kong's right arm sprite
        LD      HL,$608A        ; load HL with music buffer
        LD      (HL),$01        ; play scary music for start of game sound
        INC     HL              ; load HL with duration
        LD      (HL),$03        ; set duration to 3
        LD      HL,$6385        ; load HL with intro screen counter
        INC     (HL)            ; increase
        RET

; arrive from $0A79 when intro screen indicator == 2

        CALL    $306F                   ; animate kong climbing up the ladder with girl under arm
        LD      A,($62AF)               ; load A with kong climbing counter
        AND     $0F                     ; mask bits, now between 0 and #F.  zero?
        CALL    Z,$304A                 ; yes, roll up kong's ladder behind him

        LD      A,($690B)               ; load HL with start of Kong sprite
        CP      $5D                     ; < #5D ?
        RET     NC                      ; no, return

        LD      A,$20                   ; A := #20
        LD      (WaitTimerMSB),A        ; set timer to #20
        LD      HL,$6385                ; load HL with intro screen counter
        INC     (HL)                    ; increase
        LD      ($63C0),HL              ; store HL into ???
        RET

; arrive from $0A79 when intro screen indicator == 4

        LD      A,(FrameCounter)        ; load A with this clock counts down from #FF to 00 over and over...
        RRCA                            ; rotate right.  carry bit?
        RET     C                       ; yes, return

        LD      HL,($63C2)              ; load HL with ??? EG HL = #38B4
        LD      A,(HL)                  ; load table data
        CP      $7F                     ; end of data ?
        JP      Z,$0B1E                 ; yes, jump ahead

        INC     HL                      ; next HL
        LD      ($63C2),HL              ; store
        LD      C,A                     ; C := A
        LD      HL,$690B                ; load HL with start of Kong sprite
        RST     $38                     ; move kong
        RET

        LD      HL,$385C                ; load HL with start of kong graphic table data
        CALL    $004E                   ; update kong's sprites
        LD      DE,$6900                ; load destination with girl sprite
        LD      BC,$0008                ; set counter to 8
        LDIR                            ; draw the girl after kong takes her up the ladder
        LD      HL,$6908                ; load HL with kong sprite start address
        LD      C,$50                   ; C := #50
        RST     $38                     ; move kong
        LD      HL,$690B                ; load HL with start of Kong sprite
        LD      C,$FC                   ; C := #FC
        RST     $38                     ; move kong

        CALL    $304A                   ; roll up kong's ladder behind him
        LD      A,($638E)               ; load A with kong ladder climb counter
        CP      $0A                     ; == #A ? (all done)
        JP      NZ,$0B38                ; no, loop again

        LD      A,$03                   ; set boom sound duration
        LD      ($6082),A               ; play boom sound
        LD      DE,$392C                ; load DE with table data start for first angled girder
        CALL    $0DA7                   ; draw the angled girder
        LD      A,$10                   ; A := #10 = clear character
        LD      ($74AA),A               ; clear the right end of the top girder
        LD      ($748A),A               ; clear the right end of the top girder
        LD      A,$05                   ; A := 5
        LD      ($638D),A               ; store into kong bounce counter
        LD      A,$20                   ; A := #20
        LD      (WaitTimerMSB),A        ; set timer to #20
        LD      HL,$6385                ; load HL with intro screen counter
        INC     (HL)                    ; increase
        LD      ($63C0),HL              ; store into ???
        RET

; arrive from $0A79 when intro screen indicator == 6

        LD      A,(FrameCounter)        ; load A with this clock counts down from #FF to 00 over and over...
        RRCA                            ; rotate right.  carry bit set?
        RET     C                       ; yes, return

; make kong jump to the left during intro

        LD      HL,($63C4)      ; load HL with ??? (table data?)
        LD      A,(HL)          ; get table data
        CP      $7F             ; done ?
        JP      Z,$0B86         ; yes, jump ahead

        INC     HL              ; next table entry
        LD      ($63C4),HL      ; store for next
        LD      HL,$690B        ; load HL with start of Kong sprite
        LD      C,A             ; C := A
        RST     $38             ; move kong
        LD      HL,$6908        ; load HL with start of Kong sprite
        LD      C,$FF           ; C := #FF (negative 1)
        RST     $38             ; move kong
        RET

        LD      HL,$38CB        ; load HL with start of table data
        LD      ($63C4),HL      ; store into ???
        LD      A,$03           ; set boom sound duration
        LD      ($6082),A       ; play boom sound
        LD      HL,$38DC        ; load HL with start of table data
        LD      A,($638D)       ; load A with kong bounce counter
        DEC     A               ; decrease
        RLCA
        RLCA
        RLCA
        RLCA                            ; rotate left 4 times (mult by 16)
        LD      E,A                     ; copy to E
        LD      D,$00                   ; D := 0
        ADD     HL,DE                   ; add to HL
        EX      DE,HL                   ; DE <> HL
        CALL    $0DA7                   ; draw the screen
        LD      HL,$638D                ; load HL with kong bounce counter
        DEC     (HL)                    ; decrease.  done bouncing?
        RET     NZ                      ; no, return

        LD      A,$B0                   ; else A := #B0
        LD      (WaitTimerMSB),A        ; store into counter
        LD      HL,$6385                ; load HL with intro screen counter
        INC     (HL)                    ; increase
        RET

; arrive from $0A79 - last part of the intro to the game ?

        LD      HL,$608A                ; load HL with music sound address
        LD      A,(WaitTimerMSB)        ; load A with timer value
        CP      $90                     ; == #90 ?
        JR      NZ,$0BC8                ; no, skip ahead

        LD      (HL),$0F                ; play sound #0F = X X X kong sound
        INC     HL                      ; HL := GameMode2
        LD      (HL),$03                ; set game mode2 to 3
        LD      HL,$6919                ; load HL with kong's face sprite
        INC     (HL)                    ; increase - kong is now showing teeth
        JR      $0BD1                   ; skip ahead

        CP      $18                     ; timer == #18 ?
        JR      NZ,$0BD1                ; no, skip ahead

        LD      HL,$6919                ; load HL with kong's face sprite
        DEC     (HL)                    ; decrease - kong is normal face
        NOP                             ; no operation [?]

        RST     $18                     ; count down timer and only continue here if zero, else RET.  HL is loaded with WaitTimerMSB address
        XOR     A                       ; A := 0
        LD      ($6385),A               ; reset intro screen counter to zero
        INC     (HL)                    ; increase timer in WaitTimerMSB
        INC     HL                      ; HL := GameMode2
        INC     (HL)                    ; increase game mode2 (to 8?)
        RET

; called after kong jump on the girders at start of game ?
; also after mario dies
; how high can you get ?
; draws goofy kongs and 25m, 50m, etc.
; plays music

        CALL    $011C                   ; clear all sounds
        RST     $18                     ; count down timer and only continue here if zero, else RET

        CALL    $0874                   ; clear the screen and sprites
        LD      D,$06                   ; load task #6
        LD      A,($6200)               ; load A with 1 when mario is alive, 0 when dead
        LD      E,A                     ; store into task parameter
        CALL    $309F                   ; insert task to display remaining lives and level number
        LD      HL,REG_PALETTE_A        ; load HL with palette bank
        LD      (HL),$01                ; set palette bank selector
        INC     HL                      ; next pallete bank
        LD      (HL),$00                ; clear palette bank selector
        LD      HL,$608A                ; load HL with tune address
        LD      (HL),$02                ; play how high can you get sound?
        INC     HL                      ; HL := #608B .  load HL with music timer ?
        LD      (HL),$03                ; set to 3 units
        LD      HL,$63A7                ; load HL with address of counter
        LD      (HL),$00                ; clear the counter
        LD      HL,$76DC                ; load HL with screen address to draw the number of meters ?
        LD      ($63A8),HL              ; store - used at #0C54
        LD      A,($622E)               ; load A with number of goofy kongs to draw
        CP      $06                     ; < 6 ?
        JR      C,$0C11                 ; yes, skip next 2 steps [BUG.  change to 0C0A  1805   JR #0C11 to fix]

        LD      A,$05                   ; else A := 5
        LD      ($622E),A               ; store into number of goofy kongs to draw

        LD      A,($622F)               ; load A with current screen/level
        LD      B,A                     ; copy to B
        LD      A,($622A)               ; load A with the low byte of the pointer for lookup to screens/levels
        CP      B                       ; are they the same ?
        JR      Z,$0C1F                 ; yes, skip next 2 steps

        LD      HL,$622E                ; else load HL with number of goofys to draw
        INC     (HL)                    ; increase

        LD      ($622F),A               ; store A into current screen/level
        LD      A,($622E)               ; load A with number of goofys to draw
        LD      B,A                     ; copy to B for use as loop counter, refer to #0C7E
        LD      HL,$75BC                ; load HL with screen location start for goofy kong

        LD      C,$50                   ; C := #50 = start graphic for goofy kong

        LD      (HL),C                  ; draw part of goofy kong
        INC     C                       ; next graphic
        DEC     HL                      ; next screen location
        LD      (HL),C                  ; draw part of goofy kong
        INC     C                       ; next graphic
        DEC     HL                      ; next screen location
        LD      (HL),C                  ; draw part of goofy kong
        INC     C                       ; next graphic
        DEC     HL                      ; next screen location
        LD      (HL),C                  ; draw part of goofy kong
        LD      A,C                     ; load A with graphic number
        CP      $67                     ; == #67 ? (are we done?)
        JP      Z,$0C43                 ; yes, skip next 4 steps

        INC     C                       ; next C
        LD      DE,$0023                ; load DE with offset
        ADD     HL,DE                   ; add to screen location
        JP      $0C2B                   ; loop again

        LD      A,($63A7)               ; load A with counter
        INC     A                       ; increase
        LD      ($63A7),A               ; store
        DEC     A                       ; decrease
        SLA     A
        SLA     A                       ; shift left twice, it is now a usable offset
        PUSH    HL                      ; save HL
        LD      HL,$3CF0                ; load HL with start of table data for 25m, 50m, etc.
        PUSH    BC                      ; save BC
        LD      IX,($63A8)              ; load IX with screen VRAM address to draw number of meters
        LD      C,A                     ; C := A, used for offset
        LD      B,$00                   ; B := 0
        ADD     HL,BC                   ; add offset
        LD      A,(HL)                  ; get table data
        LD      (IX+$60),A              ; write to screen
        INC     HL                      ; next
        LD      A,(HL)                  ; get data
        LD      (IX+$40),A              ; write to screen
        INC     HL                      ; next
        LD      A,(HL)                  ; get table data
        LD      (IX+$20),A              ; write to screen
        LD      (IX-$20),$8B            ; write "m" to screen
        POP     BC                      ; restore BC
        PUSH    IX                      ; transfer IX to HL (part 1/2)
        POP     HL                      ; transfer IX to HL (part 2/2)
        LD      DE,$FFFC                ; load offset for next screen location
        ADD     HL,DE                   ; add offset
        LD      ($63A8),HL              ; store result
        POP     HL                      ; restore HL
        LD      DE,$FF5F                ; load DE with offset for goofy
        ADD     HL,DE                   ; add offset to draw next goofy
        DEC     B                       ; decrease B.  done drawing goofy kongs ?
        JP      NZ,$0C29                ; no, loop and do another [why not use DJNZ ???]

        LD      DE,$0307                ; load task data for text #7 "HOW HIGH CAN YOU GET?"
        CALL    $309F                   ; insert task to draw text
        LD      HL,WaitTimerMSB         ; load HL with timer to wait
        LD      (HL),$A0                ; set timer for #A0 units
        INC     HL                      ; HL := GameMode2
        INC     (HL)                    ;
        INC     (HL)                    ; increase game mode twice - starts game
        RET

; arrive here from $0701 when game mode = 9
; clears screen, update timers, draws current screen, sets background music,

        RST     $18             ; count down WaitTimerMSB and only continue when 0

; arrive here from $0776 during attract mode

        CALL    $0874                   ; clears the screen and sprites
        XOR     A                       ; A := 0
        LD      ($638C),A               ; reset onscreen timer
        LD      DE,$0501                ; load DE with task #5, parameter 1 update onscreen bonus timer and play sound & change to red if below 1000
        CALL    $309F                   ; insert task
        LD      HL,REG_PALETTE_A        ; load HL with palette bank selector
        LD      (HL),$00                ; clear palette bank selector
        INC     HL                      ; next bank
        LD      (HL),$01                ; set palette bank selector
        LD      A,($6227)               ; load A with screen number
        DEC     A                       ; decrease by 1
        JP      Z,$0CD4                 ; if zero jump to #0Cd4 - we were on girders - continue on #0CC6

        DEC     A                       ; if not decrease a again
        JP      Z,$0CDF                 ; if zero jump to #0CDf - we were on pie - continue on #0CC6

        DEC     A                       ; if not decrease a again
        JP      Z,$0CF2                 ; iF zero jump to #0CF2 - we were on elevators - continue on #0CC6

                                        ; else we are on rivets

        CALL    $0D43                   ; draws the blue vertical bars next to kong on rivets
        LD      HL,REG_PALETTE_A        ; load HL with palette bank selector
        LD      (HL),$01                ; set palette bank selector
        LD      A,$0B                   ; load A with music code For rivets
        LD      ($6089),A               ; set music
        LD      DE,$3C8B                ; load DE with start of table data for rivets

; other screens return here

        CALL    $0DA7           ; draw the screen

        LD      A,($6227)       ; load A with screen number
        CP      $04             ; screen is rivets level?
        CALL    Z,$0D00         ; yes, call sub to draw the rivets

        JP      $3FA0           ; fix rectractable ladders for pie factory and returns to #0D5F. [orig code was JP #0D5F ?]

; girders from $0CAB

        LD      DE,$3AE4        ; Load DE with start of table data for girders
        LD      A,$08           ; A := 8 = music code for girders
        LD      ($6089),A       ; set music for girders
        JP      $0CC6           ; jump back

; conveyors from $0CAF

        LD      DE,$3B5D                ; load DE with start of table data for conveyors
        LD      HL,REG_PALETTE_A        ; load HL with palette bank selector
        LD      (HL),$01                ; set palette bank selector
        INC     HL                      ;
        LD      (HL),$00                ; clear palette bank selector
        LD      A,$09                   ; load A with conveyor music
        LD      ($6089),A               ; set music for conveyors
        JP      $0CC6                   ; jump back

; elevators from $0CB3

        CALL    $0D27           ; draw elevator cables
        LD      A,$0A           ; A := #A
        LD      ($6089),A       ; set music for elevators
        LD      DE,$3BE5        ; load DE with start of table data for the elevators
        JP      $0CC6           ; jump back

; For the rivets level only  - draw the rivets

        LD      B,$08           ; for B = 1 to 8 rivets to draw
        LD      HL,$0D17        ; load HL with start of table data below

        LD      A,$B8           ; load A with #B8 = start code for rivet
        LD      C,$02           ; For C = 1 to 2
        LD      E,(HL)          ; load E with the high byte of the address
        INC     HL              ; next HL
        LD      D,(HL)          ; load D with the low byte of the adddress
        INC     HL              ; next HL

        LD      (DE),A          ; draw rivet onscreen
        DEC     A               ; next graphic
        INC     DE              ; next screen address
        DEC     C               ; Next C
        JP      NZ,$0D0D        ; loop until done

        DJNZ    $0D05           ; Next B

        RET

; start of table data for rivets used above
; these are addresses in video RAM for the rivets

        hex     CA 76           ; #76CA
        hex     CF 76           ; #76CF
        hex     D4 76           ; #76D4
        hex     D9 76           ; #76D9
        hex     2A 75           ; #752A
        hex     2F 75           ; #752F
        hex     34 75           ; #7534
        hex     39 75           ; #7539

; called from $0CF2 for elevators only
; draws the elevator cables

        LD      HL,$770D        ; load HL with screen RAM location
        CALL    $0D30           ; draw the left side elevator cable

        LD      HL,$760D        ; load HL with screen RAM location for right side cable

        LD      B,$11           ; for B = 1 to #11

        LD      (HL),$FD        ; draw the cable to screen
        INC     HL              ; next location
        DJNZ    $0D32           ; Next B

        LD      DE,$000F        ; load DE with offset [why here? should be before loop starts ?]
        ADD     HL,DE           ; add offset to location
        LD      B,$11           ; for B = 1 to #11

        LD      (HL),$FC        ; draw cable to screen
        INC     HL              ; next location
        DJNZ    $0D3D           ; Next B

        RET

; called from $0CB6 for rivets only
; draws top light blue vertical bars next to Kong

        LD      HL,$7687        ; load HL with screen location (left side)
        CALL    $0D4C           ; draw the bars
        LD      HL,$7547        ; load HL with screen location (right side)
        LD      B,$04           ; for B = 1 to 4

        LD      (HL),$FD        ; draw a bar
        INC     HL              ; next screen location
        DJNZ    $0D4E           ; Next B

        LD      DE,$001C        ; load offset
        ADD     HL,DE           ; add offset
        LD      B,$04           ; for B = 1 to 4

        LD      (HL),$FC        ; draw a bar
        INC     HL              ; next screen location
        DJNZ    $0D59           ; next B

        RET

; jump here from $0CD1 (via $3FA3)

        CALL    $0F56           ; clear and initialize RAM values, compute initial timer, draw all initial sprites
        CALL    $2441           ;
        LD      HL,WaitTimerMSB ; load HL with timer addr.
        LD      (HL),$40        ; set timer to #40
        INC     HL              ; HL := GameMode2
        INC     (HL)            ; increase game mode2
        LD      HL,$385C        ; load HL with start of kong graphic table data
        CALL    $004E           ; update kong's sprites

        LD      DE,$6900        ; set destination to girl sprite
        LD      BC,$0008        ; set counter to 8
        LDIR                    ; draw the girl on screen

        LD      A,($6227)       ; load a with screen number
        CP      $04             ; is this rivets screen?
        JR      Z,$0D8b         ; if yes, jump ahead a bit

        RRCA                    ; no, roll right twice
        RRCA                    ; is this the conveyors or the elevators ?
        RET     c               ; yes, return

                                ; else this is girders, kong needs to be moved

        LD      HL,$690B        ; load HL with start of kong sprite
        LD      C,$FC           ; set to move by -4
        RST     $38             ; move kong
        RET

; on the rivets

        LD      HL,$6908        ; load HL with kong sprite RAM
        LD      C,$44           ; set counter to #44 ?
        RST     $38             ; move kong

        LD      DE,$0004        ; load counters
        LD      BC,$0210        ; load counters
        LD      HL,$6900        ; load HL with start of sprite RAM (girl sprite first)
        CALL    $003D           ; move girl to right

        LD      BC,$02F8        ; load counters
        LD      HL,$6903        ; load HL with Y value of girl -1
        CALL    $003D           ; move girl up

        RET                    ;ret [to #1983]

; part of routine which draws the screen
; DE is preloaded with address of table data
; called from many places

        LD      A,(DE)          ; load a with DE - points to start of table data
        LD      ($63B3),A       ; save for later use
        CP      $AA             ; is this the end of the data?
        RET     Z               ; yes, return

; else draw screen stuff

        INC     DE              ; next table entry
        LD      A,(DE)          ; load A with table data
        LD      H,A             ; copy to H
        LD      B,H             ; copy to B
        INC     DE              ; next table entry
        LD      A,(DE)          ; load A with table data
        LD      L,A             ; copy to L
        LD      C,L             ; copy to C
        PUSH    DE              ; save DE
        CALL    $2FF0           ; convert HL into VRAM address
        POP     DE              ; restore DE
        LD      ($63AB),HL      ; store the VRAM address into this location for later use.  starting point of whatever we are drawing
        LD      A,B             ; A := B = original data item
        AND     $07             ; mask bits, now between 0 and 7
        LD      ($63B4),A       ; store into ???
        LD      A,C             ; A := C = 2nd data item
        AND     $07             ; mask bits, now between 0 and 7
        LD      ($63AF),A       ; store into ???
        INC     DE              ; next table entry
        LD      A,(DE)          ; load A with table data
        LD      H,A             ; copy to H
        SUB     B               ; subract the original data.  less than zero?
        JP      NC,$0DD3        ; no, skip next step

        NEG                     ; Negate A (A := #FF - A)

        LD      ($63B1),A       ; store into ???
        INC     DE              ; next table entry
        LD      A,(DE)          ; load A with table data
        LD      L,A             ; copy to L
        SUB     C               ; subtract the 2nd data item
        LD      ($63B2),A       ; store into ???
        LD      A,(DE)          ; load A with same table data
        AND     $07             ; mask bits, now between 0 and 7
        LD      ($63B0),A       ; store into ???
        PUSH    DE              ; save DE
        CALL    $2FF0           ; convert HL into VRAM address
        POP     DE              ; restore DE
        LD      ($63AD),HL      ; store into ???
        LD      A,($63B3)       ; load A with first data item
        CP      $02             ; < 2 ? are we drawing a ladder or a broken ladder?
        JP      P,$0E4F         ; no, skip ahead [why P, instead of NC ?]

; else we are drawing a ladder

        LD      A,($63B2)       ; load A with ???
        SUB     $10             ; subtract #10
        LD      B,A             ; copy answer to B
        LD      A,($63AF)       ; load A with ???
        ADD     A,B             ; add B
        LD      ($63B2),A       ; store into ???
        LD      A,($63AF)       ; load A with ??? computed above
        ADD     A,$F0           ; add #F0
        LD      HL,($63AB)      ; load HL with VRAM address to begin drawing
        LD      (HL),A          ; draw element to screen = girder above top of ladder ?
        INC     L               ; next location
        SUB     $30             ; subtract #30.  now the element to draw is a ladder
        LD      (HL),A          ; draw element to screen = top of ladder
        LD      A,($63B3)       ; load A with original data item
        CP      $01             ; == 1 ? (is this a broken ladder?)
        JP      NZ,$0E19        ; no, skip next 2 steps

        XOR     A               ; A := 0
        LD      ($63B2),A       ; store into ???

        LD      A,($63B2)       ; load A with ???
        SUB     $08             ; subtract 8
        LD      ($63B2),A       ; store.  are we done?
        JP      C,$0E2A         ; yes, skip ahead

        INC     L               ; next HL
        LD      (HL),$C0        ; draw ladder to screen
        JP      $0E19           ; loop again

        LD      A,($63B0)       ; load A with ???
        ADD     A,$D0           ; add #D0
        LD      HL,($63AD)      ;
        LD      (HL),A
        LD      A,($63B3)       ; load A with original data item
        CP      $01             ; == 1 ?  (is this a broken ladder ?)
        JP      NZ,$0E3F        ; no, skip next 3 steps

; this is a broken ladder.  draw bottom part of ladder

        DEC     L               ; decrease HL
        LD      (HL),$C0        ; set HL to #C0 - draws bottom part of broken ladder to screen
        INC     L               ; increase HL

        LD      A,($63B0)       ; load A with ???
        CP      $00             ; == 0 ?
        JP      Z,$0E4B         ; yes, skip next 3 steps

        ADD     A,$E0           ; add #E0
        INC     L               ; next HL
        LD      (HL),A          ; store into ???

        INC     DE              ; next table entry
        JP      $0DA7           ; loop again

; arrive from $0DF0

        LD      A,($63B3)       ; load A with original data item [why do this again ?  it was loaded just before coming here]
        CP      $02             ; == 2 ?
        JP      NZ,$0EE8        ; no, skip ahead

; else data item type 2 = girder ???

        LD      A,($63AF)       ; load A with original data item #2, masked to be between 0 and 7
        ADD     A,$F0           ; add #F0
        LD      ($63B5),A       ; store into ???
        LD      HL,($63AB)      ; load HL with screen address to being drawing the item

        LD      A,($63B5)       ; load A with ???
        LD      (HL),A          ; draw element to screen
        INC     HL              ; next screen location
        LD      A,L             ; A := L
        AND     $1F             ; mask bits, now between 0 and #1F.  at zero ?
        JP      Z,$0E78         ; yes, skip ahead

        LD      A,($63B5)       ; load A with ???
        CP      $F0             ; == #F0 ?
        JP      Z,$0E78         ; yes, skip next 2 steps

        SUB     $10             ; subtract #10
        LD      (HL),A          ; store

        LD      BC,$001F        ; load BC with offset
        ADD     HL,BC           ; add offset to HL
        LD      A,($63B1)       ; load A with ???
        SUB     $08             ; subtract 8.  done?
        JP      C,$0ECF         ; yes, skip ahead for next

        LD      ($63B1),A       ; store A into ???
        LD      A,($63B2)       ; load A with ???
        CP      $00             ; == 0 ? [why written this way?]
        JP      Z,$0E62         ; yes, jump back and draw another [of same?]

        LD      A,($63B5)
        LD      (HL),A          ; draw element to screen
        INC     HL              ; next screen location
        LD      A,L             ; A := L
        AND     $1F             ; mask bits, now between 0 and #1F.  at zero?
        JP      Z,$0EA0         ; yes, skip next 3 steps

        LD      A,($63B5)       ; load A with ???
        SUB     $10             ; subtract #10
        LD      (HL),A          ; store to screen.  draws bottom half of a girder

        LD      BC,$001F        ; load BC with offset
        ADD     HL,BC           ; add offset for next screen element
        LD      A,($63B1)       ; load A with ???
        SUB     $08             ; subtract 8.  done?
        JP      C,$0ECF         ; yes, skip ahead for next

        LD      ($63B1),A       ; store A into ???
        LD      A,($63B2)       ; load A with ???
        BIT     7,A             ; test bit 7.  is it zero?
        JP      NZ,$0ED3        ; no, skip ahead

        LD      A,($63B5)       ; load A with ???
        INC     A               ; increase
        LD      ($63B5),A       ; store result
        CP      $F8             ; == #F8 ?
        JP      NZ,$0EC9        ; no, skip next 3 steps

        INC     HL              ; next screen location
        LD      A,$F0           ; A := #F0
        LD      ($63B5),A       ; store into ???

        LD      A,L             ; A := L
        AND     $1F             ; mask bits.  now between 0 and #1F.  at zero?
        JP      NZ,$0E62        ; no, jump back

        INC     DE              ; next table entry
        JP      $0DA7           ; loop back for more

        LD      A,($63B5)       ; load A with ???
        DEC     A               ; decrease
        LD      ($63B5),A       ; store result
        CP      $F0             ; compare to #F0.  is the sign positive?
        JP      P,$0EE5         ; yes, skip next 3 steps [why?  #0EE5 is a jump - it should jump directly instead]

        DEC     HL              ;
        LD      A,$F7           ; A := #F7
        LD      ($63B5),A       ; store into ???

        JP      $0E62           ; jump back

; arrive from $0E54

        LD      A,($63B3)       ; load A with original data item [why load it again ? A already has #63B3]
        CP      $03             ; == 3?
        JP      NZ,$0F1B        ; no, skip ahead

; we are drawing a conveyor

        LD      HL,($63AB)      ; load HL with VRAM screen address to begin drawing
        LD      A,$B3           ; A := #B3 = code graphic for conveyor
        LD      (HL),A          ; draw on screen
        LD      BC,$0020        ; load BC with offset
        ADD     HL,BC           ; add offset to HL
        LD      A,($63B1)       ; load A with ???
        SUB     $10             ; subtract #10.  done ?

        JP      C,$0F14         ; yes, skip ahead

        LD      ($63B1),A       ;
        LD      A,$B1           ; A := #B1
        LD      (HL),A          ; store into ???
        LD      BC,$0020        ; load BC with offset
        ADD     HL,BC           ; add offset to HL
        LD      A,($63B1)       ; load A with ???
        SUB     $08             ; subtract 8
        JP      $0EFF           ; loop again

        LD      A,$B2           ; A := #B2
        LD      (HL),A          ; store (onscreen???)
        INC     DE              ; next table entry
        JP      $0DA7           ; loop back for more

; arrive from $0EED

        LD      A,($63B3)       ; load A with original data item [why load it again ? A already has #63B3]
        CP      $07             ; <= 7 ?
        JP      P,$0ECF         ; no, skip back and loop for next data item

        CP      $04             ; first data item == 4 ?
        JP      Z,$0F4C         ; yes, skip ahead to handle

        CP      $05             ; first data item == 5 ?
        JP      Z,$0F51         ; yes, skip ahead to handle

; redraws screen when rivets has been completed

        LD      A,$FE           ; A := #FE

        LD      ($63B5),A       ; store into ???
        LD      HL,($63AB)      ; load HL with ???

        LD      A,($63B5)       ; load A with ???
        LD      (HL),A          ; store into ???
        LD      BC,$0020        ; set offset to #20
        ADD     HL,BC           ; add offset for next
        LD      A,($63B1)       ; load A with ???
        SUB     $08             ; subtract 8
        LD      ($63B1),A       ; store result.  done ?
        JP      NC,$0F35        ; no, loop again

        INC     DE              ; else increase DE
        JP      $0DA7           ; jump back

        LD      A,$E0           ; A := #E0
        JP      $0F2F           ; jump back

        LD      A,$B0           ; A := #B0
        JP      $0F2F           ; jump back

; called from $0D5F
; clears memories from $6200 - 6227 and #6280 to 6B00
; [why are $6280 - $6280+40 cleared?  they are set immediately after]
; computes initial timer
; initializes all sprites

        LD      B,$27           ; for B = 1 to #27
        LD      HL,$6200        ; load HL with start of address
        XOR     A               ; A := #00

        LD      (HL),A          ; clear memory
        INC     L               ; next
        DJNZ    $0F5C           ; next B

        LD      C,$11           ; For C = 1 to 11
        LD      D,$80           ; load D with 80, used to reset B in inner loop
        LD      HL,$6280        ; start of memory to clear
        LD      B,D             ; For B = 1 to #80

        LD      (HL),A          ; clear (HL)
        INC     HL              ; next memory
        DJNZ    $0F68           ; Next B

        DEC     C               ; Next C
        JR      NZ,$0F67        ; loop until done

        LD      HL,$3D9C        ; source addr. = #3D9C - table data
        LD      DE,$6280        ; Destination = #6280
        LD      BC,$0040        ; counter = #40 Bytes
        LDIR                    ; copy


; values are copied into $6280 through #6280 + #40
;     3D9C: 00 00 23 68
;     3DA0: 01 11 00 00 00 10 DB 68 01 40 00 00 08 01 01 01
;     3DB0: 01 01 01 01 01 01 00 00 00 00 00 00 80 01 C0 FF
;     3DC0: 01 FF FF 34 C3 39 00 67 80 69 1A 01 00 00 00 00
;     3DD0: 00 00 00 00 04 00 10 00 00 00 00 00
;

; set up initial timer
; timer is either 5000, 6000, 7000 or 8000 depending on level

        LD      A,($6229)       ; load level number
        LD      B,A             ; copy to B
        AND     a               ; clear carry flag
        RLA                     ; rotate A left (double =2x)
        AND     a               ; clear carry flag
        RLA                     ; rotate A left (double again =4x)
        AND     a               ; clear carry flag
        RLA                     ; rotate A left (double again = 8x)
        ADD     A,b             ; add B into A  (add once = 9x)
        ADD     A,b             ; add B  into A  (add again = 10x)
        ADD     A,$28           ; add #28 (40 decimal) to A
        CP      $51             ; < #51 ?
        JR      c,$0F8E         ; yes, skip next step

        LD      A,$50           ; otherwise load A with #50 (80 decimal)

        LD      HL,$62B0        ; load HL with start of timers
        LD      B,$03           ; For B = 1 to 3

        LD      (HL),A          ; store A into timer memory
        INC     l               ; next memory
        DJNZ    $0F93           ; Next B

        ADD     A,A             ; add A with A (double a).  A is now #64, #78, #8C, or #A0
        LD      B,A             ; copy to B
        LD      A,$DC           ; A := #DC (220 decimal)
        SUB     B               ; subtract B.  answers are #78, #64, #50, or #3C
        CP      $28             ; is this less than #28 (40 decimal) ?  (will never get this ... ???)
        JR      NC,$0FA2        ; no, skip next step

        LD      A,$28           ; else load a with #28 (40). minimum value (never get this ... ?????)

        LD      (HL),A          ; store A into address of HL=#62B3 which controls timers
        INC     L               ; HL := #62B4
        LD      (HL),A          ; store A into the timer control
        LD      HL,$6209        ; load HL with #6209
        LD      (HL),$04        ; store 4 into #6209
        INC     L               ; HL := #620A
        LD      (HL),$08        ; store 8 into #620A
        LD      A,($6227)       ; load A with screen number
        LD      C,A             ; copy to C, used at #0FCB
        BIT     2,A             ; is this the rivets ?
        JR      NZ,$0FCB        ; yes, skip ahead [would be better to jump to #1131, or JR to #0FCC]

; draw 3 black sprites above the top kongs ladder
; effect to erase the 2 girders at the top of kong's ladder

        LD      HL,$6A00        ; else load HL sprite RAM - used for blank space sprite
        LD      A,$4f           ; A := #4F = X position of this sprite
        LD      B,$03           ; For B = 1 to 3

        LD      (HL),A          ; set the sprite X position
        INC     L               ; next address = sprite type
        LD      (HL),$3A        ; set sprite type as blank square
        INC     L               ; next address = sprite color
        LD      (HL),$0F        ; set color to black
        INC     L               ; next address = sprite Y position
        LD      (HL),$18        ; set sprite Y position to #18
        INC     L               ; next memory
        ADD     A,$10           ; A := A + #10 to adjust for next X position
        DJNZ    $0FBC           ; Next B

        LD      A,C             ; load A with screen number
        RST     $28             ; jump depending on the screen

; jump table data

        hex     00 00           ; unused
        hex     D7 0F           ; #0FD7 for girders
        hex     1F 10           ; #101F for conveyors
        hex     87 10           ; #1087 for elevators
        hex     31 11           ; #1131 for rivets

; arrive here when playing girders

        LD      HL,$3DDC        ; source - has the information about the barrel pile at #3DDC
        LD      DE,$69A8        ; destination = sprites
        LD      BC,$0010        ; counter is #10
        LDIR                    ; draws the barrels pile next to kong

        LD      HL,$3DEC        ; set up a copy job from table in #3DEC
        LD      DE,$6407        ; destination in memory is #6407
        LD      C,$1C           ; $1C is a secondary counter
        LD      B,$05           ; $05 is a secondary counter
        CALL    $122A           ; copy

        LD      HL,$3DF4        ; load HL with table data start for initial fire locations
        CALL    $11FA           ; ???

        LD      HL,$3E00        ; source table at #3E00 = oil can
        LD      DE,$69FC        ; destination sprite at #69FC
        LD      BC,$0004        ; 4 bytes
        LDIR                    ; draw to screen

        LD      HL,$3E0C        ; load HL with table data for hammers on girders
        CALL    $11A6           ; ???

        LD      HL,$101B        ; set up copy job from table in #101B
        LD      DE,$6707        ; set destination ?
        LD      BC,$081C        ; set counters ?
        CALL    $122A           ; copy

        LD      DE,$6807        ; set destination ?
        LD      B,$02           ; set counter to 2
        CALL    $122A           ; copy
        RET

; data used in sub at $1006

        hex     00
        hex     00
        hex     02
        hex     02

; arrive here when conveyors starts
; draws parts of the screen

        LD      HL,$3DEC        ; set up a copy job from table in #3DEC
        LD      DE,$6407        ; desitnation in memory is #6407
        LD      BC,$051C        ; counters are #05 and #1C
        CALL    $122A           ; copy

        CALL    $1186

        LD      HL,$3E18        ; set up copy job from table in #3E18
        LD      DE,$65A7        ; destination is #65A7
        LD      BC,$060C        ; counters are #05 and #0C
        CALL    $122A           ; copy

        LD      IX,$65A0        ; load IX with start of pies
        LD      HL,$69B8        ; load HL with sprites for pies
        LD      DE,$0010        ; DE := #10
        LD      B,$06           ; B := 6
        CALL    $11D3

        LD      HL,$3DFA        ; load HL with start of table data
        CALL    $11FA           ; set fireball sprite

        LD      HL,$3E04        ; set up copy job from table in #3E04 = oil can sprite
        LD      DE,$69FC        ; destination is #69FC = sprite
        LD      BC,$0004        ; four bytes to copy
        LDIR                    ; draw oil can

        LD      HL,$3E1C        ; load HL with start of table data
        LD      DE,$6944        ; load DE with sprite start for moving ladders
        LD      BC,$0008        ; set byte counter to 8
        LDIR                    ; draw moving ladders

        LD      HL,$3E24        ; set source table data
        LD      DE,$69E4        ; set destination RAM sprites
        LD      BC,$0018        ; set counter
        LDIR                    ; draw pulleys

        LD      HL,$3E10        ; load HL with table data for hammers on conveyors
        CALL    $11A6           ; ???

        LD      HL,$3E3C        ; load HL with table data for bonus items on conveyors
        LD      DE,$6A0C        ; load DE with sprite destination
        LD      BC,$000C        ; 3 items x 4 bytes = 12 bytes (#0C)
        LDIR                    ; draw bonus item sprites

        LD      A,$01           ; A := 1
        LD      ($62B9),A       ; store into fire release
        RET

; arrive here when elevators starts

        LD      HL,$3DEC        ; load HL with start of table data
        LD      DE,$6407        ; set destination ???
        LD      BC,$051C        ; set counters
        CALL    $122A           ; copy ???

        CALL    $1186

        LD      HL,$6600        ; load HL with start of elevator sprites ???
        LD      DE,$0010        ; load DE with offset to add
        LD      A,$01           ; A := 1
        LD      B,$06           ; for B = 1 to 6

        LD      (HL),A          ; write value into memory
        ADD     HL,DE           ; add offset for next
        DJNZ    $10A0           ; next B

        LD      C,$02           ; For C = 1 to 2
        LD      A,$08           ; A := 8
        LD      B,$03           ; for B = 1 to 3
        LD      HL,$660D        ; load HL with ???

        LD      (HL),A          ; write value into memory
        ADD     HL,DE           ; add offset for next
        DJNZ    $10AD           ; next B

        LD      A,$08           ; A := 8 [why?  A is already 8]
        DEC     C               ; next C
        JP      NZ,$10A8        ; loop until done

; used to draw elevator platforms???

; $6600 - 665F  = the 6 elevator values.  6610, 6620, 6630, 6640 ,6650 are starting values
;       + 3 is the X position, + 5 is the Y position

        LD      HL,$3E64        ; start of table data
        LD      DE,$6603        ; Destination sprite ? X positions ?
        LD      BC,$060E        ; Counter = #06, offset = #0E
        CALL    $11EC           ; set items from data table

        LD      HL,$3E60        ; start of table data
        LD      DE,$6607        ; Destination sprite ?
        LD      BC,$060C        ; B = 6 is loop variable, C = offset ?
        CALL    $122A           ;

        LD      IX,$6600        ; load IX with ???
        LD      HL,$6958        ; load HL with elevator sprites start
        LD      B,$06           ; B := 6
        LD      DE,$0010        ; load offset with #10
        CALL    $11D3           ; ???

        LD      HL,$3E48        ; source is data table for bonus items on elevators
        LD      DE,$6A0C        ; destination is RAM area for bonus items
        LD      BC,$000C        ; counter set for #0C bytes
        LDIR                    ; copy

; set up the 2 fireballs

        LD      IX,$6400        ; load IX with start of fire #1
        LD      (IX+$00),$01    ; set fire active
        LD      (IX+$03),$58    ; set fire X position
        LD      (IX+$0E),$58    ; set fire X position #2
        LD      (IX+$05),$80    ; set fire Y position
        LD      (IX+$0F),$80    ; set fire Y position #2

; set up 2nd fireball

        LD      (IX+$20),$01    ; set fire active
        LD      (IX+$23),$EB    ; set fire X position
        LD      (IX+$2E),$EB    ; set fire X position
        LD      (IX+$25),$60    ; set fire Y position
        LD      (IX+$2F),$60    ; set fire Y position

        LD      DE,$6970        ; destination #6970 (sprites used at top and bottom of elevators)
        LD      HL,$1121        ; source data at table below
        LD      BC,$0010        ; byte counter at #10
        LDIR                    ; copy
        RET

; data used above for top and bottom of elevator shafts

        hex     37 45 0F 60     ; X = #37, color = #45, sprite = #F, Y = #60
        hex     37 45 8F F7
        hex     77 45 0F 60
        hex     77 45 8F F7

; arrive here when rivets starts from #0FCC

        LD      HL,$3DF0        ; load HL with start of table data
        LD      DE,$6407        ; load DE with destination ?
        LD      BC,$051C        ; set counters

        CALL    $122A           ; copy fire location data to screen?

        LD      HL,$3E14        ; load HL with start of table data for hammer locations
        CALL    $11A6           ; draw the hammers

        LD      HL,$3E54        ; load HL with start of bonus items for rivets
        LD      DE,$6A0C        ; set destination sprite address
        LD      BC,$000C        ; set counter to #C bytes to copy
        LDIR                    ; draw purse, umbrella, hat to screen

        LD      HL,$1182        ; load HL with start of data table
        LD      DE,$64A3        ; load DE with destination ?
        LD      BC,$021E        ; set counters
        CALL    $11EC           ; copy

; draws black squares next to kong???

        LD      HL,$117E        ; load HL with start of data table
        LD      DE,$64A7        ; set destination sprites
        LD      BC,$021C        ; set counters B := 2, C := #1C
        CALL    $122A           ; copy

        LD      IX,$64A0        ; load IX with address of black square sprite start
        LD      (IX+$00),$01    ; store 1 into #64A0 = turn on first sprite
        LD      (IX+$20),$01    ; store 1 into #64C0 = turn on second sprite

        LD      HL,$6950        ; load HL with ???
        LD      B,$02           ; set counter to 2
        LD      DE,$0020        ; set offset to #20
        CALL    $11D3           ; draw items ???

        RET

; data used above for black space next to kong

        hex     3F 0C 08 08     ; sprite code #3F (invisible square), color = #0C (black), size = 8x8 ???
        hex     73 50 8D 50     ; 1st is at #73,#50 and the 2nd is at #8D,#50

; called from $102B and $1093

        LD      HL,$11A2        ; load HL with start of data table
        LD      DE,$6507        ; load DE with destination
        LD      BC,$0A0C        ; set counters
        CALL    $122A           ; copy

        LD      IX,$6500        ; load IX with ???
        LD      HL,$6980        ; load HL with sprite start (???)
        LD      B,$0A           ; B := #A
        LD      DE,$0010        ; load DE with offset
        CALL    $11D3           ; copy

        RET

; data table used above

        hex     3B 00 02 02

; called from 3 locations with HL preloaded with address of locations to draw to

        LD      DE,$6683        ; load DE with sprite destination address ???
        LD      BC,$020E        ; B := 2 for the 2 hammers.  C := #E for ???
        CALL    $11EC           ;

        LD      HL,$3E08        ; set source
        LD      DE,$6687        ; set destination
        LD      BC,$020C        ; set counters
        CALL    $122A           ; copy table data from #3E08 into #6687 with counters #02 and #0C

        LD      IX,$6680        ; load IX with start of hammer array
        LD      (IX+$00),$01    ; set hammer 1 active
        LD      (IX+$10),$01    ; set hammer 2 active
        LD      HL,$6A18        ; set destination for hammer sprites ?
        LD      B,$02           ; set counter to 2
        LD      DE,$0010        ; set offset to #10
        CALL    $11D3           ; draw hammers

        RET

; subroutine uses HL, DE, IX
; B used for loop counter (how many times to loop before returning)
; DE used as an offset for the next set of items to copy
; used to draw hammers initially on each level that has them ?
;

        LD      A,(IX+$03)      ; Load A with item's X position
        LD      (HL),A          ; store into HL = sprite X position
        INC     L               ; next HL
        LD      A,(IX+$07)      ; load A with item's sprite value
        LD      (HL),A          ; store into sprite value
        INC     L               ; next HL
        LD      A,(IX+$08)      ; load A with item color
        LD      (HL),A          ; store into sprite color
        INC     L               ; next HL
        LD      A,(IX+$05)      ; load A with Y position
        LD      (HL),A          ; store into sprite Y position
        INC     L               ; next HL
        ADD     IX,DE           ; add offset into IX for next set of data
        DJNZ    $11D3           ; loop until B == 0

        RET

; draw umbrella, etc to screen on rivets level?
; also used on elevators, called from #10C0

        LD      A,(HL)          ; load A with first table data
        LD      (DE),A          ; store into (DE) = sprite ?
        INC     HL              ; next table data
        INC     E
        INC     E               ; next sprite
        LD      A,(HL)          ; load next data
        LD      (DE),A          ; store
        INC     HL              ; next data
        LD      A,E             ; load A with E
        ADD     A,C             ; add C (offset for next sprite);  EG #0E
        LD      E,A             ; store into E
        DJNZ    $11EC           ; loop until done

        RET

;
; called from $104C for conveyors
; called from $0FF2 for girders
; draw stuff in conveyors and girders
; HL is preloaded with $3DFA for conveyors and #3DF4 for girders = table data for intial fire location
; 3DF4:  27 70 01 E0 00 00      ; initial data for fires on girders ?
; 3DFA:  7F 40 01 78 02 00      ; initial data for conveyors to release a fire ?
;

        LD      IX,$66A0        ; load IX with sprite memory array for fire above the barrel
        LD      DE,$6A28        ; load DE with hardware sprite memory for same fire
        LD      (IX+$00),$01    ; enable the sprite
        LD      A,(HL)          ; load A with table data
        LD      (IX+$03),A      ; store into sprite X position
        LD      (DE),A          ; store into sprite X position
        INC     E               ; next DE
        INC     HL              ; next HL
        LD      A,(HL)          ; load A with table data
        LD      (IX+$07),A      ; store into sprite graphic
        LD      (DE),A          ; store into sprite graphic
        INC     E               ; next DE
        INC     HL              ; next HL
        LD      A,(HL)          ; load A with table data
        LD      (IX+$08),A      ; store into sprite color
        LD      (DE),A          ; store into sprite color
        INC     E               ; next DE
        INC     HL              ; next HL
        LD      A,(HL)          ; load A with table data
        LD      (IX+$05),A      ; store into sprite Y position
        LD      (DE),A          ; store into sprite Y position
        INC     HL              ; next HL
        LD      A,(HL)          ; load A with table data
        LD      (IX+$09),A      ; store into size (width?) ???
        INC     HL              ; next HL
        LD      A,(HL)          ; load A with table data
        LD      (IX+$0A),A      ; store into size? (height?) ??
        RET


; Subroutine from $10CC
; Copies Data from Table in HL into the Destination at DE in chunks of 4
; B is used for the second loop variable
; C is used to specify the difference between the tables, assumed to be 4 or 5 or 0 ?
; used for example to place the hammers ???

        PUSH    HL              ; Save HL
        PUSH    BC              ; Save BC
        LD      B,$04           ; For B = 1 to 4

        LD      A,(HL)          ; load A with the Contents of HL table data
        LD      (DE),A          ; store data into address DE
        INC     HL              ; next table data
        INC     E               ; next destination
        DJNZ    $122E           ; Next B

        POP     BC              ; Restore BC - For B = 1 to Initial B value
        POP     HL              ; Restore HL
        LD      A,E             ; A := E
        ADD     A,C             ; add C
        LD      E,A             ; store result into E
        DJNZ    $122A           ; Loop again if not zero

        RET

; set initial mario sprite position and draw remaining lives and level

        RST     $18             ; count down WaitTimerMSB and only continue when 0
        LD      A,($6227)       ; load a with screen number
        CP      $03             ; is this the elevators?
        LD      BC,$e016        ; B := #E0, C := #16.  used for X,Y coordinates
        JP      Z,$124B         ; if elevators skip next step

        LD      BC,$F03F        ; else load alternate coordinates for elevators

        LD      IX,$6200        ; set IX to mario sprite array
        LD      HL,$694C        ; load HL with address for mario sprite X value
        LD      (IX+$00),$01    ; turn on sprite
        LD      (IX+$03),C      ; store X position
        LD      (HL),C          ; store X position
        INC     L               ; next
        LD      (IX+$07),$80    ; store sprite graphic
        LD      (HL),$80        ; store sprite graphic
        INC     L               ; next
        LD      (IX+$08),$02    ; store sprite color
        LD      (HL),$02        ; store sprite color
        INC     L               ; next
        LD      (IX+$05),B      ; store Y position
        LD      (HL),B          ; store Y position
        LD      (IX+$0F),$01    ; turn this on (???)
        LD      HL,GameMode2        ; load HL with game mode2 address
        INC     (HL)            ; increase game mode2 = start game
        LD      DE,$0601        ; set task #6, parameter 1 to draw lives-1 and level
        CALL    $309F           ; insert task
        RET

; jump here from $0701 when GameMode2 == #D
; mario died ?

        CALL    $1DBD                   ; check for bonus items and jumping scores, rivets
        LD      A,($639D)               ; load A with this normally 0.  1 while mario dying, 2 when dead
        RST     $28                     ; jump based on A

        hex     8B 12                   ; #128B  0 normal
        hex     AC 12                   ; #12AC  1 mario dying
        hex     DE 12                   ; #12DE  2 mario dead
        hex     00 00                   ; unused ?

        RST     $18                     ; count down WaitTimerMSB and only continue when 0
        LD      HL,$694D                ; load HL with mario sprite value
        LD      A,$F0                   ; A := #F0
        RL      (HL)                    ; rotate left (HL)
        RRA                             ; rotate right that carry bit into A
        LD      (HL),A                  ; store result into mario sprite
        LD      HL,$639D                ; load HL with mario death indicator
        INC     (HL)                    ; increase.  mario is now dying
        LD      A,$0D                   ; A := #D (13 decimal)
        LD      ($639E),A               ; store into counter for number of times to rotate mario (?)
        LD      A,$08                   ; load A with 8 frames of delay
        LD      (WaitTimerMSB),A        ; store into timer for sound delay
        CALL    $30BD                   ; clear sprites ?
        LD      A,$03                   ; load A with duration of sound
        LD      ($6088),A               ; play death sound
        RET

; arrive here when mario dies
; animates mario

        RST     $18                     ; count down WaitTimerMSB and only continue when 0
        LD      A,$08                   ; load A with 8 frames of delay
        LD      (WaitTimerMSB),A        ; store into timer for sound delays
        LD      HL,$639E                ; load counter
        DEC     (HL)                    ; decrease.  are we done ?
        JP      Z,$12CB                 ; yes, skip ahead

        LD      HL,$694D                ; load HL with mario sprite value
        LD      A,(HL)                  ; get the value
        RRA                             ; roll right = div 2
        LD      A,$02                   ; load A with 2
        RRA                             ; roll right , A now has 1
        LD      B,A                     ; copy to B
        XOR     (HL)                    ; toggle HL rightmost bit
        LD      (HL),A                  ; save new sprite value
        INC     L                       ; next HL
        LD      A,B                     ; load A with B
        AND     $80                     ; apply mask
        XOR     (HL)                    ; toggle HL
        LD      (HL),A                  ; save new value
        RET

; mario done rotating after death

        LD      HL,$694D                ; load HL with mario sprite value
        LD      A,$F4                   ; load A with #F4
        RL      (HL)                    ; rotate left HL (goes from F8 to F0)
        RRA                             ; roll right A.  A becomes FA
        LD      (HL),A                  ; store into sprite value (mario dead)
        LD      HL,$639D                ; load HL with death indicator
        INC     (HL)                    ; increase.  mario now dead
        LD      A,$80                   ; load A with delay of 80
        LD      (WaitTimerMSB),A        ; store into sound delay counter
        RET

; mario is completely dead

        RST     $18             ; count down WaitTimerMSB and only continue when 0
        CALL    $30DB           ; clear mario and elevator sprites from screen
        LD      HL,GameMode2    ; set HL to game mode2
        LD      A,(PlayerTurnB) ; load A with current player
        AND     A               ; is this player 1 ?
        JP      Z,$12ED         ; yes, skip next step

        INC     (HL)            ; increase game mode

        INC     (HL)            ; increase game mode
        DEC     HL              ; load HL with WaitTimerMSB
        LD      (HL),$01        ; store 1 into timer
        RET

; jump here from $0701
; player 1 died
; clear sounds, decrease life, check for and handle game over

        CALL    $011C           ; clear all sounds
        XOR     A               ; A := 0
        LD      ($622C),A       ; store into game start flag
        LD      HL,$6228        ; load HL with address for number of lives remaining
        DEC     (HL)            ; one less life
        LD      A,(HL)          ; load A with number of lives left
        LD      DE,P1NumLives   ; set destination address
        LD      BC,$0008        ; set counter
        LDIR                    ; copy (#6228) to (#6230) into (P1NumLives) to (P2NumLives).  copies data from player area to storage area for player 1
        AND     A               ; number of lives == 0 ?
        JP      NZ,$1334        ; no, skip ahead

; game over for this player [?]

        LD      A,$01                   ; A := 1
        LD      HL,$60B2                ; load HL with player 1 score address
        CALL    $13CA                   ; check for high score entry ???
        LD      HL,$76D4                ; load HL with screen VRAM address ???
        LD      A,(TwoPlayerGame)       ; load A with number of players
        AND     A                       ; 1 player game?
        JR      Z,$1322                 ; yes, skip next 3 steps

        LD      DE,$0302                ; load task data for text #2 "PLAYER <I>"
        CALL    $309F                   ; insert task to draw text
        DEC     HL                      ; HL := #76D3

        CALL    $1826                   ; clear an area of the screen
        LD      DE,$0300                ; load task data for text #0 "GAME OVER"
        CALL    $309F                   ; insert task to draw text
        LD      HL,WaitTimerMSB         ; load HL with timer
        LD      (HL),$C0                ; set timer to #C0
        INC     HL                      ; HL := GameMode2
        LD      (HL),$10                ; set game mode2 to #10
        RET

        LD      C,$08                   ; C := 8
        LD      A,(TwoPlayerGame)       ; load A with number of players
        AND     A                       ; 1 player game?
        JP      Z,$133F                 ; yes, skip next step

        LD      C,$17                   ; C := #17

        LD      A,C                     ; A := C
        LD      (GameMode2),A           ; store into game mode2
        RET

; arrive from $0701 when GameMode2 == #F
; clear sounds, clear game start flag, draw game over if needed, set game mode2 accordingly

        CALL    $011C           ; clear all sounds
        XOR     A               ; A := 0
        LD      ($622C),A       ; store into game start flag
        LD      HL,$6228        ; load HL with number of lives remaining
        DEC     (HL)            ; decrease
        LD      A,(HL)          ; load A with the number of lives remaining
        LD      DE,P2NumLives   ; load DE with destination address
        LD      BC,$0008        ; set counter to 8
        LDIR                    ; copy
        AND     A               ; any lives left?
        JP      NZ,$137F        ; yes, skip ahead

; game over

        LD      A,$03           ; A := 3
        LD      HL,$60B5        ; load HL with player 2 score address
        CALL    $13CA           ; check for high score entry ???
        LD      DE,$0303        ; load task data for text #3 "PLAYER <II>"
        CALL    $309F           ; insert task to draw text
        LD      DE,$0300        ; load task data for text #0 "GAME OVER"
        CALL    $309F           ; insert task to draw text
        LD      HL,$76D3        ; load HL with screen address ???
        CALL    $1826           ; clear an area of the screen
        LD      HL,WaitTimerMSB ; load HL with timer
        LD      (HL),$C0        ; set timer to #C0
        INC     HL              ; HL := GameMode2
        LD      (HL),$11        ; set game mode2 to #11
        RET

        LD      C,$17           ; C := #17
        LD      A,(P1NumLives)  ; load A with number of lives left for player 1
        AND     A               ; player 1 has lives remaining?
        JP      NZ,$138A        ; yes, skip next step

        LD      C,$08           ; C := 8

        LD      A,C             ; A := C
        LD      (GameMode2),A   ; store A into game mode2
        RET

; arrive from $0701 when GameMode2 == #10
; when 2 player game has ended

        RST     $18             ; count down timer and only continue here if zero, else RET
        LD      C,$17           ; C := #17
        LD      A,(P2NumLives)  ; load A with number of lives for player 2

        INC     (HL)            ; increase timer ??? [EG HL = WaitTimerMSB]
        AND     A               ; player has lives remaining ?
        JP      NZ,$139C        ; yes, skip next step

        LD      C,$14           ; else C := #14

        LD      A,C             ; A := C
        LD      (GameMode2),A   ; store into game mode2
        RET


; arrive from $0701 when GameMode2 == #11

        RST     $18             ; count down timer and only continue here if zero, else RET
        LD      C,$17           ; C := #17
        LD      A,(P1NumLives)  ; load A with number of lives remaining for player1
        JP      $1395           ; jump back, rest of this sub is above


; arrive from $0701 when GameMode2 == 12
; flip screen if needed, reset game mode2 to zero, set player 2

        LD      A,(UprightCab)          ; load A with upright/cocktail
        LD      (REG_FLIPSCREEN),A      ; store into hardware screen flip
        XOR     A                       ; A := 0
        LD      (GameMode2),A           ; set game mode2 to 0
        LD      HL,$0101                ; HL := #101
        LD      (PlayerTurnA),HL        ; store 1 into PlayerTurnA (set player2) and PlayerTurnB (set player2)
        RET

; arrive from $0701 when GameMode2 == 13
; set player 1, reset game mode2 to zero, set screen flip to not flipped

        XOR     A                       ; A := 0
        LD      (PlayerTurnA),A         ; set for player 1
        LD      (PlayerTurnB),A         ; store into current player number 1
        LD      (GameMode2),A           ; set game mode2 to 0
        INC     A                       ; A := 1
        LD      (REG_FLIPSCREEN),A      ; store into screen flip for no flipping
        RET

; causes the player's score to percolate up the high score list
; [but it is never read from ???]

; called from $1361, HL is preloaded with #60B5 = player 2 score address, A is preloaded with 3
; called from $130F, HL is preloaded with #60B2 = player 1 score address, A is preloaded with 1

; this sub copies player score into #61C7-#61C9
; then it breaks the score into component digits and stores them into #61B1 through #61B6
; then it sets $61B7 through $61C4 to #10 (???)
;

        LD      DE,$61C6        ; load DE with address for ???
        LD      (DE),A          ; store A into it
        RST     $8              ; continue if there are credits or the game is being played, else RET

        INC     DE              ; DE := #61C7
        LD      BC,$0003        ; set counter to 3
        LDIR                    ; copy players score into this area
        LD      B,$03           ; for B = 1 to 3
        LD      HL,$61B1        ; load HL with ???

        DEC     DE              ; count down DE.  first time it has #61C9 after the DEC
        LD      A,(DE)          ; load A with this
        RRCA
        RRCA
        RRCA
        RRCA                    ; rotate right 4 times.  this transposes the 4 low and 4 high bits of the byte
        AND     $0F             ; mask bits, now between 0 and #F.  this will give the thousands of the score on the 2nd loop.
        LD      (HL),A          ; store into (HL) ???
        INC     HL              ; next
        LD      A,(DE)          ; load A with this
        AND     $0F             ; mask bits.  this will give the hundreds of the score on the 2nd loop
        LD      (HL),A          ; store into (HL)
        INC     HL              ; next
        DJNZ    $13DA           ; next B

; sets $61B7 through $61C4 to $10 (???)

        LD      B,$0E           ; for B = 1 to #E

        LD      (HL),$10        ; store #10 into memory at (HL)
        INC     HL              ; next HL
        DJNZ    $13ED           ; next B

        LD      (HL),$3F        ; store #3F into #61C5 = end code ?

        LD      B,$05           ; for B = 1 to 5.  Do for each high score in top 5
        LD      HL,$61A5        ; load HL with lowest high score address
        LD      DE,$61C7        ; load DE with copy of player score

        LD      A,(DE)          ; load A with a digit of player's score
        SUB     (HL)            ; subtract next lowest high score
        INC     HL              ; next
        INC     DE              ; next
        LD      A,(DE)          ; load A with next digit of player's score
        SBC     A,(HL)          ; subtract with carry next lowest high score
        INC     HL              ; next
        INC     DE              ; next
        LD      A,(DE)          ; load A with next digit of player's score
        SBC     A,(HL)          ; subtract with carry next lowest high score
        RET     C               ; if player has not made this high score, return

; player has made a high score for entry in top 5

        PUSH    BC              ; else save BC

        LD      B,$19           ; for B = 1 to #19

        ; exchange the values in (HL) and (DE) for #19 bytes
        ; this causes the high score to percolate up the high score list

        LD      C,(HL)          ; C := (HL)
        LD      A,(DE)          ; A := (DE)
        LD      (HL),A          ; (HL) := A
        LD      A,C             ; A := C
        LD      (DE),A          ; (DE) := A
        DEC     HL              ; next HL
        DEC     DE              ; next DE
        DJNZ    $140A           ; Next B

        LD      BC,$FFF5        ; load BC with -#A
        ADD     HL,BC           ; add to HL.  HL now has #A less than before
        EX      DE,HL           ; DE <> HL
        ADD     HL,BC           ; add to HL, now has #A less than before
        EX      DE,HL           ; DE <> HL
        POP     BC              ; restore BC
        DJNZ    $13FC           ; Next B

        RET

; jump here from $0701 when GameMode2 == #14 (game is over)
; draw credits on screen, clears screen and sprites, checks for high score, flips screen if necessary

        CALL    $0616           ; draw credits on screen
        RST     $18             ; count down timer and only continue here if zero, else RET

        CALL    $0874           ; clears the screen and sprites
        LD      A,$00           ; A := 0
        LD      (PlayerTurnB),A ; set player number 1
        LD      (PlayerTurnA),A ; set player1
        LD      HL,$611C        ; load HL with high score entry indicator
        LD      DE,$0022        ; offset to add is #22
        LD      B,$05           ; for B = 1 to 5
        LD      A,$01           ; A := 1 = code for a new high score for player 1

        CP      (HL)            ; compare (HL) to 1 .  equal ?
        JP      Z,$1459         ; yes, jump to high score entry for player 1

        ADD     HL,DE           ; else next HL
        DJNZ    $1437           ; next B

        LD      HL,$611C        ; load HL with high score entry indicator
        LD      B,$05           ; For B = 1 to 5
        LD      A,$03           ; A := 3 = code for a new high score for player 2

        CP      (HL)            ; compare.  same?
        JP      Z,$144F         ; yes, skip ahead and being high score entry for pl2

        ADD     HL,DE           ; add offset for next
        DJNZ    $1445           ; Next B

        JP      $1475           ; skip ahead, no high score was achieved

; high score achieved ?

        LD      A,$01                   ; A := 1
        LD      (PlayerTurnB),A         ; set player #2
        LD      (PlayerTurnA),A         ; set player2
        LD      A,$00                   ; A := 0

        LD      HL,UprightCab           ; load HL with address for upright/cocktail
        OR      (HL)                    ; mix with A
        LD      (REG_FLIPSCREEN),A      ; store A into screen flip setting
        LD      A,$00                   ; A := 0
        LD      (WaitTimerMSB),A        ; clear timer
        LD      HL,GameMode2            ; load HL with game mode2 address
        INC     (HL)                    ; increase game mode2 to #15
        LD      DE,$030D                ; load task data for text #D "NAME REGISTRATION"
        LD      B,$0C                   ; set counter for #0C items (12 decimal)

        CALL    $309F                   ; insert task to draw text
        INC     DE                      ; next text set
        DJNZ    $146E                   ; next B

        RET

; jump here from $144C

        LD      A,$01                   ; A := 1
        LD      (REG_FLIPSCREEN),A      ; set screen flip setting
        LD      (GameMode1),A           ; store into game mode1
        LD      (NoCredits),A           ; set indicator for no credits
        LD      A,$00                   ; A := 0
        LD      (GameMode2),A           ; reset game mode2 to 0.  game is now totally over.
        RET


; jump from $0701 when GameMode2 == #15
; game is over - high score entry


        CALL    $0616                   ; draw credits on screen
        LD      HL,WaitTimerMSB         ; load HL with timer
        LD      A,(HL)                  ; load A with timer value
        AND     A                       ; == 0 ?
        JP      NZ,$14DC                ; no, skip ahead

        LD      (REG_PALETTE_A),A       ; set palette bank selector
        LD      (REG_PALETTE_B),A       ; set palette bank selector
        LD      (HL),$01                ; set timer to 1
        LD      HL,HSCursorDelay        ; load HL with HSCursorDelay
        LD      (HL),$0A
        INC     HL                      ; HL := HSBlinkToggle
        LD      (HL),$00
        INC     HL                      ; HL := HSBlinkTimer
        LD      (HL),$10
        INC     HL                      ; HL := HSRegiTime
        LD      (HL),$1E
        INC     HL                      ; HL := HSTimer
        LD      (HL),$3E                ; set outer loop timer
        INC     HL                      ; HL := HSCursorPos
        LD      (HL),$00                ; set high score digit selected
        LD      HL,$75E8                ; load HL with screen position for first player initial
        LD      (HSInitialPos),HL       ; save into this indicator
        LD      HL,$611C                ; load HL with address of high score indicator
        LD      A,(PlayerTurnB)         ; load A with current player number
        RLCA                            ; rotate left
        INC     A                       ; increase
        LD      C,A                     ; copy to C.  C now has 1 for player 1, 3 for player 2
        LD      DE,$0022                ; load DE with offset
        LD      B,$04                   ; for B = 1 to 4

        LD      A,(HL)                  ; load A with high score indicator
        CP      C                       ; == current player number ?
        JP      Z,$14C9                 ; yes, skip next 2 steps - this is the one

        ADD     HL,DE                   ; add offset for next HL
        DJNZ    $14C1                   ; Next B

        LD      (Unk6038),HL            ; store HL into Unk6038
        LD      DE,$FFF3                ; load DE with offset of -#13
        ADD     HL,DE                   ; add offset
        LD      ($603A),HL              ; store result into ???
        LD      B,$00                   ; B := 0
        LD      A,(HSCursorPos)         ; load A with high score entry digit selected
        LD      C,A                     ; copy to C
        CALL    $15FA                   ; ???

        LD      HL,HSTimer              ; load HL with outer loop timer
        DEC     (HL)                    ; count down timer.  at zero?
        JP      NZ,$14FC                ; no, skip ahead

        LD      (HL),$3E                ; reset outer loop timer
        DEC     HL                      ; HL := HSRegiTime
        DEC     (HL)                    ; decrease.  at zero?
        JP      Z,$15C6                 ; yes, skip ahead to handle

        LD      A,(HL)                  ; else load A with time remaining
        LD      B,$FF                   ; B := #FF.  used to count 10's

        INC     B                       ; increase B
        SUB     $0A                     ; subtract #0A (10 decimal).  gone under?
        JP      NC,$14ED                ; no, loop again.  B will have number of 10's

        ADD     A,$0A                   ; add #0A to make between 0 and 9
        LD      ($7552),A               ; draw digit to screen
        LD      A,B                     ; A := B = 10's of time left
        LD      ($7572),A               ; draw digit to screen

        LD      HL,HSCursorDelay        ; load HL with HSCursorDelay
        LD      B,(HL)                  ; load B with the value
        LD      (HL),$0A                ; store #A into it
        LD      A,(InputState)          ; load A with input
        BIT     7,A                     ; is jump button pressed?
        JP      NZ,$1546                ; yes, skip ahead

        AND     $03                     ; mask bits.  check for a left or right direction pressed
        JP      NZ,$1514                ; if direction, skip next 3 steps

        INC     A                       ; else increase A
        LD      (HL),A                  ; store into HSCursorDelay
        JP      $158A                   ; skip ahead

; left or right pressed while in high score entry

        DEC     B               ; decrease B.  at zero?
        JP      Z,$151D         ; yes, skip next 3 steps

        LD      A,B             ; A := B
        LD      (HL),A          ; store into ???
        JP      $158A           ; skip ahead

        BIT     1,A             ; is direction == left ?
        JP      NZ,$1539        ; yes, skip ahead

        LD      A,(HSCursorPos) ; load A with high score entry digit selected
        INC     A               ; increase
        CP      $1E             ; == #1E ?  (have we gone past END ?)
        JP      NZ,$152D        ; no, skip next step

        LD      A,$00           ; A := 0 [why this way and not XOR A ?] - reset this counter to "A" in the table

        LD      (HSCursorPos),A ; store into high score entry digit selected
        LD      C,A             ; C := A
        LD      B,$00           ; B := 0
        CALL    $15FA           ; ???
        JP      $158A           ; skip ahead

        LD      A,(HSCursorPos) ; load A with high score entry digit selected
        SUB     $01             ; decrease [why written this way?  DEC A is standard...]
        JP      P,$152D         ; if sign positive, loop again

        LD      A,$1D           ; A := #1D
        JP      $152D           ; jump back

; jump pressed in high score entry

        LD      A,(HSCursorPos)         ; load A with high score entry digit selected
        CP      $1C                     ; == #1C ? = code for backspace ?
        JP      Z,$156D                 ; yes, skip ahead to handle

        CP      $1D                     ; == #1D ? = code for END
        JP      Z,$15C6                 ; yes, skip ahead to hanlde

        LD      HL,(HSInitialPos)       ; else load HL with VRAM address of the initial being entered
        LD      BC,$7588                ; load BC with screen address
        AND     A                       ; clear carry flag
        SBC     HL,BC                   ; subtract.  equal?
        JP      Z,$158A                 ; yes, skip ahead

        ADD     HL,BC                   ; else add it back
        ADD     A,$11                   ; add ascii offset of #11 to A
        LD      (HL),A                  ; write letter to screen
        LD      BC,$FFE0                ; load BC with offset for next column
        ADD     HL,BC                   ; set HL to next column

        LD      (HSInitialPos),HL       ; store HL back into VRAM address of the initial being entered
        JP      $158A                   ; skip ahead

; backspace selected in high score entry

        LD      HL,(HSInitialPos)       ; else load HL with VRAM address of the initial being entered
        LD      BC,$0020                ; load offset of #20
        ADD     HL,BC                   ; add offset
        AND     A                       ; clear carry flag
        LD      BC,$7608                ; load BC with screen address
        SBC     HL,BC                   ; subtract.  equal?
        JP      NZ,$1586                ; no, skip ahead

        LD      HL,$75E8                ; else load HL with other screen address

        LD      A,$10                   ; A := #10 = blank code
        LD      (HL),A                  ; clear the screen at this position
        JP      $1567                   ; jump back

        ADD     HL,BC                   ; restore HL back to what it was
        JP      $1580                   ; jump back

; jump here from $156A and $155C and #1536 and #151A and #1511

        LD      HL,HSBlinkTimer         ; load HL with HSBlinkTimer
        DEC     (HL)                    ; decrease.  at zero ?
        JP      NZ,$15F9                ; no, jump to RET. [RET NZ would be faster and more compact]

; Blink the high score in high score table
        LD      A,(HSBlinkToggle)
        AND     A                       ; Is HSBlinkToggle zero?
        JP      NZ,$15B8                ; no, skip ahead

        LD      A,$01                   ; A := 1
        LD      (HSBlinkToggle),A       ; store into HSBlinkToggle
        LD      DE,$01BF

        LD      IY,(Unk6038)            ; load IY with Unk6038
        LD      L,(IY+$04)
        LD      H,(IY+$05)
        PUSH    HL
        POP     IX                      ; load IX with HL
        CALL    $057C                   ; ???
        LD      A,$10                   ; A := #10
        LD      (HSBlinkTimer),A        ; store into HSBlinkTimer
        JP      $15F9                   ; jump to RET [RET would be faster and more compact]

        XOR     A                       ; A := 0
        LD      (HSBlinkToggle),A       ; store into HSBlinkToggle
        LD      DE,(Unk6038)
        INC     DE
        INC     DE
        INC     DE
        JP      $15A0                   ; jump back

; arrive here from $14E7
; high score entry complete ???

        LD      DE,(Unk6038)    ; load DE with address of high score entry indicator
        XOR     A               ; A := 0
        LD      (DE),A          ; store.  this clears the high score indicator
        LD      HL,WaitTimerMSB ; load HL with timer
        LD      (HL),$80        ; set time to #80
        INC     HL              ; HL := GameMode2
        DEC     (HL)            ; decrease game mode2
        LD      B,$0C           ; for B = 1 to #C (12 decimal)
        LD      HL,$75E8        ; load HL with screen vram address
        LD      IY,($603A)      ; load IY with ???
        LD      DE,$FFE0        ; load DE with offset of -#20

        LD      A,(HL)          ; load A with
        LD      (IY+$00),A      ; store
        INC     IY              ; next
        ADD     HL,DE           ; add offset
        DJNZ    $15DF           ; next B

        LD      B,$05           ; For B = 1 to 5
        LD      DE,$0314        ; load task data for text #14 - start of high score table

        CALL    $309F           ; insert task to draw text
        INC     DE              ; next high score
        DJNZ    $15ED           ; next B

        LD      DE,$031A        ; load task data for text #1A - "YOUR NAME WAS REGISTERED"
        CALL    $309F           ; insert task to draw text
        RET

; sets the sprite to the square selector for intials entry
; called from $14D9 and $1533

        PUSH    DE              ; save DE
        PUSH    HL              ; save HL
        SLA     C               ;
        LD      HL,$360F        ; start of table data
        ADD     HL,BC
        EX      DE,HL
        LD      HL,$6974
        LD      A,(DE)          ; load A with table data
        INC     DE              ; next table entry
        LD      (HL),A          ; store
        INC     HL              ; next location
        LD      (HL),$72
        INC     HL
        LD      (HL),$0C
        INC     HL
        LD      A,(DE)
        LD      (HL),A
        POP     HL              ; restore HL
        POP     DE              ; restore DE
        RET

; arrive when GameMode2 == $16 (level completed).  called from #0701

        CALL    $30BD           ; clear sprites
        LD      A,($6227)       ; load a with screen number
        RRCA                    ; roll right with carry.  is this the rivets or the conveyors?
        JP      NC,$162f        ; yes, skip ahead to #162F

                                ; handle for girders or elevators, they are same here

        LD      A,($6388)       ; load A with this counter usually zero, counts from 1 to 5 when the level is complete
        RST     $28             ; jump based on A

        hex     54 16           ; #1654  0
        hex     70 16           ; #1670  1
        hex     8A 16           ; #168A  2
        hex     32 17           ; #1732  3
        hex     57 17           ; #1757  4
        hex     8E 17           ; #178E  5

        RRCA                    ; roll right again.  is this the rivets ?
        JP      NC,$1641        ; yes, skip ahead

; else the conveyors

        LD      A,($6388)       ; load A with this usually zero, counts from 1 to 5 when the level is complete
        RST     $28             ; jump based on A

        hex     A3 16           ; #16A3  0
        hex     BB 16           ; #16BB  1
        hex     32 17           ; #1732  2
        hex     57 17           ; #1757  3
        hex     8E 17           ; #178E  4

; rivets

        CALL    $1DBD           ; check for bonus items and jumping scores, rivets
        LD      A,($6388)       ; load A with usually zero, counts from 1 to 5 when the level is complete

        RST     $28             ; jump based on A

        hex     B6 17           ; #17B6  0
        hex     69 30           ; #3069  1
        hex     39 18           ; #1839  2
        hex     6F 18           ; #186F  3
        hex     80 18           ; #1880  4
        hex     C6 18           ; #18C6  5

; jump here from $1622 when girders or elevators is finished.  step 1 of 6

        CALL    #1708                   ; clear all sounds, draw heart sprite, redraw girl sprite, clear "help", play end of level sound
        LD      HL,#385C                ; load HL with start of kong graphic table data
        CALL    #004E                   ; update kong's sprites
        LD      A,#20                   ; A := #20
        LD      (WaitTimerMSB),A        ; set timer to #20

        LD      HL,$6388                ; load HL with end of level counter
        INC     (HL)                    ; increase counter
        LD      A,$01                   ; A := 1 = code for girders
        RST     $30                     ; if girders, continue below.  else RET

        LD      HL,$690B                ; load HL with start of kong sprite
        LD      C,$FC                   ; set movement for -4 pixels
        RST     $38                     ; move kong
        RET

; jump here from $1622 when girders or elevators is finished.  step 2 of 6

        RST     $18                     ; count down timer and only continue here if zero, else RET
        LD      HL,$3932                ; load HL with start of kong's sprites table data
        CALL    $004E                   ; update kong's sprites
        LD      A,$20                   ; A := #20
        LD      (WaitTimerMSB),A        ; set timer to #20
        LD      HL,$6388                ; load HL with end of level counter
        INC     (HL)                    ; increase counter
        LD      A,$04                   ; A := 4 = 100 code for elevators
        RST     $30                     ; only continue here if elevators, else RET

        LD      HL,$690B                ; load HL with start of Kong sprite
        LD      C,$04                   ; set to move by 4
        RST     $38                     ; move kong by +4
        RET

; jump here from $1622 when girders or elevators is finished.  step 3 of 6

        RST     $18             ; count down timer and only continue here if zero, else RET
        LD      HL,$388C        ; load HL with start of table data for kong
        CALL    $004E           ; update kong's sprites
        LD      A,$66           ; A := #66
        LD      ($690C),A       ; store into kong's right arm sprite
        XOR     A               ; A := 0
        LD      ($6924),A       ; clear the other side of kongs arm
        LD      ($692C),A       ; clear the girl sprite that kong is carrying
        LD      ($62AF),A       ; clear the kong climbing counter
        JP      $1662           ; jump back

; jump here from $1622 when conveyors is finished.  step 1 of 5

        CALL    $1708           ; clear all sounds, draw heart sprite, redraw girl sprite, clear "help", play end of level sound
        LD      A,($6910)       ; load A with kong's X position
        SUB     $3B             ; subtract #3B
        LD      HL,$385C        ; load HL with kong graphic table data
        CALL    $004E           ; update kong's sprites to default kong graphic
        LD      HL,$6908        ; load HL with start of Kong sprite
        LD      C,A             ; load C with offset computed above to move kong back where he was
        RST     $38             ; move Kong
        LD      HL,$6388        ; load HL with end of level counter
        INC     (HL)            ; increase counter
        RET

; jump here from $1622 when conveyors is finished.  step 2 of 5

        XOR     A               ; A := 0
        LD      ($62A0),A       ; clear top conveyor counter
        LD      A,($63A3)       ; load A with direction vector for top conveyor
        LD      C,A             ; copy to C
        LD      A,($6910)       ; load A with kong's X position
        CP      $5A             ; < #5A ?
        JP      NC,$16E1        ; yes, skip ahead

        BIT     7,C
        JP      Z,$16D5         ; yes, skip next 2 steps

        LD      A,$01           ; A := 1
        LD      ($62A0),A       ; store into top conveyor counter

        CALL    $2602           ; ???
        LD      A,($63A3)       ; load A with direction vector for top conveyor
        LD      C,A             ; C := 1
        LD      HL,$6908        ; load HL with start of Kong sprite
        RST     $38             ; move kong
        RET

        CP      $5D             ; < #5D ?
        JP      C,$16EE         ; no, skip ahead

        BIT     7,C             ; is bit 7 of C zero?
        JP      Z,$16D0         ; yes, jump back

        JP      $16D5           ; jump back

        LD      HL,$388C        ; load HL with start of table data for kong
        CALL    $004E           ; update kong's sprites
        LD      A,$66           ; A := #66
        LD      ($690C),A       ; store into kong's right arm sprite for climbing
        XOR     A               ; A := 0
        LD      ($6924),A       ; clear kong's arm sprite
        LD      ($692C),A       ; clear girl under kong's arm
        LD      ($62AF),A       ; clear kong climbing counter
        LD      HL,$6388        ; load HL with end of level counter
        INC     (HL)            ; increase counter
        RET

; called from $1654 and $16A3
; clears all sounds, draws heart sprite, redraws girl sprite, clear "help", play end of level sound

        CALL    $011C           ; clear all sounds
        LD      HL,$6A20        ; load HL with heart sprite
        LD      (HL),$80        ; set heart sprite X position
        INC     HL              ; next
        LD      (HL),$76        ; set heart sprite
        INC     HL              ; next
        LD      (HL),$09        ; set heart sprite color
        INC     HL              ; next
        LD      (HL),$20        ; set heart sprite Y position
        LD      HL,$6905        ; load HL with girl's sprite
        LD      (HL),$13        ; set girl's sprite
        LD      HL,$75C4        ; load HL with VRAM screen address
        LD      DE,$0020        ; DE := #20
        LD      A,$10           ; A := #10
        CALL    $0514           ; clear "help" that the girl yells
        LD      HL,$608A        ; load sound address
        LD      (HL),$07        ; play sound for end of level
        INC     HL              ; HL now has sound duration
        LD      (HL),$03        ; set duration to 3
        RET

; jump here from $1622 when girders or elevators is finished.  step 4 of 6
; jump here from $1622 when conveyors is finished.  step 3 of 5

        CALL    $306F           ; animate kong climbing up the ladder with girl under arm
        LD      A,($6913)       ; load A with kong sprite Y position
        CP      $2C             ; < #2C ? (level of the girl)
        RET     NC              ; yes, return

; else kong has grabbed the girl on the way out

        XOR     A               ; A := #00
        LD      ($6900),A       ; clear girl's head sprite
        LD      ($6904),A       ; clear girl's body sprite
        LD      ($690C),A       ; clear kong's top right sprite
        LD      A,$6B           ; A := #6B = code for sprite with kong's arm out
        LD      ($6924),A       ; store into kong's right arm sprite for carrying girl
        DEC     A               ; A := #6A = code for sprite with girl being carried
        LD      ($692C),A       ; store into girl being carried sprite
        LD      HL,$6A21        ; load HL with heart sprite
        INC     (HL)            ; change heart to broken
        LD      HL,$6388        ; load HL with end of level counter
        INC     (HL)            ; increase counter
        RET

; jump here from $1622 when girders or elevators is finished.  step 5 of 6
; jump here from $1622 when conveyors is finished.  step 4 of 5

        CALL    $306F                   ; animate kong climbing up the ladder with girl under arm
        CALL    $176C                   ; ???
        INC     HL
        INC     DE
        CALL    $1783                   ; ???
        LD      A,$40                   ; A := #40
        LD      (WaitTimerMSB),A        ; set timer to #40
        LD      HL,$6388                ; load HL with end of level counter
        INC     (HL)                    ; increase counter
        RET

; called from $175A, above

        LD      DE,$0003        ; load DE with offset to subtract
        LD      HL,$692F        ; load HL with girl under kong's arm Y position.  counting down, it will go through all of kong's body
        LD      B,$0A           ; for B = 1 to #0A

        AND     A               ; clear carry flag
        LD      A,(HL)          ; load A with Y position
        SBC     HL,DE           ; next offset
        CP      $19             ; girl still on screen?
        JP      NC,$177F        ; yes, skip next step

        LD      (HL),$00        ; set Y position to 0 = clear from screen ?

        DEC     HL              ; previous data
        DJNZ    $1774           ; Next B

        RET

; called from $175F

        LD      B,$0A           ; for B = 1 to #A

        LD      A,(HL)          ; load A with ???
        AND     A               ; == 0 ?
        JP      NZ,$0026        ; no, jump to #0026.  This will effectively RET twice

        ADD     HL,DE           ; else add offset for next memory
        DJNZ    $1785           ; next B

        RET

; jump here from $1622 when girders or elevators is finished.  step 6 of 6
; jump here from $1622 when conveyors is finished.  step 5 of 5

        RST     $18             ; count down timer and only continue here if zero, else RET
        LD      HL,($622A)      ; load HL with address for this screen/level
        INC     HL              ; next screen
        LD      A,(HL)          ; load A with the screen for next
        CP      $7F             ; at end ?
        JP      NZ,$179D        ; no, skip next 2 steps

        LD      HL,$3A73        ; load HL with table for screens/levels for level 5+
        LD      A,(HL)          ; load A with the screen

        LD      ($622A),HL      ; store screen address lookup for next time
        LD      ($6227),A       ; store A into screen number
        LD      DE,$0500        ; load task #5, parameter 0 ; adds bonus to player's score
        CALL    $309F           ; insert task
        XOR     A               ; A := 0
        LD      ($6388),A       ; clear end of level counter
        LD      HL,WaitTimerMSB ; load HL with timer addr.
        LD      (HL),$30        ; set timer to #30
        INC     HL              ; HL := GameMode2
        LD      (HL),$08        ; set game mode2 to 8
        RET

        NOP

; arrive when rivets is cleared

        CALL    $011C                   ; clear all sounds
        LD      HL,$608A                ; load HL with sound address
        LD      (HL),$0E                ; play sound for rivets falling and kong beating chest
        INC     HL                      ; HL := #608B = sound duration
        LD      (HL),$03                ; set duration to 3
        LD      A,$10                   ; A := #10 = code for clear space
        LD      DE,$0020                ; DE := #20
        LD      HL,$7623                ; load HL with video RAM location
        CALL    $0514                   ; clear "help" on left side of girl
        LD      HL,$7583                ; load HL with video RAM location
        CALL    $0514                   ; clear "help of right side of girl
        LD      HL,$76DA                ; load HL with center area of video ram
        CALL    $1826                   ; clear screen area
        LD      DE,$3A47                ; load DE with start of table data
        CALL    $0DA7                   ; draw the screen
        LD      HL,$76D5                ; load HL with center area of video ram
        CALL    $1826                   ; clear screen area
        LD      DE,$3A4D                ; load DE with start of table data
        CALL    $0DA7                   ; draw the screen
        LD      HL,$76D0                ; load HL with center area of video ram
        CALL    $1826                   ; clear screen area
        LD      DE,$3A53                ; load DE with start of table data
        CALL    $0DA7                   ; draw the screen
        LD      HL,$76CB                ; load HL with center area of video ram
        CALL    $1826                   ; clear screen area
        LD      DE,$3A59                ; load DE with start of table data
        CALL    $0DA7                   ; draw the screen
        LD      HL,$385C                ; load HL with start of kong graphic table data
        CALL    $004E                   ; update kong's sprites
        LD      HL,$6908                ; load HL with start of kong sprites
        LD      C,$44                   ; load offset of #44
        RST     $38                     ; move kong
        LD      HL,$6905                ; load HL with girl's sprite
        LD      (HL),$13                ; set girl's sprite
        LD      A,$20                   ; A := #20
        LD      (WaitTimerMSB),A        ; set timer to #20
        LD      A,$80                   ; A := #80
        LD      ($6390),A               ; store into timer ???
        LD      HL,$6388                ; load HL with end of level counter
        INC     (HL)                    ; increase counter
        LD      ($63C0),HL              ; store into ???
        RET

; called from several places with HL preloaded with a video RAM address
; used to clear sections of the rivets screen when it is completed

        LD      DE,$FFDB        ; load DE with offset for each column
        LD      C,$0E           ; for C = 1 to #0E
        LD      A,$10           ; A := #10 (clear space on screen)

        LD      B,$05           ; for B = 1 to 5

        LD      (HL),A          ; store A into (HL) - clears the screen element
        INC     HL              ; next HL
        DJNZ    $182F           ; next B

        ADD     HL,DE           ; add offset to HL
        DEC     C               ; next C
        JP      NZ,$182D        ; loop until done

        RET

; arrive from $1647 when $6388 == 2

        LD      HL,$6390        ; load HL with timer ???
        INC     (HL)            ; increase.  at zero?
        JP      Z,$1859         ; yes, skip ahead

        LD      A,(HL)          ; load A with the timer value
        AND     $07             ; mask bits, now between 0 and 7.  zero?
        RET     NZ              ; no, return

; kong is beating his chest after rivets have been cleared

        LD      DE,$39CF                ; load DE with start of table data
        BIT     3,(HL)                  ; test bit 3.  True?
        JR      NZ,$184E                ; Yes, skip next step

        LD      DE,$39F7                ; else load DE with other table start

        EX      DE,HL                   ; DE <> HL
        CALL    $004E                   ; update kong's sprites
        LD      HL,$6908                ; load HL with start of Kong sprite
        LD      C,$44                   ; C := #44
        RST     $38                     ; move kong
        RET

        LD      HL,$385C                ; load HL with start of kong graphic table data
        CALL    $004E                   ; update kong's sprites
        LD      HL,$6908                ; load HL with start of Kong sprite
        LD      C,$44                   ; C := #44
        RST     $38                     ; move kong
        LD      A,$20                   ; A := #20
        LD      (WaitTimerMSB),A        ; store into timer
        LD      HL,$6388                ; load HL with end of level counter
        INC     (HL)                    ; increase counter
        RET

; rivets has been cleared and kong is falling upside down
; arrive from $1647

        RST     $18             ; count down timer and only continue here if zero, else RET

        LD      HL,$3A1F        ; start of table data for kong upside down
        CALL    $004E           ; update kong's sprites
        LD      A,$03           ; A := 3
        LD      ($6084),A       ; play falling sound
        LD      HL,$6388        ; load HL with end of level counter
        INC     (HL)            ; increase
        RET

; arrive from $1647 when $6388 == 4

        LD      HL,$690B        ; load HL with kong start sprite
        LD      C,$01           ; load C with 1 pixel to move
        RST     $38             ; move kong
        LD      A,($691B)       ; load A with ???
        CP      $D0             ; == #D0 ?
        RET     NZ              ; no, return

        LD      A,$20           ; A := #20
        LD      ($6919),A       ; store into kong's face sprite - kong is now bigmouthed with crazy eyes
        LD      HL,$6A24        ; load HL with sprite address used for kong's aching head lines
        LD      (HL),$7F        ; set sprite X value
        INC     L               ; next
        LD      (HL),$39        ; set sprite color
        INC     L               ; next
        LD      (HL),$01        ; set sprite value
        INC     L               ; next
        LD      (HL),$D8        ; set sprite Y value
        LD      HL,$76C6        ; load HL with start of screen location to clear
        CALL    $1826           ; clear the top part of rivets
        LD      DE,$3A5F        ; load DE with table data for sections to clear after rivets done
        CALL    $0DA7           ; draw the top girder where mario and girl meet

        LD      DE,$0004        ; load counters
        LD      BC,$0228        ; load counters
        LD      HL,$6903        ; set sprite girl table data Y position
        CALL    $003D           ; move the girl down

        LD      A,$00           ; A := 0 [why written this way?]
        LD      ($62AF),A       ; store into kong climbing counter
        LD      A,$03           ; set boom sound duration
        LD      ($6082),A       ; play boom sound
        LD      HL,$6388        ; load HL with end of level counter
        INC     (HL)            ; increase counter
        RET

; arrive from $1647 when level is complete, last of 5 steps

        LD      HL,$62AF        ; load HL with kong climbing counter address
        DEC     (HL)            ; decrease.  zero?
        JP      Z,$193D         ; yes, skip ahead, handle next level routine

        LD      A,(HL)          ; load A with kong climbing counter
        AND     $07             ; mask bits, now between 0 and 7.  zero?
        RET     NZ              ; no , return

        LD      HL,$6A25        ; load HL with ???
        LD      A,(HL)          ; get value
        XOR     $80             ; toggle bit 7
        LD      (HL),A          ; store result

        LD      HL,$6919        ; load HL with ???
        LD      B,(HL)          ; load B with this value
        RES     5,B             ; clear bit 5 of B
        XOR     A               ; A := 0
        CALL    $3009           ; ???
        OR      $20             ; turn on bit 5
        LD      (HL),A          ; store result

        LD      HL,$62AF        ; load HL with kong climbing counter
        LD      A,(HL)          ; get value
        CP      $E0             ; == #E0 ?
        JP      NZ,$1910        ; no, skip ahead

        LD      A,$50           ; A := #50
        LD      ($694F),A       ; store into mario sprite Y value
        LD      A,$00           ; A := 0
        LD      ($694D),A       ; store into mario sprite value
        LD      A,$9F           ; A := #9F
        LD      ($694C),A       ; set mario sprite X value at #9F
        LD      A,($6203)       ; load A with mario X position
        CP      $80             ; < 80 ?
        JP      NC,$190F        ; yes, skip next 4 steps

        LD      A,$80           ; A := #80
        LD      ($694D),A       ; store into mario sprite value
        LD      A,$5F           ; A := #5F
        LD      ($694C),A       ; store into mario sprite X value

        LD      A,(HL)          ; load A with ???

        CP      $C0             ; == #C0 ?
        RET     NZ              ; no, return

        LD      HL,$608A        ; load HL with sound address
        LD      (HL),$0C        ; play sound for rivets cleared
        LD      A,($6229)       ; load A with level #
        RRCA                    ; roll a right .  is this an odd level ?
        JR      c,$1920         ; Yes, skip next step

        LD      (HL),$05        ; else play sound for even numbered rivets

        INC     HL              ; HL := #608B = sound duration
        LD      (HL),$03        ; set duration to 3
        LD      HL,$6A23        ; load HL with heart sprite
        LD      (HL),$40        ; set heart sprite Y position
        DEC     HL              ; decrement HL
        LD      (HL),$09        ; set heart sprite color
        DEC     HL              ; decrement HL
        LD      (HL),$76        ; set heart sprite
        DEC     HL              ; decrement HL
        LD      (HL),$8f        ; set heart sprite X position
        LD      A,($6203)       ; load A with mario X position
        CP      $80             ; is mario on the left side of the screen?
        RET     nc              ; yes, return

        LD      A,$6f           ; else A := #6F
        LD      ($6A20),A       ; store A into heart sprite X position
        RET

; kong has climbed off the screen at end of level

        LD      HL,($622A)      ; load HL with contents of #622A.  this is a pointer to the levels/screens data
        INC     HL              ; increase HL.  = next level
        LD      A,(HL)          ; load A with contents of HL = the screen we are going to play next
        CP      $7f             ; is this the end code ?
        JP      NZ,$194B        ; no, skip next 2 steps

        LD      HL,$3A73        ; yes, load HL with #3A73 = start of table data for screens/levels for level 5+
        LD      A,(HL)          ; load A with screen number from table

        LD      ($622A),HL      ; store
        LD      ($6227),A       ; store A into screen number
        LD      HL,$6229        ; load HL with level number address
        INC     (HL)            ; increase #6229 by one
        LD      DE,$0500        ; load task #5, parameter 0 ; adds bonus to player's score
        CALL    $309F           ; insert task
        XOR     A               ; A := 0
        LD      ($622E),A       ; store into number of goofys to draw
        LD      ($6388),A       ; store into end of level counter
        LD      HL,WaitTimerMSB ; load HL with timer
        LD      (HL),$e0        ; set timer to #E0
        INC     HL              ; increase HL to GameMode2
        LD      (HL),$08        ; set game mode2 to 8
        RET

; arrive from jump table at $0701 when GameMode2 == #17

        CALL    $0852           ; clear screen and all sprites
        LD      A,(PlayerTurnB) ; load A with current player number.  0 = player 1, 1 = player 2
        ADD     A,$12           ; add #12
        LD      (GameMode2),A   ; store into game mode2, now had #12 for player 1 or #13 for player 2
        RET

; main routine

        CALL    $21EE           ; used during attract mode only.  sets virtual input.

; arrive here from $0701 when playing

        CALL    $1DBD           ; check for bonus items and jumping scores, rivets
        CALL    $1E8C           ; do stuff for items hit with hammer
        CALL    $1AC3           ; check for jumping
        CALL    $1F72           ; roll barrels
        CALL    $2C8F           ; roll barrels ?
        CALL    $2C03           ; do barrel deployment ?
        CALL    $30ED           ; update fires if needed
        CALL    $2E04           ; update bouncers if on elevators
        CALL    $24EA           ; do stuff for pie factory
        CALL    $2DDB           ; deploy fireball/firefoxes for conveyors and rivets
        CALL    $2ED4           ; do stuff for hammer
        CALL    $2207           ; do stuff for conveyors
        CALL    $1A33           ; check for and handle running over rivets
        CALL    $2A85           ; check for mario falling
        CALL    $1F46           ; handle mario falling
        CALL    $26FA           ; do stuff for elevators
        CALL    $25F2           ; handle conveyor directions, adjust Mario's speed based on conveyor directions
        CALL    $19DA           ; check for mario picking up bonus item
        CALL    $03FB           ; check for kong beating chest and animate girl and her screams
        CALL    $2808           ; check for collisions with hostile sprites [set to NOPS to make mario invincible to enemy sprites]
        CALL    $281D           ; do stuff for hammers
        CALL    $1E57           ; check for end of level
        CALL    $1A07           ; handle when the bonus timer has run out
        CALL    $2FCB           ; for non-girder levels, checks for bonus timer changes. if the bonus counts down, sets a possible new fire to be released,
                                ; sets a bouncer to be deployed, updates the bonus timer onscreen, and checks for bonus time running out
        NOP
        NOP
        NOP                     ; no operations.  [a deleted call ?]

        LD      A,($6200)       ; load A with 0 if mario is dead, 1 if he is alive
        AND     A               ; is mario alive?
        RET     NZ              ; yes, return to #00D2

; mario died

        CALL    $011C           ; no, mario died.  clear all sounds
        LD      HL,$6082        ; load HL with boom sound address
        LD      (HL),$03        ; play boom sound for 3 units
        LD      HL,GameMode2    ; load HL with game mode2
        INC     (HL)            ; increase
        DEC     HL              ; HL := WaitTimerMSB (timer used for sound effects)
        LD      (HL),$40        ; set timer to wait 40 units
        RET                     ; ret to #00D2

; called from $19AD as part of the main routine
; checks for bonus items being picked up

        LD      A,($6203)       ; load A with Mario's X position
        LD      B,$03           ; for B = 1 to 3
        LD      HL,$6A0C        ; load HL with X position of first bonus

        CP      (HL)            ; are they equal?
        JP      Z,$19ED         ; yes, then test the Y position too

        INC     L
        INC     L
        INC     L
        INC     L               ; increase 4 times to point to next bonus item position
        DJNZ    $19E2           ; Loop 3 times, check for the 3 items

        RET

        LD      A,($6205)       ; load A with Mario's Y position
        INC     L
        INC     L
        INC     L               ; get HL to point to Y position of bonus item
        CP      (HL)            ; are they equal?
        RET     NZ              ; no, return from this test

        DEC     L               ; yes, decrement L 2 times to check if this item has already been picked up
        DEC     L
        BIT     3,(HL)          ; test bit 3 of HL, tells whether picked up already or not.  Item not already picked up?
        RET     NZ              ; Item picked up already, then return

; bonus item has been picked up

        DEC     L               ; decrease L.  HL now has the starting address of the sprite that was picked up
        LD      ($6343),HL      ; store into this temp memory.  read from at #1E18
        XOR     A               ; A := 0
        LD      ($6342),A       ; store into ???.  read from at #1DD6
        INC     A               ; A := 1
        LD      ($6340),A       ; store into #6340 - usually 0, changes when mario picks up bonus item. jumps over item turns to 1 quickly, then 2 until bonus disappears
        RET

; called from main routine at $19BC

        LD      A,($6386)       ; load A with the location which tells if the timer has run out yet.
        RST     $28             ; jump based on A

        hex     1E 1A           ; #1A1E if zero return immediately, bonus timer has not run out
        hex     15 1A           ; #1A15
        hex     1F 1A           ; #1A1F
        hex     2A 1A           ; #1A2A
        hex     00 00           ; unused

; arrive from $1A0A

        XOR     A               ; A := 0
        LD      ($6387),A       ; clear timer which counts down when the timer runs out
        LD      A,$02           ; A := 2
        LD      ($6386),A       ; store into the location which tells if the timer has run out yet.
        RET

; arrive from $1A0A

        LD      HL,$6387        ; load HL with timer address
        DEC     (HL)            ; decreases the timer which counts down after time has run out. time out?
        RET     NZ              ; no, return

        LD      A,$03           ; A := 3
        LD      ($6386),A       ; store 3 into #6386 - time is up for mario!
        RET

; we arrive here when the timer runs out

        LD      A,($6216)       ; load A with jump indicator
        AND     A               ; is mario jumping ?
        RET     NZ              ; yes, return, mario never dies while jumping

        POP     HL              ; no, pop HL to return to higher subroutine
        JP      $19D2           ; jump to mario died and return

; called from main routine
; check for running over rivets ?

        LD      A,$08           ; A := 8 = 1000 binary = code for rivets
        RST     $30             ; continue here only on rivets, else RET

        LD      A,($6203)       ; load A with mario's X position
        CP      $4B             ; == #4B = the column the left rivets are on ?
        JP      Z,$1A4B         ; yes, skip ahead and set the indicator

        CP      $B3             ; == #B3 = the column the right rivets are on ?
        JP      Z,$1A4B         ; yes, skip ahead and set the indicator

        LD      A,($6291)       ; else load A with rivet column indicator
        DEC     A               ; is mario possibly traversing a column?
        JP      Z,$1A51         ; yes, skip ahead
        RET                     ; else return

        LD      A,$01           ; A := 1
        LD      ($6291),A       ; store into column indicator
        RET

        LD      ($6291),A       ; clear the column indicator
        LD      B,A             ; B := 0
        LD      A,($6205)       ; load A with Mario's Y position
        DEC     A               ; decrement
        CP      $D0             ; compare with #D0.  is mario too low to go over a rivet?
        RET     NC              ; yes, return

        RLCA                    ; rotate left = mult by 2
        JP      NC,$1A62        ; no carry, skip next step

        SET     2,B             ; else B := 4

        RLCA                    ;
        RLCA                    ; rotate left twice = mult by 4
        JP      NC,$1A69        ; no carry, skip next step

        SET     1,B             ; B := B + 2
        AND     $07             ; mask bits in A, now between 0 and 7
        CP      $06             ; == 6 ?
        JP      NZ,$1A72        ; no, skip next step

        SET     1,B             ; else set this bit
        LD      A,($6203)       ; load A with mario's X position
        RLCA                    ; rotate left
        JP      NC,$1A7B        ; no carry, skip next step

        SET     0,B             ; B := B + 1
        LD      HL,$6292        ; load HL with start of array of rivets
        LD      A,B             ; A := B
        ADD     A,L             ; add #92
        LD      L,A             ; copy to L
        LD      A,(HL)          ; get the status of the rivet mario is crossing
        AND     A               ; has this rivet already been traversed?
        RET     Z               ; yes, return

; a rivet has been traversed

        LD      (HL),$00        ; set this rivet as cleared
        LD      HL,$6290        ; load HL with address of number of rivets remaining
        DEC     (HL)            ; decrease number of rivets
        LD      A,B             ; A := B
        LD      BC,$0005        ; load BC with offset of 5
        RRA                     ; rotate right.  carry?  (is this rivet on right side?)
        JP      C,$1ABD         ; yes, skip ahead and load HL with #012B and return to #1A95

        LD      HL,$02CB        ; else load HL with master offset for rivets

        AND     A               ; A == 0 ?
        JP      Z,$1A9E         ; yes, skip next 3 steps

        ADD     HL,BC           ; add offset to HL
        DEC     A               ; decrease A.  zero?
        JP      NZ,$1A99        ; no, loop again

        LD      BC,$7400        ; start of video RAM is #7400
        ADD     HL,BC           ; add offset computed based on which rivet is cleared
        LD      A,$10           ; A := #10 = clear space
        LD      (HL),A          ; erase the rivet
        DEC     L               ; next video memory
        LD      (HL),A          ; erase the top of the rivet
        INC     L               ;
        INC     L               ; next video memory
        LD      (HL),A          ; erase underneath the rivet [ not needed , there is nothing there to erase ???]
        LD      A,$01           ; A := 1
        LD      ($6340),A       ; store into #6340 - usually 0, changes when mario picks up bonus item. jumps over item turns to 1 quickly, then 2 until bonus disappears
        LD      ($6342),A       ; store into scoring indicator
        LD      ($6225),A       ; store into bonus sound indicator
        LD      A,($6216)       ; load A with jump indicator
        AND     A               ; is mario jumping ?
        CALL    Z,$1D95         ; no, play the bonus sound

        RET                     ; else return

; arrive from $1A8F above

        LD      HL,$012B        ; load HL with alternate master offset for rivets
        JP      $1A95           ; jump back to program and resume

; check for jumping and other movements
; called from main routine at $1980

        LD      A,($6216)       ; load A with jump indicator
        DEC     A               ; is mario already jumping?
        JP      Z,$1BB2         ; yes, jump ahead

        LD      A,($621E)       ; else load A with jump coming down indicator
        AND     A               ; is the jump almost done ?
        JP      NZ,$1B55        ; yes, skip way ahead

        LD      A,($6217)       ; load A with hammer check
        DEC     A               ; is hammer active?
        JP      Z,$1AE6         ; yes, skip ahead

        LD      A,($6215)       ; else load A with ladder check
        DEC     A               ; is mario on a ladder?
        JP      Z,$1B38         ; yes, skip ahead

        LD      A,(InputState)  ; load A with input
        RLA                     ; is player pressing jump ?
        JP      C,$1B6E         ; yes, begin jump subroutine

        CALL    $241F           ; else call this other sub which loads DE with something depending on mario's position.  ladder check?

        LD      A,(InputState)  ; load A with input
        DEC     E               ; E == 1 ?
        JP      Z,$1AF5         ; yes, jump ahead

        BIT     0,A             ; test bit 0 of input.  is player pressing right ?
        JP      NZ,$1C8F        ; yes, skip ahead

        DEC     D               ; else is D == 1 ?
        JP      Z,$1AFE         ; yes, skip ahead

        BIT     1,A             ; is player pressing left ?
        JP      NZ,$1CAB        ; yes, skip ahead

        LD      A,($6217)       ; else load A with hammer check
        DEC     A               ; is the hammer active?
        RET     Z               ; yes, return

        LD      A,($6205)       ; load A with Mario's Y position
        ADD     A,$08           ; Add 8
        LD      D,A             ; copy into D
        LD      A,($6203)       ; load A with Mario's X position
        OR      $03             ; turn on left 2 bits (0 and 1)
        RES     2,A             ; turn off bit 2
        LD      BC,$0015        ; load BC with #15 = number of ladders to check
        CALL    $236E           ; check for ladders nearby if none, RET to higher sub.  else A := 0 if at bottom of ladder, A := 1 if at top.  C has the ladder number/type?

; mario is near a ladder

        PUSH    AF              ; save AF for later
        LD      HL,$6207        ; load HL with movement indicator
        LD      A,(HL)          ; load movement
        AND     $80             ; mask bits
        OR      $06             ; mask bits
        LD      (HL),A          ; store movement
        LD      HL,$621A        ; load HL with ladder type address
        LD      A,$04           ; A := 4
        CP      C               ; compare.  is the ladder broken?
        LD      (HL),$01        ; store 1 into ladder type = broken ladder by default
        JP      NC,$1B2C        ; if ladder broken, skip next step

        DEC     (HL)            ; set indicator to unbroken ladder

        POP     AF              ; restore AF
        AND     A               ; A == 0 ?  is mario at bottom of ladder?
        JP      Z,$1B4E         ; yes, skip ahead

; else mario at top of ladder

        LD      A,(HL)          ; load A with broken ladder indicator
        AND     A               ; is this ladder broken?
        RET     NZ              ; yes, return.  we can't go down broken ladders

; top of unbroken ladder

        INC     L               ; next HL := #621B
        LD      (HL),D          ; store D
        INC     L               ; next HL := #621C
        LD      (HL),B          ; store B

; if mario is on a ladder
; jump here from $1ADC

        LD      A,(InputState)  ; load A with input
        BIT     3,A             ; is joystick pushed down ?
        JP      NZ,$1CF2        ; yes, skip ahead to handle

        LD      A,($6215)       ; load A with ladder status
        AND     A               ; is mario on a ladder?
        RET     Z               ; no, return

        LD      A,(InputState)  ; load A with input
        BIT     2,A             ; is joystick pushed up ?
        JP      NZ,$1D03        ; yes, skip ahead to handle

        RET                     ; else return

; mario is next to bottom of ladder

        INC     L               ; next HL := #621B
        LD      (HL),B          ; store B
        INC     L               ; next HL := #621C
        LD      (HL),D          ; store D
        JP      $1B45           ; loop back

        LD      HL,$621E        ; load HL with jump coming down indicator
        DEC     (HL)            ; decrease.  is it zero ?
        RET     NZ              ; no, return

; arrive here when jump is complete

        LD      A,($6218)       ; load A with hammer grabbing indicator
        LD      ($6217),A       ; store into hammer indicator
        LD      HL,$6207        ; load HL with movement indicator address
        LD      A,(HL)          ; load A with movement indicator
        AND     $80             ; mask bits.  we only care about bit 7, which we leave as is.  all other bits are now zero
        LD      (HL),A          ; store into movement indicator.  mario is no longer jumping
        XOR     A               ; A := 0
        LD      ($6202),A       ; set mario animation state to 0
        JP      $1DA6           ; jump ahead to update mario sprite and RET

; jump initiated.  arrive from $1AE3 when jump pressed and jump not already underway etc.

        LD      A,$01           ; A := 1
        LD      ($6216),A       ; set jump indicator
        LD      HL,$6210        ; load HL with mario's jump direction address
        LD      A,(InputState)  ; load A with copy of input
        LD      BC,$0080        ; B:= 0, C := #80 = codes for jumping right
        RRA                     ; rotate input right.  is joystick moved right ?
        JP      C,$1B8A         ; yes, skip ahead

; jumping left or straight up

        LD      BC,$FF80        ; B := #FF, C := #80 = codes for jumping left
        RRA                     ; rotate right again.  jumping to the left ?
        JP      C,$1B8A         ; yes, skip next step

; else jumping straight up

        LD      BC,$0000        ; B := 0, C := 0 = codes for jumping straight up

        XOR     A               ; A := 0
        LD      (HL),B          ; store B into #6210 = jump direction (0 = right, #FF = left, 0 = up)
        INC     L               ; HL := #6211
        LD      (HL),C          ; store C into jump direction indicator (#80 for left or right, 0 for up)
        INC     L               ; HL := #6212
        LD      (HL),$01        ; store 1 into this indicator ???
        INC     L               ; HL := #6213
        LD      (HL),$48
        INC     L               ; HL := #6214 (jump counter)
        LD      (HL),A          ; clear jump counter
        LD      ($6204),A
        LD      ($6206),A
        LD      A,($6207)       ; load movement indicator
        AND     $80             ; clear right 4 bits and leftmost bit
        OR      $0E             ; set right bits to E = 1110
        LD      ($6207),A       ; set jumping bits to indicate a jump in progress
        LD      A,($6205)       ; load A with Mario's Y position
        LD      ($620E),A       ; save mario's Y position when jump
        LD      HL,$6081        ; load HL with sound buffer address for jumping
        LD      (HL),$03        ; load sound buffer jumping sound for 3 units (3 frames?)
        RET                    ;ret to main routine (#1983)

; arrive here when mario is already jumping from #1AC7

        LD      IX,$6200        ; load IX with start of array for mario
        LD      A,($6203)       ; load A with mario's X position
        LD      (IX+$0B),A      ; store into +B
        LD      A,($6205)       ; load A with mario's Y position
        LD      (IX+$0C),A      ; store into +C = #620C = jump height
        CALL    $239C           ; handle jump stuff ?
        CALL    $241F           ; loads DE with something depending on mario's position
        DEC     D               ; D == 1 ?
        JP      NZ,$1BF2        ; no, skip ahead

; bounce mario off left side wall ?

        LD      (IX+$10),$00    ; clear jump direction
        LD      (IX+$11),$80    ; set +11 indicator to #80 (???)
        SET     7,(IX+$07)      ; set bit 7 of +7 = sprite used = make mario face the other way

        LD      A,($6220)       ; load A with falling too far indicator
        DEC     A               ; == 1 ? (falling too far?)
        JP      Z,$1BEC         ; yes, skip ahead

        CALL    $2407           ; ???
        LD      (IX+$12),H
        LD      (IX+$13),L
        LD      (IX+$14),$00    ; clear the +14 indicator (???)

        CALL    $239C           ; ???
        JP      $1C05           ; skip ahead

        DEC     E               ; decrease E.  at zero ?
        JP      NZ,$1C05        ; no, skip ahead

; bounce mario off right side wall ?

        LD      (IX+$10),$FF    ; set jump direction to left
        LD      (IX+$11),$80    ; set +11 indicator to #80
        RES     7,(IX+$07)      ; reset bit 7 of +7 = sprite used = makes mario face the other way
        JP      $1BD8           ; jump back to program

        CALL    $2B1C           ; do stuff for jumping, load A with landing indicator ?
        DEC     A               ; decrease A.  mario landing ?
        JP      Z,$1C3A         ; yes, skip ahead to handle

        LD      A,($621F)       ; else load A with #621F = 1 when mario is at apex or on way down after jump, 0 otherwise.
        DEC     A               ; decrease A.  at zero ?  is mario at apex or on way down ?
        JP      Z,$1C76         ; yes, skip ahead

        LD      A,($6214)       ; load A with jump counter
        SUB     $14             ; == #14 ? (apex of jump)
        JP      NZ,$1C33        ; no, skip ahead

; mario at apex of jump ?

        LD      A,$01           ; A := 1
        LD      ($621F),A       ; store into #621F = 1 when mario is at apex or on way down after jump, 0 otherwise.
        CALL    $2853           ; check for items under mario
        AND     A               ; was an item jumped?
        JP      Z,$1DA6         ; no, jump ahead to update mario sprite and RET

; an item was jumped

        LD      ($6342),A       ; yes, barrel has been jumped, set for later use
        LD      A,$01           ; A := 1
        LD      ($6340),A       ; store into #6340 - usually 0, changes when mario picks up bonus item. jumps over item turns to 1 quickly, then 2 until bonus disappears
        LD      ($6225),A       ; store into bonus sound indicator

        NOP                     ; No operation [what was here ???]

; can arrive from $1C18

        INC     A               ; increase A.  Will turn to zero 1 pixel before apex of jump
        CALL    Z,$2954         ; if zero, call this sub to check for hammer grab

        JP      $1DA6           ; jump ahead to update mario sprite and RET

; arrive here when mario lands.  B is preloaded with a parameter

        DEC     B               ; B == 1 ?
        JP      Z,$1C4F         ; if so, skip ahead

        INC     A               ; increase A
        LD      ($621F),A       ; store into #621F = 1 when mario is at apex or on way down after jump, 0 otherwise.
        XOR     A               ; A := 0
        LD      HL,$6210        ; load HL with jump direction
        LD      B,$05           ; for B := 1 to 5

        LD      (HL),A          ; clear this memory (jump direction, etc)
        INC     L               ; next HL
        DJNZ    $1C48           ; next B

        JP      $1DA6           ; jump ahead to update mario sprite and RET

; jump almost complete ...

        LD      ($6216),A       ; store A into jump indicator
        LD      A,($6220)       ; load A with falling too far indicator
        XOR     $01             ; toggle rightmost bit [ change to LD A, #01 to enable infinite falling without death]
        LD      ($6200),A       ; store into mario life indicator.  if mario fell too far, he will die.
        LD      HL,$6207        ; load HL with address of movement indicator
        LD      A,(HL)          ; load A with movement indicator
        AND     $80             ; maks bits, leave bit 7 as is.  all other bits are zeroed.
        OR      $0F             ; turn on all 4 low bits
        LD      (HL),A          ; store result into movement indicator
        LD      A,$04           ; A := 4
        LD      ($621E),A       ; store into jump coming down indicator
        XOR     A               ; A := 0
        LD      ($621F),A       ; store into #621F = 1 when mario is at apex or on way down after jump, 0 otherwise.
        LD      A,($6225)       ; load A with bonus sound indicator
        DEC     A               ; was a bonus awarded?
        CALL    Z,$1D95         ; yes, call this sub to play bonus sound

        JP      $1DA6           ; jump ahead to update mario sprite and RET

; mario is on way down from jump or falling

        LD      A,($6205)       ; load A with mario's Y position
        LD      HL,$620E        ; load HL with mario original Y position ?
        SUB     $0F             ; subtract #F
        CP      (HL)            ; compare.  is mario falling too far ?
        JP      C,$1DA6         ; no, jump ahead to update mario sprite and RET

; mario falling too far on a jump

        LD      A,$01           ; A := 1
        LD      ($6220),A       ; store into falling too far indicator
        LD      HL,$6084        ; load HL with address for falling sound
        LD      (HL),$03        ; play falling sound for 3 units
        JP      $1DA6           ; jump ahead to update mario sprite and RET

; arrive here when joystick is being pressed right

        LD      B,$01           ; B := 1 = movement to right
        LD      A,($620F)       ; load A with movement indicator
        AND     A               ; time to move mario ?
        JP      NZ,$1CD2        ; yes, jump ahead

        LD      A,($6202)       ; varies from 0, 2, 4, 1 when mario is walking left or right
        LD      B,A             ; copy into B. this is used in sub at #3009 called below
        LD      A,$05           ; A := 5
        CALL    $3009           ; ??? change A depending on where mario is?
        LD      ($6202),A       ; put back
        AND     $03             ; mask bits, now between 0 and 3
        OR      $80             ; turn on bit 7
        JP      $1CC2           ; skip ahead

; arrive here when joystick is being pressed left

        LD      B,$FF           ; B := #FF = -1 (movement to left)
        LD      A,($620F)       ; load A with movement indicator
        AND     A               ; time to move mario?
        JP      NZ,$1CD2        ; yes, skip ahead and move mario

        LD      A,($6202)       ; varies from 0, 2, 4, 1 when mario is walking left or right
        LD      B,A             ; copy to B.  this is used in sub at #3009 called below
        LD      A,$01           ; A := 1
        CALL    $3009           ; ??? change A depending on where mario is?
        LD      ($6202),A       ; put back
        AND     $03             ; mask bits. now between 0 and 3

        LD      HL,$6207        ; load HL with mario movement indicator/sprite value
        LD      (HL),A          ; store A into this
        RRA                     ; rotate right.  is A odd?
        CALL    C,$1D8F         ; yes , skip ahead to start walking sound and RET

        LD      A,$02           ; A := 2
        LD      ($620F),A       ; store into movement indicator (reset)
        JP      $1DA6           ; jump ahead to update mario sprite and RET

        LD      HL,$6203        ; load HL with mario X position address
        LD      A,(HL)          ; load A with mario X position
        ADD     A,B             ; add movement (either 1 or #FF)
        LD      (HL),A          ; store new result
        LD      A,($6227)       ; load A with screen number
        DEC     a               ; are we on the girders?
        JP      NZ,$1Ceb        ; no, skip ahead

        LD      h,(HL)          ; else load H with mario X position
        LD      A,($6205)       ; load A with mario Y position
        LD      l,A             ; copy to L.  HL now has mario X,Y
        CALL    $2333           ; check for movement up/down a girder, might also change Y position ?
        LD      A,l             ; load A with new Y position
        LD      ($6205),A       ; store into Y position

        LD      HL,$620F        ; load HL with address of movement indicator
        DEC     (HL)            ; decrease movement indicator
        JP      $1DA6           ; jump ahead to update mario sprite and RET

; mario moving down on a ladder
; jump here from $1B3D

        LD      A,($620F)       ; load A with movmement indicator (from 3 to 0)
        AND     A               ; == 0 ?
        JP      NZ,$1D8A        ; no, skip ahead, decrease indicator and return

; ok for mario to move

        LD      A,$03           ; A := 3
        LD      ($620F),A       ; reset movement indicator to 3
        LD      A,$02           ; A := 2 pixels to move down
        JP      $1D11           ; skip ahead

; mario moving up on a ladder
; jump here from #1B4A

        LD      A,($620F)       ; load A with movement indicator (from 4 to 0)
        AND     A               ; time to move mario ?
        JP      NZ,$1D76        ; no, skip ahead

        LD      A,$04           ; A := 4
        LD      ($620F),A       ; reset movement indicator to 4 (slower movement going up)
        LD      A,$FE           ; A := #FE = -2 pixels movement

        LD      HL,$6205        ; load HL with mario Y position address
        ADD     A,(HL)          ; add A to Y position
        LD      (HL),A          ; store result into Y position
        LD      B,A             ; copy to B
        LD      A,($6222)       ; load A with ladder toggle
        XOR     $01             ; toggle the bit
        LD      ($6222),A       ; store.  is it zero?
        JP      NZ,$1D51        ; no, skip ahead

        LD      A,B             ; A := B =  mario Y position
        ADD     A,$08           ; add 8 [offset for mario's actual position ???]
        LD      HL,$621C        ; load HL with Y value of top of ladder
        CP      (HL)            ; is mario at top of ladder ?
        JP      Z,$1D67         ; yes, skip ahead to handle

        DEC     L               ; HL := #621B = Y value of bottom of ladder
        SUB     (HL)            ; is mario at bottom of ladder ?
        JP      Z,$1D67         ; yes, skip ahead to handle

        LD      B,$05           ; B := 5
        SUB     $08             ; subtract 8.  zero?
        JP      Z,$1D3F         ; yes, skip next 4 steps

        DEC     B               ; B := 4
        SUB     $04             ; subtract 4.  zero?
        JP      Z,$1D3F         ; yes, skip next step

        DEC     B               ; B := 3

        LD      A,$80           ; A := #80
        LD      HL,$6207        ; load HL with address of mario movement indicator/sprite value
        AND     (HL)            ; mask bits with movement
        XOR     $80             ; toggle bit 7
        OR      B               ; turn on bits based on ladder position
        LD      (HL),A          ; store into mario movement indicator/sprite value

        LD      A,$01           ; A := 1
        LD      ($6215),A       ; store into ladder status.  mario is on a ladder now
        JP      $1DA6           ; jump ahead to update mario sprite and RET

        DEC     L
        DEC     L               ; HL := #6203
        LD      A,(HL)          ; load A with mario sprite value
        OR      $03             ; turn on bits 0 and 1
        RES     2,A             ; clear bit 2
        LD      (HL),A          ; store into mario sprite
        LD      A,($6224)       ; load A with sound alternator
        XOR     $01             ; toggle bit 0
        LD      ($6224),A       ; store result
        CALL    Z,$1D8F         ; if zero, play walking sound for moving on ladder

        JP      $1D49           ; jump back

; arrive from $1D29 when mario at top or bottom of ladder

        LD      A,$06           ; A := 6
        LD      ($6207),A       ; store into mario movement indicator/sprite value
        XOR     A               ; A := 0
        LD      ($6219),A       ; clear this status indicator
        LD      ($6215),A       ; clear ladder status.  mario no longer on ladder
        JP      $1DA6           ; jump ahead to update mario sprite and RET

; jump here from $1D07 when going up a ladder but not actually moving

        LD      A,($621A)       ; load A with this indicator.  set when mario is on moving ladder or broken ladder
        AND     A               ; is mario boarding or on a retracting or broken ladder?
        JP      Z,$1D8A         ; no, skip ahead

; mario on or moving onto a rectracting or broken ladder

        LD      ($6219),A       ; store 1 into status indicator
        LD      A,($621C)       ; load A with Y value of top of ladder
        SUB     $13             ; subtract #13
        LD      HL,$6205        ; load HL with mario Y position address
        CP      (HL)            ; is mario at or above the top of ladder ?
        RET     NC              ; yes, return without changing movement

        LD      HL,$620F        ; else load HL with address of movement indicator
        DEC     (HL)            ; decrease
        RET

; mario is walking

        LD      A,$03           ; load sound duration of 3 for walking
        LD      ($6080),A       ; store into walking sound buffer
        RET

; arrive here when walking over a rivet, not jumping.  from #1AB9, or from #1C70

        LD      ($6225),A       ; store A into bonus sound indicator.  A is zero so this clears the indicator
        LD      A,($6227)       ; load A with screen number
        DEC     A               ; is this the girders?
        RET     Z               ; yes , then return, we don't play this sound for the girders

; play bonus sound

        LD      HL,$608A        ; else load HL with sound address
        LD      (HL),$0D        ; play bonus sound
        INC     L               ; HL := #608B = sound duration
        LD      (HL),$03        ; set sound duration to 3
        RET

; update mario sprite

        LD      HL,$694C        ; load HL with mario sprite X position
        LD      A,($6203)       ; load A with mario's X position
        LD      (HL),A          ; store into hardware sprite mario X position
        LD      A,($6207)       ; load A with movement indicator
        INC     L               ; HL := #694D = hardware mario sprite
        LD      (HL),A          ; store into hardware mario sprite value
        LD      A,($6208)       ; load A with mario color
        INC     L               ; HL := #694E = hardware mario sprite color
        LD      (HL),A          ; store into mario sprite color
        LD      A,($6205)       ; load A with mario Y position
        INC     L               ; HL := #694F = mario sprite Y position
        LD      (HL),A          ; store into mario sprite Y position
        RET


; called from main routine at $197A
; also called from other areas


        LD      A,($6340)       ; load A with #6340 - usually 0, changes when mario picks up bonus item. jumps over item turns to 1 quickly, then 2 until bonus disappears
        RST     $28             ; jump based on A

        hex     49 1E           ; #1E49 = no item.  returns immediately
        hex     C9 1D           ; #1DC9 = item just picked up
        hex     4A 1E           ; #1E4A = bonus appears
        hex     00 00           ; unused

; an item was just picked up / jumped over / hit with hammer

        LD      A,$40           ; A := #40
        LD      ($6341),A       ; store into timer
        LD      A,$02           ; A := 2
        LD      ($6340),A       ; store into #6340 - usually 0, changes when mario picks up bonus item. jumps over item turns to 1 quickly, then 2 until bonus disappears
        LD      A,($6342)       ; load A with scoring indicator
        RRA                     ; roll right.  is this a jumped item?
        JP      C,$3E70         ; yes, award points for jumping items [ patch ? orig code had JP C,#1E25 ??? ]

        RRA                     ; else roll right
        JP      C,$1E00         ; award for hitting regular barrel with hammer

        RRA                     ; roll right.  hit blue barrel with hammer?
        JP      C,$1Df5         ; yes, skip ahead to handle

; else it was a bonus item pickup

        LD      HL,$6085        ; else load HL with bonus sound address
        LD      (HL),$03        ; play bonus sound for 3 duration
        LD      A,($6229)       ; load A with level #
        DEC     A               ; decrease A.  is this level 1 ?
        JP      Z,$1E00         ; yes, jump ahead for 300 pts

        DEC     A               ; else is this level 2 ?
        JP      Z,$1E08         ; yes, award 500 pts

        JP      $1E10           ; else award 800 pts

; blue barrel hit with hammer

        LD      A,(RngTimer1)   ; load timer, a psuedo random number
        RRA                     ; roll right = 50% chance of 500 points
        JP      C,$1E08         ; award 500 points

        RRA                     ; roll right again, gives overall 25% chance of 800 points
        JP      C,$1E10         ; award 800 points

; else award 300 points

        LD      B,$7D           ; set sprite for 300 points
        LD      DE,$0003        ; set points at 300
        JP      $1E15           ; award points

; award 500 pts

        LD      B,$7E           ; set sprite for 500 points
        LD      DE,$0005        ; set points at 500
        JP      $1E15           ; award points

; award 800 pts

        LD      B,$7f           ; set sprite for 800 points
        LD      DE,$0008        ; set points at 800

        CALL    $309f           ; insert task to add score

; arrive here when bonus item picked up or smashed with hammer

        LD      HL,($6343)      ; load HL with contents of #6343 , this gives the address of the sprite location
        LD      A,(HL)          ; load A with the X position of the sprite in question
        LD      (HL),$00        ; clear the sprite from the screen
        INC     l               ; increase L 3 times
        INC     l               ;
        INC     l               ;
        LD      c,(HL)          ; load C with the Y position of the item
        JP      $1E36           ; jump ahead


        LD      DE,$0001        ; load task for scoring, 100 pts [ never arrive at this line ??? possibly orig code came from #1DD7 ]

;___________________________________________________________________

; arrive when barrel has been jumped for points from #3E70 range
; DE is preloaded with task for scoring 100, 300, or 500 pts [bug, should be 800 pts]
;
;
;        ; award points for jumping a barrels and items
;        ; arrive from #1DD7
;        ; A is preloaded with 1,3, or 7
;        ; patch ?
;
;        3E70  110100    LD      DE,#0001        ; 100 points
;        3E73  067B      LD      B,#7B           ; sprite for 100
;        3E75  1F        RRA                     ; is the score set for 100 ?
;        3E76  D2281E    JP      NC,#1E28        ; yes, award points
;
;        3E79  1E03      LD      E,#03           ; else set 300 points
;        3E7B  067D      LD      B,#7D           ; sprite for 300
;        3E7D  1F        RRA                     ; is the score set for 300 ?
;        3E7E  D2281E    JP      NC,#1E28        ; yes, award points
;
;        3E81  1E05      LD      E,#05           ; else set 500 points [bug, should be 800]
;        3E83  067F      LD      B,#7F           ; sprite for 800
;        3E85  C3281E    JP      #1E28           ; award points
;
;___________________________________________________________________

        CALL    $309F           ; insert task to add score
        LD      A,($6205)       ; load A with Mario's Y position
        ADD     A,$14           ; add #14
        LD      C,A             ; store into C
        LD      A,($6203)       ; load A with mario's X position

        NOP
        NOP                     ; [ what used to be here?  was it LD B,#7B to set sprite for 100 pts? ]

; draw the bonus score on the screen

        LD      HL,$6A30        ; load HL with scoring sprite start
        LD      (HL),A          ; store X position
        INC     L               ; next location
        LD      (HL),B          ; store sprite graphic
        INC     L               ; next
        LD      (HL),$07        ; store color code 7
        INC     L               ; next
        LD      (HL),C          ; store Y position
        LD      A,$05           ; A := 5 = binary 0101
        RST     $30             ; only allow continue on girders and elevators, others do RET here [no bonus sound for killing firefox with hammer]
        LD      HL,$6085        ; load HL with bonus sound address
        LD      (HL),$03        ; play bonus sound for 3 duration
        RET

; arrive here from $1DC0 when bonus appears

        LD      HL,$6341        ; load HL with timer
        DEC     (HL)            ; has it run out yet ?
        RET     NZ              ; no, return

        XOR     A               ; else A := 0
        LD      ($6A30),A       ; clear this
        LD      ($6340),A       ; clear this
        RET

; called from main routine at $19B9
; checks for end of level ?

        LD      A,($6227)       ; load a with screen number
        BIT     2,A             ; are we on the rivets?
        JP      NZ,$1E80        ; yes, skip ahead to handle

        rra                     ; else rotate right with carry
        LD      A,($6205)       ; load A with y position of mario
        JP      c,$1E7A         ; skip ahead on girders and elevators

        CP      $51             ; else on the conveyors.  is mario high enough to end level?
        RET     nc              ; no, return

        LD      A,($6203)       ; else load A with mario's X position
        RLA                     ; on left or right side of screen?

        LD      A,$00           ; load A with #00.  sprite for facing left
        JP      C,$1E74         ; if on left side, skip next step

        LD      A,$80           ; else load A with sprite facing right
        LD      ($694D),A       ; set mario sprite
        JP      $1E85           ; jump ahead

; check for end of level on girders and elevators

        CP      $31             ; are we on top level (rescued girl?)
        RET     NC              ; no, return

        JP      $1E6D           ; level has been fished.  jump to end of level routine.

; arrive here when on rivets

        LD      A,($6290)       ; load A with number of rivets left
        AND     A               ; all done with rivets ?
        RET     NZ              ; no, return

        LD      A,$16           ; else A := #16
        LD      (GameMode2),A       ; store into game mode2
        POP     HL              ; pop stack to get higher address
        RET                     ; ret to a higher level [returns to #00D2]

; called from main routine at $197D
; handles items hit with hammer

        LD      A,($6350)       ; load A with hammer hit item indicator
        AND     A               ; is an item being smashed ?
        RET     Z               ; no, return

        CALL    $1E96           ; else call sub below
        POP     HL              ; then return to a higher sub
        RET                     ; rets to #00D2

        LD      A,($6345)       ; load A with this

; $6345 - usually 0.  changes to 1, then 2 when items are hit with the hammer

        RST     $28             ; jump based on A

        hex    A0 1E            ; 0       #1EA0
        hex    09 1F            ; 1       #1F09
        hex    23 1F            ; 2       #1F23

; arrive right when an item is hit

        LD      A,($6352)       ; load A with ???
        CP      $65             ; == #65 ?
        LD      HL,$69B8        ; load HL with sprites for pies
        JP      Z,$1EB4         ; yes, skip next 3 steps

        LD      HL,$69D0        ; load HL with start of fire sprites ???
        JP      C,$1EB4         ; if carry, then skip next step

        LD      HL,$6980        ; HL is X position of a barrel

        LD      IX,($6351)      ; load IX with start of item array for the item hit
        LD      D,$00           ; D := 0
        LD      A,($6353)       ; load A with the offset for each item in the array
        LD      E,A             ; copy to E.  DE now has the offset
        LD      BC,$0004        ; BC := 4
        LD      A,($6354)       ; load A with the index of the item hit
        AND     A               ; == 0 ?
        JP      Z,$1ECF         ; yes, skip ahead, we use the default HL and IX

        ADD     HL,BC           ; add offset
        ADD     IX,DE           ; add offset
        DEC     A               ; decrease counter.  done ?
        JP      NZ,$1EC8        ; no, loop again

        LD      (IX+$00),$00    ; set this sprite as no longer active
        LD      A,(IX+$15)      ; load A with +15 (0 = normal barrel,  1 = blue barrel, see next comments)

;___________________________________________________________________
;
; It turns out that IX+15 is used by firefoxes and fireballs as a counter for their animation
; This value can be 0, 1, or 2 and is updated every frame
;
; For pies, this value is 0, $7C or #CC, because it grabs the +5 slot of the next pie when one is hit
;
;___________________________________________________________________

        AND     A               ; ==0 ? is this a regular barrel?  (sometimes fires and pies fall here too)
        LD      A,$02           ; A := 2, used for 300 pts
        JP      Z,$1EDE         ; yes, skip next step

        LD      A,$04           ; else A := 4, used for random points (blue barrel, sometimes fire, sometimes pie)

        LD      ($6342),A       ; store A into scoring indicator
        LD      BC,$6A2C        ; load BC with scoring sprite address
        LD      A,(HL)          ; load A with sprite value ?
        LD      (HL),$00        ; clear the sprite that was hit
        LD      (BC),A          ; store sprite value into the scoring sprite
        INC     C               ; next
        INC     L               ; next
        LD      A,$60           ; A := #60 = sprite for large bluewhite circle
        LD      (BC),A          ; store into sprite graphic
        INC     C               ; next
        INC     L               ; next
        LD      A,$0C           ; A := #0C = color code
        LD      (BC),A          ; store into sprite color
        INC     C               ; next
        INC     L               ; next
        LD      A,(HL)          ; load A with Y value for sprite hit
        LD      (BC),A          ; store into Y value for scoring sprite
        LD      HL,$6345        ; load HL with item hit phase counter address

; $6345 - usually 0.  changes to 1, then 2 when items are hit with the hammer
; item has been hit by hammer

        INC     (HL)            ; increase the item hit phase counter
        INC     L               ; HL := #6346 = a timer used for hammering items?
        LD      (HL),$06        ; set timer to 6
        INC     L               ; HL := #6347 = counter for number of times to change between circle and small circle
        LD      (HL),$05        ; set to 5
        LD      HL,$608A        ; load HL with sound buffer address
        LD      (HL),$06        ; play sound for hammering object
        INC     L               ; HL := 608B = sound duration
        LD      (HL),$03        ; set duration to 3
        RET

; item has been hit by hammer , phase 2 of 3

        LD      HL,$6346        ; load HL with timer
        DEC     (HL)            ; count down.  zero ?
        RET     NZ              ; no, return

        LD      (HL),$06        ; else reset counter to 6
        INC     L               ; HL := #6347 = counter for this function
        DEC     (HL)            ; decrease counter.  zero?
        JP      Z,$1F1D         ; yes, skip ahead

        LD      HL,$6A2D        ; else load HL with scoring sprite graphic
        LD      A,(HL)          ; get value
        XOR     $01             ; toggle bit 0 = change sprite to small circle or back again
        LD      (HL),A          ; store
        RET

        LD      (HL),$04        ; store 4 into #6347 = timer?
        DEC     L               ;
        DEC     L               ; HL := #6345
        INC     (HL)            ; increase item hit phase counter
        RET

; arrive from jump at $1E99 when an item is hit with hammer (last step of 3)

        LD      HL,$6346        ; load HL with timer?
        DEC     (HL)            ; count down.  zero ?
        RET     NZ              ; no, return

        LD      (HL),$0C        ; reset counter to #C
        INC     L               ; HL := #6347 = counter
        DEC     (HL)            ; decrease counter.  zero?
        JP      Z,$1F34         ; yes, skip ahead

        LD      HL,$6A2D        ; no, load HL with sprite graphic
        INC     (HL)            ; increase
        RET

        DEC     L
        DEC     L               ; HL := 6345
        XOR     A               ; A := 0
        LD      (HL),A          ; store into HL.  reset the item being hit with hammer
        LD      ($6350),A       ; store into item hit indicator
        INC     A               ; A := 11:18 AM 6/15/2009
        LD      ($6340),A       ; store into bonus indicator
        LD      HL,$6A2C        ; load HL with location of item hit
        LD      ($6343),HL      ; store into #6343 for use later
        RET

; called from main routine at $19A4

        LD      A,($6221)       ; load A with falling indicator.  also set when mario lands from jumping off elevator
        AND     A               ; is mario falling?
        RET     Z               ; no, return

; mario is falling

        XOR     A               ; A := 0
        LD      (#6204),A
        LD      (#6206),A
        LD      ($6221),A       ; clear mario falling indicator
        LD      ($6210),A       ; clear jump direction
        LD      (#6211),A
        LD      ($6212),A       ; clear this indicator (???)
        LD      (#6213),A
        LD      ($6214),A       ; clear jump counter
        INC     A               ; A := 1
        LD      ($6216),A       ; set jump indicator
        LD      ($621F),A       ; set #621F = 1 when mario is at apex or on way down after jump, 0 otherwise.
        LD      A,($6205)       ; load A with ???
        LD      ($620E),A       ; store into ???
        RET

; called from main routine at $1983
; used to roll barrels

        LD      A,($6227)       ; load a with screen number
        DEC     a               ; is this the girders ?
        RET     NZ              ; no, return

; yes, we are on girders
; this subroutine checks the barrels, if any are rolling it does something, otherwise returns

        LD      IX,$6700        ; load IX with start of barrel array
        LD      HL,$6980        ; load HL with start of sprites used for barrels
        LD      DE,$0020        ; load DE with offset of #20.  used for checking next barrel
        LD      B,$0A           ; for B = 1 to #0A ( do for each barrel)

        LD      A,(IX+$00)      ; Load A with Barrel indicator (0 = no barrel, 2 = being deployed, 1=rolling)
        DEC     A               ; Is this barrel rolling ?
        JP      Z,$1F93         ; Yes, jump ahead

        INC     L               ; otherwise increase L by 4
        INC     L
        INC     L
        INC     L
        ADD     IX,DE           ; Add offset to check for next barrel
        DJNZ    $1F83           ; Next B

        RET

        LD      A,(IX+$01)      ; Load Crazy Barrel indicator
        DEC     A               ; is this a crazy barrel?
        JP      Z,$20EC         ; Yes, jump ahead

        LD      A,(IX+$02)      ; no load A with next indicator - determines the direction of the barrel
        RRA                     ; Is this barrel going down a ladder?
        JP      C,$1FAC         ; Yes, jump away to ladder sub.

        RRA                     ; Is this barrel moving right?
        JP      C,$1FE5         ; yes, jump away to move right sub.

        RRA                     ; is this barrel moving left?
        JP      C,$1FEF         ; yes, jump to moving left sub

        JP      $2053           ; else jump ahead

; arrived here because the barrel is going down a ladder from #1F9E

        EXX                     ; exchange HL, DE, and BC with their clones
        INC     (IX+$05)        ; increase the barrels Y position ( move it down)
        LD      A,(IX+$17)      ; load A with the bottom Y location of the ladder we are on

; $6717 = bottom position of next ladder it is going down or the ladder it just passed.
; ladders bottoms are at :  70, 6A, 93, 8D, 8B, B3, B0, AC, D1, CD, F3, EE

        CP      (IX+$05)        ; check against item's Y position.  are we at the bottom of this ladder?
        JP      NZ,$1FCE        ; no, jump ahead

; barrel reached bottom of ladder

        LD      A,(IX+$15)      ; load A with Barrel #15 indicator, zero = normal barrel,  1 = blue barrel
        RLCA                    ; roll left twice (multiply by 4)
        RLCA
        ADD     A,$15           ; add #15
        LD      (IX+$07),A      ; store into +7 indicator = sprite used

; $6707 - right 2 bits are 01 when rolling, 10 when being deployed.  bit 7 toggles as it rolls

        LD      A,(IX+$02)      ; load A with direction of barrel
        XOR     $07             ; XOR right 3 bits - reverses direction ?
        LD      (IX+$02),A      ; store back in direction
        JP      $21BA           ; jump ahead

; we arrived here because we are not at the bottom of the ladder
; animates barrel as it rolls down ladder?

        LD      A,(IX+$0F)      ; load A with barrel #0F counter (from 4 to 1)
        DEC     A               ; decrement, has it reached 0?
        JP      NZ,$1FDF        ; No, jump ahead, store into counter and continue on

; else animate the barrel

        LD      A,(IX+$07)      ; yes, Load A with #07 indicator = sprite used
        XOR     $01             ; toggle bit 1
        LD      (IX+$07),A      ; store back in #07 indicator = toggle sprite
        LD      A,$04           ; A := 4

        LD      (IX+$0F),A      ; store A into barrel #0F counter (from 4 to 1)
        JP      $21BA           ; jump ahead

; we arrived here because the barrel is moving to the right

        EXX                     ; exchange HL, DE, and BC with their clones
        LD      BC,$0100        ; BC := #0100
        INC     (IX+$03)        ; Increase Barrel's X posiition
        JP      $1FF6           ; jump ahead

; we arrived here because the barrel is moving to the left

        EXX                     ; exchange HL, DE, and BC with their clones
        LD      BC,$FF04        ; load BC with #FF04
        DEC     (IX+$03)        ; decrease barrel's X position

; we are here becuase the barrel is moving either left or right

        LD      H,(IX+$03)      ; load H with barrel's X position
        LD      L,(IX+$05)      ; load L with barrel's Y position
        LD      A,H             ; load A with barrel's X position
        AND     $07             ; mask left 5 bits to zero.  result is between 0 and 7
        CP      $03             ; compare with #03
        JP      Z,$215F         ; equal to #03, jump ahead to check for ladders ?

        DEC     L               ; otherwise decrease L 3 times
        DEC     L
        DEC     L
        CALL    $2333           ; check for barrel going down a slanted girder ?
        INC     L               ; increase L back to what it was
        INC     L
        INC     L
        LD      A,L             ; Load A with Barrel's Y position
        LD      (IX+$05),A      ; store back into barrel's y position
        CALL    $23DE           ;
        CALL    $24B4           ;
        LD      A,(IX+$03)      ; Load A with Barrels' X position
        CP      $1C             ; have we arrived at left edge of girder?
        JP      C,$202F         ; yes, jump ahead to handle

        CP      $E4             ; else , have we arrived at right edge of girder?
        JP      C,$21BA         ; no, jump way ahead - we're done, store values and try next barrel

; right edge of girder

        XOR     A               ; A := 0
        LD      (IX+$10),A      ; clear #10 barrel index to 0
        LD      (IX+$11),$60    ; store #60 into barrel +#11  , indicates a roll over the right edge
        JP      $2038           ; skip next 3 steps

; arrive here when barrel at left edge of girder

        XOR     A               ; A := 0
        LD      (IX+$10),$FF    ; Set Barrel #10 index with #FF
        LD      (IX+$11),$A0    ; set barrel #11 index with #A0 - indicates a roll over left edge

        LD      (IX+$12),$FF    ;
        LD      (IX+$13),$F0    ;
        LD      (IX+$14),A      ;
        LD      (IX+$0E),A      ; clear the barrel's edge indicator
        LD      (IX+$04),A      ; clear ???
        LD      (IX+$06),A      ;
        LD      (IX+$02),$08    ; load barrel properties with various numbers to indicate edge roll?
        JP      $21BA           ; jump way ahead - we're done, store values and try next barrel

; jump from #1FA9
; we arrive here because the barrel isn't going left, right, or down a ladder
; could be crazy barrel or barrel going over edge

        EXX                     ; Exchange DE, HL, BC with counterparts
        CALL    $239C           ; update barrel position ?
        CALL    $2A2F           ; ???  set A to zero or 1 depending on ???
        AND     A               ; iS A == 0 ?
        JP      NZ,$2083        ; no, jump ahead

        LD      A,(IX+$03)      ; load A with barrel X position
        ADD     A,$08           ; Add #08
        CP      $10             ; compare with #10
        JP      C,$2079         ; If carry, jump ahead, clear barrel, (rolled off screen?)

        CALL    $24B4           ; check for barrel running into oil can?
        LD      A,(IX+$10)      ; load A with +10 = rolling over edge / direction indicator
        AND     $01             ; mask all bits but 1.  result is 0 or 1
        RLCA                    ; rotate left
        RLCA                    ; rotate left again.  result is 0 or 4
        LD      C,A             ; copy into C
        CALL    $23DE           ; ???
        JP      $21BA           ; skip ahead

        XOR     A               ; A := 0
        LD      (IX+$00),A      ; clear barrel active indicator
        LD      (IX+$03),A      ; clear barrel X position
        JP      $21BA           ; done, store values and try next barrel

; barrel has landed on a new girder after going over edge, or has just done so and is bouncing

        INC     (IX+$0E)        ; increase +E (???)
        LD      A,(IX+$0E)      ; load A with this value
        DEC     A               ; decrease.  zero? (did this barrel just land???)
        JP      Z,$20A2         ; yes, skip ahead

        DEC     A               ; else decrease again.  zero?
        JP      Z,$20C3         ; yes, skip ahead

; barrel has finsished its edge maneuever

        LD      A,(IX+$10)      ; else load A with +10 = rolling over edge/direction indicator
        DEC     A               ; decrease.  was this value a 1 ?  (barrel moving right)
        LD      A,$04           ; A := 4 = rolling left code
        JP      NZ,$209C        ; no, skip next step

        LD      A,$02           ; else A := 2

        LD      (IX+$02),A      ; store into motion indicator.  02 = rolling right, 08 = rolling down, 04 = rolling left, bit 1 set when rolling down ladder
        JP      $21BA           ; jump ahead

; barrel has landed on a new girder after going over edge

        LD      A,(IX+$15)      ; load A with Barrel #15 indicator, zero = normal barrel,  1 = blue barrel
        AND     A               ; is this a blue barrel?
        JP      NZ,$20B5        ; yes, skip ahead, blue barrels always continue all the way down

; normal barrel traversed edge

        LD      HL,$6205        ; load HL with mario's Y position address
        LD      A,(IX+$05)      ; load A with +5 = barrel's Y position
        SUB     $16             ; subtract #16
        CP      (HL)            ; compare to mario Y position.  is the barrel below mario?
        JP      NC,$20C3        ; yes, skip next 5 steps

        LD      A,(IX+$10)      ; load A with +10 = rolling over edge/direction indicator
        AND     A               ; A == 0 ? is this barrel is rolling right?
        JP      NZ,$20E1        ; no, skip ahead and set alternate values, continue at #20C3

        LD      (IX+$11),A      ; else set +11 (???) to zero
        LD      (IX+$10),$FF    ; set +10 = rolling over edge indicator to #FF for rolling left

; barrel has just finished bouncing after going around ledge

        CALL    $2407           ; ???
        SRL     H
        RR      L
        SRL     H
        RR      L
        LD      (IX+$12),H      ; store H into +#12 (???)
        LD      (IX+$13),L      ; store L into +#13 (???)
        XOR     A               ; A := 0
        LD      (IX+$14),A      ; clear +#14 (???)
        LD      (IX+$04),A      ; clear +#4 (???)
        LD      (IX+$06),A      ; clear +#6 (???)
        JP      $21BA           ; skip ahead

        LD      (IX+$10),$01    ; set +10 = rolling over edge indicator to 1 for rolling right
        LD      (IX+$11),$00    ; set +11 = ??? to 0
        JP      $20C3           ; jump back

; we arrived here because its a crazy barrel from #1F97
; this is called for every pixel the barrel moves

        EXX                     ; exchange BC, DE, and HL with their alternates
        CALL    $239C           ; update Barrel's variables ?. H now has +5 and L has +6
        LD      A,H             ; Load A with H = +5 = Y position
        SUB     $1A             ; Subtract #1A (26 decimal)
        LD      B,(IX+$19)      ; load B with Barrel status #19 (?)
        CP      B               ; compare A with B
        JP      C,$2104         ; jump on carry ahead

        CALL    $2A2F           ; else call this sub (???)
        AND     A               ; is A == 0 ?
        JP      NZ,$2118        ; No, jump ahead

        CALL    $24B4           ; else call this sub (???)

        LD      A,(IX+$03)      ; load A with barrel X position
        ADD     A,$08           ; add 8
        CP      $10             ; result < #10 ?
        JP      NC,$1FCE        ; No, jump back and ???

        XOR     A               ; yes, A := 0
        LD      (IX+$00),A      ; set barrel status indicator #0 to 0 (barrel is gone)
        LD      (IX+$03),A      ; set barrel x position to 0
        JP      $21BA           ; write to sprites and check next barrel

        LD      A,(IX+$05)      ; load A with barrel's Y position
        CP      $E0             ; < #E0 ? - are we at bottom of screen?
        JP      C,$2146         ; no, jump ahead

; else this crazy barrel is no longer crazy

        LD      A,(IX+$07)      ; else Load A with +7 = sprite used
        AND     $FC             ; clear right 2 bits
        OR      $01             ; turn on bit 0
        LD      (IX+$07),A      ; store result
        XOR     A               ; A := 0
        LD      (IX+$01),A      ; barrel is no longer crazy
        LD      (IX+$02),A      ;
        LD      (IX+$10),$FF    ; set velocity to -1 (move left)
        LD      (IX+$11),A      ;
        LD      (IX+$12),A      ;
        LD      (IX+$13),$B0    ;
        LD      (IX+$0E),$01    ;
        JP      $2153           ; jump ahead

; arrive here when crazy barrel hits a girder from #211D

        CALL    $2407           ; load HL based on +14 status. also uses +11 and +12
        CALL    $22CB           ; do stuff for crazy barrels ?
        LD      A,(IX+$05)      ; load A with barrel Y position
        LD      (IX+$19),A      ; store in barrel #19 status.  used for crazy barrels?
        XOR     A               ; A := 0

        LD      (IX+$14),A      ; clear +#14 (???)
        LD      (IX+$04),A      ; clear +#4 (???)
        LD      (IX+$06),A      ; store 0 in these barrel indicators
        JP      $21BA           ; jump ahead - we're done, store values and try next barrel

; arrive here every 8 pixels moved by barrel from #2001
; L has barrels Y pos
; H has barrels X pos

        LD      A,L             ; load A with barrels Y position

        ADD     A,$05           ; add 5
        LD      D,A             ; store into D
        LD      A,H             ; load A with barrels X position
        LD      BC,$0015        ; load BC with #15 to check for all ladders
        CALL    $216D           ; check for going down ladder
        JP      $21BA           ; skip ahead

; called from #2167

        CALL    $236E           ; check for ladder.  if no ladders, RET to higher sub.  if at top of ladder, A := 1
        DEC     A               ; is there a ladder to go down?
        RET     NZ              ; no, return

        LD      A,B             ; yes, load A with B which has the value of the ladder from the check ??
        SUB     $05             ; subtract 5
        LD      (IX+$17),A      ; store into +17 to indicate which ladder we might be going down ???
        LD      A,($6348)       ; get status of the oil can fire
        AND     A               ; is the fire lit ?
        JP      Z,$21B2         ; no, always take ladders before oil is lit

        LD      A,($6205)       ; else load A with mario's Y position + 5
        SUB     $04             ; subtract 4
        CP      D               ; is the barrel already below mario  ?
        RET     C               ; yes, return without taking ladder

        LD      A,($6380)       ; else load A with difficulty from 1 to 5.  usually the level but increases during play
        RRA                     ; roll right (div 2) .  now can be 0, 1, or 2
        INC     A               ; increment.  result is now 1, 2, or 3 based on skill level
        LD      B,A             ; store into B
        LD      A,(RngTimer1)   ; load A with random timer ?
        LD      C,A             ; store into C for later use ?
        AND     $03             ; mask bits.   result now random number between 0 and 3
        CP      B               ; compare with value computed above based on skill
        RET     NC              ; ret if greater.  on highest skill this works 75% of time, only returns on 3

        LD      HL,InputState   ; load HL with player input.

; InputState - copy of RawInput, except when jump is pressed, bit 7 is set momentarily
; RawInput - right sets bit 0, left sets bit 1, up sets bit 2, down sets bit 3, jump sets bit 4

        LD      A,($6203)       ; load A with mario's x position
        CP      E               ; compare with barrel's x position
        JP      Z,$21B2         ; if equal, then go down ladder

        JP      NC,$21A9        ; if barrel is to right of mario, then check for moving to left

        BIT     0,(HL)          ; else is mario trying to move right ?
        JP      Z,$21AE         ; no, skip ahead and return without going down ladder

        JP      $21B2           ; yes, make barrel go down ladder

        BIT     1,(HL)          ; is mario trying to move left ?
        JP      NZ,$21B2        ; yes, make barrel go down ladder

        LD      A,C             ; else load A with random timer computed above
        AND     $18             ; mask with #18.    25% chance of being zero?
        RET     NZ              ; else return without going down ladder.  If zero then go down the ladder anyway

        INC     (IX+$07)        ; increase Barrel's deployment/animation status
        SET     0,(IX+$02)      ; set barrel to go down the ladder
        RET

; we arrive here because the barrel is rolling left or right or turning a corner or a crazy barrel
; stores position values, sprite value and colors into sprite values
; arrive from several locations, eg #20DE

        EXX                     ; swap DE, HL, and BC with counterparts
        LD      A,(IX+$03)      ; load A with Barrels X position
        LD      (HL),A          ; store into sprite X position
        INC     L               ; HL := HL + 1
        LD      A,(IX+$07)      ; load A with Barrels deployment/animation status
        LD      (HL),A          ; store into sprite value
        INC     L               ; HL := HL + 1
        LD      A,(IX+$08)      ; load A with Barrel's color
        LD      (HL),A          ; Store into sprite color
        INC     L               ; HL := HL + 1
        LD      A,(IX+$05)      ; Load A with Barrel's Y position
        LD      (HL),A          ; store into sprite Y position
        JP      $1F8D           ; jump back and check for next barrel

; data used in sub below for attract mode movement
; first byte is movement, second is duration

        hex     80 FE     ; jump
        hex     01 C0     ; run right
        hex     04 50     ; up = climb ladder
        hex     02 10     ; run left
        hex     82 60     ; jump left
        hex     02 10     ; run left
        hex     82 CA     ; jump left
        hex     01 10     ; run right
        hex     81 FF     ; jump right (gets hammer)
        hex     02 38     ; run left
        hex     01 80     ; run right - mario dies falling over right edge
        hex     02 FF     ; run left
        hex     04 80     ; up
        hex     04 60     ; up
        hex     80        ; ?

; called during attract mode only from #1977

        LD      DE,$21D1        ; load DE with start of table data
        LD      HL,$63CC        ; load HL with state of attract mode
        LD      A,(HL)          ; load A with state
        RLCA                    ; rotate left (x2)
        ADD     A,E             ; add to E to get the movement
        LD      E,A             ; put back
        LD      A,(DE)          ; load A with data from table
        LD      (InputState),A  ; store into copy of input
        INC     L               ; HL := #63CD (timer)
        LD      A,(HL)          ; load timer
        DEC     (HL)            ; decrement
        AND     A               ; == #00 ?
        RET     NZ              ; no, return

        INC     E               ; else next movement
        LD      A,(DE)          ; load A with timer from table
        LD      (HL),A          ; store into timer
        DEC     L               ; HL := #63CC (state)
        INC     (HL)            ; increase state
        RET

; arrive here from main routine at #199B

        LD      A,$02                   ; load A with 2 = 0010 binary
        RST     $30                     ; only continues here on conveyors, else returns from subroutine

        LD      A,(FrameCounter)        ; load A with this clock counts down from #FF to 00 over and over...
        RRA                             ; time to do this ?
        LD      HL,$6280                ; load HL with left side rectractable ladder
        LD      A,(HL)                  ; load A with ladder status
        JP      C,$2219                 ; if clock is odd, skip next 2 steps

        LD      HL,$6288                ; load HL with right side retractable ladder
        LD      A,(HL)                  ; load A with ladder status

        PUSH    HL                      ; save HL
        RST     $28                     ; jump based on A

        hex     27 22                   ; #2227         A = 0   ladder is all the way up
        hex     59 22                   ; #2259         A = 1   ladder is moving down
        hex     99 22                   ; #2299         A = 2   ladder is all the way down
        hex     A2 22                   ; #22A2         A = 3   ladder is moving up
        hex     00 00 00 00             ; unused

; ladder is all the way up

        POP     HL              ; restore HL - it has the ladder address
        INC     L               ; HL := #6289 or #6281 - timer for movement ???
        DEC     (HL)            ; decrement.  at zero ?
        JP      NZ,$223A        ; no, skip ahead and check to disable moving ladder indicator

        DEC     L               ; put HL back where it was
        INC     (HL)            ; increase ladder status.  now it is moving down
        INC     L               ;
        INC     L               ; HL := #628A or #6282
        CALL    $2243           ; only continue below if mario is on the ladder

        LD      A,$01           ; A := 1
        LD      ($621A),A       ; store into moving ladder indicator
        RET

        INC     L               ; HL := #628A or #6282
        CALL    $2243           ; only continue below if mario is on the ladder, else RET

        XOR     A               ; A := 0
        LD      ($621A),A       ; store into moving ladder indicator
        RET

; called from $2231 above with HL = #628A
; called from $223B above with HL = #628A
; called from #2276 below

        LD      A,($6205)       ; load mario's Y position
        CP      $7A             ; is mario on the top pie tray level or above?
        JP      NC,$2257        ; no, skip ahead and return to higher sub

        LD      A,($6216)       ; yes, check for a jump in progress ?
        AND     A               ; is mario jumping ?
        JP      NZ,$2257        ; yes, jump ahead and return to higher sub

        LD      A,($6203)       ; else load A with mario's X position
        CP      (HL)            ; is mario on the ladder? (or exactly lined up on it)
        RET     Z               ; yes, return

        POP     HL              ; adjust stack pointer
        RET                    ;ret to higher subroutine

; arrive from $221A when ladder is moving down

        POP     HL              ; restore HL = ladder status
        INC     L
        INC     L
        INC     L
        INC     L               ; HL now has the ladder's ???
        DEC     (HL)            ; decrease.  at zero?
        RET     NZ              ; no, return

        LD      A,$04           ; A := 4
        LD      (HL),A          ; store into the ladder's ???
        DEC     L               ; HL now has the ladder's ???
        INC     (HL)            ; increase
        CALL    $22BD           ; ???
        LD      A,$78           ; A := #78
        CP      (HL)            ; == (HL) ?
        JP      NZ,$2275        ; no, skip ahead

        DEC     L
        DEC     L
        DEC     L
        INC     (HL)
        INC     L
        INC     L
        INC     L

        DEC     L               ; HL now has ???
        CALL    $2243           ; only continue below if mario is on the ladder, else RET

; ladder is moving down and mario is on it

        LD      A,($6205)       ; load A with mario Y position
        CP      $68             ; is mario already at the low point of the ladder ?
        JP      NC,$228A        ; yes, skip ahead

        LD      HL,$6205        ; else load HL with Mario's Y position
        INC     (HL)            ; increase (move mario down one pixel)
        CALL    $3FC0           ; sets mario sprite to on ladder with left hand up and HL to #694F (mario's sprite Y position) [this line seems like a patch ??? orig could be  LD HL,#694F ]
        INC     (HL)            ; increase sprite (move mario down one pixel in the hardware .  immediate update)
        RET

        RRA                     ; rotate right A.  is A odd ?
        JP      C,$2281         ; yes, loop back

        RRA                     ; else rotate right A again.  is the 2-bit set ?
        LD      A,$01           ; A := 1
        JP      C,$2295         ; yes, skip next step

        XOR     A               ; A := 0
        LD      ($6222),A       ; store into ladder toggle
        RET

; arrive from $221A when ladder is all the way down

        POP     HL              ; restore HL
        LD      A,(RngTimer1)   ; load A with random timer
        AND     $3C             ; mask bits.  result zero?
        RET     NZ              ; no, return

        INC     (HL)            ; else increase (HL) - the ladder is now moving up
        RET

; arrive from jump at #221A
; a rectractable ladder is moving up
; HL popped from stack is either 6280 for left ladder or 6288 for right ladder

        POP     HL              ; restore HL
        INC     L
        INC     L
        INC     L
        INC     L               ; HL := HL + 4
        DEC     (HL)            ; decrease (HL).  zero?
        RET     NZ              ; no, return

        LD      (HL),$02        ; else set (HL) to 2
        DEC     L               ;
        DEC     (HL)            ; decrease ladder Y value - makes ladder move up
        CALL    $22BD           ; update the sprite
        LD      A,$68           ; A := #68
        CP      (HL)            ; reached top of ladder movement?
        RET     NZ              ; no, return

; ladder has moved all the way up

        XOR     A               ; A := 0
        LD      B,$80           ; B := #80
        DEC     L
        DEC     L
        LD      (HL),B          ;
        DEC     L               ; set HL to ladder status
        LD      (HL),A          ; set ladder status to 0 == all the way up
        RET

; called from $22AD above and from #2265
; HL is preloaded with ladder Y position

        LD      A,(HL)          ; load A with ladder Y value
        BIT     3,L             ; test bit 3 of L
        LD      DE,$694B        ; load DE with ladder sprite Y value
        JP      NZ,$22C9        ; if other ladder, skip next step

        LD      DE,$6947        ; load DE with other ladder sprite Y value
        LD      (DE),A          ; update the sprite Y value
        RET

; arrive here when crazy barrel is onscreen
; called when barrel deployed or hits a girder on the way down
; called from #2149

        LD      A,($6348)       ; load A with oil can status
        AND     A               ; is the oil can lit ?
        JP      Z,$22E1         ; no , jump ahead

        LD      A,($6380)       ; else load A with difficulty
        DEC     A               ; decrement.  will be between 0 and 4
        RST     $28             ; jump based on A

        hex     F6 22           ; #22F6
        hex     F6 22           ; #22F6
        hex     03 23           ; #2303
        hex     03 23           ; #2303
        hex     1A 23           ; #231A

; arrive here when oil can is not yet lit
; used for initial crazy barrel

        LD      A,($6229)       ; load A with level #
        LD      B,A             ; store into B
        DEC     B               ; decrement B
        LD      A,$01           ; load A with 1
        JP      Z,$22F9         ; if level was 1, then jump ahead

        DEC     B               ; decrement B again
        LD      A,$B1           ; load A with #B1 - for use with level 2 inital crazy barrel
        JP      Z,$22F9         ; if level 2, then jump ahead

        LD      A,$E9           ; else load A with #E9 - for level 3 and up inital crazy barrel
        JP      $22F9           ; jump ahead and store

; check for use with crazy barrels when difficulty is 1 or 2

        LD      A,(RngTimer1)   ; load A with random timer value

        LD      (IX+$11),A      ; store into +11
        AND     $01             ; mask bits, makes into #00 or #01
        DEC     A               ; decrement, now either #00 or #FF
        LD      (IX+$10),A      ; store into +10
        RET

; check for use with crazy barrels when difficulty is 3 or 4

        LD      A,(RngTimer1)   ; load A with random timer value
        LD      (IX+$11),A      ; store into +11
        LD      A,($6203)       ; load A with mario's X position
        CP      (IX+$03)        ; compare barrel's X position
        LD      A,$01           ; load A with 1
        JP      NC,$2316        ; if greater then skip ahead

        DEC     A               ; else decrement twice
        DEC     A               ; makes A := #FF

        LD      (IX+$10),A      ; store into +10
        RET

; check for use with crazy barrels when difficulty is 5

        LD      A,($6203)       ; load A with mario's X position
        SUB     (IX+$03)        ; subtract the barrel's X position
        LD      C,$FF           ; load C with #FF
        JP      C,$2326         ; if barrel is to left of mario, then jump ahead

        INC     C               ; else increase C to 0

        RLCA                    ; rotate left A (doubles A)
        RL      C               ; rotate left C
        RLCA                    ; rotate left A (doubles A)
        RL      C               ; rotate left C
        LD      (IX+$10),C      ; store C into +10
        LD      (IX+$11),A      ; store A into +11
        RET

; called from $2007 when barrels are rolling
; called from $     when mario is moving left or right on girders
; HL is preloaded with mario X,Y position
; B is preloaded with direction

        LD      A,$0F           ; load A with binary 00001111
        AND     H               ; and with H.  A now has between 0 and F
        DEC     B               ; Count down B.  is the direction == 1 ?
        JP      Z,$2342         ; yes, then skip ahead 4 steps

        CP      $0F             ; else check is A still = #0F ?
        RET     C               ; ret if Carry ( A < 0F ) most of time it wont?

        LD      B,$FF           ; else B := #FF
        JP      $2347           ; skip next 3 steps

        CP      $01             ; A > 1 ?
        RET     NC              ; yes, return

        LD      B,$01           ; B := 1

        LD      A,$F0           ; A := #F0
        CP      L               ; is A == L ?
        JP      Z,$2360         ; Yes, skip ahead

        LD      A,$4C           ; A := #4C
        CP      L               ; == L ?
        JP      Z,$2366         ; yes, skip ahead

        LD      A,L
        BIT     5,A
        JP      Z,#235C

        SUB     B
        LD      L,A
        RET

        ADD     A,B             ; A := A + B
        JP      $235A           ; loop back

        BIT     7,H
        JP      NZ,#2359
        RET

        LD      A,H             ; A := H
        CP      $98             ; < #98 ?
        RET     C               ; no, return

        LD      A,L             ; A := L
        JP      $235C           ; loop back

; called from $1B13 when jumping ?
; called from $216D when checking for barrel to go down a ladder?
; A has X position of barrel ?
; BC starts with #15
; called when firefoxs are moving to check for ladders
; if no ladder is nearby , it RETs to a higher subroutine

        LD      HL,$6300        ; load HL with start of table data that has positions of ladders
        CPIR                    ; check for ladders ???

; CPIR - The contents of the memory location addressed by the HL register pair is
; compared with the contents of the Accumulator. In case of a true compare, a
; condition bit is set. HL is incremented and the Byte Counter (register pair
; BC) is decremented. If decrementing causes BC to go to zero or if A = (HL),
; the instruction is terminated. If BC is not zero and A ? (HL), the program
; counter is decremented by two and the instruction is repeated. Interrupts are
; recognized and two refresh cycles are executed after each data transfer.
; If BC is set to zero before instruction execution, the instruction loops
; through 64 Kbytes if no match is found.



        JP      NZ,$239A        ; if no match, return to higher sub, no ladder nearby

        PUSH    HL              ; else a ladder may be near. save HL
        PUSH    BC              ; save BC
        LD      BC,$0014        ; load BC with #14 for offset
        ADD     HL,BC           ; add #14 to HL.  Now HL has the ladder's other value ?
        INC     C               ; C := #15
        LD      E,A             ; save A into E
        LD      A,D             ; load A with D = barrels position ?
        CP      (HL)            ; compare with ladder's position
        JP      Z,$238F         ; if equal then jump ahead

        ADD     HL,BC           ; else add #15 into HL
        CP      (HL)            ; compare position
        JP      Z,$2395         ; if equal then skip ahead

        LD      D,A             ; else load D with A
        LD      A,E             ; load A with E
        POP     BC              ; restore BC
        POP     HL              ; restore HL
        JP      $2371           ; check for next ladder?

; arrive here when a barrel is above a ladder

        ADD     HL,BC           ; add #15 into HL
        LD      A,$01           ; load A with 1 = signal that we are at top of ladder
        JP      $2398           ; jump ahead

        XOR     A               ; else A: = 0 = signal that we are at bottom of ladder
        SBC     HL,BC           ; subtract BC from HL.  restore HL to original value

        POP     BC              ; restore BC
        LD      B,(HL)          ; load B with value in HL

        POP     HL              ; restore HL
        RET

; called from $20ED for crazy barrel movement.  for this, BC, DE,and HL have their alternates
; subroutine called from $2054.  used when barrels are rolling.  only called when rolling around edges or mario jumping???
; IX has the start value of barrel sprite.  EG 6700
; IX can have 6200 for mario from #1BC2

        LD      A,(IX+$04)      ; load modified Y position, used for crazy barrels hitting girders ???
        ADD     A,(IX+$11)      ; add +11 = vertical speed?
        LD      (IX+$04),A      ; update position ?

        LD      A,(IX+$03)      ; load object's X position
        ADC     A,(IX+$10)      ; add +10 = rolling over edge/direction indicator.  note this is add with carry
        LD      (IX+$03),A      ; store into X position

        LD      A,(IX+$06)      ; load A with +6 == ??
        SUB     (IX+$13)        ; subtract +13 == ??
        LD      L,A             ; store into L
        LD      A,(IX+$05)      ; load A with barrel Y position
        SBC     A,(IX+$12)      ; subtract vertical speed????
        LD      H,A             ; store into H
        LD      A,(IX+$14)      ; load +14 = mirror of modified Y position?.  used for jump counter when mario jumps
        AND     A               ; clear flags
        RLA                     ; rotate left (mult by 2)
        INC     A               ; add 1
        LD      B,$00           ; B := 0
        RL      B               ;
        SLA     A
        RL      B
        SLA     A
        RL      B
        SLA     A
        RL      B
        LD      C,A             ; copy answer (A) to C. BC now has ???
        ADD     HL,BC           ; add to HL
        LD      (IX+$05),H      ; update Y position
        LD      (IX+$06),L      ; update +6
        INC     (IX+$14)        ; increase +14.  used for 6214 for mario as a jump counter
        RET

; called from subs that are moving a barrell left or right
; IX is memory base of the barrel in question (e.g. #6700)
; called from $2073 with C either 0 or 4
; C is preloaded with mask ?


        LD      A,(IX+$0F)      ; Load A with +#F property of barrel (counts from 4 to 1 over and over)
        DEC     A               ; decrease by one.  did counter go to zero?
        JP      NZ,$2403        ; if not, jump ahead, store new timer value and return

        XOR     A               ; A := 0
        SLA     (IX+$07)        ; shift left the barrel sprite status, push bit 7 into carry flag
        RLA                     ; rotate in carry flag into A
        SLA     (IX+$08)        ; shift left the other barrel color, push bit 7 into carry flag
        RLA                     ; rotate in carry flag into A
        LD      B,A             ; copy result into B
        LD      A,$03           ; A := 3
        OR      C               ; bitwise OR with C
        CALL    $3009           ; ???
        RRA                     ;
        RR      (IX+$08)        ; rotate right the barrel's color
        RRA                     ;
        RR      (IX+$07)        ; Roll these values back
        LD      A,$04           ; A := 4

        LD      (IX+$0F),A      ; store A into timer
        RET

;
; called from $1BDF and $20C3 and #2146
;

        LD      A,(IX+$14)      ; load A with Barrel +14 status
        RLCA
        RLCA
        RLCA
        RLCA                    ; rotate left 4 times
        LD      C,A             ; save to C for use next 2 steps
        AND     $0F             ; mask with #0F.  now between #00 and #0F
        LD      H,A             ; store into H
        LD      A,C             ; restore A to value saved above
        AND     $F0             ; mask with #F0
        LD      L,A             ; store into L
        LD      C,(IX+$13)      ; load C with +13
        LD      B,(IX+$12)      ; load B with +12
        SBC     HL,BC           ; HL := HL - BC
        RET

; arrive here when jump not pressed ?
; sets DE based on mario's position
; called from #1AE6
; called from #1BC5
; called from #2B09

        LD      DE,$0100        ; DE:= #0100
        LD      A,($6203)       ; load A with Mario's X position
        CP      $16             ; is this greater than #16 ?
        RET     C               ; yes, return

        DEC     D               ; no,
        INC     E               ; DE := #0001
        CP      $EA             ; is Mario's position > #EA ?
        RET     NC              ; yes, return

        DEC     E               ; no, DE:= #0000
        LD      A,($6227)       ; load A with screen number (01, 10, 11 or 100)
        RRCA                    ; rotate right with carry.  is this the girders or elevators?
        RET     nc              ; no, return

        LD      A,($6205)       ; otherwise load A with mario's Y position
        CP      $58             ; is this > #58 ?
        RET     nc              ; Yes, return

        LD      A,($6203)       ; else load A with mario's X position
        CP      $6C             ; is this > #6C ?
        RET     NC              ; Yes, return

        INC     D               ; else DE := #0100
        RET                     ; and return

; called from #0D62

; checksum ???

        ; 3F00:  5C 76 49 4A 01 09 08 01 3F 7D 77 1E 19 1E 24 15  .(C)1981...NINTE
        ; 3F10:  1E 14 1F 10 1F 16 10 11 1D 15 22 19 13 11 10 19  NDO.OF.AMERICA.I

; called from #0D62
; 1.  runs checksum on the NINTENDO, breaks if not correct
; 2.

        LD      HL,$3F0C        ; load HL with ROM area that has NINTENDO written
        LD      A,$5E           ; A := #5E = constant so the checksum comes to zero
        LD      B,$06           ; for B = 1 to 6

        ADD     A,(HL)          ; add this letter
        INC     HL              ; next letter
        DJNZ    $2448           ; loop until done

        LD      IY,$6310        ;
        AND     A               ; A == 0 ? checksum OK ?
        JP      Z,$2456         ; yes, skip next step

        INC     IY              ; running this step will break the game ?  loops at #2371 forever

        LD      A,($6227)       ; load A with screen number
        DEC     A               ; is this the girders?
        LD      HL,$3AE4        ; load HL with start of table data for girders
        JP      Z,$2471         ; if girders, skip ahead

        DEC     A               ; else is this the conveyors?
        LD      HL,$3B5D        ; load HL with start of table data for conveyors
        JP      Z,$2471         ; if conveyors, skip ahead

        DEC     A               ; else is this the elevators?
        LD      HL,$3BE5        ; load HL with start of table data for elevators
        JP      Z,$2471         ; if elevators, skip ahead

        LD      HL,$3C8B        ; otherwise we're on rivets.  load HL with table data for rivets

        LD      IX,$6300        ; #6300 is used for ladder positions?
        LD      DE,$0005        ; DE := 5 = offset

        LD      A,(HL)          ; load A with the next item of data
        AND     A               ; is this item == 0 ?
        JP      Z,$2488         ; yes, jump ahead

        DEC     A               ; no, decrease, was this item == 1 ?
        JP      Z,$249E         ; yes, jump down instead

        CP      $A9             ; was the item == #AA ?
        RET     Z               ; yes, return, we are done with this.  AA is at the end of each table

        ADD     HL,DE           ; if neither then add offset for next HL
        JP      $2478           ; loop again

; data element was #01

        INC     HL              ; next HL
        LD      A,(HL)          ; load A with table data (EG #3B12)
        LD      (IX+$00),A      ; store into index
        INC     HL              ; next HL
        LD      A,(HL)          ; load A with table data
        LD      (IX+$15),A      ; store into index +#15
        INC     HL              ;
        INC     HL              ; next HL, next HL
        LD      A,(HL)          ; load A with table data
        LD      (IX+$2A),A      ; store into index +#2A
        INC     IX              ; next location
        INC     HL              ; next table data
        JP      $2478           ; jump back

; data element was #02
; this sub is same as one above but uses IY instead of IX

        INC     HL
        LD      A,(HL)
        LD      (IY+#00),A
        INC     HL
        LD      A,(HL)
        LD      (IY+#15),A
        INC     HL
        INC     HL
        LD      A,(HL)
        LD      (IY+#2A),A
        INC     IY
        INC     HL
        JP      $2478           ; jump back

; called this sub from barrel roll from #2068
; check for barrel collision with the oil can ????

        LD      A,(IX+$05)      ; load A with Barrel Y position
        CP      $E8             ; Is it near the bottom or lower?
        RET     C               ; if so, return

        LD      A,(IX+$03)      ; else load A with Barrel X position
        CP      $2A             ; is X position < #2A ? (rolling oever edge on left side of screen)
        RET     NC              ; no, return

        CP      $20             ; is it past the edge of girder?
        RET     C               ; no, return

        LD      A,(IX+$15)      ; load A with Barrel #15 indicator, zero = normal barrel,  1 = blue barrel
        AND     A               ; is this a normal barrel?
        JP      Z,$24D0         ; yes, jump ahead

        LD      A,$03           ; else blue barrel, A := 3
        LD      ($62B9),A       ; store into #62B9 - used for releasing fires ?
        XOR     A               ; A := #00

        LD      (IX+$00),A      ; clear out the barrel active indicator
        LD      (IX+$03),A      ; clear out the barrel X position
        LD      HL,$6082        ; load HL with boom sound address
        LD      (HL),$03        ; play boom sound for 3 units
        POP     HL              ; get HL from stack
        LD      A,($6348)       ; turns to 1 when the oil can is on fire
        AND     A               ; is oil can already on fire ?
        JP      NZ,$21BA        ; yes, jump back, we are done

        INC     A               ; else A := 1
        LD      ($6348),A       ; set the oil can is on fire
        JP      $21BA           ; jump back , we are done.

; called from main routine at $1992
; copies pie buffer to pie sprites

        LD      A,$02           ; check level for conveyors
        RST     $30             ; if not conveyors, RET, else continue
        CALL    $2523           ; check for deployment of new pies
        CALL    $2591           ; update all pies positions based on direction of trays, remove pies in fire or off edge
        LD      IX,$65A0        ; load IX with start of pies
        LD      B,$06           ; for B = 1 to 6 pies
        LD      HL,$69B8        ; load HL with hardware address for pies

        LD      A,(IX+$00)      ; load A with sprite status
        AND     A               ; is this sprite active ?
        JP      Z,$251C         ; no, add 4 to L and loop again

        LD      A,(IX+$03)      ; load A with pie X position
        LD      (HL),A          ; store into sprite
        INC     L               ; next address
        LD      A,(IX+$07)      ; load A with pie sprite value
        LD      (HL),A          ; store into sprite
        INC     L               ; next address
        LD      A,(IX+$08)      ; load A with pie color
        LD      (HL),A          ; store into sprite
        INC     L               ; next address
        LD      A,(IX+$05)      ; load A with pie Y position
        LD      (HL),A          ; store into sprite
        INC     L               ; next address

        ADD     IX,DE           ; add offset for next pie
        DJNZ    $24FC           ; next B

        RET

        LD      A,L             ; A := L
        ADD     A,$04           ; add 4
        LD      L,A             ; store into L
        JP      $2517           ; loop back for next pie

; called from #24ED above

        LD      HL,$639B        ; load HL with pie timer
        LD      A,(HL)          ; get timer value
        AND     A               ; time to release a pie ?
        JP      NZ,$258F        ; no, decrease counter and return

        LD      A,($639A)       ; load A with fire deployment indicator ???
        AND     A               ; == 0 ? (are there no fires???)
        RET     Z               ; yes, return, no pies until fires are released

; look for a pie to deploy

        LD      B,$06           ; for B = 1 to 6 pies
        LD      DE,$0010        ; load DE with offset of #10 (16 decimal)
        LD      IX,$65A0        ; load IX with start of pie sprites table

        BIT     0,(IX+$00)      ; is this pie already onscreen?
        JP      Z,$2545         ; no, jump ahead and deploy this pie

        ADD     IX,DE           ; else load offset for next pie
        DJNZ    $2539           ; next B

        RET                    ;ret [no room for more pies, 6 already onscreen]

; deploy a pie

        CALL    $0057           ; load A with a random number
        CP      $60             ; < #60 ?
        LD      (IX+$05),$7C    ; store #7C into pie's Y position
        JP      C,$2558         ; yes, skip next 3 steps

        LD      A,($62A3)       ; load A with master direction for middle conveyor
        DEC     A               ; is this tray moving outwards ?
        JP      NZ,$256E        ; no, skip ahead

        LD      (IX+$05),$CC    ; store #CC into pie's Y position
        LD      A,($62A6)       ; load A with master direction vector for lower conveyor
        RLCA                    ; is this tray moving to the right ?

        LD      (IX+$03),$07    ; set pie X position to 7
        JP      NC,$2576        ; if tray moving right, skip ahead

        LD      (IX+$03),$F8    ; set pie X position to #F8
        JP      $2576           ; skip ahead

        CALL    $0057           ; load A with random number
        CP      $68             ; < #68 ?
        JP      $2560           ; use to decide to put on left or right side

        LD      (IX+$00),$01    ; set pie active
        LD      (IX+$07),$4B    ; set pie sprite value
        LD      (IX+$09),$08    ; set pie size??? (width?)
        LD      (IX+$0A),$03    ; set pie size??? (height?)
        LD      A,$7C           ; A := #7C
        LD      ($639B),A       ; store into pie timer for next pie deployment
        XOR     A               ; A := 0
        LD      ($639A),A       ; store into ???

        DEC     (HL)            ; decrease pie timer
        RET

; called from #24F0 above
; updates all pies

        LD      IX,$65A0        ; load IX with pie sprite buffer
        LD      DE,$0010        ; load DE with offset
        LD      B,$06           ; for B = 1 to 6

        BIT     0,(IX+$00)      ; active ?
        JP      Z,$25BB         ; no, skip ahead and loop for next

        LD      A,(IX+$03)      ; load A with pie's X position
        LD      H,A             ; copy to H
        ADD     A,$07           ; Add 7
        CP      $0E             ; < #E ? (pie < 6 or pie > #F9)
        JP      C,$25D6         ; yes, skip ahead to handle

        LD      A,(IX+$05)      ; load A with pie Y position
        CP      $7C             ; is this the top level pie?
        JP      Z,$25C0         ; yes, skip ahead

        LD      A,($63A6)       ; load A with pie direction vector for lower pie level
        ADD     A,H             ; add vector to original position
        LD      (IX+$03),A      ; store into pie X position

        ADD     IX,DE           ; add offset for next sprite
        DJNZ    $259A           ; next B

        RET

        LD      A,H             ; load A with pie X position
        CP      $80             ; is the pie in the center fire?
        JP      Z,$25D6         ; yes, skip ahead

        LD      A,($63A5)       ; load A with direction for upper left pie tray
        JP      NC,$25CF        ; if pie < #80, use this address and skip next step

        LD      A,($63A4)       ; else load A with direction for upper right tray

        ADD     A,H             ; add vector to pie position
        LD      (IX+$03),A      ; store into pie X position
        JP      $25BB           ; loop for next sprite

; pie in center fire or reached edge

        LD      HL,$69B8        ; load HL with start of pie sprites
        LD      A,$06           ; A := 6
        SUB     B               ; subtract the pie number that is removed.  zero ?
        JP      Z,$25E7         ; yes, skip ahead

        INC     L
        INC     L
        INC     L
        INC     L               ; else HL := HL + 4
        DEC     A               ; decrease A
        JP      $25DC           ; loop again

        XOR     A               ; A := 0
        LD      (IX+$00),A      ; clear pie active indicator
        LD      (IX+$03),A      ; clear pie X position
        LD      (HL),A          ; clear sprite from screen
        JP      $25BB           ; jump back and continue

; called from main routine at $19AA

        LD      A,$02           ; load A with 2 = 0010 binary
        RST     $30             ; ret if not conveyors

        CALL    $2602           ; handle top conveyor and pulleys
        CALL    $262F           ; handle middle conveyor and pulleys
        CALL    $2679           ; handle lower conveyor and pulleys
        CALL    $2AD3           ; handle mario's different speeds when on a conveyor
        RET

; called from #16D5, #25F5

        LD      A,(FrameCounter)        ; load A with this clock counts down from #FF to 00 over and over...
        RRCA                            ; is the counter odd?
        JP      C,$2616                 ; yes, skip ahead

        LD      HL,$62A0                ; load HL with top conveyor counter
        DEC     (HL)                    ; decrease.  time to reverse?
        JP      NZ,$2616                ; no, skip next 3 steps

        LD      (HL),$80                ; reset counter
        INC     L                       ; HL := #62A1 = master direction vector for top tray
        CALL    $26DE                   ; reverse the direction of this tray

        LD      HL,$62A1                ; load HL with master direction vector for top conveyor
        CALL    $26E9                   ; load A with direction vector for this frame
        LD      ($63A3),A               ; store A into direction vector for top conveyor
        LD      A,(FrameCounter)        ; load A with this clock counts down from #FF to 00 over and over...
        AND     $1F                     ; mask bits
        CP      $01                     ; == 1 ?
        RET     NZ                      ; no, return

        LD      DE,$69E4                ; else load DE with start of pulley sprites
        EX      DE,HL                   ; DE <> HL
        CALL    $26A6                   ; animate the pulleys
        RET

; called from #25F8 above

        LD      HL,$62A3                ; load HL with address of master direction vector for middle conveyor
        LD      A,($6205)               ; load A with mario's Y position
        CP      $C0                     ; is mario slightly above the lower conveyor?
        JP      C,$266F                 ; yes, skip ahead.  in this case the upper trays don't vary

        LD      A,(FrameCounter)        ; load A with this clock counts down from #FF to 00 over and over...
        RRCA                            ; roll right, is there a carry bit?
        JP      C,$264C                 ; yes, skip ahead

        DEC     L                       ; load HL with middle conveyor counter
        DEC     (HL)                    ; decrease it.  at zero?
        JP      NZ,$264C                ; no, skip ahead

        LD      (HL),$C0                ; yes, reset the counter to #C0
        INC     L                       ; HL := #62A3 = master direction vector for middle conveyor
        CALL    $26DE                   ; reverse the direction of this tray

        LD      HL,$62A3                ; load HL with master direction vector for upper left
        CALL    $26E9                   ; load A with direction vector for this frame
        LD      ($63A5),A               ; store into pie tray vector (upper right)
        NEG                             ; negate.  upper two pie trays move opposite directions
        LD      ($63A4),A               ; store into pie tray vector (upper left)
        LD      A,(FrameCounter)        ; load A with this clock counts down from #FF to 00 over and over...
        AND     $1F                     ; mask bits, now between 0 and #1F.  zero?
        RET     NZ                      ; no, return

        DEC     L                       ; HL := #62A2 = middle conveyor counter
        LD      DE,$69EC                ; load DE with middle pulley sprites
        EX      DE,HL                   ; DE <> HL
        CALL    $26A6                   ; animate the pulleys
        AND     $7F                     ; mask bits, A now betwen #7F and 0 (turns off bit 7)
        LD      HL,$69ED                ; load HL with ???
        LD      (HL),A                  ; store A
        RET

        BIT     7,(HL)          ; is this tray moving left ?
        JP      NZ,$264C        ; yes, don't change anything

        LD      (HL),$FF        ; else change tray so it is moving left
        JP      $264C           ; loop back to continue

; called from #25FB

        LD      A,(FrameCounter)        ; load A with this clock counts down from #FF to 00 over and over...
        RRCA                            ; rotate right.  is there a carry?
        JP      C,$268D                 ; yes, skip ahead

        LD      HL,$62A5                ; no, load HL with this counter
        DEC     (HL)                    ; count it down.  zero?
        JP      NZ,$268D                ; no, skip ahead

        LD      (HL),$FF                ; yes, reset counter to #FF
        INC     L                       ; HL := #62A6 = master direction vector for lower level
        CALL    $26DE                   ; reverse direction of this tray

        LD      HL,$62A6                ; load HL with master direction vector for lower level
        CALL    $26E9                   ; load A with direction vector for this frame
        LD      ($63A6),A               ; store A into pie direction for lower level
        LD      A,(FrameCounter)        ; load A with this clock counts down from #FF to 00 over and over...
        AND     $1F                     ; mask bits.  now between 0 and #1F
        CP      $02                     ; == 2 ? (1/32 chance?)
        RET     NZ                      ; no, return

        LD      DE,$69F4                ; load DE with pulley sprite start
        EX      DE,HL                   ; DE <> HL
        CALL    $26A6                   ; call sub below to animate the pulleys [why?  it should just continue here]
        RET

; called from $26A2, above with HL preloaded with pulley sprite address and DE preloaded with conveyor direction
; animates the pulleys

        INC     L               ; load HL with pulley sprite value
        LD      A,(DE)          ; load A with master conveyor direction
        RLA                     ; rotate left.  carry set?
        JP      C,$26C5         ; yes, skip ahead to handle that direction

        LD      A,(HL)          ; load A with current sprite
        INC     A               ; increase it to animate
        CP      $53             ; == #53 ? at end of sprite range?
        JP      NZ,$26B5        ; no, skip next step

        LD      A,$50           ; A := #50 = reset sprite to first

        LD      (HL),A          ; store result sprite
        LD      A,L             ; A := L = #E5
        ADD     A,$04           ; add 4 = #E9 for next sprite
        LD      L,A             ; HL now has next sprite
        LD      A,(HL)          ; load A with sprite value
        DEC     A               ; decrease to animate
        CP      $CF             ; == #CF ? end of sprites?
        JP      NZ,$26C3        ; no, skip next step

        LD      A,$D2           ; A := #D2 = reset sprite to first

        LD      (HL),A          ; store into sprite
        RET

; from $26A9 when conveyor direction is other way

        LD      A,(HL)          ; load A with sprite value
        DEC     A               ; decrease to animate
        CP      $4F             ; == #4F ? end of sprites?
        JP      NZ,$26CE        ; no, skip next step

        LD      A,$52           ; A := #52 = first sprite

        LD      (HL),A          ; store into sprite
        LD      A,L             ; A := L
        ADD     A,$04           ; add 4
        LD      L,A             ; L := A.  HL now has next sprite in set
        LD      A,(HL)          ; load A with sprite value
        INC     A               ; increase to animate
        CP      $D3             ; == #D3? end of sprites?
        JP      NZ,$26DC        ; no, skip next step

        LD      A,$D0           ; yes, A := #D0 = reset sprite to first

        LD      (HL),A          ; store sprite
        RET

; called from $268A with HL == $62A6 = master direction vector for lower level

        BIT     7,(HL)          ; is this direction moving right ?
        JP      Z,$26E6         ; yes, skip next 2 steps

        LD      (HL),$02        ; store 2 into (HL) - reverses the pie tray direction (now moving right)
        RET

        LD      (HL),$FE        ; store #FE into (HL) - reverses the pie tray direction (now moving left)
        RET

; called when deciding which way to switch the pie tray direction vectors
; HL is preloaded with the master direction vector for the tray

        LD      A,(FrameCounter)        ; load with clock counts down from #FF to 00 over and over...
        AND     $01                     ; mask bits.  now either 0 or 1.  zero?
        RET     Z                       ; yes, return.  every other frame the pie tray is stationary

        BIT     7,(HL)                  ; check bit 7 of (HL) - this is the master direction for this tray
        LD      A,$FF                   ; load A with vector for tray moving to left
        JP      NZ,$26F8                ; not zero, skip next step

        LD      A,$01                   ; load A with vector for tray moving to right
        LD      (HL),A                  ; store result
        RET

; arrive here from main routine at #19A7

        LD      A,$04           ; A := 4 = 0100 binary
        RST     $30             ; only continue here if elevators, else RET

; elevators only

        LD      A,($6205)               ; load A with mario's Y position
        CP      $F0                     ; is mario too low ?
        JP      NC,$277F                ; yes, then mario dead

        LD      A,($6229)               ; else load A with level number
        DEC     A                       ; decrement and check for zero
        LD      A,(FrameCounter)        ; load A with this clock counts down from #FF to 00 over and over...
        JP      NZ,$271A                ; if level <> 1 then jump ahead

; slow elevators for level 1, japanese rom only?

        AND     $03             ; mask bits of timer, now between 0 and 3
        CP      $01             ; == 1 ?
        JP      Z,$271E         ; yes, skip ahead and return

        JP      C,$2722         ; if greater, then jump ahead and move elevators ?

        RET                     ; else return

        RRCA                    ; rotate right the timer
        JP      C,$2722         ; if carry jump ahead and move the elevators (50% of time)

        CALL    $2745           ; handle if mario is riding elevators
        RET

        CALL    $2797           ; move elevators
        CALL    $27DA           ; check for and set elevators that have reset
        LD      B,$06           ; For B = 1 to 6
        LD      DE,$0010        ; load offset
        LD      HL,$6958        ; load starting value for elevator sprites
        LD      IX,$6600        ; memory where elevator values are stored

; update elevator sprites

        LD      A,(IX+$03)      ; load X position value for elevator
        LD      (HL),A          ; store into sprite value X position
        INC     L
        INC     L
        INC     L               ; HL now has sprite Y value
        LD      A,(IX+$05)      ; load A with elevator Y position
        LD      (HL),A          ; store into sprite Y position
        INC     L               ; next position
        ADD     IX,DE           ; next elevator
        DJNZ    $2734           ; Next B

        RET

; called from #271E

        LD      A,($6398)       ; load A with elevator riding indicator
        AND     A               ; is mario riding an elevator?
        RET     Z               ; no, return

        LD      A,($6216)       ; load A with jumping status
        AND     A               ; is mario jumping ?
        RET     NZ              ; yes, return

; arrive here when mario riding on either elevator

        LD      A,($6203)       ; load A with mario's X position. eg 37 for first, 75 for second
        CP      $2C             ; position < left edge of first elevator ?
        JP      C,$2766         ; yes, jump ahead

        CP      $43             ; else is position < right edge of first elevator ?
        JP      C,$276F         ; yes, jump ahead for first elevator checks

        CP      $6C             ; else is position < left edge of second elevator?
        JP      C,$2766         ; yes, jump ahead

        CP      $83             ; else is position < right edge of second elevator ?
        JP      C,$2787         ; yes, jump ahead for second elevator checks

; arrive here when mario jumps off of an elevator ?

        XOR     A               ; A := 0
        LD      ($6398),A       ; clear elevator riding indicator
        INC     A               ; A := 1
        LD      ($6221),A       ; store into mario falling indicator ?
        RET

; arrive here when mario riding on first elevator

        LD      A,($6205)       ; load A with Mario's Y position
        CP      $71             ; top of elevator ? (death)
        JP      C,$277F         ; yes, die

        DEC     A               ; else decrement (move mario up)
        LD      ($6205),A       ; store into Mario's Y position
        LD      ($694F),A       ; store into mario sprite Y value
        RET

        XOR     A               ; A := 0
        LD      ($6200),A       ; Make mario dead
        LD      ($6398),A       ; clear elevator riding indicator
        RET

; riding on second elevator

        LD      A,($6205)       ; load A with mario's Y position
        CP      $E8             ; at bottom of elevator ? (death)
        JP      NC,$277F        ; yes, set death and return

        INC     A               ; else increment (move mario down)
        LD      ($6205),A       ; store back into mario's Y position
        LD      ($694F),A       ; store into mario sprite Y value
        RET

; called from #2722
; moves elevators ???

        LD      B,$06           ; for B = 1 to 6 (for each elevator)
        LD      DE,$0010        ; load DE with offset
        LD      IX,$6600        ; load IX with start of sprite addr. for elevators

        BIT     0,(IX+$00)      ; is this elevator active?
        JP      Z,$27C2         ; no, skip ahead and loop for next

        BIT     3,(IX+$0D)      ; is this elevator moving down ?
        JP      Z,$27C7         ; yes, skip ahead

; elevator is moving up

        LD      A,(IX+$05)      ; load A with elevator Y position
        DEC     A               ; decrement (move up)
        LD      (IX+$05),A      ; store result
        CP      $60             ; at top of elevator ?
        JP      NZ,$27C2        ; no, skip next 2 steps

        LD      (IX+$03),$77    ; set X position to right side of elevators
        LD      (IX+$0D),$04    ; set direction to down

        ADD     IX,DE           ; add offset for next elevator
        DJNZ    $27A0           ; next B
        RET

; elevator is moving down

        LD      A,(IX+$05)      ; load A with elevator Y position
        INC     A               ; increase (move down)
        LD      (IX+$05),A      ; store result
        CP      $F8             ; at bottom of shaft ?
        JP      NZ,$27C2        ; no, loop for next

        LD      (IX+$00),$00    ; yes, make this elevator inactive
        JP      $27C2           ; jump back and loop for next elevator

; called from #2725

; [IF elevator_counter <> 0 THEN ( elevator_counter--  ; RET ) ELSE (

        LD      HL,$62A7        ; load HL with elevator counter address
        LD      A,(HL)          ; load A with elevator counter
        AND     A               ; == 0 ?
        JP      NZ,$2806        ; no, skip ahead, decrease counter and return

        LD      B,$06           ; for B = 1 to 6 elevators
        LD      IX,$6600        ; load IX with sprite addr. for elevators

        BIT     0,(IX+$00)      ; is this elevator active ?
        JP      Z,$27F4         ; no, skip ahead and reset

        ADD     IX,DE           ; add offset for next elevator
        DJNZ    $27E8           ; next B
        RET

        LD      (IX+$00),$01    ; make elevator active
        LD      (IX+$03),$37    ; set X position to left side shaft
        LD      (IX+$05),$F8    ; set Y position to bottom of shaft
        LD      (IX+$0D),$08    ; set direction to up
        LD      (HL),$34        ; reset elevator counter to #34

        DEC     (HL)            ; decrease elevator counter
        RET

; called from main routine at $19B3
; checks for collisions with hostiles sprites

        LD      IY,$6200        ; load IY with start of mario sprite
        LD      A,($6205)       ; load A with mario's Y position
        LD      C,A             ; copy to C
        LD      HL,$0407        ; H := 4, L := 7
        CALL    $286F           ; checks for collisions based on the screen.  A := 1 if collision, otherwise zero
        AND     A               ; was there a collision ?
        RET     Z               ; no, return

; mario collided with hostile sprite

        DEC     A               ; else A := 0
        LD      ($6200),A       ; store into mario life indicator, mario is dead
        RET

; called from main routine at $19B6

        LD      B,$02           ; for B = 1 to 2 hammers
        LD      DE,$0010        ; load DE with counter offset
        LD      IY,$6680        ; load IY with sprite address start ?

        BIT     0,(IY+$01)      ; is the hammer being used ?
        JP      NZ,$2832        ; yes, then do stuff ahead

        ADD     IY,DE           ; else look at next one
        DJNZ    $2826           ; next B

        RET

; hammer is active, do stuff for it

        LD      C,(IY+$05)      ; C := +5 (X position???)
        LD      H,(IY+$09)      ; H := +9 (size?  width?)
        LD      L,(IY+$0A)      ; L := +A (size?  height?)
        CALL    $286F           ; checks for collisions based on the screen.  A := 1 if collision, otherwise zero
        AND     A               ; was there a collision?
        RET     Z               ; no, return

; hammer hit something

        LD      ($6350),A       ; store A into item hit indicator ???
        LD      A,($63B9)       ; load A with the number of total items checked for collision?
        SUB     B               ; subract the number of item hit ?
        LD      ($6354),A       ; store into ???
        LD      A,E             ; load A with offset for each item
        LD      ($6353),A       ; store into ???
        LD      ($6351),IX      ; store IX into ???
        RET

; called when mario jumping, checks for items being jumped over
; arrive at apex of jump
; called from #1C20

        LD      IY,$6200        ; load IY with start of mario array
        LD      A,($6205)       ; load A with Mario's Y position
        ADD     A,$0C           ; add #0C (12 decimal)
        LD      C,A             ; copy to C
        LD      A,(InputState)  ; load A with copy of input (see RawInput). except when jump pressed, bit 7 is set momentarily.
        AND     $03             ; mask bits, now between 0 and 3
        LD      HL,$0508        ; H := #05, L := #08.  [H is the left-right window for jumping items, L is the up-down window?]
        JP      Z,$286B         ; if masked input was zero, skip next step

; player moving joystick left or right while jumping

        LD      HL,$1308        ; H := #13 (19 decimal) , L := #08. [ why is L set again ???]  [H is the left-right window, increased if joystick moved left or right]

        CALL    $3E88           ; check for items being jumped based on which screen this is [seems like a patch ?  what was original code? CALL #286F ?]
        RET


        ; 3E88  3A2762    LD      A,(#6227)     ; load A with screen number
        ; 3E8B  E5        PUSH    HL            ; save HL
        ; 3E8C  EF        RST     #28           ; jump to new location based on screen number

        ; data for above:

        ; 3E8D  00 00
        ; 3E8F  99 3E                           ; #3E99 - girders
        ; 3E91  B0 28                           ; #28B0 - pie
        ; 3E93  E0 28                           ; #28E0 - elevator
        ; 3E95  01 29                           ; #2901 - rivets



; called when hammer active from #283B - check for hammer collision with enemy sprites


        LD      A,($6227)       ; load A with screen number
        PUSH    HL              ; save HL

        RST     $28             ; jump to address below depending on screen:

        hex     00 00           ; unused
        hex     80 28           ; #2880 - girders
        hex     B0 28           ; #28B0 - conveyors
        hex     E0 28           ; #28E0 - elevators
        hex     01 29           ; #2901 - rivets
        hex     00 00           ; unused

; girders - check for collisions with barrels and fires and oil can

        POP     HL              ; restore HL
        LD      B,$0A           ; B := #0A (10 decimal).  one for each barrel
        LD      A,B             ; A := #0A
        LD      ($63B9),A       ; store counter for use later
        LD      DE,$0020        ; load DE with offset of #20
        LD      IX,$6700        ; load IX with start of barrels
        CALL    $2913           ; check for collisions with barrels
        LD      B,$05           ; B := 5
        LD      A,B             ; A := 5
        LD      ($63B9),A       ; store counter for use later
        LD      E,$20           ; E := #20
        LD      IX,$6400        ; load IX with start of fires
        CALL    $2913           ; check for collisions with fires
        LD      B,$01           ; B := 1
        LD      A,B             ; A := 1
        LD      ($63B9),A       ; store counter for use later
        LD      E,$00           ; E := #00
        LD      IX,$66A0        ; load IX with oil can fire location
        CALL    $2913           ; check for collision with oil can fire
        RET

; jump here from $3E8C when jumping/hammering ? on the pie factory

        POP     HL              ; restore HL
        LD      B,$05           ; B := 5 fires
        LD      A,B             ; A := 5 fires
        LD      ($63B9),A       ; store counter for use later
        LD      DE,$0020        ; load DE with offset
        LD      IX,$6400        ; load IX with start of fires
        CALL    $2913           ; check for collisions with fires
        LD      B,$06           ; B := 6
        LD      A,B             ; A := 6
        LD      ($63B9),A       ; store counter for use later
        LD      E,$10           ; E := #10
        LD      IX,$65A0        ; load IX with start of pies
        CALL    $2913           ; check for collisions with pies
        LD      B,$01           ; B := 1
        LD      A,B             ; A := 1
        LD      ($63B9),A       ; store counter for use later
        LD      E,$00           ; E := 0
        LD      IX,$66A0        ; load IX with oil can address
        CALL    $2913           ; check for collision with oil can fire
        RET

; jump here from $2873 or $3E8C when on the elevators

        POP     HL              ; restore HL
        LD      B,$05           ; B := 5
        LD      A,B             ; A := 5
        LD      ($63B9),A       ; store counter for use later
        LD      DE,$0020        ; load offset
        LD      IX,$6400        ; load start of addresses for fires
        CALL    $2913           ; check for collisions with fires
        LD      B,$0A           ; B := #0A
        LD      A,B             ; A := #0A
        LD      ($63B9),A       ; store counter for use later
        LD      E,$10           ; E := #10
        LD      IX,$6500        ; load IX with start of addresses for springs
        CALL    $2913           ; check for collisions with springs
        RET

; jump here from $3E8C when on the rivets
; check for collisions with firefoxes and squares next to kong

        POP     HL              ; restore HL
        LD      B,$07           ; B := 7
        LD      A,B             ; A := 7
        LD      ($63B9),A       ; store 7 into counter for use later
        LD      DE,$0020        ; load DE with offset
        LD      IX,$6400        ; load IX with start of firefox arrays
        CALL    $2913           ; check for collisions with firefoxes/squares
        RET

; core routine gets called a lot
; uses IX and DE and IY
; uses B for loop counter
; uses C for a memory location start
; HL are used
; seems to return a value in A as either 0 or 1
; check for sprite collision ???


        PUSH    IX              ; push IX to stack

; start of loop

        BIT     0,(IX+$00)      ; is this sprite active?
        JP      Z,$294C         ; no, add offset in DE and loop again

        LD      A,C             ; no, load A with C
        SUB     (IX+$05)        ; subtract the Y value of item 2
        JP      NC,$2925        ; if no carry, skip next step

        NEG                     ; A = 0 - A (negate with 2's complement)

        INC     A               ; A := A + 1
        SUB     L               ; subtract L [???]
        JP      C,$2930         ; on carry, skip next 2 steps

        SUB     (IX+$0A)        ; subtract +#0A value height???
        JP      NC,$294C        ; if no carry, add offset in DE and loop again

        LD      A,(IY+$03)      ; load A with X position of item 1
        SUB     (IX+$03)        ; subtract X position of item 2.  carry?
        JP      NC,$293B        ; no, skip next step

        NEG                     ; A = 0 - A (negate with 2's complement)

        SUB     H               ; subtract H
        JP      C,$2945         ; on carry, skip next 2 steps

        SUB     (IX+$09)        ; subtract +#09 value width???
        JP      NC,$294C        ; if no carry, add offset in DE and loop again

; else a collision

        LD      A,$01           ; A := 1 - code for collision
        POP     IX              ; restore IX
        INC     SP
        INC     SP              ; adjust SP for higher level subroutine
        RET                     ; ret to higher subroutine

        ADD     IX,DE           ; add offset for next sprite
        DJNZ    $2915           ; Next B

        XOR     A               ; A := 0 - code for no collision
        POP     IX              ; restore IX
        RET

; arrive here when jumping at top of jump, check for hammer grab

        LD      A,$0B           ; A := #0B = 1011 binary
        RST     $30             ; if level is elevators RET from this sub now.  no hammers on elevators.
        CALL    $2974           ; load A with 1 if hammer is grabbed, 0 if no grab
        LD      ($6218),A       ; store into hammer grabbing indicator
        RRCA
        RRCA                    ; rotate right twice.  if hammer grabbed, A is now #40
        LD      ($6085),A       ; play sound for bonus
        LD      A,B             ; A := B .  this indicates which hammer was grabbed if any
        AND     A               ; was a hammer grabbed?
        RET     Z               ; no, return

        CP      $01             ; was lower hammer on girders & conveyors, or upper hammer on rivets, grabbed?
        JP      Z,$296F         ; yes, skip next 2 steps

        LD      (IX+$01),$01    ; set 1st hammer active
        RET

        LD      (IX+$11),$01    ; set 2nd hammer active
        RET

; called from #2957 above
; check for hammer grab ?

        LD      IY,$6200        ; load IY with start of mario sprite values
        LD      A,($6205)       ; load A with mario's Y position
        LD      C,A             ; copy to C
        LD      HL,$0408        ; H := 4, L := 8
        LD      B,$02           ; B := 2 for the 2 hammers (?)
        LD      DE,$0010        ; offset for each hammer
        LD      IX,$6680        ; load IX with start of hammer sprites ?
        CALL    $2913           ; check for collision with hammer
        RET

; called from #323E
; fire moving.  check for girder edge near fire
; sets A := 0 if fire is free to move
; sets A := 1 if fire is next to edge of girder

        LD      HL,($63C8)      ; load HL with address of this fire
        LD      A,L             ; A := L
        ADD     A,$0E           ; add #E
        LD      L,A             ; store result.  HL now has the fire's X position
        LD      D,(HL)          ; load D with the fire's X position
        INC     L               ; next HL = fire's Y position
        LD      A,(HL)          ; load A with the fire's Y position
        ADD     A,$0C           ; add #C to offset
        LD      E,A             ; store into E
        EX      DE,HL           ; DE <> HL
        CALL    $2FF0           ; convert HL into VRAM memory location
        LD      A,(HL)          ; load A with the screen element at this location
        CP      $B0             ; > #B0 ?
        JP      C,$29AC         ; yes, skip next 5 steps, set A := 1 and return

        AND     $0F             ; else mask bits, now between 0 and #F
        CP      $08             ; <= 8 ?
        JP      NC,$29AC        ; yes, skip next 2 steps, set A := 1 and return

        XOR     A               ; A := 0 = clear signal
        RET

        LD      A,$01           ; A := 1 = fire near girder edge
        RET

; called from $2B23 during a jump

        LD      A,$04           ; A := 4 = 0100
        RST     $30             ; only continue here if we are on the elevators, else RET

        LD      IY,$6200        ; load IY with mario's array
        LD      A,($6205)       ; load A with mario's Y position
        LD      C,A             ; copy to C
        LD      HL,$0408        ; H := 4, L := 8
        CALL    $2A22           ; check for collision with elevators
        AND     A               ; was there a collision?
        JP      Z,$2A20         ; no, load B with #00 and return

; arrive here when landing near an elevator
; B has the index of the elevator that we hit

        LD      A,$06           ; A := 6
        SUB     B               ; subtract B.  zero ?
        JP      Z,$29D0         ; yes, skip ahead

        ADD     IX,DE           ; else add offset for next elevator
        DEC     A               ; decrease counter
        JP      $29C7           ; loop again

; IX now has the array start for the elevator mario trying to land on

        LD      A,(IX+$05)      ; load A with elevator's height Y position
        SUB     $04             ; subtract 4
        LD      D,A             ; copy to D
        LD      A,($620C)       ; load A with mario's jump height ?
        ADD     A,$05           ; add 5
        CP      D               ; compare.  is mario high enough to land ?
        JP      NC,$29EE        ; no, skip ahead

        LD      A,D             ; load A with elevator's height - 4
        SUB     $08             ; subtract 8
        LD      ($6205),A       ; store A into Mario's Y position
        LD      A,$01           ; A := 1
        LD      B,A             ; B := 1
        LD      ($6398),A       ; set elevator riding indicator ?
        INC     SP
        INC     SP              ; increase SP twice so the RET skips one level
        RET                     ; rets to higher subroutine (#1C08)

        LD      A,($620C)       ; load A with mario's jump height
        SUB     $0E             ; subtract #0E (14 decimal)
        CP      D               ; compare to elevator height - 4. is mario hitting his head on the bottom of the elevator ?
        JP      NC,$2A1B        ; if so, mario is dead.  set dead and return.

        LD      A,($6210)       ; load A with mario's jump direction.
        AND     A               ; == 0 ?  Is mario jumping to the right ?
        LD      A,($6203)       ; load A with mario's X position
        JP      Z,$2A08         ; if jumping to the right then skip ahead

        OR      $07             ; else mask bits, turn on all 3 lower bits
        SUB     $04             ; subtract 4
        JP      $2A0E           ; skip next 3 steps

        SUB     $08             ; subtract 8
        OR      $07             ; turn on all 3 lower bits
        ADD     A,$04           ; add 4

; used when riding an elevator

        LD      ($6203),A       ; set mario's X position
        LD      ($694C),A       ; set mario's sprite X position
        LD      A,$01           ; A := 1
        LD      B,$00           ; B := 0
        INC     SP
        INC     SP              ; set stack to next higher subroutine return
        RET                     ; ret to higher level (#1C08)

; arrive from $29F4 when mario dies trying to jump onto elevator

        XOR     A               ; A := 0
        LD      ($6200),A       ; set mario dead
        RET

; arrive from #29C1

        LD      B,A             ; B := 0
        RET

; called from #29BD

        LD      B,$06           ; B := 6
        LD      DE,$0010        ; load DE with offset
        LD      IX,$6600        ; load IX with elevator array start
        CALL    $2913           ; check for collision with elevators
        RET

; sub called during a barrel roll from #2057
; only called when barrel going over edge to next girder or for crazy barrel ?
; returns with A loaded with 0 or 1 depending on ???

        LD      A,(IX+$03)      ; load A with Barrel's X position
        LD      H,A             ; Store into H
        LD      A,(IX+$05)      ; load A with Barrel's Y position
        ADD     A,$04           ; Add 4
        LD      L,A             ; Store in L
        PUSH    HL              ; Save HL to stack
        CALL    $2FF0           ; convert HL into VRAM memory address
        POP     DE              ; load DE with HL = barrel position X,Y
        LD      A,(HL)          ; load A with the graphic at this location


; B0 = Girder with hole in center used in rivets screen
; B6 = white line on top
; B7 = wierd icon?
; B8 = red line on bottom
; C0 - C7 = girder with ladder on bottom going up
; D0 - D7 = ladder graphic with girder under going up and out
; DD = HE  (help graphic)
; DE = EL
; DF = P!
; E1 - E7 = grider graphic going up and out
; EC - E8 = blank ?
; EF = P!
; EE = EL (part of help graphic)
; ED = HE (help graphic)
; F6 - F0 = girder graphic in several vertical phases coming up from bottom
; F7 = bottom yellow line
; FA - F8 = blank ?
; FB = ? (actually a question mark)
; FC = right red edge
; FD = left red edge
; FE = X graphic
; FF = Extra Mario Icon


        CP      $B0             ; < #B0 ?
        JP      C,$2A7B         ; yes, skip ahead,  clear A to 0 and return - nothing to do.

        AND     $0F             ; mask bits.  now between 0 and #F
        CP      $08             ; < 8 ?
        JP      NC,$2A7B        ; no, skip ahead, clear A to 0 and return - nothing to do.

        LD      A,(HL)          ; load A with graphic at this location
        CP      $C0             ; == girder with ladder on bottom going up ?
        JP      Z,$2A7B         ; yes, clear A to 0 and return - nothing to do.

        JP      C,$2A69         ; < this value ?  if so, skip ahead

        CP      $D0             ; > ladder graphic with girder under going up and out ?
        JP      C,$2A6E         ; yes, skip ahead to handle

        CP      $E0             ; > grider graphic going up and out ?
        JP      C,$2A63         ; yes, skip next 2 steps

        CP      $F0             ; > girder graphic in several vertical phases coming up from bottom ?
        JP      C,$2A6E         ; yes, skip ahaed to handle

; arrive when crazy barrel hitting top of girder ?

        AND     $0F             ; mask bits, now between 0 and #F
        DEC     A               ; decrease
        JP      $2A72           ; skip ahead

; arrive when ???

        LD      A,$FF           ; A := #FF
        JP      $2A72           ; skip next 2 steps

; arrive when ???

        AND     $0F             ; mask bits, now between 0 and #F
        SUB     $09             ; subtract 9

; other conditions all arrive here
; A is loaded with a number between #F6 and #E

        LD      C,A             ; C := A
        LD      A,E             ; A := E = barrel X position
        AND     $F8             ; mask bits.  lower 3 bits are cleared
        ADD     A,C             ; add C
        CP      E               ; compare to barrel's X position.  less?
        JP      C,$2A7D         ; yes, skip next 2 steps

        XOR     A               ; A := 0
        RET

        SUB     $04             ; subtract 4
        LD      (IX+$05),A      ; store A into Y position
        LD      A,$01           ; A := 1
        RET

; called from main routine at $19A1

        LD      A,($6215)       ; load ladder status
        AND     A               ; is mario on a ladder ?
        RET     NZ              ; yes, return

        LD      A,($6216)       ; load jumping status
        AND     A               ; is mario jumping ?
        RET     NZ              ; yes, return

        LD      A,($6398)       ; load A with elevator status
        CP      $01             ; is mario riding an elevator?
        RET     Z               ; yes, return

        LD      A,($6203)       ; load A with mario's X position
        SUB     $03             ; subtract 3
        LD      H,A             ; store into H
        LD      A,($6205)       ; load A with Mario's Y position
        ADD     A,$0C           ; add #0C = 13 decimal
        LD      L,A             ; store into L
        PUSH    HL              ; save to stack
        CALL    $2FF0           ; load HL with screen position of mario's feet
        POP     DE              ; restore , DE now has the sprite X,Y addresses
        LD      A,(HL)          ; load A with the screen item at mario's feet
        CP      $B0             ; > #B0 ?
        JP      C,$2AB4         ; yes, skip next 4 steps

        AND     $0F             ; else mask bits, now between 0 and #F
        CP      $08             ; > 8 ?
        JP      NC,$2AB4        ; no, skip next step

        RET                     ; else return

; arrive when mario near an [left?] edge

        LD      A,D             ; load A with mario's X position
        AND     $07             ; mask bits, now between 0 and 7.  zero?
        JP      Z,$2ACD         ; yes, skip ahead, mario is falling

        LD      BC,$0020        ; BC := 20
        SBC     HL,BC           ; subtract from HL.  now HL is the next column?
        LD      A,(HL)          ; load A with the screen element of this location
        CP      $B0             ; > #B0 ?
        JP      C,$2ACD         ; yes, skip ahead, mario is falling

        AND     $0F             ; else mask bits, now betwen 0 and F
        CP      $08             ; > 8 ?
        JP      NC,$2ACD        ; no, mario is falling, skip ahead
        RET

; mario is falling

        LD      A,$01           ; A := 1
        LD      ($6221),A       ; store into mario falling indicator
        RET

; called from #25FE

        LD      A,($6203)       ; load A with mario's X position
        LD      B,A             ; copy to B
        LD      A,($6205)       ; load A with mario's Y position
        CP      $50             ; is mario on upper level ?
        JP      Z,$2AEA         ; yes, skip ahead

        CP      $78             ; mario on upper pie tray?
        JP      Z,$2AF6         ; yes, skip ahead

        CP      $C8             ; mario on lower pie tray ?
        JP      Z,$2AF0         ; yes, skip ahead

        RET                     ; else return

        LD      A,($63A3)       ; load A with top conveyor direction vector [why?  level complete here?]
        JP      $2B02           ; skip ahead

        LD      A,($63A6)       ; load A with pie direction lower level
        JP      $2B02           ; skip ahead

        LD      A,B             ; load A with mario X position
        CP      $80             ; is mario on the left side of the fire?
        LD      A,($63A5)       ; load A with upper right pie tray vector
        JP      NC,$2B02        ; no, skip next step

        LD      A,($63A4)       ; else load A with upper left pie tray vector

        ADD     A,B             ; add vector to mario's X position
        LD      ($6203),A       ; set mario's X position
        LD      ($694C),A       ; set mario's sprite X position
        CALL    $241F           ; loads DE with something depending on mario's position
        LD      HL,$6203        ; load HL with mario's X position
        DEC     E               ; E == 1 ?
        JP      Z,$2B18         ; yes, skip ahead

        DEC     D               ; else D == 1 ?
        JP      Z,$2B1A         ; yes, skip ahead
        RET

        DEC     (HL)            ; decrease mario's X position
        RET

        INC     (HL)            ; increase
        RET

; called from #1C05

        LD      IX,$6200        ; set IX for mario's array
        CALL    $2B29           ; do stuff for jumping.  certain crieria will set A and B and return without the rest of this sub.
        CALL    $29AF           ; handle jump stuff for elevators
        XOR     A               ; A := 0
        LD      B,A             ; B := 0
        RET

; arrive here when a jump is in progress
; called from #2B20 above

        LD      A,($6227)       ; load A with screen number
        DEC     A               ; are we on the girders?
        JP      NZ,$2B53        ; No, skip ahead

; jump on girders

        LD      A,($6203)       ; load A with mario's x position
        LD      H,A             ; copy to H
        LD      A,($6205)       ; load A with mario's y position
        ADD     A,$07           ; add 7 to y position
        LD      L,A             ; copy to L
        CALL    $2B9B           ; check for ???
        AND     A               ; == 0 ?
        JP      Z,$2B51         ; yes, skip ahead and return

        LD      A,E             ; A := E
        SUB     C               ; subtract C (???)
        CP      $04             ; < 4 ?
        JP      NC,$2B74        ; no, skip ahead, clear A and B, and return

        LD      A,C             ; A := C
        SUB     $07             ; subtract 7
        LD      ($6205),A       ; store A into mario's Y position
        LD      A,$01           ; A : = 1
        LD      B,A             ; B := 1

        POP     HL              ; move stack pointer back 1 level
        RET                     ; ret to higher sub (EG #1C08)

; arrive from $2B2D when jumping, not on girders, via call from #2B20

        LD      A,($6203)       ; load A with mario X position
        SUB     $03             ; subtract 3
        LD      H,A             ; store into H
        LD      A,($6205)       ; load A with mario's Y position
        ADD     A,$07           ; add 7
        LD      L,A             ; store into L
        CALL    $2B9B           ; check for ???
        CP      $02             ; A == 2 ?
        JP      Z,$2B7A         ; yes, skip ahead

        LD      A,D             ; A := D
        ADD     A,$07           ; add 7
        LD      H,A             ; H := A
        LD      L,E             ; L := E
        CALL    $2B9B           ; check for ???
        AND     A               ; A == 0 ?
        RET     Z               ; yes, return

        JP      $2B7A           ; else skip ahead

        LD      A,$00           ; A := 0
        LD      B,$00           ; B := 0
        POP     HL              ; move stack pointer to return to higher sub
        RET

        LD      A,($6210)       ; load A with mario's jump direction
        AND     A               ; jumping to the right ?
        LD      A,($6203)       ; load A with mario's X position
        JP      Z,$2B8B         ; if jumping right then skip next 3 steps

        OR      $07             ; mask bits, turn on lower 3 bits
        SUB     $04             ; subtract 4
        JP      $2B91           ; skip ahead

        SUB     $08             ; subtract 8
        OR      $07             ; mask bits, turn on lower 3 bits
        ADD     A,$04           ; add 4

        LD      ($6203),A       ; set mario's X position
        LD      ($694C),A       ; set mario's sprite X position
        LD      A,$01           ; A := 1
        POP     HL              ; move stack pointer to return to higher sub
        RET

; called from $2B3A and $2B6C and #2B5F above

        PUSH    HL              ; save HL
        CALL    $2FF0           ; convert HL into VRAM address
        POP     DE              ; restore into DE
        LD      A,(HL)          ; load A with the screen item in VRAM
        CP      $B0             ; > #B0 ? (???)
        JP      C,$2BD9         ; yes, skip ahead, set results to zero and return

        AND     #0F
        CP      #08
        JP      NC,$2BD9        ; yes, skip ahead, set results to zero and return

        LD      A,(HL)          ; load A with the screen item in VRAM
        CP      $C0             ; == #C0 ?
        JP      Z,$2BD9         ; yes, skip ahead, set results to zero and return

        JP      C,$2BDC         ; < #C0 ?  Yes, skip ahead to handle

        CP      $D0             ; < #D0 ?
        JP      C,$2BCB         ; yes, skip ahead to handle

        CP      $E0             ; < #E0 ?
        JP      C,$2BC5         ; yes, skip ahead to handle

        CP      $F0             ; < #F0 ?
        JP      C,$2BCB         ; yes, skip ahead to handle (same as < #D0 )

; when landing or jumping from a girder ???

        AND     $0F             ; mask bits, now between 0 and #F
        DEC     A               ; decrease.  now #FF or between 0 and #E
        JP      $2BCF           ; skip ahead

; when jumping his head (harmlessly) into a girder above him?

        AND     $0F             ; mask bits, now between 0 and #F
        SUB     $09             ; subtract 9.  now between #F7 and 6

        LD      C,A             ; C := A
        LD      A,E             ; A := E = original Y location
        AND     $F8             ; mask bits.  we dont care about 3 least sig. bits
        ADD     A,C             ; add C
        LD      C,A             ; C := A
        CP      E               ; < E (original Y location) ?
        JP      C,$2BE1         ; no, skip ahead

; mario is jumping clear, nothing in his way

        XOR     A               ; A := 0
        LD      B,A             ; B := 0
        RET

; mario is jumping and about to land on a conveyor or a girder on the rivets

        LD      A,E             ; A := E = original Y location
        AND     $F8             ; mask bits.  we dont care about 3 least sig. bits
        DEC     A               ; decrease
        LD      C,A             ; copy to C

; mario landing or his head passing through girder above

        LD      A,($620C)       ; load A with mario's jump height
        SUB     (IX+$05)        ; subtract the item's Y position (???) [EG IX = #6200 , so this is mario's Y position)
        ADD     A,E             ; add E (original Y position)
        CP      C               ; == C ?
        JP      Z,$2BEF         ; yes, skip next step

; mario head passing or landing on a noneven girder

        JP      NC,$2BF8        ; < C ?  no, skip next 4 steps

;  arrive when landing

        LD      A,C             ; A := C = original location masked
        SUB     $07             ; subtract 7 to adjust for mario' height
        LD      ($6205),A       ; store A into mario's Y position
        JP      $2BFD           ; skip next 3 steps

; arrive when mario has his head passing through girder above

        LD      A,$02           ; A := 2
        LD      B,$00           ; B := 0
        RET

; arrive when ?

        LD      A,$01           ; A := 1
        LD      B,A             ; B := 1
        POP     HL
        POP     HL              ; set stack pointer to return to higher subs
        RET

; called from main routine at $1989

        LD      A,$01                   ; \ Return if screen is not barrels
        RST     $30                     ; /
        RST     $10                     ; Ret if Mario is not alive

        LD      A,($6393)               ; \  Return if we are already in the process of deploying a barrel, no need to deploy another one
        RRCA                            ;  |
        RET     c                       ; /

        LD      A,($62B1)               ; \  Return if bonus timer is 0, no more barrels are deployed at this time
        AND     A                       ;  |
        RET     Z                       ; /

        LD      c,A                     ; otherwise load C with current timer value
        LD      A,($62B0)               ; load a with initial clock value
        SUB     $02                     ; subtract 2
        CP      c                       ; compare with C = current timer
        JP      C,$2C7B                 ; if carry, jump ahead - we are within first 2 clicks of the round - special barrels for this.

        LD      A,($6382)               ; else load A with crazy / blue barrel indicator
        BIT     1,A                     ; test bit 1 - is this the second barrel after the first crazy ?
        JP      NZ,$2C86                ; if it is, then deploy normal barrel; this barrel is never crazy.

        LD      A,($6380)               ; if not, then load A with difficulty from 1 to 5
        LD      B,A                     ; For B = 1 to difficulty
        LD      A,(FrameCounter)        ; load A with timer value.  this clock counts down from #FF to 00 over and over...
        AND     $1F                     ; zero out left 3 bits.  the result is between 0 and #1F

        CP      B                       ; compare with Loop counter B (between 1 and 5) ... is higher as time decreases
        JP      Z,$2C33                 ; if it equal then jump ahead to check for a crazy barrel

        DJNZ    $2C2C                   ; else Next B

        RET                             ; Ret without crazy barrel (?)

; chances of arriving here depend on difficulty D/32 chance .  high levels this is 5/32 = 16%

        LD      A,($62B0)       ; load A with initial clock value
        SRL     A               ; Shift Right (div 2)
        CP      C               ; is the current timer value < 1/2 initial clock value ?
        JP      C,$2C41         ; NO, skip next 3 steps

        LD      A,(RngTimer2)   ; Yes, Load A with this timer value (random)
        RRCA                    ; Test Bit 1 of this
        RET     NC              ; If bit 1 is not set, return . this gives 50% extra chance of no crazy barrel when clock is getting low

        CALL    $0057           ; else load A with a random number

; hack to increase crazy barrels
; 2C41  3E 00          LD A, $00
; 2C43  00             NOP
; hack to increase crazy barrels:
; 2C44 E600    AND     $00             ; mask all 4 bits to zero
;

        AND     $0F             ; mask out left 4 bits to zero.  A becomes a number between 0 and #F
        JP      NZ,$2C86        ; If result is not zero, deploy a normal barrel.  this routine sets #6382 to 0,
                                ; loads A with 3 and returns to #2C4F

; else get a crazy barrel
; can arrive here from $2C7E = first click of round is always crazy barrel

        LD      A,$01           ; else A := 1 = crazy barrel code

; arrive here from second barrel that is not crazy.  A is preloaded with 2.  From #2C83

        LD      ($6382),A       ; set a barrel in motion for next barrel, bit 1=crazy, 2 = second barrel which is always normal, 0 for normal barrel
        INC     A               ; Increment A for the deployment

        LD      ($638F),A       ; store A into the state of the barrel deployment between 3 and 0
        LD      A,$01           ; A := 1
        LD      ($6392),A       ; set barrel deployment indicator
        LD      A,($62B2)       ; load A with blue barrel counter
        CP      C               ; compare with current timer
        RET     NZ              ; ret if not equal

        SUB     $08             ; if equal then this will be a blue barrel.  decrement A by 8
        LD      ($62B2),A       ; put back into blue barrel counter
        LD      DE,$0020        ; now check if all 5 fires are out
        LD      HL,$6400        ; #6400 by 20's contian 1 if these fires exist

        LD      B,$05           ; FOR B = 1 to 5

        LD      A,(HL)          ; get fire status
        AND     A               ; is this fire onscreen?
        JP      Z,$2C72         ; no, skip next 3 steps; we don't have 5 fires onscreen and therefore have room for a blue barrel

        ADD     HL,DE           ; yes, add #20 offset to test next fire and loop again
        DJNZ    $2C69           ; next B

        RET                     ; not a blue barrel, return

        LD      A,($6382)       ; load A with crazy/blue barrel indicator
        or      $80             ; or with #80  - set leftmost bit on to indicate blue barrel is next
        LD      ($6382),A       ; store into crazy/blue barrel indicator
        RET                     ; ret with blue barrel

; we arrive here if timer is within first 2 clicks when deploying a barrel from #2C18

        ADD     A,$02           ; A := A + 2 (A had the initial clock value -2, now it has the initial clock value)
        CP      C               ; compare to current timer value - are we starting this round now?
        JP      Z,$2C49         ; yes, do a crazy barrel

        LD      A,$02           ; else A := 2 for the second barrel; it is always normal
        JP      $2C4B           ; jump back and continue deployment

; arrive here when the second barrel is being deployed?
; from #2C20

        XOR     A               ; A := 0
        LD      ($6382),A       ; barrel indicator to 0 == normal barrel
        LD      A,$03           ; A := 3 -- use for upcoming deployement indicator == position #3
        JP      $2C4F           ; Jump back

; called from main routine $1986

        LD      A,$01           ; A := 1 = code for girders
        RST     $30             ; if screen is girders, continue.  else RET
        RST     $10             ; if mario is alive, continue.  else RET
        LD      A,($6393)       ; load A with barrel deployment indicator
        RRCA                    ; is a barrel being deployed ?
        JP      C,$2D15         ; yes, skip ahead

        LD      A,($6392)       ; else load A with other barrel deployment indicator
        RRCA                    ; deployed ?
        RET     NC              ; no, return

; else a barrel is being deployed

        LD      IX,$6700        ; load IX with start of barrel memory
        LD      DE,$0020        ; incrementer gets #20
        LD      B,$0A           ; For B = 1 to #0A (all 10 barrels)

        LD      A,(IX+$00)      ; load A with +0 indicator
        RRCA                    ; is this barrel already rolling ?
        JP      C,$2CB3         ; yes, then jump ahead and test next barrel

        RRCA                    ; else is this barrel already being deployed ?
        JP      NC,$2CB8        ; no, then jump ahead

        ADD     IX,DE           ; Increase to next barrel
        DJNZ    $2CA8           ; Next B

        RET

; arrive here when a barrel is being deployed

        LD      ($62AA),IX      ; save this barrel indicator into #62AA.  it is recalled at #2D55
        LD      (IX+$00),$02    ; set deployement indicator
        LD      D,$00           ; D := 0
        LD      A,$0A           ; A := #0A
        SUB     B               ; A = A - B ;  B has the number of the barrel A now will be 0 if this is the first barrel, #0A if the last
        ADD     A,A             ; A = A * 2
        ADD     A,A             ; A = A * 2 (A is now 4 times what it was)
        LD      E,A             ; copy this to E
        LD      HL,$6980        ; load HL with starting sprite address for the barrels
        ADD     HL,DE           ; Now add in offset depending on the barrel number ( will vary from 0 to #28 by 4's)
        LD      ($62AC),HL      ; store this info in #62AC. will vary from #80 to #A8
        LD      A,$01           ; A := 1
        LD      ($6393),A       ; set barrel deployment indicator
        LD      DE,$0501        ; load DE with task #5, parameter 1 update onscreen bonus timer and play sound & change to red if below 1000
        CALL    $309F           ; insert task
        LD      HL,$62B1        ; load bonus counter into HL
        DEC     (HL)            ; decrement bonus counter.  Is it zero?
        JP      NZ,$2Ce6        ; no, skip next 2 steps

        LD      A,$01           ; A := 1
        LD      ($6386),A       ; store into bonus timer out indicator

        LD      A,(HL)          ; load A with bonus counter
        CP      $04             ; bonus <= 400 ?
        JP      NC,$2Cf6        ; no, skip ahead

        LD      HL,$69A8        ; else load HL with extra barrels sprites
        ADD     A,A
        ADD     A,A             ; A := A * 4
        LD      E,A             ; copy to E
        LD      D,$00           ; D := 0.  DE now has offset based on timer
        ADD     HL,DE           ; compute which sprite to remove based on timer
        LD      (HL),D          ; clear the sprite

; IX holds 6700 +N*20 = start of barrel N info
; a barrel is being deployed

        LD      (IX+$07),$15    ; set barrel sprite value to #15
        LD      (IX+$08),$0B    ; set barrel color to #0B
        LD      (IX+$15),$00    ; set +15 indicator to 0 = normal barrel,  [1 = blue barrel]
        LD      A,($6382)       ; load A with Crazy/Blue barrel indicator
        RLCA                    ; is this a blue barrel ?
        JP      NC,$2D15        ; No blue barrel, then skip next 3 steps

; blue barrel

        LD      (IX+$07),$19    ; set sprite for blue barrel
        LD      (IX+$08),$0C    ; set sprite color to blue
        LD      (IX+$15),$01    ; set blue barrel indicator

        LD      HL,$62AF        ; load HL with deployment timer
        DEC     (HL)            ; count it down.  is the timer expired?
        RET     NZ              ; no, return

        LD      (HL),$18        ; else reset the counter back to #18
        LD      A,($638F)       ; load A with the deployment indiacator.  2 = kong grabbing, 1 = kong holding, 0 = deploying, 3 = kong empty
        AND     A               ; is a barrel being deployed right now?
        JP      Z,$2D51         ; yes, jump ahead

        LD      C,A             ; else copy A to C
        LD      HL,$3932        ; load HL with table data start
        LD      A,($6382)       ; load A with crazy/blue barrel indicator
        RRCA                    ; Is this a crazy barrel?
        JP      C,$2D2F         ; yes, skip next step

        DEC     C               ; no, Decrement C

        LD      A,C
        ADD     A,A
        ADD     A,A
        ADD     A,A
        LD      C,A
        ADD     A,A
        ADD     A,A
        ADD     A,C
        LD      E,A             ; A is #50 when barrel is crazy, #28 when normal
        LD      D,$00           ; D: = 0
        ADD     HL,DE           ; HL becomes #3982 when barrel is crazy, 395A when normal, 3932 when deploying all the way.  this will skip the final animation when dropping crazy barrel (?)
        CALL    $004E           ; update kong's sprites
        LD      HL,$638F        ; load HL with deployment indicator
        DEC     (HL)            ; Decrease indicator
        JP      NZ,$2D51        ; if indicator is not zero then jump ahead

        LD      A,$01           ; else A := 1
        LD      ($62AF),A       ; Store into ???
        LD      A,($6382)       ; load A with crazy/blue barrel indicator
        RRCA                    ; Is this a crazy barrel?
        JP      C,$2D83         ; yes, jump ahead and load HL with #39CC and store into #62A8 and #62A9 and resume on #2D54

        LD      HL,($62A8)      ; else load HL with (???)

        LD      A,(HL)          ; load A with value in HL.  crazy barrel this value is #BB
        LD      IX,($62AA)      ; load IX with Barrel start address saved above
        LD      DE,($62AC)      ; load DE with sprite variable start  EG #6980.  set in #2CCC
        CP      $7F             ; A == #7F ? (time to deploy out of kong's hands ?)
        JP      Z,$2D8C         ; yes, jump ahead

        LD      C,A             ; else copy A into C
        AND     $7F             ; mask out leftmost bit.  result between 0 and  #7F
        LD      (DE),A          ; store into sprite X position
        LD      A,(IX+$07)      ; load A with barrel sprite value
        BIT     7,C             ; test bit 7 of C
        JP      Z,$2D70         ; yes, skip next step

        XOR     $03             ; no, toggle the rightmost 2 bits

        INC     DE              ; DE now has sprite value
        LD      (DE),A          ; store new sprite
        LD      (IX+$07),A      ; store into barrel sprite value
        LD      A,(IX+$08)      ; load A with barrel color
        INC     DE              ; DE now has sprite color value
        LD      (DE),A          ; store color into sprite
        INC     HL              ; increase HL.  EG #39CD for crazy barrel
        LD      A,(HL)          ; load A with this value.  EG #4D for crazy barrel
        INC     DE              ; DE now has Y position
        LD      (DE),A          ; store into sprite Y position
        INC     HL              ; increase HL .  EG #39CE for crazy barrel
        LD      ($62A8),HL      ; store into 62A8.  EG 62A8 = CE, 62A9 = 39
        RET

; arrive here because this barrel is crazy from #2D4E

        LD      HL,$39CC        ; load HL with crazy barrel data

        ; 39CC  BB
        ; 39CD  4D

        LD      ($62A8),HL      ; Load #62A8 and #62A9 with #39 and #CC
        JP      $2D54           ; jump back

; jump here from #2D5F
; kong is releasing a barrel (?)

        LD      HL,$39C3        ; load HL with start of table data address
        LD      ($62A8),HL      ; store into ???
        LD      (IX+$01),$01    ; set crazy barrel indicator
        LD      A,($6382)       ; load A with crazy/blue barrel indicator

        RRCA                    ; roll right.  is this a crazy barrel?
        JP      C,$2DA5         ; yes, skip next 2 steps

        LD      (IX+$01),$00    ; no , clear crazy indicator
        LD      (IX+$02),$02    ; load motion indicator with 2 (rolling right)

        LD      (IX+$00),$01    ; barrel is now active
        LD      (IX+$0F),$01    ;
        XOR     A               ; A := 0
        LD      (IX+$10),A      ; clear this indicator (???)
        LD      (IX+#11),A
        LD      (IX+#12),A
        LD      (IX+#13),A
        LD      (IX+#14),A
        LD      ($6393),A       ; clear barrel deployment indicator
        LD      ($6392),A       ; clear barrel deployment indicator
        LD      A,(DE)          ; load A with kong hand sprite X position
        LD      (IX+$03),A      ; store in barrel's X position
        INC     DE
        INC     DE
        INC     DE              ; DE := DE + 3 = DE now has kong hand sprite Y position
        LD      A,(DE)          ; load A with kong hand Y position
        LD      (IX+$05),A      ; store in barrel's Y position
        LD      HL,$385C        ; load HL with table data start
        CALL    $004E           ; update kong's sprites
        LD      HL,$690B        ; load HL with start of Kong sprite
        LD      C,$FC           ; load c with offset of -4
        RST     $38             ; move kong
        RET

; deploys fireball/firefoxes
; Arrive here from main routine at #1995

        LD      A,$0A                   ; A := binary 1010 = code for rivets and conveyors
        RST     $30                     ; rets immediately on girders and elevators, else continue

        RST     $10                     ; only continue if mario alive
        LD      A,($6380)               ; \  load B with (internal_difficulty+1)/2 (get's value between 1 and 3)
        INC     A                       ;  |
        AND     A                       ;  | clear carry flag
        RRA                             ;  |
        LD      B,A                     ; /
        LD      A,($6227)               ; \  Increment B by 1 if we are on conveyors (to get value between 2 and 4)
        CP      $02                     ;  |
        JR      NZ,$2DEE                ;  |
        INC     b                       ; /

        LD      A,$FE                   ; \  Load A with #FF>>(B-1) (note the first rotate right doesn't count towards the bit shift because the
        SCF                             ;  | carry flag is set)
        RRA                             ;  |
        AND     A                       ;  | clear carry flag
        DJNZ    $2DF1                   ; /

        LD      B,A                     ; \  The result of the above indicates the interval in frames between deploying successive fires.
        LD      A,(FrameCounter)        ;  | On rivets we proceed every 256 frames for internal difficulty 1 and 2, 128 frames for internal difficulty
        AND     B                       ;  | 3 and 4 and 64 frames for internal difficulty 5. On conveyors these values are cut in half.
        RET     NZ                      ; /

        LD      A,$01                   ; Time to deploy a fire. Load A with 1
        LD      ($63A0),A               ; deploy a firefox/fireball
        LD      ($639A),A               ; set deployment indicator ?
        RET

; called from main routine at $198F
; called during the elevators.  used to move the bouncers ????

        LD      A,$04                   ; A := 4 (0100 binary) to check for elevators screen
        RST     $30                     ; if not elevators it will return to program

        RST     $10                     ; if mario is alive, continue, else RET

        LD      IX,$6500                ; load IX with start of bouncer memory area
        LD      IY,$6980                ; start of sprite memory for bouncers
        LD      B,$0A                   ; for B = 1 to #0A (ten) .  do for all ten sprites

        LD      A,(IX+$00)              ; load A with sprite status
        RRCA                            ; is the sprite active ?
        JP      NC,$2EA7                ; no, jump ahead and check to deploy a new one

        LD      A,(FrameCounter)        ; else load A with timer

; FrameCounter - Timer constantly counts down from FF to 00 and then FF to 00 again and again ... 1 count per frame
; result is that each of the boucners have their sprites changed once every 16 clicks, or every 1/16 of sec.?

        AND     $0F             ; mask out left 4 bits.  result between 0 and F
        JP      NZ,$2E29        ; if not zero, jump ahead..

        LD      A,(IY+$01)      ; load A with sprite value
        XOR     $07             ; flip the right 3 bits
        LD      (IY+$01),A      ; store result = change the bouncer fom open to closed

        LD      A,(IX+$0D)      ; load A with +D = either 1 or 4.  1 when going across , 4 when going down.
        CP      $04             ; is it == 4 ? (going down?)
        JP      Z,$2E84         ; yes, jump ahead

        INC     (IX+$03)        ; no, increase X position
        INC     (IX+$03)        ; increase X position again
        LD      L,(IX+#0E)
        LD      H,(IX+$0F)      ; load HL with table address for bouncer offsets of Y positions for each pixel across
        LD      A,(HL)          ; load table data
        LD      C,A             ; copy to C
        CP      $7F             ; == #7F ? (end code ?)
        JP      Z,$2E9C         ; yes, jump ahead, reset HL to #39AA, play bouncer sound, and continue at #2E4B

        INC     HL              ; next HL
        ADD     A,(IX+$05)      ; add item's Y position
        LD      (IX+$05),A      ; store into item's Y position

        LD      (IX+#0E),L
        LD      (IX+$0F),H      ; store the updated HL for next time
        LD      A,(IX+$03)      ; load A with X position
        CP      $B7             ; < #B7 ?
        JP      C,$2E6C         ; no, skip ahead

        LD      A,C             ; yes, A := C
        CP      $7F             ; == #7F (end code?)
        JP      NZ,$2E6C        ; no, skip ahead

        LD      (IX+$0D),$04    ; set +D to 4 (???)
        XOR     A               ; A := 0
        LD      ($6083),A       ; clear sound of bouncer
        LD      A,$03           ; load sound duration of 3
        LD      ($6084),A       ; play sound for falling bouncer

        LD      A,(IX+$03)      ; load A with X position
        LD      (IY+$00),A      ; store into sprite
        LD      A,(IX+$05)      ; load A with Y position
        LD      (IY+$03),A      ; store into sprite

        LD      DE,$0010        ; set offset to add
        ADD     IX,DE           ; next sprite (IX)
        LD      E,$04           ; E := 4
        ADD     IY,DE           ; next sprite (IY)
        DJNZ    $2E12           ; Next Bouncer

        RET

; arrive when bouncer is going straight down
; need to check when falling off bottom of screen

        LD      A,$03           ; A := 3
        ADD     A,(IX+$05)      ; add to Sprite's y position (move down 3)
        LD      (IX+$05),A      ; store result
        CP      $F8             ; are we at the bottom of screen?
        JP      C,$2E6C         ; No, jump back to program

        LD      (IX+$03),$00    ; yes, reset the sprite
        LD      (IX+$00),$00    ; reset
        JP      $2E6C           ; jump back to program

; arrive from #2E41

        LD      HL,$39AA        ; load HL with start of table data
        LD      A,$03           ; load sound duration of 3
        LD      ($6083),A       ; play sound for bouncer
        JP      $2E4B           ; jump back

; jump here from #2E16

        LD      A,($6396)       ; load A with bouncer release flag
        RRCA                    ; time to deploy a bouncer?
        JP      NC,$2E78        ; no, jump back

; deploy new bouncer

        XOR     A               ; A := 0
        LD      ($6396),A       ; reset bouncer release flag
        LD      (IX+$05),$50    ; set bouncer's Y position to #50
        LD      (IX+$0D),$01    ; set value to sprite bouncing across, not down
        CALL    $0057           ; load A with random number
        AND     $0F             ; mask bits, result is between 0 and #F
        ADD     A,$F8           ; add #F8 = result is now between #F8 and #07
        LD      (IX+$03),A      ; store A into initial X position for bouncer sprite
        LD      (IX+$00),$01    ; set sprite as active
        LD      HL,$39AA        ; values #39 and #AA to be inserted below.  #39AA is the start of table data for Y offsets to add for each movement
        LD      (IX+$0E),L      ;
        LD      (IX+$0F),H      ; store HL into +E and +F
        JP      $2E78           ; jump back

; arrive from main routine at $1998
; checks for hammer grabs etc ?

        LD      A,$0B           ; B = # 1011 binary
        RST     $30             ; continue here on girders, conveyors, rivets only.  elevators RET from this sub, it has no hammers.
        RST     $10             ; continue here only if mario is alive, otherwise RET from this sub

        LD      DE,$6A18        ; load DE with hardware address of hammer sprite
        LD      IX,$6680        ; load IX with software address of hammer sprite
        LD      A,(IX+$01)      ; load A with 1st hammer active indicator
        RRCA                    ; rotate right.  carry set?  (is this hammer active?)
        JP      C,$2EED         ; yes, skip next 2 steps

        LD      DE,$6A1C        ; else load DE with hardware address of 2nd hammer sprite
        LD      IX,$6690        ; load IX with 2nd hammer sprite

        LD      (IX+$0E),$00    ; store 0 into +#E == ???
        LD      (IX+$0F),$F0    ; store #F0 into +#F (???)
        LD      A,($6217)       ; load A with hammer indicator
        RRCA                    ; is the hammer already active?
        JP      NC,$2F97        ; no, skip ahead and check for new hammer grab

        XOR     A               ; A := 0
        LD      ($6218),A       ; store into grabbing the hammer indicator. the grab is complete.
        LD      HL,$6089        ; load HL with music address
        LD      (HL),$04        ; set music for hammer
        LD      (IX+$09),$06    ; set width ?
        LD      (IX+$0A),$03    ; set height ?
        LD      B,$1E           ; B := #1E
        LD      A,($6207)       ; load A with mario movement indicator/sprite value
        SLA     A               ; shift left.  is bit 7 on?
        JP      NC,$2F1B        ; no, skip next 2 steps

        OR      $80             ; turn on bit 7 in A
        SET     7,B             ; turn on bit 7 in B

        OR      $08             ; turn on bit 3 in A
        LD      C,A             ; copy to C
        LD      A,($6394)       ; load A with hammer timer
        BIT     3,A             ; is bit 3 on in A?
        JP      Z,$2F43         ; no, skip ahead

; animate the hammer

        SET     0,B
        SET     0,C
        LD      (IX+$09),$05    ; set width?
        LD      (IX+$0A),$06    ; set height?
        LD      (IX+$0F),$00    ;
        LD      (IX+$0E),$F0    ; set offset for left side of mario (#F0 == -#10)
        BIT     7,C             ; is mario facing left?
        JP      Z,$2F43         ; yes, skip next step

        LD      (IX+$0E),$10    ; set offset for right side of mario

        LD      A,C             ; A := C
        LD      ($694D),A       ; store into mario sprite value
        LD      C,$07           ; C := 7
        LD      HL,$6394        ; load HL with hammer timer
        INC     (HL)            ; increase.  at zero?
        JP      NZ,$2FB7        ; no skip ahead

; hammer is changing or ending

        LD      HL,$6395        ; load HL with hammer length.
        INC     (HL)            ; increase
        LD      A,(HL)          ; get the value
        CP      $02             ; is the hammer all used up?
        JP      NZ,$2FBE        ; no, skip ahead and change its color every 8 frames

; arrive here when hammer runs out

        XOR     A               ; A := 0
        LD      ($6395),A       ; clear hammer length
        LD      ($6217),A       ; store into hammer indicator
        LD      (IX+$01),A      ; clear hammer active indicator
        LD      A,($6203)       ; load A with mario's X position
        NEG                     ; take negative
        LD      (IX+$0E),A      ; store into +E
        LD      A,($6207)       ; load A with mario movement indicator/sprite value
        LD      ($694D),A       ; store into mario sprite value
        LD      (IX+$00),$00    ; clear hammer active bit
        LD      A,($6389)       ; load A with previous background music
        LD      ($6089),A       ; set music with what it was before the hammer was grabbed

        EX      DE,HL           ; DE <> HL
        LD      A,($6203)       ; load A with mario's X position
        ADD     A,(IX+$0E)      ; add hammer offset
        LD      (HL),A          ; store into Hammer X position
        LD      (IX+$03),A      ; store into hammer X position
        INC     HL              ; next
        LD      (HL),B          ; store sprite graphic value
        INC     HL              ; next
        LD      (HL),C          ; store into hammer color
        INC     HL              ; next
        LD      A,($6205)       ; load A with mario's Y position
        ADD     A,(IX+$0F)      ; add hammer offset
        LD      (HL),A          ; store into hammer Y position
        LD      (IX+$05),A      ; store into hammer Y position
        RET

; arrive from $2EF9, check for grabbing hammer ?

        LD      A,($6218)       ; load A with 0, turns to 1 while mario is grabbing the hammer until he lands
        RRCA                    ; is mario grabbing the hammer?
        RET     NC              ; no, return

; arrive here when hammer is grabbed

        LD      (IX+$09),$06    ; set width ?
        LD      (IX+$0A),$03    ; set height ?
        LD      A,($6207)       ; load A with mario movement indicator/sprite value
        RLCA                    ; rotate left the high bit into carry flag
        LD      A,$3C           ; A := #3C
        RRA                     ; rotate right the carry bit back in
        LD      B,A             ; copy to B
        LD      C,$07           ; C := 7
        LD      A,($6089)       ; load A with background music value
        LD      ($6389),A       ; save so it can be restored when hammer runs out.  see #2F76
        JP      $2F7C           ; ret to program

; arrive from #2F4D

        LD      A,($6395)       ; load A with hammer length
        AND     A               ; == 0 ?  (full strength)
        JP      Z,$2F7C         ; yes, jump back now

; change hammer color ?
; hammer is half strength

        LD      A,(FrameCounter)        ; load A with this clock counts down from #FF to 00 over and over...
        BIT     3,A                     ; check bit 3 (?).  zero ?  will do this every 8 frames
        JP      Z,$2F7C                 ; yes, jump back now

        LD      C,$01                   ; else C := 1 to change hammer color
        JP      $2F7C                   ; jump back

; arrive here from main routine $19BF this is the last subroutine from there for non-girder levels, this sub
; checks for bonus timer changes if the bonus counts down, it also sets a possible new fire to be released
; sets a bouncer to be deployed updates the bonus timer onscreen checks for bonus time running out

        LD      A,$0E           ; A := #E = 1110 binary
        RST     $30             ; is this the girders?  if so, return immediately

        LD      HL,$62B4        ; else load HL with timer
        DEC     (HL)            ; count down timer.  at zero?
        RET     NZ              ; no, return

        LD      A,$03           ; else A := 3
        LD      ($62B9),A       ; store into fire release - a new fire can be released
        LD      ($6396),A       ; store into bouncer release - a new bouncer can be deployed
        LD      DE,$0501        ; load task #5, parameter #1 = update onscreen bonus timer and play sound & change to red if below 1000
        CALL    $309F           ; insert task
        LD      A,($62B3)       ; load A with intial timer value.
        LD      (HL),A          ; reset the timer
        LD      HL,$62B1        ; load HL with bonus timer
        DEC     (HL)            ; Decrement.  is the bonus timer zero?
        RET     NZ              ; no, return

        LD      A,$01           ; else time has run out.  A := 1
        LD      ($6386),A       ; set time has run out indicator
        RET

; called during a barrel roll
; HL contains the X and Y position of the barrel.  Y has been inflated by 4
; called from #2A3A
; called from $2AA2 with HL preloaded with mario's position offset a bit
; returns with HL modified in some special way
;

        LD      A,L             ; load A with Y position (inflated by 4)
        RRCA                    ; Roll right 3 times
        RRCA                    ;
        RRCA                    ;
        AND     $1F             ; mask out left 3 bits to zero (number has been divided by 8)
        LD      L,A             ; Load L with this new position
        LD      A,H             ; load A with barrel's X position
        CPL                     ; A is inverted (1's complement)
        AND     $F8             ; Mask out right 3 bits to zero
        LD      E,A             ; load E with result
        XOR     A               ; A := 0
        LD      H,A             ; H := 0
        RL      E               ; rotate E left
        RLA                     ; Rotate A left [does nothing?  A is 0]
        RL      E               ; rotate E left again
        RLA                     ; rotate A left again ?
        ADD     A,$74           ; Add #74 to A.   A = #74 now ?
        LD      D,A             ; Store this in D
        ADD     HL,DE           ; Add DE into HL
        RET


;
; called here in the middle of a barrlel being rolled left or right...
; or when mario is moving
; called from four locations
; A is preloaded with ?
;

        LD      D,A             ; D := A
        RRCA                    ; roll right.  is A odd?
        JP      C,$3022         ; yes, skip ahead

; A is even

        LD      C,$93           ; C := #93
        RRCA
        RRCA                    ; roll right twice
        JP      NC,$3017        ; no carry, skip next step

        LD      C,$6C           ; C := #6C

        RLCA                    ; roll left
        JP      C,$3031         ; if carry, skip ahead

        LD      A,C             ; A := C
        AND     $F0             ; mask bits, 4 lowest bits set to zero
        LD      C,A             ; store back into C
        JP      $3031           ; skip ahead

; arrive from $300B when A is odd

        LD      C,$B4           ; C := #B4
        RRCA
        RRCA                    ; rotate A right twice.  carry set ?
        JP      NC,$302B        ; no, skip next step

        LD      C,$1E           ; C := #1E

        BIT     2,B             ; is bit 2 on B at zero?
        JP      Z,$3031         ; yes, skip next step

        DEC     B               ; else decrease B

        LD      A,C             ; A := C
        RRCA
        RRCA                    ; rotate right twice
        LD      C,A             ; C := A
        AND     $03             ; mask bits, now between 0 and 3
        CP      B               ; == B ?
        JP      NZ,$3031        ; no, loop again

        LD      A,C             ; A := C
        RRCA
        RRCA                    ; rotate right twice
        AND     $03             ; mask bits, now between 0 and 3
        CP      $03             ; == 3 ?
        RET     NZ              ; no, return

        RES     2,D             ; clear bit 2 of D (copy of original input A)
        DEC     D               ; decrease.  zero?
        RET     NZ              ; no, return

        LD      A,$04           ; else A := 4
        RET

; called from #0AF0 and #0B38
; rolls up kong's ladder during intro

        LD      DE,$FFE0        ; load DE with offset
        LD      A,($638E)       ; load A with kong ladder climb counter
        LD      C,A             ; copy to C
        LD      B,$00           ; B := 0
        LD      HL,$7600        ; load HL with screen RAM address
        CALL    $3064           ; roll up left ladder
        LD      HL,$75C0        ; load HL with screen RAM address
        CALL    $3064           ; roll up right ladder
        LD      HL,$638E        ; load HL with kong ladder climb counter
        DEC     (HL)            ; decrease
        RET

; called from $3056 and $305C above

        ADD     HL,BC           ; add offset based on how far up kong is
        LD      A,(HL)          ; get value from screen
        ADD     HL,DE           ; add offset
        LD      (HL),A          ; store value to screen
        RET

; arrive from $0A79 when intro screen indicator == 3 or 5

        RST     $18             ; count down timer and only continue here if zero, else RET
        LD      HL,($63C0)      ; load HL with timer ???
        INC     (HL)            ; increase
        RET

; called from 3 locations

        LD      HL,$62AF        ; load HL with kong climbing counter
        INC     (HL)            ; increase
        LD      A,(HL)          ; load A with the counter
        AND     $07             ; mask bits.  now between 0 and 7.  zero?
        RET     NZ              ; no, return

; animate kong climbing up the ladder

        LD      HL,$690B        ; load HL with kong sprite array
        LD      C,$FC           ; C := -4
        RST     $38             ; move kong
        LD      C,$81           ; C := #81
        LD      HL,$6909        ; load HL with kong's right leg address sprite
        CALL    $3096           ; animate kong sprite
        LD      HL,$691D        ; load HL with kong's right arm address sprite
        CALL    $3096           ; animate kong sprite
        CALL    $0057           ; load A with random number
        AND     $80             ; mask bits, now either 0 or #80
        LD      HL,$692D        ; load HL with sprite of girl under kong's arms
        XOR     (HL)            ; toggle the sprite
        LD      (HL),A          ; store result - toggles the girl to make her wiggle randomly
        RET

; called from $3082 and $3088 above

        LD      B,$02           ; For B = 1 to 2

        LD      A,C             ; A := C
        XOR     (HL)            ; toggle with the bits in this memory location
        LD      (HL),A          ; store A into this location
        ADD     HL,DE           ; add offset for next location
        DJNZ    $3098           ; Next B

        RET

; insert task
; DE are loaded with task $ and parameter
; tasks are decoded at #02E3
; tasks are pushed into $60C0 through #60FF

        PUSH    HL              ; save HL
        LD      HL,$60C0        ; load HL with start of task list [why?  L is set later, only H needs to be loaded here]
        LD      A,($60B0)       ; load A with task pointer
        LD      L,A             ; HL now has task pointer full address
        BIT     7,(HL)          ; test high bit 7 of the task at this address.  zero?
        JP      Z,$30BB         ; yes, skip ahead, restore HL and return. [when would this happen??? if task list is full???]

        LD      (HL),D          ; else store task number into task list
        INC     L               ; next HL
        LD      (HL),E          ; store task parameter
        INC     L               ; next HL
        LD      A,L             ; load A with low byte of task pointer
        CP      $C0             ; is A > #C0 ? (did the task list roll over?)
        JP      NC,$30B8        ; no, skip next instruction

        LD      A,$C0           ; yes, reset A to #C0 for start of task list

        LD      ($60B0),A       ; store A into task list pointer

        POP     HL              ; restore HL
        RET                     ; ret to program

; arrive here from $1615 when rivets cleared
; clears all sprites for firefoxes, hammers and bonus items

        LD      HL,$6950        ; load HL with start of hammers
        LD      B,$02           ; B := 2
        CALL    $30E4           ; clear hammers ?
        LD      L,$80           ; L := #80
        LD      B,$0A           ; B := #A
        CALL    $30E4           ; clear barrels ?
        LD      L,$B8           ; L := #B8
        LD      B,$0B           ; B := #B
        CALL    $30E4           ; clear firefoxes ?
        LD      HL,$6A0C        ; load HL with start of bonus items
        LD      B,$05           ; B := 5
        JP      $30E4           ; clear bonus items

; called from #12DF
; clears mario and elevators from the screen

        LD      HL,$694C        ; load address for mario sprite X position
        LD      (HL),$00        ; clear this memory = move mario off screen
        LD      L,$58           ; HL := #6958 = elevator sprite start
        LD      B,$06           ; for B = 1 to 6

        LD      A,L             ; load A with low byte addr

        LD      (HL),$00        ; clear this sprite position to zero = move off screen
        ADD     A,$04           ; add 4 for next sprite
        LD      L,A             ; store into HL
        DJNZ    $30E5           ; next B

        RET

; called from main routine at $198C

        CALL    $30FA           ; Check internal difficulty and timers and return here based on difficulty a percentage of the time
        CALL    $313C           ; Deploy fire if fire deployment flag is set
        CALL    $31B1           ; Process all movement for all fireballs
        CALL    $34F3           ; update all fires and firefoxes
        RET

; This routine is used to adjust the fireball speed based on the internal difficulty. It works by forcing the entire fireball movement routine to
; be skipped on certain frames, returning directly back to the main routine in such cases. The higher the internal difficlty, the less often it
; short-circuits back to the main routine, the faster they will move.
; called from #30ED ABOVE

        LD      A,($6380)       ; \  Jump if internal difficulty is less than 6 (Is it possible to not jump here?)
        CP      $06             ;  |
        JR      C,$3103         ; /

        LD      A,$05           ; load A with 5 = max internal difficulty
        RST     $28             ; jump to address based on internal difficulty

        hex     10 31           ; 0       #3110
        hex     10 31           ; 1       #3110
        hex     1B 31           ; 2       #311B
        hex     26 31           ; 3       #3126
        hex     26 31           ; 4       #3126
        hex     31 31           ; 5       #3131

; internal difficulty == 0 or 1. In this case, the fireball movement routine is only executed every other frame, so that fireballs move slowly.

        LD      A,(FrameCounter)       ; load A with this clock counts down from #FF to 00 over and over...
;        LD      H,B             ; load H with B == ??? from previous subroutine ???? [what is this doing here ?] ___BUG___
        AND     $01             ; \  If lowest bit of timer is 0 Return and continue as normal
        CP      $01             ;  |
        RET     Z               ; /

        INC     SP              ; \  Else return to #198F instead of #30F0, skipping fireball movement routine
        INC     SP              ;  |
        RET                     ; /

; internal difficulty == 2. Here the fireball movement routine is executed for 5 consecutive frames out of every 8 frames.

        LD      A,(FrameCounter)       ; \  If the lowest 3 bits of timer are less than 5 (equal to 0, 1, 2, 3, or 4) then return and continue as
        AND     $07             ;  | normal
        CP      $05             ;  |
        RET     M               ; /

        INC     SP              ; \  Else return to #198F instead of #30F0, skipping fireball movement routine
        INC     SP              ;  |
        RET                     ; /

; difficulty == 3 or 4. Here the fireball movement routine is executed for 3 out of every 4 frames.

        LD      A,(FrameCounter)        ; \  If the lowest 2 bits of the timer are not 11 then return and continue as normal
        AND     $03                     ;  |
        CP      $03                     ;  |
        RET     M                       ; /

        INC     SP                      ; \  Else return to #198F instead of #30F0, skipping fireball movement routine
        INC     SP                      ;  |
        RET                             ; /

; difficulty == 5. Here the fireball movement routine is executed for 7 out of every 8 frames.

        LD      A,(FrameCounter)        ; \  If the lowest 3 bits of the timer are not 111 then return and continue as normal
        AND     $07                     ;  |
        CP      $07                     ;  |
        RET     M                       ; /

        INC     SP                      ; \  Else return to #198F instead of #30F0, skipping fireball movement routine
        INC     SP                      ;  |
        RET                             ; /

; This routine checks the fire deployment flag and deploys the actual fireball if it is set (as long as there is a free slot). It also keeps an
; updated count of the number of fireballs on screen and sets the color of fireballs based on the hammer status.
; called from #30F0

        LD      IX,$6400        ; load IX with start of fire address
        XOR     A               ; \ Reset # of fires onscreen to 0, this routine will count them.
        LD      ($63A1),A       ; /
        LD      B,$05           ; For B = 1 to 5 firefoxes
        LD      DE,$0020        ; load DE with offset to add for next firefox

        LD      A,(IX+$00)      ; \  Jump if sprite slot is unused to maybe deploy a fire there.
        CP      $00             ;  |
        JP      Z,$317C         ; /

        LD      A,($63A1)       ; \  This fire slot is active. Increment count for # of fires onscreen
        INC     A               ;  |
        LD      ($63A1),A       ; /
        LD      A,$01           ; \  Set fire color to #01 (normal) if hammer is not active, and #00 (blue) if hammer is active
        LD      (IX+$08),A      ;  |
        LD      A,($6217)       ;  |
        CP      $01             ;  |
        JP      NZ,$316A        ;  |
        LD      A,$00           ;  |
        LD      (IX+$08),A      ; /

        ADD     IX,DE           ; next sprite
        DJNZ    $3149           ; next B

        LD      HL,$63A0        ; \ Clear fire deployment flag
        LD      (HL),$00        ; /
        LD      A,($63A1)       ; \  Return all the way back to the main routine if no fires are active, otherwise just return.
        CP      $00             ;  |
        RET     NZ              ;  |
        INC     SP              ;  |
        INC     SP              ;  |
        RET                     ; /

; arrive here from #314E
        LD      A,($63A1)       ; \  Jump back and don't deploy fire if there are already 5 fires active (Can this ever happen here?)
        CP      $05             ;  |
        JP      Z,$316A         ; /
        LD      A,($6227)       ; \  Jump ahead if screen is not conveyors (i.e., the screen is rivets)
        CP      $02             ;  |
        JP      NZ,$3195        ; /
        LD      A,($63A1)       ; \  Return if current count of # of fires == internal difficulty, on conveyors we never have more fireballs
        LD      C,A             ;  | on screen than the internal difficulty
        LD      A,($6380)       ;  |
        CP      C               ;  |
        RET     Z               ; /
        LD      A,($63A0)       ; \  Jump back and don't deploy fire if fire deployment flag is not set
        CP      $01             ;  |
        JP      NZ,$316A        ; /

        LD      (IX+$00),A      ; Deploy a fire. Set status indicator to 1 = active
        LD      (IX+$18),A      ; Set spawning indicator to 1
        XOR     A               ; \ Clear fire deployment flag
        LD      ($63A0),A       ; /
        LD      A,($63A1)       ; \  Increment count of # of active fires
        INC     A               ;  |
        LD      ($63A1),A       ; /
        JP      $316A           ; jump back and loop for next

; This subroutine handles all movement for all fireballs.
; called from #30F3

        CALL    $31DD           ; Check if freezers should enter freezer mode
        XOR     A               ; \ Index of fireball being processed := 0
        LD      ($63A2),A       ; /
        LD      HL,$63E0        ; \ Address of fireball data array for current fireball being processed := #63E0 = #6400 - #20
        LD      ($63C8),HL      ; / This gets incremented by #20 at the start of the following loop

; Loop start
        LD      HL,($63C8)      ; \  Move on to next fireball by incrementing address of fireball data array for current fireball by #20
        LD      BC,$0020        ;  |
        ADD     HL,BC           ;  |
        LD      ($63C8),HL      ; /
        LD      A,(HL)          ; \  Jump if fireball is not active
        AND     A               ;  |
        JP      Z,$31D0         ; /

        CALL    $3202           ; Handle all movement for this fire

        LD      A,($63A2)       ; \  Increment index of current fireball being processed
        INC     A               ;  |
        LD      ($63A2),A       ; /
        CP      $05             ; \ Loop if index is less than 5
        JP      NZ,$31BE        ; /

        RET

; This subroutine checks if fires 2 and 4 should enter freezer mode. They always both enter at the same time and they enter with a 25% probability
; every 256 frames (note that this is 256 actual frames, not 256 fireball code execution frames).
; called from #31B1 above

        LD      A,($6380)       ; \  Return if internal difficulty is < 3, no freezers are allowed until difficulty 3.
        CP      $03             ;  |
        RET     M               ; /

        CALL    $31F6           ; Check if we should enter freezer mode (25% probability every 256 frames of entering freezer mode)
        CP      $01             ; \ Return if should not enter freezer mode
        RET     NZ              ; /

        LD      HL,$6439        ; \  Set freezer indicator of 2nd fire to #02 to enable freezer mode
        LD      A,$02           ;  |
        LD      (HL),A          ; /

        LD      HL,$6479        ; \  Set freezer indicator of 4th fire to #02 to enable freezer mode
        LD      A,$02           ;  |
        LD      (HL),A          ; /
        RET

; Every 256 frames this subroutine has a 25% chance of loading 1 into A. Otherwise a value not equal to 1 is loaded.
; called from #31E3

        LD      A,(RngTimer1)           ; \  Return with 1 not loaded in A if lowest 2 bits of RNG are not 01. (75% probability of returning)
        AND     $03                     ;  |
        CP      $01                     ;  |
        RET     NZ                      ; /

        LD      A,(FrameCounter)        ; \ Else return A with timer that constantly counts down from FF to 00  ... 1 count per frame
        RET                             ; /

; This subroutine handles all movement for a single fireball.
; called from #31CD above

        LD      IX,($63C8)      ; Load IX with address of fireball data array for current fireball
        LD      A,(IX+$18)      ; \  Jump if fireball is currently in the process of spawning
        CP      $01             ;  |
        JP      Z,$327A         ; /

        LD      A,(IX+$0D)      ; \  Jump if fireball is currently on a ladder
        CP      $04             ;  |
        JP      P,$3230         ; /

        LD      A,(IX+$19)      ; \  Jump if freezer mode is enguaged for this fireball
        CP      $02             ;  |
        JP      Z,$327E         ; /

        CALL    $330F           ; Check if fireball should randomly reverse direction
        LD      A,(RngTimer1)   ; \  Jump and do not climb any ladder with 75% probability, so a ladder is climbed with 25% probability.
        AND     $03             ;  | Note that left moving fireballs always skip the ladder climbing check and instead jump to the end of
        JP      NZ,$3233        ; /  this subroutine without updating position.

        LD      A,(IX+$0D)      ; \  Jump to end of subroutine if fireball is moving left. This is reached with 25% probability so left-moving
        AND     A               ;  | fireballs skip all movement with 25% probability, so their speed is randomized but averages 25% slower
        JP      Z,$3257         ; /  than the speed of right-moving fireballs.

; Fireball is on a ladder or about to mount ladder (as long as doing so is permitted).
        CALL    $333D           ; Handle fireball mounting/dismounting of ladders

        LD      A,(IX+$0D)      ; \  Jump if fireball is currently on a ladder
        CP      $04             ;  |
        JP      P,$3291         ; /

; Fireball is moving left or right
        CALL    $33AD           ; Handle fire movement left or right, animate fireball, and adjust Y-position for slanted girders
        CALL    $298C           ; Load A with 1 if girder edge nearby, 0 otherwise
        CP      $01             ; \ Jump if we have reached the edge of a girder
        JP      Z,$3297         ; /

        LD      IX,($63C8)      ; Load IX with address of fireball slot for this fireball
        LD      A,(IX+$0E)      ; \  Jump if X-position is < #10 (i.e., fireball has reached left edge of screen)
        CP      $10             ;  |
        JP      C,$328C         ; /

        CP      $F0             ; \ Jump if X-position is >= #F0 (i.e., fireball has reached right edge of screen)
        JP      NC,$3284        ; /

        LD      A,(IX+$13)      ; \  Jump if our index into the Y-position adjustment table hasn't reached 0 yet
        CP      $00             ;  |
        JP      NZ,$32B9        ; /

        LD      A,$11           ; Reset index into Y-position adjustment table

        LD      (IX+$13),A      ; Store updated index into Y-position adjustment table
        LD      D,$00           ; \  Index the Y-position adjustment table using +#13 to get in A the amount to adjust the Y-position by to
        LD      E,A             ;  | make the fireball bob up and down
        LD      HL,$3A7A        ;  |
        ADD     HL,DE           ;  |
        LD      A,(HL)          ; /

        ; 3A7A:  FF 00 FF FF FE FE FE FE FE FE FE FE FE FE FE FF FF 00

        LD      B,(IX+$0E)      ; \ Copy effective X-position into actual X-position (these two are always the same)
        LD      (IX+$03),B      ; /
        LD      C,(IX+$0F)      ; \  Compute the actual Y-position by adding the adjustment to the effective Y-position
        ADD     A,C             ;  |
        LD      (IX+$05),A      ; /
        RET

; Arrive from $320B when fireball is spawning
        CALL    $32BD           ; Handle fireball movement while spawning
        RET

; Arrive from $321B when freezer mode is enguaged
        CALL    $32D6           ; Handle freezing fireball
        JP      $3229           ; Jump back to program

; Arrive from $3254 when fireball has reached right edge of screen
        LD      A,$02           ; Set direction to "special" left

        LD      (IX+$0D),A      ; Store new direction, either 1 for right or 2 for left
        JP      $3257           ; Jump back

; Arrive from $324F when fireball has reached left edge of screen
        LD      A,$01           ; Set direction to right
        JP      $3286           ; Jump back

; Fireball is moving up or down a ladder
        CALL    $33E7           ; Handle fireball movement up/down the ladder and animate the fireball
        JP      $3257           ; Jump back

; Arrived from $3243 when fire is at edge of girder
        LD      IX,($63C8)      ; Load IX with address of fireball slot for this fireball
        LD      A,(IX+$0D)      ; \  Jump if fireball direction is left
        CP      $01             ;  |
        JP      NZ,$32B1        ; /

        LD      A,$02           ; Set direction to "special" left
        DEC     (IX+$0E)        ; Decrement fireball X-position, make fireball move left

        LD      (IX+$0D),A      ; Store new direction, either 1 for right, or 2 for left
        CALL    $33C3           ; Since we just moved a pixel, adjust Y-position for slanted girders on barrel screen
        JP      $3257           ; Jump back

        LD      A,$01           ; Set direction to right
        INC     (IX+$0E)        ; Incremement fireball X-position, make fireball move right
        JP      $32A8           ; Jump back

; Arrived from #325C
        DEC     A               ; Decrement index into Y-position adjustment table
        JP      $3261           ; Jump back

; This subroutine is responsible for handling fireball movement while the fireball is spawning. Here the fireball may be following a fixed trajectory
; such as when jumping out of an oil can for example.
; called from #327A

        LD      A,($6227)       ; \  Jump if we are currently on barrels
        CP      $01             ;  |
        JP      Z,$32CE         ; /

        CP      $02             ; \ Jump if we are on conveyors
        JP      Z,$32D2         ; /

        CALL    $34B9           ; Spawn fireball in proper location on rivets
        RET

        CALL    $342C           ; Handle fireball movement while coming out of oilcan on barrels
        RET

        CALL    $3478           ; Handle fireball movement while coming out of oilcan on conveyors
        RET

; This subroutine handles a freezer when freezer mode is activated, including checking when to freeze and when to leave freezer mode.
; Called from #327E

        LD      A,(IX+$1C)      ; \  Jump if fireball freeze timer is non-zero, meaning we are frozen and waiting for the timer to reach 0
        CP      $00             ;  | to unfreeze.
        JP      NZ,$32FD        ; /

        LD      A,(IX+$1D)      ; \  We reach this when a fireball is not frozen, but freezer mode is activated. Jump if the freeze flag is
        CP      $01             ;  | not set (This flag is only set when the fireball reaches the top of a ladder).
        JP      NZ,$330B        ; /

; It is time to maybe freeze the fireball at the top of a ladder.
        LD      (IX+$1D),$00    ; Reset the freeze flag to zero
        LD      A,($6205)       ; \  Jump if Mario is above fireball, in this case we leave freezer mode immediately without freezing.
        LD      B,(IX+$0F)      ;  |
        SUB     B               ;  |
        JP      C,$3303         ; /

        LD      (IX+$1C),$FF    ; Freeze the fireball for 256 fireball execution frames

        LD      (IX+$0D),$00    ; Set direction to "frozen"
        RET

; Jump here from $32DB when fireball still frozen
        DEC     (IX+$1C)        ; Decrement freeze timer
        JP      NZ,$32F8        ; Jump if it is still not time to unfreeze

; It is time to unfreeze
        LD      (IX+$19),$00    ; Clear the freezer mode flag
        LD      (IX+$1C),$00    ; Clear the freeze timer

        CALL    $330F           ; Check if fireball should randomly freeze out in the open (note this is the same as the direction reversal
                                ; routine for non-freezing fireballs, only now setting direction to 00 indicates "frozen" instead of "left")
        RET

; This subroutine randomly reversed direction of fire every 43 fireball execution frames. Note that this is not actual frames, the actual number of
; frames will vary based on internal difficulty.
; called from $321E and from $330B

        LD      A,(IX+$16)      ; \  Jump without reversing if direction reverse timer hasn't reached 0 yet
        CP      $00             ;  |
        JP      NZ,$3332        ; /

        LD      (IX+$16),$2B    ; Reset direction reverse counter to #2B
        LD      (IX+$0D),$00    ; \  Set fireball direction to be left (or frozen for freezers) and jump with 50% probability
        LD      A,(RngTimer1)       ;  |
        RRCA                    ;  |
        JP      NC,$3332        ; /

        LD      A,(IX+$0D)      ; \  Jump if direction fireball direction is 1, which is impossible, so this is a NOP.
        CP      $01             ;  |
        JP      Z,$3336         ; /

        LD      (IX+$0D),$01    ; Else set fireball direction to be right
        DEC     (IX+$16)        ; Decrement direction reverse timer
        RET

; jump here from $332B [never arrive here , buggy software]
        LD      (IX+$0D),$02    ; Set fireball direction to be "special" left
        JP      $3332           ; jump back

; This subroutine serves two purposes. If a fireball is currently on a ladder it checks to see if the fireball has reached the other end of the ladder
; and if so dismounts the ladder. Otherwise, if the fireball is not on a ladder it checks to see if there are any ladders nearby that can be taken,
; and if so it mounts the ladder.
; called from #3230

        LD      A,(IX+$0D)      ; \  Jump if fireball is climbing up a ladder
        CP      $08             ;  |
        JP      Z,$3371         ; /

        CP      $04             ; \ Jump if fireball is climbing down a ladder
        JP      Z,$338A         ; /

; Else firefox is not on a ladder, but will mount one if permitted to do so
        CALL    $33A1           ; Ret without taking ladder if fireball is on the top girder and the screen is not rivets
        LD      A,(IX+$0F)      ; \  D := Y-position of bottom of fireball
        ADD     A,$08           ;  |
        LD      D,A             ; /
        LD      A,(IX+$0E)      ; A := fireball's X-position
        LD      BC,$0015        ; BC := #0015, the number of ladders to check
        CALL    $236E           ; Check for ladders nearby, return if none, else A := 0 if at bottom of ladder, A := 1 if at top
        AND     A               ; \ Jump if there is a ladder nearby to go up
        JP      Z,$3399         ; /

; Else there is a ladder nearby to go down
        LD      (IX+$1F),B      ; Store B into +#1F = Y-position of bottom of ladder
        LD      A,($6205)       ; \  Return without taking the ladder if Mario is at or above the Y-position of the fireball
        LD      B,A             ;  |
        LD      A,(IX+$0F)      ;  |
        SUB     B               ;  |
        RET     NC              ; /

        LD      (IX+$0D),$04    ; Else set direction to descending ladder
        RET

; Arrived because fireball is moving up a ladder
        LD      A,(IX+$0F)      ; \  Return if fireball is not at the top of the ladder
        ADD     A,$08           ;  |
        LD      B,(IX+$1F)      ;  |
        CP      B               ;  |
        RET     NZ              ; /

; Fireball at top of ladder
        LD      (IX+$0D),$00    ; Set fireball direction to left
        LD      A,(IX+$19)      ; \  If freezer mode is enguaged then set the freeze flag and return, otherwise just return.
        CP      $02             ;  |
        RET     NZ              ;  |
        LD      (IX+$1D),$01    ;  |
        RET                     ; /

; Arrive because fireball is moving down a ladder
        LD      A,(IX+$0F)      ; \  Return if fireball is not at the bottom of the ladder
        ADD     A,$08           ;  |
        LD      B,(IX+$1F)      ;  |
        CP      B               ;  |
        RET     NZ              ; /

        LD      (IX+$0D),$00    ; Fireball has reached the bottom, set the direction to left
        RET

; Arrive because there is a ladder nearby to go up
        LD      (IX+$1F),B      ; Store B into +#1F = Y-position of top of ladder
        LD      (IX+$0D),$08    ; Else set direction to ascending ladder
        RET

; This subroutine returns to the higher subroutine (causing a ladder to NOT be taken) if a fireball is on the top girder and we are not on rivets.
; called from #334A

        LD      A,$07           ; \ Return if immediately we are on rivets, fireballs do not get stuck on the top in this case
        RST     $30             ; /

        LD      A,(IX+$0F)      ; \ Return if Y-position is >= 59 (i.e., fireball is not on the top girder)
        CP      $59             ;  |
        RET     NC              ; /

        INC     SP              ; \  Else return to higher subroutine. This prevents fireballs from coming down on conveyors & girders once
        INC     SP              ;  | they reach the top level.
        RET                     ; /

; This subroutine handles movemnt of a fireball to the left and right. It also animates the fireball and adjusts its Y-position if travelling up/down
; a slanted girder on the barrel screen.
; called from #323B

        LD      A,(IX+$0D)      ; \  Jump if fireball direction is right
        CP      $01             ;  |
        JP      Z,$33D9         ; /

; Fireball is moving left
        LD      A,(IX+$07)      ; \  Set direction bit in fireball graphics to face left
        AND     $7F             ;  |
        LD      (IX+$07),A      ; /
        DEC     (IX+$0E)        ; Decrement X-position

        CALL    $3409           ; Animate the fireball
; Fall into below subroutine

; This subroutine adjusts a fireball's Y-position based on movement up/down a slanted girder on the barrel screen.
; called from #32AB

        LD      A,($6227)       ; \  Return if we are not on barrels
        CP      $01             ;  |
        RET     NZ              ; /

        LD      H,(IX+$0E)      ; Load H with fireball X-position
        LD      L,(IX+$0F)      ; Load L with fireball Y-position
        LD      B,(IX+$0D)      ; Load B with fireball direction
        CALL    $2333           ; Check for fireball moving up/down a slanted girder ?
        LD      (IX+$0F),L      ; Store adjusted Y-position
        RET

; Fireball is moving right
        LD      A,(IX+$07)      ; \  Set direction bit in fireball graphics to face right
        OR      $80             ;  |
        LD      (IX+$07),A      ; /
        INC     (IX+$0E)        ; Increment X-position
        JP      $33C0           ; Jump back to program

; This subroutine handles fireball movement up and down ladders. Fireball movement up a ladder is 1/3 the speed of movement down a ladder, and
; movement down a ladder is the same speed as movement to the right. The subroutine also animates the fireball as it climbs.
; called from #3291

        CALL    $3409           ; Animate the fireball
        LD      A,(IX+$0D)      ; \  Jump if fireball is moving down the ladder
        CP      $08             ;  |
        JP      NZ,$3405        ; /

        LD      A,(IX+$14)      ; \  Jump if it is not time to climb one pixel yet
        AND     A               ;  |
        JP      NZ,$3401        ; /

        LD      (IX+$14),$02    ; Reset ladder climb timer to 2
        DEC     (IX+$0F)        ; Decrement fireball's Y position, move up one pixel
        RET

        DEC     (IX+$14)        ; Decrease ladder climb timer
        RET

        INC     (IX+$0F)        ; Increment fireball's Y position, move down one pixel
        RET

; This subroutine handles fireball animation.
; called from $33E7 and from $33C0

        LD      A,(IX+$15)      ; \  Jump if it is not time to change animation frames yet
        AND     A               ;  |
        JP      NZ,$3428        ; /

        LD      (IX+$15),$02    ; Reset animation change timer
        INC     (IX+$07)        ; \  Toggles the lowest 4 bits of +#07 between D and E, this toggles between two possible graphics that
        LD      A,(IX+$07)      ;  | the fireball can use
        AND     $0F             ;  |
        CP      $0F             ;  |
        RET     NZ              ;  |
        LD      A,(IX+$07)      ;  |
        XOR     $02             ;  |
        LD      (IX+$07),A      ; /
        RET

        DEC     (IX+$15)        ; Decrement animation change timer
        RET

; The subroutine handles fireball movement as it spawns out of the oilcan on barrels.
; Called from #32CE

        LD      L,(IX+$1A)      ; \ Load HL with address into Y-position table
        LD      H,(IX+$1B)      ; /
        XOR     A               ; \  Jump if HL is non-zero (i.e., if this is not the very first spawning frame)
        LD      BC,$0000        ;  |
        ADC     HL,BC           ;  |
        JP      NZ,$3442        ; /

        LD      HL,$3A8C        ; We just began to spawn, load HL with address of start of Y-position table
        LD      (IX+$03),$26    ; Initialize X position to #26, the X-position of the oilcan

; This table stores the Y-positions a fireball should have each frame to follow a parabolic arc used when fireballs are coming out of oilcans.
        ; 3A8C:  E8 E5 E3 E2
        ; 3A90:  E1 E0 DF DE DD DD DC DC DC DC DC DC DD DD DE DF
        ; 3AA0:  E0 E1 E2 E3 E4 E5 E7 E9 EB ED F0 AA

        INC     (IX+$03)        ; Increment X-position

        LD      A,(HL)          ; \  Jump if we've reached the end of the Y-position table (marked by #AA)
        CP      $AA             ;  |
        JP      Z,$3456         ; /

        LD      (IX+$05),A      ; Else store table data into fire's Y-position
        INC     HL              ; \  Advance to next table entry, for the next frame
        LD      (IX+$1A),L      ;  |
        LD      (IX+$1B),H      ; /
        RET

; Fire has completed its spawning and is now free-floating
        XOR     A               ; A := 0
        LD      (IX+$13),A      ; Clear fire animation height counter
        LD      (IX+$18),A      ; Clear firefox spawning indicator
        LD      (IX+$0D),A      ; Set direction to left
        LD      (IX+$1C),A      ; Clear the still indicator
        LD      A,(IX+$03)      ; \ Make copy of X-position
        LD      (IX+$0E),A      ; /
        LD      A,(IX+$05)      ; \ Make copy of Y-position
        LD      (IX+$0F),A      ; /
        LD      (IX+$1A),$00    ; \ Clear address into Y-position spawning table
        LD      (IX+$1B),$00    ; / [these last two could have been written above with one less byte each]
        RET

; This subroutine handles fireball movement as it spawns out of the oilcan on conveyors.
; Called from #32D2

        LD      L,(IX+$1A)      ; \ Load HL with address into Y-position table
        LD      H,(IX+$1B)      ; /
        XOR     A               ; \  Jump if HL is non-zero (i.e., if this is not the very first spawning frame)
        LD      BC,$0000        ;  |
        ADC     HL,BC           ;  |
        JP      NZ,$349A        ; /

        LD      HL,$3AAC        ; load HL with start of table data
        LD      A,($6203)       ; \  Jump if Mario is on left side of the screen, in this case we spawn the fireball on the left
        BIT     7,A             ;  |
        JP      Z,$34A8         ; /

        LD      (IX+$0D),$01    ; Set fireball direction to "right"
        LD      (IX+$03),$7E    ; Initialize X position to #7E

        LD      A,(IX+$0D)      ; \  Jump if fireball moving left
        CP      $01             ;  |
        JP      NZ,$34B3        ; /

        INC     (IX+$03)        ; Moving right, Increment X-position
        JP      $3445           ; Jump back, remainder of subroutine shared with the above subroutine

        LD      (IX+$0D),$02    ; Set fireball direction to "special" left (This isn't actually used at all after spawning, since immediately
                                ; after spawning it will check to reverse rection and receive a direction of either "right" or "left".
        LD      (IX+$03),$80    ; Initialize X position to #80
        JP      $349A           ; Jump back [why there?  after setting direction, we should jump directly to #34B3]

        DEC     (IX+$03)        ; Moving left, Decrement X-position
        JP      $3445           ; Jump back, remainder of subroutine shared with the above subroutine

; On rivets, this subroutine spawns a fireball on a random platform besides the very top on the side of the screen opposite the the side that Mario
; is on.
; Called from $32CA when screen is elevators or rivets

        LD      A,($6227)       ; \  Return if current screen is elevators (Can this ever happen?)
        CP      $03             ;  |
        RET     Z               ; /

        LD      A,($6203)       ; \  Jump if bit 7 of Mario's X-position is set (i.e., Mario is on the right half of the screen)
        BIT     7,A             ;  |
        JP      NZ,$34ED        ; /

        LD      HL,$3AC4        ; Load HL with start of table data for spawning fireball on right side

; Possible X and Y positions to spawn a fireball on the right side of the screen
; First value is X position, 2nd value is Y position

; 3AC4:  EE F0  ; bottom, right
; 3AC6:  DB A0  ; middle, right
; 3AC8:  E6 C8  ; 2nd from bottom, right
; 3ACA:  D6 78  ; 2nd from top, right
; 3ACC:  EB F0  ; unused?
; 3ACE:  DB A0  ; unused?
; 3AD0:  E6 C8  ; unused?
; 3AD2:  E6 C8  ; unused?

; Possible X and Y positions to spawn a fireball on the left side of the screen
; First value is X position, 2nd value is Y position

; 3AD4:  1B C8  ; 2nd from bottom, left
; 3AD6:  23 A0  ; middle, left
; 3AD8:  2B 78  ; 2nd from top, left
; 3ADA:  12 F0  ; bottom, left
; 3ADC:  1B C8  ; unused?
; 3ADE:  23 A0  ; unused?
; 3AE0:  12 F0  ; unused?
; 3AE2:  1B C8  ; unused?



        LD      B,$00           ; \  Load BC with one of #0000, #0002, #0004, or #0006 randomly
        LD      A,(RngTimer2)   ;  |
        AND     $06             ;  |
        LD      C,A             ; /
        ADD     HL,BC           ; add this result into HL to get offset into table
        LD      A,(HL)          ; \  Copy X-position from table into fireball X-position
        LD      (IX+$03),A      ;  |
        LD      (IX+$0E),A      ; /
        INC     HL              ; next table entry
        LD      A,(HL)          ; \  Copy Y-position from table into fireball Y-position
        LD      (IX+$05),A      ;  |
        LD      (IX+$0F),A      ; /
        XOR     A               ; A := 0
        LD      (IX+$0D),A      ; Set fireball direction to left
        LD      (IX+$18),A      ; Clear fireball spawning indicator
        LD      (IX+$1C),A      ; Clear +1C = still indicator
        RET

        LD      HL,$3AD4        ; Load HL with alternate start of table data for spawning fireball on left side.
        JP      $34CA           ; Jump back

; update fires or firefoxes to hardware
; called from #30F6

        LD      HL,$6400        ; start of fire/firefox data
        LD      DE,$69D0        ; start of firefox sprites (hardware)
        LD      B,$05           ; For B = 1 to 5

        LD      A,(HL)          ; get firefox data
        AND     A               ; is this sprite active ?
        JP      Z,$351E         ; no, jump away and set for next sprite

        INC     L
        INC     L
        INC     L               ; HL now points to firefox's X position (IX + #03)
        LD      A,(HL)          ; load A with firefox X position
        LD      (DE),A          ; store into sprite X position
        LD      A,$04           ; A := 4
        ADD     A,L             ; add to L
        LD      L,A             ; HL now points to firefox's Y position (IX + #07)
        INC     E               ; next DE, now it has sprite Y position
        LD      A,(HL)          ; load A with firefox Y position
        LD      (DE),A          ; store into hardaware sprite Y position
        INC     L               ; next HL
        INC     E               ; next DE
        LD      A,(HL)          ; load A with firefox sprite color value
        LD      (DE),A          ; store sprite color
        DEC     L
        DEC     L
        DEC     L               ; decrease HL by 3.  now it points to sprite value
        INC     E               ; next DE
        LD      A,(HL)          ; load A with sprite value
        LD      (DE),A          ; store sprite value to hardware
        INC     DE              ; next DE

        LD      A,$1B           ; A := #1B
        ADD     A,L             ; add to L
        LD      L,A             ; store into L.  HL how has #1B more.  The next sprite is referenced
        DJNZ    $34FB           ; Next Firefox

        RET

; arrive here when firefox is not being used, sets pointer for next sprite

        LD      A,$05           ; A := 5
        ADD     A,L             ; add to L
        LD      L,A             ; store into L.  HL is now 5 more than before
        LD      A,$04           ; A := 4
        ADD     A,E             ; add to E
        LD      E,A             ; store into E.  DE is now 4 more than before.  next sprite
        JP      $3517           ; jump back

; table data
; used for item scoring :  100, 200 , 300 etc
; called from #0525


        hex     00 00 00
        hex     00 01 00
        hex     00 02 00
        hex     00 03 00
        hex     00 04 00
        hex     00 05 00
        hex     00 06 00
        hex     00 07 00
        hex     00 08 00
        hex     00 09 00
        hex     00 00 00
        hex     00 10 00
        hex     00 20 00
        hex     00 30 00
        hex     00 40 00
        hex     00 50 00
        hex     00 60 00
        hex     00 70 00
        hex     00 80 00
        hex     00 90 00

;  table data .. loaded at $025A when game is powered on or reset
; transferred into $6100 to $61AA
; high score table

; first 2 bytes form a VRAM address. EG #7794 through #779C
; 3rd byte is the place.  1 through 5
; 4th and 5th bytes are either "ST" or "ND" or "RD" or "TH"
; 6th and 7th bytes are $10 for blank spaces
; 8th through 13th bytes are teh score digits
; 14 through end are $10 for blank spaces, ended by #3F end code
; after this is the actual score
; the last 2 bytes are ???

        hex     94 77 01 23 24 10 10 00 00 07 06 05 00 10 10 10 10 10 10 10 10 10 10 10 10 10 10 3F 00 50 76 00 F4 76
        hex     96 77 02 1E 14 10 10 00 00 06 01 00 00 10 10 10 10 10 10 10 10 10 10 10 10 10 10 3F 00 00 61 00 F6 76
        hex     98 77 03 22 14 10 10 00 00 05 09 05 00 10 10 10 10 10 10 10 10 10 10 10 10 10 10 3F 00 50 59 00 F8 76
        hex     9A 77 04 24 18 10 10 00 00 05 00 05 00 10 10 10 10 10 10 10 10 10 10 10 10 10 10 3F 00 50 50 00 FA 76
        hex     9C 77 05 24 18 10 10 00 00 04 03 00 00 10 10 10 10 10 10 10 10 10 10 10 10 10 10 3F 00 00 43 00 FC 76

; data read at #1611
; used for high score entry ???

        hex     3B
        hex     5C 4B 5C 5B 5C 6B 5C 7B 5C 8B 5C 9B 5C AB 5C BB
        hex     5C CB 5C 3B 6C 4B 6C 5B 6C 6B 6C 7B 6C 8B 6C 9B
        hex     6C AB 6C BB 6C CB 6C 3B 7C 4B 7C 5B 7C 6B 7C 7B
        hex     7C 8B 7C 9B 7C AB 7C BB 7C CB 7C

; #364B is used from #05E9

        hex     8B 36            ;0       #368B "GAME OVER"
        hex     01 00            ;1       unused ?
        hex     98 36            ;2       #3698 "PLAYER <I>"
        hex     A5 36            ;3       #36A5 "PLAYER <II>"
        hex     B2 36            ;4       #36B2 "HIGH SCORE"
        hex     BF 36            ;5       #36BF "CREDIT"
        hex     06 00            ;6       unused ?
        hex     CC 36            ;7       #36CC "HOW HIGH CAN YOU GET?" "IT'S ON LIKE KONKEY DONG!"
        hex     08 00            ;8       unused ?
        hex     E6 36            ;9       #36E6 "ONLY 1 PLAYER BUTTON"
        hex     FD 36            ;A       #36FD "1 OR 2 PLAYERS BUTTON"
        hex     0B 00            ;B       unused ?
        hex     15 37            ;C       #3715 "PUSH"
        hex     1C 37            ;D       #371C "NAME REGISTRATION"
        hex     30 37            ;E       #3730 "NAME:"
        hex     38 37            ;F       #3738 "---"
        hex     47 37            ;10      #3747 "A" through "J"
        hex     5D 37            ;11      #375D "K through "T"
        hex     73 37            ;12      #3773 "U" through "Z" and "RUBEND"
        hex     8B 37            ;13      #378B "REGI TIME"
        hex     00 61            ;14      #6100 High score entry 1 ?
        hex     22 61            ;15      #6122 High score entry 2 ?
        hex     44 61            ;16      #6144 High score entry 3 ?
        hex     66 61            ;17      #6166 High score entry 4 ?
        hex     88 61            ;18      #6188 High score entry 5?
        hex     9E 37            ;19      #379E "RANK SCORE NAME"
        hex     B6 37            ;1A      #37B6 "YOUR NAME WAS REGISTERED"
        hex     D2 37            ;1B      #37D2 "INSERT COIN"
        hex     E1 37            ;1C      #37E1 "PLAYER    COIN"
        hex     1D 00            ;1D      unused ?
        hex     00 3F            ;1E      #3F00 "(C) 1981"
        hex     09 3F            ;1F      #3F09 "NINTENDO OF AMERICA"

        hex     96 76 17 11 1D                                  ;  ..GAM
        hex     15 10 10 1F 26 15 22 3F 94 76 20 1C 11 29 15 22 ;  E..OVER...PLAYER
        hex     10 30 32 31 3F 94 76 20 1C 11 29 15 22 10 30 33 ;  .<I>...PLAYER.<2
        hex     31 3F 80 76 18 19 17 18 10 23 13 1F 22 15 3F 9F ;  >...HIGH.SCORE..
        hex     75 13 22 15 14 19 24 10 10 10 10 3F 5E 77 18 1F ;  .CREDIT.......HO
        hex     27 10 18 19 17 18 10 13 11 1E 10 29 1F 25 10 17 ;  W.HIGH.CAN.YOU.G
        hex     15 24 10 FB 10 3F 29 77 1F 1E 1C 29 10 01 10 20 ;  ET.?....ONLY.1.P
        hex     1C 11 29 15 22 10 12 25 24 24 1F 1E 3F 29 77 01 ;  LAYER.BUTTON...1
        hex     10 1F 22 10 02 10 20 1C 11 29 15 22 23 10 12 25 ;  .OR.2.PLAYERS.BU
        hex     24 24 1F 1E 3F 27 76 20 25 23 18 3F 06 77 1E 11 ;  TTON...PUSH...NA
        hex     1D 15 10 22 15 17 19 23 24 22 11 24 19 1F 1E 3F ;  ME.REGISTRATION.
        hex     88 76 1E 11 1D 15 2E 3F E9 75 2D 2D 2D 10 10 10 ;  ..NAME:...---...
        hex     10 10 10 10 10 10 3F 0B 77 11 10 12 10 13 10 14 ;  .........A.B.C.D
        hex     10 15 10 16 10 17 10 18 10 19 10 1A 3F 0D 77 1B ;  .E.F.G.H.I.J...K
        hex     10 1C 10 1D 10 1E 10 1F 10 20 10 21 10 22 10 23 ;  .L.M.N.O.P.Q.R.S
        hex     10 24 3F 0F 77 25 10 26 10 27 10 28 10 29 10 2A ;  .T...U.V.W.X.Y.Z
        hex     10 2B 10 2C 44 45 46 47 48 10 3F F2 76 22 15 17 ;  ...-RUBEND...REG
        hex     19 10 24 19 1D 15 10 10 30 03 00 31 10 3F 92 77 ;  I.TIME..........
        hex     22 11 1E 1B 10 10 23 13 1F 22 15 10 10 1E 11 1D ;  RANK..SCORE..NAM
        hex     15 10 10 10 10 3F 72 77 29 1F 25 22 10 1E 11 1D ;  E.......YOUR.NAM
        hex     15 10 27 11 23 10 22 15 17 19 23 24 15 22 15 14 ;  E.WAS.REGISTERED
        hex     42 3F A7 76 19 1E 23 15 22 24 10 13 1F 19 1E 10 ;  ....INSERT.COIN.
        hex     3F 0A 77 10 10 20 1C 11 29 15 22 10 10 10 10 13 ;  .....PLAYER....C
        hex     1F 19 1E 3F FC 76 49 4A 10 1E 19 1E 24 15 1E 14 ;  OIN......NINTEND
        hex     1F 10 10 10 10 3F                               ;  O.....

; ???

        hex     7C 75 01 09 08 01 3F

; table data used for game intro

        hex    02 97 38 68 38   ; top level where girl sits
        hex    02 DF 54 10 54   ; kongs level girder
        hex    02 EF 6D 20 6D   ; 2nd girder down
        hex    02 DF 8E 10 8E   ; 3rd girder down
        hex    02 EF AF 20 AF   ; 4th girder down
        hex    02 DF D0 10 D0   ; 5th girder down
        hex    02 EF F1 10 F1   ; bottom girder
        hex    00 53 18 53 54   ; kong's ladder (left)
        hex    00 63 18 63 54   ; kong's ladder (right)
        hex    00 93 38 93 54   ; ladder to reach girl
        hex    00 83 54 83 F1   ; long ladder (left)
        hex    00 93 54 93 F1   ; long ladder (right)
        hex    AA               ; end of data code

; table data
; used for timer graphic and zero score inside

        hex     8D 7D 8C
        hex     6F 00 7C
        hex     6E 00 7C
        hex     6D 00 7C
        hex     6C 00 7C
        hex     8F 7F 8E

; table data
; used for antimation of kong

        hex     47 27 08 50
        hex     2F A7 08 50
        hex     3B 25 08 50
        hex     00 70 08 48
        hex     3B 23 07 40
        hex     46 A9 08 44
        hex     00 70 08 48
        hex     30 29 08 44
        hex     00 70 08 48
        hex     00 70 0A 48

; table data used to draw the girl from #0D7A and #0B2A

        hex     6F 10 09 23
        hex     6F 11 0A 33

; used for animation of kong

        hex     50 34 08 3C
        hex     00 35 08 3C
        hex     53 32 08 40
        hex     63 33 08 40
        hex     00 70 08 48
        hex     53 36 08 50
        hex     63 37 08 50
        hex     6B 31 08 41
        hex     00 70 08 48
        hex     6A 14 0A 48

; used when kong jump at end of intro

        hex     FD FD FD FD FD FD FD FE FE FE FE FE
        hex     FE FF FF FF FF 00 00 01 01 01
        hex     7F              ; end code


; used when kong jumps to left during intro at #0B70

        hex     FF FF FF FF FF
        hex     00 FF 00 00 01 00 01 01 01 01 01 7F

; used after kong has jumped
; used in $0DA7.  end code is $AA

        hex     04 7F F0 10 F0
        hex     02 DF F2 70 F8
        hex     02 6F F8 10 F8
        hex     AA

        hex     04 DF D0 90 D0
        hex     02 DF DC 20 D1
        hex     AA

        hex     FF FF FF FF FF  ; unused ?

        hex     04 DF A8 20 A8
        hex     04 5F B0 20 B0
        hex     02 DF B0 20 BB
        hex     AA

        hex     04 DF 88 30 88
        hex     04 DF 90 B0 90
        hex     02 DF 9A 20 8F
        hex     AA

        hex     04 BF 68 20 68
        hex     04 3F 70 20 70
        hex     02 DF 6E 20 79
        hex     AA

        hex     02 DF 58 A0 55  ; top right ledge angled down
        hex     AA

; this is table data
; used for animation of kong
; used from #2D24

        hex     00 70 08 44
        hex     2B AC 08 4C
        hex     3B AE 08 4C
        hex     3B AF 08 3C
        hex     4B B0 07 3C
        hex     4B AD 08 4C
        hex     00 70 08 44
        hex     00 70 08 44
        hex     00 70 08 44
        hex     00 70 0A 44

; used to animate kong

        hex     47 27 08 4C
        hex     2F A7 08 4C
        hex     3B 25 08 4C
        hex     00 70 08 44
        hex     3B 23 07 3C
        hex     4B 2A 08 3C
        hex     4B 2B 08 4C
        hex     2B AA 08 3C
        hex     2B AB 08 4C
        hex     00 70 0A 44

; used for kong's middle deploy

        hex     00 70 08 44
        hex     4B 2C 08 4C
        hex     3B 2E 08 4C
        hex     3B 2F 08 3C
        hex     2B 30 07 3C
        hex     2B 2D 08 4C
        hex     00 70 08 44
        hex     00 70 08 44
        hex     00 70 08 44
        hex     00 70 0A 44

; used in #2E3D on elevators
; used for bouncers; each is an offset that is added to the Y position as it moves

        hex     FD FD FD FE FE FE FE FF FF 00 FF 00 00 01 00 01 01 02 02 02 02 03 03 03
        hex     7F              ; end code

; used in $2D8C for barrel release

        hex     1E 4E BB 4C D8 4E 59 4E 7F

; table data having to do with crazy barrels.
; used in #2D83

        hex     BB              ; for crazy barrels
        hex     4D              ;
        hex     7F              ; deployed when #7F

; table data
; kong is beating his chest

        hex     47 27 08 50
        hex     2D 26 08 50
        hex     3B 25 08 50
        hex     00 70 08 48
        hex     3B 24 07 40
        hex     4B 28 08 40
        hex     00 70 08 48
        hex     30 29 08 44
        hex     00 70 08 48
        hex     00 70 0A 48

; table data for animation of kong #28 bytes (40 decimal)
; used in #0445
; the kong is beating his chest with right leg lifted

        hex     49 A6 08 50 2F A7 08 50 3B 25 08 50 00 70 08 48
        hex     3B 24 07 40 46 A9 08 44 00 70 08 48 2B A8 08 40
        hex     00 70 08 48 00 70 0A 48

; table data for upside down kong after rivets cleared
; used in #1870
; #28 bytes = 40 bytes decimal

        hex     73 A7 88 60
        hex     8B 27 88 60
        hex     7F 25 88 60
        hex     00 70 88 68
        hex     7F 24 87 70
        hex     74 29 88 6C
        hex     00 70 88 68
        hex     8A A9 88 6C
        hex     00 70 88 68
        hex     00 70 8A 68

; table data
; used when rivets are cleared

        hex     05 AF F0 50 F0 AA
        hex     05 AF E8 50 E8 AA
        hex     05 AF E0 50 E0 AA
        hex     05 AF D8 50 D8 AA
        hex     05 B7 58 48 58 AA

; this table is used for the various screen patterns for the levels
; code 1 = girders, 4 = rivets, 2 = pies, 3 = elevators
; used from $1947 and from $1799 and from #09BA

        hex     01 04                   ; level 1
        hex     01 03 04                ; level 2
        hex     01 02 03 04             ; level 3
        hex     01 02 01 03 04          ; level 4
        hex     01 02 01 03 01 04       ; level 5 +
        hex     7F                      ; end code

; table data referenced in $3267

        hex     FF 00 FF FF FE FE FE FE FE FE FE FE FE FE FE FF FF 00

; table data referenced in $343B

        hex     E8 E5 E3 E2
        hex     E1 E0 DF DE DD DD DC DC DC DC DC DC DD DD DE DF
        hex     E0 E1 E2 E3 E4 E5 E7 E9 EB ED F0 AA

; table data refeernced in #
; controls the positions of fires coming out of the oil can on the conveyors

        hex     80 7B 78 76 74 73 72 71 70 70 6F 6F 6F 70 70 71 72 73 74 75 76 77 78
        hex     AA              ; end code

; table data referenced in $34C7

        hex     EE F0 DB A0 E6 C8 D6 78 EB F0 DB A0 E6 C8 E6 C8

; table data referenced in $34ED

        hex     1B C8 23 A0 2B 78 12 F0 1B C8 23 A0 12 F0 1B C8

; start of table data
; used for screen 1 (girders)
; 120 bytes long
; 1st byte is the code [6 = X character, 5 = circle girder used in rivets, 3 = conveyor, 2 = girder, 1 = broken ladder, 0 = ladder]
; 2nd and 3rd bytes are the X,Y locations to start drawing
; data used for #6300


        hex     02 97 38 68 38  ; top girder where girl sits
        hex     02 9F 54 10 54  ; girder where kong sits
        hex     02 DF 58 A0 55  ; 1st slanted girder at top right
        hex     02 EF 6D 20 79  ; 2nd slanted girder (has hammer at left side)
        hex     02 DF 9A 10 8E  ; 3rd slanted girder
        hex     02 EF AF 20 BB  ; 4th slanted girder
        hex     02 DF DC 10 D0  ; 5th slanted girder (has hammer at right side)
        hex     02 FF F0 80 F7  ; bottom slanted girder
        hex     02 7F F8 00 F8  ; bottom flat girder where mario starts
        hex     00 CB 57 CB 6F  ; short ladder at top right
        hex     00 CB 99 CB B1  ; short ladder at center right
        hex     00 CB DB CB F3  ; short ladder at bottom right
        hex     00 63 18 63 54  ; kong's ladder (right)
        hex     01 63 D5 63 F8  ; bottom broken ladder
        hex     00 33 78 33 90  ; short ladder at left side under top hammer
        hex     00 33 BA 33 D2  ; short ladder at left side above oil can
        hex     00 53 18 53 54  ; kong's ladder (left)
        hex     01 53 92 53 B8  ; second broken ladder from bottom, on 3rd girder
        hex     00 5B 76 5B 92  ; longer ladder under the top left hammer
        hex     00 73 B6 73 D6  ; longer ladder to left of bottom hammer
        hex     00 83 95 83 B5  ; center longer ladder
        hex     00 93 38 93 54  ; ladder leading to girl
        hex     01 BB 70 BB 98  ; third broken ladder on right side near top
        hex     01 6B 54 6B 75  ; fourth broken ladder near kong
        hex     AA        ; AA code signals end of data

; table data for screen 2 conveyors
; 135 bytes long

        hex     06 8F 90 70 90  ; central patch of XXX's
        hex     06 8F 98 70 98  ; central patch of XXX's
        hex     06 8F A0 70 A0  ; central patch of XXX's
        hex     00 63 18 63 58  ; kong's ladder (right)
        hex     00 63 80 63 A8  ; center ladder to left of oil can fire
        hex     00 63 D0 63 F8  ; bottom level ladder #2 of 4
        hex     00 53 18 53 58  ; kong's ladder (left)
        hex     00 53 A8 53 D0  ; ladder under the hat
        hex     00 9B 80 9B A8  ; center ladder to right of oil can fire
        hex     00 9B D0 9B F8  ; bottom level ladder #3 of 4
        hex     01 23 58 23 80  ; top broken ladder left side
        hex     01 DB 58 DB 80  ; top broken ladder right side
        hex     00 2B 80 2B A8  ; ladder on left platform with hammer
        hex     00 D3 80 D3 A8  ; ladder on right plantform with umbrella
        hex     00 A3 A8 A3 D0  ; ladder to right of bottom hammer
        hex     00 2B D0 2B F8  ; bottom level ladder #1 of 4
        hex     00 D3 D0 D3 F8  ; bottom level ladder #4 of 4
        hex     00 93 38 93 58  ; ladder leading to girl
        hex     02 97 38 68 38  ; girder where girl sits
        hex     03 EF 58 10 58  ; top conveyor girder
        hex     03 F7 80 88 80  ; top right conveyor next to oil can
        hex     03 77 80 08 80  ; top left conveyor next to oil can
        hex     02 A7 A8 50 A8  ; center ledge
        hex     02 E7 A8 B8 A8  ; right center ledge
        hex     02 3F A8 18 A8  ; left center ledge (has hammer)
        hex     03 EF D0 10 D0  ; main lower conveyor girder (has hammer)
        hex     02 EF F8 10 F8  ; bottom level girder
        hex     AA              ; end code

; table data for the elevators
; 165 bytes long

        hex     00 63 18 63 58  ; kong's ladder (right)
        hex     00 63 88 63 D0  ; center ladder right
        hex     00 53 18 53 58  ; long's ladder (left)
        hex     00 53 88 53 D0  ; center ladder left
        hex     00 E3 68 E3 90  ; far top right ladder leading to purse
        hex     00 E3 B8 E3 D0  ; far bottom right ladder
        hex     00 CB 90 CB B0  ; ladder leading to purse (lower level)
        hex     00 B3 58 B3 78  ; ladder leading to kong's level
        hex     00 9B 80 9B A0  ; ladder to right of top right elevator
        hex     00 93 38 93 58  ; ladder leading up to girl
        hex     00 23 88 23 C0  ; long ladder on left side
        hex     00 1B C0 1B E8  ; bottom left ladder
        hex     02 97 38 68 38  ; girder girl is on
        hex     02 B7 58 10 58  ; kong's girder
        hex     02 EF 68 E0 68  ; girder where purse is
        hex     02 D7 70 C8 70  ; girder to left of purse
        hex     02 BF 78 B0 78  ; girder holding ladder that leads up to kong's level
        hex     02 A7 80 90 80  ; girder to right of top right elevator
        hex     02 67 88 48 88  ; top girder for central ladder section between elevators
        hex     02 27 88 10 88  ; girder that holds the umbrella
        hex     02 EF 90 C8 90  ; girder under the girder that has the purse
        hex     02 A7 A0 98 A0  ; bottom girder for section to right of top right elevator
        hex     02 BF A8 B0 A8  ; small floating girder
        hex     02 D7 B0 C8 B0  ; small girder
        hex     02 EF B8 E0 B8  ; small girder
        hex     02 27 C0 10 C0  ; girder just above mario start
        hex     02 EF D0 D8 D0  ; small girder on far right bottom
        hex     02 67 D0 50 D0  ; bottom girder for central ladder section between elevators
        hex     02 CF D8 C0 D8  ; small girder
        hex     02 B7 E0 A8 E0  ; small girder
        hex     02 9F E8 88 E8  ; floating girder where the right side elevator gets off
        hex     02 27 E8 10 E8  ; girder where mario starts
        hex     02 EF F8 10 F8  ; long bottom girder (mario dies if he gets that low)
        hex     AA              ; end code

; table data for the rivets

        hex     00 7B 80 7B A8  ; center ladder level 3
        hex     00 7B D0 7B F8  ; bottom center ladder
        hex     00 33 58 33 80  ; top left ladder
        hex     00 53 58 53 80  ; top left ladder (right side)
        hex     00 AB 58 AB 80  ; top right ladder (left side)
        hex     00 CB 58 CB 80  ; top right ladder
        hex     00 2B 80 2B A8  ; level 3 ladder left side
        hex     00 D3 80 D3 A8  ; level 3 ladder right side
        hex     00 23 A8 23 D0  ; level 2 ladder left side
        hex     00 5B A8 5B D0  ; level 2 ladder #2 of 4
        hex     00 A3 A8 A3 D0  ; level 2 ladder #3 of 4
        hex     00 DB A8 DB D0  ; level 2 ladder right side
        hex     00 1B D0 1B F8  ; bottom left ladder
        hex     00 E3 D0 E3 F8  ; bottom right ladder
        hex     05 B7 30 48 30  ; girder above kong
        hex     05 CF 58 30 58  ; girder kong stands on
        hex     05 D7 80 28 80  ; level 4 girder
        hex     05 DF A8 20 A8  ; level 3 girder
        hex     05 E7 D0 18 D0  ; level 2 girder
        hex     05 EF F8 10 F8  ; bottom level girder
        hex     AA              ; end code

;

        hex     10 82 85 8B 10 85 80 8B 10 87 85 8B 81 80 80    ; .25m.50m.75m100m
        hex     8B 81 82 85 8B 81 85 80 8B                      ; 125m150m

; used to draw the game logo in attract mode
; data called from #07F7
; data grouped in 3's
; first byte is a loop counter - how many things to draw, going down
; 2nd and 3rd bytes are coordinates to start

        hex     05 88 77 01 68 77 01 6C 77 03 49 77             ; D
        hex     05 08 77 01 E8 76 01 EC 76 05 C8 76             ; O
        hex     05 88 76 02 69 76 02 4A 76 05 28 76             ; N
        hex     05 E8 75 01 CA 75 03 A9 75 01 88 75 01 8C 75    ; K
        hex     05 48 75 01 28 75 01 2A 75                      ; E (part 1)
        hex     01 2C 75 01 08 75 01 0A 75 01 0C 75             ; E (part 2)
        hex     03 C8 74 03 AA 74 03 88 74                      ; Y
        hex     05 2F 77 05 0F 77 02 F0 76 02 CF 76 02 D2 76    ; K
        hex     05 8F 76 05 6F 76 01 4F 76 01 53 76 05 2F 76    ; O
        hex     05 EF 75 02 D0 75 02 B1 75 05 8F 75             ; N
        hex     03 50 75 05 2F 75 01 0F 75 01 13 75             ; G (part 1)
        hex     01 EF 74 01 F1 74 01 F3 74 02 D1 74             ; G (part 2)
        hex     00                                              ; end code

; table code reference from $0F6F
; values are copied into $6280 through #6280 + #40

        hex     00 00 23 68
        hex     01 11 00 00 00 10 DB 68 01 40 00 00 08 01 01 01
        hex     01 01 01 01 01 01 00 00 00 00 00 00 80 01 C0 FF
        hex     01 FF FF 34 C3 39 00 67 80 69 1A 01 00 00 00 00
        hex     00 00 00 00 04 00 10 00 00 00 00 00

; data used for the barrel pile next to kong
; called from #0FD7

        hex     1E 18 0B 4B     ; first barrel
        hex     14 18 0B 4B     ; second barrel
        hex     1E 18 0B 3B     ; third barrel
        hex     14 18 0B 3B     ; fourth barrel

; the following is table data that gets copied to #6407 - location and other data of the fires?
; 05 is a loop varialbe
; 1C loops value corresponds to total length of table

        hex     3D 01 03 02

; table data that also gets called from #1138
; DE is $6407 - Fire $ 1 y value
; B is 05 and C is 1C

        hex     4D 01 04 01

        hex     27 70 01 E0 00 00       ; initial data for fires on girders ?
        hex     7F 40 01 78 02 00       ; initial data for conveyors to release a fire ?

; table data called from $0FF5.  4 bytes

        hex     27 49 0C F0     ; oil can for girders
        hex     7F 49 0C 88     ; oil can for conveyors ?

; another table called and copied into #6687-668A an #6697-#669A - has to do with the hammers
; B counter is #02 and C is #0C
; called from #122E
; 3E0C is called also from $1000

        hex     1E 07            ; 1E is the hammer sprite value.  07 is hammer color
        hex     03 09            ; ???
        hex     24 64            ; position of top hammer for girders.  24 is X, 64 is Y
        hex     BB C0            ; bottom hammer for girders at BB, C0

        hex     23 8D 7B B4      ; for conveyors

        hex     1B 8C 7C 64      ; for rivets
        hex     4B 0E 04 02      ; ???

; 2 ladder sprites for conveyors
; 46 = ladder

        hex     23 46 03 68     ; ladder at 23, 68
        hex     DB 46 03 68     ; ladder at DB, 68

; the 6 conveyor pulleys

        hex     17 50 00 5C     ; 50 = edge of conveyor pulley
        hex     E7 D0 00 5C     ; D0 = edge of conveyor pulley inverted
        hex     8C 50 00 84
        hex     73 D0 00 84
        hex     17 50 00 D4
        hex     E7 D0 00 D4

; bonus items on conveyors

        hex     53 73 0A A0             ; position of hat on pies is 53,A0
        hex     8B 74 0A F0             ; position of purse on pies is 8B,F0
        hex     DB 75 0A A0             ; umbrella on the pies is at DB,A0

; bonus items for elevators

        hex     5B 73 0A C8             ;  hat at 5B,C8
        hex     E3 74 0A 60             ;  purse at E3,60
        hex     1B 75 0A 80             ;  umbrella on elevator is 80,1B

; bonus items for rivets

        hex     DB 73 0A C8             ; hat on rivets at DB,C8
        hex     93 74 0A F0             ; purse on rivets at 93,F0
        hex     33 75 0A 50             ; umbrella on rivets at 33,50

; used in elevators - called from #10CC

        hex     44 03 08 04

; used in elevators, called from #11EC
; used for elevator sprites

        hex     37 F4
        hex     37 C0
        hex     37 8C           ; elevators on left all have X value of 37

        hex     77 70
        hex     77 A4
        hex     77 D8           ; elevators on right all have X value of 77

; award points for jumping a barrels and items
; arrive from #1DD7
; A is preloaded with 1,3, or 7
; patch ?

        LD      DE,$0001        ; 100 points
        LD      B,$7B           ; sprite for 100
        RRA                     ; is the score set for 100 ?
        JP      NC,$1E28        ; yes, award points

        LD      E,$03           ; else set 300 points
        LD      B,$7D           ; sprite for 300
        RRA                     ; is the score set for 300 ?
        JP      NC,$1E28        ; yes, award points

        LD      E,$05           ; else set 500 points [bug, should be 800] ___BUG___
        LD      B,$7F           ; sprite for 800
        JP      $1E28           ; award points


; called from #286B
; a patch ?

        LD      A,($6227)       ; load A with screen number
        PUSH    HL              ; save HL
        RST     $28             ; jump to new location based on screen number

; data for above:

        hex     00 00           ; unused
        hex     99 3E           ; #3E99 - girders
        hex     B0 28           ; #28B0 - pie
        hex     E0 28           ; #28E0 - elevator
        hex     01 29           ; #2901 - rivets
        hex     00 00           ; unused

; checks for jumps over items on girders

        POP     HL                      ; restore HL
        XOR     A                       ; A := 0
        LD      (NumObstaclesJumped),A  ; clear counter for barrels jumped
        LD      B,$0A                   ; For B = 1 to #A barrels
        LD      DE,$0020                ; load DE with offset
        LD      IX,$6700                ; load IX with start of barrel info table
        CALL    $3EC3                   ; call sub below.  check for barrels under jump

        LD      B,$05                   ; for B = 1 to 5 fires
        LD      IX,$6400                ; start of fires table
        CALL    $3EC3                   ; check for fires being jumped

        LD      A,(NumObstaclesJumped)  ; load A with counter for items jumped
        AND     A                       ; nothing jumped ?
        RET     Z                       ; yes, return

        CP      $01                     ; was 1 item jumped?
        RET     Z                       ; yes, return; 1 is the code for 100 pts

        CP      $03                     ; were less than 3 items jumped ?
        LD      A,$03                   ; A := 3  = code for 2 items, 300 pts score
        RET     C                       ; yes, return

        LD      A,$07                   ; else A := 7 = code for 3+ items, awards 800 points
        RET

; subroutine called from $3EA7 above
; checks for mario jumping over barrels or fires
; H is preloaded with either 5 or #13 (19 decimal) for the area under mario ?
; C is preloaded with mario's Y position + #C (12 decimal)
; IX preloaded with start of array for fires or barrels, EG #6700 or #6400
; L is preloaded with height window value ?
; DE is preloaded with offset to add for next sprite

        BIT     0,(IX+$00)      ; is this barrel/fire active?
        JP      Z,$3EFA         ; no, jump ahead to try next one

        LD      A,C             ; load A with mario's adjusted Y position
        SUB     (IX+$05)        ; subtract the fire/barrel Y position.  did the result go negative?
        JP      NC,$3ED3        ; no, skip next step

        NEG                     ; Negate A (A := 0 - A)

        INC     A               ; increment A
        SUB     L               ; subtract L (height window?)  Is there a carry ?
        JP      C,$3EDE         ; yes, skip next two steps

        SUB     (IX+$0A)        ; else subtract the items' height???
        JP      NC,$3EFA        ; if out of range, jump ahead to try next one

; we are within the Y range, test X range next

        LD      A,(IY+$03)      ; load A with mario's X position
        SUB     (IX+$03)        ; subtract the item's X position
        JP      NC,$3EE9        ; if no carry, skip next step

        NEG                     ; negate A

        SUB     H               ; subtract the horizontal window (5 or 19 pixels)
        JP      C,$3EF3         ; if out of range, skip next 2 steps

        SUB     (IX+$09)        ; subtract the item's width???
        JP      NC,$3EFA        ; if out of range, skip ahead to try next one

; item was jumped

        LD      A,(NumObstaclesJumped)  ; load A with counter of how many barrels/fires jumped
        INC     A                       ; increase it
        LD      (NumObstaclesJumped),A  ; store

        ADD     IX,DE                   ; add offset for next barrel or fire
        DJNZ    $3EC3                   ; Next B

        RET

; ... overwrites the message from game creators...

        hex     00
        hex     5C 76 49 4A 01 09 08 01 3F 7D 77 1E 19 1E 24 15 ; .(C)1981...NINTE
        hex     1E 14 1F 10 1F 16 10 11 1D 15 22 19 13 11 10 19 ; NDO.OF.AMERICA.I
        hex     1E 13 2B 3F                                     ; NC..

; called from $081C : patch to draw the TM logo on attract screen

        LD      HL,$74AF        ; load HL with screen VRAM address
        LD      DE,$FFE0        ; load offset
        LD      (HL),$9F        ; draw first part of TM logo to screen
        ADD     HL,DE           ; next screen location
        LD      (HL),$9E        ; draw second part of TM logo to screen
        RET

;___________________________________________________________________
;
; Original Dkong code, taken from mame set dkongj
;
;3F00:  43 4F 4E 47 52 41 54 55 4C 41 54 49 4F 4E 20 21  CONGRATULATION !
;3F10:  49 46 20 59 4F 55 20 41 4E 41 4C 59 53 45 20 20  IF YOU ANALYSE
;3F20:  44 49 46 46 49 43 55 4C 54 20 54 48 49 53 20 20  DIFFICULT THIS
;
;___________________________________________________________________


        hex     50 52 4F 47 52 41 4D 2C 57 45 20 57 4F 55 4C 44 ; PROGRAM,WE WOULD
        hex     20 54 45 41 43 48 20 59 4F 55 2E 2A 2A 2A 2A 2A ;  TEACH YOU.*****
        hex     54 45 4C 2E 54 4F 4B 59 4F 2D 4A 41 50 41 4E 20 ; TEL.TOKYO-JAPAN
        hex     30 34 34 28 32 34 34 29 32 31 35 31 20 20 20 20 ; 044(244)2151
        hex     45 58 54 45 4E 54 49 4F 4E 20 33 30 34 20 20 20 ; EXTENTION 304
        hex     53 59 53 54 45 4D 20 44 45 53 49 47 4E 20 20 20 ; SYSTEM DESIGN
        hex     49 4B 45 47 41 4D 49 20 43 4F 2E 20 4C 49 4D 2E ; IKEGAMI CO. LIM.


; jump here from #0CD1
; a patch ?

        CALL    $3FA6           ; call sub below
        JP      $0D5F           ; ret to program [this was original line wiped by patch ?]

; called from #3FA0 above

        LD      A,$02           ; A := 2
        RST     $30             ; check to see if the level is pie factory.  If not, RET to #3FA3 [then jump to #0D5F]

        LD      B,$02           ; for B = 1 to 2
        LD      HL,$776C        ; load HL with video RAM address for top rectractable ladder

        LD      (HL),$10        ; clear the top of the ladder
        INC     HL
        INC     HL              ; next address
        LD      (HL),$C0        ; draw a ladder 2 rows down
        LD      HL,$748C        ; set HL for next loop - does the other side of the screen ; [sloppy?  this instruction not needed on 2nd loop]
        DJNZ    $3FAE           ; Next B

        RET                     ; ret [to #3FA3, then jump to #0D5F]

        hex     00 00 00 00 00 00                ; unused

; called from #2285
; [seems like a patch ? - resets mario sprite when ladder descends]

        LD      HL,$694D        ; load HL with mario sprite value
        LD      (HL),$03        ; store 3 = mario on ladder with left hand up
        INC     L
        INC     L               ; HL := #694F = mario sprite Y value
        RET

; unknown
; unused ???

        hex     00 00 41 7F 7F 41 00 00
        hex     00 7F 7F 18 3C 76 63 41
        hex     00 00 7F 7F 49 49 49 41
        hex     00 1C 3E 63 41 49 79 79
        hex     00 7C 7E 13 11 13 7E 7C
        hex     00 7F 7F 0E 1C 0E 7F 7F
        hex     00 00 41 7F 7F 41 00 00



; 0000 0000 0100 0001 0111 1111 0111 1111 0100 0001 0000 0000 0000 0000
; 0111 1111 0111 1111 0001 1000 0011 1100 0111 0110 0110 0011 0100 0001
; 0000 0000 0111 1111 0111 1111 0100 1001 0100 1001 0100 1001 0100 0001
; 0001 1100 0011 1110 0110 0011 0100 0001 0100 1001 0111 1001 0111 1001
; 0111 1100








; http://www.brasington.org/arcade/tech/dk/
;
; Function Chip Type 2-Board location 4-Board location
; Color Maps 256x4 prom 2E (CPU) 2K (CPU)
; Color Maps 256x4 prom 2F (CPU) 2J (CPU)
; Character Colors 256x4 prom 2N (VIDEO) 5F (VIDEO)
; Fixed Characters 2716 3N (VIDEO) 5H (VIDEO)
; Fixed Characters 2716 3P (VIDEO) 5K (VIDEO)
; Code 0x3000-0x3fff 2532 5A (CPU) 5K (CPU)
; Code 0x2000-0x2fff 2532 5B (CPU) 5H (CPU)
; Code 0x1000-0x1Fff 2532 5C (CPU) 5G (CPU)
; Code 0x0000-0x0Fff 2532 5E (CPU) 5F (CPU)
; Not used - vacant     5L (CPU)
; Moving Objects 2716 7C (VIDEO) 4M (CLK)
; Moving Objects 2716 7D (VIDEO) 4N (CLK)
; Moving Objects 2716 7E (VIDEO) 4R (CLK)
; Moving Objects 2716 7F (VIDEO) 4S (CLK)
; Digital Sound 2716 3F (CPU) 3J (SOU)
; Digital Sound 2716 3H (CPU) 3I (SOU)
; Z80 CPU  Z80 7C (CPU) 5C (CPU)
; 8035 MPU (music) 8035 7H (CPU) 3H (SOU)
; CPU RAM 2114 3A (CPU) XX (CPU)
; CPU RAM 2114 4A (CPU) XX (CPU)
; CPU RAM 2114 3B (CPU) XX (CPU)
; CPU RAM 2114 4B (CPU) XX (CPU)
; CPU RAM 2114 3C (CPU) XX (CPU)
; CPU RAM 2114 4C (CPU) XX (CPU)
; Character RAM 2114 2P (VIDEO) XX (VIDEO)
; Character RAM 2114 2R (VIDEO) XX (VIDEO)
; Object RAM 2148 6P (VIDEO) XX (VIDEO)
; Object RAM 2148 6R (VIDEO) XX (VIDEO)



; 3D08:  05 88 77 01 68 77 01 6C 77 03 49 77              ; D
; 3D14:  05 08 77 01 E8 76 01 EC 76 05 C8 76              ; O
; 3D20:  05 88 76 02 69 76 02 4A 76 05 28 76              ; N
; 3D2C:  05 E8 75 01 CA 75 03 A9 75 01 88 75 01 8C 75     ; K
; 3D3B:  05 48 75 01 28 75 01 2A 75                       ; E (part 1)
; 3D44:  01 2C 75 01 08 75 01 0A 75 01 0C 75              ; E (part 2)
; 3D50:  03 C8 74 03 AA 74 03 88 74                       ; Y
; 3D59:  05 2F 77 05 0F 77 02 F0 76 02 CF 76 02 D2 76     ; K
; 3D68:  05 8F 76 05 6F 76 01 4F 76 01 53 76 05 2F 76     ; O
; 3D77:  05 EF 75 02 D0 75 02 B1 75 05 8F 75              ; N
; 3D83:  03 50 75 05 2F 75 01 0F 75 01 13 75              ; G (part 1)
; 3D8F:  01 EF 74 01 F1 74 01 F3 74 02 D1 74              ; G (part 2)
; 3D9B:  00                                               ; end code



; change to konkey dong:

; 3D08:  05 0F 77 01 EF 76 01 F3 76 03 D0 76              ; D transposed to where K is

; 3D59:  05 2F 77 05 88 77 02 69 77 02 48 77 02 4B 77     ; K transposed to where D is


; :dkong:20500000:3D66:00004B77:0000FFFF:konkey dong
; :dkong:20710000:3D61:77024877:FFFFFFFF:konkey dong (2/6)
; :dkong:20710000:3D5D:88770269:FFFFFFFF:konkey dong (3/6)
; :dkong:20510000:3D12:0000D076:00FFFFFF:konkey dong (4/6)
; :dkong:20710000:3D0D:7601F376:FFFFFFFF:konkey dong (5/6)
; :dkong:20710000:3D09:0F7701EF:FFFFFFFF:konkey dong (6/6)

;c_5At_g.bin:

;0D09: 0F 77 01 EF 76 01 F3 76 03 D0 76
;0D6D: 88 77 02 69 77 02 48 77 02 4B 77
