---
title: Progress
parent: Features
nav_order: 3
description: What Craftbound saves per character, the tracker, and ticking steps off.
---

# Progress

Everything about where you are is saved **per character**, so each character can level a different profession at its own pace.

## What is saved

| Per character | Per account |
| --- | --- |
| The active guide | Settings (`/craft toggle ...`) |
| Your skill in each profession | Recipes seen in the profession window, with their real reagents |
| Steps you ticked off by hand | Item IDs learned in the auction house |
| Your skill history (skill-ups with the time) | |
| Where the tracker sits, and whether you hid it | |
| Reagents bought but still in the mailbox | |

Most steps don't need saving. Craftbound works out the current step from your skill: a craft step is done once your skill reaches its end, a rank once your maximum skill is above it, a tool once it is in your bags or bank. Only the steps it can't see (disenchanting, or a tool you sold) need a tick.

## The tracker

A small box, on the right of the screen at first:

- the profession and your skill, with a progress bar,
- the next step,
- a reminder when you can train the next rank,
- how many reagents you still need.

Drag it to move it. The **×** hides it, and `/craft` brings it back. `/craft toggle tracker` turns it off for every character.

## Minimap button

The Craftbound book on the minimap: **left-click** shows or hides the tracker, **right-click** picks a guide, and dragging moves it around the minimap. Its tooltip shows your skill and the next step. Minimap collectors (SexyMap, ElvUI, MinimapButtonBag and others) gather it like any other button. `/craft toggle minimap` hides it.

## At login

The chat says where you left off, for example:

> Craftbound: Enchanting Easiest, skill 142. Next: Craft Enchant Bracer - Lesser Stamina x22 (to skill 164).

## Starting over

`/craft reset` forgets this character's ticks and history in the active guide. Your skill comes from the game, so the route picks up at your real skill again.
