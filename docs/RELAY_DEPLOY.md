# Deploying the relay on Render (free tier)

Online matches need the small Node.js relay in `server/` running on the internet. These steps use Render's free tier. They cost nothing, and no card should be needed; check Render's sign-up page, because its terms can change.

The relay stores nothing permanently and only forwards packets between the two players in a room.

## Before you start

- The project is in a GitHub repository, including the `server/` folder and `server/package-lock.json`.
- You have a free account at <https://render.com>, signed in with GitHub.

## Deploy

1. In the Render dashboard, choose **New**, then **Web Service**.
2. Connect the GitHub repository for this project.
3. Fill in the form:

   | Field | Value |
   | --- | --- |
   | Name | `sky-skirmish-relay` (any free name) |
   | Region | Singapore, or whichever is closest to your players |
   | Branch | the branch holding this code |
   | Root Directory | `server` |
   | Runtime | Node |
   | Build Command | `npm ci` |
   | Start Command | `node relay.js` |
   | Instance Type | Free |

4. Under **Advanced**, set **Health Check Path** to `/health`.
5. Choose **Create Web Service** and wait for the log to show `Sky Skirmish relay listening on port`.

Render sets the `PORT` environment variable itself. Do not set it by hand.

## Check that it is running

Open `https://YOUR-SERVICE.onrender.com/health` in a browser. You should see:

```json
{"status":"ok","rooms":0}
```

## Point the game at it

1. Open `data/tuning.json`.
2. In the `net` section, set `relay_url` to your address, using `wss://`:

   ```json
   "relay_url": "wss://YOUR-SERVICE.onrender.com",
   ```

3. Build a new APK:

   ```
   godot --headless --path . --export-debug "Android" build/sky-skirmish-debug.apk
   ```

4. Install the new APK on both phones.

To try a relay without rebuilding, run a desktop build with the flag: `godot --path . -- --relay=wss://YOUR-SERVICE.onrender.com`.

## Test over mobile data (T7 and T8)

1. Turn off Wi-Fi on both phones, so both use mobile data.
2. Open any browser and load the `/health` address once, so the server is awake.
3. Phone A: **Multiplayer**, **Online**, **Create Room**. Note the 6-character code.
4. Phone B: **Multiplayer**, **Online**, **Join Room**, then type the code and tap **Join**.
5. Phone A: tap **Start**. The match should begin within 10 seconds. This is T7.
6. Back on phone B, try a made-up code. It should say "Room not found". This is T8.

## Things to expect on the free tier

- **Sleeping.** Render stops a free service after about 15 minutes with no traffic. The next player waits up to about a minute while it restarts, and the game shows "Waking server…". Load `/health` a minute before a demo so nobody has to wait.
- **Monthly limits.** Free services have limits on hours and bandwidth. A class project should stay within them; the Render dashboard shows your usage.
- **Latency.** Every packet travels to the relay and back, so online play has more delay than LAN play. Choose the closest region.

## Security notes

- Anyone who has the room code can join that room while it has a free slot.
- The relay has no accounts and keeps no logs of game data. It limits rooms to 500 and frames to 64 KiB, and it does not rate-limit connections. That is reasonable for a class demo; do not treat it as hardened public infrastructure.
- Use `wss://`, not `ws://`, so traffic is encrypted between phones and Render.

## Run it on your own PC

```
cd server
npm ci
npm start
```

It listens on port 8080. Set `PORT` to change that. Test with `godot --path . -- --relay=ws://127.0.0.1:8080 --host --profile=host`, read the room code off the screen, then start a second copy with `godot --path . -- --relay=ws://127.0.0.1:8080 --room=CODE --profile=guest`.

## Alternatives

Fly.io and Oracle Cloud also offer free tiers. Any host that runs Node.js 20 or newer and accepts WebSocket connections will work.
