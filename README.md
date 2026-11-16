# GloryBound Scripts

Free, unobfuscated scripts for GloryBound. No keys or ads.

## Getting started

1. Open the script you want below and click **Raw**.
2. Copy the code into your executor and run it while playing GloryBound.
3. Follow the instructions for that script below.

## Scripts

### [Archer PvE](pve/archer/main.lua)

Equip Archer and run the script in a PvE match. It handles movement, attacks, abilities, dodging, and reviving. Use the control panel or number keys to turn individual features on or off. **Retry** is enabled by default.

By default, auto-revive targets other players, not bot teammates. The script is tuned for my preferences; feel free to edit it if you want different behavior.

**Freecam** is enabled by default. Press **8** to toggle it. Use **I/J/K/L** to move, **U** to go up, **O** to go down, and hold the **right mouse button** to look around. Hold **Alt** to use the cursor.

### [Gladiator PvP](pvp/gladiator/main.lua)

Equip Gladiator and run the script in the lobby to enter the ranked queue, or run it after joining a ranked match. It controls movement, attacks, guarding, and abilities. Press **F8** or the **STOP** button to stop it.

Automatic Blessing use currently supports **Iron Skin** and **Blight of Orcus**. If you want to use another Blessing automatically, you will need to customize the script. The script is tuned for my setup; in my experience, it wins roughly **70%** of matches, though results will vary with equipment and opponents.

After a match, the script returns to the lobby. To enter another queue, run it again in the lobby or use your executor's Auto Execute feature.

### [PvP Recorder](pvp/recorder.lua)

This is the recorder I used while developing the PvP script. It collects match information that can help you analyze fights and customize the script.

Run it during a ranked match, preferably before the round starts. Use **Copy current** to copy the current recording, or **Stop + copy** to stop recording and copy it. The recorder also attempts to copy during the match and when it ends. If clipboard access is unavailable, the output is printed in the console.

Recordings contain match data, including player IDs. Check them before sharing.

### [Auto Train & Auto Rebirth](Train/main.lua)

Run the script in the lobby and click the button to turn it **ON**. It uses available 1.5x training equipment and attempts to rebirth when ready. Click the button again to stop.

### [Buy Epic Chests](Chests/BuyEpicChests.lua)

Run this in the lobby to buy Epic Chests with in-game Cash. It stops when you cannot afford another chest or your chest inventory is full. If the chest opener is running, it waits instead.

### [Open All Chests](Chests/OpenAllChests.lua)

Run this in the lobby with no chest reveal currently open. It opens the chests you had when the script started, then attempts to clear the reveal queue. Run it again for chests obtained afterward.

## Auto Execute

If your executor supports Auto Execute, place the script you want to run in its designated auto-execute folder. The folder name and setup depend on the executor. Keep Roblox and the executor running, and make sure the executor runs the script again after a teleport if you want it to continue across places.

For example, Archer PvE has Retry enabled by default, so it can repeat runs while you are away. Auto Train starts **OFF** each time it runs, so you must turn it on. Gladiator enters the queue when the script runs in the lobby; it does not queue again after returning unless the script is run again.

If you need help setting it up or customizing a script, you can ask Codex or another AI coding assistant.

## Anti-AFK

Archer PvE, Gladiator PvP, and Auto Train & Auto Rebirth load a third-party Anti-AFK script at the top of each file. I did not write it.
