# Manual checklist — AirPlay courtroom output

Requires: an iPad + an Apple TV / AirPlay receiver on the same network.

1. Open a case. Tap the AirPlay button (`toolbar.airplay`) → pick the courtroom receiver.
2. If you used Control Center "Screen Mirroring":
   - Confirm the iPad shows the RED "Screen Mirroring is showing your private notes…" banner
     when the receiver is mirroring (jury scene NOT yet driving the display).
3. Confirm that once the external/jury scene connects, the receiver shows **JuryView**
   (blank/exhibit/whiteboard) and NOT the presenter sidebar/tools, and the red banner clears.
4. Publish an exhibit → it appears on the courtroom display.
5. Open the Whiteboard → Show to Jury → draw → strokes appear on the courtroom display live.
6. Play a video exhibit → it plays inside the jury layout on the receiver (not full-screen
   AVPlayer handoff).
7. Disconnect AirPlay → presenter shows "external disconnected" state; no crash.
